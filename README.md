# Laboratorio-3-taller-de-Digitales

# Laboratorio 3 – Parte 2: Periférico UART

Este repositorio contiene la implementación del periférico UART desarrollado en la Parte 2 del laboratorio.  
El diseño permite comunicación serial bidireccional entre la FPGA y una computadora usando UART a 115200 baudios.

---

## Objetivos

- Implementar un periférico UART completo dentro de la FPGA.
- Incluir registro de control, registros de datos, FIFOs y la lógica interna.
- Conectarlo al bus del sistema (S/C/DC).
- Crear un testbench para validar la funcionalidad.
- Crear un bloque de pruebas para enviar y recibir datos hacia/desde la PC.

---

## Arquitectura del Periférico

### 1. Registro de Control (`reg_sel_i = 0`)

| Bit | Nombre  | Tipo | Descripción |
|-----|---------|------|-------------|
| 0 | enviar | WC | Inicia una transmisión usando el FIFO TX. Se limpia automáticamente al terminar. |
| 1 | leer | WC | Extrae un byte del FIFO RX. Se limpia después de la lectura. |
| 2 | RXAV | RO | Indica que hay al menos un byte disponible en el FIFO RX. |
| 3 | FTXF | RO | Indica que el FIFO TX está lleno. |

---

### 2. Registros de Datos (`reg_sel_i = 1`)

- **Escritura:** el byte escrito entra al FIFO TX.
- **Lectura:** extrae un byte del FIFO RX.
- Contadores TX/RX se actualizan automáticamente.

---

### 3. FIFOs del Periférico

- FIFO TX: 512 palabras × 8 bits.
- FIFO RX: 512 palabras × 8 bits.
- Ancho hacia la interfaz UART: 8 bits.
- Ancho hacia el sistema: 32 bits (adaptado internamente).

---

### 4. Módulo de Control e Interfaz UART

El módulo entregado por el profesor maneja:
- Generación de baudios.
- TX/RX físico.
- Señales de sincronización para los FIFOs.

Nuestro diseño se conecta directamente a este módulo.

---

## Testbench

Se incluye un testbench que verifica:
- Escritura al FIFO TX.
- Lectura del FIFO RX.
- Funcionamiento de los bits `enviar` y `leer`.
- Flags `RXAV` y `FTXF`.

---

## Bloque de Pruebas en FPGA

El módulo de pruebas permite:
- Enviar bytes desde la FPGA hacia la PC al presionar un botón.
- Recibir bytes desde la PC y mostrarlos mediante LEDs o display.
- Demostrar comunicación UART bidireccional en tiempo real.

---

## Estructura del Repositorio

- `src/` – Código fuente del periférico UART (Verilog/VHDL).
- `tb/` – Testbench del periférico.
- `constraints/` – Archivo `.xdc` de pines.
- `uart_interface/` – Módulo UART entregado por el profesor.
- `README.md` – Documento actual.

---

## Uso

1. Abrir el proyecto en Vivado.
2. Agregar los archivos de `src/`, `tb/` y `constraints/`.
3. Ejecutar simulación.
4. Sintetizar, implementar y generar el bitstream.
5. Probar la comunicación con una PC.

Para la parte 1, los archivos s e encuentran aquí: https://drive.google.com/file/d/1-K_8Y63qyfZpdx5fTPKUdEYbu80AXurs/view?usp=sharing
