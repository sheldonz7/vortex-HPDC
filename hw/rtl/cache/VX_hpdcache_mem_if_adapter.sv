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
    parameter type hpdcache_mem_id_t        = logic,
    parameter type hpdcache_mem_req_t       = logic,
    parameter type hpdcache_mem_req_w_t     = logic,
    parameter type hpdcache_mem_resp_r_t    = logic,
    parameter type hpdcache_mem_resp_w_t    = logic,
    
    // VX_mem_bus_if parameters
    parameter MEM_DATA_SIZE                     = 1,  // Should match dcache data width
    parameter MEM_TAG_WIDTH                 = 1,   // Should match dcache tag width
    parameter TAG_SEL_IDX                   = 0,
    // Memory request output buffer
    parameter MEM_OUT_BUF                   = 3
    
    // parameter NUM_OUTSTANDING_REQS = 1
) (
    input  logic                 clk,
    input  logic                 reset,

    // VX bus interface
    VX_mem_bus_if.master         mem_bus_if,

    // read interface
    output logic                 mem_req_read_ready,
    input  logic                 mem_req_read_valid,
    input  hpdcache_mem_req_t    mem_req_read,

    input  logic                 mem_resp_read_ready,
    output logic                 mem_resp_read_valid,
    output hpdcache_mem_resp_r_t mem_resp_read,

    // write interface
    output logic                 mem_req_write_ready,
    input  logic                 mem_req_write_valid,
    input  hpdcache_mem_req_t    mem_req_write,

    output logic                 mem_req_write_data_ready,
    input  logic                 mem_req_write_data_valid,
    input  hpdcache_mem_req_w_t  mem_req_write_data,

    input  logic                 mem_resp_write_ready,
    output logic                 mem_resp_write_valid,
    output hpdcache_mem_resp_w_t mem_resp_write

);
    localparam VX_MEM_BUS_ADDR_WIDTH = `MEM_ADDR_WIDTH - `CLOG2(MEM_DATA_SIZE);
    
    VX_mem_bus_if #(
        .DATA_SIZE(MEM_DATA_SIZE),
        .TAG_WIDTH(MEM_TAG_WIDTH)
    ) cache_mem_bus_if[2] ();


    // VX_mem_bus_if.master    mem_read_bus_if,

    // VX_mem_bus_if.master    cache_mem_bus_if[1],
    // 
    logic [VX_MEM_BUS_ADDR_WIDTH-1:0] vx_mem_read_req_addr;
    logic [VX_MEM_BUS_ADDR_WIDTH-1:0] vx_mem_write_req_addr;

    logic cur_mem_resp_write_valid;
    logic [MEM_TAG_WIDTH-1:0] cur_mem_resp_write_tag;


    logic cur_req_state; // 0: take-read if there is, if only write come, take it next cycle, 1: take pending write, 
    logic next_req_state; // 0: take-read if there is, if only write come, take it next cycle, 1: take pending write,

    // logic [NUM_OUTSTANDING_REQS - 1 : 0] cur_req;

    // read/write req buffer
    // logic buffered_req_valid;
    // hpdcache_mem_req_t buffered_req;

    // logic buffered_req_write_data_valid;
    // hpdcache_mem_req_w_t buffered_req_write_data;

    assign vx_mem_read_req_addr = mem_req_read.mem_req_addr[`MEM_ADDR_WIDTH-1:`CLOG2(MEM_DATA_SIZE)];
    assign vx_mem_write_req_addr = mem_req_write.mem_req_addr[`MEM_ADDR_WIDTH-1:`CLOG2(MEM_DATA_SIZE)];

    // FSM register
    // always_ff @(posedge clk or negedge reset) begin
    //     if (!reset) begin
    //         cur_req_state <= 0;
    //     end else begin
    //         cur_req_state <= next_req_state;
    //     end
    // end


    // always_comb begin
    //     next_req_state = 0;
    //     mem_req_read_ready = 1'b0;
    //     mem_req_write_ready = 1'b0;
    //     mem_req_write_data_ready = 1'b0;
    //     // default values for data

    //     if (cur_req_state == 0) begin: take_read
    //         if (mem_req_write_valid) begin
    //             next_req_state = 1;
    //             mem_req_write_ready = 1'b1;
    //             mem_req_write_data_ready = 1'b1;
    //             mem_req_read_ready = 1'b0;
    //             if (mem_req_read_valid) begin
    //                 // send read request
    //                 mem_bus_if.req_data.rw = 1'b0;
    //                 mem_bus_if.req_data.addr = vx_mem_req_addr;
    //                 mem_bus_if.req_data.data = '0; // Default for read
    //                 mem_bus_if.req_data.byteen = '1; // Enable all bytes
    //                 mem_bus_if.req_data.tag = mem_req_read.mem_req_id;
    //                 mem_bus_if.req_data.flags = '0;
    //             end
    //         end else begin
    //             next_req_state = 0;
    //             mem_req_write_ready = 1'b0;
    //             mem_req_write_data_ready = 1'b0;
    //             mem_req_read_ready = 1'b1;
    //             if (mem_req_read_valid) begin
    //                 // send read request
    //                 mem_bus_if.req_data.rw = 1'b0;
    //                 mem_bus_if.req_data.addr = vx_mem_req_addr;
    //                 mem_bus_if.req_data.data = '0; // Default for read
    //                 mem_bus_if.req_data.byteen = '1; // Enable all bytes
    //                 mem_bus_if.req_data.tag = mem_req_read.mem_req_id;
    //             end

    //         end

    //     end else if (cur_req_state == 1) begin: take_write
            
    //         next_req_state = 0;
    //         mem_req_write_ready = 1'b0;
    //         mem_req_write_data_ready = 1'b0;
    //         mem_req_read_ready = 1'b1;
            
    //         // send write request
    //         mem_bus_if.req_data.rw = 1'b1;
    //         mem_bus_if.req_data.addr = vx_mem_req_addr;
    //         mem_bus_if.req_data.data = mem_req_write_data.mem_req_w_data;
    //         //mem_bus_if.req_data.byteen = mem_req_write_data.mem_req_w_byteen;
    //         mem_bus_if.req_data.tag = mem_req_write.mem_req_w_id;
    //     end
    // end


    // read request
    assign cache_mem_bus_if[0].req_valid = mem_req_read_valid;
    assign mem_req_read_ready = cache_mem_bus_if[0].req_ready;
    assign cache_mem_bus_if[0].req_data.rw = 1'b0;
    assign cache_mem_bus_if[0].req_data.addr = vx_mem_read_req_addr;
    assign cache_mem_bus_if[0].req_data.data = '0; // Default for read
    assign cache_mem_bus_if[0].req_data.byteen = '1; // Enable all bytes
    assign cache_mem_bus_if[0].req_data.tag = mem_req_read.mem_req_id;
    assign cache_mem_bus_if[0].req_data.flags = '0;


    // Read Response
    // only read requests need response
    assign mem_resp_read_valid = cache_mem_bus_if[0].rsp_valid;

    assign cache_mem_bus_if[0].rsp_ready = mem_resp_read_ready;

    assign mem_resp_read.mem_resp_r_id = cache_mem_bus_if[0].rsp_data.tag;
    assign mem_resp_read.mem_resp_r_data = cache_mem_bus_if[0].rsp_data.data;
    assign mem_resp_read.mem_resp_r_error = hpdcache_pkg::hpdcache_mem_error_e'(0);

    assign mem_resp_read.mem_resp_r_last = '1;


    // write request
    assign cache_mem_bus_if[1].req_valid = mem_req_write_valid && mem_req_write_data_valid;
    assign mem_req_write_ready = cache_mem_bus_if[1].req_ready;
    assign mem_req_write_data_ready = cache_mem_bus_if[1].req_ready;
    assign cache_mem_bus_if[1].req_data.rw = 1'b1;
    assign cache_mem_bus_if[1].req_data.addr = vx_mem_write_req_addr;
    assign cache_mem_bus_if[1].req_data.data = mem_req_write_data.mem_req_w_data;
    assign cache_mem_bus_if[1].req_data.byteen = mem_req_write_data.mem_req_w_be;
    assign cache_mem_bus_if[1].req_data.tag = mem_req_write.mem_req_id;
    assign cache_mem_bus_if[1].req_data.flags = '0;



    // Write Response
    // simply generate
    always_ff @(posedge clk or negedge reset) begin
        if (!reset) begin
            cur_mem_resp_write_valid <= 1'b0;
            cur_mem_resp_write_tag <= 0;
        end else begin
            cur_mem_resp_write_valid <= cache_mem_bus_if[1].req_valid && mem_req_write_ready;
            cur_mem_resp_write_tag <= cache_mem_bus_if[1].req_data.tag;
        end
    end



    assign mem_resp_write_valid = cur_mem_resp_write_valid;
    
    assign cache_mem_bus_if[1].rsp_ready = mem_resp_write_ready;


    assign mem_resp_write.mem_resp_w_id = cur_mem_resp_write_tag;
    
    
    assign mem_resp_write.mem_resp_w_error = hpdcache_pkg::hpdcache_mem_error_e'(0);


    assign mem_resp_write.mem_resp_w_is_atomic = 1'b0;  // AMO currently not supported


    // // control signals
    // always_ff
    // if (cur_req == 0) begin: init
    //     mem_req_read_ready = 1'b1;
    //     mem_req_write_ready = 1'b0;
        
        
    //     if (mem_req_read_valid) begin
    //         mem_req_read_ready = 1'b1;
    //     end else begin
    //         mem_req_read_ready = 1'b0;
    //     end
    // end else if (cur_req == 1) begin: write
    //     if (mem_req_write_valid) begin
    //         mem_req_write_ready = 1'b1;
    //     end else begin
    //         mem_req_write_ready = 1'b0;
    //     end
    // end
    

    // VX_elastic_buffer #(
    //     .DATAW
    // )



    // if (cur_req == 0) begin: init
    //     if (cur_req == 0) 
    //     mem_req_read_ready = buffered_req_valid ? 1'b0 : mem_bus_if.req_ready;
    //     mem_req_write_ready = buffered_req_valid ? 1'b0 : mem_bus_if.req_ready;
    //     mem_req_write_data_ready = buffered_req_write_data_valid ? 1'b0 : mem_bus_if.req_ready;
    
    // end else if (cur_req == 1) begin: 
    //     mem_resp_read_valid = mem_bus_if.rsp_valid;
    //     mem_resp_write_valid = 1'b0;
    // end else if (cur_req == 2) begin: write_resp
    //     mem_resp_read_valid = 1'b0;
    //     mem_resp_write_valid = mem_bus_if.rsp_valid;
    // end

    // // Read Request
    // assign mem_bus_if.req_valid = mem_req_read_valid_o;

    // assign mem_req_read_ready_i = mem_bus_if.req_ready;

    // assign mem_bus_if.req_data.rw = 1'b0;
    // assign mem_bus_if.req_data.addr = mem_req_read_o.mem_req_addr;
    // assign mem_bus_if.req_data.data = '0; // Default for read
    // assign mem_bus_if.req_data.byteen = '1; // Enable all bytes
    // assign mem_bus_if.req_data.tag = mem_req_read_o.mem_req_id;

    

    // write request

    VX_mem_bus_if #(
        .DATA_SIZE (MEM_DATA_SIZE),
        .TAG_WIDTH (MEM_TAG_WIDTH)
    ) mem_bus_tmp_if[1]();

    VX_mem_arb_1d #(
        .NUM_INPUTS   (2),
        .DATA_SIZE    (MEM_DATA_SIZE),
        .TAG_WIDTH    (MEM_TAG_WIDTH),
        .TAG_SEL_IDX  (TAG_SEL_IDX),
        .ARBITER      ("R"),
        .REQ_OUT_BUF  (MEM_OUT_BUF),
        .RSP_OUT_BUF  (2),
        .RSP_SEL      (0)       // only goes to read bus
    ) mem_arb (
        .clk        (clk),
        .reset      (!reset),
        .bus_in_if  (cache_mem_bus_if),
        .bus_out_if (mem_bus_tmp_if)
    );

    // VX_mem_bus_if #(
    //     .DATA_SIZE (MEM_DATA_SIZE),
    //     .TAG_WIDTH (MEM_TAG_WIDTH + `ARB_SEL_BITS(2, 1))
    // ) mem_bus_tmp_if_2[1]();


    //`ASSIGN_VX_MEM_BUS_IF (mem_bus_tmp_if_2[0], mem_bus_tmp_if[0]);
    `ASSIGN_VX_MEM_BUS_IF (mem_bus_if, mem_bus_tmp_if[0]);





    // write response


endmodule
