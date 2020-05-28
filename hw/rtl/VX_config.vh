`ifndef VX_CONFIG
`define VX_CONFIG

`include "VX_user_config.vh"

`ifndef NUM_CLUSTERS
`define NUM_CLUSTERS 1
`endif

`ifndef NUM_CORES
`define NUM_CORES 1
`endif

`ifndef NUM_WARPS
`define NUM_WARPS 8
`endif

`ifndef NUM_THREADS
`define NUM_THREADS 4
`endif

`ifndef NUM_BARRIERS
`define NUM_BARRIERS 4
`endif

`ifndef GLOBAL_BLOCK_SIZE
`define GLOBAL_BLOCK_SIZE 16
`endif

`ifndef NUM_CSRS
`define NUM_CSRS 1024
`endif

`ifndef STARTUP_ADDR
`define STARTUP_ADDR 32'h80000000
`endif

`ifndef SHARED_MEM_BASE_ADDR
`define SHARED_MEM_BASE_ADDR 32'hFE000000
`endif

`ifndef STACK_BASE_ADDR
`define STACK_BASE_ADDR 20'h6FFFF
`endif

`ifndef IO_BUS_BASE_ADDR
`define IO_BUS_BASE_ADDR 32'hFFFFFF00
`endif

`ifndef IO_BUS_ADDR_COUT
`define IO_BUS_ADDR_COUT 32'hFFFFFFFC
`endif

`ifndef L2_ENABLE
`define L2_ENABLE (`NUM_CORES > 2)
`endif

`ifndef L3_ENABLE
`define L3_ENABLE (`NUM_CLUSTERS > 1)
`endif

`define CSR_LTID    12'h020
`define CSR_LWID    12'h021
`define CSR_GTID    12'hF14 // reserved Hardware Thread ID (mhartid)
`define CSR_GWID    12'h023
`define CSR_GCID    12'h024
`define CSR_NT      12'h025
`define CSR_NW      12'h026
`define CSR_NC      12'h027

`define CSR_CYCLL   12'hC00
`define CSR_CYCLH   12'hC80
`define CSR_INSTL   12'hC02
`define CSR_INSTH   12'hC82

// ========================= Dcache Configurable Knobs ========================

// Size of cache in bytes
`ifndef DCACHE_SIZE
`define DCACHE_SIZE 2048
`endif

// Size of line inside a bank in bytes
`ifndef DBANK_LINE_SIZE
`define DBANK_LINE_SIZE `GLOBAL_BLOCK_SIZE
`endif

// Number of banks {1, 2, 4, 8,...}
`ifndef DNUM_BANKS
`define DNUM_BANKS 8
`endif

// Size of a word in bytes
`ifndef DWORD_SIZE
`define DWORD_SIZE 4
`endif

// Number of cycles to complete stage 1 (read from memory)
`ifndef DSTAGE_1_CYCLES
`define DSTAGE_1_CYCLES 1
`endif

// Core Request Queue Size
`ifndef DCREQ_SIZE
`define DCREQ_SIZE `NUM_WARPS
`endif

// Miss Reserv Queue Knob
`ifndef DMRVQ_SIZE
`define DMRVQ_SIZE (`NUM_WARPS*`NUM_THREADS)
`endif

// Dram Fill Rsp Queue Size
`ifndef DDFPQ_SIZE
`define DDFPQ_SIZE 32
`endif

// Snoop Req Queue Size
`ifndef DSNRQ_SIZE
`define DSNRQ_SIZE 16
`endif

// Core Writeback Queue Size
`ifndef DCWBQ_SIZE
`define DCWBQ_SIZE `DCREQ_SIZE
`endif

// Dram Writeback Queue Size
`ifndef DDWBQ_SIZE
`define DDWBQ_SIZE 4
`endif

// Dram Fill Req Queue Size
`ifndef DDFQQ_SIZE
`define DDFQQ_SIZE `DCREQ_SIZE
`endif

// Prefetcher
`ifndef DPRFQ_SIZE
`define DPRFQ_SIZE 32
`endif

`ifndef DPRFQ_STRIDE
`define DPRFQ_STRIDE 0
`endif

// ========================== Icache Configurable Knobs =======================

// Size of cache in bytes
`ifndef ICACHE_SIZE
`define ICACHE_SIZE 2048
`endif

// Size of line inside a bank in bytes
`ifndef IBANK_LINE_SIZE
`define IBANK_LINE_SIZE `GLOBAL_BLOCK_SIZE
`endif

// Number of banks {1, 2, 4, 8,...}
`ifndef INUM_BANKS
`define INUM_BANKS 1
`endif

// Size of a word in bytes
`ifndef IWORD_SIZE
`define IWORD_SIZE 4
`endif

// Number of cycles to complete stage 1 (read from memory)
`ifndef ISTAGE_1_CYCLES
`define ISTAGE_1_CYCLES 1
`endif

// Core Request Queue Size
`ifndef ICREQ_SIZE
`define ICREQ_SIZE `NUM_WARPS
`endif

// Miss Reserv Queue Knob
`ifndef IMRVQ_SIZE
`define IMRVQ_SIZE `ICREQ_SIZE
`endif

// Dram Fill Rsp Queue Size
`ifndef IDFPQ_SIZE
`define IDFPQ_SIZE 32
`endif

// Core Writeback Queue Size
`ifndef ICWBQ_SIZE
`define ICWBQ_SIZE `ICREQ_SIZE
`endif

// Dram Writeback Queue Size
`ifndef IDWBQ_SIZE
`define IDWBQ_SIZE 16
`endif

// Dram Fill Req Queue Size
`ifndef IDFQQ_SIZE
`define IDFQQ_SIZE `ICREQ_SIZE
`endif

// Prefetcher
`ifndef IPRFQ_SIZE
`define IPRFQ_SIZE 32
`endif

`ifndef IPRFQ_STRIDE
`define IPRFQ_STRIDE 0
`endif

// =========================== SM Configurable Knobs ==========================

// Size of cache in bytes
`ifndef SCACHE_SIZE
`define SCACHE_SIZE 1024
`endif

// Size of line inside a bank in bytes
`ifndef SBANK_LINE_SIZE
`define SBANK_LINE_SIZE `GLOBAL_BLOCK_SIZE
`endif

// Number of banks {1, 2, 4, 8,...}
`ifndef SNUM_BANKS
`define SNUM_BANKS 8
`endif

// Size of a word in bytes
`ifndef SWORD_SIZE
`define SWORD_SIZE 4
`endif

// Number of cycles to complete stage 1 (read from memory)
`ifndef SSTAGE_1_CYCLES
`define SSTAGE_1_CYCLES 1
`endif

// Core Request Queue Size
`ifndef SCREQ_SIZE
`define SCREQ_SIZE `NUM_WARPS
`endif

// Core Writeback Queue Size
`ifndef SCWBQ_SIZE
`define SCWBQ_SIZE `SCREQ_SIZE
`endif

// ======================== L2cache Configurable Knobs ========================

// Size of cache in bytes
`ifndef L2CACHE_SIZE
`define L2CACHE_SIZE 4096
`endif

// Size of line inside a bank in bytes
`ifndef L2BANK_LINE_SIZE
`define L2BANK_LINE_SIZE `GLOBAL_BLOCK_SIZE
`endif

// Number of banks {1, 2, 4, 8,...}
`ifndef L2NUM_BANKS
`define L2NUM_BANKS 8
`endif

// Size of a word in bytes
`ifndef L2WORD_SIZE
`define L2WORD_SIZE `L2BANK_LINE_SIZE
`endif

// Number of cycles to complete stage 1 (read from memory)
`ifndef L2STAGE_1_CYCLES
`define L2STAGE_1_CYCLES 1
`endif

// Core Request Queue Size
`ifndef L2CREQ_SIZE
`define L2CREQ_SIZE 32
`endif

// Miss Reserv Queue Knob
`ifndef L2MRVQ_SIZE
`define L2MRVQ_SIZE 32
`endif

// Dram Fill Rsp Queue Size
`ifndef L2DFPQ_SIZE
`define L2DFPQ_SIZE 32
`endif

// Snoop Req Queue Size
`ifndef L2SNRQ_SIZE
`define L2SNRQ_SIZE 16
`endif

// Core Writeback Queue Size
`ifndef L2CWBQ_SIZE
`define L2CWBQ_SIZE `L2CREQ_SIZE
`endif

// Dram Writeback Queue Size
`ifndef L2DWBQ_SIZE
`define L2DWBQ_SIZE 16
`endif

// Dram Fill Req Queue Size
`ifndef L2DFQQ_SIZE
`define L2DFQQ_SIZE `L2CREQ_SIZE
`endif

// Prefetcher
`ifndef L2PRFQ_SIZE
`define L2PRFQ_SIZE 32
`endif

`ifndef L2PRFQ_STRIDE
`define L2PRFQ_STRIDE 0
`endif

// ======================== L3cache Configurable Knobs ========================

// Size of cache in bytes
`ifndef L3CACHE_SIZE
`define L3CACHE_SIZE 8192
`endif

// Size of line inside a bank in bytes
`ifndef L3BANK_LINE_SIZE
`define L3BANK_LINE_SIZE `GLOBAL_BLOCK_SIZE
`endif

// Number of banks {1, 2, 4, 8,...}
`ifndef L3NUM_BANKS
`define L3NUM_BANKS 8
`endif

// Size of a word in bytes
`ifndef L3WORD_SIZE
`define L3WORD_SIZE `L3BANK_LINE_SIZE
`endif

// Number of cycles to complete stage 1 (read from memory)
`ifndef L3STAGE_1_CYCLES
`define L3STAGE_1_CYCLES 1
`endif

// Core Request Queue Size
`ifndef L3CREQ_SIZE
`define L3CREQ_SIZE 32
`endif

// Miss Reserv Queue Knob
`ifndef L3MRVQ_SIZE
`define L3MRVQ_SIZE `L3CREQ_SIZE
`endif

// Dram Fill Rsp Queue Size
`ifndef L3DFPQ_SIZE
`define L3DFPQ_SIZE 32
`endif

// Snoop Req Queue Size
`ifndef L3SNRQ_SIZE
`define L3SNRQ_SIZE 16
`endif

// Core Writeback Queue Size
`ifndef L3CWBQ_SIZE
`define L3CWBQ_SIZE `L3CREQ_SIZE
`endif

// Dram Writeback Queue Size
`ifndef L3DWBQ_SIZE
`define L3DWBQ_SIZE 16
`endif

// Dram Fill Req Queue Size
`ifndef L3DFQQ_SIZE
`define L3DFQQ_SIZE `L3CREQ_SIZE
`endif

// Prefetcher
`ifndef L3PRFQ_SIZE
`define L3PRFQ_SIZE 32
`endif

`ifndef L3PRFQ_STRIDE
`define L3PRFQ_STRIDE 0
`endif

 // VX_CONFIG
`endif
