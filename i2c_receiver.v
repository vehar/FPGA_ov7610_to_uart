// Custom Module

module i2c_receiver(
  input        i_clk,           // input clock signal
  input        i_rst,           // input reset signal
  input        i_load,          // load signal
  input  [7:0] i_data,          // input data bus
//  output reg   data_ready,      // 1 if ready to send to i2c
//  output [7:0] byte_debug,      // DEBUG output
  output       i2c_sent,
  //output       stream_on,
  
  output [7:0] command_o,
  output [7:0] slave_address_o,
  output [7:0] address_o,
  output [7:0] data_o
);
  
  // states
  typedef enum 
  {
    IDLE           = 0,
    COMMAND        = 1,
    SLAVE_ADDRESS  = 2,
    ADDRESS        = 3,
    DATA           = 4,
    SEND           = 5,
    WAITING_STATE  = 6
  } state_type;
  
  // more commands can be addedd

  localparam BEGIN_STREAM = 'b01;
  localparam END_STREAM = 'b10;


  // temporary register to save received data
  reg [7:0] r_data;
  
  // main registers 
  reg [7:0] command;
  reg [7:0] slave_address;
  reg [7:0] address;
  reg [7:0] data;
    
  // fsm variables
  state_type r_state, r_next, r_waiting_next;

  // buffered input data
  always @(posedge i_clk) begin
    if (i_rst) begin
      r_data <= 'h0;
    end else if (i_load) begin
      r_data <= i_data;
    end
  end
  
  // starting state
  always @(posedge i_clk) begin
    if (i_rst) begin
      r_state <= IDLE;
    end else begin
      r_state <= r_next;
    end
  end

  
  // change state
  always @(posedge i_clk) begin
    r_next = r_state;
    case (r_state)
      IDLE: begin
        if (i_load) begin
          r_next <= COMMAND;
        end
      end
      
      COMMAND: begin
        if( !i_load) begin
          r_next <= WAITING_STATE;
          r_waiting_next <= SLAVE_ADDRESS;
        end
      end
      
      SLAVE_ADDRESS: begin
        if (!i_load) begin     
          // some commands may not require all 3 registers so jump diretly on SEND 
          case (command)
            BEGIN_STREAM,
            END_STREAM: begin
              // SEND state should not be followed by WAITING_STATE
              r_next <= SEND;
            end

            default: begin
              r_next <= WAITING_STATE;
              r_waiting_next <= ADDRESS;
            end
          endcase 
         
        end
      end
      
      ADDRESS: begin
        if ( !i_load) begin
          r_next <= WAITING_STATE;
          r_waiting_next <= DATA;
        end
      end
      
      DATA: begin
        if ( !i_load) begin
          // SEND state should not be followed by WAITING_STATE
          r_next <= SEND;
        end
      end
      
      WAITING_STATE: begin
        if (i_load) begin
          r_next <= r_waiting_next;
        end
      end
      
      SEND: begin
        r_next <= IDLE;
      end
    endcase
  end

  // choose register to save data to based on the current state
  always @(posedge i_clk) begin
    if (i_rst) begin
      command <= 'h0;
      slave_address <= 'h0;
      address <= 'h0;
      data <= 'h0;
     // data_ready <= 'b0;
      i2c_sent <= 'b0;
      //stream_on <= 'b0;
    end else begin
      case (r_state)
        COMMAND: begin
          command <= r_data;
      //    byte_debug  <= command;
      //    data_ready <= 'b1;
          i2c_sent <= 'b0;
          
         /* case (command)
            BEGIN_STREAM: begin
              stream_on <= 'b1;
            end
            
            END_STREAM: begin
              stream_on <= 'b0;
            end
          endcase*/
        end
        
        SLAVE_ADDRESS: begin
          slave_address <= r_data;
    //      byte_debug <= slave_address;
    //      data_ready <= 'b1;
          i2c_sent <= 'b0;
        end
        
        ADDRESS: begin
          address <= r_data;
    //      byte_debug <= address;
    //      data_ready <= 'b1;
          i2c_sent <= 'b0;
        end
        
        DATA: begin
          data <= r_data;
  //        byte_debug <= data;
   //       data_ready <= 'b1;
          i2c_sent <= 'b0;
        end
        
        //! TODO: implement sending data via i2c
        
        SEND: begin
          i2c_sent <= 'b1;
          
          command_o <= command;
          slave_address_o <= slave_address;
          address_o <= address;
          data_o <= data;
        end 

        default: begin
   //       data_ready <= 'b0;
          i2c_sent <= 'b0;
        end
      endcase
    end
  end
endmodule

