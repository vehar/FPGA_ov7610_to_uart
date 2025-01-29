
module camera_interface(
  input           clk, 
  input           rst_n,
  // camera io
  input           cmos_pclk,
  input           cmos_href,
  input           cmos_vsync,
  input [7:0]     cmos_db,
  output          cmos_rst_n, 
  output          cmos_pwdn, 
  output          cmos_xclk,
  output [7:0]    byte_for_uart,
  output          send_ready

);
  //FSM state declarations
  typedef enum 
  {
    IDLE           = 0,
    VSYNC_FEDGE    = 1,
    BYTE1          = 2,
    BYTE2          = 3,
    SEND_TO_UART   = 4
  } camera_state_type;

  camera_state_type  state_q = IDLE; 
  
  reg [7:0]          pixel_q;
  //buffer for all inputs coming from the camera
  reg                pclk_1;
  reg                pclk_2;
  reg                href_1;
  reg                href_2;
  wire                vsync_1;
  wire                vsync_2;
     
  //register operations
  always @(posedge clk) begin

      pclk_2         <= pclk_1;
      pclk_1         <= cmos_pclk;
      href_2         <= href_1;
      href_1         <= cmos_href;
      vsync_2        <= vsync_1;
      vsync_1        <= cmos_vsync;
      
    case(state_q) 
    ///////////////Begin: Retrieving Pixel Data from Camera/////////////////
 	  IDLE: begin
          state_q=VSYNC_FEDGE; 
          send_ready     = 'b0;
        end
   
      VSYNC_FEDGE: begin
      send_ready     = 'b0;
        if(vsync_1=='b0 && vsync_2=='b1) begin 
          state_q=BYTE1; //vsync falling edge means new frame is incoming
        end
      end
      
      BYTE1: begin
        send_ready     = 'b0;
        if(pclk_1=='b1 && pclk_2=='b0 && href_1=='b1 && href_2=='b1) begin //rising edge of pclk means new pixel data(first byte of 16-bit pixel RGB565) is available at output
          pixel_q=cmos_db;
          state_q=SEND_TO_UART;
        end else if(vsync_1=='b1 && vsync_2=='b1) begin
          state_q=VSYNC_FEDGE;
        end
      end
       
        SEND_TO_UART: begin 
           byte_for_uart  = pixel_q;
           send_ready     = 'b1;
           state_q=BYTE1;
        end
        default: state_q=IDLE;
    endcase    
  end
  
//  always @(posedge clk) 
//    cmos_xclk <= ~cmos_xclk;

  assign cmos_pwdn=0; 
  assign cmos_rst_n=1;
  

endmodule
