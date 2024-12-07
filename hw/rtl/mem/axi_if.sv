interface axi_if #(
    parameter AXI_DATA_WIDTH = 0,
    parameter AXI_ADDR_WIDTH = 0,
    parameter AXI_TID_WIDTH  = 0,
    parameter AXI_NUM_BANKS  = 1
) ();

    typedef struct packed {
        logic [AXI_ADDR_WIDTH-1:0] addr;
        logic [AXI_TID_WIDTH-1:0]  id;
        logic [7:0]                len;
        logic [2:0]                size;
        logic [1:0]                burst;
        logic [1:0]                lock;
        logic [3:0]                cache;
        logic [2:0]                prot;
        logic [3:0]                qos;
        logic [3:0]                region;
    } aw_req_data_t;

    typedef struct packed {
        logic [AXI_DATA_WIDTH-1:0] data;
        logic [AXI_DATA_WIDTH/8-1:0] strb;
        logic last;
    } w_req_data_t;

    typedef struct packed {
        logic [AXI_TID_WIDTH-1:0] id;
        logic [1:0]               resp;
    } w_resp_data_t;

    typedef struct packed {
        logic [AXI_ADDR_WIDTH-1:0] addr;
        logic [AXI_TID_WIDTH-1:0]  id;
        logic [7:0]                len;
        logic [2:0]                size;
        logic [1:0]                burst;
        logic [1:0]                lock;
        logic [3:0]                cache;
        logic [2:0]                prot;
        logic [3:0]                qos;
        logic [3:0]                region;
    } ar_req_data_t;

    typedef struct packed {
        logic [AXI_DATA_WIDTH-1:0] data;
        logic last;
        logic [AXI_TID_WIDTH-1:0]  id;
        logic [1:0]               resp;
    } r_resp_data_t;



    // AXI write request address channel
    logic axi_awvalid[AXI_NUM_BANKS];
    logic axi_awready[AXI_NUM_BANKS];
    aw_req_data_t axi_awdata[AXI_NUM_BANKS];

    // AXI write request data channel
    logic axi_wvalid[AXI_NUM_BANKS];
    logic axi_wready[AXI_NUM_BANKS];
    w_req_data_t axi_wdata[AXI_NUM_BANKS];


    // AXI write response channel
    logic axi_bvalid[AXI_NUM_BANKS];
    logic axi_bready[AXI_NUM_BANKS];
    w_resp_data_t axi_bdata[AXI_NUM_BANKS];

    // AXI read request channel
    logic axi_arvalid[AXI_NUM_BANKS];
    logic axi_arready[AXI_NUM_BANKS];
    ar_req_data_t axi_ardata[AXI_NUM_BANKS];

    // AXI read response channel
    logic axi_rvalid[AXI_NUM_BANKS];
    logic axi_rready[AXI_NUM_BANKS];
    r_resp_data_t axi_rdata[AXI_NUM_BANKS];


    
    output axi_awvalid,
    output axi_awdata,
    input  axi_awready,

    output axi_wvalid,
    output axi_wdata,
    input  axi_wready,

    input  axi_bvalid,
    output axi_bdata,

    output axi_arvalid,
    output axi_ardata,
    input  axi_arready,

    input  axi_rvalid,
    output axi_rdata
    

// // Memory AXI bus
//     // AXI write request address channel
//     output wire                         m_axi_awvalid [AXI_NUM_BANKS],
//     input wire                          m_axi_awready [AXI_NUM_BANKS],
//     output wire [AXI_ADDR_WIDTH-1:0]    m_axi_awaddr [AXI_NUM_BANKS],
//     output wire [AXI_TID_WIDTH-1:0]     m_axi_awid [AXI_NUM_BANKS],
//     output wire [7:0]                   m_axi_awlen [AXI_NUM_BANKS],
//     output wire [2:0]                   m_axi_awsize [AXI_NUM_BANKS],
//     output wire [1:0]                   m_axi_awburst [AXI_NUM_BANKS],
//     output wire [1:0]                   m_axi_awlock [AXI_NUM_BANKS],
//     output wire [3:0]                   m_axi_awcache [AXI_NUM_BANKS],
//     output wire [2:0]                   m_axi_awprot [AXI_NUM_BANKS],
//     output wire [3:0]                   m_axi_awqos [AXI_NUM_BANKS],
//     output wire [3:0]                   m_axi_awregion [AXI_NUM_BANKS],

//     // AXI write request data channel
//     output wire                         m_axi_wvalid [AXI_NUM_BANKS],
//     input wire                          m_axi_wready [AXI_NUM_BANKS],
//     output wire [AXI_DATA_WIDTH-1:0]    m_axi_wdata [AXI_NUM_BANKS],
//     output wire [AXI_DATA_WIDTH/8-1:0]  m_axi_wstrb [AXI_NUM_BANKS],
//     output wire                         m_axi_wlast [AXI_NUM_BANKS],

//     // AXI write response channel
//     input wire                          m_axi_bvalid [AXI_NUM_BANKS],
//     output wire                         m_axi_bready [AXI_NUM_BANKS],
//     input wire [AXI_TID_WIDTH-1:0]      m_axi_bid [AXI_NUM_BANKS],
//     input wire [1:0]                    m_axi_bresp [AXI_NUM_BANKS],

//     // AXI read request channel
//     output wire                         m_axi_arvalid [AXI_NUM_BANKS],
//     input wire                          m_axi_arready [AXI_NUM_BANKS],
//     output wire [AXI_ADDR_WIDTH-1:0]    m_axi_araddr [AXI_NUM_BANKS],
//     output wire [AXI_TID_WIDTH-1:0]     m_axi_arid [AXI_NUM_BANKS],
//     output wire [7:0]                   m_axi_arlen [AXI_NUM_BANKS],
//     output wire [2:0]                   m_axi_arsize [AXI_NUM_BANKS],
//     output wire [1:0]                   m_axi_arburst [AXI_NUM_BANKS],
//     output wire [1:0]                   m_axi_arlock [AXI_NUM_BANKS],
//     output wire [3:0]                   m_axi_arcache [AXI_NUM_BANKS],
//     output wire [2:0]                   m_axi_arprot [AXI_NUM_BANKS],
//     output wire [3:0]                   m_axi_arqos [AXI_NUM_BANKS],
//     output wire [3:0]                   m_axi_arregion [AXI_NUM_BANKS],

//     // AXI read response channel
//     input wire                          m_axi_rvalid [AXI_NUM_BANKS],
//     output wire                         m_axi_rready [AXI_NUM_BANKS],
//     input wire [AXI_DATA_WIDTH-1:0]     m_axi_rdata [AXI_NUM_BANKS],
//     input wire                          m_axi_rlast [AXI_NUM_BANKS],
//     input wire [AXI_TID_WIDTH-1:0]      m_axi_rid [AXI_NUM_BANKS],
//     input wire [1:0]                    m_axi_rresp [AXI_NUM_BANKS],



endinterface