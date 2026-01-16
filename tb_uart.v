`timescale 1ns/1ps


module uart_testbench;
    parameter FCLK = 500_000_000; 
    parameter CLK_PERIOD = 1000000000 / FCLK; 

    localparam TEST_DATA = 8'h55; 

    reg clk;
    reg rst_n;
    reg [7:0] data_in_tx;
    reg data_in_ready;
    reg [2:0] baud_tx_sel;
    reg parity_enable;

    wire txd_tx;
    reg rxd_rx; 

    wire [7:0] data_out_rx;
    wire data_out_ready_rx;
    
    tx_module #(.fclk(FCLK)) uut_tx (
        .txd(txd_tx),
        .clk(clk),
        .rst_n(rst_n),
        .data_in(data_in_tx),
        .data_in_ready(data_in_ready),
        .baud(baud_tx_sel),
        .parity(parity_enable)
    );

    rx_module #(.fclk(FCLK)) uut_rx (
        .rxd(rxd_rx),
        .clk(clk),
        .rst_n(rst_n),
        .data_out(data_out_rx),
        .data_out_ready(data_out_ready_rx),
        .baud(baud_tx_sel)
    );

    always @(txd_tx) begin
        rxd_rx = txd_tx;
    end

    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    initial begin
        $display("--- Bắt đầu Testbench UART ---");
        rst_n = 1'b0;       
        data_in_tx = 8'd0;   
        data_in_ready = 1'b0; 
        parity_enable = 1'b1;

        baud_tx_sel = 3'd5; 
        
        # (CLK_PERIOD * 10);

        rst_n = 1'b1; 
        $display("Thoát Reset. Thiết lập Baud Rate 115200.");
        
        # (CLK_PERIOD * 10);
        
        data_in_tx = TEST_DATA;
        data_in_ready = 1'b1;
        
        # (CLK_PERIOD * 2); 
        data_in_ready = 1'b0;
        $display("TX: Bắt đầu truyền dữ liệu 0x%h...", TEST_DATA);

        @(posedge data_out_ready_rx) begin
            if (data_out_ready_rx && (data_out_rx === TEST_DATA)) begin
                $display("RX: Dữ liệu nhận thành công! (0x%h)", data_out_rx);
                $display("--- TEST PASSED ---");
            end else begin
                $display("RX: LỖI nhận dữ liệu. Nhận được: 0x%h", data_out_rx);
                $display("RX Ready: %b", data_out_ready_rx);
                $display("--- TEST FAILED ---");
            end
        end
        # (100000);

        $finish;
    end

endmodule
