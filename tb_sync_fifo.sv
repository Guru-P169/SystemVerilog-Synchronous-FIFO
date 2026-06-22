`timescale 1ns/1ps

module tb_sync_fifo;

logic clk;
logic rst_n;
logic wr_en;
logic rd_en;
logic [31:0] wr_data;
logic [31:0] rd_data;
logic full;
logic almost_full;
logic empty;
logic almost_empty;

sync_fifo dut (
    .clk(clk),
    .rst_n(rst_n),
    .wr_en(wr_en),
    .wr_data(wr_data),
    .rd_en(rd_en),
    .full(full),
    .almost_full(almost_full),
    .rd_data(rd_data),
    .empty(empty),
    .almost_empty(almost_empty)
);

always #5 clk = ~clk;

initial begin
    clk = 0;
    rst_n = 0;
    wr_en = 0;
    rd_en = 0;
    wr_data = 0;

    #20;
    rst_n = 1;

    // Write 3 values
    repeat (3) begin
        @(posedge clk);
        wr_en = 1;
        wr_data = wr_data + 1;
    end

    @(posedge clk);
    wr_en = 0;

    // Read 3 values
    repeat (3) begin
        @(posedge clk);
        rd_en = 1;
    end

    @(posedge clk);
    rd_en = 0;

    #20;
    $finish;
end

endmodule  