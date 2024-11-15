// this is a temporary file we can use for the vortex adapter

// in the cva6 repo, this file served the purpose of mapping its core’s request and response signals to the HPDCache


//THINGS WE NEED:
// * handle input output requests TOP PRIORITY 
// * Atomic operations? (these were included in cva6 and I am not quite sure if they are needed here)
// * Flush mannagement - theoretically done
// * possible bank routing and mannagement 

module Vortex_hpdcache_if_adapter 
#(
    parameter ADDR_WIDTH = `MEM_ADDR_WIDTH,
    parameter DATA_WIDTH = `XLEN,
    parameter TAG_WIDTH = 8,
    parameter UUID_WIDTH = `UUID_WIDTH,
    parameter NUM_REQS = 4,
    parameter PASSTHRU = 0,           // Passthrough: bypasses cache for all requests
    parameter NC_ENABLE = 1           // Enables bypass for non-cacheable requests only
) (
    // Clock and Reset
    input wire clk,
    input wire reset,

    // Core Interface (Vortex)
    input wire core_req_valid,
    input wire [ADDR_WIDTH-1:0] core_req_addr,
    input wire core_req_rw,
    input wire [DATA_WIDTH-1:0] core_req_data,
    input wire [TAG_WIDTH-1:0] core_req_tag,
    input wire core_req_flush,
    output wire core_rsp_valid,
    output wire [DATA_WIDTH-1:0] core_rsp_data,
    output wire [TAG_WIDTH-1:0] core_rsp_tag,
    output wire core_req_ready,

    // HPDCache Interface
    output wire hpdcache_req_valid,
    output wire [ADDR_WIDTH-1:0] hpdcache_req_addr,
    output wire hpdcache_req_rw,
    output wire [DATA_WIDTH-1:0] hpdcache_req_data,
    output wire [TAG_WIDTH-1:0] hpdcache_req_tag,
    input wire hpdcache_rsp_valid,
    input wire [DATA_WIDTH-1:0] hpdcache_rsp_data,
    input wire [TAG_WIDTH-1:0] hpdcache_rsp_tag,
    input wire hpdcache_req_ready,

    // Performance Monitoring Interface (optional)
    output wire perf_monitor_valid,
    output wire [31:0] perf_cache_hits,
    output wire [31:0] perf_cache_misses
);

    // Bypass Control
    wire bypass_request = (PASSTHRU != 0) || (NC_ENABLE && core_req_nc_valid);

    // MSHR Handling Signals (simplified for integration)
    reg mshr_alloc_valid;
    reg [ADDR_WIDTH-1:0] mshr_alloc_addr;
    reg mshr_alloc_ready;

    // Request and Response Control Logic
    assign hpdcache_req_valid = core_req_valid && ~bypass_request && mshr_alloc_ready;
    assign hpdcache_req_addr  = core_req_addr;
    assign hpdcache_req_rw    = core_req_rw;
    assign hpdcache_req_data  = core_req_data;
    assign hpdcache_req_tag   = core_req_tag;
    assign core_req_ready     = hpdcache_req_ready && mshr_alloc_ready && ~bypass_request;

    // Response Path
    assign core_rsp_valid = hpdcache_rsp_valid;
    assign core_rsp_data  = hpdcache_rsp_data;
    assign core_rsp_tag   = hpdcache_rsp_tag;

    // Flush Handling Logic
    reg flush_in_progress;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            flush_in_progress <= 0;
        end else if (core_req_flush) begin
            flush_in_progress <= 1;
        end else if (flush_complete) begin
            flush_in_progress <= 0;
        end
    end
    wire flush_complete = (/* condition for flush completion */);

    // Performance Counters
    reg [31:0] cache_hits, cache_misses;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            cache_hits <= 0;
            cache_misses <= 0;
        end else if (hpdcache_rsp_valid) begin
            if (~is_miss) cache_hits <= cache_hits + 1;
            else cache_misses <= cache_misses + 1;
        end
    end

    assign perf_monitor_valid = hpdcache_rsp_valid;
    assign perf_cache_hits = cache_hits;
    assign perf_cache_misses = cache_misses;

endmodule


