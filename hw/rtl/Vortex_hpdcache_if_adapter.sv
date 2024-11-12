// this is a temporary file we can use for the vortex adapter

// in the cva6 repo, this file served the purpose of mapping its core’s request and response signals to the HPDCache


//THINGS WE NEED:
// * handle input output requests
// * Atomic operations? (these were included in cva6 and I am not quite sure if they are needed here)
// * Flush mannagement
// * possible bank routing and mannagement 

module Vortex_hpdcache_if_adapter #(
    parameter ADDR_WIDTH = `MEM_ADDR_WIDTH,  // Updated based on Vortex configuration
    parameter DATA_WIDTH = `XLEN,            // Data width, defined by the architecture (32 or 64)
    parameter TAG_WIDTH = 8,                 // Tag width, customizable
    parameter UUID_WIDTH = `UUID_WIDTH,      // Unique ID width for request tracking
    parameter NUM_REQS = 4                   // Number of simultaneous requests handled
) (
    // Clock and Reset
    input wire clk,
    input wire reset,

    // Core Interface (Vortex)
    input wire core_req_valid,
    input wire [ADDR_WIDTH-1:0] core_req_addr,
    input wire core_req_rw,                 // Read/Write flag
    input wire [DATA_WIDTH-1:0] core_req_data,
    input wire [TAG_WIDTH-1:0] core_req_tag,
    input wire core_req_flush,              // Flush request
    input wire core_req_bypass,             // Bypass request for non-cacheable data
    output wire core_rsp_valid,
    output wire [DATA_WIDTH-1:0] core_rsp_data,
    output wire [TAG_WIDTH-1:0] core_rsp_tag,
    output wire core_req_ready,

    // HPDCache Interface (AXI Compatible)
    output wire hpdcache_req_valid,
    output wire [ADDR_WIDTH-1:0] hpdcache_req_addr,
    output wire hpdcache_req_rw,            // Read/Write flag for HPDCache
    output wire [DATA_WIDTH-1:0] hpdcache_req_data,
    output wire [TAG_WIDTH-1:0] hpdcache_req_tag,
    input wire hpdcache_rsp_valid,
    input wire [DATA_WIDTH-1:0] hpdcache_rsp_data,
    input wire [TAG_WIDTH-1:0] hpdcache_rsp_tag,
    input wire hpdcache_req_ready,

    // Flush Control Signals
    input wire flush_begin,
    output wire flush_end,

    // Performance Monitoring Interface (optional)
    output wire perf_monitor_valid,
    output wire [31:0] perf_cache_hits,
    output wire [31:0] perf_cache_misses
);

    // State Machine for Handling Flushes
    reg [2:0] state, state_n;
    localparam STATE_IDLE  = 0;
    localparam STATE_FLUSH = 1;
    localparam STATE_WAIT  = 2;
    localparam STATE_DONE  = 3;

    // MSHR Handling
    reg mshr_valid;
    wire mshr_ready = (state == STATE_IDLE);  // MSHR ready only when idle
    wire is_miss = core_req_valid && ~core_req_ready;  // Basic miss detection

    // Bypass Handling for Non-Cacheable Data
    wire bypass_request = core_req_bypass; // Check if the request is a bypass
    assign hpdcache_req_valid = core_req_valid && !bypass_request && (state == STATE_IDLE);

    // Multi-Request Handling for NUM_REQS
    wire [NUM_REQS-1:0] req_valid_array;
    wire [NUM_REQS-1:0][ADDR_WIDTH-1:0] req_addr_array;
    wire [NUM_REQS-1:0][DATA_WIDTH-1:0] req_data_array;
    wire [NUM_REQS-1:0][TAG_WIDTH-1:0] req_tag_array;

    generate
        for (genvar i = 0; i < NUM_REQS; i++) begin
            assign req_valid_array[i] = (core_req_valid && (state == STATE_IDLE));
            assign req_addr_array[i]  = core_req_addr;
            assign req_data_array[i]  = core_req_data;
            assign req_tag_array[i]   = core_req_tag;
        end
    endgenerate

    // Request Path (including bypass handling)
    assign hpdcache_req_valid = core_req_valid && !bypass_request && (state == STATE_IDLE);
    assign hpdcache_req_addr  = core_req_addr;
    assign hpdcache_req_rw    = core_req_rw;
    assign hpdcache_req_data  = core_req_data;
    assign hpdcache_req_tag   = core_req_tag;
    assign core_req_ready     = hpdcache_req_ready && (state == STATE_IDLE);

    // Response Path
    assign core_rsp_valid = hpdcache_rsp_valid; //responce path ready/valid
    assign core_rsp_data  = hpdcache_rsp_data;
    assign core_rsp_tag   = hpdcache_rsp_tag;

    // Flush Handling Logic
    always @(*) begin
        state_n = state;
        case (state)
            STATE_IDLE: begin
                if (flush_begin) begin
                    state_n = STATE_FLUSH;
                end
            end
            STATE_FLUSH: begin
                if (mshr_ready) begin
                    state_n = STATE_WAIT;
                end
            end
            STATE_WAIT: begin
                if (~is_miss) begin  // Wait until no misses are pending
                    state_n = STATE_DONE;
                end
            end
            STATE_DONE: begin
                state_n = STATE_IDLE;
            end
        endcase
    end

    // Update State and Flush Signals
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= STATE_IDLE;
        end else begin
            state <= state_n;
        end
    end

    assign flush_end = (state == STATE_DONE);

    // Performance Monitoring Logic
    reg [31:0] cache_hits, cache_misses;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            cache_hits <= 0;
            cache_misses <= 0;
        end else begin
            if (hpdcache_rsp_valid && !is_miss) cache_hits <= cache_hits + 1;
            else if (hpdcache_rsp_valid && is_miss) cache_misses <= cache_misses + 1;
        end
    end

    assign perf_monitor_valid = hpdcache_rsp_valid;
    assign perf_cache_hits = cache_hits;
    assign perf_cache_misses = cache_misses;

endmodule

