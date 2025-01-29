(* top *) module uart_to_7seg #(
  parameter IN_CLK_HZ         = 50_000_000, //osc = 48_000_000
  parameter DATA_FRAME        = 8,          // number of data bits 
  parameter BAUD_RATE         = 115200,     // transmitting speed
  parameter OVERSAMPLING_MODE = 16,         // bit offset or overlap 
  parameter STOP_BIT          = 1,          // length of stop bit 
  parameter LSB               = 1          // determine serial data transfer 1= MSB to LSB 
) (
// Main inputs
  (* iopad_external_pin, clkbuf_inhibit *) input i_clk,
  (* iopad_external_pin *) input i_por,
// OSC config outputs
  (* iopad_external_pin *) output OSC_CTRL_EN,
  (* iopad_external_pin *) output OSC_CTRL_MODE,
// PLL config outputs
  (* iopad_external_pin *) output PLL_CTRL_PD,
  (* iopad_external_pin *) output PLL_CTRL_CLK_SELECTION,
  (* iopad_external_pin *) output PLL_CTRL_BYPASS,
  (* iopad_external_pin *) output [5:0] PLL_CTRL_REFDIV,
  (* iopad_external_pin *) output [11:0] PLL_CTRL_FBDIV,
  (* iopad_external_pin *) output [2:0] PLL_CTRL_POSTDIV1, PLL_CTRL_POSTDIV2,
  
// Custom IO
  // UART
  (* iopad_external_pin *) output o_tx_start_oe,
  (* iopad_external_pin *) output o_tx,
  (* iopad_external_pin *) output o_tx_oe,

  (* iopad_external_pin *) input  i_rx,
  (* iopad_external_pin *) output o_rx_oe,
  
  // I2C
  (* iopad_external_pin *) output SDA_O,
  (* iopad_external_pin *) output SDA_OE,
  (* iopad_external_pin *) input  SDA_I,
  
  (* iopad_external_pin *) output SCL_O,
  (* iopad_external_pin *) output SCL_OE,
  
  // DBG
  (* iopad_external_pin *) output SAMP_CLK,
  (* iopad_external_pin *) output SAMP_CLK_OE,

  // camera
  (* iopad_external_pin *) input wire cmos_href_i, 
  (* iopad_external_pin *) output wire cmos_href_oe, 
  
  (* iopad_external_pin *) input wire cmos_vsync_i, 
  (* iopad_external_pin *) output wire cmos_vsync_oe, 
  
  (* iopad_external_pin *) input wire cmos_pclk_i,
  (* iopad_external_pin *) output wire cmos_pclk_oe,
  
  (* iopad_external_pin *) input wire [7:0] cmos_db_i,
  (* iopad_external_pin *) output wire [7:0] cmos_db_oe, 
  
  (* iopad_external_pin *) output wire cmos_rst_n_o, 
  (* iopad_external_pin *) output wire cmos_pwdn_o, 
  (* iopad_external_pin *) output wire cmos_xclk_o,
  );

assign OSC_CTRL_EN = 1'b1;
assign OSC_CTRL_MODE = 1'b1;
// PLL config Fout = Fin * 10
assign PLL_CTRL_PD = 1'b0;
assign PLL_CTRL_CLK_SELECTION = 1'b0;
assign PLL_CTRL_BYPASS = 1'b0;

assign PLL_CTRL_FBDIV = 44;
assign PLL_CTRL_REFDIV = 1;
assign PLL_CTRL_POSTDIV1 = 5;
assign PLL_CTRL_POSTDIV2 = 5;
  
assign o_rx_oe       = 1'b1;
assign o_tx_start_oe = 1'b1;

assign cmos_db_oe = 'hFF;
assign cmos_href_oe = 1'b1;
assign cmos_vsync_oe = 1'b1;
assign cmos_pclk_oe = 1'b0;
// Debug

//>>>>>>>>>reset buffer
  wire w_rst, w_tx_done;
  input_reset_buf impl_input_reset_buf (
    .i_clk        (i_clk),
    .i_por        (i_por),
    .o_rst        (w_rst)
  );

//>>>>>>>>>UART RX-TX
wire [DATA_FRAME-1:0]  w_rx_data;
wire uart_rx_done;
//wire uart_debug;
wire o_tx_done;
wire [DATA_FRAME-1:0]  data_for_tx;
wire tx_start_t;

//Synchronized rx to avoid metastability
reg  [1:0]  r_rx;
always @(posedge i_clk) begin;
  if(w_rst)  r_rx <= 2'b11;
  else       r_rx <= {r_rx[0], i_rx};
end

//wire [7:0]   i2c_data_deb;
//wire       	 i2c_done;

// IF recieves 0x55 or 0xAA 0x22 - hardware stucks (TODO Debug)
uart_rxtx #(
    .IN_CLK_HZ         (IN_CLK_HZ        ),
    .DATA_FRAME        (DATA_FRAME       ),
    .BAUD_RATE         (BAUD_RATE        ),
    .OVERSAMPLING_MODE (OVERSAMPLING_MODE),
    .STOP_BIT          (STOP_BIT         ),
    .LSB               (LSB              )
  ) impl_uart (
    .i_clk             (i_clk    ),
    .i_rst             (w_rst    ),
    .i_rx              (r_rx[1]  ),
    .o_rx_data         (w_rx_data),
    .o_rx_done         (uart_rx_done),
    
    .tx_data		 	(data_for_tx),
    .tx_start 	   		(tx_start_t), //Start
    .tx 			    (o_tx),
    .tx_done 			(o_tx_done),
   // .dbg (uart_debug)
  );
  


// Debug
//assign rx_done_o = uart_rx_done;
//assign SAMP_CLK = uart_debug;
//assign bus_o = w_rx_data;

//>>>>>>>>>Command parse FSM
reg          d_sent;
//reg          stream_on_sig;

wire [7:0]   i2c_command;
wire [7:0]   i2c_slave_address;
wire [7:0]   i2c_address;
wire [7:0]   i2c_data;

i2c_receiver i2c_test (
  .i_clk             (i_clk),
  .i_rst             (w_rst),
  .i_load            (uart_rx_done),
  .i_data            (w_rx_data),
 // .data_ready        (i2c_done),
 // .byte_debug        (i2c_data_deb),
  .i2c_sent          (d_sent),
 // .stream_on         (stream_on_sig),
  .command_o         (i2c_command),
  .slave_address_o   (i2c_slave_address),
  .address_o         (i2c_address),
  .data_o            (i2c_data)
);

//>>>>>>>>>I2C-master
localparam  DATA_WIDTH      =   8;
localparam  ADDRESS_WIDTH   =   7;

wire    [DATA_WIDTH-1:0]        i2c_master_mosi_data = i2c_data;
wire    [DATA_WIDTH-1:0]     	i2c_master_register_address = i2c_address;
wire    [ADDRESS_WIDTH-1:0]     i2c_master_device_address = i2c_slave_address;

reg    [DATA_WIDTH-1:0]        i2c_master_miso_data;
reg                            i2c_master_busy;

//wire i2cDebug;

i2c_master i2c(
            .clock                  (i_clk),
            .reset_n                (w_rst),
            .enable                 (d_sent), //1  - to start fsm
            .read_write             (d_sent), //1 - write operation, 0 - read
            .mosi_data              (i2c_master_mosi_data),
            .register_address       (i2c_master_register_address),
            .device_address         (i2c_master_device_address),

            .divider                ('d123), //Const
            .miso_data              (i2c_master_miso_data), //Readed data
            .busy                   (i2c_master_busy), //Active "1"
            
           .external_serial_data_i (SDA_I),
    		.external_serial_data (SDA_O),
    		.external_serial_data_oe (SDA_OE),
    		
    		.external_serial_clock (SCL_O),
    		.external_serial_clock_oe (SCL_OE),
    		//.dbg(i2cDebug)
);
defparam i2c.DATA_WIDTH = DATA_WIDTH;
defparam i2c.REGISTER_WIDTH = DATA_WIDTH;
defparam i2c.ADDRESS_WIDTH = ADDRESS_WIDTH;
  
// Debug
//assign dbg2 = d_sent;
//assign bus_o = i2c_slave_address;

//>>>>>>>>>Serialyser
camera_interface  camera_inter (
  .clk             (i_clk), 
  .rst_n           (w_rst),
  // camera io
  .cmos_pclk       (cmos_pclk_i),
  .cmos_href       (cmos_href_i),
  .cmos_vsync      (cmos_vsync_i),
  .cmos_db         (cmos_db_i),
  //.tx_uart_done    (o_tx_done),

  .cmos_rst_n      (cmos_rst_n_o), 
  .cmos_pwdn       (cmos_pwdn_o), 
  //.cmos_xclk       (cmos_xclk_o),
  .byte_for_uart   (data_for_tx),
  .send_ready      (tx_start_t)
);

 assign SAMP_CLK = tx_start_t;
 assign SAMP_CLK_OE = 0;
 assign o_tx_oe = 0;
 
 sampleClkGen pclk_gen (
     .clk		(i_clk),
     .en		('b1),
     .nreset	(!w_rst),
	 .data_in 	('d8), //2 = 12MHz, d16 = 500kHz
	 .sampClk 	(cmos_xclk_o)
 );
 
endmodule