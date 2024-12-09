// Copyright © 2019-2023
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

`include "VX_cache_define.vh"
`include "hpdcache_typedef.svh"

module VX_hpdcache
    import VX_gpu_pkg::*;
    import hpdcache_pkg::*; 
#(
    parameter `STRING INSTANCE_ID   = "",

    // Number of Word requests per cycle
    parameter NUM_REQS              = 4,

    // Size of cache in bytes
    parameter CACHE_SIZE            = 32768,
    // Size of line inside a bank in bytes
    parameter LINE_SIZE             = 64,
    // Number of banks
    parameter NUM_BANKS             = 4,
    // Number of associative ways
    parameter NUM_WAYS              = 4,
    // Size of a word in bytes
    parameter WORD_SIZE             = 16,

    // Core Response Queue Size
    parameter CRSQ_SIZE             = 4,
    // Miss Reserv Queue Knob
    parameter MSHR_SIZE             = 16,
    // Memory Response Queue Size
    parameter MRSQ_SIZE             = 4,
    // Memory Request Queue Size
    parameter MREQ_SIZE             = 4,

    // Enable cache writeable
    parameter WRITE_ENABLE          = 1,

    // Enable cache writeback
    parameter WRITEBACK             = 0,

    // Enable dirty bytes on writeback
    parameter DIRTY_BYTES           = 0,

    // Replacement policy
    parameter REPL_POLICY           = `CS_REPL_CYCLIC,

    // Request debug identifier
    parameter UUID_WIDTH            = 0,

    // core request tag size
    parameter TAG_WIDTH             = UUID_WIDTH + 1,

    // core request flags
    parameter FLAGS_WIDTH           = 0,

    // Core response output register
    parameter CORE_OUT_BUF          = 3,

    // Memory request output register
    parameter MEM_OUT_BUF           = 3
 ) (
    // PERF
`ifdef PERF_ENABLE
    output cache_perf_t     cache_perf,
`endif

    input wire clk,
    input wire reset,

    VX_mem_bus_if.slave     core_bus_if [NUM_REQS],
    VX_mem_bus_if.master    mem_bus_if
);

    `STATIC_ASSERT(NUM_BANKS == (1 << `CLOG2(NUM_BANKS)), ("invalid parameter: number of banks must be power of 2"))
    `STATIC_ASSERT(WRITE_ENABLE || !WRITEBACK, ("invalid parameter: writeback requires write enable"))
    `STATIC_ASSERT(WRITEBACK || !DIRTY_BYTES, ("invalid parameter: dirty bytes require writeback"))

  function int unsigned __minu(int unsigned x, int unsigned y);
    return x < y ? x : y;
  endfunction

  function int unsigned __maxu(int unsigned x, int unsigned y);
    return y < x ? x : y;
  endfunction



    localparam REQ_SEL_WIDTH   = `UP(`CS_REQ_SEL_BITS);
    localparam WORD_SEL_WIDTH  = `UP(`CS_WORD_SEL_BITS);
    localparam MSHR_ADDR_WIDTH = `LOG2UP(MSHR_SIZE);
    localparam MEM_TAG_WIDTH   = `CACHE_MEM_TAG_WIDTH(MSHR_SIZE, NUM_BANKS, UUID_WIDTH);
    localparam WORDS_PER_LINE  = LINE_SIZE / WORD_SIZE;
    localparam WORD_WIDTH      = WORD_SIZE * 8;
    localparam WORD_SEL_BITS   = `CLOG2(WORDS_PER_LINE);
    localparam BANK_SEL_BITS   = `CLOG2(NUM_BANKS);
    localparam BANK_SEL_WIDTH  = `UP(BANK_SEL_BITS);
    localparam LINE_ADDR_WIDTH = (`CS_WORD_ADDR_WIDTH - BANK_SEL_BITS - WORD_SEL_BITS);
    localparam CORE_REQ_DATAW  = LINE_ADDR_WIDTH + 1 + WORD_SEL_WIDTH + WORD_SIZE + WORD_WIDTH + TAG_WIDTH + `UP(FLAGS_WIDTH);
    localparam CORE_RSP_DATAW  = WORD_WIDTH + TAG_WIDTH;
    localparam BANK_MEM_TAG_WIDTH = UUID_WIDTH + MSHR_ADDR_WIDTH;

    localparam CORE_RSP_REG_DISABLE = (NUM_BANKS != 1) || (NUM_REQS != 1);
    localparam MEM_REQ_REG_DISABLE  = (NUM_BANKS != 1);

    localparam REQ_XBAR_BUF = (NUM_REQS > 4) ? 2 : 0;


// performance monitoring and tracking
`ifdef PERF_ENABLE
    wire perf_read_miss_per_bank;
    wire perf_write_miss_per_bank;
    wire perf_mshr_stall_per_bank;
`endif

    // if write buffer is currently empty
    logic wbuffer_empty_o;

    // if there is flush request
    logic [NUM_REQS-1:0] flush_req_valid;
    logic dcache_flush;

    // one or more of the requesters issue a flush request
    assign dcache_flush = flush_req_valid != 0;
    
    
    // VX_mem_bus_if #(
    //     .DATA_SIZE (WORD_SIZE),
    //     .TAG_WIDTH (TAG_WIDTH)
    // ) core_bus2_if[NUM_REQS]();

    // wire [NUM_BANKS-1:0] per_bank_flush_begin;
    // wire [`UP(UUID_WIDTH)-1:0] flush_uuid;
    // wire [NUM_BANKS-1:0] per_bank_flush_end;

    // wire [NUM_BANKS-1:0] per_bank_core_req_fire;

    // VX_mem_bus_if #(
    //     .DATA_SIZE (LINE_SIZE),
    //     .TAG_WIDTH (MEM_TAG_WIDTH)
    // ) mem_bus_tmp_if();

    // wire [BANK_MEM_TAG_WIDTH-1:0] bank_mem_rsp_tag;
    // wire [`UP(`CS_BANK_SEL_BITS)-1:0] mem_rsp_bank_id;

    // if (NUM_BANKS > 1) begin : g_mem_rsp_tag_s_with_banks
    //     assign bank_mem_rsp_tag = mem_rsp_tag_s[MEM_TAG_WIDTH-1:`CS_BANK_SEL_BITS];
    //     assign mem_rsp_bank_id = mem_rsp_tag_s[`CS_BANK_SEL_BITS-1:0];
    // end else begin : g_mem_rsp_tag_s_no_bank
    //     assign bank_mem_rsp_tag = mem_rsp_tag_s;
    //     assign mem_rsp_bank_id = 0;
    // end

    // if (FLAGS_WIDTH != 0) begin : g_mem_req_flags
    //     assign mem_bus_tmp_if.req_data.flags = mem_req_flush_b;
    // end else begin : g_no_mem_req_flags
    //     assign mem_bus_tmp_if.req_data.flags = '0;
    //     `UNUSED_VAR (mem_req_flush_b)
    // end

    // if (WRITE_ENABLE) begin : g_mem_bus_if
    //     `ASSIGN_VX_MEM_BUS_IF (mem_bus_if, mem_bus_tmp_if);
    // end else begin : g_mem_bus_if_ro
    //     `ASSIGN_VX_MEM_BUS_RO_IF (mem_bus_if, mem_bus_tmp_if);
    // end

    ///////////////////////////////////////////////////////////////////////////

    // wire [NUM_BANKS-1:0]                        per_bank_core_req_valid;
    // wire [NUM_BANKS-1:0][`CS_LINE_ADDR_WIDTH-1:0] per_bank_core_req_addr;
    // wire [NUM_BANKS-1:0]                        per_bank_core_req_rw;
    // wire [NUM_BANKS-1:0][WORD_SEL_WIDTH-1:0]    per_bank_core_req_wsel;
    // wire [NUM_BANKS-1:0][WORD_SIZE-1:0]         per_bank_core_req_byteen;
    // wire [NUM_BANKS-1:0][`CS_WORD_WIDTH-1:0]    per_bank_core_req_data;
    // wire [NUM_BANKS-1:0][TAG_WIDTH-1:0]         per_bank_core_req_tag;
    // wire [NUM_BANKS-1:0][REQ_SEL_WIDTH-1:0]     per_bank_core_req_idx;
    // wire [NUM_BANKS-1:0][`UP(FLAGS_WIDTH)-1:0]  per_bank_core_req_flags;
    // wire [NUM_BANKS-1:0]                        per_bank_core_req_ready;

    // // Bank requests dispatch

    // wire [NUM_REQS-1:0]                      core_req_valid;
    // wire [NUM_REQS-1:0][`CS_WORD_ADDR_WIDTH-1:0] core_req_addr;
    // wire [NUM_REQS-1:0]                      core_req_rw;
    // wire [NUM_REQS-1:0][WORD_SIZE-1:0]       core_req_byteen;
    // wire [NUM_REQS-1:0][`CS_WORD_WIDTH-1:0]  core_req_data;
    // wire [NUM_REQS-1:0][TAG_WIDTH-1:0]       core_req_tag;
    // wire [NUM_REQS-1:0][`UP(FLAGS_WIDTH)-1:0] core_req_flags;
    // wire [NUM_REQS-1:0]                      core_req_ready;

    // wire [NUM_REQS-1:0][LINE_ADDR_WIDTH-1:0] core_req_line_addr;
    // wire [NUM_REQS-1:0][BANK_SEL_WIDTH-1:0]  core_req_bid;
    // wire [NUM_REQS-1:0][WORD_SEL_WIDTH-1:0]  core_req_wsel;

    // wire [NUM_REQS-1:0][CORE_REQ_DATAW-1:0]  core_req_data_in;
    // wire [NUM_BANKS-1:0][CORE_REQ_DATAW-1:0] core_req_data_out;

    // for (genvar i = 0; i < NUM_REQS; ++i) begin : g_core_req
    //     assign core_req_valid[i]  = core_bus2_if[i].req_valid;
    //     assign core_req_rw[i]     = core_bus2_if[i].req_data.rw;
    //     assign core_req_byteen[i] = core_bus2_if[i].req_data.byteen;
    //     assign core_req_addr[i]   = core_bus2_if[i].req_data.addr;
    //     assign core_req_data[i]   = core_bus2_if[i].req_data.data;
    //     assign core_req_tag[i]    = core_bus2_if[i].req_data.tag;
    //     assign core_req_flags[i]  = `UP(FLAGS_WIDTH)'(core_bus2_if[i].req_data.flags);
    //     assign core_bus2_if[i].req_ready = core_req_ready[i];
    // end

    // for (genvar i = 0; i < NUM_REQS; ++i) begin : g_core_req_wsel
    //     if (WORDS_PER_LINE > 1) begin : g_wsel
    //         assign core_req_wsel[i] = core_req_addr[i][0 +: WORD_SEL_BITS];
    //     end else begin : g_no_wsel
    //         assign core_req_wsel[i] = '0;
    //     end
    // end

    // for (genvar i = 0; i < NUM_REQS; ++i) begin : g_core_req_line_addr
    //     assign core_req_line_addr[i] = core_req_addr[i][(BANK_SEL_BITS + WORD_SEL_BITS) +: LINE_ADDR_WIDTH];
    // end

    // for (genvar i = 0; i < NUM_REQS; ++i) begin : g_core_req_bid
    //     if (NUM_BANKS > 1) begin : g_multibanks
    //         assign core_req_bid[i] = core_req_addr[i][WORD_SEL_BITS +: BANK_SEL_BITS];
    //     end else begin : g_singlebank
    //         assign core_req_bid[i] = '0;
    //     end
    // end

    // for (genvar i = 0; i < NUM_REQS; ++i) begin : g_core_req_data_in
    //     assign core_req_data_in[i] = {
    //         core_req_line_addr[i],
    //         core_req_rw[i],
    //         core_req_wsel[i],
    //         core_req_byteen[i],
    //         core_req_data[i],
    //         core_req_tag[i],
    //         core_req_flags[i]
    //     };
    // end

`ifdef PERF_ENABLE
    wire [`PERF_CTR_BITS-1:0] perf_collisions;
`endif


localparam int HPDCACHE_NREQUESTERS = 1;   //

// hpcache
    localparam hpdcache_pkg::hpdcache_user_cfg_t HPDcacheUserCfg = '{
        // HPDCache configuration for Vortex GPU
        // Core parameters
        nRequesters: HPDCACHE_NREQUESTERS,  // should be set as NUMBER of INPUT of Vortex_cache_cluster, set to 1 for test
        paWidth: int'(`MEM_ADDR_WIDTH),  // From Vortex MEM_ADDR_WIDTH, 
        wordWidth: int'(`CS_WORD_WIDTH),  // From Vortex CS_WORD_WIDTH (8 * WORD_SIZE)
        sets: int'(`CS_LINES_PER_BANK),  // CACHE_SIZE / (LINE_SIZE * NUM_WAYS) for NUMBANK = 1
        ways: int'(NUM_WAYS),  // From Vortex NUM_WAYS
        clWords: int'(`CS_WORDS_PER_LINE),  // From Vortex CS_WORDS_PER_LINE (LINE_SIZE/WORD_SIZE)
        reqWords: int'(1),  // Single word requests

        // Request tracking
        reqTransIdWidth: int'(TAG_WIDTH),  // core request tag width
        reqSrcIdWidth: int'(`UP(`CS_REQ_SEL_BITS)),  // `CLOG2(NUM_REQS)

        // Cache organization
        victimSel: (REPL_POLICY == `CS_REPL_PLRU) ? hpdcache_pkg::HPDCACHE_VICTIM_PLRU :  // hpdcache does not support cyclic
                                                    hpdcache_pkg::HPDCACHE_VICTIM_RANDOM,

        // Data RAM configuration
        //dataWaysPerRamWord: int'(__minu(NUM_WAYS, 128/`CS_WORD_WIDTH)),
        dataWaysPerRamWord: int'(2),
        dataSetsPerRam: int'(`CS_LINES_PER_BANK),
        dataRamByteEnable: bit'(1'b1),
        // accessWords: int'(__maxu(`CS_LINE_WIDTH / (2 * `CS_WORD_WIDTH), 1)),
        accessWords: int'(4),

        // MSHR configuration
        mshrSets: int'((MSHR_SIZE < 16) ? 1 : MSHR_SIZE / 2),
        mshrWays: int'((MSHR_SIZE < 16) ? MSHR_SIZE : 2),
        mshrWaysPerRamWord: int'((MSHR_SIZE < 16) ? MSHR_SIZE : 2),
        mshrSetsPerRam: int'((MSHR_SIZE < 16) ? 1 : MSHR_SIZE / 2),
        mshrRamByteEnable: bit'(1'b1),
        mshrUseRegbank: bit'(MSHR_SIZE < 16),

        // Core response handling
        refillCoreRspFeedthrough: bit'(1'b1),
        refillFifoDepth: int'(2),

        // Write buffer configuration
        wbufDirEntries: int'(MREQ_SIZE),  // From Vortex MREQ_SIZE
        wbufDataEntries: int'(MREQ_SIZE), 
        wbufWords: int'(1),
        wbufTimecntWidth: int'(3),

        // Request tracking
        rtabEntries: int'(4),

        // Flush handling
        flushEntries: 8,
        flushFifoDepth: 4,

        // Memory interface
        memAddrWidth: int'(`CS_LINE_ADDR_WIDTH),  // From Vortex CS_MEM_ADDR_WIDTH
        memIdWidth: int'(MEM_TAG_WIDTH),  // From Vortex MEM_TAG_WIDTH
        memDataWidth: int'(`CS_LINE_WIDTH),  // From Vortex CS_LINE_WIDTH (8 * LINE_SIZE)

        // Write policies
        wtEn: bit'(WRITE_ENABLE),  // From Vortex WRITE_ENABLE
        wbEn: bit'(WRITEBACK)    // From Vortex WRITEBACK

    };



  // Print at elaboration time
  initial begin
    $display("HPDcache Configuration:");
    $display("  nRequesters: %0d", HPDcacheUserCfg.nRequesters);
    $display("  paWidth: %0d", HPDcacheUserCfg.paWidth);
    $display("  wordWidth: %0d", HPDcacheUserCfg.wordWidth);
    $display("  sets: %0d", HPDcacheUserCfg.sets);
    $display("  ways: %0d", HPDcacheUserCfg.ways);
    $display("  clWords: %0d", HPDcacheUserCfg.clWords);
    $display("  reqWords: %0d", HPDcacheUserCfg.reqWords);
    $display("  reqTransIdWidth: %0d", HPDcacheUserCfg.reqTransIdWidth);
    $display("  reqSrcIdWidth: %0d", HPDcacheUserCfg.reqSrcIdWidth);
    $display("  victimSel: %0d", HPDcacheUserCfg.victimSel);
    $display("  dataWaysPerRamWord: %0d", HPDcacheUserCfg.dataWaysPerRamWord);
    $display("  dataSetsPerRam: %0d", HPDcacheUserCfg.dataSetsPerRam);
    $display("  dataRamByteEnable: %0d", HPDcacheUserCfg.dataRamByteEnable);
    $display("  accessWords: %0d", HPDcacheUserCfg.accessWords);
    $display("  mshrSets: %0d", HPDcacheUserCfg.mshrSets);
    $display("  mshrWays: %0d", HPDcacheUserCfg.mshrWays);
    $display("  mshrWaysPerRamWord: %0d", HPDcacheUserCfg.mshrWaysPerRamWord);
    $display("  mshrSetsPerRam: %0d", HPDcacheUserCfg.mshrSetsPerRam);
    $display("  mshrRamByteEnable: %0d", HPDcacheUserCfg.mshrRamByteEnable);
    $display("  mshrUseRegbank: %0d", HPDcacheUserCfg.mshrUseRegbank);
    $display("  refillCoreRspFeedthrough: %0d", HPDcacheUserCfg.refillCoreRspFeedthrough);
    $display("  refillFifoDepth: %0d", HPDcacheUserCfg.refillFifoDepth);
    $display("  wbufDirEntries: %0d", HPDcacheUserCfg.wbufDirEntries);
    $display("  wbufDataEntries: %0d", HPDcacheUserCfg.wbufDataEntries);
    $display("  wbufWords: %0d", HPDcacheUserCfg.wbufWords);
    $display("  wbufTimecntWidth: %0d", HPDcacheUserCfg.wbufTimecntWidth);
    $display("  rtabEntries: %0d", HPDcacheUserCfg.rtabEntries);
    $display("  flushEntries: %0d", HPDcacheUserCfg.flushEntries);
    $display("  flushFifoDepth: %0d", HPDcacheUserCfg.flushFifoDepth);
    $display("  memAddrWidth: %0d", HPDcacheUserCfg.memAddrWidth);
    $display("  memIdWidth: %0d", HPDcacheUserCfg.memIdWidth);
    $display("  memDataWidth: %0d", HPDcacheUserCfg.memDataWidth);
    $display("  wtEn: %0d", HPDcacheUserCfg.wtEn);
    $display("  wbEn: %0d", HPDcacheUserCfg.wbEn);
  end




    localparam hpdcache_pkg::hpdcache_cfg_t HPDcacheCfg = hpdcache_pkg::hpdcacheBuildConfig(
      HPDcacheUserCfg
    );

    `STATIC_ASSERT(HPDcacheCfg.u.wordWidth < 0, ("wordwidth: %0d", HPDcacheCfg.u.wordWidth))
    `STATIC_ASSERT(HPDcacheUserCfg.wordWidth < 0, ("user: wordwidth: %0d", HPDcacheUserCfg.wordWidth))
    `STATIC_ASSERT(HPDcacheUserCfg.accessWords < 0, ("user: accesswords: %0d", HPDcacheUserCfg.accessWords))
    `STATIC_ASSERT(HPDcacheUserCfg.paWidth < 0, ("pawidth: %0d", HPDcacheCfg.u.paWidth))
    `STATIC_ASSERT(HPDcacheUserCfg.memAddrWidth < 0, ("memAddrwidth: %0d", HPDcacheCfg.u.memAddrWidth))
    `STATIC_ASSERT(NUM_BANKS < 0, ("numbanks: %0d", NUM_BANKS))
    `STATIC_ASSERT(HPDcacheUserCfg.clWords < 0, ("clwords: %0d", HPDcacheUserCfg.clWords))

    // generate type definitions

    `HPDCACHE_TYPEDEF_MEM_ATTR_T(hpdcache_mem_addr_t, hpdcache_mem_id_t, hpdcache_mem_data_t,
                                hpdcache_mem_be_t, HPDcacheCfg);
    `HPDCACHE_TYPEDEF_MEM_REQ_T(hpdcache_mem_req_t, hpdcache_mem_addr_t, hpdcache_mem_id_t);
    `HPDCACHE_TYPEDEF_MEM_RESP_R_T(hpdcache_mem_resp_r_t, hpdcache_mem_id_t, hpdcache_mem_data_t);
    `HPDCACHE_TYPEDEF_MEM_REQ_W_T(hpdcache_mem_req_w_t, hpdcache_mem_data_t, hpdcache_mem_be_t);
    `HPDCACHE_TYPEDEF_MEM_RESP_W_T(hpdcache_mem_resp_w_t, hpdcache_mem_id_t);

    `HPDCACHE_TYPEDEF_REQ_ATTR_T(hpdcache_req_offset_t, hpdcache_data_word_t, hpdcache_data_be_t,
                                hpdcache_req_data_t, hpdcache_req_be_t, hpdcache_req_sid_t,
                                hpdcache_req_tid_t, hpdcache_tag_t, HPDcacheCfg);
    `HPDCACHE_TYPEDEF_REQ_T(hpdcache_req_t, hpdcache_req_offset_t, hpdcache_req_data_t,
                            hpdcache_req_be_t, hpdcache_req_sid_t, hpdcache_req_tid_t,
                            hpdcache_tag_t);
    `HPDCACHE_TYPEDEF_RSP_T(hpdcache_rsp_t, hpdcache_req_data_t, hpdcache_req_sid_t,
                            hpdcache_req_tid_t);

    typedef logic [HPDcacheCfg.u.wbufTimecntWidth-1:0] hpdcache_wbuf_timecnt_t;

    // if adapter for load/store core request/response


    // hardware prefetcher
    typedef logic [63:0] hwpf_stride_param_t;

    logic                        dcache_req_valid[HPDCACHE_NREQUESTERS];
    logic                        dcache_req_ready[HPDCACHE_NREQUESTERS];
    hpdcache_req_t               dcache_req      [HPDCACHE_NREQUESTERS];
    logic                        dcache_req_abort[HPDCACHE_NREQUESTERS];
    hpdcache_tag_t               dcache_req_tag  [HPDCACHE_NREQUESTERS];
    hpdcache_pkg::hpdcache_pma_t dcache_req_pma  [HPDCACHE_NREQUESTERS];
    logic                        dcache_rsp_valid[HPDCACHE_NREQUESTERS];
    hpdcache_rsp_t               dcache_rsp      [HPDCACHE_NREQUESTERS];
    logic                        dcache_read_miss, dcache_write_miss;

    logic dcache_enable;

    // turn on by default
    assign dcache_enable = 1'b1;


    generate
        for (genvar r = 0; r < NUM_REQS; ++r) begin : gen_vx_hpdcache_if_adapter
            VX_hpdcache_core_if_adapter #(
            // .CVA6Cfg              (CVA6Cfg),
            .HPDcacheCfg          (HPDcacheCfg),
            .hpdcache_tag_t       (hpdcache_tag_t),
            .hpdcache_req_offset_t(hpdcache_req_offset_t),
            .hpdcache_req_sid_t   (hpdcache_req_sid_t),
            .hpdcache_req_t       (hpdcache_req_t),
            .hpdcache_rsp_t       (hpdcache_rsp_t),
            //.dcache_req_i_t       (dcache_req_i_t),
            //.dcache_req_o_t       (dcache_req_o_t),
            // .is_load_port         (1'b1)
            .CACHE_SIZE           (CACHE_SIZE),
            .LINE_SIZE            (LINE_SIZE),
            .NUM_BANKS            (NUM_BANKS),
            .NUM_WAYS             (NUM_WAYS),
            .WORD_SIZE            (WORD_SIZE)
        ) i_vx_hpdcache_if_adapter (
            .clk(clk),
            .reset(reset),

            .hpdcache_req_sid_i(hpdcache_req_sid_t'(r)),

            .flush_op_o        (flush_req_valid[r]),
            .vx_core_bus     (core_bus_if [r]),
                                
            .hpdcache_req_valid(dcache_req_valid[r]),
            .hpdcache_req_ready(dcache_req_ready[r]),
            .hpdcache_req      (dcache_req[r]),
            .hpdcache_req_abort(dcache_req_abort[r]),
            .hpdcache_req_tag  (dcache_req_tag[r]),
            .hpdcache_req_pma  (dcache_req_pma[r]),

            .hpdcache_rsp_valid(dcache_rsp_valid[r]),
            .hpdcache_rsp      (dcache_rsp[r])
        );
        end;
    endgenerate

    // CMO request generation





    // if adapter for memory request/response
    // hpdcache memory interface signals

    logic                 dcache_read_ready;
    logic                 dcache_read_valid;
    hpdcache_mem_req_t    dcache_read;

    logic                 dcache_read_resp_ready;
    logic                 dcache_read_resp_valid;
    hpdcache_mem_resp_r_t dcache_read_resp;

    logic                 dcache_write_ready;
    logic                 dcache_write_valid;
    hpdcache_mem_req_t    dcache_write;

    logic                 dcache_write_data_ready;
    logic                 dcache_write_data_valid;
    hpdcache_mem_req_w_t  dcache_write_data;

    logic                 dcache_write_resp_ready;
    logic                 dcache_write_resp_valid;
    hpdcache_mem_resp_w_t dcache_write_resp;

    // vx_hpdcache_mem_if_adapter #(
    //     .hpdcache_mem_id_t    (hpdcache_mem_id_t),
    //     .hpdcache_mem_req_t   (hpdcache_mem_req_t),
    //     .hpdcache_mem_req_w_t (hpdcache_mem_req_w_t),
    //     .hpdcache_mem_resp_r_t(hpdcache_mem_resp_r_t),
    //     .hpdcache_mem_resp_w_t(hpdcache_mem_resp_w_t),
    // ) i_vx_hpdcache_mem_if_adapter (
    //     .clk_i,
    //     .rst_ni,

    //     // memory request signals
    //     .mem_bus_if    (mem_bus_if),

    //     .mem_req_read_ready(dcache_read_ready),
    //     .mem_req_read_valid(dcache_read_valid),
    //     .mem_req_read      (dcache_read),

    //     .mem_resp_read_ready(dcache_read_resp_ready),
    //     .mem_resp_read_valid(dcache_read_resp_valid),
    //     .mem_resp_read      (dcache_read_resp),

    //     .mem_req_write_ready(dcache_write_ready),
    //     .mem_req_write_valid(dcache_write_valid),
    //     .mem_req_write      (dcache_write),

    //     .mem_req_write_data_ready(dcache_write_data_ready),
    //     .mem_req_write_data_valid(dcache_write_data_valid),
    //     .mem_req_write_data      (dcache_write_data),

    //     .mem_resp_write_ready(dcache_write_resp_ready),
    //     .mem_resp_write_valid(dcache_write_resp_valid),
    //     .mem_resp_write      (dcache_write_resp),

    // );

    hpdcache #(
      .HPDcacheCfg          (HPDcacheCfg),
      .wbuf_timecnt_t       (hpdcache_wbuf_timecnt_t),
      .hpdcache_tag_t       (hpdcache_tag_t),
      .hpdcache_data_word_t (hpdcache_data_word_t),
      .hpdcache_data_be_t   (hpdcache_data_be_t),
      .hpdcache_req_offset_t(hpdcache_req_offset_t),
      .hpdcache_req_data_t  (hpdcache_req_data_t),
      .hpdcache_req_be_t    (hpdcache_req_be_t),
      .hpdcache_req_sid_t   (hpdcache_req_sid_t),
      .hpdcache_req_tid_t   (hpdcache_req_tid_t),
      .hpdcache_req_t       (hpdcache_req_t),
      .hpdcache_rsp_t       (hpdcache_rsp_t),
      .hpdcache_mem_addr_t  (hpdcache_mem_addr_t),
      .hpdcache_mem_id_t    (hpdcache_mem_id_t),
      .hpdcache_mem_data_t  (hpdcache_mem_data_t),
      .hpdcache_mem_be_t    (hpdcache_mem_be_t),
      .hpdcache_mem_req_t   (hpdcache_mem_req_t),
      .hpdcache_mem_req_w_t (hpdcache_mem_req_w_t),
      .hpdcache_mem_resp_r_t(hpdcache_mem_resp_r_t),
      .hpdcache_mem_resp_w_t(hpdcache_mem_resp_w_t)
    ) i_hpdcache (
      .clk_i(clk),
      .rst_ni(reset),

      .wbuf_flush_i(dcache_flush),

      .core_req_valid_i(dcache_req_valid),
      .core_req_ready_o(dcache_req_ready),
      .core_req_i      (dcache_req),
      .core_req_abort_i(dcache_req_abort),
      .core_req_tag_i  (dcache_req_tag),
      .core_req_pma_i  (dcache_req_pma),

      .core_rsp_valid_o(dcache_rsp_valid),
      .core_rsp_o      (dcache_rsp),

      .mem_req_read_ready_i(dcache_read_ready),
      .mem_req_read_valid_o(dcache_read_valid),
      .mem_req_read_o      (dcache_read),

      .mem_resp_read_ready_o(dcache_read_resp_ready),
      .mem_resp_read_valid_i(dcache_read_resp_valid),
      .mem_resp_read_i      (dcache_read_resp),

      .mem_req_write_ready_i(dcache_write_ready),
      .mem_req_write_valid_o(dcache_write_valid),
      .mem_req_write_o      (dcache_write),

      .mem_req_write_data_ready_i(dcache_write_data_ready),
      .mem_req_write_data_valid_o(dcache_write_data_valid),
      .mem_req_write_data_o      (dcache_write_data),

      .mem_resp_write_ready_o(dcache_write_resp_ready),
      .mem_resp_write_valid_i(dcache_write_resp_valid),
      .mem_resp_write_i      (dcache_write_resp),

      .evt_cache_write_miss_o(dcache_write_miss),
      .evt_cache_read_miss_o (dcache_read_miss),
      .evt_uncached_req_o    (  /* unused */),
      .evt_cmo_req_o         (  /* unused */),
      .evt_write_req_o       (  /* unused */),
      .evt_read_req_o        (  /* unused */),
      .evt_prefetch_req_o    (  /* unused */),
      .evt_req_on_hold_o     (  /* unused */),
      .evt_rtab_rollback_o   (  /* unused */),
      .evt_stall_refill_o    (  /* unused */),
      .evt_stall_o           (  /* unused */),

      .wbuf_empty_o(wbuffer_empty_o),

      .cfg_enable_i                       (dcache_enable),
      .cfg_wbuf_threshold_i               (3'd2),
      .cfg_wbuf_reset_timecnt_on_write_i  (1'b1),
      .cfg_wbuf_sequential_waw_i          (1'b0),
      .cfg_wbuf_inhibit_write_coalescing_i(1'b0),
      .cfg_prefetch_updt_plru_i           (1'b1),
      .cfg_error_on_cacheable_amo_i       (1'b0),
      .cfg_rtab_single_entry_i            (1'b0),
      .cfg_default_wb_i                   (1'b0)
    );

    // // Bank responses gather

    // wire [NUM_BANKS-1:0][CORE_RSP_DATAW-1:0] core_rsp_data_in;
    // wire [NUM_REQS-1:0][CORE_RSP_DATAW-1:0]  core_rsp_data_out;

    // for (genvar i = 0; i < NUM_BANKS; ++i) begin : g_core_rsp_data_in
    //     assign core_rsp_data_in[i] = {per_bank_core_rsp_data[i], per_bank_core_rsp_tag[i]};
    // end

    // VX_stream_xbar #(
    //     .NUM_INPUTS  (NUM_BANKS),
    //     .NUM_OUTPUTS (NUM_REQS),
    //     .DATAW       (CORE_RSP_DATAW),
    //     .ARBITER     ("R")
    // ) rsp_xbar (
    //     .clk       (clk),
    //     .reset     (reset),
    //     `UNUSED_PIN (collisions),
    //     .valid_in  (per_bank_core_rsp_valid),
    //     .data_in   (core_rsp_data_in),
    //     .sel_in    (per_bank_core_rsp_idx),
    //     .ready_in  (per_bank_core_rsp_ready),
    //     .valid_out (core_rsp_valid_s),
    //     .data_out  (core_rsp_data_out),
    //     .ready_out (core_rsp_ready_s),
    //     `UNUSED_PIN (sel_out)
    // );

    // for (genvar i = 0; i < NUM_REQS; ++i) begin : g_core_rsp_data_s
    //     assign {core_rsp_data_s[i], core_rsp_tag_s[i]} = core_rsp_data_out[i];
    // end

// `ifdef PERF_ENABLE
//     // per cycle: core_reads, core_writes
//     wire [`CLOG2(NUM_REQS+1)-1:0] perf_core_reads_per_cycle;
//     wire [`CLOG2(NUM_REQS+1)-1:0] perf_core_writes_per_cycle;

//     wire [NUM_REQS-1:0] perf_core_reads_per_req;
//     wire [NUM_REQS-1:0] perf_core_writes_per_req;

//     // per cycle: read misses, write misses, msrq stalls, pipeline stalls
//     wire [`CLOG2(NUM_BANKS+1)-1:0] perf_read_miss_per_cycle;
//     wire [`CLOG2(NUM_BANKS+1)-1:0] perf_write_miss_per_cycle;
//     wire [`CLOG2(NUM_BANKS+1)-1:0] perf_mshr_stall_per_cycle;
//     wire [`CLOG2(NUM_REQS+1)-1:0] perf_crsp_stall_per_cycle;

//     `BUFFER(perf_core_reads_per_req, core_req_valid & core_req_ready & ~core_req_rw);
//     `BUFFER(perf_core_writes_per_req, core_req_valid & core_req_ready & core_req_rw);

//     `POP_COUNT(perf_core_reads_per_cycle, perf_core_reads_per_req);
//     `POP_COUNT(perf_core_writes_per_cycle, perf_core_writes_per_req);
//     `POP_COUNT(perf_read_miss_per_cycle, perf_read_miss_per_bank);
//     `POP_COUNT(perf_write_miss_per_cycle, perf_write_miss_per_bank);
//     `POP_COUNT(perf_mshr_stall_per_cycle, perf_mshr_stall_per_bank);

//     wire [NUM_REQS-1:0] perf_crsp_stall_per_req;
//     for (genvar i = 0; i < NUM_REQS; ++i) begin : g_perf_crsp_stall_per_req
//         assign perf_crsp_stall_per_req[i] = core_bus2_if[i].rsp_valid && ~core_bus2_if[i].rsp_ready;
//     end

//     `POP_COUNT(perf_crsp_stall_per_cycle, perf_crsp_stall_per_req);

//     wire perf_mem_stall_per_cycle = mem_bus_if.req_valid && ~mem_bus_if.req_ready;

//     reg [`PERF_CTR_BITS-1:0] perf_core_reads;
//     reg [`PERF_CTR_BITS-1:0] perf_core_writes;
//     reg [`PERF_CTR_BITS-1:0] perf_read_misses;
//     reg [`PERF_CTR_BITS-1:0] perf_write_misses;
//     reg [`PERF_CTR_BITS-1:0] perf_mshr_stalls;
//     reg [`PERF_CTR_BITS-1:0] perf_mem_stalls;
//     reg [`PERF_CTR_BITS-1:0] perf_crsp_stalls;

//     always @(posedge clk) begin
//         if (reset) begin
//             perf_core_reads   <= '0;
//             perf_core_writes  <= '0;
//             perf_read_misses  <= '0;
//             perf_write_misses <= '0;
//             perf_mshr_stalls  <= '0;
//             perf_mem_stalls   <= '0;
//             perf_crsp_stalls  <= '0;
//         end else begin
//             perf_core_reads   <= perf_core_reads   + `PERF_CTR_BITS'(perf_core_reads_per_cycle);
//             perf_core_writes  <= perf_core_writes  + `PERF_CTR_BITS'(perf_core_writes_per_cycle);
//             perf_read_misses  <= perf_read_misses  + `PERF_CTR_BITS'(perf_read_miss_per_cycle);
//             perf_write_misses <= perf_write_misses + `PERF_CTR_BITS'(perf_write_miss_per_cycle);
//             perf_mshr_stalls  <= perf_mshr_stalls  + `PERF_CTR_BITS'(perf_mshr_stall_per_cycle);
//             perf_mem_stalls   <= perf_mem_stalls   + `PERF_CTR_BITS'(perf_mem_stall_per_cycle);
//             perf_crsp_stalls  <= perf_crsp_stalls  + `PERF_CTR_BITS'(perf_crsp_stall_per_cycle);
//         end
//     end

//     assign cache_perf.reads        = perf_core_reads;
//     assign cache_perf.writes       = perf_core_writes;
//     assign cache_perf.read_misses  = perf_read_misses;
//     assign cache_perf.write_misses = perf_write_misses;
//     assign cache_perf.bank_stalls  = perf_collisions;
//     assign cache_perf.mshr_stalls  = perf_mshr_stalls;
//     assign cache_perf.mem_stalls   = perf_mem_stalls;
//     assign cache_perf.crsp_stalls  = perf_crsp_stalls;
// `endif

endmodule
