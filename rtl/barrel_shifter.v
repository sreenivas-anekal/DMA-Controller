module barrel_shifter #(
    parameter DATA_WIDTH = 4,                    
    parameter SHIFT_BITS = 2                     
)(
    input  wire [DATA_WIDTH-1:0]  data_address,
    input  wire [SHIFT_BITS-1:0]  shift_amount,
    output wire [DATA_WIDTH-1:0]  out_shifted_address
);
    wire [DATA_WIDTH-1:0] stage_wire [0:SHIFT_BITS];
    assign stage_wire[0] = data_address;
    genvar i;
    generate
        for (i = 0; i < SHIFT_BITS; i = i + 1) begin : shift_stage
        localparam SHIF = 1 << i;
            assign stage_wire[i+1] = shift_amount[i]? (stage_wire[i] >> SHIF): stage_wire[i];
        end
    endgenerate
    assign out_shifted_address = stage_wire[SHIFT_BITS];
endmodule