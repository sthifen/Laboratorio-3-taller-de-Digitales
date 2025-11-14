module top_fifo_fpga(
    input wire clk,                 // Reloj de la FPGA (100 MHz)
    input wire btn_rst,             // Botón de reset
    input wire btn_wr,              // Botón para escribir
    input wire btn_rd,              // Botón para leer
    input wire [7:0] switches,      // Switches para datos de entrada
    output wire [7:0] leds_dout,    // LEDs mostrando datos de salida
    output wire led_full,           // LED indicando FIFO llena
    output wire led_empty,          // LED indicando FIFO vacía
    output wire [3:0] leds_count    // LEDs mostrando cantidad de datos (0-16)
);

    // Señales internas
    wire clk_16mhz;                 // Reloj de 16 MHz del PLL
    wire locked;                    // PLL bloqueado
    wire rst_sync;                  // Reset sincronizado
    
    // Señales debounced de los botones
    wire btn_wr_pulse;
    wire btn_rd_pulse;
    
    // Reset: activo mientras PLL no esté bloqueado o botón presionado
    assign rst_sync = btn_rst | ~locked;
    
    // Instancia del PLL
    pll_16mhz pll_inst (
        .clk_in1(clk),
        .clk_out1(clk_16mhz),
        .reset(btn_rst),
        .locked(locked)
    );
    
    // Debouncer para botón de escritura
    debouncer #(.DELAY(500000)) db_wr (  // ~5ms a 100 MHz
        .clk(clk),
        .btn_in(btn_wr),
        .btn_out(btn_wr_pulse)
    );
    
    // Debouncer para botón de lectura
    debouncer #(.DELAY(500000)) db_rd (
        .clk(clk),
        .btn_in(btn_rd),
        .btn_out(btn_rd_pulse)
    );
    
    // Instancia de la FIFO de 16 palabras
    fifo_16x8 fifo_inst (
        .clk(clk_16mhz),
        .srst(rst_sync),
        .din(switches),
        .wr_en(btn_wr_pulse & ~led_full),  // Solo escribir si no está llena
        .rd_en(btn_rd_pulse & ~led_empty), // Solo leer si no está vacía
        .dout(leds_dout),
        .full(led_full),
        .empty(led_empty),
        .data_count(leds_count)
    );

endmodule


// Módulo Debouncer para eliminar rebotes de botones
module debouncer #(
    parameter DELAY = 500000  // Delay en ciclos de reloj (5ms @ 100MHz)
)(
    input wire clk,
    input wire btn_in,
    output reg btn_out
);

    reg [19:0] counter;
    reg btn_sync_0, btn_sync_1;
    
    always @(posedge clk) begin
        // Sincronización de 2 etapas
        btn_sync_0 <= btn_in;
        btn_sync_1 <= btn_sync_0;
        
        // Contador para debounce
        if (btn_sync_1 == 1'b1 && counter < DELAY) begin
            counter <= counter + 1;
        end else if (btn_sync_1 == 1'b0) begin
            counter <= 0;
        end
        
        // Salida estable
        if (counter == DELAY - 1) begin
            btn_out <= 1'b1;
        end else begin
            btn_out <= 1'b0;
        end
    end

endmodule