library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_periph is
  port(
    clk        : in  std_logic;
    rst_n      : in  std_logic;
    entrada_i  : in  std_logic_vector(31 downto 0); -- bus 32b
    wr_i       : in  std_logic;                     -- 1=write, 0=read
    reg_sel_i  : in  std_logic;                     -- 0=control, 1=datos
    salida_o   : out std_logic_vector(31 downto 0);
    uart_rx_i  : in  std_logic;
    uart_tx_o  : out std_logic
  );
end entity;

architecture rtl of uart_periph is
    --------------------------------------------------------------------
  -- Definición de tipo y señal de estado para la FSM TX
  --------------------------------------------------------------------
    type t_state is (TX_IDLE, TX_FETCH, TX_LOAD, TX_LAUNCH, TX_WAIT);
    signal st : t_state := TX_IDLE;
    signal launch_cnt : unsigned(1 downto 0) := (others=>'0'); -- 0..3

  signal reset : std_logic := '0';

  -- Señales UART 
  signal tx_start    : std_logic := '0';
  signal tx_rdy      : std_logic;
  signal rx_data_rdy : std_logic;
  signal uart_din    : std_logic_vector(7 downto 0);
  signal uart_dout   : std_logic_vector(7 downto 0);

  -- Señales de alto nivel (las iremos cableando)
  signal enviar, leer, FTXF, RXAV : std_logic := '0';
  signal bytesTX, bytesRX : unsigned(8 downto 0) := (others=>'0');
  signal rx_last_data : std_logic_vector(7 downto 0) := (others=>'0');
  
  -- FIFO TX
  signal tx_din, tx_dout : std_logic_vector(7 downto 0);
  signal tx_wr_en, tx_rd_en, tx_full, tx_empty : std_logic;
  signal tx_count : unsigned(8 downto 0);
  signal tx_rdy_sync, tx_rdy_last : std_logic := '0';

  
  -- FIFO RX
  signal rx_din, rx_dout : std_logic_vector(7 downto 0);
  signal rx_wr_en, rx_rd_en, rx_full, rx_empty : std_logic;
  signal rx_count : unsigned(8 downto 0);

begin
  reset <= not rst_n;

  -- UART 
  U_UART : entity work.UART
    port map(
      clk         => clk,
      reset       => reset,
      tx_start    => tx_start,
      tx_rdy      => tx_rdy,
      rx_data_rdy => rx_data_rdy,
      data_in     => uart_din,
      data_out    => uart_dout,
      rx          => uart_rx_i,
      tx          => uart_tx_o
    );

  -- FIFO TX
  U_FIFO_TX : entity work.fifo_uart_tx
  port map(
    clk        => clk,
    srst       => reset,
    din        => tx_din,
    wr_en      => tx_wr_en,
    rd_en      => tx_rd_en,
    dout       => tx_dout,
    full       => tx_full,
    empty      => tx_empty,
    data_count => tx_count
  );

  -- FIFO RX
  U_FIFO_RX : entity work.fifo_uart_rx
  port map(
    clk        => clk,
    srst       => reset,
    din        => rx_din,
    wr_en      => rx_wr_en,
    rd_en      => rx_rd_en,
    dout       => rx_dout,
    full       => rx_full,
    empty      => rx_empty,
    data_count => rx_count
  );

  --------------------------------------------------------------------
  -- 1) Adaptador 32 → 8 bits (escritura a FIFO TX)
  --------------------------------------------------------------------
  tx_din   <= entrada_i(7 downto 0);
  tx_wr_en <= '1' when (reg_sel_i='1' and wr_i='1' and tx_full='0') else '0';

  --------------------------------------------------------------------
  -- 3) Registro de control (bits enviar, leer, FTXF, RXAV, contadores)
  --------------------------------------------------------------------
  process(clk)
  begin
    if rising_edge(clk) then
      if reset='1' then
        enviar <= '0';
        leer   <= '0';
      else
        -- Escritura del host (bits WC)
        if (reg_sel_i='0' and wr_i='1') then
          enviar <= entrada_i(0);
          leer   <= entrada_i(1);
        end if;

        -- Limpieza automática S/C/DC
        if (enviar='1' and tx_empty='1') then
          enviar <= '0';  -- cuando se vacía TX
        end if;

        if (leer='1' and rx_rd_en='1') then
          leer <= '0';    -- cuando se extrae dato o RX vacía
        end if;
      end if;
    end if;
  end process;

  FTXF    <= tx_full;
  RXAV    <= '1' when (rx_count /= 0) else '0';
  bytesTX <= tx_count;
  bytesRX <= rx_count;

   --------------------------------------------------------------------
  -- 4) Lógica de lectura RX (con un ciclo de latencia para el FIFO)
  --------------------------------------------------------------------
  process(clk)
  variable rd_pending : std_logic := '0';
  variable dummy_done : std_logic := '0'; -- ejecuta el dummy solo una vez
  begin
    if rising_edge(clk) then
      if reset='1' then
        rx_rd_en     <= '0';
        rx_last_data <= (others=>'0');
        rd_pending   := '0';
        dummy_done   := '0';
      else
        rx_rd_en <= '0';

        -- Dummy read UNA sola vez para limpiar la latencia
        if (dummy_done='0' and leer='0' and rx_empty='0' and rd_pending='0') then
          rx_rd_en   <= '1';
          rd_pending := '1';
          dummy_done := '1';

        -- Lectura normal cuando el host pulsa "leer"
        elsif (leer='1' and rd_pending='0') then
          rx_rd_en   <= '1';     -- pop del FIFO
          rd_pending := '1';     -- espera 1 ciclo

        -- Captura el dato válido un ciclo después del pop
        elsif (rd_pending='1') then
          rx_last_data <= rx_dout;
          rd_pending   := '0';
        end if;
      end if;
    end if; 
  end process;

     --------------------------------------------------------------------
    -- 5) FSM TX: ráfagas desde FIFO TX con tx_start de 4 ciclos
    --------------------------------------------------------------------
    
    process(clk)
    begin
      if rising_edge(clk) then
        if reset='1' then
          tx_start   <= '0';
          tx_rd_en   <= '0';
          uart_din   <= (others=>'0');
          st         <= TX_IDLE;
          launch_cnt <= (others=>'0');
        else
          -- defaults
          tx_start <= '0';
          tx_rd_en <= '0';
    
          case st is
            when TX_IDLE =>
              if (enviar='1' and tx_empty='0') then
                tx_rd_en   <= '1';
                st         <= TX_FETCH;        -- ciclo de latencia del FIFO
              end if;
    
            when TX_FETCH =>
              st <= TX_LOAD;                   -- ya está listo tx_dout en el siguiente ciclo
    
            when TX_LOAD =>
              uart_din   <= tx_dout;           -- captura el byte
              launch_cnt <= (others=>'0');
              st         <= TX_LAUNCH;
    
            when TX_LAUNCH =>
            tx_start <= '1';  -- mantener activo
            if (tx_rdy = '1') then
              -- el UART confirmó que arrancó (ya terminó el byte anterior)
              st <= TX_WAIT;
            end if;
        
          when TX_WAIT =>
            if (tx_rdy_sync = '1' and enviar='1' and tx_empty='0') then
              -- listo para otro byte
              tx_rd_en <= '1';
              st <= TX_FETCH;
            elsif (tx_rdy_sync = '1') then
              -- nada más que enviar
              st <= TX_IDLE;
            end if;
        
    
            when others =>
              st <= TX_IDLE;
          end case;
        end if;
      end if;
    end process;
    
  --------------------------------------------------------------------
   -- Sincronizador de pulso tx_rdy (para no perder el flanco)
   --------------------------------------------------------------------
   process(clk)
   begin
     if rising_edge(clk) then
       tx_rdy_last <= tx_rdy;
       if (tx_rdy='1' and tx_rdy_last='0') then
         tx_rdy_sync <= '1';
       else
         tx_rdy_sync <= '0';
       end if;
     end if;
   end process;
    
  
  --------------------------------------------------------------------
  -- 6) Recepción UART → FIFO RX
  --------------------------------------------------------------------
  rx_din   <= uart_dout;
  rx_wr_en <= rx_data_rdy and (not rx_full);

  --------------------------------------------------------------------
  -- Salida unificada (datos o control según reg_sel_i)
  --------------------------------------------------------------------
  process(reg_sel_i, enviar, leer, FTXF, RXAV, bytesTX, bytesRX, rx_last_data)
    variable ctrl : std_logic_vector(31 downto 0);
  begin
    -- Inicializa registro de control
    ctrl := (others => '0');
    ctrl(0) := enviar;
    ctrl(1) := leer;
    ctrl(2) := FTXF;
    ctrl(3) := RXAV;
    ctrl(12 downto 4)  := std_logic_vector(bytesTX);
    ctrl(21 downto 13) := std_logic_vector(bytesRX);

    -- Selección de salida
    if reg_sel_i = '1' then
      -- Concatena 24 ceros con los 8 bits del dato recibido
      salida_o <= (23 downto 0 => '0') & rx_last_data;
    else
      salida_o <= ctrl;
    end if;
  end process;

end architecture;
