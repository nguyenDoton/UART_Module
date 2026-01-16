module uart_top 
#(
    parameter sysclk = 50000000,
    parameter low_baudrate = 4800
)
(   //Baud generator
    input  wire       clk,
    input  wire       rst,
    input  wire [2:0] sel,        
    
    // TX 
    input  wire [7:0] tx_data_in,
    input  wire       tx_start,
    output wire       tx_out,     
    output wire       tx_done,    
    
    // RX 
    input  wire       rx_in,      
    output wire       rx_done,    
    output wire       flag,       
    output wire [7:0] rx_data_out 
);

    
    wire w_baud_tick;

   
    baud_generator #(
        .sysclk(sysclk), 
        .low_baudrate(low_baudrate)
    ) baud_gen_inst (
        .clk(clk),
        .rst(rst),
        .sel(sel),
        .baud_tick(w_baud_tick)
    );

   
    Tx tx_inst (
        .clk(clk),
        .rst(rst),
        .baud_tick(w_baud_tick), 
        .tx_start(tx_start),
        .transmit_data(tx_data_in),
        .tx_stop(tx_done),       
        .tx_out(tx_out)
    );

   
    Rx #(
        .sysclk(sysclk), 
        .low_baudrate(low_baudrate)
    ) rx_inst (
        .clk(clk),
        .rst(rst),
        .sel(sel),              
        .rx_in(rx_in),
        .rx_done(rx_done),
        .flag(flag),
        .data_received(rx_data_out)
    );

endmodule



module Tx(
    input [7:0] transmit_data,
    input baud_tick,
    input clk,
    input rst,
    input tx_start,
    output reg tx_stop,
    output reg tx_out
);

    reg [7:0] data_reg;
    reg [3:0] bit_index;
    reg [3:0] state;

    always@(posedge clk or posedge rst) begin
        if(rst) begin
            state <= 0;
            data_reg <= 0;
            tx_out <= 1;
            tx_stop <= 0;
            bit_index <= 0;
        end else begin 
            tx_stop <= 0;

            case(state)
                0: begin //idle
                    bit_index <= 0;
                    tx_out <= 1;
                    if(tx_start == 1) begin
                        state <= 1;
                        data_reg <= transmit_data;
                    end else begin 
                        state <= state;
                    end
                end
                
                1: begin  //start
                    tx_out <= 0;
                    if(baud_tick == 1) begin
                        state <= 2;
                    end else begin
                        state <= state;
                    end
                end

                2: begin //data tranmission
                    tx_out <= data_reg[bit_index];
                    if (baud_tick == 1) begin
                        if(bit_index < 7) begin
                            bit_index <= bit_index + 1;
                        end else begin
                            bit_index <= 0;
                            state <= 3;
                        end
                    end else begin
                        state <= state;
                    end
                end

                3: begin //parity
                    tx_out <= ^data_reg;
                    if(baud_tick == 1) begin
                        state <= 4;
                    end else begin
                        state <= state;
                    end
                end

                4: begin //stop
                    tx_out <= 1;
                    if(baud_tick == 1) begin
                        tx_stop <= 1;
                        state <= 0;
                    end else begin
                        state <= state;
                    end
                end
                
                default: state <= 0;
            endcase
        end
    end

endmodule

module Rx #(
    parameter sysclk = 50000000,
    parameter low_baudrate = 4800
) (
    input  wire       rx_in,
    input  wire       clk,
    input  wire       rst,
    input  wire [2:0] sel,
    output reg        rx_done,
    output reg        flag,
    output reg  [7:0] data_received
);

    localparam base_baudrate = sysclk / low_baudrate;

    reg [2:0]   state;
    reg [7:0]   data_reg;
    reg [2:0]   bit_index;
    reg [13:0]  clk_count;
    wire [13:0] count_per_tick;

    assign count_per_tick = base_baudrate >> sel;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state         <= 0;
            bit_index     <= 0;
            data_reg      <= 0;
            rx_done       <= 0;
            data_received <= 0;
            flag          <= 0;
            clk_count     <= 0;
        end else begin
            rx_done <= 0;

            case (state)
                0: begin
                    clk_count <= 0;
                    bit_index <= 0;
                    if (rx_in == 0) begin
                        state <= 1;
                    end
                end

                1: begin
                    if (clk_count == (count_per_tick >> 1)) begin
                        if (rx_in == 0) begin
                            clk_count <= 0;
                            state     <= 2;
                        end else begin
                            state <= 0;
                        end
                    end else begin
                        clk_count <= clk_count + 1;
                    end
                end

                2: begin
                    if (clk_count == count_per_tick) begin
                        clk_count <= 0;
                        data_reg[bit_index] <= rx_in;
                        
                        if (bit_index < 7) begin
                            bit_index <= bit_index + 1;
                        end else begin
                            bit_index <= 0;
                            state     <= 3;
                        end
                    end else begin
                        clk_count <= clk_count + 1;
                    end
                end

                3: begin
                    if (clk_count == count_per_tick) begin
                        clk_count <= 0;
                        flag      <= rx_in ^ (^data_reg);
                        state     <= 4;
                    end else begin
                        clk_count <= clk_count + 1;
                    end
                end

                4: begin
                    if (clk_count == count_per_tick) begin
                        rx_done       <= 1;
                        data_received <= data_reg;
                        state         <= 0;
                    end else begin
                        clk_count <= clk_count + 1;
                    end
                end

                default: state <= 0;
            endcase
        end
    end

endmodule





module baud_generator
#(parameter sysclk = 50000000,
 parameter low_baudrate = 4800)
(
 input clk,
 input rst,
 input [2:0] sel,
 output reg baud_tick
);
 wire [13:0] count_per_tick;
 reg [13:0] count;
 integer base_baudrate = (sysclk / low_baudrate);
 assign count_per_tick = base_baudrate >> sel;

 always@(posedge clk or posedge rst) begin
 
    if( rst) begin
       count <= 1'b0;
       baud_tick <= 1'b0;
   end else begin
       if(count < count_per_tick-1) begin
            count <= count + 1;
            baud_tick <= 0;
       end else begin
            count <= 0;
            baud_tick <= 1'b1;
       end
   end
 end
endmodule
