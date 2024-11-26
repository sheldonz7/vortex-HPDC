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

module VX_hpdcache_mem_if_adapter import VX_gpu_pkg::*; #(
    parameter type hpdcache_mem_id_t = logic,
    parameter type hpdcache_mem_req_t = logic,
    parameter type hpdcache_mem_req_w_t = logic,
    parameter type hpdcache_mem_resp_r_t = logic,
    parameter type hpdcache_mem_resp_w_t = logic,
    
    // VX_mem_bus_if parameters
    parameter DATA_SIZE = 1,  // Should match dcache data width
    parameter TAG_WIDTH = 1   // Should match dcache tag width
) (

    VX_mem_bus_if.master    mem_bus_if,

    // read interface
    output logic                 mem_req_read_ready_i,
    input  logic                 mem_req_read_valid_o,
    input  hpdcache_mem_req_t    mem_req_read_o,

    input  logic                 mem_resp_read_ready_o,
    output logic                 mem_resp_read_valid_i,
    output hpdcache_mem_resp_r_t mem_resp_read_i,

    // write interface
    output logic                 mem_req_write_ready_i,
    input  logic                 mem_req_write_valid_o,
    input  hpdcache_mem_req_t    mem_req_write_o,

    output logic                 mem_req_write_data_ready_i,
    input  logic                 mem_req_write_data_valid_o,
    input  hpdcache_mem_req_w_t  mem_req_write_data_o,

    input  logic                 mem_resp_write_ready_o,
    output logic                 mem_resp_write_valid_i,
    output hpdcache_mem_resp_w_t mem_resp_write_i

);

    // Read Request
    assign mem_bus_if.req_valid = mem_req_read_valid_o;

    assign mem_req_read_ready_i = mem_bus_if.req_ready;

    assign mem_bus_if.req_data.rw = 1'b0;
    assign mem_bus_if.req_data.addr = mem_req_read_o.mem_req_addr;
    assign mem_bus_if.req_data.data = '0; // Default for read
    assign mem_bus_if.req_data.byteen = '1; // Enable all bytes
    assign mem_bus_if.req_data.tag = mem_req_read_o.mem_req_id;

    // Read Response
    assign mem_resp_read_valid_i = mem_bus_if.rsp_valid;

    assign mem_bus_if.rsp_ready = mem_resp_read_ready_o;

    assign mem_resp_read_i.mem_resp_r_id = mem_bus_if.rsp_data.tag;
    assign mem_resp_read_i.mem_resp_r_data = mem_bus_if.rsp_data.data;



endmodule
