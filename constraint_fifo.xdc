## Archivo de Constraints para Nexys 4 DDR (Artix-7)
## Laboratorio 3 - Parte 3: FIFO con hardware

## Reloj de 100 MHz
set_property -dict { PACKAGE_PIN E3 IOSTANDARD LVCMOS33 } [get_ports { clk }];
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports { clk }];

## Botones (activos en alto cuando se presionan)
set_property -dict { PACKAGE_PIN E16 IOSTANDARD LVCMOS33 } [get_ports { btn_rst }];    # BTNC (Centro)
set_property -dict { PACKAGE_PIN F15 IOSTANDARD LVCMOS33 } [get_ports { btn_wr }];     # BTNU (Arriba)
set_property -dict { PACKAGE_PIN V10 IOSTANDARD LVCMOS33 } [get_ports { btn_rd }];     # BTND (Abajo)

## Switches para datos de entrada (SW0-SW7)
set_property -dict { PACKAGE_PIN U9 IOSTANDARD LVCMOS33 } [get_ports { switches[0] }];
set_property -dict { PACKAGE_PIN U8 IOSTANDARD LVCMOS33 } [get_ports { switches[1] }];
set_property -dict { PACKAGE_PIN R7 IOSTANDARD LVCMOS33 } [get_ports { switches[2] }];
set_property -dict { PACKAGE_PIN R6 IOSTANDARD LVCMOS33 } [get_ports { switches[3] }];
set_property -dict { PACKAGE_PIN R5 IOSTANDARD LVCMOS33 } [get_ports { switches[4] }];
set_property -dict { PACKAGE_PIN V7 IOSTANDARD LVCMOS33 } [get_ports { switches[5] }];
set_property -dict { PACKAGE_PIN V6 IOSTANDARD LVCMOS33 } [get_ports { switches[6] }];
set_property -dict { PACKAGE_PIN V5 IOSTANDARD LVCMOS33 } [get_ports { switches[7] }];

## LEDs para datos de salida (LD0-LD7)
set_property -dict { PACKAGE_PIN T8 IOSTANDARD LVCMOS33 } [get_ports { leds_dout[0] }];
set_property -dict { PACKAGE_PIN V9 IOSTANDARD LVCMOS33 } [get_ports { leds_dout[1] }];
set_property -dict { PACKAGE_PIN R8 IOSTANDARD LVCMOS33 } [get_ports { leds_dout[2] }];
set_property -dict { PACKAGE_PIN T6 IOSTANDARD LVCMOS33 } [get_ports { leds_dout[3] }];
set_property -dict { PACKAGE_PIN T5 IOSTANDARD LVCMOS33 } [get_ports { leds_dout[4] }];
set_property -dict { PACKAGE_PIN T4 IOSTANDARD LVCMOS33 } [get_ports { leds_dout[5] }];
set_property -dict { PACKAGE_PIN U7 IOSTANDARD LVCMOS33 } [get_ports { leds_dout[6] }];
set_property -dict { PACKAGE_PIN U6 IOSTANDARD LVCMOS33 } [get_ports { leds_dout[7] }];

## LEDs para señales de estado
set_property -dict { PACKAGE_PIN V4 IOSTANDARD LVCMOS33 } [get_ports { led_full }];   # LD8
set_property -dict { PACKAGE_PIN U3 IOSTANDARD LVCMOS33 } [get_ports { led_empty }];  # LD9

## LEDs para data_count (LD10-LD13)
set_property -dict { PACKAGE_PIN V1 IOSTANDARD LVCMOS33 } [get_ports { leds_count[0] }];
set_property -dict { PACKAGE_PIN R1 IOSTANDARD LVCMOS33 } [get_ports { leds_count[1] }];
set_property -dict { PACKAGE_PIN P5 IOSTANDARD LVCMOS33 } [get_ports { leds_count[2] }];
set_property -dict { PACKAGE_PIN U1 IOSTANDARD LVCMOS33 } [get_ports { leds_count[3] }];

## Configuración adicional
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]