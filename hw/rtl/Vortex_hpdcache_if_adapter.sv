// this is a temporary file we can use for the vortex adapter

// in the cva6 repo, this file served the purpose of mapping its core’s request and response signals to the HPDCache


`include "VX_cache_define.vh"

module VX_hpdcache_if_adapter import VX_gpu_pkg::*; 
#(
    parameter `STRING INSTANCE_ID   = "",

    parameter NUM_REQS              = 4,        // Number of Word requests per cycle
    parameter TAG_WIDTH             = 8,        // Core request tag size
    parameter WORD_SIZE             = 16,       // Word size in bytes
    parameter LINE_SIZE             = 64,       // Line size in bytes
    parameter FLAGS_WIDTH           = 0,        // Core request flags
    parameter CORE_OUT_BUF          = 3         // Core response output buffer size
) (
    input wire clk,
    input wire reset,

    // Core interface
    VX_mem_bus_if.slave core_bus_if [NUM_REQS],

    // Cache interface
    output logic core_req_valid_o [NUM_REQS],
    output logic core_req_ready_o [NUM_REQS],
    output logic [TAG_WIDTH-1:0] core_req_tag_o [NUM_REQS],
    output logic core_rsp_valid_i [NUM_REQS],
    output logic core_rsp_ready_i [NUM_REQS],

    // Memory interface (preserved for other teams)
    input wire mem_req_valid,
    input wire mem_req_ready,
    output wire mem_rsp_valid,
    output wire mem_rsp_ready
);

// Core-to-Cache Request Adapter
for (genvar i = 0; i < NUM_REQS; i++) begin : core_to_cache_req
    assign core_req_valid_o[i] = core_bus_if[i].req_valid;
    assign core_req_ready_o[i] = core_bus_if[i].req_ready;
    assign core_req_tag_o[i]   = core_bus_if[i].req_data.tag;
end

// Cache-to-Core Response Adapter
for (genvar i = 0; i < NUM_REQS; i++) begin : cache_to_core_rsp
    assign core_bus_if[i].rsp_valid = core_rsp_valid_i[i];
    assign core_bus_if[i].rsp_ready = core_rsp_ready_i[i];
    assign core_bus_if[i].rsp_data  = core_rsp_valid_i[i] ? core_req_tag_o[i] : '0;
end

// Preserve memory-related elements as placeholders
assign mem_rsp_valid = mem_req_valid;
assign mem_rsp_ready = mem_req_ready;

endmodule


