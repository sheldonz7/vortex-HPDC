`include "VX_define.vh"

module VX_axi_read_mem_arb #(
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
    // AXI read request channel
    input wire                         m_axi_arvalid_0,
    output wire                        m_axi_arready_0,
    input wire [AXI_ADDR_WIDTH-1:0]    m_axi_araddr_0,
    input wire [AXI_TID_WIDTH-1:0]     m_axi_arid_0,
    input wire [7:0]                   m_axi_arlen_0,
    input wire [2:0]                   m_axi_arsize_0,
    input wire [1:0]                   m_axi_arburst_0,
    input wire [1:0]                   m_axi_arlock_0,
    input wire [3:0]                   m_axi_arcache_0,
    input wire [2:0]                   m_axi_arprot_0,
    input wire [3:0]                   m_axi_arqos_0,
    input wire [3:0]                   m_axi_arregion_0,

    // AXI read response channel
    output wire                          m_axi_rvalid_0,
    input wire                           m_axi_rready_0,
    output wire [AXI_DATA_WIDTH-1:0]     m_axi_rdata_0,
    output wire                          m_axi_rlast_0,
    output wire [AXI_TID_WIDTH-1:0]      m_axi_rid_0,
    output wire [1:0]                    m_axi_rresp_0,

    // AXI input slave 1
    // AXI read request channel
    input wire                         m_axi_arvalid_1,
    output wire                        m_axi_arready_1,
    input wire [AXI_ADDR_WIDTH-1:0]    m_axi_araddr_1,
    input wire [AXI_TID_WIDTH-1:0]     m_axi_arid_1,
    input wire [7:0]                   m_axi_arlen_1,
    input wire [2:0]                   m_axi_arsize_1,
    input wire [1:0]                   m_axi_arburst_1,
    input wire [1:0]                   m_axi_arlock_1,
    input wire [3:0]                   m_axi_arcache_1,
    input wire [2:0]                   m_axi_arprot_1,
    input wire [3:0]                   m_axi_arqos_1,
    input wire [3:0]                   m_axi_arregion_1,

    // AXI read response channel
    output wire                          m_axi_rvalid_1,
    input wire                           m_axi_rready_1,
    output wire [AXI_DATA_WIDTH-1:0]     m_axi_rdata_1,
    output wire                          m_axi_rlast_1,
    output wire [AXI_TID_WIDTH-1:0]      m_axi_rid_1,
    output wire [1:0]                    m_axi_rresp_1,

    // AXI output master
    // AXI read request channel
    output wire                         m_axi_arvalid,
    input wire                          m_axi_arready,
    output wire [AXI_ADDR_WIDTH-1:0]    m_axi_araddr,
    output wire [AXI_TID_WIDTH:0]       m_axi_arid,
    output wire [7:0]                   m_axi_arlen,
    output wire [2:0]                   m_axi_arsize,
    output wire [1:0]                   m_axi_arburst,
    output wire [1:0]                   m_axi_arlock,
    output wire [3:0]                   m_axi_arcache,
    output wire [2:0]                   m_axi_arprot,
    output wire [3:0]                   m_axi_arqos,
    output wire [3:0]                   m_axi_arregion,

    // AXI read response channel
    input wire                          m_axi_rvalid,
    output wire                         m_axi_rready,
    input wire [AXI_DATA_WIDTH-1:0]     m_axi_rdata,
    input wire                          m_axi_rlast,
    input wire [AXI_TID_WIDTH:0]        m_axi_rid,
    input wire [1:0]                    m_axi_rresp

);
    localparam DATA_WIDTH   = AXI_DATA_WIDTH;
    localparam LOG_NUM_REQS = `ARB_SEL_BITS(NUM_INPUTS, NUM_OUTPUTS);
    localparam REQ_DATAW    = AXI_ADDR_WIDTH+AXI_TID_WIDTH+8+3+2+2+4+3+4+4;
    localparam RSP_DATAW    = AXI_DATA_WIDTH+1+AXI_TID_WIDTH;

    `STATIC_ASSERT ((NUM_INPUTS >= NUM_OUTPUTS), ("invalid parameter"))

    wire [NUM_INPUTS-1:0]                   req_valid_in;
    wire [NUM_INPUTS-1:0][REQ_DATAW-1:0]    req_data_in;
    wire [NUM_INPUTS-1:0]                   req_ready_in;

    wire [NUM_OUTPUTS-1:0]                          req_valid_out;
    wire [NUM_OUTPUTS-1:0][REQ_DATAW-1:0]           req_data_out;
    wire [NUM_OUTPUTS-1:0][`UP(LOG_NUM_REQS)-1:0]   req_sel_out;
    wire [NUM_OUTPUTS-1:0]                          req_ready_out;

    assign req_valid_in[0] = m_axi_arvalid_0;
    assign req_data_in[0] = {
        m_axi_araddr_0,
        m_axi_arid_0,
        m_axi_arlen_0,
        m_axi_arsize_0,
        m_axi_arburst_0,
        m_axi_arlock_0,
        m_axi_arcache_0,
        m_axi_arprot_0,
        m_axi_arqos_0,
        m_axi_arregion_0
    };
    assign m_axi_arready_0 = req_ready_in[0];

    assign req_valid_in[1] = m_axi_arvalid_1;
    assign req_data_in[1] = {
        m_axi_araddr_1,
        m_axi_arid_1,
        m_axi_arlen_1,
        m_axi_arsize_1,
        m_axi_arburst_1,
        m_axi_arlock_1,
        m_axi_arcache_1,
        m_axi_arprot_1,
        m_axi_arqos_1,
        m_axi_arregion_1
    };
    assign m_axi_arready_1 = req_ready_in[1];

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
            .data_out (m_axi_arid)
        );
        assign m_axi_arvalid = req_valid_out[i];
        assign {
            m_axi_araddr,
            req_tag_out,
            m_axi_arlen,
            m_axi_arsize,
            m_axi_arburst,
            m_axi_arlock,
            m_axi_arcache,
            m_axi_arprot,
            m_axi_arqos,
            m_axi_arregion
        } = req_data_out[i];
        assign req_ready_out[i] = m_axi_arready;
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
            .data_in  (m_axi_rid),
            .data_out (rsp_tag_out)
        );

        assign rsp_valid_in[i] = m_axi_rvalid;
        assign rsp_data_in[i] = {rsp_tag_out, m_axi_rlast, m_axi_rdata};
        assign m_axi_rready = rsp_ready_in[i];

        if (NUM_INPUTS > 1) begin : g_rsp_sel_in
            assign rsp_sel_in[i] = m_axi_rid[TAG_SEL_IDX +: LOG_NUM_REQS];
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

    assign m_axi_rvalid_0 = rsp_valid_out[0];
    assign {
        m_axi_rid_0,
        m_axi_rlast_0,
        m_axi_rdata_0
    } = rsp_data_out[0];
    assign rsp_ready_out[0] = m_axi_rready_0;


    assign m_axi_rvalid_1 = rsp_valid_out[1];
    assign {
        m_axi_rid_1,
        m_axi_rlast_1,
        m_axi_rdata_1
    } = rsp_data_out[1];
    assign rsp_ready_out[1] = m_axi_rready_1;

endmodule
