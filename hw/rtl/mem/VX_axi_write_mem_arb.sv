`include "VX_define.vh"

module VX_axi_write_mem_arb #(
    parameter NUM_INPUTS     = 1,
    parameter NUM_OUTPUTS    = 1,
    parameter TAG_SEL_IDX    = 0,
    parameter REQ_OUT_BUF    = 0,
    parameter RSP_OUT_BUF    = 0,
    parameter `STRING ARBITER = "R",

    parameter AXI_DATA_WIDTH = 0,
    parameter AXI_ADDR_WIDTH = 0,
    parameter AXI_TID_WIDTH  = 0
) (
    input wire              clk,
    input wire              reset,

    // AXI input slave 0
    // AXI write request address channel
    input wire                         m_axi_awvalid_0,
    output wire                        m_axi_awready_0,
    input wire [AXI_ADDR_WIDTH-1:0]    m_axi_awaddr_0,
    input wire [AXI_TID_WIDTH-1:0]     m_axi_awid_0,
    input wire [7:0]                   m_axi_awlen_0,
    input wire [2:0]                   m_axi_awsize_0,
    input wire [1:0]                   m_axi_awburst_0,
    input wire [1:0]                   m_axi_awlock_0,
    input wire [3:0]                   m_axi_awcache_0,
    input wire [2:0]                   m_axi_awprot_0,
    input wire [3:0]                   m_axi_awqos_0,
    input wire [3:0]                   m_axi_awregion_0,
    // AXI write request data channel
    input wire                         m_axi_wvalid_0,
    output wire                        m_axi_wready_0,
    input wire [AXI_DATA_WIDTH-1:0]    m_axi_wdata_0,
    input wire [AXI_DATA_WIDTH/8-1:0]  m_axi_wstrb_0,
    input wire                         m_axi_wlast_0,
    // AXI write response channel
    output wire                          m_axi_bvalid_0,
    input wire                           m_axi_bready_0,
    output wire [AXI_TID_WIDTH-1:0]      m_axi_bid_0,
    output wire [1:0]                    m_axi_bresp_0,

    // AXI input slave 1
    // AXI write request address channel
    input wire                         m_axi_awvalid_1,
    output wire                        m_axi_awready_1,
    input wire [AXI_ADDR_WIDTH-1:0]    m_axi_awaddr_1,
    input wire [AXI_TID_WIDTH-1:0]     m_axi_awid_1,
    input wire [7:0]                   m_axi_awlen_1,
    input wire [2:0]                   m_axi_awsize_1,
    input wire [1:0]                   m_axi_awburst_1,
    input wire [1:0]                   m_axi_awlock_1,
    input wire [3:0]                   m_axi_awcache_1,
    input wire [2:0]                   m_axi_awprot_1,
    input wire [3:0]                   m_axi_awqos_1,
    input wire [3:0]                   m_axi_awregion_1,
    // AXI write request data channel
    input wire                         m_axi_wvalid_1,
    output wire                        m_axi_wready_1,
    input wire [AXI_DATA_WIDTH-1:0]    m_axi_wdata_1,
    input wire [AXI_DATA_WIDTH/8-1:0]  m_axi_wstrb_1,
    input wire                         m_axi_wlast_1,
    // AXI write response channel
    output wire                          m_axi_bvalid_1,
    input wire                           m_axi_bready_1,
    output wire [AXI_TID_WIDTH-1:0]      m_axi_bid_1,
    output wire [1:0]                    m_axi_bresp_1,

    // AXI output master    
    // AXI write request address channel
    output wire                         m_axi_awvalid,
    input wire                          m_axi_awready,
    output wire [AXI_ADDR_WIDTH-1:0]    m_axi_awaddr,
    output wire [AXI_TID_WIDTH-1:0]     m_axi_awid,
    output wire [7:0]                   m_axi_awlen,
    output wire [2:0]                   m_axi_awsize,
    output wire [1:0]                   m_axi_awburst,
    output wire [1:0]                   m_axi_awlock,
    output wire [3:0]                   m_axi_awcache,
    output wire [2:0]                   m_axi_awprot,
    output wire [3:0]                   m_axi_awqos,
    output wire [3:0]                   m_axi_awregion,

    // AXI write request data channel
    output wire                         m_axi_wvalid,
    input wire                          m_axi_wready,
    output wire [AXI_DATA_WIDTH-1:0]    m_axi_wdata,
    output wire [AXI_DATA_WIDTH/8-1:0]  m_axi_wstrb,
    output wire                         m_axi_wlast,

    // AXI write response channel
    input wire                          m_axi_bvalid,
    output wire                         m_axi_bready,
    input wire [AXI_TID_WIDTH-1:0]      m_axi_bid,
    input wire [1:0]                    m_axi_bresp

);
    localparam DATA_WIDTH   = AXI_DATA_WIDTH;
    localparam LOG_NUM_REQS = `ARB_SEL_BITS(NUM_INPUTS, NUM_OUTPUTS);
    localparam REQ_DATAW    = AXI_ADDR_WIDTH+AXI_TID_WIDTH+8+3+2+2+4+3+4+4+1+AXI_DATA_WIDTH+(AXI_DATA_WIDTH/8)+1;
    localparam RSP_DATAW    = AXI_TID_WIDTH;

    `STATIC_ASSERT ((NUM_INPUTS >= NUM_OUTPUTS), ("invalid parameter"))

    wire [NUM_INPUTS-1:0]                   req_valid_in;
    wire [NUM_INPUTS-1:0][REQ_DATAW-1:0]    req_data_in;
    wire [NUM_INPUTS-1:0]                   req_ready_in;

    wire [NUM_OUTPUTS-1:0]                          req_valid_out;
    wire [NUM_OUTPUTS-1:0][REQ_DATAW-1:0]           req_data_out;
    wire [NUM_OUTPUTS-1:0][`UP(LOG_NUM_REQS)-1:0]   req_sel_out;
    wire [NUM_OUTPUTS-1:0]                          req_ready_out;

    assign req_valid_in[0] = m_axi_awvalid_0;
    assign req_data_in[0] = {
        m_axi_awaddr_0,
        m_axi_awid_0,
        m_axi_awlen_0,
        m_axi_awsize_0,
        m_axi_awburst_0,
        m_axi_awlock_0,
        m_axi_awcache_0,
        m_axi_awprot_0,
        m_axi_awqos_0,
        m_axi_awregion_0,
        m_axi_wvalid_0,
        m_axi_wdata_0,
        m_axi_wstrb_0,
        m_axi_wlast_0
    };
    assign m_axi_awready_0 = req_ready_in[0];

    assign req_valid_in[1] = m_axi_awvalid_1;
    assign req_data_in[1] = {
        m_axi_awaddr_1,
        m_axi_awid_1,
        m_axi_awlen_1,
        m_axi_awsize_1,
        m_axi_awburst_1,
        m_axi_awlock_1,
        m_axi_awcache_1,
        m_axi_awprot_1,
        m_axi_awqos_1,
        m_axi_awregion_1,
        m_axi_wvalid_1,
        m_axi_wdata_1,
        m_axi_wstrb_1,
        m_axi_wlast_1
    };
    assign m_axi_awready_1 = req_ready_in[1];

    VX_stream_arb #(
        .NUM_INPUTS  (NUM_INPUTS),
        .NUM_OUTPUTS (NUM_OUTPUTS),
        .DATAW       (REQ_DATAW),
        .ARBITER     (ARBITER),
        .OUT_BUF     (REQ_OUT_BUF)
    ) req_arb (
        .clk       (clk),
        .reset     (reset),
        .valid_in  (req_valid_in),
        .ready_in  (req_ready_in),
        .data_in   (req_data_in),
        .data_out  (req_data_out),
        .sel_out   (req_sel_out),
        .valid_out (req_valid_out),
        .ready_out (req_ready_out)
    );

    for (genvar i = 0; i < NUM_OUTPUTS; ++i) begin : g_bus_out_if
        wire [AXI_TID_WIDTH-1:0] req_tag_out;
        VX_bits_insert #(
            .N   (AXI_TID_WIDTH),
            .S   (LOG_NUM_REQS),
            .POS (TAG_SEL_IDX)
        ) bits_insert (
            .data_in  (req_tag_out),
            .ins_in   (req_sel_out[i]),
            .data_out (m_axi_awid)
        );
        assign m_axi_awvalid = req_valid_out[i];
        assign {
            m_axi_awaddr,
            req_tag_out,
            m_axi_awlen,
            m_axi_awsize,
            m_axi_awburst,
            m_axi_awlock,
            m_axi_awcache,
            m_axi_awprot,
            m_axi_awqos,
            m_axi_awregion,
            m_axi_wvalid,
            m_axi_wdata,
            m_axi_wstrb,
            m_axi_wlast,
        } = req_data_out[i];
        assign req_ready_out[i] = m_axi_awready;
    end

    ///////////////////////////////////////////////////////////////////////////

    wire [NUM_INPUTS-1:0]                 rsp_valid_out;
    wire [NUM_INPUTS-1:0][RSP_DATAW-1:0]  rsp_data_out;
    wire [NUM_INPUTS-1:0]                 rsp_ready_out;

    wire [NUM_OUTPUTS-1:0]                rsp_valid_in;
    wire [NUM_OUTPUTS-1:0][RSP_DATAW-1:0] rsp_data_in;
    wire [NUM_OUTPUTS-1:0]                rsp_ready_in;

    wire [NUM_OUTPUTS-1:0][LOG_NUM_REQS-1:0] rsp_sel_in;

    for (genvar i = 0; i < NUM_OUTPUTS; ++i) begin : g_rsp_data_in
        wire [AXI_TID_WIDTH-1:0] rsp_tag_out;
        VX_bits_remove #(
            .N   (AXI_TID_WIDTH + LOG_NUM_REQS),
            .S   (LOG_NUM_REQS),
            .POS (TAG_SEL_IDX)
        ) bits_remove (
            .data_in  (m_axi_bid),
            .data_out (rsp_tag_out)
        );

        assign rsp_valid_in[i] = m_axi_bvalid;
        assign rsp_data_in[i] = rsp_tag_out;
        assign m_axi_bready = rsp_ready_in[i];

        if (NUM_INPUTS > 1) begin : g_rsp_sel_in
            assign rsp_sel_in[i] = m_axi_bid[TAG_SEL_IDX +: LOG_NUM_REQS];
        end else begin : g_no_rsp_sel_in
            assign rsp_sel_in[i] = '0;
        end
    end

    VX_stream_switch #(
        .NUM_INPUTS  (NUM_OUTPUTS),
        .NUM_OUTPUTS (NUM_INPUTS),
        .DATAW       (RSP_DATAW),
        .OUT_BUF     (RSP_OUT_BUF)
    ) rsp_switch (
        .clk       (clk),
        .reset     (reset),
        .sel_in    (rsp_sel_in),
        .valid_in  (rsp_valid_in),
        .ready_in  (rsp_ready_in),
        .data_in   (rsp_data_in),
        .data_out  (rsp_data_out),
        .valid_out (rsp_valid_out),
        .ready_out (rsp_ready_out)
    );

    assign m_axi_bvalid_0 = rsp_valid_out[0];
    assign {
        m_axi_bid_0
    } = rsp_data_out[0];
    assign rsp_ready_out[0] = m_axi_bready_0;


    assign m_axi_bvalid_1 = rsp_valid_out[1];
    assign {
        m_axi_bid_1
    } = rsp_data_out[1];
    assign rsp_ready_out[1] = m_axi_bready_1;

endmodule
