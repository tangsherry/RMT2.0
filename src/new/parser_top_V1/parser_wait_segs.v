`timescale 1ns / 1ps
//1.取来自滤波器的控制报文,控制报文属于parser模块的，布置控制规则到ram里
//2.对数据报文进行处理，【1】取8段2048b的数据报文，少于2048b的数据报文则补充0字段输出，【2】输出数据报文的vlan，
//【3】拆分数据报文中待处理的报文头和其余字段。
//3.取出数据报文对应vlan所匹配控制报文规定的提取指令。

//取8段报文头字段，2048bit，不够2048bit的补充至2048bit。

module parser_wait_segs #(
	parameter C_AXIS_DATA_WIDTH = 256,
	parameter C_AXIS_TUSER_WIDTH = 128,
	parameter C_NUM_SEGS = 8,
	parameter PARSER_MOD_ID = 3'd1,
	parameter PARSER_WIDTH = 16,
	parameter PARSER_NUM = 24,
	parameter C_PARSER_RAM_WIDTH = PARSER_WIDTH*PARSER_NUM,
	parameter C_VLANID_WIDTH = 12
)
(
	input											axis_clk     ,
	input											aresetn      ,
	// 
	input [C_AXIS_DATA_WIDTH-1:0]					s_axis_tdata ,
	input [C_AXIS_TUSER_WIDTH-1:0]					s_axis_tuser ,
	input [C_AXIS_DATA_WIDTH/8-1:0]					s_axis_tkeep ,
	input											s_axis_tvalid,
	input											s_axis_tlast ,
	output reg										s_axis_tready,
	
	//
	output reg [C_AXIS_DATA_WIDTH-1:0]	            o_seg_tdata   ,//just use the ram to out
	output reg  									o_seg_wea     ,
	output reg [2:0] 								o_seg_addra   ,
	output reg										o_seg_wait_end,//only set high once clk if 8 segs get
	// output reg dina,
	output reg[C_AXIS_TUSER_WIDTH-1:0]				o_tuser_1st   ,

	//output vlan
	output reg [C_VLANID_WIDTH-1:0] 				o_vlan        ,
	output reg 										o_vlan_valid  

);

localparam	WAIT_1ST_SEG=0,
			WAIT_2ND_SEG=1,
			WAIT_3RD_SEG=2,
			WAIT_4TH_SEG=3,
			WAIT_5TH_SEG=4,
			WAIT_6TH_SEG=5,
			WAIT_7TH_SEG=6,
			WAIT_8TH_SEG=7,
			OUTPUT_SEGS =8,
			EMPTY_1CYCLE=9,
			EMPTY_2CYCLE=10,
			EMPTY_3CYCLE=11,
			EMPTY_4CYCLE=12,
			EMPTY_5CYCLE=13,
			EMPTY_6CYCLE=14,
			EMPTY_7CYCLE=15,
			EMPTY_8CYCLE=16,
			WAIT_TILL_LAST=17;

reg [C_AXIS_DATA_WIDTH-1:0 ] r_segs_tdata_next ;
reg [C_AXIS_TUSER_WIDTH-1:0] r_tuser_1st_next  ;
reg 						 r_segs_valid_next ;
reg         				 r_seg_wea_next    ;
reg [2:0]   				 r_seg_addra_next  ;
reg 						 s_axis_tready_next;
reg [5:0]                    state,state_next  ;




wire [11:0] vlan_id;
assign vlan_id = {s_axis_tdata[115:112],s_axis_tdata[127:120]};


reg [11:0] vlan_id_next    ;
reg        vlan_valid_next ;

//经过过滤器之后的数据报文和控制报文一定是可以进行rmt处理的有效报文，区别在不知道该报文的长度，
//是否满足进行2048b的查找
always @(*) begin
	state_next = state;
	
	r_segs_tdata_next  = o_seg_tdata  ;
	r_segs_valid_next  = 0            ;
	r_seg_addra_next   = 3'd0         ;
	r_seg_wea_next     = 1'b0         ;
  
	r_tuser_1st_next   = o_tuser_1st  ;
	s_axis_tready_next = s_axis_tready;

	vlan_id_next       = o_vlan       ;
	vlan_valid_next    = 1'b0         ;

	case (state)
		// at least 2 segs
		WAIT_1ST_SEG: begin
			if (s_axis_tvalid) begin
				r_seg_wea_next     = 1'b1        ;
				r_seg_addra_next   = 3'd0        ;
				r_segs_tdata_next  = s_axis_tdata;
				r_tuser_1st_next   = s_axis_tuser;
 
				vlan_id_next       = {s_axis_tdata[115:112],s_axis_tdata[127:120]};
				vlan_valid_next    = 1'b1        ;
				s_axis_tready_next = 1'b1        ;
				//
				state_next         = WAIT_2ND_SEG;
			end
		end
		WAIT_2ND_SEG: begin
			if (s_axis_tvalid) begin
				r_segs_tdata_next = s_axis_tdata;
				r_seg_addra_next  = 3'd1        ;
				r_seg_wea_next    = 1'b1        ;
				if (s_axis_tlast) begin //数据报文一定不会小于64B，所以在两段这里判别是否是最后一段
					state_next = EMPTY_1CYCLE;
					s_axis_tready_next = 0; //如果第2段数据报文就少于2048b，这里补充完整2048b的数据，不再向过滤器阶段取数据
				end
				else begin
					state_next = WAIT_3RD_SEG;
				end
			end
		end
		WAIT_3RD_SEG: begin
			if (s_axis_tvalid) begin
				r_segs_tdata_next = s_axis_tdata;
				r_seg_addra_next  = 3'd2;
				r_seg_wea_next    = 1'b1;
				if (s_axis_tlast) begin
					s_axis_tready_next = 0;
					state_next = EMPTY_2CYCLE;
				end
				else begin
					state_next = WAIT_4TH_SEG;
				end
			end
		end
		WAIT_4TH_SEG: begin
			if (s_axis_tvalid) begin
				r_segs_tdata_next = s_axis_tdata;
				r_seg_addra_next = 3'd3;
				r_seg_wea_next = 1'b1;
				if (s_axis_tlast) begin
					s_axis_tready_next = 0;
					state_next = EMPTY_3CYCLE;
				end
				else begin
					state_next = WAIT_5TH_SEG;
				end
			end
		end
		WAIT_5TH_SEG: begin
			if (s_axis_tvalid) begin
				r_segs_tdata_next = s_axis_tdata;
				r_seg_addra_next = 3'd4;
				r_seg_wea_next = 1'b1;

				if (s_axis_tlast) begin
					s_axis_tready_next = 0;
					state_next = EMPTY_4CYCLE;
				end
				else begin
					state_next = WAIT_6TH_SEG;
				end
			end
		end
		WAIT_6TH_SEG: begin
			if (s_axis_tvalid) begin
				r_segs_tdata_next = s_axis_tdata;
				r_seg_addra_next = 3'd5;
				r_seg_wea_next = 1'b1;
				if (s_axis_tlast) begin
					s_axis_tready_next = 0;
					state_next = EMPTY_5CYCLE;
				end
				else begin
					state_next = WAIT_7TH_SEG;
				end
			end
		end
		WAIT_7TH_SEG: begin
			if (s_axis_tvalid) begin
				r_segs_tdata_next= s_axis_tdata;
				r_seg_addra_next = 3'd6;
				r_seg_wea_next = 1'b1;
				if (s_axis_tlast) begin
					s_axis_tready_next = 0;
					state_next = EMPTY_6CYCLE;
				end
				else begin
					state_next = WAIT_8TH_SEG;
				end
			end
		end
		WAIT_8TH_SEG: begin
			if (s_axis_tvalid) begin
				r_segs_tdata_next = s_axis_tdata;
				r_seg_addra_next = 3'd7;
				r_seg_wea_next = 1'b1;
				r_segs_valid_next = 1;
				if (s_axis_tlast) begin //正好是8段报文结束
					s_axis_tready_next = 1;
					state_next = WAIT_1ST_SEG;
				end
				else begin
					state_next = WAIT_TILL_LAST; //超过8段报文结束
				end
			end
		end

		EMPTY_1CYCLE: begin
			
			s_axis_tready_next = 0;
			state_next = EMPTY_2CYCLE;
		end
		
		EMPTY_2CYCLE: begin
			
			s_axis_tready_next = 0;
			state_next = EMPTY_3CYCLE;
		end

		EMPTY_3CYCLE: begin
			
			s_axis_tready_next = 0;
			state_next = EMPTY_4CYCLE;
		end

		EMPTY_4CYCLE: begin
			
			s_axis_tready_next = 0;
			state_next = EMPTY_5CYCLE;
		end

		EMPTY_5CYCLE: begin
			
			s_axis_tready_next = 0;
			state_next = EMPTY_6CYCLE;
		end

		EMPTY_6CYCLE: begin
			r_segs_valid_next  = 1;
			s_axis_tready_next = 1;
			state_next = WAIT_1ST_SEG;
		end

		WAIT_TILL_LAST: begin //等待一个报文的结束，这里一个报文只提取2048b
			if (s_axis_tlast && s_axis_tvalid) begin
				s_axis_tready_next = 1;
				state_next = WAIT_1ST_SEG;
			end
		end
	endcase
end

always @(posedge axis_clk) begin
	if (~aresetn) begin
		state          <= WAIT_1ST_SEG       ;
		o_seg_tdata    <= 256'd0             ;
		o_seg_wait_end <= 1'd0               ;
		o_seg_wea      <= 1'd0               ;
		o_seg_addra    <= 1'd0               ;
		o_tuser_1st    <= 128'd0             ;
		s_axis_tready  <= 1'd1               ;
		o_vlan         <= 1'd0               ;
		o_vlan_valid   <= 1'd0               ;
	end
	else begin
		state          <= state_next         ;
		o_seg_wea      <= r_seg_wea_next     ;
		o_seg_addra    <= r_seg_addra_next   ;
		o_seg_tdata    <= r_segs_tdata_next  ;
		o_tuser_1st    <= r_tuser_1st_next   ;
  
		o_seg_wait_end <= r_segs_valid_next  ;
		s_axis_tready  <= s_axis_tready_next ;
		o_vlan         <= vlan_id_next       ;
		o_vlan_valid   <= vlan_valid_next    ;
	end
end

endmodule
