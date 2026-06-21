// mm2s_channel.v
module mm2s_channel #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter BURST_MAX  = 8
)(
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire [31:0]            mm2s_ctrl,
    input  wire [ADDR_WIDTH-1:0]  src_addr,
    input  wire [31:0]            mm2s_len,
    output wire [31:0]            mm2s_status,
    output wire                   mm2s_done,
    output wire                   m_axi_arvalid,
    output wire [ADDR_WIDTH-1:0]  m_axi_araddr,
    output wire [7:0]             m_axi_arlen,
    output wire [2:0]             m_axi_arsize,
    output wire [1:0]             m_axi_arburst,
    input  wire                   m_axi_arready,
    input  wire                   m_axi_rvalid,
    input  wire [DATA_WIDTH-1:0]  m_axi_rdata,
    input  wire                   m_axi_rlast,
    output wire                   m_axi_rready,
    output wire [DATA_WIDTH-1:0]  m_axis_tdata,
    output wire                   m_axis_tvalid,
    input  wire                   m_axis_tready,
    output wire                   m_axis_tlast
);

    wire                    fifo_wr_en;
    wire [DATA_WIDTH-1:0]   fifo_wdata;
    wire                    fifo_rd_en;
    wire                    fifo_empty;
    wire [4:0]              fifo_count;
    
    wire                    fifo_full = (fifo_count >= 16);

    mm2s_control_fsm #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .BURST_MAX(BURST_MAX)
    ) u_mm2s_fsm (
        .clk(clk), .rst_n(rst_n),
        .mm2s_ctrl(mm2s_ctrl), .src_addr(src_addr), .mm2s_len(mm2s_len),
        .m_axi_arvalid(m_axi_arvalid), .m_axi_araddr(m_axi_araddr), .m_axi_arlen(m_axi_arlen),
        .m_axi_arsize(m_axi_arsize), .m_axi_arburst(m_axi_arburst), .m_axi_arready(m_axi_arready),
        .m_axi_rvalid(m_axi_rvalid), .m_axi_rdata(m_axi_rdata), .m_axi_rlast(m_axi_rlast), .m_axi_rready(m_axi_rready),
        .fifo_wr_en(fifo_wr_en), .fifo_wdata(fifo_wdata), .fifo_full(fifo_full), 
        .mm2s_status(mm2s_status), .mm2s_done(mm2s_done)
    );

    mm2s_datapath #(
        .DATA_WIDTH(DATA_WIDTH),
        .FIFO_DEPTH(16)
    ) u_mm2s_buffer (
        .clk(clk), .rst_n(rst_n),
        .s_axis_tdata(fifo_wdata), .s_axis_tvalid(fifo_wr_en), .s_axis_tready(), .s_axis_tlast(m_axi_rlast && m_axi_rvalid),
        .fifo_rdata(m_axis_tdata), .fifo_rd_en(fifo_rd_en), .fifo_empty(fifo_empty), .fifo_count(fifo_count)
    );

    assign m_axis_tvalid = !fifo_empty;
    assign fifo_rd_en    = m_axis_tvalid && m_axis_tready;
    assign m_axis_tlast  = fifo_empty && mm2s_done; 

endmodule
