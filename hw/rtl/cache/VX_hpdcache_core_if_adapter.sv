// this is a temporary file we can use for the vortex adapter

// in the cva6 repo, this file served the purpose of mapping its core’s request and response signals to the HPDCache


//THINGS WE NEED:
// * handle input output requests TOP PRIORITY 
// * Atomic operations? (these were included in cva6 and I am not quite sure if they are needed here)
// * Flush mannagement - theoretically done
// * possible bank routing and mannagement 

`include "VX_cache_define.vh"

module Vortex_hpdcache_core_if_adapter 
#(
    parameter hpdcache_pkg::hpdcache_cfg_t HPDcacheCfg = '0,
    parameter type hpdcache_tag_t = logic,
    parameter type hpdcache_req_offset_t = logic,
    parameter type hpdcache_req_sid_t = logic,
    parameter type hpdcache_req_t = logic,
    parameter type hpdcache_rsp_t = logic,
    parameter type dcache_req_i_t = logic,
    parameter type dcache_req_o_t = logic,

    parameter REQ_DATA_SIZE = 16,
    parameter ADDR_WIDTH = `MEM_ADDR_WIDTH,
    parameter DATA_WIDTH = `XLEN,
    parameter TAG_WIDTH = 8,
    parameter UUID_WIDTH = `UUID_WIDTH,
    parameter NUM_REQS = 4,
    parameter PASSTHRU = 0,           // Passthrough: bypasses cache for all requests
    parameter NC_ENABLE = 1,           // Enables bypass for non-cacheable requests only
    parameter WRITEBACK = 0
) (
    // Clock and Reset
    input wire clk,
    input wire reset,

    // Core Interface (Vortex)
    // input wire core_req_valid,
    // input wire [ADDR_WIDTH-1:0] core_req_addr,
    // input wire core_req_rw,
    // input wire [DATA_WIDTH-1:0] core_req_data,
    // input wire [TAG_WIDTH-1:0] core_req_tag,
    // input wire core_req_flush,
    // output wire core_rsp_valid,
    // output wire [DATA_WIDTH-1:0] core_rsp_data,
    // output wire [TAG_WIDTH-1:0] core_rsp_tag,
    // output wire core_req_ready,

    input hpdcache_req_sid_t hpdcache_req_sid_i,
    VX_mem_bus_if.slave     vx_core_bus,

    // HPDCache Interface
    // output wire hpdcache_req_valid,
    // output wire [ADDR_WIDTH-1:0] hpdcache_req_addr,
    // output wire hpdcache_req_rw,
    // output wire [DATA_WIDTH-1:0] hpdcache_req_data,
    // output wire [TAG_WIDTH-1:0] hpdcache_req_tag,
    // input wire hpdcache_rsp_valid,
    // input wire [DATA_WIDTH-1:0] hpdcache_rsp_data,
    // input wire [TAG_WIDTH-1:0] hpdcache_rsp_tag,
    // input wire hpdcache_req_ready,

    output logic                        dcache_req_valid;
    input logic                        dcache_req_ready;
    output hpdcache_req_t               dcache_req     ;
    output logic                        dcache_req_abort;
    output hpdcache_tag_t               dcache_req_tag  ;
    output hpdcache_pkg::hpdcache_pma_t dcache_req_pma  ;
    
    input logic                        dcache_rsp_valid;
    input hpdcache_rsp_t               dcache_rsp    ;

);
    logic [`MEM_ADDR_WIDTH-1:0] byte_req_addr;
    logic []      hpdcache_addr_offset;


    // CMO detection
    wire CMO ;
    wire CMO_TYPE ; 

    // signal handling and bitfield generation
    assign line_idx = addr_st0[`CS_LINE_SEL_BITS-1:0];
    assign line_tag = `CS_LINE_ADDR_TAG(addr_st0);

    // generate byte address from word address and remove tag bits    
    assign byte_req_addr = vx_core_bus.req_data.addr << `CLOG2(REQ_DATA_SIZE); // core request is the word address, shift by
    assign hpdcache_addr_offset = 


    // CMO
    assign 


    // MSHR Handling Signals (simplified for integration)
    reg mshr_alloc_valid;
    reg [ADDR_WIDTH-1:0] mshr_alloc_addr;
    reg mshr_alloc_ready;

    // Request and Response Control Logic
    // assign hpdcache_req_valid = core_req_valid && ~bypass_request && mshr_alloc_ready;
    // assign hpdcache_req_addr  = core_req_addr;
    // assign hpdcache_req_rw    = core_req_rw;
    // assign hpdcache_req_data  = core_req_data;
    // assign hpdcache_req_tag   = core_req_tag;
    // assign core_req_ready     = hpdcache_req_ready && mshr_alloc_ready && ~bypass_request;

    assign vx_core_bus.req_ready = hpdcache_req_ready;
    assign hpdcache_req_valid = vx_core_bus.req_valid;

    assign hpdcache_req.addr_offset = hpdcache_addr_offset;
    
    
    assign hpdcache_req.wdata = vx_core_bus.req_data.data;
    assign hpdcache_req.op = vx_core_bus.req_data.rw ? hpdcache_pkg::HPDCACHE_REQ_LOAD : hpdcache_pkg::HPDCACHE_REQ_STORE;
    assign hpdcache_req.be = vx_core_bus.req_data.byteen;
    assign hpdcache_req.size = `CLOG2(DATA_SIZE); // always full word access
    assign hpdcache_req.sid = hpdcache_req_sid_i;
    assign hpdcache_req.tid = vx_core_bus.req_data.tag;
    assign hpdcache_req.need_rsp = vx_core_bus.req_data.rw ? 1'b1 : 1'b0;
    assign hpdcache_req.phys_indexed = 1'b1;
    assign hpdcache_req.addr_tag = line_tag;
    assign hpdcache_req.pma.uncacheable = 1'b0;
    assign hpdcache_req.pma.io = 1'b0;
    assign hpdcache_req.pma.wr_policy_hint = WRITEBACK ? hpdcache_pkg::HPDCACHE_WR_POLICY_WB : hpdcache_pkg::HPDCACHE_WR_POLICY_WT;
    
    assign hpdcache_req.abort = '0; // unused on Vortex
    assign hpdcache_req_tag_o = '0; // unused on physically indexed request
    assign hpdcache_req_pma_o.uncacheable = 1'b0;    // unused on Vortex yet
    assign hpdcache_req_pma_o.io = 1'b0;
    assign hpdcache_req_pma_o.wr_policy_hint = WRITEBACK ? hpdcache_pkg::HPDCACHE_WR_POLICY_WB : hpdcache_pkg::HPDCACHE_WR_POLICY_WT;


    // // Response Path
    // assign core_rsp_valid = hpdcache_rsp_valid;
    // assign core_rsp_data  = hpdcache_rsp_data;
    // assign core_rsp_tag   = hpdcache_rsp_tag;

    assign vx_core_bus.rsp_valid = hpdcache_rsp_valid;
    assign vx_core_bus.rsp_data.data = hpdcache_rsp.rdata;
    assign vx_core_bus.rsp_data.tag = hpdcache_rsp.tid;



    // // Flush Handling Logic
    // reg flush_in_progress;
    // always @(posedge clk or posedge reset) begin
    //     if (reset) begin
    //         flush_in_progress <= 0;
    //     end else if (core_req_flush) begin
    //         flush_in_progress <= 1;
    //     end else if (flush_complete) begin
    //         flush_in_progress <= 0;
    //     end
    // end
    // wire flush_complete = (/* condition for flush completion */);

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


