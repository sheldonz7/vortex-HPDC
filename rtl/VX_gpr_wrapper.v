`include "VX_define.v"

module VX_gpr_wrapper (
	input wire                  clk,
	VX_wb_inter                 VX_writeback_inter,
	VX_forward_response_inter   VX_fwd_rsp,
	VX_gpr_read_inter           VX_gpr_read,
	VX_gpr_jal_inter            VX_gpr_jal,
	VX_gpr_clone_inter          VX_gpr_clone,
	VX_gpr_wspawn_inter         VX_gpr_wspawn,

	output wire[`NT_M1:0][31:0] out_a_reg_data,
	output wire[`NT_M1:0][31:0] out_b_reg_data,
	output wire                 out_clone_stall
	
);

	wire[`NW-1:0][`NT_M1:0][31:0] temp_a_reg_data;
	wire[`NW-1:0][`NT_M1:0][31:0] temp_b_reg_data;

	wire[`NT_M1:0][31:0] jal_data;
	genvar index;
	for (index = 0; index <= `NT_M1; index = index + 1) assign jal_data[index] = VX_gpr_jal.curr_PC;


	assign out_a_reg_data = VX_gpr_jal.is_jal ? jal_data :  temp_a_reg_data[VX_gpr_read.warp_num];

	assign out_b_reg_data = temp_b_reg_data[VX_gpr_read.warp_num];

	wire[31:0][31:0] w0_t0_registers;

	wire[`NW-1:0]  temp_clone_stall;

	assign out_clone_stall = (|temp_clone_stall);


	wire       curr_warp_zero     = VX_gpr_read.warp_num == 0;
	wire       context_zero_valid = (VX_writeback_inter.wb_warp_num == 0);
	wire       real_zero_isclone  = VX_gpr_clone.is_clone  && (VX_gpr_clone.warp_num == 0); 

	wire write_register = (VX_writeback_inter.wb != 2'h0) ? (1'b1) : (1'b0);

	VX_context VX_Context_zero(
		.clk              (clk),
		.in_warp          (curr_warp_zero),
		.in_wb_warp       (context_zero_valid),
		.in_valid         (VX_writeback_inter.wb_valid),
		.in_rd            (VX_writeback_inter.rd),
		.in_src1          (VX_gpr_read.rs1),
		.in_src2          (VX_gpr_read.rs2),
		.in_is_clone      (real_zero_isclone),
		.in_src1_fwd      (VX_fwd_rsp.src1_fwd),
		.in_src1_fwd_data (VX_fwd_rsp.src1_fwd_data),
		.in_src2_fwd      (VX_fwd_rsp.src2_fwd),
		.in_src2_fwd_data (VX_fwd_rsp.src2_fwd_data),
		.in_write_register(write_register),
		.in_write_data    (VX_writeback_inter.write_data),
		.out_a_reg_data   (temp_a_reg_data[0]),
		.out_b_reg_data   (temp_b_reg_data[0]),
		.out_clone_stall  (temp_clone_stall[0]),
		.w0_t0_registers  (w0_t0_registers)
	);

	genvar r;
	generate
		for (r = 1; r < `NW; r = r + 1) begin
			wire context_glob_valid = (VX_writeback_inter.wb_warp_num == r);
			wire curr_warp_glob     = VX_gpr_read.warp_num == r;
			wire real_wspawn        = VX_gpr_wspawn.is_wspawn && (VX_gpr_wspawn.which_wspawn == r); 
			wire real_isclone       = VX_gpr_clone.is_clone  && (VX_gpr_clone.warp_num == r);      
			VX_context_slave VX_Context_one(
				.clk              (clk),
				.in_warp          (curr_warp_glob),
				.in_wb_warp       (context_glob_valid),
				.in_valid         (VX_writeback_inter.wb_valid),
				.in_rd            (VX_writeback_inter.rd),
				.in_src1          (VX_gpr_read.rs1),
				.in_src2          (VX_gpr_read.rs2),
				.in_is_clone      (real_isclone),
				.in_src1_fwd      (VX_fwd_rsp.src1_fwd),
				.in_src1_fwd_data (VX_fwd_rsp.src1_fwd_data),
				.in_src2_fwd      (VX_fwd_rsp.src2_fwd),
				.in_src2_fwd_data (VX_fwd_rsp.src2_fwd_data),
				.in_write_register(write_register),
				.in_write_data    (VX_writeback_inter.write_data),
				.in_wspawn_regs   (w0_t0_registers),
				.in_wspawn        (real_wspawn),
				.out_a_reg_data   (temp_a_reg_data[r]),
				.out_b_reg_data   (temp_b_reg_data[r]),
				.out_clone_stall  (temp_clone_stall[r])
			);
		end
	endgenerate

endmodule