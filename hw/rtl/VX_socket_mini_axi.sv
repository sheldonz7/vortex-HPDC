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

`include "VX_define.vh"

module VX_socket_mini_axi import VX_gpu_pkg::*; #(
    parameter SOCKET_ID = 0,
    parameter `STRING INSTANCE_ID = "",
    parameter AXI_DATA_WIDTH = `VX_MEM_DATA_WIDTH,
    parameter AXI_ADDR_WIDTH = `MEM_ADDR_WIDTH + (`VX_MEM_DATA_WIDTH/8),
    parameter AXI_TID_WIDTH  = `VX_MEM_TAG_WIDTH,
    parameter AXI_NUM_BANKS  = 2 // one for icache, one for dcache
) (
    `SCOPE_IO_DECL

    // Clock
    input wire              clk,
    input wire              reset,

`ifdef PERF_ENABLE
    VX_mem_perf_if.slave    mem_perf_if,
`endif

    // DCRs
    VX_dcr_bus_if.slave     dcr_bus_if,

    // Memory AXI bus
    // AXI write request address channel
    output wire                         m_axi_awvalid [AXI_NUM_BANKS],
    input wire                          m_axi_awready [AXI_NUM_BANKS],
    output wire [AXI_ADDR_WIDTH-1:0]    m_axi_awaddr [AXI_NUM_BANKS],
    output wire [AXI_TID_WIDTH-1:0]     m_axi_awid [AXI_NUM_BANKS],
    output wire [7:0]                   m_axi_awlen [AXI_NUM_BANKS],
    output wire [2:0]                   m_axi_awsize [AXI_NUM_BANKS],
    output wire [1:0]                   m_axi_awburst [AXI_NUM_BANKS],
    output wire [1:0]                   m_axi_awlock [AXI_NUM_BANKS],
    output wire [3:0]                   m_axi_awcache [AXI_NUM_BANKS],
    output wire [2:0]                   m_axi_awprot [AXI_NUM_BANKS],
    output wire [3:0]                   m_axi_awqos [AXI_NUM_BANKS],
    output wire [3:0]                   m_axi_awregion [AXI_NUM_BANKS],

    // AXI write request data channel
    output wire                         m_axi_wvalid [AXI_NUM_BANKS],
    input wire                          m_axi_wready [AXI_NUM_BANKS],
    output wire [AXI_DATA_WIDTH-1:0]    m_axi_wdata [AXI_NUM_BANKS],
    output wire [AXI_DATA_WIDTH/8-1:0]  m_axi_wstrb [AXI_NUM_BANKS],
    output wire                         m_axi_wlast [AXI_NUM_BANKS],

    // AXI write response channel
    input wire                          m_axi_bvalid [AXI_NUM_BANKS],
    output wire                         m_axi_bready [AXI_NUM_BANKS],
    input wire [AXI_TID_WIDTH-1:0]      m_axi_bid [AXI_NUM_BANKS],
    input wire [1:0]                    m_axi_bresp [AXI_NUM_BANKS],

    // AXI read request channel
    output wire                         m_axi_arvalid [AXI_NUM_BANKS],
    input wire                          m_axi_arready [AXI_NUM_BANKS],
    output wire [AXI_ADDR_WIDTH-1:0]    m_axi_araddr [AXI_NUM_BANKS],
    output wire [AXI_TID_WIDTH-1:0]     m_axi_arid [AXI_NUM_BANKS],
    output wire [7:0]                   m_axi_arlen [AXI_NUM_BANKS],
    output wire [2:0]                   m_axi_arsize [AXI_NUM_BANKS],
    output wire [1:0]                   m_axi_arburst [AXI_NUM_BANKS],
    output wire [1:0]                   m_axi_arlock [AXI_NUM_BANKS],
    output wire [3:0]                   m_axi_arcache [AXI_NUM_BANKS],
    output wire [2:0]                   m_axi_arprot [AXI_NUM_BANKS],
    output wire [3:0]                   m_axi_arqos [AXI_NUM_BANKS],
    output wire [3:0]                   m_axi_arregion [AXI_NUM_BANKS],

    // AXI read response channel
    input wire                          m_axi_rvalid [AXI_NUM_BANKS],
    output wire                         m_axi_rready [AXI_NUM_BANKS],
    input wire [AXI_DATA_WIDTH-1:0]     m_axi_rdata [AXI_NUM_BANKS],
    input wire                          m_axi_rlast [AXI_NUM_BANKS],
    input wire [AXI_TID_WIDTH-1:0]      m_axi_rid [AXI_NUM_BANKS],
    input wire [1:0]                    m_axi_rresp [AXI_NUM_BANKS],

`ifdef GBAR_ENABLE
    // Barrier
    VX_gbar_bus_if.master   gbar_bus_if,
`endif
    // Status
    output wire             busy
);

    localparam ICACHE_AXI_NUM_BANKS = 1;
    localparam DCACHE_AXI_NUM_BANKS = 1;

`ifdef SCOPE
    localparam scope_core = 0;
    `SCOPE_IO_SWITCH (`SOCKET_SIZE);
`endif

`ifdef GBAR_ENABLE
    VX_gbar_bus_if per_core_gbar_bus_if[`SOCKET_SIZE]();

    VX_gbar_arb #(
        .NUM_REQS (`SOCKET_SIZE),
        .OUT_BUF  ((`SOCKET_SIZE > 1) ? 2 : 0)
    ) gbar_arb (
        .clk        (clk),
        .reset      (reset),
        .bus_in_if  (per_core_gbar_bus_if),
        .bus_out_if (gbar_bus_if)
    );
`endif

    ///////////////////////////////////////////////////////////////////////////

`ifdef PERF_ENABLE
    VX_mem_perf_if mem_perf_tmp_if();
    assign mem_perf_tmp_if.l2cache = mem_perf_if.l2cache;
    assign mem_perf_tmp_if.l3cache = mem_perf_if.l3cache;
    assign mem_perf_tmp_if.lmem = 'x;
    assign mem_perf_tmp_if.mem = mem_perf_if.mem;
`endif

    ///////////////////////////////////////////////////////////////////////////

    localparam DST_LDATAW = `CLOG2(AXI_DATA_WIDTH);
    localparam SRC_LDATAW = `CLOG2(`VX_MEM_DATA_WIDTH);
    localparam SUB_LDATAW = DST_LDATAW - SRC_LDATAW;
    localparam VX_MEM_TAG_A_WIDTH  = `VX_MEM_TAG_WIDTH + `MAX(SUB_LDATAW, 0);
    localparam VX_MEM_ADDR_A_WIDTH = `VX_MEM_ADDR_WIDTH - SUB_LDATAW;

    wire                            mem_req_valid;
    wire                            mem_req_rw;
    wire [`VX_MEM_BYTEEN_WIDTH-1:0] mem_req_byteen;
    wire [`VX_MEM_ADDR_WIDTH-1:0]   mem_req_addr;
    wire [`VX_MEM_DATA_WIDTH-1:0]   mem_req_data;
    wire [`VX_MEM_TAG_WIDTH-1:0]    mem_req_tag;
    wire                            mem_req_ready;

    wire                            mem_rsp_valid;
    wire [`VX_MEM_DATA_WIDTH-1:0]   mem_rsp_data;
    wire [`VX_MEM_TAG_WIDTH-1:0]    mem_rsp_tag;
    wire                            mem_rsp_ready;


    // Memory AXI bus
    // AXI write request address channel
     wire                         icache_m_axi_awvalid [AXI_NUM_BANKS];
    wire                          icache_m_axi_awready [AXI_NUM_BANKS];
     wire [AXI_ADDR_WIDTH-1:0]    icache_m_axi_awaddr [AXI_NUM_BANKS];
     wire [AXI_TID_WIDTH-1:0]     icache_m_axi_awid [AXI_NUM_BANKS];
     wire [7:0]                   icache_m_axi_awlen [AXI_NUM_BANKS];
     wire [2:0]                   icache_m_axi_awsize [AXI_NUM_BANKS];
     wire [1:0]                   icache_m_axi_awburst [AXI_NUM_BANKS];
     wire [1:0]                   icache_m_axi_awlock [AXI_NUM_BANKS];
     wire [3:0]                   icache_m_axi_awcache [AXI_NUM_BANKS];
     wire [2:0]                   icache_m_axi_awprot [AXI_NUM_BANKS];
     wire [3:0]                   icache_m_axi_awqos [AXI_NUM_BANKS];
     wire [3:0]                   icache_m_axi_awregion [AXI_NUM_BANKS];

    // AXI write request data channel
     wire                         icache_m_axi_wvalid [AXI_NUM_BANKS];
    wire                          icache_m_axi_wready [AXI_NUM_BANKS];
     wire [AXI_DATA_WIDTH-1:0]    icache_m_axi_wdata [AXI_NUM_BANKS];
     wire [AXI_DATA_WIDTH/8-1:0]  icache_m_axi_wstrb [AXI_NUM_BANKS];
     wire                         icache_m_axi_wlast [AXI_NUM_BANKS];

    // AXI write response channel
    wire                          icache_m_axi_bvalid [AXI_NUM_BANKS];
     wire                         icache_m_axi_bready [AXI_NUM_BANKS];
    wire [AXI_TID_WIDTH-1:0]      icache_m_axi_bid [AXI_NUM_BANKS];
    wire [1:0]                    icache_m_axi_bresp [AXI_NUM_BANKS];

    // AXI read request channel
     wire                         icache_m_axi_arvalid [AXI_NUM_BANKS];
    wire                          icache_m_axi_arready [AXI_NUM_BANKS];
     wire [AXI_ADDR_WIDTH-1:0]    icache_m_axi_araddr [AXI_NUM_BANKS];
     wire [AXI_TID_WIDTH-1:0]     icache_m_axi_arid [AXI_NUM_BANKS];
     wire [7:0]                   icache_m_axi_arlen [AXI_NUM_BANKS];
     wire [2:0]                   icache_m_axi_arsize [AXI_NUM_BANKS];
     wire [1:0]                   icache_m_axi_arburst [AXI_NUM_BANKS];
     wire [1:0]                   icache_m_axi_arlock [AXI_NUM_BANKS];
     wire [3:0]                   icache_m_axi_arcache [AXI_NUM_BANKS];
     wire [2:0]                   icache_m_axi_arprot [AXI_NUM_BANKS];
     wire [3:0]                   icache_m_axi_arqos [AXI_NUM_BANKS];
     wire [3:0]                   icache_m_axi_arregion [AXI_NUM_BANKS];

    // AXI read response channel
    wire                          icache_m_axi_rvalid [AXI_NUM_BANKS];
     wire                         icache_m_axi_rready [AXI_NUM_BANKS];
    wire [AXI_DATA_WIDTH-1:0]     icache_m_axi_rdata [AXI_NUM_BANKS];
    wire                          icache_m_axi_rlast [AXI_NUM_BANKS];
    wire [AXI_TID_WIDTH-1:0]      icache_m_axi_rid [AXI_NUM_BANKS];
    wire [1:0]                    icache_m_axi_rresp [AXI_NUM_BANKS];

    // dcache

     // Memory AXI bus
    // AXI write request address channel
     wire                         dcache_m_axi_awvalid [AXI_NUM_BANKS];
    wire                          dcache_m_axi_awready [AXI_NUM_BANKS];
     wire [AXI_ADDR_WIDTH-1:0]    dcache_m_axi_awaddr [AXI_NUM_BANKS];
     wire [AXI_TID_WIDTH-1:0]     dcache_m_axi_awid [AXI_NUM_BANKS];
     wire [7:0]                   dcache_m_axi_awlen [AXI_NUM_BANKS];
     wire [2:0]                   dcache_m_axi_awsize [AXI_NUM_BANKS];
     wire [1:0]                   dcache_m_axi_awburst [AXI_NUM_BANKS];
     wire [1:0]                   dcache_m_axi_awlock [AXI_NUM_BANKS];
     wire [3:0]                   dcache_m_axi_awcache [AXI_NUM_BANKS];
     wire [2:0]                   dcache_m_axi_awprot [AXI_NUM_BANKS];
     wire [3:0]                   dcache_m_axi_awqos [AXI_NUM_BANKS];
     wire [3:0]                   dcache_m_axi_awregion [AXI_NUM_BANKS];

    // AXI write request data channel
     wire                         dcache_m_axi_wvalid [AXI_NUM_BANKS];
    wire                          dcache_m_axi_wready [AXI_NUM_BANKS];
     wire [AXI_DATA_WIDTH-1:0]    dcache_m_axi_wdata [AXI_NUM_BANKS];
     wire [AXI_DATA_WIDTH/8-1:0]  dcache_m_axi_wstrb [AXI_NUM_BANKS];
     wire                         dcache_m_axi_wlast [AXI_NUM_BANKS];

    // AXI write response channel
    wire                          dcache_m_axi_bvalid [AXI_NUM_BANKS];
     wire                         dcache_m_axi_bready [AXI_NUM_BANKS];
    wire [AXI_TID_WIDTH-1:0]      dcache_m_axi_bid [AXI_NUM_BANKS];
    wire [1:0]                    dcache_m_axi_bresp [AXI_NUM_BANKS];

    // AXI read request channel
     wire                         dcache_m_axi_arvalid [AXI_NUM_BANKS];
    wire                          dcache_m_axi_arready [AXI_NUM_BANKS];
     wire [AXI_ADDR_WIDTH-1:0]    dcache_m_axi_araddr [AXI_NUM_BANKS];
     wire [AXI_TID_WIDTH-1:0]     dcache_m_axi_arid [AXI_NUM_BANKS];
     wire [7:0]                   dcache_m_axi_arlen [AXI_NUM_BANKS];
     wire [2:0]                   dcache_m_axi_arsize [AXI_NUM_BANKS];
     wire [1:0]                   dcache_m_axi_arburst [AXI_NUM_BANKS];
     wire [1:0]                   dcache_m_axi_arlock [AXI_NUM_BANKS];
     wire [3:0]                   dcache_m_axi_arcache [AXI_NUM_BANKS];
     wire [2:0]                   dcache_m_axi_arprot [AXI_NUM_BANKS];
     wire [3:0]                   dcache_m_axi_arqos [AXI_NUM_BANKS];
     wire [3:0]                   dcache_m_axi_arregion [AXI_NUM_BANKS];

    // AXI read response channel
    wire                          dcache_m_axi_rvalid [AXI_NUM_BANKS];
     wire                         dcache_m_axi_rready [AXI_NUM_BANKS];
    wire [AXI_DATA_WIDTH-1:0]     dcache_m_axi_rdata [AXI_NUM_BANKS];
    wire                          dcache_m_axi_rlast [AXI_NUM_BANKS];
    wire [AXI_TID_WIDTH-1:0]      dcache_m_axi_rid [AXI_NUM_BANKS];
    wire [1:0]                    dcache_m_axi_rresp [AXI_NUM_BANKS];


    VX_mem_bus_if #(
        .DATA_SIZE (ICACHE_WORD_SIZE),
        .TAG_WIDTH (ICACHE_TAG_WIDTH)
    ) per_core_icache_bus_if[`SOCKET_SIZE]();

    VX_mem_bus_if #(
        .DATA_SIZE (ICACHE_LINE_SIZE),
        .TAG_WIDTH (ICACHE_MEM_TAG_WIDTH)
    ) icache_mem_bus_if();

    `RESET_RELAY (icache_reset, reset);

    VX_cache_cluster #(
        .INSTANCE_ID    (`SFORMATF(("%s-icache", INSTANCE_ID))),
        .NUM_UNITS      (`NUM_ICACHES),
        .NUM_INPUTS     (`SOCKET_SIZE),
        .TAG_SEL_IDX    (0),
        .CACHE_SIZE     (`ICACHE_SIZE),
        .LINE_SIZE      (ICACHE_LINE_SIZE),
        .NUM_BANKS      (1),
        .NUM_WAYS       (`ICACHE_NUM_WAYS),
        .WORD_SIZE      (ICACHE_WORD_SIZE),
        .NUM_REQS       (1),
        .CRSQ_SIZE      (`ICACHE_CRSQ_SIZE),
        .MSHR_SIZE      (`ICACHE_MSHR_SIZE),
        .MRSQ_SIZE      (`ICACHE_MRSQ_SIZE),
        .MREQ_SIZE      (`ICACHE_MREQ_SIZE),
        .TAG_WIDTH      (ICACHE_TAG_WIDTH),
        .FLAGS_WIDTH    (0),
        .UUID_WIDTH     (`UUID_WIDTH),
        .WRITE_ENABLE   (0),
        .REPL_POLICY    (`ICACHE_REPL_POLICY),
        .NC_ENABLE      (0),
        .CORE_OUT_BUF   (3),
        .MEM_OUT_BUF    (2)
    ) icache (
    `ifdef PERF_ENABLE
        .cache_perf     (mem_perf_tmp_if.icache),
    `endif
        .clk            (clk),
        .reset          (icache_reset),
        .core_bus_if    (per_core_icache_bus_if),
        .mem_bus_if     (icache_mem_bus_if)
    );

    assign mem_req_valid = icache_mem_bus_if.req_valid;
    assign mem_req_rw    = icache_mem_bus_if.req_data.rw;
    assign mem_req_byteen= icache_mem_bus_if.req_data.byteen;
    assign mem_req_addr  = icache_mem_bus_if.req_data.addr;
    assign mem_req_data  = icache_mem_bus_if.req_data.data;
    assign mem_req_tag   = icache_mem_bus_if.req_data.tag;
    assign icache_mem_bus_if.req_ready = mem_req_ready;
    `UNUSED_VAR (icache_mem_bus_if.req_data.flags)

    assign icache_mem_bus_if.rsp_valid = mem_rsp_valid;
    assign icache_mem_bus_if.rsp_data.data  = mem_rsp_data;
    assign icache_mem_bus_if.rsp_data.tag   = mem_rsp_tag;
    assign mem_rsp_ready = icache_mem_bus_if.rsp_ready;

    



    wire                            mem_req_valid_a;
    wire                            mem_req_rw_a;
    wire [(AXI_DATA_WIDTH/8)-1:0]   mem_req_byteen_a;
    wire [VX_MEM_ADDR_A_WIDTH-1:0]  mem_req_addr_a;
    wire [AXI_DATA_WIDTH-1:0]       mem_req_data_a;
    wire [VX_MEM_TAG_A_WIDTH-1:0]   mem_req_tag_a;
    wire                            mem_req_ready_a;

    wire                            mem_rsp_valid_a;
    wire [AXI_DATA_WIDTH-1:0]       mem_rsp_data_a;
    wire [VX_MEM_TAG_A_WIDTH-1:0]   mem_rsp_tag_a;
    wire                            mem_rsp_ready_a;

    VX_mem_adapter #(
        .SRC_DATA_WIDTH (`VX_MEM_DATA_WIDTH),
        .DST_DATA_WIDTH (AXI_DATA_WIDTH),
        .SRC_ADDR_WIDTH (`VX_MEM_ADDR_WIDTH),
        .DST_ADDR_WIDTH (VX_MEM_ADDR_A_WIDTH),
        .SRC_TAG_WIDTH  (`VX_MEM_TAG_WIDTH),
        .DST_TAG_WIDTH  (VX_MEM_TAG_A_WIDTH),
        .REQ_OUT_BUF    (0),
        .RSP_OUT_BUF    (0)
    ) mem_adapter (
        .clk                (clk),
        .reset              (reset),

        .mem_req_valid_in   (mem_req_valid),
        .mem_req_addr_in    (mem_req_addr),
        .mem_req_rw_in      (mem_req_rw),
        .mem_req_byteen_in  (mem_req_byteen),
        .mem_req_data_in    (mem_req_data),
        .mem_req_tag_in     (mem_req_tag),
        .mem_req_ready_in   (mem_req_ready),

        .mem_rsp_valid_in   (mem_rsp_valid),
        .mem_rsp_data_in    (mem_rsp_data),
        .mem_rsp_tag_in     (mem_rsp_tag),
        .mem_rsp_ready_in   (mem_rsp_ready),

        .mem_req_valid_out  (mem_req_valid_a),
        .mem_req_addr_out   (mem_req_addr_a),
        .mem_req_rw_out     (mem_req_rw_a),
        .mem_req_byteen_out (mem_req_byteen_a),
        .mem_req_data_out   (mem_req_data_a),
        .mem_req_tag_out    (mem_req_tag_a),
        .mem_req_ready_out  (mem_req_ready_a),

        .mem_rsp_valid_out  (mem_rsp_valid_a),
        .mem_rsp_data_out   (mem_rsp_data_a),
        .mem_rsp_tag_out    (mem_rsp_tag_a),
        .mem_rsp_ready_out  (mem_rsp_ready_a)
    );

    VX_axi_adapter #(
        .DATA_WIDTH     (AXI_DATA_WIDTH),
        .ADDR_WIDTH_IN  (VX_MEM_ADDR_A_WIDTH),
        .ADDR_WIDTH_OUT (AXI_ADDR_WIDTH),
        .TAG_WIDTH_IN   (VX_MEM_TAG_A_WIDTH),
        .TAG_WIDTH_OUT  (AXI_TID_WIDTH),
        .NUM_BANKS      (ICACHE_AXI_NUM_BANKS),
        .BANK_INTERLEAVE(0),
        .RSP_OUT_BUF    ((ICACHE_AXI_NUM_BANKS > 1) ? 2 : 0)
    ) mem_adapter_icache (
        .clk            (clk),
        .reset          (reset),

        .mem_req_valid  (mem_req_valid_a),
        .mem_req_rw     (mem_req_rw_a),
        .mem_req_byteen (mem_req_byteen_a),
        .mem_req_addr   (mem_req_addr_a),
        .mem_req_data   (mem_req_data_a),
        .mem_req_tag    (mem_req_tag_a),
        .mem_req_ready  (mem_req_ready_a),

        .mem_rsp_valid  (mem_rsp_valid_a),
        .mem_rsp_data   (mem_rsp_data_a),
        .mem_rsp_tag    (mem_rsp_tag_a),
        .mem_rsp_ready  (mem_rsp_ready_a),

        .m_axi_awvalid  (icache_m_axi_awvalid),
        .m_axi_awready  (icache_m_axi_awready),
        .m_axi_awaddr   (icache_m_axi_awaddr),
        .m_axi_awid     (icache_m_axi_awid),
        .m_axi_awlen    (icache_m_axi_awlen),
        .m_axi_awsize   (icache_m_axi_awsize),
        .m_axi_awburst  (icache_m_axi_awburst),
        .m_axi_awlock   (icache_m_axi_awlock),
        .m_axi_awcache  (icache_m_axi_awcache),
        .m_axi_awprot   (icache_m_axi_awprot),
        .m_axi_awqos    (icache_m_axi_awqos),
        .m_axi_awregion (icache_m_axi_awregion),

        .m_axi_wvalid   (icache_m_axi_wvalid),
        .m_axi_wready   (icache_m_axi_wready),
        .m_axi_wdata    (icache_m_axi_wdata),
        .m_axi_wstrb    (icache_m_axi_wstrb),
        .m_axi_wlast    (icache_m_axi_wlast),

        .m_axi_bvalid   (icache_m_axi_bvalid),
        .m_axi_bready   (icache_m_axi_bready),
        .m_axi_bid      (icache_m_axi_bid),
        .m_axi_bresp    (icache_m_axi_bresp),

        .m_axi_arvalid  (icache_m_axi_arvalid),
        .m_axi_arready  (icache_m_axi_arready),
        .m_axi_araddr   (icache_m_axi_araddr),
        .m_axi_arid     (icache_m_axi_arid),
        .m_axi_arlen    (icache_m_axi_arlen),
        .m_axi_arsize   (icache_m_axi_arsize),
        .m_axi_arburst  (icache_m_axi_arburst),
        .m_axi_arlock   (icache_m_axi_arlock),
        .m_axi_arcache  (icache_m_axi_arcache),
        .m_axi_arprot   (icache_m_axi_arprot),
        .m_axi_arqos    (icache_m_axi_arqos),
        .m_axi_arregion (icache_m_axi_arregion),

        .m_axi_rvalid   (icache_m_axi_rvalid),
        .m_axi_rready   (icache_m_axi_rready),
        .m_axi_rdata    (icache_m_axi_rdata),
        .m_axi_rlast    (icache_m_axi_rlast),
        .m_axi_rid      (icache_m_axi_rid),
        .m_axi_rresp    (icache_m_axi_rresp)
    );


    ///////////////////////////////////////////////////////////////////////////

    VX_mem_bus_if #(
        .DATA_SIZE (DCACHE_WORD_SIZE),
        .TAG_WIDTH (DCACHE_TAG_WIDTH)
    ) per_core_dcache_bus_if[`SOCKET_SIZE * DCACHE_NUM_REQS]();

    VX_mem_bus_if #(
        .DATA_SIZE (DCACHE_LINE_SIZE),
        .TAG_WIDTH (DCACHE_MEM_TAG_WIDTH)
    ) dcache_mem_bus_if();

    `RESET_RELAY (dcache_reset, reset);


    wire                            dcache_mem_req_valid;
    wire                            dcache_mem_req_rw;
    wire [`VX_MEM_BYTEEN_WIDTH-1:0] dcache_mem_req_byteen;
    wire [`VX_MEM_ADDR_WIDTH-1:0]   dcache_mem_req_addr;
    wire [`VX_MEM_DATA_WIDTH-1:0]   dcache_mem_req_data;
    wire [`VX_MEM_TAG_WIDTH-1:0]    dcache_mem_req_tag;
    wire                            dcache_mem_req_ready;

    wire                            dcache_mem_rsp_valid;
    wire [`VX_MEM_DATA_WIDTH-1:0]   dcache_mem_rsp_data;
    wire [`VX_MEM_TAG_WIDTH-1:0]    dcache_mem_rsp_tag;
    wire                            dcache_mem_rsp_ready;


    VX_cache_cluster #(
        .INSTANCE_ID    (`SFORMATF(("%s-dcache", INSTANCE_ID))),
        .NUM_UNITS      (`NUM_DCACHES),
        .NUM_INPUTS     (`SOCKET_SIZE),
        .TAG_SEL_IDX    (0),
        .CACHE_SIZE     (`DCACHE_SIZE),
        .LINE_SIZE      (DCACHE_LINE_SIZE),
        .NUM_BANKS      (`DCACHE_NUM_BANKS),
        .NUM_WAYS       (`DCACHE_NUM_WAYS),
        .WORD_SIZE      (DCACHE_WORD_SIZE),
        .NUM_REQS       (DCACHE_NUM_REQS),
        .CRSQ_SIZE      (`DCACHE_CRSQ_SIZE),
        .MSHR_SIZE      (`DCACHE_MSHR_SIZE),
        .MRSQ_SIZE      (`DCACHE_MRSQ_SIZE),
        .MREQ_SIZE      (`DCACHE_WRITEBACK ? `DCACHE_MSHR_SIZE : `DCACHE_MREQ_SIZE),
        .TAG_WIDTH      (DCACHE_TAG_WIDTH),
        .UUID_WIDTH     (`UUID_WIDTH),
        .FLAGS_WIDTH    (`MEM_REQ_FLAGS_WIDTH),
        .WRITE_ENABLE   (1),
        .WRITEBACK      (`DCACHE_WRITEBACK),
        .DIRTY_BYTES    (`DCACHE_DIRTYBYTES),
        .REPL_POLICY    (`DCACHE_REPL_POLICY),
        .NC_ENABLE      (1),
        .CORE_OUT_BUF   (3),
        .MEM_OUT_BUF    (2),
        .ENABLE_HPDCACHE (`ENABLE_HPDCACHE)
    ) dcache (
    `ifdef PERF_ENABLE
        .cache_perf     (mem_perf_tmp_if.dcache),
    `endif
        .clk            (clk),
        .reset          (dcache_reset),
        .core_bus_if    (per_core_dcache_bus_if),
        .mem_bus_if     (dcache_mem_bus_if)

    );

    assign dcache_mem_req_valid = dcache_mem_bus_if.req_valid;
    assign dcache_mem_req_rw    = dcache_mem_bus_if.req_data.rw;
    assign dcache_mem_req_byteen= dcache_mem_bus_if.req_data.byteen;
    assign dcache_mem_req_addr  = dcache_mem_bus_if.req_data.addr;
    assign dcache_mem_req_data  = dcache_mem_bus_if.req_data.data;
    assign dcache_mem_req_tag   = dcache_mem_bus_if.req_data.tag;
    assign dcache_mem_bus_if.req_ready = dcache_mem_req_ready;
    `UNUSED_VAR (dcache_mem_bus_if.req_data.flags)

    assign dcache_mem_bus_if.rsp_valid = dcache_mem_rsp_valid;
    assign dcache_mem_bus_if.rsp_data.data  = dcache_mem_rsp_data;
    assign dcache_mem_bus_if.rsp_data.tag   = dcache_mem_rsp_tag;
    assign dcache_mem_rsp_ready = dcache_mem_bus_if.rsp_ready;


    wire                            dcache_mem_req_valid_a;
    wire                            dcache_mem_req_rw_a;
    wire [(AXI_DATA_WIDTH/8)-1:0]   dcache_mem_req_byteen_a;
    wire [VX_MEM_ADDR_A_WIDTH-1:0]  dcache_mem_req_addr_a;
    wire [AXI_DATA_WIDTH-1:0]       dcache_mem_req_data_a;
    wire [VX_MEM_TAG_A_WIDTH-1:0]   dcache_mem_req_tag_a;
    wire                            dcache_mem_req_ready_a;

    wire                            dcache_mem_rsp_valid_a;
    wire [AXI_DATA_WIDTH-1:0]       dcache_mem_rsp_data_a;
    wire [VX_MEM_TAG_A_WIDTH-1:0]   dcache_mem_rsp_tag_a;
    wire                            dcache_mem_rsp_ready_a;

    VX_mem_adapter #(
        .SRC_DATA_WIDTH (`VX_MEM_DATA_WIDTH),
        .DST_DATA_WIDTH (AXI_DATA_WIDTH),
        .SRC_ADDR_WIDTH (`VX_MEM_ADDR_WIDTH),
        .DST_ADDR_WIDTH (VX_MEM_ADDR_A_WIDTH),
        .SRC_TAG_WIDTH  (`VX_MEM_TAG_WIDTH),
        .DST_TAG_WIDTH  (VX_MEM_TAG_A_WIDTH),
        .REQ_OUT_BUF    (0),
        .RSP_OUT_BUF    (0)
    ) mem_adapter_dcache (
        .clk                (clk),
        .reset              (reset),

        .mem_req_valid_in   (dcache_mem_req_valid),
        .mem_req_addr_in    (dcache_mem_req_addr),
        .mem_req_rw_in      (dcache_mem_req_rw),
        .mem_req_byteen_in  (dcache_mem_req_byteen),
        .mem_req_data_in    (dcache_mem_req_data),
        .mem_req_tag_in     (dcache_mem_req_tag),
        .mem_req_ready_in   (dcache_mem_req_ready),

        .mem_rsp_valid_in   (dcache_mem_rsp_valid),
        .mem_rsp_data_in    (dcache_mem_rsp_data),
        .mem_rsp_tag_in     (dcache_mem_rsp_tag),
        .mem_rsp_ready_in   (dcache_mem_rsp_ready),

        .mem_req_valid_out  (dcache_mem_req_valid_a),
        .mem_req_addr_out   (dcache_mem_req_addr_a),
        .mem_req_rw_out     (dcache_mem_req_rw_a),
        .mem_req_byteen_out (dcache_mem_req_byteen_a),
        .mem_req_data_out   (dcache_mem_req_data_a),
        .mem_req_tag_out    (dcache_mem_req_tag_a),
        .mem_req_ready_out  (dcache_mem_req_ready_a),

        .mem_rsp_valid_out  (dcache_mem_rsp_valid_a),
        .mem_rsp_data_out   (dcache_mem_rsp_data_a),
        .mem_rsp_tag_out    (dcache_mem_rsp_tag_a),
        .mem_rsp_ready_out  (dcache_mem_rsp_ready_a)
    );

    VX_axi_adapter #(
        .DATA_WIDTH     (AXI_DATA_WIDTH),
        .ADDR_WIDTH_IN  (VX_MEM_ADDR_A_WIDTH),
        .ADDR_WIDTH_OUT (AXI_ADDR_WIDTH),
        .TAG_WIDTH_IN   (VX_MEM_TAG_A_WIDTH),
        .TAG_WIDTH_OUT  (AXI_TID_WIDTH),
        .NUM_BANKS      (AXI_NUM_BANKS),
        .BANK_INTERLEAVE(0),
        .RSP_OUT_BUF    ((AXI_NUM_BANKS > 1) ? 2 : 0)
    ) axi_adapter (
        .clk            (clk),
        .reset          (reset),

        .mem_req_valid  (dcache_mem_req_valid_a),
        .mem_req_rw     (dcache_mem_req_rw_a),
        .mem_req_byteen (dcache_mem_req_byteen_a),
        .mem_req_addr   (dcache_mem_req_addr_a),
        .mem_req_data   (dcache_mem_req_data_a),
        .mem_req_tag    (dcache_mem_req_tag_a),
        .mem_req_ready  (dcache_mem_req_ready_a),

        .mem_rsp_valid  (dcache_mem_rsp_valid_a),
        .mem_rsp_data   (dcache_mem_rsp_data_a),
        .mem_rsp_tag    (dcache_mem_rsp_tag_a),
        .mem_rsp_ready  (dcache_mem_rsp_ready_a),

        .m_axi_awvalid  (dcache_m_axi_awvalid),
        .m_axi_awready  (dcache_m_axi_awready),
        .m_axi_awaddr   (dcache_m_axi_awaddr),
        .m_axi_awid     (dcache_m_axi_awid),
        .m_axi_awlen    (dcache_m_axi_awlen),
        .m_axi_awsize   (dcache_m_axi_awsize),
        .m_axi_awburst  (dcache_m_axi_awburst),
        .m_axi_awlock   (dcache_m_axi_awlock),
        .m_axi_awcache  (dcache_m_axi_awcache),
        .m_axi_awprot   (dcache_m_axi_awprot),
        .m_axi_awqos    (dcache_m_axi_awqos),
        .m_axi_awregion (dcache_m_axi_awregion),

        .m_axi_wvalid   (dcache_m_axi_wvalid),
        .m_axi_wready   (dcache_m_axi_wready),
        .m_axi_wdata    (dcache_m_axi_wdata),
        .m_axi_wstrb    (dcache_m_axi_wstrb),
        .m_axi_wlast    (dcache_m_axi_wlast),

        .m_axi_bvalid   (dcache_m_axi_bvalid),
        .m_axi_bready   (dcache_m_axi_bready),
        .m_axi_bid      (dcache_m_axi_bid), 
        .m_axi_bresp    (dcache_m_axi_bresp),

        .m_axi_arvalid  (dcache_m_axi_arvalid),
        .m_axi_arready  (dcache_m_axi_arready),
        .m_axi_araddr   (dcache_m_axi_araddr),
        .m_axi_arid     (dcache_m_axi_arid),
        .m_axi_arlen    (dcache_m_axi_arlen),
        .m_axi_arsize   (dcache_m_axi_arsize),
        .m_axi_arburst  (dcache_m_axi_arburst),
        .m_axi_arlock   (dcache_m_axi_arlock),
        .m_axi_arcache  (dcache_m_axi_arcache),
        .m_axi_arprot   (dcache_m_axi_arprot),
        .m_axi_arqos    (dcache_m_axi_arqos),
        .m_axi_arregion (dcache_m_axi_arregion),

        .m_axi_rvalid   (dcache_m_axi_rvalid),
        .m_axi_rready   (dcache_m_axi_rready),
        .m_axi_rdata    (dcache_m_axi_rdata),
        .m_axi_rlast    (dcache_m_axi_rlast),
        .m_axi_rid      (dcache_m_axi_rid),
        .m_axi_rresp    (dcache_m_axi_rresp)
    );


    ///////////////////////////////////////////////////////////////////////////

    // VX_mem_bus_if #(
    //     .DATA_SIZE (`L1_LINE_SIZE),
    //     .TAG_WIDTH (L1_MEM_TAG_WIDTH)
    // ) l1_mem_bus_if[2]();

    // VX_mem_bus_if #(
    //     .DATA_SIZE (`L1_LINE_SIZE),
    //     .TAG_WIDTH (L1_MEM_ARB_TAG_WIDTH)
    // ) l1_mem_arb_bus_if[1]();

    // `ASSIGN_VX_MEM_BUS_IF_X (l1_mem_bus_if[0], icache_mem_bus_if, L1_MEM_TAG_WIDTH, ICACHE_MEM_TAG_WIDTH);
    // `ASSIGN_VX_MEM_BUS_IF_X (l1_mem_bus_if[1], dcache_mem_bus_if, L1_MEM_TAG_WIDTH, DCACHE_MEM_TAG_WIDTH);

    // VX_mem_arb #(
    //     .NUM_INPUTS (2),
    //     .DATA_SIZE  (`L1_LINE_SIZE),
    //     .TAG_WIDTH  (L1_MEM_TAG_WIDTH),
    //     .TAG_SEL_IDX(0),
    //     .ARBITER    ("P"), // prioritize the icache
    //     .REQ_OUT_BUF(3),
    //     .RSP_OUT_BUF(3)
    // ) mem_arb (
    //     .clk        (clk),
    //     .reset      (reset),
    //     .bus_in_if  (l1_mem_bus_if),
    //     .bus_out_if (l1_mem_arb_bus_if)
    // );

    // `ASSIGN_VX_MEM_BUS_IF (mem_bus_if, l1_mem_arb_bus_if[0]);

 
 
    for (genvar bank_id = 0; bank_id < AXI_NUM_BANKS; ++bank_id) begin: axi_arb
        VX_axi_read_mem_arb #(
            .TAG_SEL_IDX(0),
            .ARBITER    ("P"), // prioritize the icache
            .REQ_OUT_BUF(3),
            .RSP_OUT_BUF(3),
            .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
            .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
            .AXI_TID_WIDTH(AXI_TID_WIDTH)
        ) read_mem_arb (
            .clk        (clk),
            .reset      (reset),

            .m_axi_arvalid_0  (icache_m_axi_arvalid[bank_id]),
            .m_axi_arready_0  (icache_m_axi_arready[bank_id]),
            .m_axi_araddr_0   (icache_m_axi_araddr[bank_id]),
            .m_axi_arid_0     (icache_m_axi_arid[bank_id]),
            .m_axi_arlen_0    (icache_m_axi_arlen[bank_id]),
            .m_axi_arsize_0   (icache_m_axi_arsize[bank_id]),
            .m_axi_arburst_0  (icache_m_axi_arburst[bank_id]),
            .m_axi_arlock_0   (icache_m_axi_arlock[bank_id]),
            .m_axi_arcache_0  (icache_m_axi_arcache[bank_id]),
            .m_axi_arprot_0   (icache_m_axi_arprot[bank_id]),
            .m_axi_arqos_0    (icache_m_axi_arqos[bank_id]),
            .m_axi_arregion_0 (icache_m_axi_arregion[bank_id]),

            .m_axi_rvalid_0   (icache_m_axi_rvalid[bank_id]),
            .m_axi_rready_0   (icache_m_axi_rready[bank_id]),
            .m_axi_rdata_0    (icache_m_axi_rdata[bank_id]),
            .m_axi_rlast_0    (icache_m_axi_rlast[bank_id]),
            .m_axi_rid_0      (icache_m_axi_rid[bank_id]),
            .m_axi_rresp_0    (icache_m_axi_rresp[bank_id]),

            .m_axi_arvalid_1  (dcache_m_axi_arvalid[bank_id]),
            .m_axi_arready_1  (dcache_m_axi_arready[bank_id]),
            .m_axi_araddr_1   (dcache_m_axi_araddr[bank_id]),
            .m_axi_arid_1     (dcache_m_axi_arid[bank_id]),
            .m_axi_arlen_1    (dcache_m_axi_arlen[bank_id]),
            .m_axi_arsize_1   (dcache_m_axi_arsize[bank_id]),
            .m_axi_arburst_1  (dcache_m_axi_arburst[bank_id]),
            .m_axi_arlock_1   (dcache_m_axi_arlock[bank_id]),
            .m_axi_arcache_1  (dcache_m_axi_arcache[bank_id]),
            .m_axi_arprot_1   (dcache_m_axi_arprot[bank_id]),
            .m_axi_arqos_1    (dcache_m_axi_arqos[bank_id]),
            .m_axi_arregion_1 (dcache_m_axi_arregion[bank_id]),

            .m_axi_rvalid_1   (dcache_m_axi_rvalid[bank_id]),
            .m_axi_rready_1   (dcache_m_axi_rready[bank_id]),
            .m_axi_rdata_1    (dcache_m_axi_rdata[bank_id]),
            .m_axi_rlast_1    (dcache_m_axi_rlast[bank_id]),
            .m_axi_rid_1      (dcache_m_axi_rid[bank_id]),
            .m_axi_rresp_1    (dcache_m_axi_rresp[bank_id]),

            .m_axi_arvalid    (m_axi_araddr[bank_id]),
            .m_axi_arready    (m_axi_arready[bank_id]),    
            .m_axi_araddr     (m_axi_araddr[bank_id]),
            .m_axi_arid       (m_axi_arid[bank_id]),
            .m_axi_arlen      (m_axi_arlen[bank_id]),
            .m_axi_arsize     (m_axi_arsize[bank_id]),
            .m_axi_arburst    (m_axi_arburst[bank_id]),
            .m_axi_arlock     (m_axi_arlock[bank_id]),
            .m_axi_arcache    (m_axi_arcache[bank_id]),
            .m_axi_arprot     (m_axi_arprot[bank_id]),
            .m_axi_arqos      (m_axi_arqos[bank_id]),
            .m_axi_arregion   (m_axi_arregion[bank_id]),

            .m_axi_rvalid     (m_axi_rvalid[bank_id]),
            .m_axi_rready     (m_axi_rready[bank_id]),
            .m_axi_rdata      (m_axi_rdata[bank_id]),
            .m_axi_rlast      (m_axi_rlast[bank_id]),
            .m_axi_rid        (m_axi_rid[bank_id]),
            .m_axi_rresp      (m_axi_rresp[bank_id])
        );
    
        VX_axi_write_mem_arb #(
            .TAG_SEL_IDX(0),
            .ARBITER    ("P"), // prioritize the icache
            .REQ_OUT_BUF(3),
            .RSP_OUT_BUF(3),
            .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
            .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
            .AXI_TID_WIDTH(AXI_TID_WIDTH)
        ) write_mem_arb (
            .clk        (clk),
            .reset      (reset),

            // write request address channel
            .m_axi_awvalid_0  (icache_m_axi_awvalid[bank_id]),
            .m_axi_awready_0  (icache_m_axi_awready[bank_id]),
            .m_axi_awaddr_0   (icache_m_axi_awaddr[bank_id]),
            .m_axi_awid_0     (icache_m_axi_awid[bank_id]),
            .m_axi_awlen_0    (icache_m_axi_awlen[bank_id]),
            .m_axi_awsize_0   (icache_m_axi_awsize[bank_id]),
            .m_axi_awburst_0  (icache_m_axi_awburst[bank_id]),
            .m_axi_awlock_0   (icache_m_axi_awlock[bank_id]),
            .m_axi_awcache_0  (icache_m_axi_awcache[bank_id]),
            .m_axi_awprot_0   (icache_m_axi_awprot[bank_id]),
            .m_axi_awqos_0    (icache_m_axi_awqos[bank_id]),
            .m_axi_awregion_0 (icache_m_axi_awregion[bank_id]),
            // write request data channel
            .m_axi_wvalid_0   (icache_m_axi_wvalid[bank_id]),
            .m_axi_wready_0   (icache_m_axi_wready[bank_id]),
            .m_axi_wdata_0    (icache_m_axi_wdata[bank_id]),
            .m_axi_wstrb_0    (icache_m_axi_wstrb[bank_id]),
            .m_axi_wlast_0    (icache_m_axi_wlast[bank_id]),
            // write response channel
            .m_axi_bvalid_0   (icache_m_axi_bvalid[bank_id]),
            .m_axi_bready_0   (icache_m_axi_bready[bank_id]),
            .m_axi_bid_0      (icache_m_axi_bid[bank_id]),
            .m_axi_bresp_0    (icache_m_axi_bresp[bank_id]),

            // write request address channel
            .m_axi_awvalid_1  (dcache_m_axi_awvalid[bank_id]),
            .m_axi_awready_1  (dcache_m_axi_awready[bank_id]),
            .m_axi_awaddr_1   (dcache_m_axi_awaddr[bank_id]),
            .m_axi_awid_1     (dcache_m_axi_awid[bank_id]),
            .m_axi_awlen_1    (dcache_m_axi_awlen[bank_id]),
            .m_axi_awsize_1   (dcache_m_axi_awsize[bank_id]),
            .m_axi_awburst_1  (dcache_m_axi_awburst[bank_id]),
            .m_axi_awlock_1   (dcache_m_axi_awlock[bank_id]),
            .m_axi_awcache_1  (dcache_m_axi_awcache[bank_id]),
            .m_axi_awprot_1   (dcache_m_axi_awprot[bank_id]),
            .m_axi_awqos_1    (dcache_m_axi_awqos[bank_id]),
            .m_axi_awregion_1 (dcache_m_axi_awregion[bank_id]),

            // write request data channel
            .m_axi_wvalid_1   (dcache_m_axi_wvalid[bank_id]),
            .m_axi_wready_1   (dcache_m_axi_wready[bank_id]),
            .m_axi_wdata_1    (dcache_m_axi_wdata[bank_id]),
            .m_axi_wstrb_1    (dcache_m_axi_wstrb[bank_id]),
            .m_axi_wlast_1    (dcache_m_axi_wlast[bank_id]),

            // write response channel
            .m_axi_bvalid_1   (dcache_m_axi_bvalid[bank_id]),
            .m_axi_bready_1   (dcache_m_axi_bready[bank_id]),
            .m_axi_bid_1      (dcache_m_axi_bid[bank_id]),
            .m_axi_bresp_1    (dcache_m_axi_bresp[bank_id]),

            // write request address channel
            .m_axi_awvalid    (m_axi_awaddr[bank_id]),
            .m_axi_awready    (m_axi_awready[bank_id]),
            .m_axi_awaddr     (m_axi_awaddr[bank_id]),
            .m_axi_awid       (m_axi_awid[bank_id]),
            .m_axi_awlen      (m_axi_awlen[bank_id]),
            .m_axi_awsize     (m_axi_awsize[bank_id]),
            .m_axi_awburst    (m_axi_awburst[bank_id]),
            .m_axi_awlock     (m_axi_awlock[bank_id]),
            .m_axi_awcache    (m_axi_awcache[bank_id]),
            .m_axi_awprot     (m_axi_awprot[bank_id]),
            .m_axi_awqos      (m_axi_awqos[bank_id]),
            .m_axi_awregion   (m_axi_awregion[bank_id]),

            // write request data channel
            .m_axi_wvalid     (m_axi_wvalid[bank_id]),
            .m_axi_wready     (m_axi_wready[bank_id]),
            .m_axi_wdata      (m_axi_wdata[bank_id]),
            .m_axi_wstrb      (m_axi_wstrb[bank_id]),
            .m_axi_wlast      (m_axi_wlast[bank_id]),

            // write response channel
            .m_axi_bvalid     (m_axi_bvalid[bank_id]),
            .m_axi_bready     (m_axi_bready[bank_id]),
            .m_axi_bid        (m_axi_bid[bank_id]),
            .m_axi_bresp      (m_axi_bresp[bank_id])

        );
    end
    ///////////////////////////////////////////////////////////////////////////

    wire [`SOCKET_SIZE-1:0] per_core_busy;

    // Generate all cores
    for (genvar core_id = 0; core_id < `SOCKET_SIZE; ++core_id) begin : g_cores

        `RESET_RELAY (core_reset, reset);

        VX_dcr_bus_if core_dcr_bus_if();
        `BUFFER_DCR_BUS_IF (core_dcr_bus_if, dcr_bus_if, 1'b1, (`SOCKET_SIZE > 1))

        VX_core #(
            .CORE_ID  ((SOCKET_ID * `SOCKET_SIZE) + core_id),
            .INSTANCE_ID (`SFORMATF(("%s-core%0d", INSTANCE_ID, core_id)))
        ) core (
            `SCOPE_IO_BIND  (scope_core + core_id)

            .clk            (clk),
            .reset          (core_reset),

        `ifdef PERF_ENABLE
            .mem_perf_if    (mem_perf_tmp_if),
        `endif

            .dcr_bus_if     (core_dcr_bus_if),

            .dcache_bus_if  (per_core_dcache_bus_if[core_id * DCACHE_NUM_REQS +: DCACHE_NUM_REQS]),

            .icache_bus_if  (per_core_icache_bus_if[core_id]),

        `ifdef GBAR_ENABLE
            .gbar_bus_if    (per_core_gbar_bus_if[core_id]),
        `endif

            .busy           (per_core_busy[core_id])
        );
    end

    `BUFFER_EX(busy, (| per_core_busy), 1'b1, 1, (`SOCKET_SIZE > 1));

endmodule
