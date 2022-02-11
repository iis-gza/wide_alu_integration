module wide_alu_top 
#(
  parameter type reg_req_t = logic,
  parameter type reg_rsp_t = logic
  )(
    input logic clk_i,
    input logic rst_ni,
    input logic test_mode_i,
    input 	reg_req_t reg_req_i,
    output 	reg_rsp_t reg_rsp_o
);

   wide_alu_reg2hw_t reg_file_to_ip ;
   wide_alu_hw2reg_t ip_to_reg_file;

   wide_alu wide_alu_i 
     (
      .clk_i  (clk_i),                      
      .rst_ni (rst_ni),              
      .trigger_i (reg_file_to_ip.ctrl1.trigger.q & reg_file_to_ip.ctrl1.trigger.qe),
      .clear_err_i(reg_file_to_ip.ctrl1.clear_err.q & reg_file_to_ip.ctrl1.clear_err.qe),
      .op_a_i(reg_file_to_ip.op_a),
      .op_b_i(reg_file_to_ip.op_b),
      .result_o(ip_to_reg_file.result),
      .deaccel_factor_we_i(reg_file_to_ip.ctrl2.delay.qe),
      .deaccel_factor_i(reg_file_to_ip.ctrl2.delay.q),
      .deaccel_factor_o(ip_to_reg_file.ctrl2.delay.d),
      .op_sel_we_i(reg_file_to_ip.ctrl2.opsel.qe),
      .op_sel_i(wide_alu_pkg::optype_e'(reg_file_to_ip.ctrl2.opsel.q)),   
      .op_sel_o (wide_alu_pkg::optype_e'(ip_to_reg_file.ctrl2.opsel.d)),   
      .status_o (ip_to_reg_file.status.d)
      );
   
   wide_alu_reg_top wide_alu_reg_top_i
     (
      .clk_i (clk_i),                                                               
      .rst_ni (rst_ni),                                                              
      .reg_req_i (reg_req_i),                                                
      .reg_rsp_o (reg_rsp_o),                                                
      .reg2hw (reg_file_to_ip), // Write                
      .hw2reg (ip_to_reg_file), // Read                 
      .devmode_i (1)
      );

endmodule
