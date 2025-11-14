library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_uart_periph is
end;

architecture sim of tb_uart_periph is
  ------------------------------------------------------------------
  -- Señales del DUT
  ------------------------------------------------------------------
  signal clk        : std_logic := '0';
  signal rst_n      : std_logic := '0';
  signal entrada_i  : std_logic_vector(31 downto 0) := (others=>'0');
  signal salida_o   : std_logic_vector(31 downto 0);
  signal wr_i       : std_logic := '0';
  signal reg_sel_i  : std_logic := '0';
  signal uart_tx_o  : std_logic;
  signal uart_rx_i  : std_logic;

  -- Clock de 16 MHz -> periodo 62.5 ns
  constant CLK_PERIOD : time := 62.5 ns;

  -- Helpers para leer campos del registro de control (reg_sel_i=0)
  function bytesTX_ctrl(slv : std_logic_vector(31 downto 0)) return integer is
  begin
    -- CTRL[12:4] = bytesTX (9 bits)
    return to_integer(unsigned(slv(12 downto 4)));
  end function;

  function bytesRX_ctrl(slv : std_logic_vector(31 downto 0)) return integer is
  begin
    -- CTRL[21:13] = bytesRX (9 bits)
    return to_integer(unsigned(slv(21 downto 13)));
  end function;

begin
  -------------------------------------------------------------------
  -- DUT
  -------------------------------------------------------------------
  DUT : entity work.uart_periph
    port map(
      clk        => clk,
      rst_n      => rst_n,
      entrada_i  => entrada_i,
      wr_i       => wr_i,
      reg_sel_i  => reg_sel_i,
      salida_o   => salida_o,
      uart_rx_i  => uart_rx_i,
      uart_tx_o  => uart_tx_o
    );

  -------------------------------------------------------------------
  -- 1) Genera clk=16 MHz y rst_n.
  -------------------------------------------------------------------
  clk   <= not clk after CLK_PERIOD/2;

  -------------------------------------------------------------------
  -- 2) Loopback: conecta TX a RX
  -------------------------------------------------------------------
  uart_rx_i <= uart_tx_o;

  -------------------------------------------------------------------
  -- 3-6) Estímulos principales 
  -------------------------------------------------------------------
  stim : process
    variable v : integer;
  begin
    -- Reset
    rst_n <= '0';
    wait for 500 ns;
    rst_n <= '1';
    wait for 500 ns;

    ---------------------------------------------------------------
    -- 3) Escribe 5 bytes en reg_sel=1 (ventana de datos)
    ---------------------------------------------------------------
    reg_sel_i <= '1';
    for i in 0 to 4 loop
      entrada_i <= (others => '0');
      entrada_i(7 downto 0) <= std_logic_vector(to_unsigned(65 + i, 8)); -- 'A'..'E'
      wr_i <= '1';
      wait for CLK_PERIOD;
      wr_i <= '0';
      wait for 5*CLK_PERIOD;
    end loop;

    ---------------------------------------------------------------
    -- 4) En control: enviar=1 (pulso write con bit0=1)
    ---------------------------------------------------------------
    reg_sel_i <= '0';
    entrada_i <= (others => '0');
    entrada_i(0) <= '1';  -- enviar=1
    wr_i <= '1';
    wait for CLK_PERIOD;
    wr_i <= '0';

    ---------------------------------------------------------------
    -- 5) Espera a que bytesTX llegue a 0 (poll a registro de control)
    ---------------------------------------------------------------
    -- Ponemos reg_sel=0 para leer el registro de control
    reg_sel_i <= '0';
    -- Polling con timeout simple
    for k in 0 to 200000 loop                  -- ~12.5 ms de margen
      -- salida_o refleja CTRL cuando reg_sel_i=0
      v := bytesTX_ctrl(salida_o);
      --report "Polling bytesTX = " & integer'image(v); (ESTO LO USE PARA VERIFICAR)
      exit when v = 0;
      wait for 50*CLK_PERIOD;
    end loop;

    ---------------------------------------------------------------
    -- 6) Lee 5 bytes recibidos:
    --    * Pulsa leer=1 en control (reg_sel=0, bit1=1, wr_i=1 un ciclo)
    --    * Cambia a reg_sel=1 para leer el dato: salida_o[7:0]
    ---------------------------------------------------------------
    -- Espera extra antes de leer
    wait for 30 ms;
    
    for j in 0 to 4 loop
      -- Pulso leer
      reg_sel_i <= '0';
      entrada_i <= (others => '0');
      entrada_i(1) <= '1';  -- leer=1
      wr_i <= '1';
      wait for CLK_PERIOD;
      wr_i <= '0';

      -- Da un par de ciclos para que el periférico haga el pop y
      -- capture rx_last_data
      wait for 4*CLK_PERIOD;

      -- Lee en ventana de datos
      reg_sel_i <= '1';
      wait for 2*CLK_PERIOD;

      report "Dato leído = " &
             integer'image(to_integer(unsigned(salida_o(7 downto 0)))) severity note;
      wait for 1 ms;
    end loop;

    -- Verificaciones extra (opcionales):
    -- RXAV debe ir a 0; enviar y leer deben autolimpiar.
    reg_sel_i <= '0';
    wait for 10*CLK_PERIOD;
    report "bytesRX (debe ser 0) = " & integer'image(bytesRX_ctrl(salida_o)) severity note;
    -- Bits enviar/leer están en CTRL[0] y CTRL[1]; puedes mirar en la forma de onda.

    wait;
  end process;
end;
