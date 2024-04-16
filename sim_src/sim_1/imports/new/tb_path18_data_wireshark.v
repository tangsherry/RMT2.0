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
//通过过滤器但是没有命中的报文的处理
//当配置出错时候的异常恢复问题
module tb_path18_data_wireshark #(
    // Slave AXI parameters
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
    parameter OFFBYTE_ID = 4'b0011,//这里会导致数据报文下发报错，但是应该不会导致配置失效，无法正确命中的问题
    parameter PARSER_MOD_ID = 4'b0001,
    parameter BIT_CFG_MOD_ID1 = 4'b1111,
    parameter BIT_CFG_MOD_ID2 = 4'b1100,
    parameter BIT_TCAM_MOD_ID1 = 4'b1110,
    parameter BIT_TCAM_MOD_ID2 = 4'b1000,
    parameter KEY_EX_ID = 4'h0002,
    parameter STAGE_ID0 = 4'b0000,
    parameter STAGE_ID4 = 4'b0100,
    parameter STAGE_ID1 = 4'b0001,
    parameter STAGE_ID2 = 4'b0010,
    parameter STAGE_ID3 = 4'b0011,
    parameter C_PKT_VEC_WIDTH = 8*(8+4+2)*8+100+256
    )();

localparam CYCLE = 10;
localparam PACKETS = 18;

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

//读取txt数据到 hexdata_mem ，记录txt里每段报文的截止地址，为了tlast的设置
wire [6:0] txt_mem_addr [PACKETS:0]  ;
assign txt_mem_addr[0]  = 7'd0  ;
assign txt_mem_addr[1]  = 7'd9  ;
assign txt_mem_addr[2]  = 7'd18 ;
assign txt_mem_addr[3]  = 7'd27 ;
assign txt_mem_addr[4]  = 7'd37 ;
assign txt_mem_addr[5]  = 7'd47 ;
assign txt_mem_addr[6]  = 7'd57 ;
assign txt_mem_addr[7]  = 7'd62 ;
assign txt_mem_addr[8]  = 7'd67 ;
assign txt_mem_addr[9]  = 7'd72 ;
assign txt_mem_addr[10] = 7'd79 ;
assign txt_mem_addr[11] = 7'd86 ;
assign txt_mem_addr[12] = 7'd93 ;
assign txt_mem_addr[13] = 7'd95 ;
assign txt_mem_addr[14] = 7'd97 ;
assign txt_mem_addr[15] = 7'd99 ;
assign txt_mem_addr[16] = 7'd105;
assign txt_mem_addr[17] = 7'd111;
assign txt_mem_addr[18] = 7'd117;

integer wr_file,wr2_file,rd_file,rd_data,j,i,k;
reg  [255:0] hexdata_mem     [0:116];
reg  [255:0] hexdata_swapped [0:116];//数据字段大小端转换进入

initial begin
    rd_file = $fopen("/home/yang/Desktop/xp5/bit0322/deparser_ram1024_0408.xpr/tb_data_hexstream.txt","r");
    for(i=0;i<PACKETS;i=i+1) begin
        for(j=txt_mem_addr[i];j<txt_mem_addr[i+1];j=j+1) begin
            rd_data = $fscanf(rd_file,"%h",hexdata_mem[j]);
            for(k=0;k<32;k=k+1)begin
                hexdata_swapped[j][255-8*k-:8] = hexdata_mem[j][k*8+:8];//大小端转换
            end
        end
    end
    $fclose(rd_file);
end

//写数据到txt文档
initial begin
    wr_file  = $fopen("/home/yang/Desktop/xp5/bit0322/deparser_ram1024_0408.xpr/s_axis_data.txt","w");
    wr2_file = $fopen("/home/yang/Desktop/xp5/bit0322/deparser_ram1024_0408.xpr/m_axis_data.txt","w");
end
//造随机出0和1的tvalid，用于读取报文
reg rand;
initial begin
    rand = 0;
end
always @(posedge clk)begin
    if(!aresetn)
        rand <= 1'b0;
    else 
        rand <= {$random}%2;
end


//used in packet
wire [255:0] ctrl_s_axis_tdata_swapped;
assign ctrl_s_axis_tdata_swapped = {	
    s_axis_tdata[0  +:8],      	//[255:248]
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

//偏移字节数，偏移地址
//eth->ieee802-1q->ieee802-1q(1)->ipv4 off = 176
//eth->ieee802-1q->ipv4 off =                144
//eth->ipv4  =                               112
reg [15:0] s1_off_byte[31:0];
reg [15:0] s1_off_addr[31:0];
reg [15:0] swap_s1_off_byte [31:0] ;
reg [15:0] swap_s1_off_addr [31:0] ;

initial begin
    s1_off_addr[ 0] = 16'h0000;
    s1_off_addr[ 1] = 16'h0001;
    s1_off_addr[ 2] = 16'h0002;
    s1_off_byte[ 0] = 16'd18; //144bit=18byte
    s1_off_byte[ 1] = 16'd14; //112bit=14byte
    s1_off_byte[ 2] = 16'd22; //176bit=22byte 
    for(i=3;i<32;i=i+1)begin
        s1_off_byte[ i] = 16'h00;
        s1_off_addr[i] = 16'hff;
    end
end

initial begin
    for (i=0;i<32;i=i+1)begin
        swap_s1_off_addr[ i] = {s1_off_addr[i][7:0],s1_off_addr[i][15:8]};
        swap_s1_off_byte[ i] = {s1_off_byte[i][7:0],s1_off_byte[i][15:8]};
    end
end

//组成的7个指令，只改变偏移字节
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


reg [15:0]parser_ram_addr_swap[7:0];
initial begin
    for (i=0;i<8;i=i+1)begin
        parser_ram_addr_swap[ i] = {parser_ram_addr[i][7:0],parser_ram_addr[i][15:8]};
    end
end

//=======================================parser table===========================================
wire [255:0] parser_table1 [511:0];
wire [255:0] parser_table2 [511:0];
reg [15 :0] parser_act0 [23:0];
reg [15:0] parser_act_swap0 [23:0];
initial begin
    for (i=0;i<24;i=i+1)begin
        parser_act0[ i] = {valid[ i],2'b00,off_64b_seg[ i],off_byte[ i],val_index[ i],val_type[ i]};
        parser_act_swap0[ i] = {parser_act0[ i][7:0],parser_act0[ i][15:8]}; 
    end
end
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
reg [15:0] parser_act1 [23:0];
reg [15:0] parser_act_swap1 [23:0];//一共有512个24X16b的指令，作为测试，可以少造一些报文，还是写for循环的方式吧
initial begin
    for (i=0;i<24;i=i+1)begin
        parser_act1[ i] = {valid[ i],2'b00,off_64b_seg[ i],off_byte1[ i],val_index[ i],val_type[ i]};
        parser_act_swap1[ i] = {parser_act1[ i][7:0],parser_act1[ i][15:8]}; 
    end
end
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
reg [15:0] parser_act2 [23:0];
reg [15:0] parser_act_swap2 [23:0];//一共有512个24X16b的指令，作为测试，可以少造一些报文，还是写for循环的方式吧
initial begin
    for (i=0;i<24;i=i+1)begin
        parser_act2[ i] = {valid[i],2'b00,off_64b_seg[i],off_byte2[i],val_index[i],val_type[i]};
        parser_act_swap2[ i] = {parser_act2[ i][7:0],parser_act2[ i][15:8]}; 
    end
end
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
reg [15:0] parser_act3 [23:0];
reg [15:0] parser_act_swap3 [23:0];//一共有512个24X16b的指令，作为测试，可以少造一些报文，还是写for循环的方式吧
initial begin
    for (i=0;i<24;i=i+1)begin
        parser_act3[ i] = {valid[i],2'b00,off_64b_seg[i],off_byte3[i],val_index[i],val_type[i]};
        parser_act_swap3[ i] = {parser_act3[ i][7:0],parser_act3[ i][15:8]}; 
    end
end

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
reg [15:0] parser_act4 [23:0];
reg [15:0] parser_act_swap4 [23:0];//一共有512个24X16b的指令，作为测试，可以少造一些报文，还是写for循环的方式吧
initial begin
    for (i=0;i<24;i=i+1)begin
        parser_act4[ i] = {valid[i],2'b00,off_64b_seg[i],off_byte4[i],val_index[i],val_type[i]};
        parser_act_swap4[ i] = {parser_act4[ i][7:0],parser_act4[ i][15:8]}; 
    end
end

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
reg [15:0] parser_act5 [23:0];
reg [15:0] parser_act_swap5 [23:0];//一共有512个24X16b的指令，作为测试，可以少造一些报文，还是写for循环的方式吧
initial begin
    for (i=0;i<24;i=i+1)begin
        parser_act5[ i] = {valid[i],2'b00,off_64b_seg[i],off_byte5[i],val_index[i],val_type[i]};
        parser_act_swap5[ i] = {parser_act5[ i][7:0],parser_act5[ i][15:8]}; 
    end
end
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

//一组parser配置指令数据
reg [15:0] parser_act6 [23:0];
reg [15:0] parser_act_swap6 [23:0];//一共有512个24X16b的指令，作为测试，可以少造一些报文，还是写for循环的方式吧
initial begin
    for (i=0;i<24;i=i+1) begin
        parser_act6[ i] = {valid[ i],2'b00,off_64b_seg[ i],off_byte6[i],val_index[ i],val_type[i]};
        parser_act_swap6[ i] = {parser_act6[ i][7:0],parser_act6[ i][15:8]}; 
    end
end

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

//bit_tcam配置
wire [127:0]bit_tcam_mask;
assign bit_tcam_mask = 128'd0;

//****************************************************************************************
//第一个top模块bit位提取配置bit_cfg_1
reg [15:0] bit_act [127:0];
//没有具体提取数据的可以直接循环写0
initial begin
    bit_act[ 0 ] = {6'b100000,7'd20  ,3'd3};//163 01 放在提取的最低位，wireshark抓取的最低位
    bit_act[ 1 ] = {6'b100000,7'd16  ,3'd4};//132 08
    bit_act[ 2 ] = {6'b100000,7'd16  ,3'd0};//128 08
    bit_act[ 3 ] = {6'b100000,7'd12  ,3'd4};//100 81
    bit_act[ 4 ] = {6'b100000,7'd12  ,3'd0};//96  81
    bit_act[ 5 ] = {6'b000000,7'd0  ,3'd5};
    bit_act[ 6 ] = {6'b000000,7'd0  ,3'd6};
    bit_act[ 7 ] = {6'b000000,7'd0  ,3'd7};
    bit_act[ 8 ] = {6'b000000,7'd1  ,3'd0};
    bit_act[ 9 ] = {6'b000000,7'd1  ,3'd1};
    bit_act[ 10] = {6'b000000,7'd1  ,3'd2};
    bit_act[ 11] = {6'b000000,7'd1  ,3'd3};
    bit_act[ 12] = {6'b000000,7'd1  ,3'd4};
    bit_act[ 13] = {6'b000000,7'd1  ,3'd5};
    bit_act[ 14] = {6'b000000,7'd1  ,3'd6};
    bit_act[ 15] = {6'b000000,7'd1  ,3'd7};
    bit_act[ 16] = {6'b100000,7'd2  ,3'd0};
    bit_act[ 17] = {6'b100000,7'd2  ,3'd1};
    bit_act[ 18] = {6'b100000,7'd2  ,3'd2};
    bit_act[ 19] = {6'b100000,7'd2  ,3'd3};
    bit_act[ 20] = {6'b100000,7'd2  ,3'd4};
    bit_act[ 21] = {6'b100000,7'd2  ,3'd5};
    bit_act[ 22] = {6'b100000,7'd2  ,3'd6};
    bit_act[ 23] = {6'b100000,7'd2  ,3'd7};
    bit_act[ 24] = {6'b100000,7'd3  ,3'd0};
    bit_act[ 25] = {6'b100000,7'd3  ,3'd1};
    bit_act[ 26] = {6'b100000,7'd3  ,3'd2};
    bit_act[ 27] = {6'b100000,7'd3  ,3'd3};
    bit_act[ 28] = {6'b100000,7'd3  ,3'd4};
    bit_act[ 29] = {6'b100000,7'd3  ,3'd5};
    bit_act[ 30] = {6'b100000,7'd3  ,3'd6};
    bit_act[ 31] = {6'b100000,7'd3  ,3'd7};

    for (i=32;i<127;i=i+1)begin
        bit_act[i] = {6'b100000,7'd0  ,3'd0};

    end
end
//交换循环
reg [15:0] bit_act_swap [127:0];
initial begin
    for (i=0;i<127;i=i+1)begin
       bit_act_swap[ i ] = {bit_act[ i ][7:0],bit_act[ i ][15:8]};
    end
end

//*************************************************************************************
//第二个top模块bit位提取配置bit_cfg_2
reg [15:0] bit_act2 [127:0];
//没有具体提取数据的可以直接循环写0
initial begin
    bit_act2[ 0 ] = {6'b100000,7'd67  ,3'd7};//543 01 放在提取的最低位，wireshark抓取的最低位
    bit_act2[ 1 ] = {6'b100000,7'd43  ,3'd7};//351 08
    bit_act2[ 2 ] = {6'b100000,7'd9   ,3'd7};//79 08
    bit_act2[ 3 ] = {6'b100000,7'd9   ,3'd5};//77 81
    bit_act2[ 4 ] = {6'b100000,7'd9   ,3'd3};//75  81
    bit_act2[ 5 ] = {6'b100000,7'd9   ,3'd2}; //74 
    // bit_act2[ 0 ] = {6'b100000,7'd0   ,3'd0};
    // bit_act2[ 1 ] = {6'b100000,7'd0   ,3'd1};
    // bit_act2[ 2 ] = {6'b100000,7'd0   ,3'd2};
    // bit_act2[ 3 ] = {6'b100000,7'd0   ,3'd3};
    // bit_act2[ 4 ] = {6'b100000,7'd0   ,3'd4};
    // bit_act2[ 5 ] = {6'b100000,7'd0   ,3'd5};
    bit_act2[ 6 ] = {6'b100000,7'd0   ,3'd6};
    bit_act2[ 7 ] = {6'b100000,7'd0   ,3'd7};
    bit_act2[ 8 ] = {6'b100000,7'd1   ,3'd0};
    bit_act2[ 9 ] = {6'b100000,7'd1   ,3'd1};
    bit_act2[ 10] = {6'b100000,7'd1   ,3'd2};
    bit_act2[ 11] = {6'b100000,7'd1   ,3'd3};
    bit_act2[ 12] = {6'b100000,7'd1   ,3'd4};    
    
    bit_act2[ 13] = {6'b100000,7'd1   ,3'd5};
    bit_act2[ 14] = {6'b100000,7'd1   ,3'd6};
    bit_act2[ 15] = {6'b100000,7'd1   ,3'd7};
    bit_act2[ 16] = {6'b100000,7'd2   ,3'd0};
    bit_act2[ 17] = {6'b100000,7'd2   ,3'd1};
    bit_act2[ 18] = {6'b100000,7'd2   ,3'd2};
    bit_act2[ 19] = {6'b100000,7'd2   ,3'd3};
    bit_act2[ 20] = {6'b100000,7'd2   ,3'd4};
    bit_act2[ 21] = {6'b100000,7'd2   ,3'd5};
    bit_act2[ 22] = {6'b100000,7'd2   ,3'd6};
    bit_act2[ 23] = {6'b100000,7'd2   ,3'd7};
    bit_act2[ 24] = {6'b100000,7'd3   ,3'd0};
    bit_act2[ 25] = {6'b100000,7'd3   ,3'd1};
    bit_act2[ 26] = {6'b100000,7'd3   ,3'd2};
    bit_act2[ 27] = {6'b100000,7'd3   ,3'd3};
    bit_act2[ 28] = {6'b100000,7'd3   ,3'd4};
    bit_act2[ 29] = {6'b100000,7'd3   ,3'd5};
    bit_act2[ 30] = {6'b100000,7'd3   ,3'd6};
    bit_act2[ 31] = {6'b100000,7'd3   ,3'd7};

    for (i=32;i<127;i=i+1)begin
        bit_act2[i] = {6'b100000,7'd0  ,3'd0};

    end
end
//交换循环
reg [15:0] bit_act_swap2 [127:0];
initial begin
    for (i=0;i<127;i=i+1)begin
       bit_act_swap2[ i ] = {bit_act2[ i ][7:0],bit_act2[ i ][15:8]};
    end
end

//***********************************************************************
//第一个top模块tcam配置
wire [127:0]  bit_tcam_cfg   [31:0];
wire [31 :0]  bit32_tcam_cfg [7 :0];//最大深度给到32
wire [15 :0]  bit16_tcam_cfg [15:0];//最大深度给到32

assign bit32_tcam_cfg[0] = 32'h00000000;
assign bit32_tcam_cfg[1] = 32'h11111111;
assign bit32_tcam_cfg[2] = 32'h22222222;
assign bit32_tcam_cfg[3] = 32'h33333333;
assign bit32_tcam_cfg[4] = 32'h44444444;
assign bit32_tcam_cfg[5] = 32'h55555555;
assign bit32_tcam_cfg[6] = 32'h66666666;
assign bit32_tcam_cfg[7] = 32'h3c6a4840;

assign bit16_tcam_cfg[0  ] = 16'h1200;//数据还是按字节倒过来配置了
assign bit16_tcam_cfg[1  ] = 16'h1111;
assign bit16_tcam_cfg[2  ] = 16'h2222;
assign bit16_tcam_cfg[3  ] = 16'h3333;
assign bit16_tcam_cfg[4  ] = 16'h4444;
assign bit16_tcam_cfg[5  ] = 16'h5555;
assign bit16_tcam_cfg[6  ] = 16'h6666;
assign bit16_tcam_cfg[7  ] = 16'h3c6a;
assign bit16_tcam_cfg[8  ] = 16'h8888;
assign bit16_tcam_cfg[9  ] = 16'h9999;
assign bit16_tcam_cfg[10 ] = 16'haaaa;
assign bit16_tcam_cfg[11 ] = 16'hbbbb;
assign bit16_tcam_cfg[12 ] = 16'hcccc;
assign bit16_tcam_cfg[13 ] = 16'hdddd;
assign bit16_tcam_cfg[14 ] = 16'heeee;
assign bit16_tcam_cfg[15 ] = 16'hffff;

//与wireshark的TCAM表相同顺序
//补充逻辑，没有匹配上的报文路径怎么走
assign bit_tcam_cfg[ 2] = {bit32_tcam_cfg[3 ],bit32_tcam_cfg[2 ],bit32_tcam_cfg[1 ],bit32_tcam_cfg[0 ]};//00000//8a9f020100 02 003002000b0055555555
assign bit_tcam_cfg[ 3] = {bit32_tcam_cfg[7 ],bit32_tcam_cfg[6 ],bit32_tcam_cfg[5 ],bit32_tcam_cfg[4 ]};//10000   
assign bit_tcam_cfg[ 0] = {bit16_tcam_cfg[7 ],bit16_tcam_cfg[6 ],bit16_tcam_cfg[5 ],bit16_tcam_cfg[4 ],bit16_tcam_cfg[ 3],bit16_tcam_cfg[ 2],bit16_tcam_cfg[1],bit16_tcam_cfg[0]};//addr11
assign bit_tcam_cfg[ 1] = {bit16_tcam_cfg[15],bit16_tcam_cfg[14],bit16_tcam_cfg[13],bit16_tcam_cfg[12],bit16_tcam_cfg[11],bit16_tcam_cfg[10],bit16_tcam_cfg[9],bit16_tcam_cfg[8]};//addr11
assign bit_tcam_cfg[ 4] = {128'h0};//addr02
assign bit_tcam_cfg[ 5] = {128'h0};
assign bit_tcam_cfg[ 6] = {128'h0};
assign bit_tcam_cfg[ 7] = {128'h0};
assign bit_tcam_cfg[ 8] = {128'h0};
assign bit_tcam_cfg[ 9] = {120'd0,8'b00000000};
assign bit_tcam_cfg[10] = {120'd0,8'b00000000};
assign bit_tcam_cfg[11] = {120'd0,8'b00000000};
assign bit_tcam_cfg[12] = {120'd0,8'b00000000};
assign bit_tcam_cfg[13] = {120'd0,8'b00000000};
assign bit_tcam_cfg[14] = {120'd0,8'b00000000};
assign bit_tcam_cfg[15] = {120'd0,8'b00000000};
assign bit_tcam_cfg[16] = {120'd0,8'b00000000};
assign bit_tcam_cfg[17] = {120'd0,8'b00000000};
assign bit_tcam_cfg[18] = {120'd0,8'b00000000};
assign bit_tcam_cfg[19] = {120'd0,8'b00000000};
assign bit_tcam_cfg[20] = {120'd0,8'b00000000};
assign bit_tcam_cfg[21] = {120'd0,8'b00000000};
assign bit_tcam_cfg[22] = {120'd0,8'b00000000};
assign bit_tcam_cfg[23] = {120'd0,8'b00000000};
assign bit_tcam_cfg[24] = {120'd0,8'b00000000};
assign bit_tcam_cfg[25] = {120'd0,8'b00000000};
assign bit_tcam_cfg[26] = {120'd0,8'b00000000};
assign bit_tcam_cfg[27] = {120'd0,8'b00000000};
assign bit_tcam_cfg[28] = {120'd0,8'b00000000};
assign bit_tcam_cfg[29] = {120'd0,8'b00000000};
assign bit_tcam_cfg[30] = {120'd0,8'b00000000};
assign bit_tcam_cfg[31] = {120'd0,8'b00000000};

//***********************************************************************
//第二个top模块tcam配置
wire [127:0]  bit_tcam_cfg2   [31:0];
wire [31 :0]  bit32_tcam_cfg2 [7 :0];//最大深度给到32
wire [15 :0]  bit16_tcam_cfg2 [15:0];//最大深度给到32

assign bit32_tcam_cfg2[0] = 32'h00000000;
assign bit32_tcam_cfg2[1] = 32'h11111111;
assign bit32_tcam_cfg2[2] = 32'h22222222;
assign bit32_tcam_cfg2[3] = 32'h33333333;
assign bit32_tcam_cfg2[4] = 32'h44444444;
assign bit32_tcam_cfg2[5] = 32'h55555555;
assign bit32_tcam_cfg2[6] = 32'h66666666;
assign bit32_tcam_cfg2[7] = 32'h3c6a4840;

assign bit16_tcam_cfg2[0  ] = 16'h1400;//数据还是按字节倒过来配置了
assign bit16_tcam_cfg2[1  ] = 16'h1111;
assign bit16_tcam_cfg2[2  ] = 16'h2222;
assign bit16_tcam_cfg2[3  ] = 16'h3333;
assign bit16_tcam_cfg2[4  ] = 16'h4444;
assign bit16_tcam_cfg2[5  ] = 16'h5555;
assign bit16_tcam_cfg2[6  ] = 16'h6666;
assign bit16_tcam_cfg2[7  ] = 16'h3c6a;
assign bit16_tcam_cfg2[8  ] = 16'h8888;
assign bit16_tcam_cfg2[9  ] = 16'h9999;
assign bit16_tcam_cfg2[10 ] = 16'haaaa;
assign bit16_tcam_cfg2[11 ] = 16'hbbbb;
assign bit16_tcam_cfg2[12 ] = 16'hcccc;
assign bit16_tcam_cfg2[13 ] = 16'hdddd;
assign bit16_tcam_cfg2[14 ] = 16'heeee;
assign bit16_tcam_cfg2[15 ] = 16'hffff;

//与wireshark的TCAM表相同顺序
//补充逻辑，没有匹配上的报文路径怎么走
assign bit_tcam_cfg2[ 2] = {bit32_tcam_cfg2[3 ],bit32_tcam_cfg2[2 ],bit32_tcam_cfg2[1 ],bit32_tcam_cfg2[0 ]};//00000//8a9f020100 02 003002000b0055555555
assign bit_tcam_cfg2[ 3] = {bit32_tcam_cfg2[7 ],bit32_tcam_cfg2[6 ],bit32_tcam_cfg2[5 ],bit32_tcam_cfg2[4 ]};//10000   
assign bit_tcam_cfg2[ 0] = {bit16_tcam_cfg2[7 ],bit16_tcam_cfg2[6 ],bit16_tcam_cfg2[5 ],bit16_tcam_cfg2[4 ],bit16_tcam_cfg2[ 3],bit16_tcam_cfg2[ 2],bit16_tcam_cfg2[1],bit16_tcam_cfg2[0]};//addr11
assign bit_tcam_cfg2[ 1] = {bit16_tcam_cfg2[15],bit16_tcam_cfg2[14],bit16_tcam_cfg2[13],bit16_tcam_cfg2[12],bit16_tcam_cfg2[11],bit16_tcam_cfg2[10],bit16_tcam_cfg2[9],bit16_tcam_cfg2[8]};//addr11
assign bit_tcam_cfg2[ 4] = {128'h0};//addr02
assign bit_tcam_cfg2[ 5] = {128'h0};
assign bit_tcam_cfg2[ 6] = {128'h0};
assign bit_tcam_cfg2[ 7] = {128'h0};
assign bit_tcam_cfg2[ 8] = {128'h0};
assign bit_tcam_cfg2[ 9] = {120'd0,8'b00000000};
assign bit_tcam_cfg2[10] = {120'd0,8'b00000000};
assign bit_tcam_cfg2[11] = {120'd0,8'b00000000};
assign bit_tcam_cfg2[12] = {120'd0,8'b00000000};
assign bit_tcam_cfg2[13] = {120'd0,8'b00000000};
assign bit_tcam_cfg2[14] = {120'd0,8'b00000000};
assign bit_tcam_cfg2[15] = {120'd0,8'b00000000};
assign bit_tcam_cfg2[16] = {120'd0,8'b00000000};
assign bit_tcam_cfg2[17] = {120'd0,8'b00000000};
assign bit_tcam_cfg2[18] = {120'd0,8'b00000000};
assign bit_tcam_cfg2[19] = {120'd0,8'b00000000};
assign bit_tcam_cfg2[20] = {120'd0,8'b00000000};
assign bit_tcam_cfg2[21] = {120'd0,8'b00000000};
assign bit_tcam_cfg2[22] = {120'd0,8'b00000000};
assign bit_tcam_cfg2[23] = {120'd0,8'b00000000};
assign bit_tcam_cfg2[24] = {120'd0,8'b00000000};
assign bit_tcam_cfg2[25] = {120'd0,8'b00000000};
assign bit_tcam_cfg2[26] = {120'd0,8'b00000000};
assign bit_tcam_cfg2[27] = {120'd0,8'b00000000};
assign bit_tcam_cfg2[28] = {120'd0,8'b00000000};
assign bit_tcam_cfg2[29] = {120'd0,8'b00000000};
assign bit_tcam_cfg2[30] = {120'd0,8'b00000000};
assign bit_tcam_cfg2[31] = {120'd0,8'b00000000};

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
reg [7:0] send_cnt ;
integer i;
initial begin
    finish_txt = 1'b0;
    send_cnt = 0;
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
    
    ////////////////////////////////////////////bit_cfg1////////////////////////////////////  
    #(CYCLE);
    s_axis_tdata <= {256'h6f6fbc4c114000001a858e0000450008ff000081a66840486a3c888888888888};
    s_axis_tvalid <= 1'b1;
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tuser <= 128'h000000000000000000000000408000a0;
    s_axis_tlast <= 1'b0;
    #(CYCLE)
    // s_axis_tdata <= {256'h00000000000000000000000000000001000000007a00f2f13412dededede6f6f};
    s_axis_tdata <= {124'h0000000000000000000000000000000,vlan_id,8'h00,STAGE_ID4,BIT_CFG_MOD_ID1,112'h00007a00f2f13412dededede6f6f};
    s_axis_tvalid <= 1'b1               ;
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tuser <= 128'b0              ;
    s_axis_tlast <= 1'b0                ;

    for(i = 0;i<1;i=i+1)begin
        #(CYCLE)
        s_axis_tdata <= {
            bit_act_swap[16*i+15 ],bit_act_swap[16*i+14 ],bit_act_swap[16*i+13 ],bit_act_swap[16*i+12 ],
            bit_act_swap[16*i+11 ],bit_act_swap[16*i+10 ],bit_act_swap[16*i+9  ],bit_act_swap[16*i+8  ],
            bit_act_swap[16*i+7  ],bit_act_swap[16*i+6  ],bit_act_swap[16*i+5  ],bit_act_swap[16*i+4  ],
            bit_act_swap[16*i+3  ],bit_act_swap[16*i+2  ],bit_act_swap[16*i+1  ],bit_act_swap[16*i    ]
        };
        s_axis_tvalid <= 1'b1;
        s_axis_tkeep <= 64'hffffffffffffffff;
        s_axis_tuser <= 128'b0;
        if(i==0)
            s_axis_tlast <= 1'b1;
        else
            s_axis_tlast <= 1'b0;
    end
    #(CYCLE)
    s_axis_tdata <= 256'd0;
    s_axis_tvalid <= 1'b0;
    s_axis_tkeep <= 64'h0;
    s_axis_tuser <= 128'b0;
    s_axis_tlast <= 1'b0;
    #(20*CYCLE)

////////////////////////////////////////////bit_cfg2////////////////////////////////////  
    #(CYCLE);
    s_axis_tdata <= {256'h6f6fbc4c114000001a858e0000450008ff000081a66840486a3c888888888888};
    s_axis_tvalid <= 1'b1;
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tuser <= 128'h000000000000000000000000408000a0;
    s_axis_tlast <= 1'b0;
    #(CYCLE)
    s_axis_tdata <= {124'h0000000000000000000000000000000,vlan_id,8'h00,STAGE_ID4,BIT_CFG_MOD_ID2,112'h00007a00f2f13412dededede6f6f};
    s_axis_tvalid <= 1'b1               ;
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tuser <= 128'b0              ;
    s_axis_tlast <= 1'b0                ;
    for(i = 0;i<1;i=i+1)begin
        #(CYCLE)
        s_axis_tdata <= {
            bit_act_swap2[16*i+15 ],bit_act_swap2[16*i+14 ],bit_act_swap2[16*i+13 ],bit_act_swap2[16*i+12 ],
            bit_act_swap2[16*i+11 ],bit_act_swap2[16*i+10 ],bit_act_swap2[16*i+9  ],bit_act_swap2[16*i+8  ],
            bit_act_swap2[16*i+7  ],bit_act_swap2[16*i+6  ],bit_act_swap2[16*i+5  ],bit_act_swap2[16*i+4  ],
            bit_act_swap2[16*i+3  ],bit_act_swap2[16*i+2  ],bit_act_swap2[16*i+1  ],bit_act_swap2[16*i    ]
        };
        s_axis_tvalid <= 1'b1;
        s_axis_tkeep <= 64'hffffffffffffffff;
        s_axis_tuser <= 128'b0;
        if(i == 0)
            s_axis_tlast <= 1'b1;
        else
            s_axis_tlast <= 1'b0;
    end
    #(CYCLE)
    s_axis_tdata <= 256'd0;
    s_axis_tvalid <= 1'b0;
    s_axis_tkeep <= 64'h0;
    s_axis_tuser <= 128'b0;
    s_axis_tlast <= 1'b0;
    #(20*CYCLE)
/////////////////////////////////////////////bit_tcam_cfg1//////////////////////////////////////
    #(CYCLE);
    s_axis_tdata <= {256'h6f6fbc4c114000001a858e0000450008ff000081a66840486a3c888888888888};
    s_axis_tvalid <= 1'b1;
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tuser <= 128'h000000000000000000000000408000a0;
    s_axis_tlast <= 1'b0;
    #(CYCLE)
    // s_axis_tdata <= {256'h00000000000000000000000000000001000000007a00f2f13412dededede6f6f};
    s_axis_tdata <= {124'h0000000000000000000000000000000,vlan_id,8'h00,STAGE_ID4,BIT_TCAM_MOD_ID1,112'h00007a00f2f13412dededede6f6f};
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
    for(i = 0;i<16;i=i+1)begin
        #(CYCLE)
        s_axis_tdata <= {
            bit_tcam_cfg[2*i+1],bit_tcam_cfg[2*i]
        };
        s_axis_tvalid <= 1'b1;
        s_axis_tkeep <= 64'hffffffffffffffff;
        s_axis_tuser <= 128'b0;
        if(i == 15)
            s_axis_tlast <= 1'b1;
        else 
            s_axis_tlast <= 1'b0;
    end
    #(CYCLE)
    s_axis_tdata <= 256'd0;
    s_axis_tvalid <= 1'b0;
    s_axis_tkeep <= 64'h0;
    s_axis_tuser <= 128'b0;
    s_axis_tlast <= 1'b0;
    #(20*CYCLE)
/////////////////////////////////////////////bit_tcam_cfg2//////////////////////////////////////
    #(CYCLE);
    s_axis_tdata <= {256'h6f6fbc4c114000001a858e0000450008ff000081a66840486a3c888888888888};
    s_axis_tvalid <= 1'b1;
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tuser <= 128'h000000000000000000000000408000a0;
    s_axis_tlast <= 1'b0;
    #(CYCLE)
    // s_axis_tdata <= {256'h00000000000000000000000000000001000000007a00f2f13412dededede6f6f};
    s_axis_tdata <= {124'h0000000000000000000000000000000,vlan_id,8'h00,STAGE_ID4,BIT_TCAM_MOD_ID2,112'h00007a00f2f13412dededede6f6f};
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
    for(i = 0;i<16;i=i+1)begin
        #(CYCLE)
        s_axis_tdata <= {
            bit_tcam_cfg2[2*i+1],bit_tcam_cfg2[2*i]
        };
        s_axis_tvalid <= 1'b1;
        s_axis_tkeep <= 64'hffffffffffffffff;
        s_axis_tuser <= 128'b0;
        if(i == 15)
            s_axis_tlast <= 1'b1;
        else 
            s_axis_tlast <= 1'b0;
    end
    #(CYCLE)
    s_axis_tdata <= 256'd0;
    s_axis_tvalid <= 1'b0;
    s_axis_tkeep <= 64'h0;
    s_axis_tuser <= 128'b0;
    s_axis_tlast <= 1'b0;
    #(20*CYCLE)
// ///////////////////////////////////////////////////OFFBYTE:2^4=16,WIDTH = 8////////////////////////////////////  
    #(CYCLE);
    s_axis_tdata <= {256'h6f6fbc4c114000001a858e0000450008ff000081a66840486a3c888888888888};
    s_axis_tvalid <= 1'b1;
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tuser <= 128'h000000000000000000000000408000a0;
    s_axis_tlast <= 1'b0;
    #(CYCLE)
    // s_axis_tdata <= {256'h00000000000000000000000000000001000000007a00f2f13412dededede6f6f};
    s_axis_tdata <= {124'h0000000000000000000000000000000,vlan_id,8'h00,STAGE_ID0,OFFBYTE_ID,112'h00007a00f2f13412dededede6f6f};
    s_axis_tvalid <= 1'b1;
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tuser <= 128'b0;
    s_axis_tlast <= 1'b0;

    for(i=0;i<7;i= i+1) begin //parser_cfg
        #(CYCLE)
        s_axis_tdata <= {swap_s1_off_addr[i],swap_s1_off_byte[i]};
        s_axis_tvalid <= 1'b1;
        s_axis_tkeep <= 64'hffffffffffffffff;
        s_axis_tuser <= 128'b0;
        s_axis_tlast <= 1'b0;

    end
        
    #(CYCLE)
    s_axis_tdata <= 256'hffffffffffffffffffffffffffffffff;
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

    for(i=0;i<7;i= i+1) begin //parser_cfg //因为是两段半，所以用两个256来表示发完一组parser= 16X24的指令
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

//////////////////////////packet send from this time////////////////////////////////////////// 
    while(send_cnt < 117) begin
        @(posedge clk) begin
            if(rand) begin
                s_axis_tdata <= hexdata_swapped[send_cnt];
                s_axis_tvalid <= 1'b1;
                send_cnt <= send_cnt+1;
                if( (send_cnt == txt_mem_addr[1]-1 )||
                    (send_cnt == txt_mem_addr[2]-1 )||
                    (send_cnt == txt_mem_addr[3]-1 )||
                    (send_cnt == txt_mem_addr[4]-1 )||
                    (send_cnt == txt_mem_addr[5]-1 )||
                    (send_cnt == txt_mem_addr[6]-1 )||
                    (send_cnt == txt_mem_addr[7]-1 )||
                    (send_cnt == txt_mem_addr[8]-1 )||
                    (send_cnt == txt_mem_addr[9]-1 )||
                    (send_cnt == txt_mem_addr[10]-1)||
                    (send_cnt == txt_mem_addr[11]-1)||
                    (send_cnt == txt_mem_addr[12]-1)||
                    (send_cnt == txt_mem_addr[13]-1)||
                    (send_cnt == txt_mem_addr[14]-1)||
                    (send_cnt == txt_mem_addr[15]-1)||
                    (send_cnt == txt_mem_addr[16]-1)||
                    (send_cnt == txt_mem_addr[17]-1)||
                    (send_cnt == txt_mem_addr[18]-1))
                    s_axis_tlast <= 1'b1;
                else
                    s_axis_tlast <= 1'b0;

            end
            else begin
                s_axis_tdata <= s_axis_tdata;
                s_axis_tvalid <= 1'b0;
                send_cnt <= send_cnt;
                s_axis_tlast <= 1'b0;
            end
       end
    end
    #(CYCLE)
    send_cnt     <= 0;
    s_axis_tdata <= 256'd0;
    s_axis_tvalid <= 1'b0;
    s_axis_tkeep <= 64'h0;
    s_axis_tuser <= 128'b0;
    s_axis_tlast <= 1'b1;

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
