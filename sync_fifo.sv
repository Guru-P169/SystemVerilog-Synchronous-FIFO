`timescale 1ns / 1ps

module sync_fifo #(
    parameter int DATA_WIDTH =32,
    parameter int ADDR_WIDTH =4,
    parameter int ALMOST_FULL_THRESH =12,
    parameter int ALMOST_EMPTY_THRESH =4
)(
    input logic clk,
    input logic rst_n,
    input logic wr_en,
    input logic [DATA_WIDTH-1:0] wr_data,
    input logic rd_en,
    output logic full,
    output logic almost_full,
    output logic [DATA_WIDTH-1:0] rd_data,
    output logic empty,
    output logic almost_empty
);
localparam int DEPTH = 1<<ADDR_WIDTH;

typedef logic [ADDR_WIDTH:0] ptr_t;

logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];
ptr_t wr_ptr;
ptr_t rd_ptr;

logic do_write;
logic do_read;
 
ptr_t full_count;

always_comb begin
    do_write =wr_en && (!full || (rd_en && !empty));
    do_read = rd_en && (!empty || (wr_en && !full));
end


always_ff @(posedge clk) begin
    if(!rst_n) begin
        wr_ptr <='0;
    end else if(do_write) begin
        wr_ptr <= wr_ptr +1'b1;
        end
end

always_ff @(posedge clk) begin
     if (!rst_n) begin
        rd_ptr <= '0;
    end else if (do_read) begin
        rd_ptr <= rd_ptr + 1'b1;
    end
end


always_ff @(posedge clk) begin
    if(do_write)begin
        mem[wr_ptr[ADDR_WIDTH-1:0]] <= wr_data;
    end
end


always_ff @(posedge clk) begin
    if(!rst_n)begin
        rd_data <= '0;
    end else if(do_read) begin
        rd_data <=mem[rd_ptr[ADDR_WIDTH-1:0]];
    end
end


always_comb begin

    full_count = wr_ptr-rd_ptr;

    empty =(wr_ptr==rd_ptr);

    full =(wr_ptr[ADDR_WIDTH]!=rd_ptr[ADDR_WIDTH]) && (wr_ptr[ADDR_WIDTH-1:0]==rd_ptr[ADDR_WIDTH-1:0]);

    almost_full =(full_count >= ALMOST_FULL_THRESH) && !full;
    almost_empty = (full_count <= ALMOST_EMPTY_THRESH) && !empty;

end




`ifndef SYNTHESIS
property no_overflow;
    @(posedge clk) disable iff (!rst_n)
    (full && wr_en && !rd_en) |-> 1'b0;
endproperty
assert_no_overflow: assert property (no_overflow)
    else $error("FIFO no_overflow: Writing to a full FIFO!");

property no_underflow;
    @(posedge clk) disable iff (!rst_n)
    (empty && rd_en && !wr_en) |-> 1'b0;
endproperty
assert_no_underflow: assert property (no_underflow) 
        else $error("FIFO Underflow: Reading from an empty FIFO!");
    `endif


endmodule