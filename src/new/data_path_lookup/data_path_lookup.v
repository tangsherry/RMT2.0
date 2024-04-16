`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/12/30 10:39:55
// Design Name: 
// Module Name: data_path_lookup
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
//功能实现：1.1024b字段协议解析，生成查找parser_table的TCAM-index索引
//功能实现：2.将来自过滤器的数据报文原路转发到parser_wait_segs阶段
//功能实现：3.将该模块的配置匹配报文进行解析
//功能实现：4.与该模块无关的控制报文直接转发出去

module data_path_lookup #(
	parameter C_AXIS_DATA_WIDTH= 256,
	parameter SEG_ADDR = 3,
	parameter CFG_ORDER_NUM = 128,//how to solve the 6
	parameter CFG_S_ORDER_WID = 16
)(
    input          		axis_clk         ,
    input          		aresetn          ,
 
	input     [7:0]                                  i_offset_byte           ,//前一步提取了偏移地址，影响读出的字节数
	input                                            i_offset_byte_valid     ,
	//in s_axis_path_data
	input [C_AXIS_DATA_WIDTH-1:0]		             i_dp_segs_tdata         ,
	input 								             i_dp_segs_valid         ,
	input 								             i_dp_segs_wea           ,
	input [SEG_ADDR-1:0]				             i_dp_segs_addra         ,

	// in control path
	input 	[CFG_ORDER_NUM*CFG_S_ORDER_WID-1:0]      i_cfg_bit_info  		,
	input 				                             i_cfg_bit_updata		,

    output     reg [CFG_ORDER_NUM-1:0]               o_dp_bit               ,
	output     reg                                   o_dp_bit_valid         ,
	output     reg [CFG_ORDER_NUM-1:0]               o_dp_bit_mask          ,

	output     [C_AXIS_DATA_WIDTH-1:0]               o_dp_segs_tdata        ,
	output                                           o_dp_segs_valid        ,
	output                                           o_dp_segs_wea          ,
	output     [SEG_ADDR-1:0]                        o_dp_segs_addra 

    );
localparam GROUP = (CFG_ORDER_NUM-1)/4+1;
reg [GROUP*64-1:0]r_cfg_bit_info;
reg r_cfg_bit_updata;
always @(posedge axis_clk)begin
	if(~aresetn) begin
		r_cfg_bit_info <= 0;
		r_cfg_bit_updata <= 0;
	end
	else if(i_cfg_bit_updata)begin
		r_cfg_bit_info <= i_cfg_bit_info;//为了方便处理，扩展寄存器位宽是4的倍数
		r_cfg_bit_updata <= 1'b1;
	end
	else begin
		r_cfg_bit_info <= r_cfg_bit_info;
		r_cfg_bit_updata <= 0;
	end
end
//=====================wait data===================================
assign o_dp_segs_tdata = i_dp_segs_tdata ;
assign o_dp_segs_valid = i_dp_segs_valid ;
assign o_dp_segs_wea   = i_dp_segs_wea   ;
assign o_dp_segs_addra = i_dp_segs_addra ;


reg     [1:0]   	r_tdata_addr       	;//写入256b的地址
reg 	[255:0] 	r_seg_tdata			;
reg 			 	r_seg_wea			;
reg                 r_wait_seg_end      ;

always @(posedge axis_clk) begin
	if(!aresetn)begin
		r_tdata_addr   <= 2'd0  ;
		r_seg_tdata    <= 256'd0;
		r_seg_wea      <= 1'b0  ;
		r_wait_seg_end <= 1'd0  ;
	end
	else begin
		if(i_dp_segs_addra < 3'd4 )begin
			r_tdata_addr <= i_dp_segs_addra;
			r_seg_tdata  <= i_dp_segs_tdata;
			r_seg_wea    <= i_dp_segs_wea  ;
			if(i_dp_segs_addra == 3'd3)
				r_wait_seg_end <= 1'b1;
			else 
				r_wait_seg_end <= 1'b0;
		end
		else begin
			r_tdata_addr   <= 0   ;
			r_seg_tdata    <= 0   ;
			r_seg_wea      <= 0   ;
			r_wait_seg_end <= 1'b0;
		end
	end
end

/*==============================extract logic==================================*/
//将配置报文和数据报文取出来预处理，1.由上位机直接设置固定这些指令（优先），2.数据报文命中这些指令
reg [63:0] r_cfg_bit_info_group    [GROUP-1:0];//将128b的提取配置信息分4个一组，每组64位信息，分32组
   
wire [2:0] bit_act_low         [GROUP-1:0];
wire 	   bit_act_low_valid   [GROUP-1:0];
wire [7:0] bit_o               [GROUP-1:0];
wire [3:0] bit_mask            [GROUP-1:0];

reg [2:0]  r_bit_act_low       [GROUP-1:0];
reg 	   r_bit_act_low_valid [GROUP-1:0];
reg [7:0]  r_bit               [GROUP-1:0];
reg [3:0]  r_bit_mask          [GROUP-1:0];

wire [GROUP-1:0] w_bit_out_valid;
wire [GROUP-1:0] w_bit_out;
wire [GROUP-1:0] w_bit_out_mask;
// reg [127:0] bit_seg_out_valid;
generate
	genvar index;
	for(index=0;index < GROUP;index = index+1)begin://将128条指令分为32组，每组解析四个指令，因为下一组数据可以提取需要4个周期
	sub_op
	//将128X8b数据分为32X32组
	always @(posedge axis_clk) begin
		if(!aresetn) begin
			r_cfg_bit_info_group[index ] <= 0;
		end
		else begin
			if(r_cfg_bit_updata)
				r_cfg_bit_info_group[index] <= {r_cfg_bit_info[(3*GROUP+index+1)*16-1:(3*GROUP+index)*16],r_cfg_bit_info[(2*GROUP+index+1)*16-1:(2*GROUP+index)*16],r_cfg_bit_info[(1*GROUP+index+1)*16-1:(GROUP+index)*16],r_cfg_bit_info[(index+1)*16-1:index*16]};
			else 
				r_cfg_bit_info_group[index ] <= r_cfg_bit_info_group[index ];
		end
	end

	sub0_bit #(
		.BIT_WIDTH(16),
		.BIT_GROUP_NUM(4)							
	)
	sub0_bit(
		.axis_clk           (axis_clk					),
		.aresetn            (aresetn 					),
	//in  
		.i_bit_bram         (r_cfg_bit_info_group[index]),//each sub0_parser only solve 2 index
		.i_offset_byte      (i_offset_byte              ),
        .i_offset_byte_valid(i_offset_byte_valid        ),

		.i_seg_tdata        (r_seg_tdata      			),
		.i_seg_wea          (r_seg_wea        			),
		.i_seg_addra        (r_tdata_addr     			),
		.i_wait_segs_end    (r_wait_seg_end             ),
	//out
		.o_bit_act_low      (bit_act_low[index]      	),
		.o_bit_act_low_valid(bit_act_low_valid[index]	),
		.o_bit_8            (bit_o[index]            	),//8 bits
		.o_bit_mask         (bit_mask[index]          )

	);

always @(posedge axis_clk) begin
	if(!aresetn) begin
		r_bit_act_low[index]       	<= 1'b0						;     
		r_bit_act_low_valid[index] 	<= 1'b0						;
		r_bit[index]               	<= 8'd0						;  
		r_bit_mask[index]           <= 4'd0                     ;      
	end	
	else begin	
		r_bit_act_low[index]       	<= bit_act_low[index]		;     
		r_bit_act_low_valid[index] 	<= bit_act_low_valid[index]	;
		r_bit[index]               	<= bit_o[index]				;    
		r_bit_mask[index]           <= bit_mask[index]          ;
	end
end

//we need the same clk of the parse_act and pkts_hdr
	sub1_bit #(
	.SUB_PKTS_LEN (8),
	.L_BIT_ACT_LEN(3),
	.O_BIT_LEN    (1)
	)
	sub1_bit (
		.clk				(axis_clk					),
		.aresetn			(aresetn 					),

		.i_bit_act_valid	(r_bit_act_low_valid[index]	),
		.i_bit_act			(r_bit_act_low[index]		),
		.i_bit_hdr			(r_bit[index]				),//8bits
		.i_bit_mask         (r_bit_mask[index]          ),

		.o_bit_out_valid	(w_bit_out_valid[index]		),
		.o_bit_out			(w_bit_out[index]			),
		.o_bit_mask         (w_bit_out_mask[index]      )
		// .o_bit_seg_valid    (bit_seg_out_valid[index])//we can get the val in 5 clk ,and each clk 4 parser
	);
	end

endgenerate
localparam BIT_IDLE = 0,
		   BIT_1    = 1,
		   BIT_2    = 2,
		   BIT_3    = 3,
		   BIT_END  = 4;

reg [3:0] bit_o_state;
reg [4*GROUP-1:0] r_dp_bit      ;
reg 			  r_dp_bit_valid;

always @(posedge axis_clk) begin
	if(!aresetn) begin
		r_dp_bit <= 0;
		r_dp_bit_valid <= 1'd0;
		bit_o_state <= BIT_IDLE;
	end
	else begin 
		case(bit_o_state)
			BIT_IDLE :begin
				if(w_bit_out_valid[0] == 1'b1)begin
					r_dp_bit[GROUP-1:0]  <= w_bit_out;
					r_dp_bit_valid <= 1'd0;
					bit_o_state <= BIT_1  ;
				end
				else begin
					r_dp_bit       <= r_dp_bit;
					r_dp_bit_valid <= 1'd0    ;
					bit_o_state <= BIT_IDLE   ;
				end
			end
			BIT_1:begin
				if(w_bit_out_valid[0] == 1'b1)begin
					r_dp_bit[2*GROUP-1:GROUP]  <= w_bit_out;
					r_dp_bit_valid <= 1'd0;
					bit_o_state <= BIT_2  ;
				end
				else begin
					r_dp_bit       <= r_dp_bit;
					r_dp_bit_valid <= 1'd0    ;
					bit_o_state <= BIT_1  ;
				end
			end
			BIT_2:begin
				if(w_bit_out_valid[0] == 1'b1)begin
					r_dp_bit[3*GROUP-1:2*GROUP]  <= w_bit_out;
					r_dp_bit_valid <= 1'd0;
					bit_o_state <= BIT_3  ;
				end
				else begin
					r_dp_bit       <= r_dp_bit;
					r_dp_bit_valid <= 1'd0    ;
					bit_o_state <= BIT_2      ;
				end
			end
			BIT_3:begin
				if(w_bit_out_valid[0] == 1'b1)begin
					r_dp_bit[4*GROUP-1:3*GROUP]  <= w_bit_out;
					r_dp_bit_valid <= 1'd1  ;
					bit_o_state <= BIT_END  ;
				end
				else begin
					r_dp_bit       <= r_dp_bit;
					r_dp_bit_valid <= 1'd0    ;
					bit_o_state    <= BIT_3   ;
				end
			end
			BIT_END:begin
				r_dp_bit    <= r_dp_bit ;
				bit_o_state <= BIT_IDLE ;
				r_dp_bit_valid <= 1'd0  ;
			end
		endcase
	end
end
//这里的总线保持不知道综合实现时候是否能过
always @(posedge axis_clk) begin
	if(~aresetn) begin
		o_dp_bit <= 0;
		o_dp_bit_valid <= 0;
	end
	else if(r_dp_bit_valid)begin
		o_dp_bit <= r_dp_bit;
		o_dp_bit_valid <= 1'b1;
	end
	else begin
		o_dp_bit <= o_dp_bit;
		o_dp_bit_valid <= 1'b0;
	end
end


endmodule
