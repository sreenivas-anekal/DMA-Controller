// dma_arbiter.v
// 2-Channel Fair Round-Robin Arbiter Module

module dma_arbiter (
    input  wire        clk,
    input  wire        rst_n,

    // Channel Request Inputs
    input  wire        req_mm2s,
    input  wire        req_s2mm,

    // Active channel finished flag
    input  wire        transfer_done,

    // Allocation Channel Grants
    output reg         grant_mm2s,
    output reg         grant_s2mm
);

    // State Tracking: 0 = MM2S favored, 1 = S2MM favored
    reg last_priority; 
    reg bus_busy;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            grant_mm2s    <= 1'b0;
            grant_s2mm    <= 1'b0;
            last_priority <= 1'b0;
            bus_busy      <= 1'b0;
        end else begin
            
            // Hold the bus lock steady until the active master finishes
            if (bus_busy) begin
                if (transfer_done) begin
                    bus_busy   <= 1'b0;
                    grant_mm2s <= 1'b0;
                    grant_s2mm <= 1'b0;
                end
            end else begin
                // Evaluation Matrix based on who went last
                case (last_priority)
                    1'b0: begin // S2MM has priority right now
                        if (req_s2mm) begin
                            grant_s2mm    <= 1'b1;
                            bus_busy      <= 1'b1;
                            last_priority <= 1'b1; 
                        end else if (req_mm2s) begin
                            grant_mm2s    <= 1'b1;
                            bus_busy      <= 1'b1;
                            last_priority <= 1'b0; 
                        end
                    end

                    1'b1: begin // MM2S has priority right now
                        if (req_mm2s) begin
                            grant_mm2s    <= 1'b1;
                            bus_busy      <= 1'b1;
                            last_priority <= 1'b0;
                        end else if (req_s2mm) begin
                            grant_s2mm    <= 1'b1;
                            bus_busy      <= 1'b1;
                            last_priority <= 1'b1;
                        end
                    end
                endcase
            end
        end
    end
endmodule
