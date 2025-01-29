/*
---------------------------------------------------------------------------
Copyright 2021 Dialog Semiconductor

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"),
to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE
OR OTHER DEALINGS IN THE SOFTWARE.
---------------------------------------------------------------------------
Base Module Name: uart
Target Devices: SLG47910
Tools version:
  Software: FPGA Navigator v1.0
  Hardware: FPGAPAK Development Board Rev.1.0
Revision:
  05.11.2021 r001 - New design
---------------------------------------------------------------------------
Description :
The UART module (Universal Asynchronous receiver-transmitter) used for asynchronous serial communication,
the module function is to convert outgoing data into serial binary stream and vice versa.
_______      _______________________________________________________
       \____/_____X_____X_____X_____X_____X_____X_____X_____X_____X
      [START][LSB........... DATA FRAME ................MSB][STOP]
---------------------------------------------------------------------------
PARAMETERS
  Name          :  Range  :  Default   :  Description
  ICLK_FREQ_HZ  :         :  50000000  :  input operating frequency (Hz)
  DATA FRAME    :  5 - 9  :  8         :  number of data bits (5 ~ 9 bits long)
  BAUD_RATE     :         :  115200    :  transmittion speed 9600 - 115200
  STOP_BIT      :  1 - 2  :  1         :  length of stop bit
  LSB           :  1 bit  :  0         :  determine serial data transfer format ("0" = LSB to MSB, "1" = MSB to LSB)
---------------------------------------------------------------------------
PINS
  clk - input clock signal
  nreset - input negative reset signal
  tx - tx input carries the output serial data
  tx_start - input (rising edge detect) which enable transmit data
  tx_data - transmit data inputs
  tx_done - done signal
  rx - rx input carries the input serial data
  rx_data - recive data outputs
  rx_done - done signal
---------------------------------------------------------------------------
*/

`timescale 1ns/1ps

module uart_rxtx #(
  parameter IN_CLK_HZ         = 42_000_000,  // input operating frequency (Hz)
  parameter DATA_FRAME        = 8,           // number of data bits (5 ~ 9 bits long)
  parameter BAUD_RATE         = 115200,       // transmitting speed 9600 - 115200
  parameter OVERSAMPLING_MODE = 16,          // bit offset or overlap
  parameter STOP_BIT          = 1,           // length of stop bit
  parameter LSB               = 0            // determine serial data transfer format ("0" = LSB to MSB, "1" = MSB to LSB)
) (
// common port
  input                   i_clk,       // input clock signal
  input                   i_rst,       // input reset signal
// interface port
  input                   i_rx,        // rx input carries the input serial data
// internal port
  output [DATA_FRAME-1:0] o_rx_data,   // receive data outputs
  output                  o_rx_done,    // done signal
  
  input [DATA_FRAME-1:0] tx_data,
  input tx_start,
  output tx,
  output tx_done,
 // output dbg
);

  wire w_tick;

  uart_rxtx_tx #(
    .DATA_FRAME (DATA_FRAME),
    .BAUD_RATE (BAUD_RATE),
    .OVERSAMPLING_MODE (OVERSAMPLING_MODE),
    .STOP_BIT (STOP_BIT),
    .LSB (LSB)
  ) uart_tx_wrapper (
    .clk (i_clk),
    .nreset (i_rst),
    .tx_data (tx_data),
    .tx_start (tx_start),
    .tx (tx),
    .tick (w_tick),
    .tx_done (tx_done),
    
  //  .dbg (dbg)
  );

  uart_rx #(
    .DATA_FRAME        (DATA_FRAME       ),
    .BAUD_RATE         (BAUD_RATE        ),
    .OVERSAMPLING_MODE (OVERSAMPLING_MODE),
    .STOP_BIT          (STOP_BIT         ),
    .LSB               (LSB              )  
  ) uart_rx_wrapper (
    .i_clk     (i_clk    ),
    .i_rst     (i_rst    ),
    .i_rx      (i_rx     ),
    .i_tick    (w_tick   ),
    .o_rx_data (o_rx_data),
    .o_rx_done (o_rx_done)
  );

  baud_rate_gen #(
    .BAUD_RATE         (BAUD_RATE        ),
    .OVERSAMPLING_MODE (OVERSAMPLING_MODE),
    .IN_CLK_HZ         (IN_CLK_HZ        )
  ) baud_rate_gen_wrapper (
    .i_clk  (i_clk ),
    .i_rst  (i_rst ),
    .o_tick (w_tick)
  );

endmodule


module baud_rate_gen #(
  parameter IN_CLK_HZ         = 50_000_000,
  parameter BAUD_RATE         = 115200,
  parameter OVERSAMPLING_MODE = 16
) (
  input      i_clk,
  input      i_rst,
  output reg o_tick
);

  localparam DIV_CNT_VAL   = (IN_CLK_HZ / (BAUD_RATE * OVERSAMPLING_MODE)) - 1;
  localparam DIV_CNT_WIDTH = $clog2(DIV_CNT_VAL);

  reg [DIV_CNT_WIDTH-1:0] r_count = 0;

  always @(posedge i_clk) begin
    if (i_rst) begin
      r_count <= 'b0;
      o_tick  <= 'b0;
    end else begin
      r_count <= r_count + 1;
      o_tick  <= 'b0;
      if (r_count == DIV_CNT_VAL) begin
        r_count <= 'b0;
        o_tick  <= 'b1;
      end
    end
  end

endmodule


module uart_rx #(
  parameter DATA_FRAME        = 8,      // number of data bits (5 ~ 9 bits long)
  parameter BAUD_RATE         = 115200, // transmitting speed 9600 - 115200
  parameter OVERSAMPLING_MODE = 16,     // bit offset or overlap
  parameter STOP_BIT          = 1,      // length of stop bit
  parameter LSB               = 0       // determine serial data transfer format ("0" = LSB to MSB, "1" = MSB to LSB)
) (
  input                       i_clk,     // input clock signal
  input                       i_rst,     // input reset signal
  input                       i_rx,      // rx input carries the input serial data
  input                       i_tick,    // input baud rate
  output reg [DATA_FRAME-1:0] o_rx_data, // receive data outputs
  output reg                  o_rx_done  // done signal
);
  localparam IDLE  = 4'b0001;
  localparam START = 4'b0010;
  localparam DATA  = 4'b0100;
  localparam STOP  = 4'b1000;

  localparam STOP_BIT_P1 = (STOP_BIT == 1.5) ? (OVERSAMPLING_MODE / 2) - 1 : 0;
  localparam STOP_BIT_P2 = (STOP_BIT == 1.5) ? 1 : STOP_BIT - 1;

//FSM variables
  reg [3:0] r_state, r_next;
  
  reg r_read_data;
  reg r_index_cnt_en;
  reg r_cnt_en;
//wire
  reg w_read_data;
  reg w_index_cnt_en;
  reg w_rx_done;
  reg w_cnt_en;

//Counter variables
  reg                    [3:0] r_cnt   = 'h0;
  reg [$clog2(DATA_FRAME)-1:0] r_index = 'h0;
  
  always @(posedge i_clk) begin
    if (i_rst)  r_state <= IDLE;
    else       r_state <= r_next;
  end

  always @* begin
    r_next = r_state;
    case(r_state)
      IDLE:  if (!i_rx)  r_next = START;
      START: begin
        if (r_cnt == 0) begin
          if (!i_rx) r_next = DATA;
          else      r_next = IDLE;      
        end
      end

      DATA: begin
        if (i_tick && r_cnt == 0) begin
          if(r_index == DATA_FRAME - 1) r_next = STOP;
        end
      end

      STOP: if (i_tick && r_cnt == STOP_BIT_P1 && r_index == STOP_BIT_P2) r_next = IDLE;
      default:  r_next = IDLE;
    endcase
  end

  always @* begin
    w_index_cnt_en = 'b0;
    w_rx_done      = 'b0;
    w_read_data    = 'b0;
    w_cnt_en       = 'b0;
    case (r_state)
      IDLE: w_cnt_en   = 'b0;
      START: w_cnt_en   = 'b1;
      DATA: begin
        w_cnt_en       = 'b1;
        w_read_data    = 'b1;
        w_index_cnt_en = 'b1;
      end
      STOP: begin
        w_cnt_en       = 'b1;
        w_read_data    = 'b0;
        w_rx_done      = 'b1;
        w_index_cnt_en = 'b1;
      end
    endcase
  end

  always @(posedge i_clk) begin
    if (i_rst) begin
      r_read_data    <= 'b0;
      r_cnt_en       <= 'b0;
      r_index_cnt_en <= 'b0;
      o_rx_done      <= 'b0;
    end else begin
      if (i_tick) begin
        r_read_data    <= w_read_data;
        r_index_cnt_en <= w_index_cnt_en;
      end
      r_cnt_en      <= w_cnt_en;
      o_rx_done     <= w_rx_done;
    end
  end

  always @(posedge i_clk) begin
    if (i_rst) o_rx_data <= 'b0;
    else if (r_read_data && i_tick && r_cnt == 'b0) begin
      case (LSB)
        1'b0:    o_rx_data <= {o_rx_data[DATA_FRAME-2:0], i_rx};
        1'b1:    o_rx_data <= {i_rx, o_rx_data[DATA_FRAME-1:1]};
        default: o_rx_data <= {o_rx_data[DATA_FRAME-2:0], i_rx};
      endcase
    end
  end

  //Counter
  always @(posedge i_clk) begin
    if (i_rst) r_cnt <= (OVERSAMPLING_MODE / 2) - 1;
    else if (r_cnt_en) begin
      if (i_tick) r_cnt <= r_cnt - 1;
    end 
    else r_cnt <= (OVERSAMPLING_MODE) - 1;
  end

  always @(posedge i_clk) begin
    if (i_rst) r_index <= 'b0;
    else if (r_index_cnt_en) begin
      if (i_tick && r_cnt == 'b0) r_index <= r_index + 1;
    end else r_index <= 'b0;
  end

endmodule


module uart_rxtx_tx #(
  parameter DATA_FRAME = 8,
  parameter BAUD_RATE = 115200,
  parameter OVERSAMPLING_MODE = 16,
  parameter STOP_BIT = 1,
  parameter LSB = 0
) (
  input clk,
  input nreset,
  input [DATA_FRAME-1:0] tx_data,
  input tx_start,
  input tick,
  output reg tx,
//  output dbg,
  output reg tx_done
);

  localparam IDLE = 4'b0001;
  localparam START = 4'b0010;
  localparam DATA = 4'b0100;
  localparam STOP = 4'b1000;

  localparam STOP_BIT_P1 = (STOP_BIT == 1.5) ? (OVERSAMPLING_MODE/2)-1 : 0;
  localparam STOP_BIT_P2 = (STOP_BIT == 1.5) ? 1 : STOP_BIT-1;

  //FSM variables
  reg [3:0] state = IDLE;
  reg [3:0] next  = IDLE;
  reg n_send_data;
  reg send_data;
  reg index_cnt_en;
  reg n_index_cnt_en;
  reg n_load;
  reg n_tx;
  reg load;
  reg n_tx_done;
  reg n_cnt_en;
  reg cnt_en;

  reg tx_regA;
  reg tx_regB;
  wire tx_r_edge;
  wire tx_re_start;

  always @(posedge clk) begin
    tx_regA <= tx_start;
    tx_regB <= tx_regA;
  end

  assign tx_re_start = tx_regA & ~tx_regB;
 // assign dbg = tick;

  //Counter variables
  reg [3:0] cnt = 'b0;
  reg [$clog2(DATA_FRAME)-1:0] index = 'b0;

  //P2S variables
  reg [DATA_FRAME-1:0] tx_buffer;

  always @(posedge clk) begin
    if (nreset)  state <= IDLE;
    else         state <= next;
  end

  always @* begin
    next = state;
    case(state)
      IDLE: if (tx_re_start) next = START;
      START: if (cnt == 0 && tick) next = DATA;
      DATA: if (tick && cnt == 0) begin
        if(index == DATA_FRAME-1) next = STOP;
      end
      STOP: if (tick && cnt == STOP_BIT_P1 && index == STOP_BIT_P2) next = IDLE;
      default: next = IDLE;
    endcase
  end

  always @* begin
    n_index_cnt_en = 'b0;
    n_tx_done = 'b0;
    n_send_data = 'b0;
    n_cnt_en = 'b0;
    n_load = 'b0;
    n_tx = 'b1;
    case (state)
      IDLE: ;
      START: begin
        n_cnt_en = 'b1;
        n_load = 'b1;
        n_tx = 'b0;
      end
      DATA: begin
        n_load = 'b0;
        n_cnt_en = 'b1;
        n_send_data = 'b1;
        n_index_cnt_en = 'b1;
        case (LSB)
          1'b1: n_tx = tx_buffer[0];
          1'b0: n_tx = tx_buffer[DATA_FRAME-1];
          default: n_tx = tx_buffer[0];
        endcase
      end
      STOP: begin
        n_load = 'b0;
        n_cnt_en = 'b1;
        n_send_data = 'b0;
        n_tx_done = 'b1;
        n_index_cnt_en = 'b1;
      end
    endcase
  end

  always @(posedge clk) begin
    if (nreset) begin
      send_data <= 'b0;
      cnt_en <= 'b0;
      tx_done <= 'b0;
      index_cnt_en <= 'b0;
      load <= 'b0;
      tx <= 1'b1;
    end else begin
      if (tick) send_data <= n_send_data;
      cnt_en <= n_cnt_en;
      tx_done <= n_tx_done;
      load <= n_load;
      tx <= n_tx;
      if (tick) index_cnt_en <= n_index_cnt_en;
    end
  end

  always @(posedge clk) begin
    if (nreset) tx_buffer <= 'h0;
    else begin
      if (load) tx_buffer <= tx_data;
      else if (tick && cnt == 'b0)
        case (LSB)
          1'b1: tx_buffer <= tx_buffer >> 1;
          1'b0: tx_buffer <= tx_buffer << 1;
          default: tx_buffer <= tx_buffer >> 1;
      endcase
    end
  end

  //Counter
  always @(posedge clk) begin
    if (nreset) cnt <= (OVERSAMPLING_MODE/2)-1;
    else if (cnt_en) begin
      if (tick) cnt <= cnt - 1;
    end else
      cnt <= (OVERSAMPLING_MODE)-1;
  end

  always @(posedge clk) begin
    if (nreset)   index <= 'b0;
    else if (index_cnt_en) begin
      if (tick && cnt == 'b0)   index <= index + 1;
    end else index <= 'b0;
  end

endmodule
