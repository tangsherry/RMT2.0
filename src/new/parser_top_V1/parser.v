`timescale 1ns / 1ps

//1.parser是否还需要按照固定容器类型而在做调整，执行24条指令同步解析
module parser_top #(
	parameter C_S_AXIS_DATA_WIDTH = 256,
	parameter C_S_AXIS_TUSER_WIDTH = 128,
	parameter PHV_WIDTH = (8+4+2)*8*8+100+256, // check with the doc
	parameter PKTS_LEN = 2048,
	parameter PARSER_MOD_ID = 3'd1,
	parameter C_NUM_SEGS = 8,
	parameter C_VLANID_WIDTH = 12,
	parameter PARSER_NUM = 24,
	parameter PARSER_WIDTH = 16
)
(
	input									axis_clk,
	input									aresetn,

	// input slvae axi stream
	input [C_S_AXIS_DATA_WIDTH-1:0]			s_axis_tdata,
	input [C_S_AXIS_TUSER_WIDTH-1:0]		s_axis_tuser,
	input [C_S_AXIS_DATA_WIDTH/8-1:0]		s_axis_tkeep,
	input									s_axis_tvalid,
	input									s_axis_tlast,
	output									s_axis_tready,
	
	// output
	output reg								o_phv_valid,
	output reg [PHV_WIDTH-1:0]			    o_phv_data,

	// back-pressure signals
	input									i_stg_ready,

	// output vlan
	output [C_VLANID_WIDTH-1:0]				out_vlan,
	output									out_vlan_valid,
	input									out_vlan_ready,

	// output to different pkt fifo queues (i.e., data cache)
	output [C_S_AXIS_DATA_WIDTH-1:0]		m_axis_tdata_0,//uncatch the data
	output [C_S_AXIS_TUSER_WIDTH-1:0]		m_axis_tuser_0,
	output [C_S_AXIS_DATA_WIDTH/8-1:0]		m_axis_tkeep_0,
	output									m_axis_tlast_0,
	output									m_axis_tvalid_0,
	input									m_axis_tready_0,

	// ctrl path
	input [C_S_AXIS_DATA_WIDTH-1:0]			ctrl_s_axis_tdata,
	input [C_S_AXIS_TUSER_WIDTH-1:0]		ctrl_s_axis_tuser,
	input [C_S_AXIS_DATA_WIDTH/8-1:0]		ctrl_s_axis_tkeep,
	input									ctrl_s_axis_tvalid,
	input									ctrl_s_axis_tlast,

	output [C_S_AXIS_DATA_WIDTH-1:0]		ctrl_m_axis_tdata,
	output [C_S_AXIS_TUSER_WIDTH-1:0]		ctrl_m_axis_tuser,
	output [C_S_AXIS_DATA_WIDTH/8-1:0]		ctrl_m_axis_tkeep,
	output									ctrl_m_axis_tvalid,
	output									ctrl_m_axis_tlast

);

localparam	DO_PARER_GROUP = 12;//we can get 12 parser_act in one clk time 
localparam	DO_PARER_GROUP_NUM = 2;
localparam  PARSER_GROUP_WIDTH =  DO_PARER_GROUP_NUM*PARSER_WIDTH;
localparam  SUB_PKTS_LEN = 128;
localparam  L_PARSE_ACT_LEN = 8;
localparam  VAL_OUT_LEN = 64;
localparam  C_OFFBYTE_RAM_WIDTH = 16;
wire        m_axis_tready_queue;

wire [C_S_AXIS_DATA_WIDTH-1:0]    ctrl_s_axis_tdata1  ;
wire [C_S_AXIS_TUSER_WIDTH-1:0]   ctrl_s_axis_tuser1  ;
wire [C_S_AXIS_DATA_WIDTH/8-1:0]  ctrl_s_axis_tkeep1  ;
wire                              ctrl_s_axis_tvalid1 ;
wire                              ctrl_s_axis_tlast1  ;

assign m_axis_tready_queue = m_axis_tready_0;

localparam	IDLE=0,
			FLUSH_REST_PKTS=1;
reg [1:0] state, state_next;
reg [1:0] cur_queue, cur_queue_next;
wire [1:0] cur_queue_plus1;

reg  [31:0] parser_bram_in       [DO_PARER_GROUP-1:0];
reg         parser_bram_in_valid [DO_PARER_GROUP-1:0];
wire [7:0] parser_act_low        [DO_PARER_GROUP-1:0];
wire parser_act_low_valid        [DO_PARER_GROUP-1:0];
wire [63:0] segs_8B_1            [DO_PARER_GROUP-1:0];
wire [63:0] segs_8B_2            [DO_PARER_GROUP-1:0];

assign cur_queue_plus1 = (cur_queue==3)?0:cur_queue+1;

// ==================================================
assign m_axis_tdata_0 = s_axis_tdata; //add debug here
assign m_axis_tuser_0 = s_axis_tuser;
assign m_axis_tkeep_0 = s_axis_tkeep;
assign m_axis_tlast_0 = s_axis_tlast;
assign m_axis_tvalid_0 = s_axis_tvalid & m_axis_tready_0;

always @(*) begin
	state_next = state;
	cur_queue_next = cur_queue;

	case (state)
		IDLE: begin
			if (s_axis_tvalid) begin
				// if (m_axis_tready_queue[cur_queue]) begin
				if (m_axis_tready_queue) begin	

					if (!s_axis_tlast) begin
						state_next = FLUSH_REST_PKTS;
					end
					else begin
						cur_queue_next = cur_queue_plus1;
					end
				end
			end
		end
		FLUSH_REST_PKTS: begin
			if (s_axis_tvalid) begin
				// if (m_axis_tready_queue[cur_queue]) begin
					if (m_axis_tready_queue) begin

					if (s_axis_tlast) begin
						cur_queue_next = cur_queue_plus1;
						state_next = IDLE;
					end
				end
			end
		end
	endcase
end

always @(posedge axis_clk) begin
	if (~aresetn) begin
		state <= IDLE;
		cur_queue <= 0;
	end
	else begin
		state <= state_next;
		cur_queue <= cur_queue_next;
	end
end

// ==================================================

localparam P_IDLE=0;

reg [1:0] p_state, p_state_next;
reg [1:0] p_cur_queue, p_cur_queue_next;
wire [1:0] p_cur_queue_plus1;

assign p_cur_queue_plus1 = (p_cur_queue==3)?0:p_cur_queue+1;

wire p_cur_queue_val;
assign p_cur_queue_val = (p_cur_queue==0)?1:0;

wire o_phv_valid_w;
wire [PHV_WIDTH-1:0] phv_w;
reg [PHV_WIDTH-1:0] phv_next;
reg o_phv_valid_next;

always @(*) begin
	p_state_next = p_state;
	p_cur_queue_next = p_cur_queue;
	
	phv_next = o_phv_data;
	o_phv_valid_next = 0;
	case (p_state)
		P_IDLE: begin
			if (o_phv_valid_w) begin
				phv_next = phv_w;
				o_phv_valid_next = 1;
				p_cur_queue_next = p_cur_queue_plus1;
			end
		end
	endcase
end

always @(posedge axis_clk) begin
	if (~aresetn) begin
		p_state <= P_IDLE;
		p_cur_queue <= 0;
		o_phv_data <= 0;
		o_phv_valid <= 0;
	end
	else begin
		p_state <= p_state_next;
		p_cur_queue <= p_cur_queue_next;
		o_phv_data <= phv_next;
		o_phv_valid <= o_phv_valid_next;
	end
end

wire  val_out_valid      [DO_PARER_GROUP-1:0];
wire [63:0] val_out      [DO_PARER_GROUP-1:0];
wire [1 :0] val_out_type [DO_PARER_GROUP-1:0];
wire [2 :0] val_out_seq  [DO_PARER_GROUP-1:0];
wire sub_seg_out_valid   [DO_PARER_GROUP-1:0];

wire [C_S_AXIS_DATA_WIDTH-1:0]	            w_segs_tdata;
wire [C_S_AXIS_TUSER_WIDTH-1:0]				w_tuser_1st_out;
wire [383:0]								bram_out;
wire                                        bram_out_valid;
wire [8:0]                                  bram_out_addrb;
wire										w_segs_end;

reg [C_S_AXIS_DATA_WIDTH-1:0]	            r_segs_tdata;
reg [C_S_AXIS_TUSER_WIDTH-1:0]				r_tuser_1st_out;

reg 										r_segs_end;
reg [2:0]  									r_segs_addra;
reg        									r_segs_wea ;
wire       									w_segs_wea ;
wire [2:0] 									w_segs_addra;
wire [11:0]                                 wait_vlan;
wire                                        wait_vlan_valid;

//only get 2048b data,将parser模块要使用的数据截取出来
parser_wait_segs #(
	.C_AXIS_DATA_WIDTH (256),
	.C_AXIS_TUSER_WIDTH(128),
	.C_NUM_SEGS        (8  ),
	.PARSER_MOD_ID     (1  ),
	.PARSER_WIDTH      (16 ),
	.PARSER_NUM        (24 ),
	.C_PARSER_RAM_WIDTH(8  ),
	.C_VLANID_WIDTH    (12 )
)
get_segs
(
	.axis_clk				(axis_clk),
	.aresetn				(aresetn),

	.s_axis_tdata			(s_axis_tdata),//adjust the pkt is valid
	.s_axis_tuser			(s_axis_tuser),
	.s_axis_tkeep			(s_axis_tkeep),
	.s_axis_tvalid			(s_axis_tvalid),
	.s_axis_tlast			(s_axis_tlast),
	.s_axis_tready			(s_axis_tready),

	// output
	.o_seg_tdata			(w_segs_tdata),
	.o_seg_wea              (w_segs_wea  ),
	.o_seg_addra            (w_segs_addra),
	.o_seg_wait_end		    (w_segs_end),

	.o_tuser_1st			(w_tuser_1st_out),
	
	// vlan
	.o_vlan                 (wait_vlan),
	.o_vlan_valid           (wait_vlan_valid)
);


always @(posedge axis_clk) begin
	if (~aresetn) begin
		r_segs_tdata    <= 0;
		r_tuser_1st_out <= 0;
		r_segs_end    <= 0;
		r_segs_wea      <= 0;
		r_segs_addra    <= 0;
	end
	else begin
		r_segs_tdata    <= w_segs_tdata;
		r_tuser_1st_out <= w_tuser_1st_out;
		r_segs_end      <= w_segs_end;
		r_segs_wea      <= w_segs_wea;
		r_segs_addra    <= w_segs_addra;
	end
end

wire [C_OFFBYTE_RAM_WIDTH-1:0] w_offset_byte          ;
wire                           w_offset_byte_valid    ;
wire [8:0]                     w_offset_byte_addrb    ;

wire [255:0] w_dp_segs_tdata1    ;
wire         w_dp_segs_valid1    ;
wire         w_dp_segs_wea1	     ;
wire [2:0]   w_dp_segs_addra1    ;


//本级RAM里存放下一级提取地址
data_path_top1  #(
	.C_AXIS_DATA_WIDTH     (C_S_AXIS_DATA_WIDTH    ),
	.C_AXIS_TUSER_WIDTH    (C_S_AXIS_TUSER_WIDTH   ),
	.C_RAM_WIDTH           (C_OFFBYTE_RAM_WIDTH    ), //offset_byte_ram_width = 16
	.C_RAM_DEPTH_WIDTH     ( 5                     ), //RAM的深度2的对数
	.CFG_ORDER_NUM         ( 5                     ), //提取bit位数量
	.CFG_S_ORDER_WID       ( 16                    ), //每个bit位提取指令位宽
	.CFG_TCAM_DEPTH        ( 32                    ), //配置TCAM深度,must>2
	.CFG_TCAM_MA_ADDR_WIDTH( 5                     ), //配置tcam地址宽度，是TCAM深度的2对数
	.CFG_BIT_MOD_ID        ( 15                    ),
	.CFG_TCAM_MOD_ID       ( 14                    )

)
data_path_top1
(
	.axis_clk (axis_clk),
    .aresetn  (aresetn),
	
	.i_dp_segs_tdata		(r_segs_tdata		),
	.i_dp_segs_valid        (r_segs_end		    ),
	.i_dp_segs_wea			(r_segs_wea			),//写ram每个地址使能
	.i_dp_segs_addra		(r_segs_addra		),

	.i_offset_byte          (0                  ),
	.i_offset_byte_valid    (1                  ),
	.i_wait_vlan			(0      			),//不给偏移地址增加额外的需求
	.i_wait_vlan_valid		(               	),

	.ctrl_s_axis_tdata		(ctrl_s_axis_tdata  ),
	.ctrl_s_axis_tuser		(ctrl_s_axis_tuser  ),
	.ctrl_s_axis_tkeep		(ctrl_s_axis_tkeep  ),
	.ctrl_s_axis_tvalid		(ctrl_s_axis_tvalid ),
	.ctrl_s_axis_tlast		(ctrl_s_axis_tlast  ),

	.ctrl_m_axis_tdata		(ctrl_s_axis_tdata1  ),
	.ctrl_m_axis_tuser		(ctrl_s_axis_tuser1  ),
	.ctrl_m_axis_tkeep		(ctrl_s_axis_tkeep1  ),
	.ctrl_m_axis_tvalid		(ctrl_s_axis_tvalid1 ),
	.ctrl_m_axis_tlast		(ctrl_s_axis_tlast1  ),

	.o_bram			        (w_offset_byte      ),
	.o_bram_valid           (w_offset_byte_valid),
	.o_bram_addrb           (w_offset_byte_addrb),//扩展功能：将parser的地址直接传给deparser，在parser和deparser同配置的情况下

	.o_dp_segs_tdata	    (w_dp_segs_tdata1   ),
	.o_dp_segs_valid        (w_dp_segs_valid1   ),
	.o_dp_segs_wea	        (w_dp_segs_wea1	    ),
	.o_dp_segs_addra	    (w_dp_segs_addra1   )
);

data_path_top2  #(
	.C_AXIS_DATA_WIDTH     (C_S_AXIS_DATA_WIDTH    ),
	.C_AXIS_TUSER_WIDTH    (C_S_AXIS_TUSER_WIDTH   ),
	.C_PARSER_RAM_WIDTH    ( 384                   ), //16X24
	.CFG_ORDER_NUM         ( 6                     ), //提取bit位数量
	.CFG_S_ORDER_WID       ( 16                    ), //每个bit位提取指令位宽
	.CFG_TCAM_DEPTH        ( 32                    ), //配置TCAM深度,must>2
	.CFG_TCAM_MA_ADDR_WIDTH( 5                     ), //配置tcam地址宽度，是TCAM深度的2对数
	.CFG_BIT_MOD_ID        ( 12                    ),
	.CFG_TCAM_MOD_ID       ( 8                     )
)
data_path_top2
(
	.axis_clk (axis_clk),
    .aresetn  (aresetn),
	
	.i_dp_segs_tdata		(w_dp_segs_tdata1		),
	.i_dp_segs_valid        (w_dp_segs_valid1		),
	.i_dp_segs_wea			(w_dp_segs_wea1			),//写ram每个地址使能
	.i_dp_segs_addra		(w_dp_segs_addra1		),

	//二级提取的报文是在一级提取的偏移地址基础上提取
	.i_offset_byte          (w_offset_byte          ),
	.i_offset_byte_valid    (w_offset_byte_valid    ),//字节偏移输出先进，与提取的数据加好之后再数据字段

	.i_wait_vlan			(wait_vlan			),
	.i_wait_vlan_valid		(wait_vlan_valid	),

	.ctrl_s_axis_tdata		(ctrl_s_axis_tdata1  ),
	.ctrl_s_axis_tuser		(ctrl_s_axis_tuser1  ),
	.ctrl_s_axis_tkeep		(ctrl_s_axis_tkeep1  ),
	.ctrl_s_axis_tvalid		(ctrl_s_axis_tvalid1 ),
	.ctrl_s_axis_tlast		(ctrl_s_axis_tlast1  ),

	.ctrl_m_axis_tdata		(ctrl_m_axis_tdata  ),
	.ctrl_m_axis_tuser		(ctrl_m_axis_tuser  ),
	.ctrl_m_axis_tkeep		(ctrl_m_axis_tkeep  ),
	.ctrl_m_axis_tvalid		(ctrl_m_axis_tvalid ),
	.ctrl_m_axis_tlast		(ctrl_m_axis_tlast  ),

	.o_bram			        (bram_out           ),
	.o_bram_valid           (bram_out_valid     ),
	.o_bram_addrb           (bram_out_addrb     )
);


//we can divide 24 parser_act in two clk by which is parallel
generate
	genvar index;
	for(index=0;index < DO_PARER_GROUP;index = index+1)begin:
	sub_op
	always @(posedge axis_clk) begin
		if(!aresetn) begin
			parser_bram_in[index ] <= 0;
			parser_bram_in_valid[index]   <= 1'b0;
		end
		else if(bram_out_valid)begin
			parser_bram_in[index ] <= bram_out[PARSER_GROUP_WIDTH*(DO_PARER_GROUP-index)-1:PARSER_GROUP_WIDTH*(DO_PARER_GROUP-index-1)];
			parser_bram_in_valid[index]   <= 1'b1;
		end
		else begin
			parser_bram_in[index]       <= parser_bram_in[index];
			parser_bram_in_valid[index] <= 1'b0;
		end
	end

	sub0_parser #(
		.PARSER_WIDTH(PARSER_WIDTH),
		.DO_PARER_GROUP_NUM(DO_PARER_GROUP_NUM))
	sub0_parser(
		.axis_clk         (axis_clk),
		.aresetn          (aresetn),
	//in
		.i_parser_bram         (parser_bram_in[index]),//each sub0_parser only solve 2 index
		.i_parser_bram_valid   (parser_bram_in_valid[index] ),

		.i_seg_tdata           (r_segs_tdata         ),
		.i_seg_wea             (r_segs_wea           ),
		.i_seg_addra           (r_segs_addra         ),
		.i_wait_segs_end       (r_segs_end           ),
	//out
		.o_parser_act_low      (parser_act_low[index]),
		.o_parser_act_low_valid(parser_act_low_valid[index]),
		.o_segs_8B_1           (segs_8B_1[index]),//64 bits
		.o_segs_8B_2      	   (segs_8B_2[index])//64 bits

	);

//we need the same clk of the parse_act and pkts_hdr
	sub1_parser #(
	.SUB_PKTS_LEN   (SUB_PKTS_LEN ),
	.L_PARSE_ACT_LEN(L_PARSE_ACT_LEN),
	.VAL_OUT_LEN    (VAL_OUT_LEN)
	)
	sub1_parser (
		.clk				(axis_clk),
		.aresetn			(aresetn),
		//in
		.parse_act_valid	(parser_act_low_valid[index]),
		// .parse_act			(sub_parse_act[index]),
		.parse_act			(parser_act_low[index]),
		.pkts_hdr			({segs_8B_2[index],segs_8B_1[index]}),//128bits
		//out
		.val_out_valid		(val_out_valid[index]),
		.val_out			(val_out[index]),
		.val_out_type		(val_out_type[index]),
		.val_out_seq		(val_out_seq[index]),
		.o_sub_seg_valid    (sub_seg_out_valid[index])//we can get the val in 5 clk ,and each clk 4 parser
	);
	end
endgenerate

	wire [DO_PARER_GROUP-1:0]           w_val_out_valid;
	wire [64*DO_PARER_GROUP-1:0]    	w_val_out;
	wire [2*DO_PARER_GROUP-1:0]    		w_val_out_type;
	wire [3*DO_PARER_GROUP-1:0] 		w_val_out_seq;
	wire [1*DO_PARER_GROUP-1:0]			w_sub_seg_valid;
	
	assign w_val_out_valid = {
		val_out_valid[0],val_out_valid[1],val_out_valid[2],val_out_valid[3],
		val_out_valid[4],val_out_valid[5],val_out_valid[6],val_out_valid[7],
		val_out_valid[8],val_out_valid[9],val_out_valid[10],val_out_valid[11]};
		
	assign w_val_out = {val_out[0],val_out[1],val_out[2],val_out[3],
						val_out[4],val_out[5],val_out[6],val_out[7],
						val_out[8],val_out[9],val_out[10],val_out[11]
					};
						
	assign w_val_out_type = {val_out_type[0 ],val_out_type[1 ],val_out_type[2 ],val_out_type[3 ],
							 val_out_type[4 ],val_out_type[5 ],val_out_type[6 ],val_out_type[7 ],
							 val_out_type[8 ],val_out_type[9 ],val_out_type[10],val_out_type[11]
							};

	assign w_val_out_seq = {val_out_seq[0 ],val_out_seq[1 ],val_out_seq[2 ],val_out_seq[3 ],
							val_out_seq[4 ],val_out_seq[5 ],val_out_seq[6 ],val_out_seq[7 ],
							val_out_seq[8 ],val_out_seq[9 ],val_out_seq[10],val_out_seq[11]
						};

	assign w_sub_seg_valid = {sub_seg_out_valid[0 ],sub_seg_out_valid[1 ],sub_seg_out_valid[2 ],sub_seg_out_valid[3 ],
							  sub_seg_out_valid[4 ],sub_seg_out_valid[5 ],sub_seg_out_valid[6 ],sub_seg_out_valid[7 ],
							  sub_seg_out_valid[8 ],sub_seg_out_valid[9 ],sub_seg_out_valid[10],sub_seg_out_valid[11]
							};

//每次parser指令命中之后生成一个phv，所以每个phv携带自己的deparser查表指令放回是合理的

	parser_do_parsing #(
		.C_AXIS_DATA_WIDTH (C_S_AXIS_DATA_WIDTH),
		.C_AXIS_TUSER_WIDTH(C_S_AXIS_TUSER_WIDTH),
		.PHV_WIDTH         (PHV_WIDTH),
		.PKTS_LEN          (PKTS_LEN),
		.PARSER_MOD_ID     (PARSER_MOD_ID),
		.C_NUM_SEGS        (C_NUM_SEGS),
		.C_VLANID_WIDTH    (C_VLANID_WIDTH),
		.DO_PARER_GROUP    (DO_PARER_GROUP)
	)
	do_parsing
	(
		//in
		.axis_clk				(axis_clk       ),
		.aresetn				(aresetn        ),
		//in parser bram addrb_out
		.sub_parse_val_valid    (w_val_out_valid), //? it also can be get from bram_out 
		.sub_parse_val          (w_val_out      ),       //only this is new and important
		.sub_parse_val_type     (w_val_out_type ),
		.sub_parse_val_seq      (w_val_out_seq  ),
		//in 
		.i_bram_parser_addrb    (bram_out_addrb ),
		.i_bram_parser_valid    (bram_out_valid ),
		//in vlan from parser wait 
		.i_vlan                 (wait_vlan      ),
		.i_vlan_valid           (wait_vlan_valid),
		.tuser_1st				(r_tuser_1st_out),
		.i_sub_seg_valid        (w_sub_seg_valid),

		//in
		.i_stg_ready			(i_stg_ready    ),
		//out  
		.o_phv_valid			(o_phv_valid_w  ),
		.o_phv			        (phv_w          ),
		//out
		.out_vlan				(out_vlan       ),
		.out_vlan_valid			(out_vlan_valid ),
		//in 
		.out_vlan_ready			(out_vlan_ready )
	);
ila_3 ila_parser (
	.clk(axis_clk), // input wire clk


	.probe0(w_offset_byte      ), // input wire [255:0]  probe0  
	.probe1(w_offset_byte_valid), // input wire [0:0]  probe1 
	.probe2(w_offset_byte_addrb),
	.probe3(o_phv_data[383:0]  ),
	.probe4(o_phv_valid        ),
	.probe5(bram_out           ),
	.probe6(bram_out_valid     )
	
);
endmodule
