// mm2s_tb.v
`timescale 1ns/1ps

module tb_mm2s_channel;

    reg clk;
    reg rst_n;
    reg [31:0] mm2s_ctrl;
    reg [31:0] src_addr;
    reg [31:0] mm2s_len;
    wire        m_axi_arvalid;
    wire [31:0] m_axi_araddr;
    wire [7:0]  m_axi_arlen;
    wire [2:0]  m_axi_arsize;
    wire [1:0]  m_axi_arburst;
    reg         m_axi_arready;
    reg         m_axi_rvalid;
    reg [31:0]  m_axi_rdata;
    reg         m_axi_rlast;
    wire        m_axi_rready;
    wire [31:0] m_axis_tdata;
    wire        m_axis_tvalid;
    reg         m_axis_tready;
    wire        m_axis_tlast;

    integer i;
    integer watchdog_count;

    mm2s_channel dma_mm2s_inst (
        .clk(clk), .rst_n(rst_n),
        .mm2s_ctrl(mm2s_ctrl), .src_addr(src_addr), .mm2s_len(mm2s_len),
        .mm2s_status(), .mm2s_done(),
        .m_axi_arvalid(m_axi_arvalid), .m_axi_araddr(m_axi_araddr), .m_axi_arlen(m_axi_arlen),
        .m_axi_arsize(m_axi_arsize), .m_axi_arburst(m_axi_arburst), .m_axi_arready(m_axi_arready),
        .m_axi_rvalid(m_axi_rvalid), .m_axi_rdata(m_axi_rdata), .m_axi_rlast(m_axi_rlast), .m_axi_rready(m_axi_rready),
        .m_axis_tdata(m_axis_tdata), .m_axis_tvalid(m_axis_tvalid), .m_axis_tready(m_axis_tready), .m_axis_tlast(m_axis_tlast)
    );

    initial clk = 0;
    always #10 clk = ~clk;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_mm2s_channel);
        $shm_open("waves.shm");
        $shm_probe("ACTM");
    end

    initial begin
        rst_n = 0; mm2s_ctrl = 0; src_addr = 0; mm2s_len = 0;
        m_axi_arready = 0; m_axi_rvalid = 0; m_axi_rdata = 0; m_axi_rlast = 0;
        m_axis_tready = 1; 
        watchdog_count = 0;
        
        #40 rst_n = 1;
        repeat(2) @(negedge clk);

        $display("[%0t] Launching MM2S DMA Channel Transfer Request...", $time);
        src_addr  = 32'h1000_A000;
        mm2s_len  = 32'd32; 
        mm2s_ctrl = 32'h1; 
        
        @(negedge clk);
        mm2s_ctrl = 32'h0; 

        while (!m_axi_arvalid && watchdog_count < 20) begin
            @(posedge clk);
            watchdog_count = watchdog_count + 1;
        end

        if (!m_axi_arvalid) begin
            $display("[ERROR] Watchdog timeout! m_axi_arvalid never went high.");
            $finish;
        end
        
        #2; 
        m_axi_arready = 1;
        @(posedge clk);
        #2;
        m_axi_arready = 0;

        for (i = 0; i < 8; i = i + 1) begin
            @(negedge clk); 
            m_axi_rvalid = 1;
            m_axi_rdata  = 32'hBEEF_0000 + i;
            m_axi_rlast  = (i == 7); 
        end
        
        @(negedge clk);
        m_axi_rvalid = 0;
        m_axi_rlast  = 0;

        #200;
        $display("[%0t] Simulation complete! Waveforms generated.", $time);
        $finish;
    end

endmodule
