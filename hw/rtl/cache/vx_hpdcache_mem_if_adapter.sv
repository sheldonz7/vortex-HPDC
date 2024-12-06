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

    parameter NUM_OUTSTANDING_REQS = 1
) (
    input  logic                 clk,
    input  logic                 reset,

    // VX bus interface
    VX_mem_bus_if.master    mem_bus_if,

    // read interface
    output logic                 mem_req_read_ready,
    input  logic                 mem_req_read_valid,
    input  hpdcache_mem_req_t    mem_req_read_o,

    input  logic                 mem_resp_read_ready,
    output logic                 mem_resp_read_valid,
    output hpdcache_mem_resp_r_t mem_resp_read_i,

    // write interface
    output logic                 mem_req_write_ready,
    input  logic                 mem_req_write_valid,
    input  hpdcache_mem_req_t    mem_req_write_o,

    output logic                 mem_req_write_data_ready,
    input  logic                 mem_req_write_data_valid,
    input  hpdcache_mem_req_w_t  mem_req_write_data,

    input  logic                 mem_resp_write_ready,
    output logic                 mem_resp_write_valid,
    output hpdcache_mem_resp_w_t mem_resp_write

);
    
    logic cur_req_state; // 0: take-read if there is, if only write come, take it next cycle, 1: take pending write, 
    logic next_req_state; // 0: take-read if there is, if only write come, take it next cycle, 1: take pending write,

    logic [NUM_OUTSTANDING_REQS - 1 : 0] cur_req;

    // read/write req buffer
    // logic buffered_req_valid;
    // hpdcache_mem_req_t buffered_req;

    // logic buffered_req_write_data_valid;
    // hpdcache_mem_req_w_t buffered_req_write_data;


    always_ff (@(posedge clk) or @(negedge reset)) begin
        if (!reset) begin
            cur_req <= 0;
        end else begin
            cur_req <= next_req;
        end
    end


    always_comb begin
        next_req_state = state;
        mem_req_read_ready = 1'b0;
        mem_req_write_ready = 1'b0;
        mem_req_write_data_ready = 1'b0;
        // default values for data

        if (cur_req == 0) begin: take_read
            if (mem_req_write_valid) begin
                next_req_state = 1;
                mem_req_write_ready = 1'b1;
                mem_req_write_data_ready = 1'b1;
                mem_req_read_ready = 1'b0;
                if (mem_req_read_valid) begin
                    // send read request
                    mem_bus_if.req_data.rw = 1'b0;
                    mem_bus_if.req_data.addr = mem_req_read_o.mem_req_addr;
                    mem_bus_if.req_data.data = '0; // Default for read
                    mem_bus_if.req_data.byteen = '1; // Enable all bytes
                    mem_bus_if.req_data.tag = mem_req_read_o.mem_req_id;
                end
            end else begin
                next_req_state = 0;
                mem_req_write_ready = 1'b0;
                mem_req_write_data_ready = 1'b0;
                mem_req_read_ready = 1'b1;
                if (mem_req_read_valid) begin
                    // send read request
                    mem_bus_if.req_data.rw = 1'b0;
                    mem_bus_if.req_data.addr = mem_req_read_o.mem_req_addr;
                    mem_bus_if.req_data.data = '0; // Default for read
                    mem_bus_if.req_data.byteen = '1; // Enable all bytes
                    mem_bus_if.req_data.tag = mem_req_read_o.mem_req_id;
                end

            end

        end else if (cur_req_state == 1) begin: take_write
            
            next_req_state = 0;
            mem_req_write_ready = 1'b0;
            mem_req_write_data_ready = 1'b0;
            mem_req_read_ready = 1'b1;
            
            // send write request
        end
    end



    // Read Response
    assign mem_resp_read_valid_i = cur_req[0] ? 1'b0 : mem_bus_if.rsp_valid;

    assign mem_bus_if.rsp_ready = cur_req[0] ? 1'b0 : mem_resp_read_ready_o;

    assign mem_resp_read_i.mem_resp_r_id = mem_bus_if.rsp_data.tag;
    assign mem_resp_read_i.mem_resp_r_data = mem_bus_if.rsp_data.data;
    assign mem_resp_read_i.mem_resp_r_error = '0;
    assign mem_resp_read_i.mem_resp_r_last = '0;


    // // Write Response
    // assign mem_resp_write_valid_i = cur_req[0] ? mem_bus_if.rsp_valid : 1'b0;

    // assign mem_bus_if.rsp_ready = mem_resp_write_ready_o;


    // assign mem_resp_write_i.mem_resp_w_id = mem_bus_if.rsp_data.tag;
    // assign mem_resp_write_i.mem_resp_w_error = '0;
    // assign mem_resp_write_i.mem_resp_w_last = '0;


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



    if (cur_req == 0) begin: init
        if (cur_req == 0) 
        mem_req_read_ready = buffered_req_valid ? 1'b0 : mem_bus_if.req_ready;
        mem_req_write_ready = buffered_req_valid ? 1'b0 : mem_bus_if.req_ready;
        mem_req_write_data_ready = buffered_req_write_data_valid ? 1'b0 : mem_bus_if.req_ready;
    
    end else if (cur_req == 1) begin: 
        mem_resp_read_valid = mem_bus_if.rsp_valid;
        mem_resp_write_valid = 1'b0;
    end else if (cur_req == 2) begin: write_resp
        mem_resp_read_valid = 1'b0;
        mem_resp_write_valid = mem_bus_if.rsp_valid;
    end

    // Read Request
    assign mem_bus_if.req_valid = mem_req_read_valid_o;

    assign mem_req_read_ready_i = mem_bus_if.req_ready;

    assign mem_bus_if.req_data.rw = 1'b0;
    assign mem_bus_if.req_data.addr = mem_req_read_o.mem_req_addr;
    assign mem_bus_if.req_data.data = '0; // Default for read
    assign mem_bus_if.req_data.byteen = '1; // Enable all bytes
    assign mem_bus_if.req_data.tag = mem_req_read_o.mem_req_id;

    

    // write request





    // write response


endmodule
