`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/10/19 16:39:16
// Design Name: 
// Module Name: tb_deparser_top
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

//当前测试文件仅仿真了2048b的数据报文情况，还没有构造少于2048b和大于2048b的报文，
//这里需要进一步仿真验证
module tb_deparser_top #(
    //     // Slave AXI parameters
	// parameter C_AXIS_DATA_WIDTH = 32,
	parameter C_AXIS_ADDR_WIDTH = 12,
	parameter C_BASEADDR = 32'h80000000,
	// AXI Stream parameters
	// Slave
	parameter C_S_AXIS_DATA_WIDTH = 256,
	parameter C_S_AXIS_TUSER_WIDTH = 128,
	// Master
	parameter C_M_AXIS_DATA_WIDTH = 256,
	// self-defined
	parameter PHV_ADDR_WIDTH = 4,
    parameter vlan_id = 4'b0001,
    parameter PARSER_MOD_ID = 4'b0001,
    parameter BIT_CFG_MOD_ID = 4'b1111,
    parameter BIT_TCAM_MOD_ID = 4'b1110,
    parameter KEY_EX_ID = 4'h0002,
    parameter STAGE_ID0 = 4'b0000,
    parameter STAGE_ID4 = 4'b0100,
    parameter STAGE_ID1 = 4'b0001,
    parameter STAGE_ID2 = 4'b0010,
    parameter STAGE_ID3 = 4'b0011,
    parameter C_PKT_VEC_WIDTH = 8*(8+4+2)*8+100+256
    )();

localparam CYCLE = 10;

reg                                     clk          ;
reg                                     aresetn      ;
    
reg [C_S_AXIS_DATA_WIDTH-1:0]		    s_axis_tdata ;
reg [((C_S_AXIS_DATA_WIDTH/8))-1:0]	    s_axis_tkeep ;
reg [C_S_AXIS_TUSER_WIDTH-1:0]		    s_axis_tuser ;
reg									    s_axis_tvalid;
wire								    s_axis_tready;
reg									    s_axis_tlast ;

wire [C_S_AXIS_DATA_WIDTH-1:0]		    m_axis_tdata ;
wire [((C_S_AXIS_DATA_WIDTH/8))-1:0]    m_axis_tkeep ;
wire [C_S_AXIS_TUSER_WIDTH-1:0]		    m_axis_tuser ;
wire								    m_axis_tvalid;
reg										m_axis_tready;
wire									m_axis_tlast ;

//used in packet
wire [255:0] ctrl_s_axis_tdata_swapped;
assign ctrl_s_axis_tdata_swapped = {	s_axis_tdata[0  +:8],      	//[255:248]
								s_axis_tdata[8  +:8],		//[247:240]
								s_axis_tdata[16 +:8],		//[239:232]
								s_axis_tdata[24 +:8],		//[231:224]
								s_axis_tdata[32 +:8],		//[223:216]
								s_axis_tdata[40 +:8],		//[215:208]
								s_axis_tdata[48 +:8],		//[207:200]
								s_axis_tdata[56 +:8],		//[199:192]
								s_axis_tdata[64 +:8],		//[191:184]
								s_axis_tdata[72 +:8],		//[183:176]
								s_axis_tdata[80 +:8],		//[175:168]
								s_axis_tdata[88 +:8],		//[167:160]
								s_axis_tdata[96 +:8],		//[159:152]
								s_axis_tdata[104+:8],		//[151:144]
								s_axis_tdata[112+:8],		//[143:136]
								s_axis_tdata[120+:8],		//[135:128]
								s_axis_tdata[128+:8],		//[127:120]
								s_axis_tdata[136+:8],		//[119:112]
								s_axis_tdata[144+:8],		//[111:104]
								s_axis_tdata[152+:8],		//[103:96 ]
								s_axis_tdata[160+:8],		//[95 :88 ]
								s_axis_tdata[168+:8],		//[87 :80 ]
								s_axis_tdata[176+:8],		//[79 :72 ]
								s_axis_tdata[184+:8],		//[71 :64 ]
								s_axis_tdata[192+:8],		//[63 :56 ]
								s_axis_tdata[200+:8],		//[55 :48 ]
								s_axis_tdata[208+:8],		//[47 :40 ]
								s_axis_tdata[216+:8],		//[39 :32 ]
								s_axis_tdata[224+:8],		//[31 :24 ]
								s_axis_tdata[232+:8],		//[23 :16 ]
								s_axis_tdata[240+:8],		//[15 :08 ]
								s_axis_tdata[248+:8]        //[07 :00 ]
                            };		

//assign s_axis_tready = 1'b1;
// //parser act here
wire  [23:0]     valid     ;
assign valid = 24'hffffff;


wire [4:0] off_64b_seg  [23:0];//value 0-31
assign off_64b_seg[0 ] = 5'd28,off_64b_seg[1 ] = 5'd29,off_64b_seg[2  ] = 5'd30,off_64b_seg[3  ] = 5'd31  ;
assign off_64b_seg[4 ] = 5'd24,off_64b_seg[5 ] = 5'd25,off_64b_seg[6  ] = 5'd26,off_64b_seg[7  ] = 5'd27  ;
assign off_64b_seg[8 ] = 5'd20,off_64b_seg[9 ] = 5'd21,off_64b_seg[10 ] = 5'd22,off_64b_seg[11 ] = 5'd23  ;
assign off_64b_seg[12] = 5'd16,off_64b_seg[13] = 5'd17,off_64b_seg[14 ] = 5'd18,off_64b_seg[15 ] = 5'd19  ;
assign off_64b_seg[16] = 5'd12,off_64b_seg[17] = 5'd13,off_64b_seg[18 ] = 5'd14,off_64b_seg[19 ] = 5'd15  ;
assign off_64b_seg[20] = 5'd8 ,off_64b_seg[21] = 5'd9 ,off_64b_seg[22 ] = 5'd10,off_64b_seg[23 ] = 5'd11  ;

wire [2:0] val_index [23:0];
assign val_index[0 ] = 3'd0,val_index[1 ] = 3'd1,val_index[2 ] = 3'd2,val_index[3 ] = 3'd3;
assign val_index[4 ] = 3'd4,val_index[5 ] = 3'd5,val_index[6 ] = 3'd6,val_index[7 ] = 3'd7;
assign val_index[8 ] = 3'd0,val_index[9 ] = 3'd1,val_index[10] = 3'd2,val_index[11] = 3'd3;
assign val_index[12] = 3'd4,val_index[13] = 3'd5,val_index[14] = 3'd6,val_index[15] = 3'd7;
assign val_index[16] = 3'd0,val_index[17] = 3'd1,val_index[18] = 3'd2,val_index[19] = 3'd3;
assign val_index[20] = 3'd4,val_index[21] = 3'd5,val_index[22] = 3'd6,val_index[23] = 3'd7;

wire [1:0] val_type  [23:0];
assign val_type[0 ] = 2'b01,val_type[1 ] = 2'b01,val_type[2 ] = 2'b01,val_type[3 ] = 2'b01;//2B
assign val_type[4 ] = 2'b01,val_type[5 ] = 2'b01,val_type[6 ] = 2'b01,val_type[7 ] = 2'b01;
assign val_type[8 ] = 2'b10,val_type[9 ] = 2'b10,val_type[10] = 2'b10,val_type[11] = 2'b10;//4B
assign val_type[12] = 2'b10,val_type[13] = 2'b10,val_type[14] = 2'b10,val_type[15] = 2'b10;
assign val_type[16] = 2'b11,val_type[17] = 2'b11,val_type[18] = 2'b11,val_type[19] = 2'b11;//8B
assign val_type[20] = 2'b11,val_type[21] = 2'b11,val_type[22] = 2'b11,val_type[23] = 2'b11;

//组成的7个指令只动偏移字节
wire [2:0] off_byte   [23:0];//0-7
assign off_byte[0 ] = 3'd1,off_byte[1 ] = 3'd1,off_byte[2 ] = 3'd1,off_byte[3 ] = 3'd1;
assign off_byte[4 ] = 3'd0,off_byte[5 ] = 3'd0,off_byte[6 ] = 3'd0,off_byte[7 ] = 3'd0;
assign off_byte[8 ] = 3'd1,off_byte[9 ] = 3'd1,off_byte[10] = 3'd1,off_byte[11] = 3'd1;
assign off_byte[12] = 3'd0,off_byte[13] = 3'd0,off_byte[14] = 3'd0,off_byte[15] = 3'd0;
assign off_byte[16] = 3'd0,off_byte[17] = 3'd0,off_byte[18] = 3'd0,off_byte[19] = 3'd0;
assign off_byte[20] = 3'd0,off_byte[21] = 3'd0,off_byte[22] = 3'd0,off_byte[23] = 3'd0;

wire [2:0] off_byte1   [23:0];//0-7
assign off_byte1[0 ] = 3'd0,off_byte1[1 ] = 3'd0,off_byte1[2 ] = 3'd0,off_byte1[3 ] = 3'd0;
assign off_byte1[4 ] = 3'd0,off_byte1[5 ] = 3'd0,off_byte1[6 ] = 3'd0,off_byte1[7 ] = 3'd0;
assign off_byte1[8 ] = 3'd0,off_byte1[9 ] = 3'd0,off_byte1[10] = 3'd0,off_byte1[11] = 3'd0;
assign off_byte1[12] = 3'd0,off_byte1[13] = 3'd0,off_byte1[14] = 3'd0,off_byte1[15] = 3'd0;
assign off_byte1[16] = 3'd0,off_byte1[17] = 3'd0,off_byte1[18] = 3'd0,off_byte1[19] = 3'd0;
assign off_byte1[20] = 3'd0,off_byte1[21] = 3'd0,off_byte1[22] = 3'd0,off_byte1[23] = 3'd0;

wire [2:0] off_byte2   [23:0];//0-7
assign off_byte2[0 ] = 3'd1,off_byte2[1 ] = 3'd1,off_byte2[2 ] = 3'd1,off_byte2[3 ] = 3'd1;
assign off_byte2[4 ] = 3'd1,off_byte2[5 ] = 3'd1,off_byte2[6 ] = 3'd1,off_byte2[7 ] = 3'd1;
assign off_byte2[8 ] = 3'd1,off_byte2[9 ] = 3'd1,off_byte2[10] = 3'd1,off_byte2[11] = 3'd1;
assign off_byte2[12] = 3'd0,off_byte2[13] = 3'd0,off_byte2[14] = 3'd0,off_byte2[15] = 3'd0;
assign off_byte2[16] = 3'd0,off_byte2[17] = 3'd0,off_byte2[18] = 3'd0,off_byte2[19] = 3'd0;
assign off_byte2[20] = 3'd0,off_byte2[21] = 3'd0,off_byte2[22] = 3'd0,off_byte2[23] = 3'd0;

wire [2:0] off_byte3   [23:0];//0-7
assign off_byte3[0 ] = 3'd0,off_byte3[1 ] = 3'd0,off_byte3[2 ] = 3'd0,off_byte3[3 ] = 3'd0;
assign off_byte3[4 ] = 3'd0,off_byte3[5 ] = 3'd0,off_byte3[6 ] = 3'd0,off_byte3[7 ] = 3'd0;
assign off_byte3[8 ] = 3'd0,off_byte3[9 ] = 3'd0,off_byte3[10] = 3'd0,off_byte3[11] = 3'd0;
assign off_byte3[12] = 3'd0,off_byte3[13] = 3'd0,off_byte3[14] = 3'd0,off_byte3[15] = 3'd0;
assign off_byte3[16] = 3'd0,off_byte3[17] = 3'd0,off_byte3[18] = 3'd0,off_byte3[19] = 3'd0;
assign off_byte3[20] = 3'd0,off_byte3[21] = 3'd0,off_byte3[22] = 3'd0,off_byte3[23] = 3'd0;

wire [2:0] off_byte4   [23:0];//0-7
assign off_byte4[0 ] = 3'd1,off_byte4[1 ] = 3'd1,off_byte4[2 ] = 3'd1,off_byte4[3 ] = 3'd1;
assign off_byte4[4 ] = 3'd0,off_byte4[5 ] = 3'd0,off_byte4[6 ] = 3'd0,off_byte4[7 ] = 3'd0;
assign off_byte4[8 ] = 3'd1,off_byte4[9 ] = 3'd1,off_byte4[10] = 3'd1,off_byte4[11] = 3'd1;
assign off_byte4[12] = 3'd0,off_byte4[13] = 3'd0,off_byte4[14] = 3'd0,off_byte4[15] = 3'd0;
assign off_byte4[16] = 3'd0,off_byte4[17] = 3'd0,off_byte4[18] = 3'd0,off_byte4[19] = 3'd0;
assign off_byte4[20] = 3'd0,off_byte4[21] = 3'd0,off_byte4[22] = 3'd0,off_byte4[23] = 3'd0;

wire [2:0] off_byte5   [23:0];//0-7
assign off_byte5[0 ] = 3'd0,off_byte5[1 ] = 3'd0,off_byte5[2 ] = 3'd0,off_byte5[3 ] = 3'd0;
assign off_byte5[4 ] = 3'd0,off_byte5[5 ] = 3'd0,off_byte5[6 ] = 3'd0,off_byte5[7 ] = 3'd0;
assign off_byte5[8 ] = 3'd0,off_byte5[9 ] = 3'd0,off_byte5[10] = 3'd0,off_byte5[11] = 3'd0;
assign off_byte5[12] = 3'd0,off_byte5[13] = 3'd0,off_byte5[14] = 3'd0,off_byte5[15] = 3'd0;
assign off_byte5[16] = 3'd0,off_byte5[17] = 3'd0,off_byte5[18] = 3'd0,off_byte5[19] = 3'd0;
assign off_byte5[20] = 3'd0,off_byte5[21] = 3'd0,off_byte5[22] = 3'd0,off_byte5[23] = 3'd0;

wire [2:0] off_byte6   [23:0];//0-7
assign off_byte6[0 ] = 3'd1,off_byte6[1 ] = 3'd1,off_byte6[2 ] = 3'd1,off_byte6[3 ] = 3'd1;
assign off_byte6[4 ] = 3'd0,off_byte6[5 ] = 3'd0,off_byte6[6 ] = 3'd0,off_byte6[7 ] = 3'd0;
assign off_byte6[8 ] = 3'd1,off_byte6[9 ] = 3'd1,off_byte6[10] = 3'd1,off_byte6[11] = 3'd1;
assign off_byte6[12] = 3'd0,off_byte6[13] = 3'd0,off_byte6[14] = 3'd0,off_byte6[15] = 3'd0;
assign off_byte6[16] = 3'd0,off_byte6[17] = 3'd0,off_byte6[18] = 3'd0,off_byte6[19] = 3'd0;
assign off_byte6[20] = 3'd0,off_byte6[21] = 3'd0,off_byte6[22] = 3'd0,off_byte6[23] = 3'd0;

wire [2:0] off_byte7   [23:0];//0-7
assign off_byte7[0 ] = 3'd0,off_byte7[1 ] = 3'd0,off_byte7[2 ] = 3'd0,off_byte7[3 ] = 3'd0;
assign off_byte7[4 ] = 3'd0,off_byte7[5 ] = 3'd0,off_byte7[6 ] = 3'd0,off_byte7[7 ] = 3'd0;
assign off_byte7[8 ] = 3'd0,off_byte7[9 ] = 3'd0,off_byte7[10] = 3'd0,off_byte7[11] = 3'd0;
assign off_byte7[12] = 3'd0,off_byte7[13] = 3'd0,off_byte7[14] = 3'd0,off_byte7[15] = 3'd0;
assign off_byte7[16] = 3'd0,off_byte7[17] = 3'd0,off_byte7[18] = 3'd0,off_byte7[19] = 3'd0;
assign off_byte7[20] = 3'd0,off_byte7[21] = 3'd0,off_byte7[22] = 3'd0,off_byte7[23] = 3'd0;

wire [2:0] off_byte8   [23:0];//0-7
assign off_byte8[0 ] = 3'd1,off_byte8[1 ] = 3'd1,off_byte8[2 ] = 3'd1,off_byte8[3 ] = 3'd1;
assign off_byte8[4 ] = 3'd0,off_byte8[5 ] = 3'd0,off_byte8[6 ] = 3'd0,off_byte8[7 ] = 3'd0;
assign off_byte8[8 ] = 3'd1,off_byte8[9 ] = 3'd1,off_byte8[10] = 3'd1,off_byte8[11] = 3'd1;
assign off_byte8[12] = 3'd0,off_byte8[13] = 3'd0,off_byte8[14] = 3'd0,off_byte8[15] = 3'd0;
assign off_byte8[16] = 3'd0,off_byte8[17] = 3'd0,off_byte8[18] = 3'd0,off_byte8[19] = 3'd0;
assign off_byte8[20] = 3'd0,off_byte8[21] = 3'd0,off_byte8[22] = 3'd0,off_byte8[23] = 3'd0;

wire [2:0] off_byte9   [23:0];//0-7
assign off_byte9[0 ] = 3'd0,off_byte9[1 ] = 3'd0,off_byte9[2 ] = 3'd0,off_byte9[3 ] = 3'd0;
assign off_byte9[4 ] = 3'd0,off_byte9[5 ] = 3'd0,off_byte9[6 ] = 3'd0,off_byte9[7 ] = 3'd0;
assign off_byte9[8 ] = 3'd0,off_byte9[9 ] = 3'd0,off_byte9[10] = 3'd0,off_byte9[11] = 3'd0;
assign off_byte9[12] = 3'd0,off_byte9[13] = 3'd0,off_byte9[14] = 3'd0,off_byte9[15] = 3'd0;
assign off_byte9[16] = 3'd0,off_byte9[17] = 3'd0,off_byte9[18] = 3'd0,off_byte9[19] = 3'd0;
assign off_byte9[20] = 3'd0,off_byte9[21] = 3'd0,off_byte9[22] = 3'd0,off_byte9[23] = 3'd0;


wire [15:0] parser_ram_addr [7:0];
assign parser_ram_addr[0] ={7'd0,9'h020};
assign parser_ram_addr[1] ={7'd0,9'h021};
assign parser_ram_addr[2] ={7'd0,9'h022};
assign parser_ram_addr[3] ={7'd0,9'h023};
assign parser_ram_addr[4] ={7'd0,9'h024};
assign parser_ram_addr[5] ={7'd0,9'h025};
assign parser_ram_addr[6] ={7'd0,9'h026};
assign parser_ram_addr[7] ={7'd0,9'h027};


wire [15:0]parser_ram_addr_swap[7:0];
assign parser_ram_addr_swap[0] = {parser_ram_addr[0][7:0],parser_ram_addr[0][15:8]};
assign parser_ram_addr_swap[1] = {parser_ram_addr[1][7:0],parser_ram_addr[1][15:8]};
assign parser_ram_addr_swap[2] = {parser_ram_addr[2][7:0],parser_ram_addr[2][15:8]};
assign parser_ram_addr_swap[3] = {parser_ram_addr[3][7:0],parser_ram_addr[3][15:8]};
assign parser_ram_addr_swap[4] = {parser_ram_addr[4][7:0],parser_ram_addr[4][15:8]};
assign parser_ram_addr_swap[5] = {parser_ram_addr[5][7:0],parser_ram_addr[5][15:8]};
assign parser_ram_addr_swap[6] = {parser_ram_addr[6][7:0],parser_ram_addr[6][15:8]};
assign parser_ram_addr_swap[7] = {parser_ram_addr[7][7:0],parser_ram_addr[7][15:8]};

//=======================================parser table===========================================
wire [255:0] parser_table1 [511:0];
wire [255:0] parser_table2 [511:0];
wire [15:0] parser_act0 [23:0];
assign parser_act0[ 0] = {valid[ 0],2'b00,off_64b_seg[ 0],off_byte[ 0],val_index[ 0],val_type[ 0]};
assign parser_act0[ 1] = {valid[ 1],2'b00,off_64b_seg[ 1],off_byte[ 1],val_index[ 1],val_type[ 1]};
assign parser_act0[ 2] = {valid[ 2],2'b00,off_64b_seg[ 2],off_byte[ 2],val_index[ 2],val_type[ 2]};
assign parser_act0[ 3] = {valid[ 3],2'b00,off_64b_seg[ 3],off_byte[ 3],val_index[ 3],val_type[ 3]};
assign parser_act0[ 4] = {valid[ 4],2'b00,off_64b_seg[ 4],off_byte[ 4],val_index[ 4],val_type[ 4]};
assign parser_act0[ 5] = {valid[ 5],2'b00,off_64b_seg[ 5],off_byte[ 5],val_index[ 5],val_type[ 5]};
assign parser_act0[ 6] = {valid[ 6],2'b00,off_64b_seg[ 6],off_byte[ 6],val_index[ 6],val_type[ 6]};
assign parser_act0[ 7] = {valid[ 7],2'b00,off_64b_seg[ 7],off_byte[ 7],val_index[ 7],val_type[ 7]};
assign parser_act0[ 8] = {valid[ 8],2'b00,off_64b_seg[ 8],off_byte[ 8],val_index[ 8],val_type[ 8]};
assign parser_act0[ 9] = {valid[ 9],2'b00,off_64b_seg[ 9],off_byte[ 9],val_index[ 9],val_type[ 9]};
assign parser_act0[10] = {valid[10],2'b00,off_64b_seg[10],off_byte[10],val_index[10],val_type[10]};
assign parser_act0[11] = {valid[11],2'b00,off_64b_seg[11],off_byte[11],val_index[11],val_type[11]};
assign parser_act0[12] = {valid[12],2'b00,off_64b_seg[12],off_byte[12],val_index[12],val_type[12]};
assign parser_act0[13] = {valid[13],2'b00,off_64b_seg[13],off_byte[13],val_index[13],val_type[13]};
assign parser_act0[14] = {valid[14],2'b00,off_64b_seg[14],off_byte[14],val_index[14],val_type[14]};
assign parser_act0[15] = {valid[15],2'b00,off_64b_seg[15],off_byte[15],val_index[15],val_type[15]};//8ffe
assign parser_act0[16] = {valid[16],2'b00,off_64b_seg[16],off_byte[16],val_index[16],val_type[16]};
assign parser_act0[17] = {valid[17],2'b00,off_64b_seg[17],off_byte[17],val_index[17],val_type[17]};
assign parser_act0[18] = {valid[18],2'b00,off_64b_seg[18],off_byte[18],val_index[18],val_type[18]};
assign parser_act0[19] = {valid[19],2'b00,off_64b_seg[19],off_byte[19],val_index[19],val_type[19]};
assign parser_act0[20] = {valid[20],2'b00,off_64b_seg[20],off_byte[20],val_index[20],val_type[20]};
assign parser_act0[21] = {valid[21],2'b00,off_64b_seg[21],off_byte[21],val_index[21],val_type[21]};
assign parser_act0[22] = {valid[22],2'b00,off_64b_seg[22],off_byte[22],val_index[22],val_type[22]};
assign parser_act0[23] = {valid[23],2'b00,off_64b_seg[23],off_byte[23],val_index[23],val_type[23]};//97ff

wire [15:0] parser_act_swap0 [23:0];//一共有512个24X16b的指令，作为测试，可以少造一些报文，还是写for循环的方式吧
assign parser_act_swap0[ 0] = {parser_act0[ 0][7:0],parser_act0[ 0][15:8]}; 
assign parser_act_swap0[ 1] = {parser_act0[ 1][7:0],parser_act0[ 1][15:8]}; 
assign parser_act_swap0[ 2] = {parser_act0[ 2][7:0],parser_act0[ 2][15:8]}; 
assign parser_act_swap0[ 3] = {parser_act0[ 3][7:0],parser_act0[ 3][15:8]}; 
assign parser_act_swap0[ 4] = {parser_act0[ 4][7:0],parser_act0[ 4][15:8]}; 
assign parser_act_swap0[ 5] = {parser_act0[ 5][7:0],parser_act0[ 5][15:8]}; 
assign parser_act_swap0[ 6] = {parser_act0[ 6][7:0],parser_act0[ 6][15:8]}; 
assign parser_act_swap0[ 7] = {parser_act0[ 7][7:0],parser_act0[ 7][15:8]};
assign parser_act_swap0[ 8] = {parser_act0[ 8][7:0],parser_act0[ 8][15:8]}; 
assign parser_act_swap0[ 9] = {parser_act0[ 9][7:0],parser_act0[ 9][15:8]}; 
assign parser_act_swap0[10] = {parser_act0[10][7:0],parser_act0[10][15:8]}; 
assign parser_act_swap0[11] = {parser_act0[11][7:0],parser_act0[11][15:8]}; 
assign parser_act_swap0[12] = {parser_act0[12][7:0],parser_act0[12][15:8]}; 
assign parser_act_swap0[13] = {parser_act0[13][7:0],parser_act0[13][15:8]}; 
assign parser_act_swap0[14] = {parser_act0[14][7:0],parser_act0[14][15:8]}; 
assign parser_act_swap0[15] = {parser_act0[15][7:0],parser_act0[15][15:8]};
assign parser_act_swap0[16] = {parser_act0[16][7:0],parser_act0[16][15:8]}; 
assign parser_act_swap0[17] = {parser_act0[17][7:0],parser_act0[17][15:8]}; 
assign parser_act_swap0[18] = {parser_act0[18][7:0],parser_act0[18][15:8]}; 
assign parser_act_swap0[19] = {parser_act0[19][7:0],parser_act0[19][15:8]}; 
assign parser_act_swap0[20] = {parser_act0[20][7:0],parser_act0[20][15:8]}; 
assign parser_act_swap0[21] = {parser_act0[21][7:0],parser_act0[21][15:8]}; 
assign parser_act_swap0[22] = {parser_act0[22][7:0],parser_act0[22][15:8]}; 
assign parser_act_swap0[23] = {parser_act0[23][7:0],parser_act0[23][15:8]};

assign parser_table1[0] = {  
    parser_act_swap0[15],parser_act_swap0[14],parser_act_swap0[13],parser_act_swap0[12],
    parser_act_swap0[11],parser_act_swap0[10],parser_act_swap0[ 9],parser_act_swap0[ 8],
    parser_act_swap0[ 7],parser_act_swap0[ 6],parser_act_swap0[ 5],parser_act_swap0[ 4],
    parser_act_swap0[ 3],parser_act_swap0[ 2],parser_act_swap0[ 1],parser_act_swap0[ 0]
};
assign parser_table2[0] = {    parser_act_swap0[23],parser_act_swap0[22],parser_act_swap0[21],parser_act_swap0[20],
                               parser_act_swap0[19],parser_act_swap0[18],parser_act_swap0[17],parser_act_swap0[16],
                               parser_ram_addr_swap[0]
                          };
//一组数据
wire [15:0] parser_act1 [23:0];
assign parser_act1[ 0] = {valid[ 0],2'b00,off_64b_seg[ 0],off_byte1[ 0],val_index[ 0],val_type[ 0]};
assign parser_act1[ 1] = {valid[ 1],2'b00,off_64b_seg[ 1],off_byte1[ 1],val_index[ 1],val_type[ 1]};
assign parser_act1[ 2] = {valid[ 2],2'b00,off_64b_seg[ 2],off_byte1[ 2],val_index[ 2],val_type[ 2]};
assign parser_act1[ 3] = {valid[ 3],2'b00,off_64b_seg[ 3],off_byte1[ 3],val_index[ 3],val_type[ 3]};
assign parser_act1[ 4] = {valid[ 4],2'b00,off_64b_seg[ 4],off_byte1[ 4],val_index[ 4],val_type[ 4]};
assign parser_act1[ 5] = {valid[ 5],2'b00,off_64b_seg[ 5],off_byte1[ 5],val_index[ 5],val_type[ 5]};
assign parser_act1[ 6] = {valid[ 6],2'b00,off_64b_seg[ 6],off_byte1[ 6],val_index[ 6],val_type[ 6]};
assign parser_act1[ 7] = {valid[ 7],2'b00,off_64b_seg[ 7],off_byte1[ 7],val_index[ 7],val_type[ 7]};
assign parser_act1[ 8] = {valid[ 8],2'b00,off_64b_seg[ 8],off_byte1[ 8],val_index[ 8],val_type[ 8]};
assign parser_act1[ 9] = {valid[ 9],2'b00,off_64b_seg[ 9],off_byte1[ 9],val_index[ 9],val_type[ 9]};
assign parser_act1[10] = {valid[10],2'b00,off_64b_seg[10],off_byte1[10],val_index[10],val_type[10]};
assign parser_act1[11] = {valid[11],2'b00,off_64b_seg[11],off_byte1[11],val_index[11],val_type[11]};
assign parser_act1[12] = {valid[12],2'b00,off_64b_seg[12],off_byte1[12],val_index[12],val_type[12]};
assign parser_act1[13] = {valid[13],2'b00,off_64b_seg[13],off_byte1[13],val_index[13],val_type[13]};
assign parser_act1[14] = {valid[14],2'b00,off_64b_seg[14],off_byte1[14],val_index[14],val_type[14]};
assign parser_act1[15] = {valid[15],2'b00,off_64b_seg[15],off_byte1[15],val_index[15],val_type[15]};//8ffe
assign parser_act1[16] = {valid[16],2'b00,off_64b_seg[16],off_byte1[16],val_index[16],val_type[16]};
assign parser_act1[17] = {valid[17],2'b00,off_64b_seg[17],off_byte1[17],val_index[17],val_type[17]};
assign parser_act1[18] = {valid[18],2'b00,off_64b_seg[18],off_byte1[18],val_index[18],val_type[18]};
assign parser_act1[19] = {valid[19],2'b00,off_64b_seg[19],off_byte1[19],val_index[19],val_type[19]};
assign parser_act1[20] = {valid[20],2'b00,off_64b_seg[20],off_byte1[20],val_index[20],val_type[20]};
assign parser_act1[21] = {valid[21],2'b00,off_64b_seg[21],off_byte1[21],val_index[21],val_type[21]};
assign parser_act1[22] = {valid[22],2'b00,off_64b_seg[22],off_byte1[22],val_index[22],val_type[22]};
assign parser_act1[23] = {valid[23],2'b00,off_64b_seg[23],off_byte1[23],val_index[23],val_type[23]};//97ff

wire [15:0] parser_act_swap1 [23:0];//一共有512个24X16b的指令，作为测试，可以少造一些报文，还是写for循环的方式吧
assign parser_act_swap1[ 0] = {parser_act1[ 0][7:0],parser_act1[ 0][15:8]}; 
assign parser_act_swap1[ 1] = {parser_act1[ 1][7:0],parser_act1[ 1][15:8]}; 
assign parser_act_swap1[ 2] = {parser_act1[ 2][7:0],parser_act1[ 2][15:8]}; 
assign parser_act_swap1[ 3] = {parser_act1[ 3][7:0],parser_act1[ 3][15:8]}; 
assign parser_act_swap1[ 4] = {parser_act1[ 4][7:0],parser_act1[ 4][15:8]}; 
assign parser_act_swap1[ 5] = {parser_act1[ 5][7:0],parser_act1[ 5][15:8]}; 
assign parser_act_swap1[ 6] = {parser_act1[ 6][7:0],parser_act1[ 6][15:8]}; 
assign parser_act_swap1[ 7] = {parser_act1[ 7][7:0],parser_act1[ 7][15:8]};
assign parser_act_swap1[ 8] = {parser_act1[ 8][7:0],parser_act1[ 8][15:8]}; 
assign parser_act_swap1[ 9] = {parser_act1[ 9][7:0],parser_act1[ 9][15:8]}; 
assign parser_act_swap1[10] = {parser_act1[10][7:0],parser_act1[10][15:8]}; 
assign parser_act_swap1[11] = {parser_act1[11][7:0],parser_act1[11][15:8]}; 
assign parser_act_swap1[12] = {parser_act1[12][7:0],parser_act1[12][15:8]}; 
assign parser_act_swap1[13] = {parser_act1[13][7:0],parser_act1[13][15:8]}; 
assign parser_act_swap1[14] = {parser_act1[14][7:0],parser_act1[14][15:8]}; 
assign parser_act_swap1[15] = {parser_act1[15][7:0],parser_act1[15][15:8]};
assign parser_act_swap1[16] = {parser_act1[16][7:0],parser_act1[16][15:8]}; 
assign parser_act_swap1[17] = {parser_act1[17][7:0],parser_act1[17][15:8]}; 
assign parser_act_swap1[18] = {parser_act1[18][7:0],parser_act1[18][15:8]}; 
assign parser_act_swap1[19] = {parser_act1[19][7:0],parser_act1[19][15:8]}; 
assign parser_act_swap1[20] = {parser_act1[20][7:0],parser_act1[20][15:8]}; 
assign parser_act_swap1[21] = {parser_act1[21][7:0],parser_act1[21][15:8]}; 
assign parser_act_swap1[22] = {parser_act1[22][7:0],parser_act1[22][15:8]}; 
assign parser_act_swap1[23] = {parser_act1[23][7:0],parser_act1[23][15:8]};

assign parser_table1[1] = {
    parser_act_swap1[15],parser_act_swap1[14],parser_act_swap1[13],parser_act_swap1[12],
    parser_act_swap1[11],parser_act_swap1[10],parser_act_swap1[ 9],parser_act_swap1[ 8],
    parser_act_swap1[ 7],parser_act_swap1[ 6],parser_act_swap1[ 5],parser_act_swap1[ 4],
    parser_act_swap1[ 3],parser_act_swap1[ 2],parser_act_swap1[ 1],parser_act_swap1[ 0]
};

assign parser_table2[1] = {    parser_act_swap1[23],parser_act_swap1[22],parser_act_swap1[21],parser_act_swap1[20],
                               parser_act_swap1[19],parser_act_swap1[18],parser_act_swap1[17],parser_act_swap1[16],
                               parser_ram_addr_swap[1]
                          };

//二组数据
wire [15:0] parser_act2 [23:0];
assign parser_act2[ 0] = {valid[ 0],2'b00,off_64b_seg[ 0],off_byte2[ 0],val_index[ 0],val_type[ 0]};
assign parser_act2[ 1] = {valid[ 1],2'b00,off_64b_seg[ 1],off_byte2[ 1],val_index[ 1],val_type[ 1]};
assign parser_act2[ 2] = {valid[ 2],2'b00,off_64b_seg[ 2],off_byte2[ 2],val_index[ 2],val_type[ 2]};
assign parser_act2[ 3] = {valid[ 3],2'b00,off_64b_seg[ 3],off_byte2[ 3],val_index[ 3],val_type[ 3]};
assign parser_act2[ 4] = {valid[ 4],2'b00,off_64b_seg[ 4],off_byte2[ 4],val_index[ 4],val_type[ 4]};
assign parser_act2[ 5] = {valid[ 5],2'b00,off_64b_seg[ 5],off_byte2[ 5],val_index[ 5],val_type[ 5]};
assign parser_act2[ 6] = {valid[ 6],2'b00,off_64b_seg[ 6],off_byte2[ 6],val_index[ 6],val_type[ 6]};
assign parser_act2[ 7] = {valid[ 7],2'b00,off_64b_seg[ 7],off_byte2[ 7],val_index[ 7],val_type[ 7]};
assign parser_act2[ 8] = {valid[ 8],2'b00,off_64b_seg[ 8],off_byte2[ 8],val_index[ 8],val_type[ 8]};
assign parser_act2[ 9] = {valid[ 9],2'b00,off_64b_seg[ 9],off_byte2[ 9],val_index[ 9],val_type[ 9]};
assign parser_act2[10] = {valid[10],2'b00,off_64b_seg[10],off_byte2[10],val_index[10],val_type[10]};
assign parser_act2[11] = {valid[11],2'b00,off_64b_seg[11],off_byte2[11],val_index[11],val_type[11]};
assign parser_act2[12] = {valid[12],2'b00,off_64b_seg[12],off_byte2[12],val_index[12],val_type[12]};
assign parser_act2[13] = {valid[13],2'b00,off_64b_seg[13],off_byte2[13],val_index[13],val_type[13]};
assign parser_act2[14] = {valid[14],2'b00,off_64b_seg[14],off_byte2[14],val_index[14],val_type[14]};
assign parser_act2[15] = {valid[15],2'b00,off_64b_seg[15],off_byte2[15],val_index[15],val_type[15]};//8ffe
assign parser_act2[16] = {valid[16],2'b00,off_64b_seg[16],off_byte2[16],val_index[16],val_type[16]};
assign parser_act2[17] = {valid[17],2'b00,off_64b_seg[17],off_byte2[17],val_index[17],val_type[17]};
assign parser_act2[18] = {valid[18],2'b00,off_64b_seg[18],off_byte2[18],val_index[18],val_type[18]};
assign parser_act2[19] = {valid[19],2'b00,off_64b_seg[19],off_byte2[19],val_index[19],val_type[19]};
assign parser_act2[20] = {valid[20],2'b00,off_64b_seg[20],off_byte2[20],val_index[20],val_type[20]};
assign parser_act2[21] = {valid[21],2'b00,off_64b_seg[21],off_byte2[21],val_index[21],val_type[21]};
assign parser_act2[22] = {valid[22],2'b00,off_64b_seg[22],off_byte2[22],val_index[22],val_type[22]};
assign parser_act2[23] = {valid[23],2'b00,off_64b_seg[23],off_byte2[23],val_index[23],val_type[23]};//97ff

wire [15:0] parser_act_swap2 [23:0];//一共有512个24X16b的指令，作为测试，可以少造一些报文，还是写for循环的方式吧
assign parser_act_swap2[ 0] = {parser_act2[ 0][7:0],parser_act2[ 0][15:8]}; 
assign parser_act_swap2[ 1] = {parser_act2[ 1][7:0],parser_act2[ 1][15:8]}; 
assign parser_act_swap2[ 2] = {parser_act2[ 2][7:0],parser_act2[ 2][15:8]}; 
assign parser_act_swap2[ 3] = {parser_act2[ 3][7:0],parser_act2[ 3][15:8]}; 
assign parser_act_swap2[ 4] = {parser_act2[ 4][7:0],parser_act2[ 4][15:8]}; 
assign parser_act_swap2[ 5] = {parser_act2[ 5][7:0],parser_act2[ 5][15:8]}; 
assign parser_act_swap2[ 6] = {parser_act2[ 6][7:0],parser_act2[ 6][15:8]}; 
assign parser_act_swap2[ 7] = {parser_act2[ 7][7:0],parser_act2[ 7][15:8]};
assign parser_act_swap2[ 8] = {parser_act2[ 8][7:0],parser_act2[ 8][15:8]}; 
assign parser_act_swap2[ 9] = {parser_act2[ 9][7:0],parser_act2[ 9][15:8]}; 
assign parser_act_swap2[10] = {parser_act2[10][7:0],parser_act2[10][15:8]}; 
assign parser_act_swap2[11] = {parser_act2[11][7:0],parser_act2[11][15:8]}; 
assign parser_act_swap2[12] = {parser_act2[12][7:0],parser_act2[12][15:8]}; 
assign parser_act_swap2[13] = {parser_act2[13][7:0],parser_act2[13][15:8]}; 
assign parser_act_swap2[14] = {parser_act2[14][7:0],parser_act2[14][15:8]}; 
assign parser_act_swap2[15] = {parser_act2[15][7:0],parser_act2[15][15:8]};
assign parser_act_swap2[16] = {parser_act2[16][7:0],parser_act2[16][15:8]}; 
assign parser_act_swap2[17] = {parser_act2[17][7:0],parser_act2[17][15:8]}; 
assign parser_act_swap2[18] = {parser_act2[18][7:0],parser_act2[18][15:8]}; 
assign parser_act_swap2[19] = {parser_act2[19][7:0],parser_act2[19][15:8]}; 
assign parser_act_swap2[20] = {parser_act2[20][7:0],parser_act2[20][15:8]}; 
assign parser_act_swap2[21] = {parser_act2[21][7:0],parser_act2[21][15:8]}; 
assign parser_act_swap2[22] = {parser_act2[22][7:0],parser_act2[22][15:8]}; 
assign parser_act_swap2[23] = {parser_act2[23][7:0],parser_act2[23][15:8]};

assign parser_table1[2] = {  
    
    parser_act_swap2[15],parser_act_swap2[14],parser_act_swap2[13],parser_act_swap2[12],
    parser_act_swap2[11],parser_act_swap2[10],parser_act_swap2[ 9],parser_act_swap2[ 8],
    parser_act_swap2[ 7],parser_act_swap2[ 6],parser_act_swap2[ 5],parser_act_swap2[ 4],
    parser_act_swap2[ 3],parser_act_swap2[ 2],parser_act_swap2[ 1],parser_act_swap2[ 0]
};

assign parser_table2[2] = { parser_act_swap2[23],parser_act_swap2[22],parser_act_swap2[21],parser_act_swap2[20],
                            parser_act_swap2[19],parser_act_swap2[18],parser_act_swap2[17],parser_act_swap2[16],
                            parser_ram_addr_swap[2]
                          };
//一组数据
wire [15:0] parser_act3 [23:0];
assign parser_act3[ 0] = {valid[ 0],2'b00,off_64b_seg[ 0],off_byte3[ 0],val_index[ 0],val_type[ 0]};
assign parser_act3[ 1] = {valid[ 1],2'b00,off_64b_seg[ 1],off_byte3[ 1],val_index[ 1],val_type[ 1]};
assign parser_act3[ 2] = {valid[ 2],2'b00,off_64b_seg[ 2],off_byte3[ 2],val_index[ 2],val_type[ 2]};
assign parser_act3[ 3] = {valid[ 3],2'b00,off_64b_seg[ 3],off_byte3[ 3],val_index[ 3],val_type[ 3]};
assign parser_act3[ 4] = {valid[ 4],2'b00,off_64b_seg[ 4],off_byte3[ 4],val_index[ 4],val_type[ 4]};
assign parser_act3[ 5] = {valid[ 5],2'b00,off_64b_seg[ 5],off_byte3[ 5],val_index[ 5],val_type[ 5]};
assign parser_act3[ 6] = {valid[ 6],2'b00,off_64b_seg[ 6],off_byte3[ 6],val_index[ 6],val_type[ 6]};
assign parser_act3[ 7] = {valid[ 7],2'b00,off_64b_seg[ 7],off_byte3[ 7],val_index[ 7],val_type[ 7]};
assign parser_act3[ 8] = {valid[ 8],2'b00,off_64b_seg[ 8],off_byte3[ 8],val_index[ 8],val_type[ 8]};
assign parser_act3[ 9] = {valid[ 9],2'b00,off_64b_seg[ 9],off_byte3[ 9],val_index[ 9],val_type[ 9]};
assign parser_act3[10] = {valid[10],2'b00,off_64b_seg[10],off_byte3[10],val_index[10],val_type[10]};
assign parser_act3[11] = {valid[11],2'b00,off_64b_seg[11],off_byte3[11],val_index[11],val_type[11]};
assign parser_act3[12] = {valid[12],2'b00,off_64b_seg[12],off_byte3[12],val_index[12],val_type[12]};
assign parser_act3[13] = {valid[13],2'b00,off_64b_seg[13],off_byte3[13],val_index[13],val_type[13]};
assign parser_act3[14] = {valid[14],2'b00,off_64b_seg[14],off_byte3[14],val_index[14],val_type[14]};
assign parser_act3[15] = {valid[15],2'b00,off_64b_seg[15],off_byte3[15],val_index[15],val_type[15]};//8ffe
assign parser_act3[16] = {valid[16],2'b00,off_64b_seg[16],off_byte3[16],val_index[16],val_type[16]};
assign parser_act3[17] = {valid[17],2'b00,off_64b_seg[17],off_byte3[17],val_index[17],val_type[17]};
assign parser_act3[18] = {valid[18],2'b00,off_64b_seg[18],off_byte3[18],val_index[18],val_type[18]};
assign parser_act3[19] = {valid[19],2'b00,off_64b_seg[19],off_byte3[19],val_index[19],val_type[19]};
assign parser_act3[20] = {valid[20],2'b00,off_64b_seg[20],off_byte3[20],val_index[20],val_type[20]};
assign parser_act3[21] = {valid[21],2'b00,off_64b_seg[21],off_byte3[21],val_index[21],val_type[21]};
assign parser_act3[22] = {valid[22],2'b00,off_64b_seg[22],off_byte3[22],val_index[22],val_type[22]};
assign parser_act3[23] = {valid[23],2'b00,off_64b_seg[23],off_byte3[23],val_index[23],val_type[23]};//97ff

wire [15:0] parser_act_swap3 [23:0];//一共有512个24X16b的指令，作为测试，可以少造一些报文，还是写for循环的方式吧
assign parser_act_swap3[ 0] = {parser_act3[ 0][7:0],parser_act3[ 0][15:8]}; 
assign parser_act_swap3[ 1] = {parser_act3[ 1][7:0],parser_act3[ 1][15:8]}; 
assign parser_act_swap3[ 2] = {parser_act3[ 2][7:0],parser_act3[ 2][15:8]}; 
assign parser_act_swap3[ 3] = {parser_act3[ 3][7:0],parser_act3[ 3][15:8]}; 
assign parser_act_swap3[ 4] = {parser_act3[ 4][7:0],parser_act3[ 4][15:8]}; 
assign parser_act_swap3[ 5] = {parser_act3[ 5][7:0],parser_act3[ 5][15:8]}; 
assign parser_act_swap3[ 6] = {parser_act3[ 6][7:0],parser_act3[ 6][15:8]}; 
assign parser_act_swap3[ 7] = {parser_act3[ 7][7:0],parser_act3[ 7][15:8]};
assign parser_act_swap3[ 8] = {parser_act3[ 8][7:0],parser_act3[ 8][15:8]}; 
assign parser_act_swap3[ 9] = {parser_act3[ 9][7:0],parser_act3[ 9][15:8]}; 
assign parser_act_swap3[10] = {parser_act3[10][7:0],parser_act3[10][15:8]}; 
assign parser_act_swap3[11] = {parser_act3[11][7:0],parser_act3[11][15:8]}; 
assign parser_act_swap3[12] = {parser_act3[12][7:0],parser_act3[12][15:8]}; 
assign parser_act_swap3[13] = {parser_act3[13][7:0],parser_act3[13][15:8]}; 
assign parser_act_swap3[14] = {parser_act3[14][7:0],parser_act3[14][15:8]}; 
assign parser_act_swap3[15] = {parser_act3[15][7:0],parser_act3[15][15:8]};
assign parser_act_swap3[16] = {parser_act3[16][7:0],parser_act3[16][15:8]}; 
assign parser_act_swap3[17] = {parser_act3[17][7:0],parser_act3[17][15:8]}; 
assign parser_act_swap3[18] = {parser_act3[18][7:0],parser_act3[18][15:8]}; 
assign parser_act_swap3[19] = {parser_act3[19][7:0],parser_act3[19][15:8]}; 
assign parser_act_swap3[20] = {parser_act3[20][7:0],parser_act3[20][15:8]}; 
assign parser_act_swap3[21] = {parser_act3[21][7:0],parser_act3[21][15:8]}; 
assign parser_act_swap3[22] = {parser_act3[22][7:0],parser_act3[22][15:8]}; 
assign parser_act_swap3[23] = {parser_act3[23][7:0],parser_act3[23][15:8]};

assign parser_table1[3] = {
    parser_act_swap3[23],parser_act_swap3[22],parser_act_swap3[21],parser_act_swap3[20],
    parser_act_swap3[19],parser_act_swap3[18],parser_act_swap3[17],parser_act_swap3[16],
    parser_act_swap3[15],parser_act_swap3[14],parser_act_swap3[13],parser_act_swap3[12],
    parser_act_swap3[11],parser_act_swap3[10],parser_act_swap3[ 9],parser_act_swap3[ 8],
    parser_act_swap3[ 7],parser_act_swap3[ 6],parser_act_swap3[ 5],parser_act_swap3[ 4],
    parser_act_swap3[ 3],parser_act_swap3[ 2],parser_act_swap3[ 1],parser_act_swap3[ 0]
};
assign parser_table2[3] = { parser_act_swap3[23],parser_act_swap3[22],parser_act_swap3[21],parser_act_swap3[20],
                            parser_act_swap3[19],parser_act_swap3[18],parser_act_swap3[17],parser_act_swap3[16],
                            parser_ram_addr_swap[3]
                          };
//一组数据
wire [15:0] parser_act4 [23:0];
assign parser_act4[ 0] = {valid[ 0],2'b00,off_64b_seg[ 0],off_byte4[ 0],val_index[ 0],val_type[ 0]};
assign parser_act4[ 1] = {valid[ 1],2'b00,off_64b_seg[ 1],off_byte4[ 1],val_index[ 1],val_type[ 1]};
assign parser_act4[ 2] = {valid[ 2],2'b00,off_64b_seg[ 2],off_byte4[ 2],val_index[ 2],val_type[ 2]};
assign parser_act4[ 3] = {valid[ 3],2'b00,off_64b_seg[ 3],off_byte4[ 3],val_index[ 3],val_type[ 3]};
assign parser_act4[ 4] = {valid[ 4],2'b00,off_64b_seg[ 4],off_byte4[ 4],val_index[ 4],val_type[ 4]};
assign parser_act4[ 5] = {valid[ 5],2'b00,off_64b_seg[ 5],off_byte4[ 5],val_index[ 5],val_type[ 5]};
assign parser_act4[ 6] = {valid[ 6],2'b00,off_64b_seg[ 6],off_byte4[ 6],val_index[ 6],val_type[ 6]};
assign parser_act4[ 7] = {valid[ 7],2'b00,off_64b_seg[ 7],off_byte4[ 7],val_index[ 7],val_type[ 7]};
assign parser_act4[ 8] = {valid[ 8],2'b00,off_64b_seg[ 8],off_byte4[ 8],val_index[ 8],val_type[ 8]};
assign parser_act4[ 9] = {valid[ 9],2'b00,off_64b_seg[ 9],off_byte4[ 9],val_index[ 9],val_type[ 9]};
assign parser_act4[10] = {valid[10],2'b00,off_64b_seg[10],off_byte4[10],val_index[10],val_type[10]};
assign parser_act4[11] = {valid[11],2'b00,off_64b_seg[11],off_byte4[11],val_index[11],val_type[11]};
assign parser_act4[12] = {valid[12],2'b00,off_64b_seg[12],off_byte4[12],val_index[12],val_type[12]};
assign parser_act4[13] = {valid[13],2'b00,off_64b_seg[13],off_byte4[13],val_index[13],val_type[13]};
assign parser_act4[14] = {valid[14],2'b00,off_64b_seg[14],off_byte4[14],val_index[14],val_type[14]};
assign parser_act4[15] = {valid[15],2'b00,off_64b_seg[15],off_byte4[15],val_index[15],val_type[15]};//8ffe
assign parser_act4[16] = {valid[16],2'b00,off_64b_seg[16],off_byte4[16],val_index[16],val_type[16]};
assign parser_act4[17] = {valid[17],2'b00,off_64b_seg[17],off_byte4[17],val_index[17],val_type[17]};
assign parser_act4[18] = {valid[18],2'b00,off_64b_seg[18],off_byte4[18],val_index[18],val_type[18]};
assign parser_act4[19] = {valid[19],2'b00,off_64b_seg[19],off_byte4[19],val_index[19],val_type[19]};
assign parser_act4[20] = {valid[20],2'b00,off_64b_seg[20],off_byte4[20],val_index[20],val_type[20]};
assign parser_act4[21] = {valid[21],2'b00,off_64b_seg[21],off_byte4[21],val_index[21],val_type[21]};
assign parser_act4[22] = {valid[22],2'b00,off_64b_seg[22],off_byte4[22],val_index[22],val_type[22]};
assign parser_act4[23] = {valid[23],2'b00,off_64b_seg[23],off_byte4[23],val_index[23],val_type[23]};//97ff

wire [15:0] parser_act_swap4 [23:0];//一共有512个24X16b的指令，作为测试，可以少造一些报文，还是写for循环的方式吧
assign parser_act_swap4[ 0] = {parser_act4[ 0][7:0],parser_act4[ 0][15:8]}; 
assign parser_act_swap4[ 1] = {parser_act4[ 1][7:0],parser_act4[ 1][15:8]}; 
assign parser_act_swap4[ 2] = {parser_act4[ 2][7:0],parser_act4[ 2][15:8]}; 
assign parser_act_swap4[ 3] = {parser_act4[ 3][7:0],parser_act4[ 3][15:8]}; 
assign parser_act_swap4[ 4] = {parser_act4[ 4][7:0],parser_act4[ 4][15:8]}; 
assign parser_act_swap4[ 5] = {parser_act4[ 5][7:0],parser_act4[ 5][15:8]}; 
assign parser_act_swap4[ 6] = {parser_act4[ 6][7:0],parser_act4[ 6][15:8]}; 
assign parser_act_swap4[ 7] = {parser_act4[ 7][7:0],parser_act4[ 7][15:8]};
assign parser_act_swap4[ 8] = {parser_act4[ 8][7:0],parser_act4[ 8][15:8]}; 
assign parser_act_swap4[ 9] = {parser_act4[ 9][7:0],parser_act4[ 9][15:8]}; 
assign parser_act_swap4[10] = {parser_act4[10][7:0],parser_act4[10][15:8]}; 
assign parser_act_swap4[11] = {parser_act4[11][7:0],parser_act4[11][15:8]}; 
assign parser_act_swap4[12] = {parser_act4[12][7:0],parser_act4[12][15:8]}; 
assign parser_act_swap4[13] = {parser_act4[13][7:0],parser_act4[13][15:8]}; 
assign parser_act_swap4[14] = {parser_act4[14][7:0],parser_act4[14][15:8]}; 
assign parser_act_swap4[15] = {parser_act4[15][7:0],parser_act4[15][15:8]};
assign parser_act_swap4[16] = {parser_act4[16][7:0],parser_act4[16][15:8]}; 
assign parser_act_swap4[17] = {parser_act4[17][7:0],parser_act4[17][15:8]}; 
assign parser_act_swap4[18] = {parser_act4[18][7:0],parser_act4[18][15:8]}; 
assign parser_act_swap4[19] = {parser_act4[19][7:0],parser_act4[19][15:8]}; 
assign parser_act_swap4[20] = {parser_act4[20][7:0],parser_act4[20][15:8]}; 
assign parser_act_swap4[21] = {parser_act4[21][7:0],parser_act4[21][15:8]}; 
assign parser_act_swap4[22] = {parser_act4[22][7:0],parser_act4[22][15:8]}; 
assign parser_act_swap4[23] = {parser_act4[23][7:0],parser_act4[23][15:8]};

assign parser_table1[4] = {
    
    parser_act_swap4[15],parser_act_swap4[14],parser_act_swap4[13],parser_act_swap4[12],
    parser_act_swap4[11],parser_act_swap4[10],parser_act_swap4[ 9],parser_act_swap4[ 8],
    parser_act_swap4[ 7],parser_act_swap4[ 6],parser_act_swap4[ 5],parser_act_swap4[ 4],
    parser_act_swap4[ 3],parser_act_swap4[ 2],parser_act_swap4[ 1],parser_act_swap4[ 0]
};
assign parser_table2[4] = { parser_act_swap4[23],parser_act_swap4[22],parser_act_swap4[21],parser_act_swap4[20],
                            parser_act_swap4[19],parser_act_swap4[18],parser_act_swap4[17],parser_act_swap4[16],
                            parser_ram_addr_swap[4]
                          };
//一组数据
wire [15:0] parser_act5 [23:0];
assign parser_act5[ 0] = {valid[ 0],2'b00,off_64b_seg[ 0],off_byte5[ 0],val_index[ 0],val_type[ 0]};
assign parser_act5[ 1] = {valid[ 1],2'b00,off_64b_seg[ 1],off_byte5[ 1],val_index[ 1],val_type[ 1]};
assign parser_act5[ 2] = {valid[ 2],2'b00,off_64b_seg[ 2],off_byte5[ 2],val_index[ 2],val_type[ 2]};
assign parser_act5[ 3] = {valid[ 3],2'b00,off_64b_seg[ 3],off_byte5[ 3],val_index[ 3],val_type[ 3]};
assign parser_act5[ 4] = {valid[ 4],2'b00,off_64b_seg[ 4],off_byte5[ 4],val_index[ 4],val_type[ 4]};
assign parser_act5[ 5] = {valid[ 5],2'b00,off_64b_seg[ 5],off_byte5[ 5],val_index[ 5],val_type[ 5]};
assign parser_act5[ 6] = {valid[ 6],2'b00,off_64b_seg[ 6],off_byte5[ 6],val_index[ 6],val_type[ 6]};
assign parser_act5[ 7] = {valid[ 7],2'b00,off_64b_seg[ 7],off_byte5[ 7],val_index[ 7],val_type[ 7]};
assign parser_act5[ 8] = {valid[ 8],2'b00,off_64b_seg[ 8],off_byte5[ 8],val_index[ 8],val_type[ 8]};
assign parser_act5[ 9] = {valid[ 9],2'b00,off_64b_seg[ 9],off_byte5[ 9],val_index[ 9],val_type[ 9]};
assign parser_act5[10] = {valid[10],2'b00,off_64b_seg[10],off_byte5[10],val_index[10],val_type[10]};
assign parser_act5[11] = {valid[11],2'b00,off_64b_seg[11],off_byte5[11],val_index[11],val_type[11]};
assign parser_act5[12] = {valid[12],2'b00,off_64b_seg[12],off_byte5[12],val_index[12],val_type[12]};
assign parser_act5[13] = {valid[13],2'b00,off_64b_seg[13],off_byte5[13],val_index[13],val_type[13]};
assign parser_act5[14] = {valid[14],2'b00,off_64b_seg[14],off_byte5[14],val_index[14],val_type[14]};
assign parser_act5[15] = {valid[15],2'b00,off_64b_seg[15],off_byte5[15],val_index[15],val_type[15]};//8ffe
assign parser_act5[16] = {valid[16],2'b00,off_64b_seg[16],off_byte5[16],val_index[16],val_type[16]};
assign parser_act5[17] = {valid[17],2'b00,off_64b_seg[17],off_byte5[17],val_index[17],val_type[17]};
assign parser_act5[18] = {valid[18],2'b00,off_64b_seg[18],off_byte5[18],val_index[18],val_type[18]};
assign parser_act5[19] = {valid[19],2'b00,off_64b_seg[19],off_byte5[19],val_index[19],val_type[19]};
assign parser_act5[20] = {valid[20],2'b00,off_64b_seg[20],off_byte5[20],val_index[20],val_type[20]};
assign parser_act5[21] = {valid[21],2'b00,off_64b_seg[21],off_byte5[21],val_index[21],val_type[21]};
assign parser_act5[22] = {valid[22],2'b00,off_64b_seg[22],off_byte5[22],val_index[22],val_type[22]};
assign parser_act5[23] = {valid[23],2'b00,off_64b_seg[23],off_byte5[23],val_index[23],val_type[23]};//97ff

wire [15:0] parser_act_swap5 [23:0];//一共有512个24X16b的指令，作为测试，可以少造一些报文，还是写for循环的方式吧
assign parser_act_swap5[ 0] = {parser_act5[ 0][7:0],parser_act5[ 0][15:8]}; 
assign parser_act_swap5[ 1] = {parser_act5[ 1][7:0],parser_act5[ 1][15:8]}; 
assign parser_act_swap5[ 2] = {parser_act5[ 2][7:0],parser_act5[ 2][15:8]}; 
assign parser_act_swap5[ 3] = {parser_act5[ 3][7:0],parser_act5[ 3][15:8]}; 
assign parser_act_swap5[ 4] = {parser_act5[ 4][7:0],parser_act5[ 4][15:8]}; 
assign parser_act_swap5[ 5] = {parser_act5[ 5][7:0],parser_act5[ 5][15:8]}; 
assign parser_act_swap5[ 6] = {parser_act5[ 6][7:0],parser_act5[ 6][15:8]}; 
assign parser_act_swap5[ 7] = {parser_act5[ 7][7:0],parser_act5[ 7][15:8]};
assign parser_act_swap5[ 8] = {parser_act5[ 8][7:0],parser_act5[ 8][15:8]}; 
assign parser_act_swap5[ 9] = {parser_act5[ 9][7:0],parser_act5[ 9][15:8]}; 
assign parser_act_swap5[10] = {parser_act5[10][7:0],parser_act5[10][15:8]}; 
assign parser_act_swap5[11] = {parser_act5[11][7:0],parser_act5[11][15:8]}; 
assign parser_act_swap5[12] = {parser_act5[12][7:0],parser_act5[12][15:8]}; 
assign parser_act_swap5[13] = {parser_act5[13][7:0],parser_act5[13][15:8]}; 
assign parser_act_swap5[14] = {parser_act5[14][7:0],parser_act5[14][15:8]}; 
assign parser_act_swap5[15] = {parser_act5[15][7:0],parser_act5[15][15:8]};
assign parser_act_swap5[16] = {parser_act5[16][7:0],parser_act5[16][15:8]}; 
assign parser_act_swap5[17] = {parser_act5[17][7:0],parser_act5[17][15:8]}; 
assign parser_act_swap5[18] = {parser_act5[18][7:0],parser_act5[18][15:8]}; 
assign parser_act_swap5[19] = {parser_act5[19][7:0],parser_act5[19][15:8]}; 
assign parser_act_swap5[20] = {parser_act5[20][7:0],parser_act5[20][15:8]}; 
assign parser_act_swap5[21] = {parser_act5[21][7:0],parser_act5[21][15:8]}; 
assign parser_act_swap5[22] = {parser_act5[22][7:0],parser_act5[22][15:8]}; 
assign parser_act_swap5[23] = {parser_act5[23][7:0],parser_act5[23][15:8]};

assign parser_table1[5] = {
    
    parser_act_swap5[15],parser_act_swap5[14],parser_act_swap5[13],parser_act_swap5[12],
    parser_act_swap5[11],parser_act_swap5[10],parser_act_swap5[ 9],parser_act_swap5[ 8],
    parser_act_swap5[ 7],parser_act_swap5[ 6],parser_act_swap5[ 5],parser_act_swap5[ 4],
    parser_act_swap5[ 3],parser_act_swap5[ 2],parser_act_swap5[ 1],parser_act_swap5[ 0]
};
assign parser_table2[5] = { parser_act_swap5[23],parser_act_swap5[22],parser_act_swap5[21],parser_act_swap5[20],
                            parser_act_swap5[19],parser_act_swap5[18],parser_act_swap5[17],parser_act_swap5[16],
                            parser_ram_addr_swap[5]
                          };
//一组数据
wire [15:0] parser_act6 [23:0];
assign parser_act6[ 0] = {valid[ 0],2'b00,off_64b_seg[ 0],off_byte6[ 0],val_index[ 0],val_type[ 0]};
assign parser_act6[ 1] = {valid[ 1],2'b00,off_64b_seg[ 1],off_byte6[ 1],val_index[ 1],val_type[ 1]};
assign parser_act6[ 2] = {valid[ 2],2'b00,off_64b_seg[ 2],off_byte6[ 2],val_index[ 2],val_type[ 2]};
assign parser_act6[ 3] = {valid[ 3],2'b00,off_64b_seg[ 3],off_byte6[ 3],val_index[ 3],val_type[ 3]};
assign parser_act6[ 4] = {valid[ 4],2'b00,off_64b_seg[ 4],off_byte6[ 4],val_index[ 4],val_type[ 4]};
assign parser_act6[ 5] = {valid[ 5],2'b00,off_64b_seg[ 5],off_byte6[ 5],val_index[ 5],val_type[ 5]};
assign parser_act6[ 6] = {valid[ 6],2'b00,off_64b_seg[ 6],off_byte6[ 6],val_index[ 6],val_type[ 6]};
assign parser_act6[ 7] = {valid[ 7],2'b00,off_64b_seg[ 7],off_byte6[ 7],val_index[ 7],val_type[ 7]};
assign parser_act6[ 8] = {valid[ 8],2'b00,off_64b_seg[ 8],off_byte6[ 8],val_index[ 8],val_type[ 8]};
assign parser_act6[ 9] = {valid[ 9],2'b00,off_64b_seg[ 9],off_byte6[ 9],val_index[ 9],val_type[ 9]};
assign parser_act6[10] = {valid[10],2'b00,off_64b_seg[10],off_byte6[10],val_index[10],val_type[10]};
assign parser_act6[11] = {valid[11],2'b00,off_64b_seg[11],off_byte6[11],val_index[11],val_type[11]};
assign parser_act6[12] = {valid[12],2'b00,off_64b_seg[12],off_byte6[12],val_index[12],val_type[12]};
assign parser_act6[13] = {valid[13],2'b00,off_64b_seg[13],off_byte6[13],val_index[13],val_type[13]};
assign parser_act6[14] = {valid[14],2'b00,off_64b_seg[14],off_byte6[14],val_index[14],val_type[14]};
assign parser_act6[15] = {valid[15],2'b00,off_64b_seg[15],off_byte6[15],val_index[15],val_type[15]};//8ffe
assign parser_act6[16] = {valid[16],2'b00,off_64b_seg[16],off_byte6[16],val_index[16],val_type[16]};
assign parser_act6[17] = {valid[17],2'b00,off_64b_seg[17],off_byte6[17],val_index[17],val_type[17]};
assign parser_act6[18] = {valid[18],2'b00,off_64b_seg[18],off_byte6[18],val_index[18],val_type[18]};
assign parser_act6[19] = {valid[19],2'b00,off_64b_seg[19],off_byte6[19],val_index[19],val_type[19]};
assign parser_act6[20] = {valid[20],2'b00,off_64b_seg[20],off_byte6[20],val_index[20],val_type[20]};
assign parser_act6[21] = {valid[21],2'b00,off_64b_seg[21],off_byte6[21],val_index[21],val_type[21]};
assign parser_act6[22] = {valid[22],2'b00,off_64b_seg[22],off_byte6[22],val_index[22],val_type[22]};
assign parser_act6[23] = {valid[23],2'b00,off_64b_seg[23],off_byte6[23],val_index[23],val_type[23]};//97ff

wire [15:0] parser_act_swap6 [23:0];//一共有512个24X16b的指令，作为测试，可以少造一些报文，还是写for循环的方式吧
assign parser_act_swap6[ 0] = {parser_act6[ 0][7:0],parser_act6[ 0][15:8]}; 
assign parser_act_swap6[ 1] = {parser_act6[ 1][7:0],parser_act6[ 1][15:8]}; 
assign parser_act_swap6[ 2] = {parser_act6[ 2][7:0],parser_act6[ 2][15:8]}; 
assign parser_act_swap6[ 3] = {parser_act6[ 3][7:0],parser_act6[ 3][15:8]}; 
assign parser_act_swap6[ 4] = {parser_act6[ 4][7:0],parser_act6[ 4][15:8]}; 
assign parser_act_swap6[ 5] = {parser_act6[ 5][7:0],parser_act6[ 5][15:8]}; 
assign parser_act_swap6[ 6] = {parser_act6[ 6][7:0],parser_act6[ 6][15:8]}; 
assign parser_act_swap6[ 7] = {parser_act6[ 7][7:0],parser_act6[ 7][15:8]};
assign parser_act_swap6[ 8] = {parser_act6[ 8][7:0],parser_act6[ 8][15:8]}; 
assign parser_act_swap6[ 9] = {parser_act6[ 9][7:0],parser_act6[ 9][15:8]}; 
assign parser_act_swap6[10] = {parser_act6[10][7:0],parser_act6[10][15:8]}; 
assign parser_act_swap6[11] = {parser_act6[11][7:0],parser_act6[11][15:8]}; 
assign parser_act_swap6[12] = {parser_act6[12][7:0],parser_act6[12][15:8]}; 
assign parser_act_swap6[13] = {parser_act6[13][7:0],parser_act6[13][15:8]}; 
assign parser_act_swap6[14] = {parser_act6[14][7:0],parser_act6[14][15:8]}; 
assign parser_act_swap6[15] = {parser_act6[15][7:0],parser_act6[15][15:8]};
assign parser_act_swap6[16] = {parser_act6[16][7:0],parser_act6[16][15:8]}; 
assign parser_act_swap6[17] = {parser_act6[17][7:0],parser_act6[17][15:8]}; 
assign parser_act_swap6[18] = {parser_act6[18][7:0],parser_act6[18][15:8]}; 
assign parser_act_swap6[19] = {parser_act6[19][7:0],parser_act6[19][15:8]}; 
assign parser_act_swap6[20] = {parser_act6[20][7:0],parser_act6[20][15:8]}; 
assign parser_act_swap6[21] = {parser_act6[21][7:0],parser_act6[21][15:8]}; 
assign parser_act_swap6[22] = {parser_act6[22][7:0],parser_act6[22][15:8]}; 
assign parser_act_swap6[23] = {parser_act6[23][7:0],parser_act6[23][15:8]};

assign parser_table1[6] = {
    
    parser_act_swap6[15],parser_act_swap6[14],parser_act_swap6[13],parser_act_swap6[12],
    parser_act_swap6[11],parser_act_swap6[10],parser_act_swap6[ 9],parser_act_swap6[ 8],
    parser_act_swap6[ 7],parser_act_swap6[ 6],parser_act_swap6[ 5],parser_act_swap6[ 4],
    parser_act_swap6[ 3],parser_act_swap6[ 2],parser_act_swap6[ 1],parser_act_swap6[ 0]
};
assign parser_table2[6] = { parser_act_swap6[23],parser_act_swap6[22],parser_act_swap6[21],parser_act_swap6[20],
                            parser_act_swap6[19],parser_act_swap6[18],parser_act_swap6[17],parser_act_swap6[16],
                            parser_ram_addr_swap[6]
                        };

wire [127:0]bit_tcam_mask;
assign bit_tcam_mask = 128'd0;

wire [15:0] bit_act [127:0];
assign bit_act[ 0 ] = {6'b100000,7'd0  ,3'd0};
assign bit_act[ 1 ] = {6'b100000,7'd0  ,3'd1};
assign bit_act[ 2 ] = {6'b100000,7'd0  ,3'd2};
assign bit_act[ 3 ] = {6'b100000,7'd0  ,3'd3};
assign bit_act[ 4 ] = {6'b100000,7'd0  ,3'd4};
assign bit_act[ 5 ] = {6'b100000,7'd0  ,3'd5};
assign bit_act[ 6 ] = {6'b100000,7'd0  ,3'd6};
assign bit_act[ 7 ] = {6'b100000,7'd0  ,3'd7};

assign bit_act[ 8 ] = {6'b100000,7'd1  ,3'd0};
assign bit_act[ 9 ] = {6'b100000,7'd1  ,3'd1};
assign bit_act[ 10] = {6'b100000,7'd1  ,3'd2};
assign bit_act[ 11] = {6'b100000,7'd1  ,3'd3};
assign bit_act[ 12] = {6'b100000,7'd1  ,3'd4};
assign bit_act[ 13] = {6'b100000,7'd1  ,3'd5};
assign bit_act[ 14] = {6'b100000,7'd1  ,3'd6};
assign bit_act[ 15] = {6'b100000,7'd1  ,3'd7};

assign bit_act[ 16] = {6'b100000,7'd1  ,3'd0};
assign bit_act[ 17] = {6'b100000,7'd1  ,3'd0};
assign bit_act[ 18] = {6'b100000,7'd18 ,3'd0};
assign bit_act[ 19] = {6'b100000,7'd19 ,3'd0};
assign bit_act[ 20] = {6'b100000,7'd20 ,3'd0};
assign bit_act[ 21] = {6'b100000,7'd21 ,3'd0};
assign bit_act[ 22] = {6'b100000,7'd22 ,3'd0};
assign bit_act[ 23] = {6'b100000,7'd23 ,3'd0};
assign bit_act[ 24] = {6'b100000,7'd24 ,3'd0};
assign bit_act[ 25] = {6'b100000,7'd25 ,3'd0};
assign bit_act[ 26] = {6'b100000,7'd26 ,3'd0};
assign bit_act[ 27] = {6'b100000,7'd27 ,3'd0};
assign bit_act[ 28] = {6'b100000,7'd28 ,3'd0};
assign bit_act[ 29] = {6'b100000,7'd29 ,3'd0};
assign bit_act[ 30] = {6'b100000,7'd30 ,3'd0};
assign bit_act[ 31] = {6'b100000,7'd31 ,3'd0};
assign bit_act[ 32] = {6'b100000,7'd32 ,3'd0};
assign bit_act[ 33] = {6'b100000,7'd33 ,3'd0};
assign bit_act[ 34] = {6'b100000,7'd34 ,3'd0};
assign bit_act[ 35] = {6'b100000,7'd35 ,3'd0};
assign bit_act[ 36] = {6'b100000,7'd36 ,3'd0};
assign bit_act[ 37] = {6'b100000,7'd37 ,3'd0};
assign bit_act[ 38] = {6'b100000,7'd38 ,3'd0};
assign bit_act[ 39] = {6'b100000,7'd39 ,3'd0};
assign bit_act[ 40] = {6'b100000,7'd40 ,3'd0};
assign bit_act[ 41] = {6'b100000,7'd41 ,3'd0};
assign bit_act[ 42] = {6'b100000,7'd42 ,3'd0};
assign bit_act[ 43] = {6'b100000,7'd43 ,3'd0};
assign bit_act[ 44] = {6'b100000,7'd44 ,3'd0};
assign bit_act[ 45] = {6'b100000,7'd45 ,3'd0};
assign bit_act[ 46] = {6'b100000,7'd46 ,3'd0};
assign bit_act[ 47] = {6'b100000,7'd47 ,3'd0};
assign bit_act[ 48] = {6'b100000,7'd48 ,3'd0};
assign bit_act[ 49] = {6'b100000,7'd49 ,3'd0};
assign bit_act[ 50] = {6'b100000,7'd50 ,3'd0};
assign bit_act[ 51] = {6'b100000,7'd51 ,3'd0};
assign bit_act[ 52] = {6'b100000,7'd52 ,3'd0};
assign bit_act[ 53] = {6'b100000,7'd53 ,3'd0};
assign bit_act[ 54] = {6'b100000,7'd54 ,3'd0};
assign bit_act[ 55] = {6'b100000,7'd55 ,3'd0};
assign bit_act[ 56] = {6'b100000,7'd56 ,3'd0};
assign bit_act[ 57] = {6'b100000,7'd57 ,3'd0};
assign bit_act[ 58] = {6'b100000,7'd58 ,3'd0};
assign bit_act[ 59] = {6'b100000,7'd59 ,3'd0};
assign bit_act[ 60] = {6'b100000,7'd60 ,3'd0};
assign bit_act[ 61] = {6'b100000,7'd61 ,3'd0};
assign bit_act[ 62] = {6'b100000,7'd62 ,3'd0};
assign bit_act[ 63] = {6'b100000,7'd63 ,3'd0};
assign bit_act[ 64] = {6'b100000,7'd64 ,3'd0};
assign bit_act[ 65] = {6'b100000,7'd65 ,3'd0};
assign bit_act[ 66] = {6'b100000,7'd66 ,3'd0};
assign bit_act[ 67] = {6'b100000,7'd67 ,3'd0};
assign bit_act[ 68] = {6'b100000,7'd68 ,3'd0};
assign bit_act[ 69] = {6'b100000,7'd69 ,3'd0};
assign bit_act[ 70] = {6'b100000,7'd70 ,3'd0};
assign bit_act[ 71] = {6'b100000,7'd71 ,3'd0};
assign bit_act[ 72] = {6'b100000,7'd72 ,3'd0};
assign bit_act[ 73] = {6'b100000,7'd73 ,3'd0};
assign bit_act[ 74] = {6'b100000,7'd74 ,3'd0};
assign bit_act[ 75] = {6'b100000,7'd75 ,3'd0};
assign bit_act[ 76] = {6'b100000,7'd76 ,3'd0};
assign bit_act[ 77] = {6'b100000,7'd77 ,3'd0};
assign bit_act[ 78] = {6'b100000,7'd78 ,3'd0};
assign bit_act[ 79] = {6'b100000,7'd79 ,3'd0};
assign bit_act[ 80] = {6'b100000,7'd80 ,3'd0};
assign bit_act[ 81] = {6'b100000,7'd81 ,3'd0};
assign bit_act[ 82] = {6'b100000,7'd82 ,3'd0};
assign bit_act[ 83] = {6'b100000,7'd83 ,3'd0};
assign bit_act[ 84] = {6'b100000,7'd84 ,3'd0};
assign bit_act[ 85] = {6'b100000,7'd85 ,3'd0};
assign bit_act[ 86] = {6'b100000,7'd86 ,3'd0};
assign bit_act[ 87] = {6'b100000,7'd87 ,3'd0};
assign bit_act[ 88] = {6'b100000,7'd88 ,3'd0};
assign bit_act[ 89] = {6'b100000,7'd89 ,3'd0};
assign bit_act[ 90] = {6'b100000,7'd90 ,3'd0};
assign bit_act[ 91] = {6'b100000,7'd91 ,3'd0};
assign bit_act[ 92] = {6'b100000,7'd92 ,3'd0};
assign bit_act[ 93] = {6'b100000,7'd93 ,3'd0};
assign bit_act[ 94] = {6'b100000,7'd94 ,3'd0};
assign bit_act[ 95] = {6'b100000,7'd95 ,3'd0};
assign bit_act[ 96] = {6'b100000,7'd96 ,3'd0};
assign bit_act[ 97] = {6'b100000,7'd97 ,3'd0};
assign bit_act[ 98] = {6'b100000,7'd98 ,3'd0};
assign bit_act[ 99] = {6'b100000,7'd99 ,3'd0};
assign bit_act[100] = {6'b100000,7'd100,3'd0};
assign bit_act[101] = {6'b100000,7'd101,3'd0};
assign bit_act[102] = {6'b100000,7'd102,3'd0};
assign bit_act[103] = {6'b100000,7'd103,3'd0};
assign bit_act[104] = {6'b100000,7'd104,3'd0};
assign bit_act[105] = {6'b100000,7'd105,3'd0};
assign bit_act[106] = {6'b100000,7'd106,3'd0};
assign bit_act[107] = {6'b100000,7'd107,3'd0};
assign bit_act[108] = {6'b100000,7'd108,3'd0};
assign bit_act[109] = {6'b100000,7'd109,3'd0};
assign bit_act[110] = {6'b100000,7'd110,3'd0};
assign bit_act[111] = {6'b100000,7'd111,3'd0};
assign bit_act[112] = {6'b100000,7'd112,3'd0};
assign bit_act[113] = {6'b100000,7'd113,3'd0};
assign bit_act[114] = {6'b100000,7'd114,3'd0};
assign bit_act[115] = {6'b100000,7'd115,3'd0};
assign bit_act[116] = {6'b100000,7'd116,3'd0};
assign bit_act[117] = {6'b100000,7'd117,3'd0};
assign bit_act[118] = {6'b100000,7'd118,3'd0};
assign bit_act[119] = {6'b100000,7'd119,3'd0};
assign bit_act[120] = {6'b100000,7'd120,3'd0};
assign bit_act[121] = {6'b100000,7'd121,3'd0};
assign bit_act[122] = {6'b100000,7'd122,3'd0};
assign bit_act[123] = {6'b100000,7'd123,3'd0};
assign bit_act[124] = {6'b100000,7'd124,3'd0};
assign bit_act[125] = {6'b100000,7'd125,3'd0};
assign bit_act[126] = {6'b100000,7'd126,3'd0};
assign bit_act[127] = {6'b100000,7'd127,3'd0};

wire [15:0] bit_act_swap [127:0];
assign bit_act_swap[ 0 ] = {bit_act[ 0 ][7:0],bit_act[ 0 ][15:8]};
assign bit_act_swap[ 1 ] = {bit_act[ 1 ][7:0],bit_act[ 1 ][15:8]};
assign bit_act_swap[ 2 ] = {bit_act[ 2 ][7:0],bit_act[ 2 ][15:8]};
assign bit_act_swap[ 3 ] = {bit_act[ 3 ][7:0],bit_act[ 3 ][15:8]};
assign bit_act_swap[ 4 ] = {bit_act[ 4 ][7:0],bit_act[ 4 ][15:8]};
assign bit_act_swap[ 5 ] = {bit_act[ 5 ][7:0],bit_act[ 5 ][15:8]};
assign bit_act_swap[ 6 ] = {bit_act[ 6 ][7:0],bit_act[ 6 ][15:8]};
assign bit_act_swap[ 7 ] = {bit_act[ 7 ][7:0],bit_act[ 7 ][15:8]};
assign bit_act_swap[ 8 ] = {bit_act[ 8 ][7:0],bit_act[ 8 ][15:8]};
assign bit_act_swap[ 9 ] = {bit_act[ 9 ][7:0],bit_act[ 9 ][15:8]};
assign bit_act_swap[ 10] = {bit_act[ 10][7:0],bit_act[ 10][15:8]};
assign bit_act_swap[ 11] = {bit_act[ 11][7:0],bit_act[ 11][15:8]};
assign bit_act_swap[ 12] = {bit_act[ 12][7:0],bit_act[ 12][15:8]};
assign bit_act_swap[ 13] = {bit_act[ 13][7:0],bit_act[ 13][15:8]};
assign bit_act_swap[ 14] = {bit_act[ 14][7:0],bit_act[ 14][15:8]};
assign bit_act_swap[ 15] = {bit_act[ 15][7:0],bit_act[ 15][15:8]};
assign bit_act_swap[ 16] = {bit_act[ 16][7:0],bit_act[ 16][15:8]};
assign bit_act_swap[ 17] = {bit_act[ 17][7:0],bit_act[ 17][15:8]};
assign bit_act_swap[ 18] = {bit_act[ 18][7:0],bit_act[ 18][15:8]};
assign bit_act_swap[ 19] = {bit_act[ 19][7:0],bit_act[ 19][15:8]};
assign bit_act_swap[ 20] = {bit_act[ 20][7:0],bit_act[ 20][15:8]};
assign bit_act_swap[ 21] = {bit_act[ 21][7:0],bit_act[ 21][15:8]};
assign bit_act_swap[ 22] = {bit_act[ 22][7:0],bit_act[ 22][15:8]};
assign bit_act_swap[ 23] = {bit_act[ 23][7:0],bit_act[ 23][15:8]};
assign bit_act_swap[ 24] = {bit_act[ 24][7:0],bit_act[ 24][15:8]};
assign bit_act_swap[ 25] = {bit_act[ 25][7:0],bit_act[ 25][15:8]};
assign bit_act_swap[ 26] = {bit_act[ 26][7:0],bit_act[ 26][15:8]};
assign bit_act_swap[ 27] = {bit_act[ 27][7:0],bit_act[ 27][15:8]};
assign bit_act_swap[ 28] = {bit_act[ 28][7:0],bit_act[ 28][15:8]};
assign bit_act_swap[ 29] = {bit_act[ 29][7:0],bit_act[ 29][15:8]};
assign bit_act_swap[ 30] = {bit_act[ 30][7:0],bit_act[ 30][15:8]};
assign bit_act_swap[ 31] = {bit_act[ 31][7:0],bit_act[ 31][15:8]};
assign bit_act_swap[ 32] = {bit_act[ 32][7:0],bit_act[ 32][15:8]};
assign bit_act_swap[ 33] = {bit_act[ 33][7:0],bit_act[ 33][15:8]};
assign bit_act_swap[ 34] = {bit_act[ 34][7:0],bit_act[ 34][15:8]};
assign bit_act_swap[ 35] = {bit_act[ 35][7:0],bit_act[ 35][15:8]};
assign bit_act_swap[ 36] = {bit_act[ 36][7:0],bit_act[ 36][15:8]};
assign bit_act_swap[ 37] = {bit_act[ 37][7:0],bit_act[ 37][15:8]};
assign bit_act_swap[ 38] = {bit_act[ 38][7:0],bit_act[ 38][15:8]};
assign bit_act_swap[ 39] = {bit_act[ 39][7:0],bit_act[ 39][15:8]};
assign bit_act_swap[ 40] = {bit_act[ 40][7:0],bit_act[ 40][15:8]};
assign bit_act_swap[ 41] = {bit_act[ 41][7:0],bit_act[ 41][15:8]};
assign bit_act_swap[ 42] = {bit_act[ 42][7:0],bit_act[ 42][15:8]};
assign bit_act_swap[ 43] = {bit_act[ 43][7:0],bit_act[ 43][15:8]};
assign bit_act_swap[ 44] = {bit_act[ 44][7:0],bit_act[ 44][15:8]};
assign bit_act_swap[ 45] = {bit_act[ 45][7:0],bit_act[ 45][15:8]};
assign bit_act_swap[ 46] = {bit_act[ 46][7:0],bit_act[ 46][15:8]};
assign bit_act_swap[ 47] = {bit_act[ 47][7:0],bit_act[ 47][15:8]};
assign bit_act_swap[ 48] = {bit_act[ 48][7:0],bit_act[ 48][15:8]};
assign bit_act_swap[ 49] = {bit_act[ 49][7:0],bit_act[ 49][15:8]};
assign bit_act_swap[ 50] = {bit_act[ 50][7:0],bit_act[ 50][15:8]};
assign bit_act_swap[ 51] = {bit_act[ 51][7:0],bit_act[ 51][15:8]};
assign bit_act_swap[ 52] = {bit_act[ 52][7:0],bit_act[ 52][15:8]};
assign bit_act_swap[ 53] = {bit_act[ 53][7:0],bit_act[ 53][15:8]};
assign bit_act_swap[ 54] = {bit_act[ 54][7:0],bit_act[ 54][15:8]};
assign bit_act_swap[ 55] = {bit_act[ 55][7:0],bit_act[ 55][15:8]};
assign bit_act_swap[ 56] = {bit_act[ 56][7:0],bit_act[ 56][15:8]};
assign bit_act_swap[ 57] = {bit_act[ 57][7:0],bit_act[ 57][15:8]};
assign bit_act_swap[ 58] = {bit_act[ 58][7:0],bit_act[ 58][15:8]};
assign bit_act_swap[ 59] = {bit_act[ 59][7:0],bit_act[ 59][15:8]};
assign bit_act_swap[ 60] = {bit_act[ 60][7:0],bit_act[ 60][15:8]};
assign bit_act_swap[ 61] = {bit_act[ 61][7:0],bit_act[ 61][15:8]};
assign bit_act_swap[ 62] = {bit_act[ 62][7:0],bit_act[ 62][15:8]};
assign bit_act_swap[ 63] = {bit_act[ 63][7:0],bit_act[ 63][15:8]};
assign bit_act_swap[ 64] = {bit_act[ 64][7:0],bit_act[ 64][15:8]};
assign bit_act_swap[ 65] = {bit_act[ 65][7:0],bit_act[ 65][15:8]};
assign bit_act_swap[ 66] = {bit_act[ 66][7:0],bit_act[ 66][15:8]};
assign bit_act_swap[ 67] = {bit_act[ 67][7:0],bit_act[ 67][15:8]};
assign bit_act_swap[ 68] = {bit_act[ 68][7:0],bit_act[ 68][15:8]};
assign bit_act_swap[ 69] = {bit_act[ 69][7:0],bit_act[ 69][15:8]};
assign bit_act_swap[ 70] = {bit_act[ 70][7:0],bit_act[ 70][15:8]};
assign bit_act_swap[ 71] = {bit_act[ 71][7:0],bit_act[ 71][15:8]};
assign bit_act_swap[ 72] = {bit_act[ 72][7:0],bit_act[ 72][15:8]};
assign bit_act_swap[ 73] = {bit_act[ 73][7:0],bit_act[ 73][15:8]};
assign bit_act_swap[ 74] = {bit_act[ 74][7:0],bit_act[ 74][15:8]};
assign bit_act_swap[ 75] = {bit_act[ 75][7:0],bit_act[ 75][15:8]};
assign bit_act_swap[ 76] = {bit_act[ 76][7:0],bit_act[ 76][15:8]};
assign bit_act_swap[ 77] = {bit_act[ 77][7:0],bit_act[ 77][15:8]};
assign bit_act_swap[ 78] = {bit_act[ 78][7:0],bit_act[ 78][15:8]};
assign bit_act_swap[ 79] = {bit_act[ 79][7:0],bit_act[ 79][15:8]};
assign bit_act_swap[ 80] = {bit_act[ 80][7:0],bit_act[ 80][15:8]};
assign bit_act_swap[ 81] = {bit_act[ 81][7:0],bit_act[ 81][15:8]};
assign bit_act_swap[ 82] = {bit_act[ 82][7:0],bit_act[ 82][15:8]};
assign bit_act_swap[ 83] = {bit_act[ 83][7:0],bit_act[ 83][15:8]};
assign bit_act_swap[ 84] = {bit_act[ 84][7:0],bit_act[ 84][15:8]};
assign bit_act_swap[ 85] = {bit_act[ 85][7:0],bit_act[ 85][15:8]};
assign bit_act_swap[ 86] = {bit_act[ 86][7:0],bit_act[ 86][15:8]};
assign bit_act_swap[ 87] = {bit_act[ 87][7:0],bit_act[ 87][15:8]};
assign bit_act_swap[ 88] = {bit_act[ 88][7:0],bit_act[ 88][15:8]};
assign bit_act_swap[ 89] = {bit_act[ 89][7:0],bit_act[ 89][15:8]};
assign bit_act_swap[ 90] = {bit_act[ 90][7:0],bit_act[ 90][15:8]};
assign bit_act_swap[ 91] = {bit_act[ 91][7:0],bit_act[ 91][15:8]};
assign bit_act_swap[ 92] = {bit_act[ 92][7:0],bit_act[ 92][15:8]};
assign bit_act_swap[ 93] = {bit_act[ 93][7:0],bit_act[ 93][15:8]};
assign bit_act_swap[ 94] = {bit_act[ 94][7:0],bit_act[ 94][15:8]};
assign bit_act_swap[ 95] = {bit_act[ 95][7:0],bit_act[ 95][15:8]};
assign bit_act_swap[ 96] = {bit_act[ 96][7:0],bit_act[ 96][15:8]};
assign bit_act_swap[ 97] = {bit_act[ 97][7:0],bit_act[ 97][15:8]};
assign bit_act_swap[ 98] = {bit_act[ 98][7:0],bit_act[ 98][15:8]};
assign bit_act_swap[ 99] = {bit_act[ 99][7:0],bit_act[ 99][15:8]};
assign bit_act_swap[100] = {bit_act[100][7:0],bit_act[100][15:8]};
assign bit_act_swap[101] = {bit_act[101][7:0],bit_act[101][15:8]};
assign bit_act_swap[102] = {bit_act[102][7:0],bit_act[102][15:8]};
assign bit_act_swap[103] = {bit_act[103][7:0],bit_act[103][15:8]};
assign bit_act_swap[104] = {bit_act[104][7:0],bit_act[104][15:8]};
assign bit_act_swap[105] = {bit_act[105][7:0],bit_act[105][15:8]};
assign bit_act_swap[106] = {bit_act[106][7:0],bit_act[106][15:8]};
assign bit_act_swap[107] = {bit_act[107][7:0],bit_act[107][15:8]};
assign bit_act_swap[108] = {bit_act[108][7:0],bit_act[108][15:8]};
assign bit_act_swap[109] = {bit_act[109][7:0],bit_act[109][15:8]};
assign bit_act_swap[110] = {bit_act[110][7:0],bit_act[110][15:8]};
assign bit_act_swap[111] = {bit_act[111][7:0],bit_act[111][15:8]};
assign bit_act_swap[112] = {bit_act[112][7:0],bit_act[112][15:8]};
assign bit_act_swap[113] = {bit_act[113][7:0],bit_act[113][15:8]};
assign bit_act_swap[114] = {bit_act[114][7:0],bit_act[114][15:8]};
assign bit_act_swap[115] = {bit_act[115][7:0],bit_act[115][15:8]};
assign bit_act_swap[116] = {bit_act[116][7:0],bit_act[116][15:8]};
assign bit_act_swap[117] = {bit_act[117][7:0],bit_act[117][15:8]};
assign bit_act_swap[118] = {bit_act[118][7:0],bit_act[118][15:8]};
assign bit_act_swap[119] = {bit_act[119][7:0],bit_act[119][15:8]};
assign bit_act_swap[120] = {bit_act[120][7:0],bit_act[120][15:8]};
assign bit_act_swap[121] = {bit_act[121][7:0],bit_act[121][15:8]};
assign bit_act_swap[122] = {bit_act[122][7:0],bit_act[122][15:8]};
assign bit_act_swap[123] = {bit_act[123][7:0],bit_act[123][15:8]};
assign bit_act_swap[124] = {bit_act[124][7:0],bit_act[124][15:8]};
assign bit_act_swap[125] = {bit_act[125][7:0],bit_act[125][15:8]};
assign bit_act_swap[126] = {bit_act[126][7:0],bit_act[126][15:8]};
assign bit_act_swap[127] = {bit_act[127][7:0],bit_act[127][15:8]};



wire [127:0] bit_tcam_cfg [31:0];
//i_dp_tcam = 55555555000b00023000020001029f8a
//mirror 8a9f02010002003002000b0055555555
//8a9f020100 02 003002000b0055555555
//8a9f020100 0c 003002000b0055555555
//8a9f020100 3c 003002000b0055555555
//8a9f020100 5c 003002000b0055555555
//8a9f020100 4c 003002000b0055555555
//8a9f020100 44 003002000b0055555555
//8a9f020100 c4 003002000b0055555555
//与wireshark的TCAM表相同顺序
//buchongluoji,meiyoupipeishangdebaowenzenmezou
assign bit_tcam_cfg[ 0] = {128'h3c5620e082215555555555553c003c3c};//00000//8a9f020100 02 003002000b0055555555
assign bit_tcam_cfg[ 1] = {128'h0090843c820155555555555555555555};//10000   
assign bit_tcam_cfg[ 2] = {128'h8a9f0201003c003002000b0055555555};//addr11
assign bit_tcam_cfg[ 3] = {128'h8a9f0201005c003002000b0055555555};
assign bit_tcam_cfg[ 4] = {128'h8a9f0201004c003002000b0055555555};//addr02
assign bit_tcam_cfg[ 5] = {128'h8a9f02010044003002000b0055555555};
assign bit_tcam_cfg[ 6] = {128'h8a9f020100c4003002000b0055555555};
assign bit_tcam_cfg[ 7] = {128'h8a9f02010002003002000b0055555555};
assign bit_tcam_cfg[ 8] = {128'h8a9f0201000c003002000b0055555555};
assign bit_tcam_cfg[ 9] = {120'd10,8'b00000000};
assign bit_tcam_cfg[10] = {120'd11,8'b00000000};
assign bit_tcam_cfg[11] = {120'd12,8'b00000000};
assign bit_tcam_cfg[12] = {120'd13,8'b00000000};
assign bit_tcam_cfg[13] = {120'd14,8'b00000000};
assign bit_tcam_cfg[14] = {120'd15,8'b00000000};
assign bit_tcam_cfg[15] = {120'd16,8'b00000000};
assign bit_tcam_cfg[16] = {120'd17,8'b00000000};
assign bit_tcam_cfg[17] = {120'd18,8'b00000000};
assign bit_tcam_cfg[18] = {120'd19,8'b00000000};
assign bit_tcam_cfg[19] = {120'd20,8'b00000000};
assign bit_tcam_cfg[20] = {120'd21,8'b00000000};
assign bit_tcam_cfg[21] = {120'd22,8'b00000000};
assign bit_tcam_cfg[22] = {120'd23,8'b00000000};
assign bit_tcam_cfg[23] = {120'd24,8'b00000000};
assign bit_tcam_cfg[24] = {120'd25,8'b00000000};
assign bit_tcam_cfg[25] = {120'd26,8'b00000000};
assign bit_tcam_cfg[26] = {120'd27,8'b00000000};
assign bit_tcam_cfg[27] = {120'd28,8'b00000000};
assign bit_tcam_cfg[28] = {120'd29,8'b00000000};
assign bit_tcam_cfg[29] = {120'd30,8'b00000000};
assign bit_tcam_cfg[30] = {120'd31,8'b00000000};
assign bit_tcam_cfg[31] = {120'd32,8'b00000000};

//clk signal
always begin
    #(CYCLE/2) clk = ~clk;//100MHz
end

//reset signal
initial begin
    clk = 0;
    aresetn = 0;
    #(10);
    aresetn = 0; //reset all the values
    #(10);
    aresetn = 1;
end

/////////////////////////256bit//////////////////////////////////////////////////////////////
reg finish_txt;
integer i;
initial begin
    finish_txt = 1'b0;
    s_axis_tdata <= 256'b0;
    s_axis_tkeep <= 64'h0;
    s_axis_tuser <= 128'h0;
    s_axis_tvalid <= 1'b0;
    s_axis_tlast <= 1'b0;
    #(3*CYCLE+CYCLE/2);
    #(40* CYCLE)
    m_axis_tready <= 1'b1;
    s_axis_tdata <= 256'b0; 
    s_axis_tkeep <= 64'h0;
    s_axis_tuser <= 128'h0;
    s_axis_tvalid <= 1'b0;
    s_axis_tlast <= 1'b0;
    
    ////////////////////////////////////////////bit_cfg////////////////////////////////////  
    #(CYCLE);
    s_axis_tdata <= {256'h6f6fbc4c114000001a858e0000450008ff000081a66840486a3c888888888888};
    s_axis_tvalid <= 1'b1;
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tuser <= 128'h000000000000000000000000408000a0;
    s_axis_tlast <= 1'b0;
    #(CYCLE)
    // s_axis_tdata <= {256'h00000000000000000000000000000001000000007a00f2f13412dededede6f6f};
    s_axis_tdata <= {124'h0000000000000000000000000000000,vlan_id,8'h00,STAGE_ID4,BIT_CFG_MOD_ID,112'h00007a00f2f13412dededede6f6f};
    s_axis_tvalid <= 1'b1               ;
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tuser <= 128'b0              ;
    s_axis_tlast <= 1'b0                ;
    #(CYCLE)
    s_axis_tdata <= {
        bit_act_swap[15 ],bit_act_swap[14 ],bit_act_swap[13 ],bit_act_swap[12 ],
        bit_act_swap[11 ],bit_act_swap[10 ],bit_act_swap[9  ],bit_act_swap[8  ],
        bit_act_swap[7  ],bit_act_swap[6  ],bit_act_swap[5  ],bit_act_swap[4  ],
        bit_act_swap[3  ],bit_act_swap[2  ],bit_act_swap[1  ],bit_act_swap[0  ]
    };
    s_axis_tvalid <= 1'b1;
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tuser <= 128'b0;
    s_axis_tlast <= 1'b0;
     #(CYCLE)
    s_axis_tdata <= {
        bit_act_swap[31],bit_act_swap[30],bit_act_swap[29],bit_act_swap[28],
        bit_act_swap[27],bit_act_swap[26],bit_act_swap[25],bit_act_swap[24],
        bit_act_swap[23],bit_act_swap[22],bit_act_swap[21],bit_act_swap[20],
        bit_act_swap[19],bit_act_swap[18],bit_act_swap[17],bit_act_swap[16]
    };
    s_axis_tvalid <= 1'b1;
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tuser <= 128'b0;
    s_axis_tlast <= 1'b1;
    // #(CYCLE)
    // s_axis_tdata <= {
    //     bit_act_swap[47],bit_act_swap[46],bit_act_swap[45],bit_act_swap[44],
    //     bit_act_swap[43],bit_act_swap[42],bit_act_swap[41],bit_act_swap[40],
    //     bit_act_swap[39],bit_act_swap[38],bit_act_swap[37],bit_act_swap[36],
    //     bit_act_swap[35],bit_act_swap[34],bit_act_swap[33],bit_act_swap[32]
    // };
    // s_axis_tvalid <= 1'b1;
    // s_axis_tkeep <= 64'hffffffffffffffff;
    // s_axis_tuser <= 128'b0;
    // s_axis_tlast <= 1'b0;
    // #(CYCLE)
    // s_axis_tdata <= {
    //     bit_act_swap[63],bit_act_swap[62],bit_act_swap[61],bit_act_swap[60],
    //     bit_act_swap[59],bit_act_swap[58],bit_act_swap[57],bit_act_swap[56],
    //     bit_act_swap[55],bit_act_swap[54],bit_act_swap[53],bit_act_swap[52],
    //     bit_act_swap[51],bit_act_swap[50],bit_act_swap[49],bit_act_swap[48]
    // };
    // s_axis_tvalid <= 1'b1;
    // s_axis_tkeep <= 64'hffffffffffffffff;
    // s_axis_tuser <= 128'b0;
    // s_axis_tlast <= 1'b0;
    // #(CYCLE)
    // s_axis_tdata <= {
    //     bit_act_swap[79],bit_act_swap[78],bit_act_swap[77],bit_act_swap[76],
    //     bit_act_swap[75],bit_act_swap[74],bit_act_swap[73],bit_act_swap[72],
    //     bit_act_swap[71],bit_act_swap[70],bit_act_swap[69],bit_act_swap[68],
    //     bit_act_swap[67],bit_act_swap[66],bit_act_swap[65],bit_act_swap[64]
    // };
    // s_axis_tvalid <= 1'b1;
    // s_axis_tkeep <= 64'hffffffffffffffff;
    // s_axis_tuser <= 128'b0;
    // s_axis_tlast <= 1'b0;
    // #(CYCLE)
    // s_axis_tdata <= {
    //     bit_act_swap[95],bit_act_swap[94],bit_act_swap[93],bit_act_swap[92],
    //     bit_act_swap[91],bit_act_swap[90],bit_act_swap[89],bit_act_swap[88],
    //     bit_act_swap[87],bit_act_swap[86],bit_act_swap[85],bit_act_swap[84],
    //     bit_act_swap[83],bit_act_swap[82],bit_act_swap[81],bit_act_swap[80]
    // };
    // s_axis_tvalid <= 1'b1;
    // s_axis_tkeep <= 64'hffffffffffffffff;
    // s_axis_tuser <= 128'b0;
    // s_axis_tlast <= 1'b0;
    // #(CYCLE)
    // s_axis_tdata <= {
    //     bit_act_swap[111],bit_act_swap[110],bit_act_swap[109],bit_act_swap[108],
    //     bit_act_swap[107],bit_act_swap[106],bit_act_swap[105],bit_act_swap[104],
    //     bit_act_swap[103],bit_act_swap[102],bit_act_swap[101],bit_act_swap[100],
    //     bit_act_swap[99] ,bit_act_swap[98] ,bit_act_swap[97] ,bit_act_swap[96]
    // };
    // s_axis_tvalid <= 1'b1;
    // s_axis_tkeep <= 64'hffffffffffffffff;
    // s_axis_tuser <= 128'b0;
    // s_axis_tlast <= 1'b0;
    //  #(CYCLE)
    // s_axis_tdata <= {
    //     bit_act_swap[127],bit_act_swap[126],bit_act_swap[125],bit_act_swap[124],
    //     bit_act_swap[123],bit_act_swap[122],bit_act_swap[121],bit_act_swap[120],
    //     bit_act_swap[119],bit_act_swap[118],bit_act_swap[117],bit_act_swap[116],
    //     bit_act_swap[115],bit_act_swap[114],bit_act_swap[113],bit_act_swap[112]
    // };
    // s_axis_tvalid <= 1'b1;
    // s_axis_tkeep <= 64'hffffffffffffffff;
    // s_axis_tuser <= 128'b0;
    // s_axis_tlast <= 1'b1;
    #(CYCLE)
    s_axis_tdata <= 256'd0;
    s_axis_tvalid <= 1'b0;
    s_axis_tkeep <= 64'h0;
    s_axis_tuser <= 128'b0;
    s_axis_tlast <= 1'b0;
    #(20*CYCLE)
/////////////////////////////////////////////bit_tcam_cfg//////////////////////////////////////
    #(CYCLE);
    s_axis_tdata <= {256'h6f6fbc4c114000001a858e0000450008ff000081a66840486a3c888888888888};
    s_axis_tvalid <= 1'b1;
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tuser <= 128'h000000000000000000000000408000a0;
    s_axis_tlast <= 1'b0;
    #(CYCLE)
    // s_axis_tdata <= {256'h00000000000000000000000000000001000000007a00f2f13412dededede6f6f};
    s_axis_tdata <= {124'h0000000000000000000000000000000,vlan_id,8'h00,STAGE_ID4,BIT_TCAM_MOD_ID,112'h00007a00f2f13412dededede6f6f};
    s_axis_tvalid <= 1'b1               ;
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tuser <= 128'b0              ;
    s_axis_tlast <= 1'b0                ;
    #(CYCLE)
    s_axis_tdata <= {
        bit_tcam_mask[0],128'd0
    };
    s_axis_tvalid <= 1'b1;
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tuser <= 128'b0;
    s_axis_tlast <= 1'b0;
     #(CYCLE)
    s_axis_tdata <= {
        bit_tcam_cfg[1],bit_tcam_cfg[0]
    };
    s_axis_tvalid <= 1'b1;
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tuser <= 128'b0;
    s_axis_tlast <= 1'b0;
    #(CYCLE)
    s_axis_tdata <= {
        bit_tcam_cfg[3],bit_tcam_cfg[2]
    };
    s_axis_tvalid <= 1'b1;
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tuser <= 128'b0;
    s_axis_tlast <= 1'b0;
    #(CYCLE)
    s_axis_tdata <= {
        bit_tcam_cfg[5],bit_tcam_cfg[4]
    };
    s_axis_tvalid <= 1'b1;
    s_axis_tkeep <= 64'h0;
    s_axis_tuser <= 128'b0;
    s_axis_tlast <= 1'b0;
    #(CYCLE)
    s_axis_tdata <= {
        bit_tcam_cfg[7],bit_tcam_cfg[6]
    };
    s_axis_tvalid <= 1'b1;
    s_axis_tkeep <= 64'h0;
    s_axis_tuser <= 128'b0;
    s_axis_tlast <= 1'b0;
    #(CYCLE)
    s_axis_tdata <= {
        bit_tcam_cfg[9],bit_tcam_cfg[8]
    };
    s_axis_tvalid <= 1'b1;
    s_axis_tkeep <= 64'h0;
    s_axis_tuser <= 128'b0;
    s_axis_tlast <= 1'b0;
    #(CYCLE)
    s_axis_tdata <= {
        bit_tcam_cfg[11],bit_tcam_cfg[10]
    };
    s_axis_tvalid <= 1'b1;
    s_axis_tkeep <= 64'h0;
    s_axis_tuser <= 128'b0;
    s_axis_tlast <= 1'b0;
    #(CYCLE)
    s_axis_tdata <= {
        bit_tcam_cfg[13],bit_tcam_cfg[12]
    };
    s_axis_tvalid <= 1'b1;
    s_axis_tkeep <= 64'h0;
    s_axis_tuser <= 128'b0;
    s_axis_tlast <= 1'b0;
    #(CYCLE)
    s_axis_tdata <= {
        bit_tcam_cfg[15],bit_tcam_cfg[14]
    };
    s_axis_tvalid <= 1'b1;
    s_axis_tkeep <= 64'h0;
    s_axis_tuser <= 128'b0;
    s_axis_tlast <= 1'b0;
    #(CYCLE)
    s_axis_tdata <= {
        bit_tcam_cfg[17],bit_tcam_cfg[16]
    };
    s_axis_tvalid <= 1'b1;
    s_axis_tkeep <= 64'h0;
    s_axis_tuser <= 128'b0;
    s_axis_tlast <= 1'b0;
    #(CYCLE)
    s_axis_tdata <= {
        bit_tcam_cfg[19],bit_tcam_cfg[18]
    };
    s_axis_tvalid <= 1'b1;
    s_axis_tkeep <= 64'h0;
    s_axis_tuser <= 128'b0;
    s_axis_tlast <= 1'b0;
    #(CYCLE)
    s_axis_tdata <= {
        bit_tcam_cfg[21],bit_tcam_cfg[20]
    };
    s_axis_tvalid <= 1'b1;
    s_axis_tkeep <= 64'h0;
    s_axis_tuser <= 128'b0;
    s_axis_tlast <= 1'b0;
    #(CYCLE)
    s_axis_tdata <= {
        bit_tcam_cfg[23],bit_tcam_cfg[22]
    };
    s_axis_tvalid <= 1'b1;
    s_axis_tkeep <= 64'h0;
    s_axis_tuser <= 128'b0;
    s_axis_tlast <= 1'b0;
    #(CYCLE)
    s_axis_tdata <= {
        bit_tcam_cfg[25],bit_tcam_cfg[24]
    };
    s_axis_tvalid <= 1'b1;
    s_axis_tkeep <= 64'h0;
    s_axis_tuser <= 128'b0;
    s_axis_tlast <= 1'b0;
    #(CYCLE)
    s_axis_tdata <= {
        bit_tcam_cfg[27],bit_tcam_cfg[26]
    };
    s_axis_tvalid <= 1'b1;
    s_axis_tkeep <= 64'h0;
    s_axis_tuser <= 128'b0;
    s_axis_tlast <= 1'b0;
    #(CYCLE)
    s_axis_tdata <= {
        bit_tcam_cfg[29],bit_tcam_cfg[28]
    };
    s_axis_tvalid <= 1'b1;
    s_axis_tkeep <= 64'h0;
    s_axis_tuser <= 128'b0;
    s_axis_tlast <= 1'b0;
    #(CYCLE)
    s_axis_tdata <= {
        bit_tcam_cfg[31],bit_tcam_cfg[30]
    };
    s_axis_tvalid <= 1'b1;
    s_axis_tkeep <= 64'h0;
    s_axis_tuser <= 128'b0;
    s_axis_tlast <= 1'b1;
    #(CYCLE)
    s_axis_tdata <= 256'd0;
    s_axis_tvalid <= 1'b0;
    s_axis_tkeep <= 64'h0;
    s_axis_tuser <= 128'b0;
    s_axis_tlast <= 1'b0;
    #(20*CYCLE)

///////////////////////////////////////////////////parser:2^9=511////////////////////////////////////  
    
        #(CYCLE);
        s_axis_tdata <= {256'h6f6fbc4c114000001a858e0000450008ff000081a66840486a3c888888888888};
        s_axis_tvalid <= 1'b1;
        s_axis_tkeep <= 64'hffffffffffffffff;
        s_axis_tuser <= 128'h000000000000000000000000408000a0;
        s_axis_tlast <= 1'b0;
        #(CYCLE)
        // s_axis_tdata <= {256'h00000000000000000000000000000001000000007a00f2f13412dededede6f6f};
        s_axis_tdata <= {124'h0000000000000000000000000000000,vlan_id,8'h00,STAGE_ID0,PARSER_MOD_ID,112'h00007a00f2f13412dededede6f6f};
        s_axis_tvalid <= 1'b1;
        s_axis_tkeep <= 64'hffffffffffffffff;
        s_axis_tuser <= 128'b0;
        s_axis_tlast <= 1'b0;

    for(i=0;i<7;i= i+1) begin //parser_cfg
        #(CYCLE)
        s_axis_tdata <= parser_table1[i];
        s_axis_tvalid <= 1'b1;
        s_axis_tkeep <= 64'hffffffffffffffff;
        s_axis_tuser <= 128'b0;
        s_axis_tlast <= 1'b0;

         #(CYCLE)
        s_axis_tdata <= parser_table2[i];
        s_axis_tvalid <= 1'b1;
        s_axis_tkeep <= 64'hffffffffffffffff;
        s_axis_tuser <= 128'b0;
        s_axis_tlast <= 1'b0;
    end
        
        #(CYCLE)
        s_axis_tdata <= 256'd0;
        s_axis_tvalid <= 1'b1;
        s_axis_tkeep <= 64'hffffffffffffffff;
        s_axis_tuser <= 128'b0;
        s_axis_tlast <= 1'b1;
        #(CYCLE)
        s_axis_tdata <= 256'd0;
        s_axis_tvalid <= 1'b0;
        s_axis_tkeep <= 64'hffffffffffffffff;
        s_axis_tuser <= 128'b0;
        s_axis_tlast <= 1'b1;
        #(20*CYCLE);
    

//////////deparser/////////////////////
    s_axis_tdata <= {256'h6f6fbc4c114000001a858e0000450008ff000081a66840486a3c888888888888};
    s_axis_tvalid <= 1'b1;
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tuser <= 128'h000000000000000000000000408000a0;
    s_axis_tlast <= 1'b0;
    #(CYCLE)
    // s_axis_tdata <= {256'h00000000000000000000000000000001000500007a00f2f13412dededede6f6f};
    s_axis_tdata <= {124'h0000000000000000000000000000000,vlan_id,128'h000500007a00f2f13412dededede6f6f};
    s_axis_tvalid <= 1'b1;
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tuser <= 128'b0;
    s_axis_tlast <= 1'b0;

    for(i=0;i<7;i= i+1) begin //parser_cfg
        #(CYCLE)
        s_axis_tdata <= parser_table1[i];
        s_axis_tvalid <= 1'b1;
        s_axis_tkeep <= 64'hffffffffffffffff;
        s_axis_tuser <= 128'b0;
        s_axis_tlast <= 1'b0;

        #(CYCLE)
        s_axis_tdata <= parser_table2[i];
        s_axis_tvalid <= 1'b1;
        s_axis_tkeep <= 64'hffffffffffffffff;
        s_axis_tuser <= 128'b0;
        s_axis_tlast <= 1'b0;
end
 #(CYCLE)
        s_axis_tdata <= 256'd0;
        s_axis_tvalid <= 1'b1;
        s_axis_tkeep <= 64'hffffffffffffffff;
        s_axis_tuser <= 128'b0;
        s_axis_tlast <= 1'b1;
 #(CYCLE)
        s_axis_tdata <= 256'd0;
        s_axis_tvalid <= 1'b0;
        s_axis_tkeep <= 64'hffffffffffffffff;
        s_axis_tuser <= 128'b0;
        s_axis_tlast <= 1'b1;
    #(20*CYCLE);

    ////////////2048 bit-1///////////////
    //SCAPY
    #(CYCLE)
    s_axis_tdata <= 256'ha8c0a921111700000100ee000045000801000081da54be486a3ca66840486a3c;//0-3
    s_axis_tuser <= {128'h0000000000000000000000004080007e};
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tvalid <= 1'b1;
    s_axis_tlast <= 1'b0;
     #(CYCLE)
    s_axis_tdata <= 256'h100f0e0d0c0b0a09080706050403020100003e8cda00a05b39300200a8c00300;//0-3
    s_axis_tuser <= {128'h0000000000000000000000004080007e};
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tvalid <= 1'b1;
    s_axis_tlast <= 1'b0;
    #(CYCLE)
    s_axis_tdata <= 256'h100f0e0d0c0b0a09080706050403020100003e8cda00a05b39300200a8c00300;//0-3
    s_axis_tuser <= {128'h0000000000000000000000004080007e};
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tvalid <= 1'b0;
    s_axis_tlast <= 1'b0;
    #(CYCLE)
    s_axis_tdata <= 256'h100f0e0d0c0b0a09080706050403020100003e8cda00a05b39300200a8c00300;//0-3
    s_axis_tuser <= {128'h0000000000000000000000004080007e};
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tvalid <= 1'b0;
    s_axis_tlast <= 1'b0;
    #(CYCLE)
    s_axis_tdata <= 256'h100f0e0d0c0b0a09080706050403020100003e8cda00a05b39300200a8c00300;//0-3
    s_axis_tuser <= {128'h0000000000000000000000004080007e};
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tvalid <= 1'b0;
    s_axis_tlast <= 1'b0;
     #(CYCLE)
    s_axis_tdata <= 256'h302f2e2d2c2b2a292827262524232221201f1e1d1c1b1a191817161514131211;//0-3
    s_axis_tuser <= {128'h0000000000000000000000004080007e};
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tvalid <= 1'b1;
    s_axis_tlast <= 1'b0;
    #(CYCLE)
    s_axis_tdata <= 256'h302f2e2d2c2b2a292827262524232221201f1e1d1c1b1a191817161514131211;//0-3
    s_axis_tuser <= {128'h0000000000000000000000004080007e};
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tvalid <= 1'b0;
    s_axis_tlast <= 1'b0;
    #(CYCLE)
    s_axis_tdata <= 256'h302f2e2d2c2b2a292827262524232221201f1e1d1c1b1a191817161514131211;//0-3
    s_axis_tuser <= {128'h0000000000000000000000004080007e};
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tvalid <= 1'b0;
    s_axis_tlast <= 1'b0;
    #(CYCLE)
    s_axis_tdata <= 256'h302f2e2d2c2b2a292827262524232221201f1e1d1c1b1a191817161514131211;//0-3
    s_axis_tuser <= {128'h0000000000000000000000004080007e};
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tvalid <= 1'b0;
    s_axis_tlast <= 1'b0;
     #(CYCLE)
    s_axis_tdata <= 256'h504f4e4d4c4b4a494847464544434241403f3e3d3c3b3a393837363534333231;//0-3
    s_axis_tuser <= {128'h0000000000000000000000004080007e};
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tvalid <= 1'b1;
    s_axis_tlast <= 1'b0;
    #(CYCLE)
    s_axis_tdata <= 256'h504f4e4d4c4b4a494847464544434241403f3e3d3c3b3a393837363534333231;//0-3
    s_axis_tuser <= {128'h0000000000000000000000004080007e};
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tvalid <= 1'b0;
    s_axis_tlast <= 1'b0;
    #(CYCLE)
    s_axis_tdata <= 256'h504f4e4d4c4b4a494847464544434241403f3e3d3c3b3a393837363534333231;//0-3
    s_axis_tuser <= {128'h0000000000000000000000004080007e};
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tvalid <= 1'b0;
    s_axis_tlast <= 1'b0;
    #(CYCLE)
    s_axis_tdata <= 256'h504f4e4d4c4b4a494847464544434241403f3e3d3c3b3a393837363534333231;//0-3
    s_axis_tuser <= {128'h0000000000000000000000004080007e};
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tvalid <= 1'b0;
    s_axis_tlast <= 1'b0;
     #(CYCLE)
    s_axis_tdata <= 256'h706f6e6d6c6b6a696867666564636261605f5e5d5c5b5a595857565554535251;//0-3
    s_axis_tuser <= {128'h0000000000000000000000004080007e};
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tvalid <= 1'b1;
    s_axis_tlast <= 1'b0;
       #(CYCLE)
    s_axis_tdata <= 256'h706f6e6d6c6b6a696867666564636261605f5e5d5c5b5a595857565554535251;//0-3
    s_axis_tuser <= {128'h0000000000000000000000004080007e};
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tvalid <= 1'b0;
    s_axis_tlast <= 1'b0;
        #(CYCLE)
    s_axis_tdata <= 256'h706f6e6d6c6b6a696867666564636261605f5e5d5c5b5a595857565554535251;//0-3
    s_axis_tuser <= {128'h0000000000000000000000004080007e};
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tvalid <= 1'b0;
    s_axis_tlast <= 1'b0;
        #(CYCLE)
    s_axis_tdata <= 256'h706f6e6d6c6b6a696867666564636261605f5e5d5c5b5a595857565554535251;//0-3
    s_axis_tuser <= {128'h0000000000000000000000004080007e};
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tvalid <= 1'b0;
    s_axis_tlast <= 1'b0;
     #(CYCLE)
    s_axis_tdata <= 256'h908f8e8d8c8b8a898887868584838281807f7e7d7c7b7a797877767574737271;//0-3
    s_axis_tuser <= {128'h0000000000000000000000004080007e};
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tvalid <= 1'b1;
    s_axis_tlast <= 1'b0;
         #(CYCLE)
    s_axis_tdata <= 256'h908f8e8d8c8b8a898887868584838281807f7e7d7c7b7a797877767574737271;//0-3
    s_axis_tuser <= {128'h0000000000000000000000004080007e};
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tvalid <= 1'b0;
    s_axis_tlast <= 1'b0;
         #(CYCLE)
    s_axis_tdata <= 256'h908f8e8d8c8b8a898887868584838281807f7e7d7c7b7a797877767574737271;//0-3
    s_axis_tuser <= {128'h0000000000000000000000004080007e};
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tvalid <= 1'b0;
    s_axis_tlast <= 1'b0;
         #(CYCLE)
    s_axis_tdata <= 256'h908f8e8d8c8b8a898887868584838281807f7e7d7c7b7a797877767574737271;//0-3
    s_axis_tuser <= {128'h0000000000000000000000004080007e};
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tvalid <= 1'b0;
    s_axis_tlast <= 1'b0;
    #(CYCLE)
    s_axis_tdata <= 256'h908f8e8d8c8b8a898887868584838281a09f9e9d9c9b9a999897969594939291;//0-3
    s_axis_tuser <= {128'h0000000000000000000000004080007e};
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tvalid <= 1'b1;
    s_axis_tlast <= 1'b0;
        #(CYCLE)
    s_axis_tdata <= 256'h908f8e8d8c8b8a898887868584838281a09f9e9d9c9b9a999897969594939291;//0-3
    s_axis_tuser <= {128'h0000000000000000000000004080007e};
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tvalid <= 1'b0;
    s_axis_tlast <= 1'b0;
            #(CYCLE)
    s_axis_tdata <= 256'h908f8e8d8c8b8a898887868584838281a09f9e9d9c9b9a999897969594939291;//0-3
    s_axis_tuser <= {128'h0000000000000000000000004080007e};
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tvalid <= 1'b0;
    s_axis_tlast <= 1'b0;
            #(CYCLE)
    s_axis_tdata <= 256'h908f8e8d8c8b8a898887868584838281a09f9e9d9c9b9a999897969594939291;//0-3
    s_axis_tuser <= {128'h0000000000000000000000004080007e};
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tvalid <= 1'b0;
    s_axis_tlast <= 1'b0;
    #(CYCLE)
    s_axis_tdata <= 256'h504f4e4d4c4b4a494847464544434241a09f9e9d9c9b9a999897969594939291;//0-3
    s_axis_tuser <= {128'h0000000000000000000000004080007e};
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tvalid <= 1'b1;
    s_axis_tlast <= 1'b1;
    #(CYCLE)
    s_axis_tdata <= 256'h908f8e8d8c8b8a898887868584838281807f7e7d7c7b7a797877767574737271;//0-3
    s_axis_tuser <= {128'h0000000000000000000000004080007e};
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tvalid <= 1'b0;
    s_axis_tlast <= 1'b1;
    /////////////////////////////////////////////////////////////////////
    // 192.168.0.2 to 255.255.255.0
    // #(10*CYCLE)
    
    // s_axis_tdata <= 256'ha8c00200a8c0e677114000409140240000450008da54be486a3cffffffffffff;//0-3
    // s_axis_tuser <= {128'h0000000000000000000000004080007e};
    // s_axis_tkeep <= 64'hffffffffffffffff;
    // s_axis_tvalid <= 1'b1;
    // s_axis_tlast <= 1'b0;
    // #(CYCLE)
    // s_axis_tdata <= 256'h000000043246435473821000fe05b5a5ff000000000000000000000000000000;//0-3
    // s_axis_tuser <= {128'h0000000000000000000000004080007e};
    // s_axis_tkeep <= 64'hffffffffffffffff;
    // s_axis_tvalid <= 1'b1;
    // s_axis_tlast <= 1'b1;
    // #(CYCLE)
    // s_axis_tdata <= 256'h908f8e8d8c8b8a898887868584838281807f7e7d7c7b7a797877767574737271;//0-3
    // s_axis_tuser <= {128'h0000000000000000000000004080007e};
    // s_axis_tkeep <= 64'hffffffffffffffff;
    // s_axis_tvalid <= 1'b0;
    // s_axis_tlast <= 1'b1;;//0-3

    // #(50*CYCLE)
    // // s_axis_tdata <= {256'h000000000000000000004011480000000060dd8603454d555302224433221100};
    // s_axis_tdata <= {132'h0000000000004011460000000060dd86,4'd0,vlan_id,120'h00008101454d555302224433221100};//0-3
    // s_axis_tuser <= {128'h0000000000000000000000004080007e};
    // s_axis_tkeep <= 64'hffffffffffffffff;
    // s_axis_tvalid <= 1'b1;
    // s_axis_tlast <= 1'b0;
    // #(CYCLE)
    // // s_axis_tdata <= {256'h000000000000000000004011480000000060dd8603454d555302224433221100};
    // s_axis_tdata <= {132'h0000000000004011460000000060dd86,4'd0,vlan_id,120'h00008101454d555302224433221100};//0-3
    // s_axis_tuser <= {128'h0000000000000000000000004080007e};
    // s_axis_tkeep <= 64'hffffffffffffffff;
    // s_axis_tvalid <= 1'b0;
    // s_axis_tlast <= 1'b0;
    // #(CYCLE)
    // s_axis_tdata <= {256'h4600d5ddea000200000000000000000000000000000001000000000000000000};//4-7
    // s_axis_tuser <= 128'b0;
    // s_axis_tkeep <= 64'hffffffffffffffff;
    // s_axis_tvalid <= 1'b1;
    // s_axis_tlast <= 1'b0;
    // #(CYCLE)
    // s_axis_tdata <= {256'h4600d5ddea000200000000000000000000000000000001000000000000000000};//4-7
    // s_axis_tuser <= 128'b0;
    // s_axis_tkeep <= 64'hffffffffffffffff;
    // s_axis_tvalid <= 1'b0;
    // s_axis_tlast <= 1'b0;
    // #(CYCLE)
    // s_axis_tdata <= {256'h0000000000000000000000002108251d00000000000000000000000000009320};//8-11
    // s_axis_tuser <= {115'b0,12'b0000_0000_0000,1'b0};
    // s_axis_tkeep <= 64'hffffffffffffffff;
    // s_axis_tvalid <= 1'b1;
    // s_axis_tlast <= 1'b0;
    // #(CYCLE)
    // s_axis_tdata <= {256'h0000000000000000000000002108251d00000000000000000000000000009320};//8-11
    // s_axis_tuser <= {115'b0,12'b0000_0000_0000,1'b0};
    // s_axis_tkeep <= 64'hffffffffffffffff;
    // s_axis_tvalid <= 1'b0;
    // s_axis_tlast <= 1'b0;
    // #(CYCLE)
    // s_axis_tdata <= {256'h201f1e1d1c1b1a191817161514131211100f0e0d0c0b0a090807060504030201};//12-15
    // s_axis_tuser <= 128'h0;
    // s_axis_tkeep <= 64'hffffffffffffffff;
    // s_axis_tvalid <= 1'b1;
    // s_axis_tlast <= 1'b0;
    // #(CYCLE)
    // s_axis_tdata <= {256'h201f1e1d1c1b1a191817161514131211100f0e0d0c0b0a090807060504030201};//12-15
    // s_axis_tuser <= 128'h0;
    // s_axis_tkeep <= 64'hffffffffffffffff;
    // s_axis_tvalid <= 1'b0;
    // s_axis_tlast <= 1'b0;
    // #(CYCLE)
    // s_axis_tdata <= {256'h403f3e3d3c3b3a393837363534333231302f2e2d2c2b2a292827262524232221};//16-19
    // s_axis_tuser <= 128'h0;
    // s_axis_tkeep <= 64'hffffffffffffffff;
    // s_axis_tvalid <= 1'b1;
    // s_axis_tlast <= 1'b0;
    // #(CYCLE)
    // s_axis_tdata <= {256'h403f3e3d3c3b3a393837363534333231302f2e2d2c2b2a292827262524232221};//16-19
    // s_axis_tuser <= 128'h0;
    // s_axis_tkeep <= 64'hffffffffffffffff;
    // s_axis_tvalid <= 1'b0;
    // s_axis_tlast <= 1'b0;
    // #(CYCLE)
    // s_axis_tdata <= {256'h605f5e5d5c5b5a595857565554535251504f4e4d4c4b4a494847464544434241};//20-23
    // s_axis_tuser <= 128'h0;
    // s_axis_tkeep <= 64'hffffffffffffffff;
    // s_axis_tvalid <= 1'b1;
    // s_axis_tlast <= 1'b0;
    // #(CYCLE)
    // s_axis_tdata <= {256'h605f5e5d5c5b5a595857565554535251504f4e4d4c4b4a494847464544434241};//20-23
    // s_axis_tuser <= 128'h0;
    // s_axis_tkeep <= 64'hffffffffffffffff;
    // s_axis_tvalid <= 1'b0;
    // s_axis_tlast <= 1'b0;
    // // #(CYCLE)
    // // s_axis_tdata <= {256'h807f7e7d7c7b7a797877767574737271706f6e6d6c6b6a696867666564636261};//24-27
    // // s_axis_tuser <= 128'h0;
    // // s_axis_tkeep <= 64'hffffffffffffffff;
    // // s_axis_tvalid <= 1'b1;
    // // s_axis_tlast <= 1'b0;
    // #(CYCLE)
    // s_axis_tdata <= {256'h807f7e7d7c7b7a797877767574737271706f6e6d6c6b6a696867666564636261};//24-27
    // s_axis_tuser <= 128'h0;
    // s_axis_tkeep <= 64'hffffffffffffffff;
    // s_axis_tvalid <= 1'b0;
    // s_axis_tlast <= 1'b0;
    // #(CYCLE)
    // s_axis_tdata <= {256'ha09f9e9d9c9b9a999897969594939291908f8e8d8c8b8a898887868584838281};//28-31
    // s_axis_tuser <= 128'h0;
    // s_axis_tkeep <= 64'hffffffffffffffff;
    // s_axis_tvalid <= 1'b1;
    // s_axis_tlast <= 1'b0;
    // #(CYCLE)
    // s_axis_tdata <= {256'ha09f9e9d9c9b9a999897969594939291908f8e8d8c8b8a898887868584838281};//28-31
    // s_axis_tuser <= 128'h0;
    // s_axis_tkeep <= 64'hffffffffffffffff;
    // s_axis_tvalid <= 1'b0;
    // s_axis_tlast <= 1'b0;
    // #(CYCLE)
    // s_axis_tdata <= {256'ha09f9e9d9c9b9a999897969594939291908f8e8d8c8b8a898887868584838281};//28-31
    // s_axis_tuser <= 128'h0;
    // s_axis_tkeep <= 64'hffffffffffffffff;
    // s_axis_tvalid <= 1'b0;
    // s_axis_tlast <= 1'b0;

    // ////////////2048 bit-2///////////////
    // #(CYCLE)
    // // s_axis_tdata <= {256'h000000000000000000004011480000000060dd8603454d555302224433221100};
    // s_axis_tdata <= {132'h0000000000004011460000000060dd86,4'd0,vlan_id,120'h000081445566778899aabbccddeeff};
    // s_axis_tuser <= {128'h0000000000000000000000004080007e};
    // s_axis_tkeep <= 64'hffffffffffffffff;
    // s_axis_tvalid <= 1'b1;
    // s_axis_tlast <= 1'b0;
    // #(CYCLE)
    // // s_axis_tdata <= {256'h000000000000000000004011480000000060dd8603454d555302224433221100};
    // s_axis_tdata <= {132'h0000000000004011460000000060dd86,4'd0,vlan_id,120'h000081445566778899aabbccddeeff};
    // s_axis_tuser <= {128'h0000000000000000000000004080007e};
    // s_axis_tkeep <= 64'hffffffffffffffff;
    // s_axis_tvalid <= 1'b0;
    // s_axis_tlast <= 1'b0;
    // #(CYCLE)
    // s_axis_tdata <= {256'h4600d5ddea000200000000000000000000000000070504000000000000000000};
    // s_axis_tuser <= 128'b0;
    // s_axis_tkeep <= 64'hffffffffffffffff;
    // s_axis_tvalid <= 1'b1;
    // s_axis_tlast <= 1'b0;
    // #(CYCLE)
    // s_axis_tdata <= {256'h4600d5ddea000200000000000000000000000000000001000000000000000000};
    // s_axis_tuser <= 128'b0;
    // s_axis_tkeep <= 64'hffffffffffffffff;
    // s_axis_tvalid <= 1'b0;
    // s_axis_tlast <= 1'b0;
    // #(CYCLE)
    // s_axis_tdata <= {256'h0000000000000000000000002108251d00000000000000000000000000009320};
    // s_axis_tuser <= {115'b0,12'b0000_0000_0000,1'b0};
    // s_axis_tkeep <= 64'hffffffffffffffff;
    // s_axis_tvalid <= 1'b1;
    // s_axis_tlast <= 1'b0;
    // #(CYCLE)
    // s_axis_tdata <= {256'h0000000000000000000000002108251d00000000000000000000000000009320};
    // s_axis_tuser <= {115'b0,12'b0000_0000_0000,1'b0};
    // s_axis_tkeep <= 64'hffffffffffffffff;
    // s_axis_tvalid <= 1'b0;
    // s_axis_tlast <= 1'b0;
    // #(CYCLE)
    // s_axis_tdata <= {256'h201f1e1d1c1b1a191817161514131211100f0e0d0c0b0a090807060504030201};
    // s_axis_tuser <= 128'h0;
    // s_axis_tkeep <= 64'hffffffffffffffff;
    // s_axis_tvalid <= 1'b1;
    // s_axis_tlast <= 1'b0;
    // #(CYCLE)
    // s_axis_tdata <= {256'h201f1e1d1c1b1a191817161514131211100f0e0d0c0b0a090807060504030201};
    // s_axis_tuser <= 128'h0;
    // s_axis_tkeep <= 64'hffffffffffffffff;
    // s_axis_tvalid <= 1'b0;
    // s_axis_tlast <= 1'b0;
    // #(CYCLE)
    // s_axis_tdata <= {256'h403f3e3d3c3b3a393837363534333231302f2e2d2c2b2a292827262524232221};
    // s_axis_tuser <= 128'h0;
    // s_axis_tkeep <= 64'hffffffffffffffff;
    // s_axis_tvalid <= 1'b1;
    // s_axis_tlast <= 1'b0;
    // #(CYCLE)
    // s_axis_tdata <= {256'h403f3e3d3c3b3a393837363534333231302f2e2d2c2b2a292827262524232221};
    // s_axis_tuser <= 128'h0;
    // s_axis_tkeep <= 64'hffffffffffffffff;
    // s_axis_tvalid <= 1'b0;
    // s_axis_tlast <= 1'b0;
    // #(CYCLE)
    // s_axis_tdata <= {8'd1,240'd0,8'd1};
    // s_axis_tuser <= 128'h0;
    // s_axis_tkeep <= 64'hffffffffffffffff;
    // s_axis_tvalid <= 1'b1;
    // s_axis_tlast <= 1'b0;
    // #(CYCLE)
    // s_axis_tdata <= {8'd1,240'd0,8'd1};
    // s_axis_tuser <= 128'h0;
    // s_axis_tkeep <= 64'hffffffffffffffff;
    // s_axis_tvalid <= 1'b0;
    // s_axis_tlast <= 1'b0;
    // #(CYCLE)
    // s_axis_tdata <= {8'd2,240'd0,8'd2};
    // s_axis_tuser <= 128'h0;
    // s_axis_tkeep <= 64'hffffffffffffffff;
    // s_axis_tvalid <= 1'b1;
    // s_axis_tlast <= 1'b0;
    // #(CYCLE)
    // s_axis_tdata <= {8'd2,240'd0,8'd2};
    // s_axis_tuser <= 128'h0;
    // s_axis_tkeep <= 64'hffffffffffffffff;
    // s_axis_tvalid <= 1'b0;
    // s_axis_tlast <= 1'b0;
    // #(CYCLE)
    // s_axis_tdata <= {8'd3,240'd0,8'd3};
    // s_axis_tuser <= 128'h0;
    // s_axis_tkeep <= 64'hffffffffffffffff;
    // s_axis_tvalid <= 1'b1;
    // s_axis_tlast <= 1'b1;
    // #(CYCLE)
    // s_axis_tdata <= {256'h0};
    // s_axis_tuser <= 128'h0;
    // s_axis_tkeep <= 64'hffffffffffffffff;
    // s_axis_tvalid <= 1'b0;
    // s_axis_tlast <= 1'b0;

////////////2048 bit-3///////////////
//     #(50*CYCLE)
//     // s_axis_tdata <= {256'h000000000000000000004011480000000060dd8603454d555302224433221100};
//     s_axis_tdata <= {132'h0000000000004011460000000060dd86,4'd0,vlan_id,120'h00008101454d555302224433221100};//0-3
//     s_axis_tuser <= {128'h0000000000000000000000004080007e};
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     // s_axis_tdata <= {256'h000000000000000000004011480000000060dd8603454d555302224433221100};
//     s_axis_tdata <= {132'h0000000000004011460000000060dd86,4'd0,vlan_id,120'h00008101454d555302224433221100};//0-3
//     s_axis_tuser <= {128'h0000000000000000000000004080007e};
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b0;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h4600d5ddea000200000000000000000000000000070504000000000000000000};//4-7
//     s_axis_tuser <= 128'b0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h4600d5ddea000200000000000000000000000000000001000000000000000000};//4-7
//     s_axis_tuser <= 128'b0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b0;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h0000000000000000000000002108251d00000000000000000000000000009320};//8-11
//     s_axis_tuser <= {115'b0,12'b0000_0000_0000,1'b0};
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h0000000000000000000000002108251d00000000000000000000000000009320};//8-11
//     s_axis_tuser <= {115'b0,12'b0000_0000_0000,1'b0};
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b0;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h201f1e1d1c1b1a191817161514131211100f0e0d0c0b0a090807060504030201};//12-15
//     s_axis_tuser <= 128'h0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h201f1e1d1c1b1a191817161514131211100f0e0d0c0b0a090807060504030201};//12-15
//     s_axis_tuser <= 128'h0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b0;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h302f2e2d2c2b2a292827262524232221403f3e3d3c3b3a393837363534333231};//16-19
//     s_axis_tuser <= 128'h0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h403f3e3d3c3b3a393837363534333231504f4e4d4c4b4a494847464544434241};//16-19
//     s_axis_tuser <= 128'h0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b0;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h605f5e5d5c5b5a595857565554535251302f2e2d2c2b2a292827262524232221};//20-23
//     s_axis_tuser <= 128'h0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h605f5e5d5c5b5a595857565554535251504f4e4d4c4b4a494847464544434241};//20-23
//     s_axis_tuser <= 128'h0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b0;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h807f7e7d7c7b7a797877767574737271706f6e6d6c6b6a696867666564636261};//24-27
//     s_axis_tuser <= 128'h0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h807f7e7d7c7b7a797877767574737271706f6e6d6c6b6a696867666564636261};//24-27
//     s_axis_tuser <= 128'h0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b0;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'ha09f9e9d9c9b9a999897969594939291908f8e8d8c8b8a898887868584838281};//28-31
//     s_axis_tuser <= 128'h0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b1;
//     #(CYCLE)
//     s_axis_tdata <= {256'ha09f9e9d9c9b9a999897969594939291908f8e8d8c8b8a898887868584838281};//28-31
//     s_axis_tuser <= 128'h0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b0;
//     s_axis_tlast <= 1'b1;
//     #(CYCLE)
//     s_axis_tdata <= {256'h0};
//     s_axis_tuser <= 128'h0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b0;
//     s_axis_tlast <= 1'b0;
// ////////////2048 bit-4///////////////
//     #(CYCLE)
//     // s_axis_tdata <= {256'h000000000000000000004011480000000060dd8603454d555302224433221100};
//     s_axis_tdata <= {132'h0000000000004011460000000060dd86,4'd0,vlan_id,120'h00008101454d555302224433221100};//0-3
//     s_axis_tuser <= {128'h0000000000000000000000004080007e};
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     // s_axis_tdata <= {256'h000000000000000000004011480000000060dd8603454d555302224433221100};
//     s_axis_tdata <= {132'h0000000000004011460000000060dd86,4'd0,vlan_id,120'h00008101454d555302224433221100};//0-3
//     s_axis_tuser <= {128'h0000000000000000000000004080007e};
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b0;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h4600d5ddea000200000000000000000000000707070504000000000000000000};//4-7
//     s_axis_tuser <= 128'b0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h4600d5ddea000200000000000000000000000000000001000000000000000000};//4-7
//     s_axis_tuser <= 128'b0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b0;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h0000000000000000000000002108251d00000000000000000000000000009320};//8-11
//     s_axis_tuser <= {115'b0,12'b0000_0000_0000,1'b0};
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h0000000000000000000000002108251d00000000000000000000000000009320};//8-11
//     s_axis_tuser <= {115'b0,12'b0000_0000_0000,1'b0};
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b0;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h100f0e0d0c0b0a090807060504030201201f1e1d1c1b1a191817161514131211};//12-15
//     s_axis_tuser <= 128'h0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h201f1e1d1c1b1a191817161514131211100f0e0d0c0b0a090807060504030201};//12-15
//     s_axis_tuser <= 128'h0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b0;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h403f3e3d3c3b3a393837363534333231302f2e2d2c2b2a292827262524232221};//16-19
//     s_axis_tuser <= 128'h0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h403f3e3d3c3b3a393837363534333231302f2e2d2c2b2a292827262524232221};//16-19
//     s_axis_tuser <= 128'h0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b0;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h605f5e5d5c5b5a595857565554535251807f7e7d7c7b7a797877767574737271};//20-23
//     s_axis_tuser <= 128'h0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h605f5e5d5c5b5a595857565554535251504f4e4d4c4b4a494847464544434241};//20-23
//     s_axis_tuser <= 128'h0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b0;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h504f4e4d4c4b4a494847464544434241706f6e6d6c6b6a696867666564636261};//24-27
//     s_axis_tuser <= 128'h0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h807f7e7d7c7b7a797877767574737271706f6e6d6c6b6a696867666564636261};//24-27
//     s_axis_tuser <= 128'h0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b0;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'ha09f9e9d9c9b9a999897969594939291908f8e8d8c8b8a898887868584838281};//28-31
//     s_axis_tuser <= 128'h0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b1;
//     #(CYCLE)
//     s_axis_tdata <= {256'ha09f9e9d9c9b9a999897969594939291908f8e8d8c8b8a898887868584838281};//28-31
//     s_axis_tuser <= 128'h0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b0;
//     s_axis_tlast <= 1'b1;
//     #(CYCLE)
//     s_axis_tdata <= {256'h0};
//     s_axis_tuser <= 128'h0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b0;
//     s_axis_tlast <= 1'b0;
//     ////////////2048 bit-5///////////////
//     #(CYCLE)
//     // s_axis_tdata <= {256'h000000000000000000004011480000000060dd8603454d555302224433221100};
//     s_axis_tdata <= {132'h0000000000004011460000000060dd86,4'd0,vlan_id,120'h00008101454d555302224433221100};//0-3
//     s_axis_tuser <= {128'h0000000000000000000000004080007e};
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     // s_axis_tdata <= {256'h000000000000000000004011480000000060dd8603454d555302224433221100};
//     s_axis_tdata <= {132'h0000000000004011460000000060dd86,4'd0,vlan_id,120'h00008101454d555302224433221100};//0-3
//     s_axis_tuser <= {128'h0000000000000000000000004080007e};
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b0;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h4600d5ddea000200000000000000000000090807070504000000000000000000};//4-7
//     s_axis_tuser <= 128'b0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h4600d5ddea000200000000000000000000000000000001000000000000000000};//4-7
//     s_axis_tuser <= 128'b0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b0;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h0000000000000000000000002108251d00000000000000000000000000009320};//8-11
//     s_axis_tuser <= {115'b0,12'b0000_0000_0000,1'b0};
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h0000000000000000000000002108251d00000000000000000000000000009320};//8-11
//     s_axis_tuser <= {115'b0,12'b0000_0000_0000,1'b0};
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b0;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h201f1e1d1c1b1a191817161514131211100f0e0d0c0b0a090807060504030201};//12-15
//     s_axis_tuser <= 128'h0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h201f1e1d1c1b1a191817161514131211100f0e0d0c0b0a090807060504030201};//12-15
//     s_axis_tuser <= 128'h0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b0;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h403f3e3d3c3b3a393837363534333231302f2e2d2c2b2a292827262524232221};//16-19
//     s_axis_tuser <= 128'h0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h403f3e3d3c3b3a393837363534333231302f2e2d2c2b2a292827262524232221};//16-19
//     s_axis_tuser <= 128'h0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b0;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h504f4e4d4c4b4a494847464544434241605f5e5d5c5b5a595857565554535251};//20-23
//     s_axis_tuser <= 128'h0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h605f5e5d5c5b5a595857565554535251504f4e4d4c4b4a494847464544434241};//20-23
//     s_axis_tuser <= 128'h0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b0;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h807f7e7d7c7b7a797877767574737271706f6e6d6c6b6a696867666564636261};//24-27
//     s_axis_tuser <= 128'h0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h807f7e7d7c7b7a797877767574737271706f6e6d6c6b6a696867666564636261};//24-27
//     s_axis_tuser <= 128'h0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b0;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'ha09f9e9d9c9b9a999897969594939291908f8e8d8c8b8a898887868584838281};//28-31
//     s_axis_tuser <= 128'h0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b1;
//     #(CYCLE)
//     s_axis_tdata <= {256'ha09f9e9d9c9b9a999897969594939291908f8e8d8c8b8a898887868584838281};//28-31
//     s_axis_tuser <= 128'h0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b0;
//     s_axis_tlast <= 1'b1;
//     #(CYCLE)
//     s_axis_tdata <= {256'h0};
//     s_axis_tuser <= 128'h0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b0;
//     s_axis_tlast <= 1'b0;
//     ////////////2048 bit-6///////////////
//     #(CYCLE)
//     // s_axis_tdata <= {256'h000000000000000000004011480000000060dd8603454d555302224433221100};
//     s_axis_tdata <= {132'h0000000000004011460000000060dd86,4'd0,vlan_id,120'h00008101454d555302224433221100};//0-3
//     s_axis_tuser <= {128'h0000000000000000000000004080007e};
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h4600d5ddea000200000000000000000000090808070504000000000000000000};//4-7
//     s_axis_tuser <= 128'b0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h0000000000000000000000002108251d00000000000000000000000000009320};//8-11
//     s_axis_tuser <= {115'b0,12'b0000_0000_0000,1'b0};
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h201f1e1d1c1b1a191817161514131211100f0e0d0c0b0a090807060504030201};//12-15
//     s_axis_tuser <= 128'h0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h403f3e3d3c3b3a393837363534333231302f2e2d2c2b2a292827262524232221};//16-19
//     s_axis_tuser <= 128'h0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h605f5e5d5c5b5a595857565554535251504f4e4d4c4b4a494847464544434241};//20-23
//     s_axis_tuser <= 128'h0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h807f7e7d7c7b7a797877767574737271706f6e6d6c6b6a696867666564636261};//24-27
//     s_axis_tuser <= 128'h0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'ha09f9e9d9c9b9a999897969594939291908f8e8d8c8b8a898887868584838281};//28-31
//     s_axis_tuser <= 128'h0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b1;
//     #(CYCLE)
//     s_axis_tdata <= {256'h0};
//     s_axis_tuser <= 128'h0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b0;
//     s_axis_tlast <= 1'b0;
//         ////////////2048 bit-7///////////////
//     #(CYCLE)
//     // s_axis_tdata <= {256'h000000000000000000004011480000000060dd8603454d555302224433221100};
//     s_axis_tdata <= {132'h0000000000004011460000000060dd86,4'd0,vlan_id,120'h00008101454d555302224433221100};//0-3
//     s_axis_tuser <= {128'h0000000000000000000000004080007e};
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     // s_axis_tdata <= {256'h000000000000000000004011480000000060dd8603454d555302224433221100};
//     s_axis_tdata <= {132'h0000000000004011460000000060dd86,4'd0,vlan_id,120'h00008101454d555302224433221100};//0-3
//     s_axis_tuser <= {128'h0000000000000000000000004080007e};
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b0;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h4600d5ddea000200000000000000000000090808080504000000000000000000};//4-7
//     s_axis_tuser <= 128'b0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h4600d5ddea000200000000000000000000000000000001000000000000000000};//4-7
//     s_axis_tuser <= 128'b0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b0;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h0000000000000000000000002108251d00000000000000000000000000009320};//8-11
//     s_axis_tuser <= {115'b0,12'b0000_0000_0000,1'b0};
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h0000000000000000000000002108251d00000000000000000000000000009320};//8-11
//     s_axis_tuser <= {115'b0,12'b0000_0000_0000,1'b0};
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b0;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h201f1e1d1c1b1a191817161514131211100f0e0d0c0b0a090807060504030201};//12-15
//     s_axis_tuser <= 128'h0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h201f1e1d1c1b1a191817161514131211100f0e0d0c0b0a090807060504030201};//12-15
//     s_axis_tuser <= 128'h0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b0;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h403f3e3d3c3b3a393837363534333231302f2e2d2c2b2a292827262524232221};//16-19
//     s_axis_tuser <= 128'h0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h403f3e3d3c3b3a393837363534333231302f2e2d2c2b2a292827262524232221};//16-19
//     s_axis_tuser <= 128'h0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b0;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h605f5e5d5c5b5a595857565554535251504f4e4d4c4b4a494847464544434241};//20-23
//     s_axis_tuser <= 128'h0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h605f5e5d5c5b5a595857565554535251504f4e4d4c4b4a494847464544434241};//20-23
//     s_axis_tuser <= 128'h0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b0;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h807f7e7d7c7b7a797877767574737271706f6e6d6c6b6a696867666564636261};//24-27
//     s_axis_tuser <= 128'h0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h807f7e7d7c7b7a797877767574737271706f6e6d6c6b6a696867666564636261};//24-27
//     s_axis_tuser <= 128'h0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b0;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'ha09f9e9d9c9b9a999897969594939291908f8e8d8c8b8a898887868584838281};//28-31
//     s_axis_tuser <= 128'h0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b1;
//     #(CYCLE)
//     s_axis_tdata <= {256'ha09f9e9d9c9b9a999897969594939291908f8e8d8c8b8a898887868584838281};//28-31
//     s_axis_tuser <= 128'h0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b0;
//     s_axis_tlast <= 1'b1;
//     #(CYCLE)
//     s_axis_tdata <= {256'h0};
//     s_axis_tuser <= 128'h0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b0;
//     s_axis_tlast <= 1'b0;
        ////////////2048 bit-8///////////////
    // #(CYCLE)
    // // s_axis_tdata <= {256'h000000000000000000004011480000000060dd8603454d555302224433221100};
    // s_axis_tdata <= {132'h0000000000004011460000000060dd86,4'd0,vlan_id,120'h00008101454d555302224433221100};//0-3
    // s_axis_tuser <= {128'h0000000000000000000000004080007e};
    // s_axis_tkeep <= 64'hffffffffffffffff;
    // s_axis_tvalid <= 1'b1;
    // s_axis_tlast <= 1'b0;
    // #(CYCLE)
    // s_axis_tdata <= {256'h4600d5ddea000200000000000000000007090808080504000000000000000000};//4-7
    // s_axis_tuser <= 128'b0;
    // s_axis_tkeep <= 64'hffffffffffffffff;
    // s_axis_tvalid <= 1'b1;
    // s_axis_tlast <= 1'b0;
    // #(CYCLE)
    // s_axis_tdata <= {256'h0000000000000000000000002108251d00000000000000000000000000009320};//8-11
    // s_axis_tuser <= {115'b0,12'b0000_0000_0000,1'b0};
    // s_axis_tkeep <= 64'hffffffffffffffff;
    // s_axis_tvalid <= 1'b1;
    // s_axis_tlast <= 1'b0;
    // #(CYCLE)
    // s_axis_tdata <= {256'h201f1e1d1c1b1a191817161514131211100f0e0d0c0b0a090807060504030201};//12-15
    // s_axis_tuser <= 128'h0;
    // s_axis_tkeep <= 64'hffffffffffffffff;
    // s_axis_tvalid <= 1'b1;
    // s_axis_tlast <= 1'b0;
    // #(CYCLE)
    // s_axis_tdata <= {256'h403f3e3d3c3b3a393837363534333231302f2e2d2c2b2a292827262524232221};//16-19
    // s_axis_tuser <= 128'h0;
    // s_axis_tkeep <= 64'hffffffffffffffff;
    // s_axis_tvalid <= 1'b1;
    // s_axis_tlast <= 1'b0;
    // #(CYCLE)
    // s_axis_tdata <= {256'h605f5e5d5c5b5a595857565554535251504f4e4d4c4b4a494847464544434241};//20-23
    // s_axis_tuser <= 128'h0;
    // s_axis_tkeep <= 64'hffffffffffffffff;
    // s_axis_tvalid <= 1'b1;
    // s_axis_tlast <= 1'b0;
    // #(CYCLE)
    // s_axis_tdata <= {256'h807f7e7d7c7b7a797877767574737271706f6e6d6c6b6a696867666564636261};//24-27
    // s_axis_tuser <= 128'h0;
    // s_axis_tkeep <= 64'hffffffffffffffff;
    // s_axis_tvalid <= 1'b1;
    // s_axis_tlast <= 1'b0;
    // #(CYCLE)
    // s_axis_tdata <= {256'ha09f9e9d9c9b9a999897969594939291908f8e8d8c8b8a898887868584838281};//28-31
    // s_axis_tuser <= 128'h0;
    // s_axis_tkeep <= 64'hffffffffffffffff;
    // s_axis_tvalid <= 1'b1;
    // s_axis_tlast <= 1'b1;
    // #(CYCLE);
    // s_axis_tdata <= {256'h0};
    // s_axis_tuser <= 128'h0;
    // s_axis_tkeep <= 64'hffffffffffffffff;
    // s_axis_tvalid <= 1'b0;
    // s_axis_tlast <= 1'b0;

    #(500*CYCLE);
    finish_txt = 1'b1;
end

rmt_wrapper #(
    .C_S_AXIS_DATA_WIDTH (256 ),
    .C_S_AXIS_TUSER_WIDTH(128),
    .C_NUM_QUEUES        (1),
    .C_VLANID_WIDTH      (12),
    .C_S_AXI_DATA_WIDTH  (32),
    .C_S_AXI_ADDR_WIDTH  (12)
)rmt_wrapper_ins
(
	.clk(clk),		// axis clk
	.aresetn(aresetn),	

	// input Slave AXI Stream
	.s_axis_tdata (s_axis_tdata ),
	.s_axis_tkeep (s_axis_tkeep ),
	.s_axis_tuser (s_axis_tuser ),
	.s_axis_tvalid(s_axis_tvalid),
	.s_axis_tready(s_axis_tready),
	.s_axis_tlast (s_axis_tlast ),

	// output Master AXI Stream
	.m_axis_tdata (m_axis_tdata ),
	.m_axis_tkeep (m_axis_tkeep ),
	.m_axis_tuser (m_axis_tuser ),
	.m_axis_tvalid(m_axis_tvalid),
	.m_axis_tready(m_axis_tready),
	.m_axis_tlast (m_axis_tlast )
	
);


wire [C_S_AXIS_DATA_WIDTH-1:0]	sim_s_axis_tdata_swapped;
wire [C_S_AXIS_DATA_WIDTH-1:0]	sim_m_axis_tdata_swapped;
//控制报文需要一次性倒换，倒完之后再按单条指令的位置做截取，一般按顺序算的话，倒完之后优先取高位作为指令的第一条
assign sim_s_axis_tdata_swapped = {	    s_axis_tdata[0  +:8],      	//[255:248]
										s_axis_tdata[8  +:8],		//[247:240]
										s_axis_tdata[16 +:8],		//[239:232]
										s_axis_tdata[24 +:8],		//[231:224]
										s_axis_tdata[32 +:8],		//[223:216]
										s_axis_tdata[40 +:8],		//[215:208]
										s_axis_tdata[48 +:8],		//[207:200]
										s_axis_tdata[56 +:8],		//[199:192]
										s_axis_tdata[64 +:8],		//[191:184]
										s_axis_tdata[72 +:8],		//[183:176]
										s_axis_tdata[80 +:8],		//[175:168]
										s_axis_tdata[88 +:8],		//[167:160]
										s_axis_tdata[96 +:8],		//[159:152]
										s_axis_tdata[104+:8],		//[151:144]
										s_axis_tdata[112+:8],		//[143:136]
										s_axis_tdata[120+:8],		//[135:128]
										s_axis_tdata[128+:8],		//[127:120]
										s_axis_tdata[136+:8],		//[119:112]
										s_axis_tdata[144+:8],		//[111:104]
										s_axis_tdata[152+:8],		//[103:96 ]
										s_axis_tdata[160+:8],		//[95 :88 ]
										s_axis_tdata[168+:8],		//[87 :80 ]
										s_axis_tdata[176+:8],		//[79 :72 ]
										s_axis_tdata[184+:8],		//[71 :64 ]
										s_axis_tdata[192+:8],		//[63 :56 ]
										s_axis_tdata[200+:8],		//[55 :48 ]
										s_axis_tdata[208+:8],		//[47 :40 ]
										s_axis_tdata[216+:8],		//[39 :32 ]
										s_axis_tdata[224+:8],		//[31 :24 ]
										s_axis_tdata[232+:8],		//[23 :16 ]
										s_axis_tdata[240+:8],		//[15 :08 ]
										s_axis_tdata[248+:8]};		//[07 :00 ]

assign sim_m_axis_tdata_swapped = {	    m_axis_tdata[0  +:8],      	//[255:248]
										m_axis_tdata[8  +:8],		//[247:240]
										m_axis_tdata[16 +:8],		//[239:232]
										m_axis_tdata[24 +:8],		//[231:224]
										m_axis_tdata[32 +:8],		//[223:216]
										m_axis_tdata[40 +:8],		//[215:208]
										m_axis_tdata[48 +:8],		//[207:200]
										m_axis_tdata[56 +:8],		//[199:192]
										m_axis_tdata[64 +:8],		//[191:184]
										m_axis_tdata[72 +:8],		//[183:176]
										m_axis_tdata[80 +:8],		//[175:168]
										m_axis_tdata[88 +:8],		//[167:160]
										m_axis_tdata[96 +:8],		//[159:152]
										m_axis_tdata[104+:8],		//[151:144]
										m_axis_tdata[112+:8],		//[143:136]
										m_axis_tdata[120+:8],		//[135:128]
										m_axis_tdata[128+:8],		//[127:120]
										m_axis_tdata[136+:8],		//[119:112]
										m_axis_tdata[144+:8],		//[111:104]
										m_axis_tdata[152+:8],		//[103:96 ]
										m_axis_tdata[160+:8],		//[95 :88 ]
										m_axis_tdata[168+:8],		//[87 :80 ]
										m_axis_tdata[176+:8],		//[79 :72 ]
										m_axis_tdata[184+:8],		//[71 :64 ]
										m_axis_tdata[192+:8],		//[63 :56 ]
										m_axis_tdata[200+:8],		//[55 :48 ]
										m_axis_tdata[208+:8],		//[47 :40 ]
										m_axis_tdata[216+:8],		//[39 :32 ]
										m_axis_tdata[224+:8],		//[31 :24 ]
										m_axis_tdata[232+:8],		//[23 :16 ]
										m_axis_tdata[240+:8],		//[15 :08 ]
										m_axis_tdata[248+:8]};		//[07 :00 ]


//将输入和输出数据打印到txt文本中进行比较
integer wr_file,wr2_file;
initial begin
    wr_file = $fopen("/home/yang/Desktop/xp5/bit227/s_axis_data.txt","w");
    wr2_file = $fopen("/home/yang/Desktop/xp5/bit227/m_axis_data.txt","w");
end

always @(posedge clk) begin
    if(s_axis_tvalid == 1'b1)
    $fwrite(wr_file,"%h\n",sim_s_axis_tdata_swapped);
    if(m_axis_tvalid == 1'b1)
    $fwrite(wr2_file,"%h\n",sim_m_axis_tdata_swapped);
end


always @(posedge clk)begin
    if(finish_txt) begin
        $fclose(wr_file);
        $fclose(wr2_file);
    end
end


endmodule

// localparam C_NUM_QUEUES = 4;
// localparam C_VLANID_WIDTH = 12;

// // initial begin
// //     reg_int_01 = 32'd11111111;
// //     reg_int_02 = 32'd2;
// //     reg_int_03 = 32'd0;
// // end
// /////////////////////////256λ��ͨ·//////////////////////////////////////////////////////////////
// initial begin

//     #(3*CYCLE+CYCLE/2);
//     #(40* CYCLE)
//     m_axis_tready <= 1'b1;
//     s_axis_tdata <= 256'b0; 
//     s_axis_tkeep <= 64'h0;
//     s_axis_tuser <= 128'h0;
//     s_axis_tvalid <= 1'b0;
//     s_axis_tlast <= 1'b0;
// /////////////��parser��������////////////////////////////////////  
//     #CYCLE;
//     s_axis_tdata <= {256'h6f6fbc4c114000001a858e0000450008ff000081a66840486a3c888888888888};
//     s_axis_tvalid <= 1'b1;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tuser <= 128'h000000000000000000000000408000a0;
//     s_axis_tlast <= 1'b0;
//     // #CYCLE;
//     // s_axis_tdata <= {256'h0};
//     // s_axis_tvalid <= 1'b0;
//     // s_axis_tkeep <= 64'hffffffffffffffff;
//     // s_axis_tuser <= 128'h0;
//     // s_axis_tlast <= 1'b0;
//     // #CYCLE;
//     // s_axis_tdata <= {256'h0};
//     // s_axis_tvalid <= 1'b0;
//     // s_axis_tkeep <= 64'hffffffffffffffff;
//     // s_axis_tuser <= 128'h0;
//     // s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     // s_axis_tdata <= {256'h00000000000000000000000000000001000000007a00f2f13412dededede6f6f};
//     s_axis_tdata <= {124'h0000000000000000000000000000000,vlan_id,8'h00,STAGE_ID0,PARSER_MOD_ID,112'h00007a00f2f13412dededede6f6f};
//     s_axis_tvalid <= 1'b1;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tuser <= 128'b0;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {
//         parser_act_swap[0 ],parser_act_swap[1 ],parser_act_swap[2 ],parser_act_swap[3 ],
//         parser_act_swap[4 ],parser_act_swap[5 ],parser_act_swap[6 ],parser_act_swap[7 ],
//         parser_act_swap[8 ],parser_act_swap[9 ],parser_act_swap[10],parser_act_swap[11],
//         parser_act_swap[12],parser_act_swap[13],parser_act_swap[14],parser_act_swap[15]
//             };
//     s_axis_tvalid <= 1'b1;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tuser <= 128'b0;
//     s_axis_tlast <= 1'b0;
//      #(CYCLE)
//     s_axis_tdata <= {128'h0,
//         parser_act_swap[16],parser_act_swap[17],parser_act_swap[18],parser_act_swap[19],
//         parser_act_swap[20],parser_act_swap[21],parser_act_swap[22],parser_act_swap[23]
//     };
//     s_axis_tvalid <= 1'b1;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tuser <= 128'b0;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h0};
//     s_axis_tvalid <= 1'b1;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tuser <= 128'b0;
//     s_axis_tlast <= 1'b1;
//     #(CYCLE)
//     s_axis_tdata <= 256'b0;
//     s_axis_tvalid <= 1'b0;
//     s_axis_tkeep <= 64'h0;
//     s_axis_tuser <= 128'b0;
//     s_axis_tlast <= 1'b0;
//     #(20*CYCLE)
// //////////deparser/////////////////////
//     s_axis_tdata <= {256'h6f6fbc4c114000001a858e0000450008ff000081a66840486a3c888888888888};
//     s_axis_tvalid <= 1'b1;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tuser <= 128'h000000000000000000000000408000a0;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     // s_axis_tdata <= {256'h00000000000000000000000000000001000500007a00f2f13412dededede6f6f};
//     s_axis_tdata <= {124'h0000000000000000000000000000000,vlan_id,128'h000500007a00f2f13412dededede6f6f};
//     s_axis_tvalid <= 1'b1;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tuser <= 128'b0;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h0000000000000000000000002108251d4f264d244b22230c6311610d67196515};
//     s_axis_tvalid <= 1'b1;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tuser <= 128'b0;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'b0};
//     s_axis_tvalid <= 1'b1;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tuser <= 128'b0;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h0};
//     s_axis_tvalid <= 1'b1;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tuser <= 128'b0;
//     s_axis_tlast <= 1'b1;
//     #(CYCLE)
//     s_axis_tdata <= 256'b0;
//     s_axis_tvalid <= 1'b0;
//     s_axis_tkeep <= 64'h0;
//     s_axis_tuser <= 128'b0;
//     s_axis_tlast <= 1'b0;
//     #(20*CYCLE)
//     ////////////////////////////ker_extract off_set//////////////////////////
//     #(2*CYCLE)
//     s_axis_tdata <= {256'h6f6fbc4c114000001a85310000450008ff00008103454d555302888888888888};
//     s_axis_tvalid <= 1'b1;
//     s_axis_tkeep <= 32'hffffffff;
//     s_axis_tuser <= 128'h00000000000000000000000040800043;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     // s_axis_tdata <= {256'h00000000000000000000000000000001000100001d00f2f13412dededede6f6f};
//     s_axis_tdata <= {124'h0000000000000000000000000000000,vlan_id,8'h00,STAGE_ID0,KEY_EX_ID,112'h00001d00f2f13412dededede6f6f};
//     s_axis_tvalid <= 1'b1;
//     s_axis_tkeep <= 32'hffffffff;
//     s_axis_tuser <= 128'b0;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h0000000000000000000000000000002300000000000000000000000067000023};
//     s_axis_tvalid <= 1'b1;
//     s_axis_tkeep <= 32'hffffffff;
//     s_axis_tuser <= 128'b0;
//     s_axis_tlast <= 1'b1;
//     #(CYCLE)
//     s_axis_tdata <= {16'h0000,240'b0};
//     s_axis_tvalid <= 1'b0;
//     s_axis_tkeep <= 32'hffffffff;
//     s_axis_tuser <= 128'b0;
//     s_axis_tlast <= 1'b0;
//     #(20*CYCLE)
//     ////////////////////////////ker_extract mask//////////////////////////
//     #(2*CYCLE)
//     s_axis_tdata <= {256'h6f6fbc4c114000001a854e0000450008ff00008103454d555302888888888888};
//     s_axis_tvalid <= 1'b1;
//     s_axis_tkeep <= 32'hffffffff;
//     s_axis_tuser <= 128'h00000000000000000000000040800060;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     // s_axis_tdata <= {256'h000000000000000000000000000000010f0100003a00f2f13412dededede6f6f};
//     s_axis_tdata <= {124'h0000000000000000000000000000000,vlan_id,8'h00,STAGE_ID0,KEY_EX_ID,112'h00003a00f2f13412dededede6f6f};
//     s_axis_tvalid <= 1'b1;
//     s_axis_tkeep <= 32'hffffffff;
//     s_axis_tuser <= 128'b0;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h00000000000000000000000000000000ffffffffffffffffffffffffff000000};
//     s_axis_tvalid <= 1'b1;
//     s_axis_tkeep <= 32'hffffffff;
//     s_axis_tuser <= 128'b0;
//     s_axis_tlast <= 1'b1;
//     #(CYCLE)
//     s_axis_tdata <= {256'h0};
//     s_axis_tvalid <= 1'b0;
//     s_axis_tkeep <= 32'hffffffff;
//     s_axis_tuser <= 128'b0;
//     s_axis_tlast <= 1'b0;
//     #(20*CYCLE)
//     /////////////////��дlookup_tcam��һ������////////////////
//     #(2*CYCLE)
//     //s_axis_tdata <= {256'h6f6fbc4c114000001a854e0000450008ff00008102454d555302888888888888};
//     s_axis_tdata <= {256'h6f6fbc4c114000001a854e0000450008ff00008101454d555302888888888888};
//     s_axis_tvalid <= 1'b1;
//     s_axis_tkeep <= 32'hffffffff;
//     s_axis_tuser <= 128'h00000000000000000000000010200060;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h00000000000000000000000000000007000200003a00f2f13412dededede6f6f};
//     s_axis_tvalid <= 1'b1;
//     s_axis_tkeep <= 32'hffffffff;
//     s_axis_tuser <= 128'b0;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= 256'h0000000000000000020000000000000000000000000000000000000000000000;
//     // s_axis_tdata <= 256'h0000000000000000000000000000000000000000000000000000000000000000;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tkeep <= 32'hffffffff;
//     s_axis_tuser <= 128'b0;
//     s_axis_tlast <= 1'b1;
//     #(CYCLE)
//     s_axis_tdata <= {256'h0};
//     s_axis_tvalid <= 1'b0;
//     s_axis_tkeep <= 32'hffffffff;
//     s_axis_tuser <= 128'b0;
//     s_axis_tlast <= 1'b0;
//     #(20*CYCLE)
//     //****************************д��looup_action��һ������*********************************************************************//
//     #(2*CYCLE)
//     s_axis_tdata <= {256'h6f6fbc4c114000001a85ce0000450008ff00008101454d555302888888888888};
//     s_axis_tvalid <= 1'b1;
//     s_axis_tkeep <= 32'hffffffff;
//     s_axis_tuser <= 128'h000000000000000000000000102000e0;
//     s_axis_tlast <= 1'b0;
//     //action table
//     #(CYCLE)
//     s_axis_tdata <= {256'h000000000000000000000000000000070f020000ba00f2f13412dededede6f6f};
//     s_axis_tvalid <= 1'b1;
//     s_axis_tkeep <= 32'hffffffff;
//     s_axis_tuser <= 128'b0;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h0000000000000000000000000000000000000000000000000000000000000000};
//     s_axis_tvalid <= 1'b1;
//     s_axis_tkeep <= 32'hffffffff;
//     s_axis_tuser <= 128'b0;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h0000000000000000000000000000000000000000000000000000000000000000};
//     s_axis_tvalid <= 1'b1;
//     s_axis_tkeep <= 32'hffffffff;
//     s_axis_tuser <= 128'b0;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h0000000000000000000000000000000000000000000000000800200300000000};
//     s_axis_tvalid <= 1'b1;
//     s_axis_tkeep <= 32'hffffffff;
//     s_axis_tuser <= 128'b0;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h0000000000000000000000000000000000000000000000000000000000000000};
//     s_axis_tvalid <= 1'b1;
//     s_axis_tkeep <= 32'hffffffff;
//     s_axis_tuser <= 128'b0;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h0000000000000000000000000000000000000000000000000000000000000000};
//     s_axis_tvalid <= 1'b1;
//     s_axis_tkeep <= 32'hffffffff;
//     s_axis_tuser <= 128'b0;
//     s_axis_tlast <= 1'b1;
//     #(CYCLE)
//     s_axis_tdata <= 256'b0;
//     s_axis_tvalid <= 1'b0;
//     s_axis_tkeep <= 32'hffffffff;
//     s_axis_tuser <= 128'b0;
//     s_axis_tlast <= 1'b0;
//     #(20*CYCLE);       
//     ////////foure data packets first que///////////////
//     #(2*CYCLE)
//     // s_axis_tdata <= {256'h000000000000000000004011480000000060dd8603454d555302224433221100};
//     s_axis_tdata <= {132'h0000000000004011460000000060dd86,4'd0,vlan_id,120'h00008101454d555302224433221100};
//     s_axis_tuser <= {128'h0000000000000000000000004080007e};
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h4600d5ddea000200000000000000000000000000000001000000000000000000};
//     s_axis_tuser <= 128'b0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h0000000000000000000000002108251d00000000000000000000000000009320};
//     s_axis_tuser <= {115'b0,12'b0000_0000_0000,1'b0};
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h00000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e};
//     s_axis_tuser <= 128'h0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h3e3d3c3b3a393837363534333231302f2e2d2c2b2a292827262524232221201f};
//     s_axis_tuser <= 128'h0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b1;
//     #(CYCLE)
//     s_axis_tdata <= {256'h0};
//     s_axis_tuser <= 128'h0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b0;
//     s_axis_tlast <= 1'b0;

//     #(20*CYCLE)
//     // s_axis_tdata <= {256'h000000000000000000004011480000000060dd8603454d555302224433221100};
//     s_axis_tdata <= {256'h0000000000004011480000000060dd860100008101454d555302224433221100};
//     s_axis_tuser <= {128'h0000000000000000000000004080007e};
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h4800d5ddea000200000000000000000000000000000001000000000000000000};
//     s_axis_tuser <= 128'b0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h00000000000000000000000000000000ccccccccbbbbbbbbaaaaaaaa00009c20};
//     s_axis_tuser <= {115'b0,12'b0000_0000_0000,1'b0};
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h0000000000000000000000000000000000000000000000000000000000000000};
//     s_axis_tuser <= 128'h0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
//     #(CYCLE)
//     s_axis_tdata <= {256'h0};
//     s_axis_tuser <= 128'h0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b1;
//     #(CYCLE)
//     s_axis_tdata <= {256'h0};
//     s_axis_tuser <= 128'h0;
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tvalid <= 1'b0;
//     s_axis_tlast <= 1'b0;

// end

// endmodule