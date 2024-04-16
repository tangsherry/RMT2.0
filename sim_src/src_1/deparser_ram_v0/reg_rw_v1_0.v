//////////////////////////////////////////////////////////////////////////////////
// Company       :                                                                   
// Engineer      :                                         
// Create Date   :                                              
// Design Name   :                                                                   
// Module Name   : reg_rw_v1_0.v                                                   
// Project Name  :                                                                  
// Target Devices:                                                                
// Tool Versions :                                                                 
// Description   : ��д�Ĵ���                                                                
// Dependencies  :                                                                  
// Revision 1.0 - File Created                                                    
// Additional Comments:                                                           
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ns

module reg_rw_v1_0(
    input                i_clk       
   ,input                i_rst 
   ,input                i_ini_en      
   ,output  reg [7:0]    o_reg       
   ,input                i_cs         
   ,input       [7:0]    i_ini_value         
   ,input       [7:0 ]   i_wdat              
   );
    
    always @ (posedge i_clk) begin
      if(i_rst == 1'b0) begin
         o_reg <= 1'b0;
      end
      else if(i_cs == 1'b1) begin //新写入值
         o_reg[7:0]   <= i_wdat[7:0]+1'b1  ;//仅为了仿真验证该处数据放回有改动
      end
      else if(i_ini_en == 1'b1)begin
         o_reg  <= i_ini_value; //载入初始值
      end
      else begin               
      	o_reg  <= o_reg  ; //指令修改之后，数据输出保持
      end                             
    end  
    
endmodule

// always @(q_reset or q_add or q_reg ) begin
//    case ({q_reset,q_add})
//       2'b00:begin
//          q_next <= q_reg;
//       end
//       2'b01:begin
//          q_next <= q_reg + 1'b1;
//       end
//       default:begin
//          q_next <= 32'd0;
//       end
//    endcase
// end
