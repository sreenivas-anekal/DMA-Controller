`timescale 1ns/1ps

module tb_s2mm_datapath;

    parameter DATA_WIDTH = 32;
    parameter FIFO_DEPTH = 16;

    reg clk, rst_n;

    // AXI-Stream
    reg  [DATA_WIDTH-1:0] s_axis_tdata;
    reg                   s_axis_tvalid;
    wire                  s_axis_tready;
    reg                   s_axis_tlast;

    // FIFO side
    wire [DATA_WIDTH-1:0] fifo_rdata;
    reg                   fifo_rd_en;
    wire                  fifo_empty;
    wire [4:0]            fifo_count;

    // DUT
    s2mm_datapath #(
        .DATA_WIDTH(DATA_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),

        .s_axis_tdata(s_axis_tdata),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tlast(s_axis_tlast),

        .fifo_rdata(fifo_rdata),
        .fifo_rd_en(fifo_rd_en),
        .fifo_empty(fifo_empty),
        .fifo_count(fifo_count)
    );

    // Clock
    initial clk = 0;
    always #5 clk = ~clk;

    // =========================================================
    // TASK: send stream data
    // =========================================================
    task send_stream;
        input integer n;
        input [31:0] base;
        integer i;
        begin
            for (i = 0; i < n; i = i + 1) begin
                @(posedge clk);
                s_axis_tvalid <= 1;
                s_axis_tdata  <= base + i;
                s_axis_tlast  <= (i == n-1);

                // wait until accepted
                while (!s_axis_tready)
                    @(posedge clk);
            end

            @(posedge clk);
            s_axis_tvalid <= 0;
            s_axis_tlast  <= 0;
        end
    endtask

    // =========================================================
    // TASK: read FIFO data
    // =========================================================
    task read_fifo;
        input integer n;
        integer i;
        begin
            for (i = 0; i < n; i = i + 1) begin
                @(posedge clk);
                fifo_rd_en <= 1;
                @(posedge clk);
                fifo_rd_en <= 0;

                $display("[%0t] READ: %h (count=%0d)",
                          $time, fifo_rdata, fifo_count);
            end
        end
    endtask

    // =========================================================
    // TEST
    // =========================================================
    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_s2mm_datapath);

        // init
        rst_n = 0;
        s_axis_tvalid = 0;
        s_axis_tdata  = 0;
        s_axis_tlast  = 0;
        fifo_rd_en    = 0;

        #20;
        rst_n = 1;

        // -----------------------------------------------------
        // TEST 1: Basic write/read
        // -----------------------------------------------------
        $display("\n=== TEST1: Write 8 words ===");
        send_stream(8, 32'hA0000000);

        #20;

        $display("\n=== Reading FIFO ===");
        read_fifo(8);

        // -----------------------------------------------------
        // TEST 2: Overflow behavior (TREADY drop)
        // -----------------------------------------------------
        $display("\n=== TEST2: Fill FIFO completely ===");
        send_stream(16, 32'hB0000000);

        #10;
        $display("FIFO COUNT = %0d (should be 16)", fifo_count);

        // Try sending more (should stall)
        fork
            send_stream(4, 32'hC0000000);
        join

        #50;
        $display("TREADY = %b (should be 0 when full)", s_axis_tready);

        // -----------------------------------------------------
        // TEST 3: Drain and resume
        // -----------------------------------------------------
        $display("\n=== TEST3: Drain FIFO ===");
        read_fifo(16);

        #20;
        $display("FIFO EMPTY = %b (should be 1)", fifo_empty);

        #50;
        $finish;
    end

endmodule