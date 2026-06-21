// mm2s_control_fsm.v
module mm2s_control_fsm #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter BURST_MAX  = 8
)(
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire [31:0]            mm2s_ctrl,     
    input  wire [ADDR_WIDTH-1:0]  src_addr,      
    input  wire [31:0]            mm2s_len,      
    output reg                    m_axi_arvalid,
    output reg  [ADDR_WIDTH-1:0]  m_axi_araddr,
    output reg  [7:0]             m_axi_arlen,
    output wire [2:0]             m_axi_arsize,
    output wire [1:0]             m_axi_arburst,
    input  wire                   m_axi_arready,
    input  wire                   m_axi_rvalid,
    input  wire [DATA_WIDTH-1:0]  m_axi_rdata,
    input  wire                   m_axi_rlast,
    output reg                    m_axi_rready,
    output reg                    fifo_wr_en,
    output reg  [DATA_WIDTH-1:0]  fifo_wdata,
    input  wire                   fifo_full,
    output reg  [31:0]            mm2s_status,   
    output reg                    mm2s_done
);

    assign m_axi_arsize  = 3'b010; 
    assign m_axi_arburst = 2'b01;  

    localparam [2:0] IDLE       = 3'd0,
                     READ_ADDR  = 3'd1,
                     READ_DATA  = 3'd2,
                     DONE       = 3'd3;

    reg [2:0] state;
    reg [ADDR_WIDTH-1:0] addr_reg;
    reg [31:0]           bytes_left;
    reg [7:0]            burst_beats;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= IDLE;
            m_axi_arvalid <= 1'b0;
            m_axi_araddr  <= 0;
            m_axi_arlen   <= 0;
            m_axi_rready  <= 1'b0;
            fifo_wr_en    <= 1'b0;
            fifo_wdata    <= 0;
            mm2s_done     <= 1'b0;
            mm2s_status   <= 0;
            bytes_left    <= 0;
            burst_beats   <= 0;
            addr_reg      <= 0;
        end else begin
            mm2s_done  <= 1'b0; 
            fifo_wr_en <= 1'b0;

            case (state)
                IDLE: begin
                    m_axi_arvalid <= 1'b0;
                    m_axi_rready  <= 1'b0;
                    if (mm2s_ctrl[0] && mm2s_len != 0) begin
                        addr_reg    <= src_addr;
                        bytes_left  <= mm2s_len;
                        mm2s_status <= 32'd1; 
                        state       <= READ_ADDR;
                    end
                end

                READ_ADDR: begin
                    if (!fifo_full) begin
                        m_axi_arvalid <= 1'b1;
                        m_axi_araddr  <= addr_reg;
                        
                        if (bytes_left >= (BURST_MAX * 4)) begin
                            m_axi_arlen <= BURST_MAX - 1;
                            burst_beats <= BURST_MAX;
                        end else begin
                            m_axi_arlen <= (bytes_left >> 2) - 1;
                            burst_beats <= bytes_left >> 2;
                        end

                        if (m_axi_arvalid && m_axi_arready) begin
                            m_axi_arvalid <= 1'b0;
                            m_axi_rready  <= 1'b1;
                            state         <= READ_DATA;
                        end
                    end
                end

                READ_DATA: begin
                    if (m_axi_rvalid && m_axi_rready) begin
                        fifo_wr_en <= 1'b1;
                        fifo_wdata <= m_axi_rdata; 
                        bytes_left <= bytes_left - 4;
                        addr_reg   <= addr_reg + 4;

                        if (m_axi_rlast) begin
                            m_axi_rready <= 1'b0;
                            if (bytes_left <= 4) begin 
                                state <= DONE;
                            end else begin
                                state <= READ_ADDR; 
                            end
                        end
                    end
                end

                DONE: begin
                    mm2s_done   <= 1'b1;
                    mm2s_status <= 32'd2; 
                    state       <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule
