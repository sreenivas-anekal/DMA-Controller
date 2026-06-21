// mm2s_datapath.v
module mm2s_datapath #(
    parameter DATA_WIDTH = 32,
    parameter FIFO_DEPTH = 16
)(
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire [DATA_WIDTH-1:0]  s_axis_tdata,
    input  wire                   s_axis_tvalid,
    output reg                    s_axis_tready,
    input  wire                   s_axis_tlast,
    output reg  [DATA_WIDTH-1:0]  fifo_rdata,
    input  wire                   fifo_rd_en,
    output reg                    fifo_empty,
    output reg  [4:0]             fifo_count
);
    reg [DATA_WIDTH-1:0] mem [0:FIFO_DEPTH-1];
    reg [4:0] wr_ptr, rd_ptr;
    reg [4:0] count;

    wire write_en = s_axis_tvalid && s_axis_tready;
    wire read_en  = fifo_rd_en && (count > 0);

    always @(posedge clk) begin
        if (!rst_n) begin
            wr_ptr <= 0; rd_ptr <= 0; count <= 0; fifo_rdata <= 0;
        end else begin
            if (write_en) begin
                mem[wr_ptr] <= s_axis_tdata;
                wr_ptr      <= wr_ptr + 1;
            end
            if (read_en) begin
                fifo_rdata <= mem[rd_ptr];
                rd_ptr     <= rd_ptr + 1;
            end
            case ({write_en, read_en})
                2'b10: count <= count + 1;   
                2'b01: count <= count - 1;   
                2'b11: count <= count;       
                default: ;
            endcase
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            fifo_empty <= 1; fifo_count <= 0; s_axis_tready <= 1;
        end else begin
            fifo_empty    <= (count == 0);
            fifo_count    <= count;
            s_axis_tready <= (count < FIFO_DEPTH);
        end
    end
endmodule
