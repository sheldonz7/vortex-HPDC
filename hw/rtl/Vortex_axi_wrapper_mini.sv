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

module Vortex_axi_wrapper_mini import VX_gpu_pkg::*; #(
    parameter AXI_DATA_WIDTH = `VX_MEM_DATA_WIDTH,
    parameter AXI_ADDR_WIDTH = `MEM_ADDR_WIDTH + (`VX_MEM_DATA_WIDTH/8),
    parameter AXI_TID_WIDTH  = `VX_MEM_TAG_WIDTH,
    parameter AXI_NUM_BANKS  = 2
)(
    `SCOPE_IO_DECL

    // Clock
    input  wire                         clk,
    input  wire                         reset,

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

    // DCR write request
    input  wire                         dcr_wr_valid,
    input  wire [`VX_DCR_ADDR_WIDTH-1:0] dcr_wr_addr,
    input  wire [`VX_DCR_DATA_WIDTH-1:0] dcr_wr_data,

    // Status
    output wire                         busy
);
`ifdef SCOPE
    localparam scope_cluster = 0;
    `SCOPE_IO_SWITCH (`NUM_CLUSTERS);

    localparam scope_socket = 0;
    `SCOPE_IO_SWITCH (`NUM_SOCKETS);

`endif



`ifdef PERF_ENABLE
    VX_mem_perf_if mem_perf_if();
    assign mem_perf_if.icache  = 'x;
    assign mem_perf_if.dcache  = 'x;
    assign mem_perf_if.l2cache = '0;
    assign mem_perf_if.lmem    = 'x;
    assign mem_perf_if.mem     = '0;
    assign mem_perf_if.l3cache = '0;
`endif


`ifdef GBAR_ENABLE

    VX_gbar_bus_if per_socket_gbar_bus_if[`NUM_SOCKETS]();
    VX_gbar_bus_if gbar_bus_if();

    VX_gbar_arb #(
        .NUM_REQS (`NUM_SOCKETS),
        .OUT_BUF  ((`NUM_SOCKETS > 2) ? 1 : 0) // bgar_unit has no backpressure
    ) gbar_arb (
        .clk        (clk),
        .reset      (reset),
        .bus_in_if  (per_socket_gbar_bus_if),
        .bus_out_if (gbar_bus_if)
    );

    VX_gbar_unit #(
        .INSTANCE_ID (`SFORMATF(("gbar%0d", CLUSTER_ID)))
    ) gbar_unit (
        .clk         (clk),
        .reset       (reset),
        .gbar_bus_if (gbar_bus_if)
    );

`endif

    localparam DST_LDATAW = `CLOG2(AXI_DATA_WIDTH);
    localparam SRC_LDATAW = `CLOG2(`VX_MEM_DATA_WIDTH);
    localparam SUB_LDATAW = DST_LDATAW - SRC_LDATAW;
    localparam VX_MEM_TAG_A_WIDTH  = `VX_MEM_TAG_WIDTH + `MAX(SUB_LDATAW, 0);
    localparam VX_MEM_ADDR_A_WIDTH = `VX_MEM_ADDR_WIDTH - SUB_LDATAW;


    localparam CLUSTER_ID = 0;

    // DCR: Vortex -> CLuster -> socket
    VX_dcr_bus_if dcr_bus_if();
    assign dcr_bus_if.write_valid = dcr_wr_valid;
    assign dcr_bus_if.write_addr  = dcr_wr_addr;
    assign dcr_bus_if.write_data  = dcr_wr_data;

    `RESET_RELAY (cluster_reset, reset);
    VX_dcr_bus_if cluster_dcr_bus_if();
        `BUFFER_DCR_BUS_IF (cluster_dcr_bus_if, dcr_bus_if, 1'b1, (`NUM_CLUSTERS > 1))

    `RESET_RELAY (socket_reset, reset);

    VX_dcr_bus_if socket_dcr_bus_if();
    wire is_base_dcr_addr = (cluster_dcr_bus_if.write_addr >= `VX_DCR_BASE_STATE_BEGIN && cluster_dcr_bus_if.write_addr < `VX_DCR_BASE_STATE_END);
    `BUFFER_DCR_BUS_IF (socket_dcr_bus_if, cluster_dcr_bus_if, is_base_dcr_addr, (`NUM_SOCKETS > 1))



    VX_socket_mini_axi #(
        .SOCKET_ID(0),
        .INSTANCE_ID("socket0"),
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .AXI_TID_WIDTH(AXI_TID_WIDTH),
        .AXI_NUM_BANKS(AXI_NUM_BANKS)
    ) socket (
        `SCOPE_IO_BIND (scope_socket)
        
        .clk(clk),
        .reset(socket_reset),

        `ifdef PERF_ENABLE
            .mem_perf_if    (mem_perf_tmp_if),
        `endif

        .dcr_bus_if     (socket_dcr_bus_if),

        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_awready(m_axi_awready),
        .m_axi_awaddr(m_axi_awaddr),
        .m_axi_awid(m_axi_awid),
        .m_axi_awlen(m_axi_awlen),
        .m_axi_awsize(m_axi_awsize),
        .m_axi_awburst(m_axi_awburst),
        .m_axi_awlock(m_axi_awlock),
        .m_axi_awcache(m_axi_awcache),
        .m_axi_awprot(m_axi_awprot),
        .m_axi_awqos(m_axi_awqos),
        .m_axi_awregion(m_axi_awregion),

        .m_axi_wvalid(m_axi_wvalid),
        .m_axi_wready(m_axi_wready),
        .m_axi_wdata(m_axi_wdata),
        .m_axi_wstrb(m_axi_wstrb),
        .m_axi_wlast(m_axi_wlast),

        .m_axi_bvalid(m_axi_bvalid),
        .m_axi_bready(m_axi_bready),
        .m_axi_bid(m_axi_bid),
        .m_axi_bresp(m_axi_bresp),

        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_arready(m_axi_arready),
        .m_axi_araddr(m_axi_araddr),
        .m_axi_arid(m_axi_arid),
        .m_axi_arlen(m_axi_arlen),
        .m_axi_arsize(m_axi_arsize),
        .m_axi_arburst(m_axi_arburst),
        .m_axi_arlock(m_axi_arlock),
        .m_axi_arcache(m_axi_arcache),
        .m_axi_arprot(m_axi_arprot),
        .m_axi_arqos(m_axi_arqos),
        .m_axi_arregion(m_axi_arregion),

        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_rready(m_axi_rready),
        .m_axi_rdata(m_axi_rdata),
        .m_axi_rlast(m_axi_rlast),
        .m_axi_rid(m_axi_rid),
        .m_axi_rresp(m_axi_rresp),

        `ifdef GBAR_ENABLE
            .gbar_bus_if    (per_socket_gbar_bus_if[socket_id]),
        `endif

        .busy(busy)
    );

endmodule
