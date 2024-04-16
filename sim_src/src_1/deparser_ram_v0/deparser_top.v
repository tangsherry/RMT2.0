`timescale 1ns / 1ps

module deparser_top #(
	parameter	C_AXIS_DATA_WIDTH  = 256,
	parameter	C_AXIS_TUSER_WIDTH = 128,
	parameter	C_PKT_VEC_WIDTH    = (8+4+2)*8*8+100+256,
	parameter	DEPARSER_MOD_ID    = 3'b101,
	parameter	C_VLANID_WIDTH     = 12,
	parameter   C_PARSER_RAM_WIDTH = 384
)
(
	input									axis_clk,
	input									aresetn ,
	
	input [C_AXIS_DATA_WIDTH-1:0  ]			pkt_fifo_tdata,
	input [C_AXIS_DATA_WIDTH/8-1:0]			pkt_fifo_tkeep,
	input [C_AXIS_TUSER_WIDTH-1:0 ]			pkt_fifo_tuser,
	input									pkt_fifo_tlast,
	input									pkt_fifo_empty,
	output									pkt_fifo_rd_en,

	input [C_PKT_VEC_WIDTH-1:0]				phv_fifo_out    ,
	input									phv_fifo_empty  ,
	output									phv_fifo_rd_en  ,

	output [C_AXIS_DATA_WIDTH-1:0]			depar_out_tdata ,
	output [C_AXIS_DATA_WIDTH/8-1:0]		depar_out_tkeep ,
	output [C_AXIS_TUSER_WIDTH-1:0]			depar_out_tuser ,
	output									depar_out_tvalid,
	output 									depar_out_tlast ,
	input									depar_out_tready,

	// control path
	input [C_AXIS_DATA_WIDTH-1:0]			ctrl_s_axis_tdata ,
	input [C_AXIS_TUSER_WIDTH-1:0]			ctrl_s_axis_tuser ,
	input [C_AXIS_DATA_WIDTH/8-1:0]			ctrl_s_axis_tkeep ,
	input									ctrl_s_axis_tvalid,
	input									ctrl_s_axis_tlast
);

// wire [C_AXIS_DATA_WIDTH*4-1:0  ]		fst_half_fifo_tdata_in, fst_half_fifo_tdata_out;
wire [C_AXIS_DATA_WIDTH-1:0  ]			fst_half_fifo_tdata1_in, fst_half_fifo_tdata1_out;
wire [C_AXIS_DATA_WIDTH-1:0  ]			fst_half_fifo_tdata2_in, fst_half_fifo_tdata2_out;
wire [C_AXIS_DATA_WIDTH-1:0  ]			fst_half_fifo_tdata3_in, fst_half_fifo_tdata3_out;
wire [C_AXIS_DATA_WIDTH-1:0  ]			fst_half_fifo_tdata4_in, fst_half_fifo_tdata4_out;
wire [C_AXIS_TUSER_WIDTH*4-1:0 ]		fst_half_fifo_tuser_in, fst_half_fifo_tuser_out;
wire [C_AXIS_DATA_WIDTH/8*4-1:0]	    fst_half_fifo_tkeep_in, fst_half_fifo_tkeep_out;
wire [3:0                      ]		fst_half_fifo_tlast_in, fst_half_fifo_tlast_out;
wire fst_half_fifo_empty    ;
wire fst_half_fifo_full     ;
wire fst_half_fifo_valid_in ;
wire fst_half_fifo_rd_en    ;

// wire [C_AXIS_DATA_WIDTH*4-1:0  ]		snd_half_fifo_tdata_in, snd_half_fifo_tdata_out;
wire [C_AXIS_DATA_WIDTH-1:0  ]			snd_half_fifo_tdata1_in, snd_half_fifo_tdata1_out;
wire [C_AXIS_DATA_WIDTH-1:0  ]			snd_half_fifo_tdata2_in, snd_half_fifo_tdata2_out;
wire [C_AXIS_DATA_WIDTH-1:0  ]			snd_half_fifo_tdata3_in, snd_half_fifo_tdata3_out;
wire [C_AXIS_DATA_WIDTH-1:0  ]			snd_half_fifo_tdata4_in, snd_half_fifo_tdata4_out;
wire [C_AXIS_TUSER_WIDTH*4-1:0 ]		snd_half_fifo_tuser_in, snd_half_fifo_tuser_out;
wire [C_AXIS_DATA_WIDTH/8*4-1:0]	    snd_half_fifo_tkeep_in, snd_half_fifo_tkeep_out;
wire [3:0                      ]		snd_half_fifo_tlast_in, snd_half_fifo_tlast_out;
wire snd_half_fifo_empty;
wire snd_half_fifo_full;
wire snd_half_fifo_valid_in;
wire snd_half_fifo_rd_en;
wire [C_VLANID_WIDTH-1:0] vlan_fifo_in, vlan_fifo_out;
wire vlan_valid_in;
wire vlan_fifo_rd_en;
wire vlan_fifo_full;
wire vlan_fifo_empty;

wire [C_AXIS_DATA_WIDTH-1:0]	seg_fifo_tdata_in, seg_fifo_tdata_out;
wire [C_AXIS_TUSER_WIDTH-1:0]	seg_fifo_tuser_in, seg_fifo_tuser_out;
wire [C_AXIS_DATA_WIDTH/8-1:0]	seg_fifo_tkeep_in, seg_fifo_tkeep_out;
wire							seg_fifo_tlast_in, seg_fifo_tlast_out;
wire seg_fifo_valid_in;
wire seg_fifo_rd_en;
wire seg_fifo_full;
wire seg_fifo_empty;

//该模块是整个deparser的第一个模块，从等待报文到数据输出到fifo再到depar读取报文是直接进直接出的
depar_wait_segs #(
)
wait_segs
(
	.clk										(axis_clk),
	.aresetn									(aresetn),

	.pkt_fifo_tdata								(pkt_fifo_tdata),
	.pkt_fifo_tuser								(pkt_fifo_tuser),
	.pkt_fifo_tkeep								(pkt_fifo_tkeep),
	.pkt_fifo_tlast								(pkt_fifo_tlast),
	.pkt_fifo_empty								(pkt_fifo_empty),

	.fst_half_fifo_ready						(~fst_half_fifo_full),
	.snd_half_fifo_ready						(~snd_half_fifo_full),

	.pkt_fifo_rd_en							    (pkt_fifo_rd_en),//可以读入所有数据到wait模块进入待处理

	.o_vlan										(vlan_fifo_in),
	.o_vlan_valid								(vlan_valid_in),
	//half of 2048b
	.fst_half_tdata1							(fst_half_fifo_tdata1_in),
	.fst_half_tdata2							(fst_half_fifo_tdata2_in),
	.fst_half_tdata3							(fst_half_fifo_tdata3_in),
	.fst_half_tdata4							(fst_half_fifo_tdata4_in),
	.fst_half_tuser								(fst_half_fifo_tuser_in),
	.fst_half_tkeep								(fst_half_fifo_tkeep_in),
	.fst_half_tlast								(fst_half_fifo_tlast_in),
	.fst_half_valid								(fst_half_fifo_valid_in),
	//half of 2048b
	.snd_half_tdata1							(snd_half_fifo_tdata1_in),
	.snd_half_tdata2							(snd_half_fifo_tdata2_in),
	.snd_half_tdata3							(snd_half_fifo_tdata3_in),
	.snd_half_tdata4							(snd_half_fifo_tdata4_in),
	.snd_half_tuser								(snd_half_fifo_tuser_in),
	.snd_half_tkeep								(snd_half_fifo_tkeep_in),
	.snd_half_tlast								(snd_half_fifo_tlast_in),
	.snd_half_valid								(snd_half_fifo_valid_in),
	//the other data except 2048b pkt
	.output_fifo_tdata							(seg_fifo_tdata_in),
	.output_fifo_tuser							(seg_fifo_tuser_in),
	.output_fifo_tkeep							(seg_fifo_tkeep_in),
	.output_fifo_tlast							(seg_fifo_tlast_in),
	.output_fifo_valid							(seg_fifo_valid_in),
	.output_fifo_ready							(~seg_fifo_full)//如果报文满了，就不接收报文了，如果没有满，可以接收
);

//缓存从wait中得到的2048b的一半数据
fallthrough_small_fifo #(
	.WIDTH(4*(C_AXIS_DATA_WIDTH)),
	.MAX_DEPTH_BITS(4)
)
fst_half_fifo (
	.din				({fst_half_fifo_tdata1_in, fst_half_fifo_tdata2_in,fst_half_fifo_tdata3_in,fst_half_fifo_tdata4_in}),
	.wr_en				(fst_half_fifo_valid_in),//after three clk data can be put to the line 
	//
	.rd_en				(fst_half_fifo_rd_en),
	.dout				({fst_half_fifo_tdata1_out,fst_half_fifo_tdata2_out,fst_half_fifo_tdata3_out,fst_half_fifo_tdata4_out}),
	//
	.full				(),
	.prog_full			(),
	.nearly_full		(fst_half_fifo_full),
	.empty				(fst_half_fifo_empty),
	.reset				(~aresetn),
	.clk				(axis_clk)
);
//缓存从wait中得到的2048b的一半数据
fallthrough_small_fifo #(
	.WIDTH(4*(C_AXIS_DATA_WIDTH)),
	.MAX_DEPTH_BITS(4)
)
snd_half_fifo (
	.din				({snd_half_fifo_tdata1_in,snd_half_fifo_tdata2_in,snd_half_fifo_tdata3_in,snd_half_fifo_tdata4_in}),
	.wr_en				(snd_half_fifo_valid_in),
	//
	.rd_en				(snd_half_fifo_rd_en),
	.dout				({snd_half_fifo_tdata1_out,snd_half_fifo_tdata2_out,snd_half_fifo_tdata3_out,snd_half_fifo_tdata4_out}),
	//
	.full				(),
	.prog_full			(),
	.nearly_full		(snd_half_fifo_full),
	.empty				(snd_half_fifo_empty),
	.reset				(~aresetn),
	.clk				(axis_clk)
);

wire tuser_fifo_rd_en;
fallthrough_small_fifo #(
	.WIDTH(4*(C_AXIS_TUSER_WIDTH+C_AXIS_DATA_WIDTH/8+1)),
	.MAX_DEPTH_BITS(4)
)
fst_half_tuser_fifo (
	.din				({fst_half_fifo_tuser_in, fst_half_fifo_tkeep_in, fst_half_fifo_tlast_in}),
	.wr_en				(fst_half_fifo_valid_in),//after three clk data can be put to the line 
	//
	.rd_en				(tuser_fifo_rd_en),
	.dout				({fst_half_fifo_tuser_out, fst_half_fifo_tkeep_out, fst_half_fifo_tlast_out}),
	//
	.full				(),
	.prog_full			(),
	.nearly_full		(),
	.empty				(),
	.reset				(~aresetn),
	.clk				(axis_clk)
);
//缓存从wait中得到的2048b的一半数据
fallthrough_small_fifo #(
	.WIDTH(4*(C_AXIS_TUSER_WIDTH+C_AXIS_DATA_WIDTH/8+1)),
	.MAX_DEPTH_BITS(4)
)
snd_half_tuser_fifo (
	.din				({snd_half_fifo_tuser_in, snd_half_fifo_tkeep_in, snd_half_fifo_tlast_in}),
	.wr_en				(snd_half_fifo_valid_in),
	//
	.rd_en				(tuser_fifo_rd_en),
	.dout				({snd_half_fifo_tuser_out, snd_half_fifo_tkeep_out, snd_half_fifo_tlast_out}),
	//
	.full				(),
	.prog_full			(),
	.nearly_full		(),
	.empty				(),
	.reset				(~aresetn),
	.clk				(axis_clk)
);

//==============================================

//缓存从wait中得到的vlan数据
// vlan fifo
fallthrough_small_fifo #(
	.WIDTH(C_VLANID_WIDTH),
	.MAX_DEPTH_BITS(5)
)
vlan_fifo (
	.din					(vlan_fifo_in),
	.wr_en					(vlan_valid_in),
	//
	.rd_en					(vlan_fifo_rd_en),
	.dout					(vlan_fifo_out),
	//
	.full					(),
	.prog_full				(),
	.nearly_full			(vlan_fifo_full),
	.empty					(vlan_fifo_empty),
	.reset					(~aresetn),
	.clk					(axis_clk)
);

//缓存从wait中得到的vlan数据
// seg fifo 区别于2048b的其他字段
fallthrough_small_fifo #(
	.WIDTH(C_AXIS_DATA_WIDTH+C_AXIS_TUSER_WIDTH+C_AXIS_DATA_WIDTH/8+1),
	.MAX_DEPTH_BITS(5)
)
seg_fifo (
	.din					({seg_fifo_tdata_in, seg_fifo_tuser_in, seg_fifo_tkeep_in, seg_fifo_tlast_in}),
	.wr_en					(seg_fifo_valid_in),
	//
	.rd_en					(seg_fifo_rd_en),
	.dout					({seg_fifo_tdata_out, seg_fifo_tuser_out, seg_fifo_tkeep_out, seg_fifo_tlast_out}),
	//
	.full					(),
	.prog_full				(),
	.nearly_full			(seg_fifo_full),
	.empty					(seg_fifo_empty),
	.reset					(~aresetn),
	.clk					(axis_clk)
);



//该模块是整个阶段的最终模块，将所有准备数据读如之后，输出逆解析报文
depar_do_deparsing #(
	.C_PKT_VEC_WIDTH   (C_PKT_VEC_WIDTH   ),
	.DEPARSER_MOD_ID   (DEPARSER_MOD_ID   ),
	.C_AXIS_DATA_WIDTH (C_AXIS_DATA_WIDTH ),
	.C_AXIS_TUSER_WIDTH(C_AXIS_TUSER_WIDTH),
	.C_NUM_SEGS        (8                 ),
	.C_VLANID_WIDTH    (C_VLANID_WIDTH    ),
	.C_PARSER_RAM_WIDTH(C_PARSER_RAM_WIDTH)
)
do_deparsing
(
	.clk										(axis_clk),
	.aresetn									(aresetn),
	// phv
	.phv_fifo_out								(phv_fifo_out),
	.phv_fifo_empty								(phv_fifo_empty),
	.phv_fifo_rd_en								(phv_fifo_rd_en),
	// vlan
	.vlan_id									(vlan_fifo_out),
	.vlan_fifo_empty							(vlan_fifo_empty),
	.vlan_fifo_rd_en							(vlan_fifo_rd_en),
	// first half
	.fst_half_fifo_tdata1						(fst_half_fifo_tdata1_out),
	.fst_half_fifo_tdata2						(fst_half_fifo_tdata2_out),
	.fst_half_fifo_tdata3						(fst_half_fifo_tdata3_out),
	.fst_half_fifo_tdata4						(fst_half_fifo_tdata4_out),
	.fst_half_fifo_tuser						(fst_half_fifo_tuser_out ),
	.fst_half_fifo_tkeep						(fst_half_fifo_tkeep_out ),
	.fst_half_fifo_tlast						(fst_half_fifo_tlast_out ),
	.fst_half_fifo_empty						(fst_half_fifo_empty     ),
	.fst_half_fifo_rd_en						(fst_half_fifo_rd_en     ),
	// second half
	.snd_half_fifo_valid_in                     (snd_half_fifo_valid_in  ),//数据的读出还要看新的四个数据是否已经写进
	.snd_half_fifo_tdata1						(snd_half_fifo_tdata1_out),
	.snd_half_fifo_tdata2						(snd_half_fifo_tdata2_out),
	.snd_half_fifo_tdata3						(snd_half_fifo_tdata3_out),
	.snd_half_fifo_tdata4						(snd_half_fifo_tdata4_out),
	.snd_half_fifo_tuser						(snd_half_fifo_tuser_out ),
	.snd_half_fifo_tkeep						(snd_half_fifo_tkeep_out ),
	.snd_half_fifo_tlast						(snd_half_fifo_tlast_out ),
	.snd_half_fifo_empty						(snd_half_fifo_empty),
	.snd_half_fifo_rd_en						(snd_half_fifo_rd_en),
	.o_tuser_fifo_rd_en                         (tuser_fifo_rd_en),
	// segs
	.pkt_fifo_tdata								(seg_fifo_tdata_out),
	.pkt_fifo_tuser								(seg_fifo_tuser_out),
	.pkt_fifo_tkeep								(seg_fifo_tkeep_out),
	.pkt_fifo_tlast								(seg_fifo_tlast_out),
	.pkt_fifo_empty								(seg_fifo_empty),
	.pkt_fifo_rd_en								(seg_fifo_rd_en),
	// output
	.depar_out_tdata							(depar_out_tdata),
	.depar_out_tuser							(depar_out_tuser),
	.depar_out_tkeep							(depar_out_tkeep),
	.depar_out_tlast							(depar_out_tlast),
	.depar_out_tvalid							(depar_out_tvalid),
	.depar_out_tready							(depar_out_tready),
	// control path
	.ctrl_s_axis_tdata							(ctrl_s_axis_tdata),
	.ctrl_s_axis_tuser							(ctrl_s_axis_tuser),
	.ctrl_s_axis_tkeep							(ctrl_s_axis_tkeep),
	.ctrl_s_axis_tvalid							(ctrl_s_axis_tvalid),
	.ctrl_s_axis_tlast							(ctrl_s_axis_tlast)
);

endmodule
