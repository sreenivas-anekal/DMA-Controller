module axi4_lite_slave (
    // Clock & Reset
    input  wire        clk,
    input  wire        rst_n,

    // ── Write Address Channel (AW) 
    input  wire [31:0] s_axi_awaddr,
    input  wire        s_axi_awvalid,
    output reg         s_axi_awready,

    // ── Write Data Channel (W) 
    input  wire [31:0] s_axi_wdata,
    input  wire [ 3:0] s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output reg         s_axi_wready,

    // ── Write Response Channel (B)
    output reg  [ 1:0] s_axi_bresp,
    output reg         s_axi_bvalid,
    input  wire        s_axi_bready,

    // ── Read Address Channel (AR)
    input  wire [31:0] s_axi_araddr,
    input  wire        s_axi_arvalid,
    output reg         s_axi_arready,

    // ── Read Data Channel (R)
    output reg  [31:0] s_axi_rdata,
    output reg  [ 1:0] s_axi_rresp,
    output reg         s_axi_rvalid,
    input  wire        s_axi_rready,

    // ── Register outputs to DMA channels 
    output wire [31:0] mm2s_src_addr,
    output wire [31:0] mm2s_length,
    output wire [31:0] mm2s_control,
    output wire [31:0] s2mm_dst_addr,
    output wire [31:0] s2mm_length,
    output wire [31:0] s2mm_control,

    // ── Status inputs from DMA channels 
    input  wire [31:0] mm2s_status,
    input  wire [31:0] s2mm_status
);

// Parameters — Write FSM states
localparam WR_IDLE = 2'd0;
localparam WR_ADDR = 2'd1;
localparam WR_DATA = 2'd2;
localparam WR_RESP = 2'd3;

// Parameters — Read FSM states
localparam RD_IDLE = 2'd0;
localparam RD_ADDR = 2'd1;
localparam RD_DATA = 2'd2;

// Internal registers
reg [31:0] reg_mm2s_src_addr;
reg [31:0] reg_mm2s_length;
reg [31:0] reg_mm2s_control;
reg [31:0] reg_s2mm_dst_addr;
reg [31:0] reg_s2mm_length;
reg [31:0] reg_s2mm_control;

// FSM state registers
reg [1:0] wr_state;
reg [1:0] rd_state;

// Address capture registers
reg [4:2] aw_addr_reg;
reg [4:2] ar_addr_reg;

// Write validity flags
reg wr_addr_valid;
reg rd_addr_valid;

// ── Auto-clear flags (written and cleared inside the SAME always block only)
// Single driver — no multi-driver conflict, deterministic NBA ordering.
// Cycle N  : task writes reg_*_control, sets flag (task NBA wins — later in source)
// Cycle N+1: flag-check fires at top of else, clears reg_*_control (only NBA in block)
reg mm2s_ctrl_written;
reg s2mm_ctrl_written;

// Output wiring — register file → DMA channels
assign mm2s_src_addr = reg_mm2s_src_addr;
assign mm2s_length   = reg_mm2s_length;
assign mm2s_control  = reg_mm2s_control;
assign s2mm_dst_addr = reg_s2mm_dst_addr;
assign s2mm_length   = reg_s2mm_length;
assign s2mm_control  = reg_s2mm_control;

// ── WRITE PATH FSM (single always block — sole driver of all reg_* and flags)
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        wr_state          <= WR_IDLE;
        s_axi_awready     <= 1'b0;
        s_axi_wready      <= 1'b0;
        s_axi_bvalid      <= 1'b0;
        s_axi_bresp       <= 2'b00;
        aw_addr_reg       <= 3'd0;
        wr_addr_valid     <= 1'b0;
        rd_addr_valid     <= 1'b0;
        reg_mm2s_src_addr <= 32'h0;
        reg_mm2s_length   <= 32'h0;
        reg_mm2s_control  <= 32'h0;
        reg_s2mm_dst_addr <= 32'h0;
        reg_s2mm_length   <= 32'h0;
        reg_s2mm_control  <= 32'h0;
        mm2s_ctrl_written <= 1'b0;   // reset flags here — single driver
        s2mm_ctrl_written <= 1'b0;
    end else begin

        // ── Auto-clear — checked at the TOP of the else clause.
        // On the write cycle   : flag is still 0, so this block is skipped.
        //                        Task fires below, writes control, sets flag.
        //                        Task NBA is LATER in source → wins for this cycle.
        // On the cycle after   : flag is 1, this block fires and clears control.
        //                        FSM is in WR_RESP, task is not called, no conflict.
        if (mm2s_ctrl_written) begin
            reg_mm2s_control  <= 32'h0;
            mm2s_ctrl_written <= 1'b0;
        end
        if (s2mm_ctrl_written) begin
            reg_s2mm_control  <= 32'h0;
            s2mm_ctrl_written <= 1'b0;
        end

        // ── Write FSM
        case (wr_state)
            WR_IDLE: begin
                s_axi_awready <= 1'b1;
                s_axi_wready  <= 1'b1;
                if (s_axi_awvalid) begin
                    aw_addr_reg   <= s_axi_awaddr[4:2];
                    wr_addr_valid <= (s_axi_awaddr[31:5] == 27'd0);
                    s_axi_awready <= 1'b0;
                    if (s_axi_wvalid) begin
                        s_axi_wready <= 1'b0;
                        wr_state     <= WR_RESP;
                        do_register_write(s_axi_awaddr[4:2],
                                          s_axi_wdata,
                                          s_axi_wstrb,
                                          (s_axi_awaddr[31:5] == 27'd0));
                    end else begin
                        wr_state <= WR_DATA;
                    end
                end
            end

            WR_ADDR: begin
                wr_state <= WR_DATA;
            end

            WR_DATA: begin
                s_axi_wready <= 1'b1;
                if (s_axi_wvalid) begin
                    s_axi_wready <= 1'b0;
                    do_register_write(aw_addr_reg,
                                      s_axi_wdata,
                                      s_axi_wstrb,
                                      wr_addr_valid);
                    wr_state <= WR_RESP;
                end
            end

            WR_RESP: begin
                if (!s_axi_bvalid) begin
                    s_axi_bvalid <= 1'b1;
                    s_axi_bresp  <= wr_addr_valid ? 2'b00 : 2'b10;
                end else if (s_axi_bready) begin
                    s_axi_bvalid <= 1'b0;
                    wr_state     <= WR_IDLE;
                end
            end
        endcase
    end
end

// ── Register write task (called only from the write FSM always block above)
task do_register_write;
    input [2:0]  addr;
    input [31:0] wdata;
    input [3:0]  wstrb;
    input        valid;
    integer i;
    begin
        if (valid) begin
            case (addr)
                3'b000: begin
                    for (i = 0; i < 4; i = i+1)
                        if (wstrb[i]) reg_mm2s_src_addr[i*8 +: 8] <= wdata[i*8 +: 8];
                end
                3'b001: begin
                    for (i = 0; i < 4; i = i+1)
                        if (wstrb[i]) reg_mm2s_length[i*8 +: 8] <= wdata[i*8 +: 8];
                end
                3'b010: begin
                    // Write control bits, then set flag.
                    // Flag-check at top of else is skipped this cycle (flag was 0).
                    // auto-clear fires next cycle.
                    if (wstrb[0]) reg_mm2s_control[1:0] <= wdata[1:0];
                    reg_mm2s_control[31:2] <= 30'd0;
                    mm2s_ctrl_written      <= 1'b1;
                end
                3'b011: ; // MM2S_STATUS — READ-ONLY
                3'b100: begin
                    for (i = 0; i < 4; i = i+1)
                        if (wstrb[i]) reg_s2mm_dst_addr[i*8 +: 8] <= wdata[i*8 +: 8];
                end
                3'b101: begin
                    for (i = 0; i < 4; i = i+1)
                        if (wstrb[i]) reg_s2mm_length[i*8 +: 8] <= wdata[i*8 +: 8];
                end
                3'b110: begin
                    if (wstrb[0]) reg_s2mm_control[1:0] <= wdata[1:0];
                    reg_s2mm_control[31:2] <= 30'd0;
                    s2mm_ctrl_written      <= 1'b1;
                end
                3'b111: ; // S2MM_STATUS — READ-ONLY
            endcase
        end
    end
endtask

// ── READ PATH FSM
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rd_state      <= RD_IDLE;
        s_axi_arready <= 1'b0;
        s_axi_rvalid  <= 1'b0;
        s_axi_rdata   <= 32'h0;
        s_axi_rresp   <= 2'b00;
        ar_addr_reg   <= 3'd0;
        rd_addr_valid <= 1'b0;
    end else begin
        case (rd_state)
            RD_IDLE: begin
                s_axi_arready <= 1'b1;
                if (s_axi_arvalid) begin
                    ar_addr_reg   <= s_axi_araddr[4:2];
                    rd_addr_valid <= (s_axi_araddr[31:5] == 27'd0);
                    s_axi_arready <= 1'b0;
                    rd_state      <= RD_DATA;
                end
            end

            RD_DATA: begin
                if (!s_axi_rvalid) begin
                    s_axi_rvalid <= 1'b1;
                    s_axi_rresp  <= rd_addr_valid ? 2'b00 : 2'b10;
                    if (!rd_addr_valid) begin
                        s_axi_rdata <= 32'hDEAD_BEEF;
                    end else begin
                        case (ar_addr_reg)
                            3'b000: s_axi_rdata <= reg_mm2s_src_addr;
                            3'b001: s_axi_rdata <= reg_mm2s_length;
                            3'b010: s_axi_rdata <= {30'd0, reg_mm2s_control[1:0]};
                            3'b011: s_axi_rdata <= {29'd0, mm2s_status[2:0]};
                            3'b100: s_axi_rdata <= reg_s2mm_dst_addr;
                            3'b101: s_axi_rdata <= reg_s2mm_length;
                            3'b110: s_axi_rdata <= {30'd0, reg_s2mm_control[1:0]};
                            3'b111: s_axi_rdata <= {29'd0, s2mm_status[2:0]};
                        endcase
                    end
                end else if (s_axi_rready) begin
                    s_axi_rvalid <= 1'b0;
                    rd_state     <= RD_IDLE;
                end
            end
        endcase
    end
end

endmodule