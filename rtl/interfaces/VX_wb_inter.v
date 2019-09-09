
`ifndef VX_WB_INTER

`define VX_WB_INTER


interface VX_wb_inter ();

	wire[`NT_M1:0][31:0]  write_data; 
	wire[4:0]      		  rd;
	wire[1:0]      		  wb;
	wire[`NT_M1:0]        wb_valid;
	wire[`NW_M1:0]        wb_warp_num;



	modport snk (
		input write_data,
		input rd,
		input wb,
		input wb_valid,
		input wb_warp_num
	);


	modport src (
		output write_data,
		output rd,
		output wb,
		output wb_valid,
		output wb_warp_num
	);

endinterface



`endif