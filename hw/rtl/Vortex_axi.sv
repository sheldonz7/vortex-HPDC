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

// Vortex_axi: Updated version to include HPDcache integration

`include "VX_define.vh"

module Vortex_axi 
#(
    parameter AXI_DATA_WIDTH  = 512,
    parameter AXI_ADDR_WIDTH  = 64,
    parameter AXI_TID_WIDTH   = 6,
    parameter MEM_LINE_SIZE   = 64,
    parameter MEM_ADDR_WIDTH  = 64,
    parameter MEM_DATA_WIDTH  = 512,
    parameter MEM_TAG_WIDTH   = 10
) (
    input  wire clk,
    input  wire reset,

    // Core request interface
    input  wire mem_req_valid,
    input  wire mem_req_rw,
    input  wire [MEM_ADDR_WIDTH-1:0] mem_req_addr,
    input  wire [MEM_LINE_SIZE-1:0] mem_req_byteen,
    input  wire [MEM_DATA_WIDTH-1:0] mem_req_data,
    input  wire [MEM_TAG_WIDTH-1:0] mem_req_tag,
    output wire mem_req_ready,

    // Core response interface
    output wire mem_rsp_valid,
    output wire [MEM_DATA_WIDTH-1:0] mem_rsp_data,
    output wire [MEM_TAG_WIDTH-1:0] mem_rsp_tag,
    input  wire mem_rsp_ready,

    // AXI master interface
    output wire [AXI_ADDR_WIDTH-1:0] axi_awaddr,
    output wire [AXI_TID_WIDTH-1:0]  axi_awid,
    output wire                      axi_awvalid,
    input  wire                      axi_awready,
    output wire [AXI_DATA_WIDTH-1:0] axi_wdata,
    output wire [AXI_DATA_WIDTH/8-1:0] axi_wstrb,
    output wire                      axi_wvalid,
    input  wire                      axi_wready,
    input  wire                      axi_bvalid,
    output wire                      axi_bready,
    output wire [AXI_ADDR_WIDTH-1:0] axi_araddr,
    output wire [AXI_TID_WIDTH-1:0]  axi_arid,
    output wire                      axi_arvalid,
    input  wire                      axi_arready,
    input  wire [AXI_DATA_WIDTH-1:0] axi_rdata,
    input  wire                      axi_rvalid,
    output wire                      axi_rready
);

// Signals for HPDcache interface
wire hpd_req_valid, hpd_req_ready;
wire [MEM_ADDR_WIDTH-1:0] hpd_req_addr;
wire [MEM_DATA_WIDTH-1:0] hpd_req_data;
wire [MEM_LINE_SIZE-1:0]  hpd_req_byteen;
wire hpd_req_rw;
wire [MEM_TAG_WIDTH-1:0]  hpd_req_tag;

wire hpd_rsp_valid, hpd_rsp_ready;
wire [MEM_DATA_WIDTH-1:0] hpd_rsp_data;
wire [MEM_TAG_WIDTH-1:0]  hpd_rsp_tag;

// Instantiate memory adapter
VX_mem_adapter #(
    .MEM_ADDR_WIDTH (MEM_ADDR_WIDTH),
    .MEM_DATA_WIDTH (MEM_DATA_WIDTH),
    .MEM_LINE_SIZE  (MEM_LINE_SIZE),
    .MEM_TAG_WIDTH  (MEM_TAG_WIDTH)
) mem_adapter (
    .clk            (clk),
    .reset          (reset),
    .mem_req_valid  (mem_req_valid),
    .mem_req_ready  (mem_req_ready),
    .mem_req_rw     (mem_req_rw),
    .mem_req_addr   (mem_req_addr),
    .mem_req_byteen (mem_req_byteen),
    .mem_req_data   (mem_req_data),
    .mem_req_tag    (mem_req_tag),
    .mem_rsp_valid  (hpd_req_valid),
    .mem_rsp_ready  (hpd_req_ready),
    .mem_rsp_data   (hpd_req_data),
    .mem_rsp_tag    (hpd_req_tag)
);

// Instantiate HPDcache
VX_hpdcache #(
    .MEM_ADDR_WIDTH (MEM_ADDR_WIDTH),
    .MEM_DATA_WIDTH (MEM_DATA_WIDTH),
    .MEM_LINE_SIZE  (MEM_LINE_SIZE),
    .MEM_TAG_WIDTH  (MEM_TAG_WIDTH)
) hpd_cache (
    .clk            (clk),
    .reset          (reset),
    .core_req_valid (hpd_req_valid),
    .core_req_ready (hpd_req_ready),
    .core_req_addr  (hpd_req_addr),
    .core_req_rw    (hpd_req_rw),
    .core_req_data  (hpd_req_data),
    .core_req_byteen(hpd_req_byteen),
    .core_req_tag   (hpd_req_tag),
    .core_rsp_valid (hpd_rsp_valid),
    .core_rsp_ready (hpd_rsp_ready),
    .core_rsp_data  (hpd_rsp_data),
    .core_rsp_tag   (hpd_rsp_tag)
);

// Instantiate AXI adapter
VX_axi_adapter #(
    .AXI_DATA_WIDTH (AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH (AXI_ADDR_WIDTH),
    .AXI_TID_WIDTH  (AXI_TID_WIDTH),
    .MEM_LINE_SIZE  (MEM_LINE_SIZE),
    .MEM_ADDR_WIDTH (MEM_ADDR_WIDTH),
    .MEM_DATA_WIDTH (MEM_DATA_WIDTH),
    .MEM_TAG_WIDTH  (MEM_TAG_WIDTH)
) axi_adapter (
    .clk            (clk),
    .reset          (reset),
    .mem_req_valid  (hpd_rsp_valid),
    .mem_req_ready  (hpd_rsp_ready),
    .mem_req_addr   (hpd_req_addr),
    .mem_req_rw     (hpd_req_rw),
    .mem_req_data   (hpd_req_data),
    .mem_req_byteen (hpd_req_byteen),
    .mem_req_tag    (hpd_req_tag),
    .mem_rsp_valid  (mem_rsp_valid),
    .mem_rsp_ready  (mem_rsp_ready),
    .mem_rsp_data   (mem_rsp_data),
    .mem_rsp_tag    (mem_rsp_tag),
    .axi_awaddr     (axi_awaddr),
    .axi_awid       (axi_awid),
    .axi_awvalid    (axi_awvalid),
    .axi_awready    (axi_awready),
    .axi_wdata      (axi_wdata),
    .axi_wstrb      (axi_wstrb),
    .axi_wvalid     (axi_wvalid),
    .axi_wready     (axi_wready),
    .axi_bvalid     (axi_bvalid),
    .axi_bready     (axi_bready),
    .axi_araddr     (axi_araddr),
    .axi_arid       (axi_arid),
    .axi_arvalid    (axi_arvalid),
    .axi_arready    (axi_arready),
    .axi_rdata      (axi_rdata),
    .axi_rvalid     (axi_rvalid),
    .axi_rready     (axi_rready)
);

endmodule
