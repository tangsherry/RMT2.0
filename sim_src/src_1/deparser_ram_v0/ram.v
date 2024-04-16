`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/10/11 08:16:28
// Design Name: 
// Module Name: ram
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
//////////////////////////////////////////////////////////////////////////////////
//只要指令有效，修改指令对应偏移的8个字节
`define SUB_DEPARSE_2B_ODD(index) \
   i_wr_data2[mem_32breg_addr1_odd[index]]           = mem_val1_odd[index][7:0];  \

`define SUB_DEPARSE_2B_EVEN(index) \
   i_wr_data1[mem_32breg_addr1_even[index]]          = mem_val1_even[index][7:0];  \

module ram(
   input clk,
   input aresetn,
   input [255:0] i_ini_pkt_data0,//寄存器里的数据预先载入
   input [255:0] i_ini_pkt_data1,
   input [255:0] i_ini_pkt_data2,
   input [255:0] i_ini_pkt_data3,
   input [255:0] i_ini_pkt_data4,
   input [255:0] i_ini_pkt_data5,
   input [255:0] i_ini_pkt_data6,
   input [255:0] i_ini_pkt_data7, 
   input         i_reg_ini_str  ,//载入寄存器初始值，只保留一个初始值载入的状态，非持续性不变

   input [8*4-1:0]    i_val_odd,
   input [8*4-1:0]    i_val_even,
   input [2*4-1 :0]   i_val_type,
   input [8*4-1 :0]   i_val_offset_odd,
   input [8*4-1 :0]   i_val_offset_even,
   input [3:0]        i_val_end,//先来一步
   input [3:0]        i_val_valid,//判断数据是否变更
    

   output reg [255:0] o_pkt_data0,//组成256b输出
   output reg [255:0] o_pkt_data1,
   output reg [255:0] o_pkt_data2,
   output reg [255:0] o_pkt_data3,
   output reg [255:0] o_pkt_data4,
   output reg [255:0] o_pkt_data5,
   output reg [255:0] o_pkt_data6,
   output reg [255:0] o_pkt_data7,
   output reg         o_pkt_data_valid         //寄存器数据更新完成
   );

wire w_val_in;
reg r_reg_ini_str;
wire [8*4-1:0]  w_val1_odd;
wire [8*4-1:0]  w_val1_even;
wire [2*4-1 :0] w_val1_type;
wire [8*4-1 :0] w_val1_offset_odd;
wire [8*4-1 :0] w_val1_offset_even;
wire [3:0]      w_val1_valid;

assign w_val_in = (i_val_end == 4'hf)?1'b1:1'b0;//写入数据使能
always @(posedge clk) begin
    if(~aresetn) begin
        r_reg_ini_str <= 0;
    end
    else begin
        r_reg_ini_str <= i_reg_ini_str;
    end
end

//数据先进来，有效指令后进,后面的模块是数据后进来，指令先暂存
fallthrough_small_fifo #(
	.WIDTH(140),
	.MAX_DEPTH_BITS(4)
)
ram_val_fifo (
	.din				({i_val_odd,i_val_even, i_val_type,i_val_offset_odd,i_val_offset_even,i_val_valid}),
	.wr_en				(w_val_in),//after three clk data can be put to the line 
	//
	.rd_en				(reg_end ),//在切换前fifo数据已经出了
	.dout				({w_val1_odd,w_val1_even,w_val1_type,w_val1_offset_odd,w_val1_offset_even,w_val1_valid}),
	//
	.full				(),
	.prog_full			(),
	.nearly_full		(fst_half_fifo_full),
	.empty				(w_val_fifo_empty),
	.reset				(~aresetn),
	.clk				(clk)
);





reg [7:0]   i_wr_data2 [127:0];//奇数1，3
reg [7:0]   i_wr_data1 [127:0];//偶数0，2        

reg [3:0] r_val_valid1 ;
reg reg_end,reg_end_nxt;

genvar index;
//24个按32位偏偏移的起始地址
reg [7:0] mem_32breg_addr1_odd [3:0] ;//2B
reg [7:0] mem_32breg_addr1_even [3:0] ;//2B
    always @(posedge clk) begin
        if(~aresetn) begin
            mem_32breg_addr1_odd[ 0] <= 0;
            mem_32breg_addr1_odd[ 1] <= 0;
            mem_32breg_addr1_odd[ 2] <= 0;
            mem_32breg_addr1_odd[ 3] <= 0;
        end
        else if(r_reg_ini_str )begin
            mem_32breg_addr1_odd[ 0] <= w_val1_offset_odd[7 :0 ];
            mem_32breg_addr1_odd[ 1] <= w_val1_offset_odd[15: 8];
            mem_32breg_addr1_odd[ 2] <= w_val1_offset_odd[23:16];
            mem_32breg_addr1_odd[ 3] <= w_val1_offset_odd[31:24];
           
        end
        else begin
            mem_32breg_addr1_odd[ 0] <= mem_32breg_addr1_odd[ 0] ;
            mem_32breg_addr1_odd[ 1] <= mem_32breg_addr1_odd[ 1] ;
            mem_32breg_addr1_odd[ 2] <= mem_32breg_addr1_odd[ 2] ;
            mem_32breg_addr1_odd[ 3] <= mem_32breg_addr1_odd[ 3] ;
            
        end
    end

    always @(posedge clk) begin
        if(~aresetn) begin
            mem_32breg_addr1_even[ 0] <= 0;
            mem_32breg_addr1_even[ 1] <= 0;
            mem_32breg_addr1_even[ 2] <= 0;
            mem_32breg_addr1_even[ 3] <= 0;
        end
        else if(r_reg_ini_str )begin
            mem_32breg_addr1_even[ 0] <= w_val1_offset_even[7 :0 ];
            mem_32breg_addr1_even[ 1] <= w_val1_offset_even[15: 8];
            mem_32breg_addr1_even[ 2] <= w_val1_offset_even[23:16];
            mem_32breg_addr1_even[ 3] <= w_val1_offset_even[31:24];

        end
        else begin
            mem_32breg_addr1_even[ 0] <= mem_32breg_addr1_even[ 0]  ;
            mem_32breg_addr1_even[ 1] <= mem_32breg_addr1_even[ 1]  ;
            mem_32breg_addr1_even[ 2] <= mem_32breg_addr1_even[ 2]  ;
            mem_32breg_addr1_even[ 3] <= mem_32breg_addr1_even[ 3]  ;

        end
    end

//24个按64bit区分的容器数据
reg [7:0] mem_val1_odd [3:0] ;
   always @(posedge clk) begin
       if(~aresetn)begin
           mem_val1_odd[ 0] <= 0;
           mem_val1_odd[ 1] <= 0;
           mem_val1_odd[ 2] <= 0;
           mem_val1_odd[ 3] <= 0;
            
       end
       else if(r_reg_ini_str )begin
           mem_val1_odd[ 0] <= w_val1_odd[7  : 0];
           mem_val1_odd[ 1] <= w_val1_odd[15 : 8];
           mem_val1_odd[ 2] <= w_val1_odd[23 :16];
           mem_val1_odd[ 3] <= w_val1_odd[31 :24];
            
       end
       else begin
           mem_val1_odd[ 0] <= mem_val1_odd[ 0];
           mem_val1_odd[ 1] <= mem_val1_odd[ 1];
           mem_val1_odd[ 2] <= mem_val1_odd[ 2];
           mem_val1_odd[ 3] <= mem_val1_odd[ 3];
            
       end
   end 

   reg [7:0] mem_val1_even [3:0] ;
   always @(posedge clk) begin
       if(~aresetn)begin
           mem_val1_even[ 0] <= 0;
           mem_val1_even[ 1] <= 0;
           mem_val1_even[ 2] <= 0;
           mem_val1_even[ 3] <= 0;
            
       end
       else if(r_reg_ini_str )begin
           mem_val1_even[ 0] <= w_val1_even[7  : 0];
           mem_val1_even[ 1] <= w_val1_even[15 : 8];
           mem_val1_even[ 2] <= w_val1_even[23 :16];
           mem_val1_even[ 3] <= w_val1_even[31 :24];
            
       end
       else begin
           mem_val1_even[ 0] <= mem_val1_even[ 0];
           mem_val1_even[ 1] <= mem_val1_even[ 1];
           mem_val1_even[ 2] <= mem_val1_even[ 2];
           mem_val1_even[ 3] <= mem_val1_even[ 3];
            
       end
   end 

//原始数据按32bits，分64个放入RAM中
 reg [7:0] mem [255:0] ;
   always @(posedge clk) begin
       
       mem[ 0] <= i_ini_pkt_data0[7   :0  ];
       mem[ 1] <= i_ini_pkt_data0[15  :8  ];
       mem[ 2] <= i_ini_pkt_data0[23  :16 ];
       mem[ 3] <= i_ini_pkt_data0[31  :24 ];
       mem[ 4] <= i_ini_pkt_data0[39  :32 ];
       mem[ 5] <= i_ini_pkt_data0[47  :40 ];
       mem[ 6] <= i_ini_pkt_data0[55  :48 ];
       mem[ 7] <= i_ini_pkt_data0[63  :56 ];
       mem[ 8] <= i_ini_pkt_data0[71  :64 ];
       mem[ 9] <= i_ini_pkt_data0[79  :72 ];
       mem[10] <= i_ini_pkt_data0[87  :80 ];
       mem[11] <= i_ini_pkt_data0[95  :88 ];
       mem[12] <= i_ini_pkt_data0[103 :96 ];
       mem[13] <= i_ini_pkt_data0[111 :104];
       mem[14] <= i_ini_pkt_data0[119 :112];
       mem[15] <= i_ini_pkt_data0[127 :120];
       mem[16] <= i_ini_pkt_data0[135 :128];
       mem[17] <= i_ini_pkt_data0[143 :136];
       mem[18] <= i_ini_pkt_data0[151 :144];
       mem[19] <= i_ini_pkt_data0[159 :152];
       mem[20] <= i_ini_pkt_data0[167 :160];
       mem[21] <= i_ini_pkt_data0[175 :168];
       mem[22] <= i_ini_pkt_data0[183 :176];
       mem[23] <= i_ini_pkt_data0[191 :184];
       mem[24] <= i_ini_pkt_data0[199 :192];
       mem[25] <= i_ini_pkt_data0[207 :200];
       mem[26] <= i_ini_pkt_data0[215 :208];
       mem[27] <= i_ini_pkt_data0[223:216 ];
       mem[28] <= i_ini_pkt_data0[231:224 ];
       mem[29] <= i_ini_pkt_data0[239:232 ];
       mem[30] <= i_ini_pkt_data0[247:240 ];
       mem[31] <= i_ini_pkt_data0[255:248 ];

       mem[32] <= i_ini_pkt_data1[7   :0  ];
       mem[33] <= i_ini_pkt_data1[15  :8  ];
       mem[34] <= i_ini_pkt_data1[23  :16 ];
       mem[35] <= i_ini_pkt_data1[31  :24 ];
       mem[36] <= i_ini_pkt_data1[39  :32 ];
       mem[37] <= i_ini_pkt_data1[47  :40 ];
       mem[38] <= i_ini_pkt_data1[55  :48 ];                
       mem[39] <= i_ini_pkt_data1[63  :56 ];
       mem[40] <= i_ini_pkt_data1[71  :64 ];
       mem[41] <= i_ini_pkt_data1[79  :72 ];
       mem[42] <= i_ini_pkt_data1[87  :80 ];
       mem[43] <= i_ini_pkt_data1[95  :88 ];
       mem[44] <= i_ini_pkt_data1[103 :96 ];
       mem[45] <= i_ini_pkt_data1[111 :104];
       mem[46] <= i_ini_pkt_data1[119 :112];
       mem[47] <= i_ini_pkt_data1[127 :120];
       mem[48] <= i_ini_pkt_data1[135 :128];
       mem[49] <= i_ini_pkt_data1[143 :136];
       mem[50] <= i_ini_pkt_data1[151 :144];
       mem[51] <= i_ini_pkt_data1[159 :152];
       mem[52] <= i_ini_pkt_data1[167 :160];
       mem[53] <= i_ini_pkt_data1[175 :168];
       mem[54] <= i_ini_pkt_data1[183 :176];
       mem[55] <= i_ini_pkt_data1[191 :184];
       mem[56] <= i_ini_pkt_data1[199 :192];
       mem[57] <= i_ini_pkt_data1[207 :200];
       mem[58] <= i_ini_pkt_data1[215 :208];
       mem[59] <= i_ini_pkt_data1[223 :216];
       mem[60] <= i_ini_pkt_data1[231 :224];
       mem[61] <= i_ini_pkt_data1[239 :232];
       mem[62] <= i_ini_pkt_data1[247 :240];
       mem[63] <= i_ini_pkt_data1[255 :248];

       mem[64] <= i_ini_pkt_data2[7   :0  ];
       mem[65] <= i_ini_pkt_data2[15  :8  ];
       mem[66] <= i_ini_pkt_data2[23  :16 ];
       mem[67] <= i_ini_pkt_data2[31  :24 ];
       mem[68] <= i_ini_pkt_data2[39  :32 ];
       mem[69] <= i_ini_pkt_data2[47  :40 ];
       mem[70] <= i_ini_pkt_data2[55  :48 ];
       mem[71] <= i_ini_pkt_data2[63  :56 ];
       mem[72] <= i_ini_pkt_data2[71  :64 ];
       mem[73] <= i_ini_pkt_data2[79  :72 ];
       mem[74] <= i_ini_pkt_data2[87  :80 ];
       mem[75] <= i_ini_pkt_data2[95  :88 ];
       mem[76] <= i_ini_pkt_data2[103 :96 ];
       mem[77] <= i_ini_pkt_data2[111 :104];
       mem[78] <= i_ini_pkt_data2[119 :112];
       mem[79] <= i_ini_pkt_data2[127 :120];
       mem[80] <= i_ini_pkt_data2[135 :128];
       mem[81] <= i_ini_pkt_data2[143 :136];
       mem[82] <= i_ini_pkt_data2[151 :144];
       mem[83] <= i_ini_pkt_data2[159 :152];
       mem[84] <= i_ini_pkt_data2[167 :160];
       mem[85] <= i_ini_pkt_data2[175 :168];
       mem[86] <= i_ini_pkt_data2[183 :176];
       mem[87] <= i_ini_pkt_data2[191 :184];
       mem[88] <= i_ini_pkt_data2[199 :192];
       mem[89] <= i_ini_pkt_data2[207 :200];
       mem[90] <= i_ini_pkt_data2[215 :208];
       mem[91] <= i_ini_pkt_data2[223:216 ];
       mem[92] <= i_ini_pkt_data2[231:224 ];
       mem[93] <= i_ini_pkt_data2[239:232 ];
       mem[94] <= i_ini_pkt_data2[247:240 ];
       mem[95] <= i_ini_pkt_data2[255:248 ];

       mem[96 ] <= i_ini_pkt_data3[7   :0  ];
       mem[97 ] <= i_ini_pkt_data3[15  :8  ];
       mem[98 ] <= i_ini_pkt_data3[23  :16 ];
       mem[99 ] <= i_ini_pkt_data3[31  :24 ];
       mem[100] <= i_ini_pkt_data3[39  :32 ];
       mem[101] <= i_ini_pkt_data3[47  :40 ];
       mem[102] <= i_ini_pkt_data3[55  :48 ];
       mem[103] <= i_ini_pkt_data3[63  :56 ];
       mem[104] <= i_ini_pkt_data3[71  :64 ];
       mem[105] <= i_ini_pkt_data3[79  :72 ];
       mem[106] <= i_ini_pkt_data3[87  :80 ];
       mem[107] <= i_ini_pkt_data3[95  :88 ];
       mem[108] <= i_ini_pkt_data3[103 :96 ];
       mem[109] <= i_ini_pkt_data3[111 :104];
       mem[110] <= i_ini_pkt_data3[119 :112];
       mem[111] <= i_ini_pkt_data3[127 :120];
       mem[112] <= i_ini_pkt_data3[135 :128];
       mem[113] <= i_ini_pkt_data3[143 :136];
       mem[114] <= i_ini_pkt_data3[151 :144];
       mem[115] <= i_ini_pkt_data3[159 :152];
       mem[116] <= i_ini_pkt_data3[167 :160];
       mem[117] <= i_ini_pkt_data3[175 :168];
       mem[118] <= i_ini_pkt_data3[183 :176];
       mem[119] <= i_ini_pkt_data3[191 :184];
       mem[120] <= i_ini_pkt_data3[199 :192];
       mem[121] <= i_ini_pkt_data3[207 :200];
       mem[122] <= i_ini_pkt_data3[215 :208];
       mem[123] <= i_ini_pkt_data3[223 :216];
       mem[124] <= i_ini_pkt_data3[231 :224];
       mem[125] <= i_ini_pkt_data3[239 :232];
       mem[126] <= i_ini_pkt_data3[247 :240];
       mem[127] <= i_ini_pkt_data3[255 :248];

       mem[128] <= i_ini_pkt_data4[7   :0  ];
       mem[129] <= i_ini_pkt_data4[15  :8  ];
       mem[130] <= i_ini_pkt_data4[23  :16 ];
       mem[131] <= i_ini_pkt_data4[31  :24 ];
       mem[132] <= i_ini_pkt_data4[39  :32 ];
       mem[133] <= i_ini_pkt_data4[47  :40 ];
       mem[134] <= i_ini_pkt_data4[55  :48 ];
       mem[135] <= i_ini_pkt_data4[63  :56 ];
       mem[136] <= i_ini_pkt_data4[71  :64 ];
       mem[137] <= i_ini_pkt_data4[79  :72 ];
       mem[138] <= i_ini_pkt_data4[87  :80 ];
       mem[139] <= i_ini_pkt_data4[95  :88 ];
       mem[140] <= i_ini_pkt_data4[103 :96 ];
       mem[141] <= i_ini_pkt_data4[111 :104];
       mem[142] <= i_ini_pkt_data4[119 :112];
       mem[143] <= i_ini_pkt_data4[127 :120];
       mem[144] <= i_ini_pkt_data4[135 :128];
       mem[145] <= i_ini_pkt_data4[143 :136];
       mem[146] <= i_ini_pkt_data4[151 :144];
       mem[147] <= i_ini_pkt_data4[159 :152];
       mem[148] <= i_ini_pkt_data4[167 :160];
       mem[149] <= i_ini_pkt_data4[175 :168];
       mem[150] <= i_ini_pkt_data4[183 :176];
       mem[151] <= i_ini_pkt_data4[191 :184];
       mem[152] <= i_ini_pkt_data4[199 :192];
       mem[153] <= i_ini_pkt_data4[207 :200];
       mem[154] <= i_ini_pkt_data4[215 :208];
       mem[155] <= i_ini_pkt_data4[223 :216];
       mem[156] <= i_ini_pkt_data4[231 :224];
       mem[157] <= i_ini_pkt_data4[239 :232];
       mem[158] <= i_ini_pkt_data4[247 :240];
       mem[159] <= i_ini_pkt_data4[255 :248];

       mem[160] <= i_ini_pkt_data5[7   :0  ];
       mem[161] <= i_ini_pkt_data5[15  :8  ];
       mem[162] <= i_ini_pkt_data5[23  :16 ];
       mem[163] <= i_ini_pkt_data5[31  :24 ];
       mem[164] <= i_ini_pkt_data5[39  :32 ];
       mem[165] <= i_ini_pkt_data5[47  :40 ];
       mem[166] <= i_ini_pkt_data5[55  :48 ];
       mem[167] <= i_ini_pkt_data5[63  :56 ];
       mem[168] <= i_ini_pkt_data5[71  :64 ];
       mem[169] <= i_ini_pkt_data5[79  :72 ];
       mem[170] <= i_ini_pkt_data5[87  :80 ];
       mem[171] <= i_ini_pkt_data5[95  :88 ];
       mem[172] <= i_ini_pkt_data5[103 :96 ];
       mem[173] <= i_ini_pkt_data5[111 :104];
       mem[174] <= i_ini_pkt_data5[119 :112];
       mem[175] <= i_ini_pkt_data5[127 :120];
       mem[176] <= i_ini_pkt_data5[135 :128];
       mem[177] <= i_ini_pkt_data5[143 :136];
       mem[178] <= i_ini_pkt_data5[151 :144];
       mem[179] <= i_ini_pkt_data5[159 :152];
       mem[180] <= i_ini_pkt_data5[167 :160];
       mem[181] <= i_ini_pkt_data5[175 :168];
       mem[182] <= i_ini_pkt_data5[183 :176];
       mem[183] <= i_ini_pkt_data5[191 :184];
       mem[184] <= i_ini_pkt_data5[199 :192];
       mem[185] <= i_ini_pkt_data5[207 :200];
       mem[186] <= i_ini_pkt_data5[215 :208];
       mem[187] <= i_ini_pkt_data5[223 :216];
       mem[188] <= i_ini_pkt_data5[231 :224];
       mem[189] <= i_ini_pkt_data5[239 :232];
       mem[190] <= i_ini_pkt_data5[247 :240];
       mem[191] <= i_ini_pkt_data5[255 :248]; 

       mem[192] <= i_ini_pkt_data6[7   :0  ];
       mem[193] <= i_ini_pkt_data6[15  :8  ];
       mem[194] <= i_ini_pkt_data6[23  :16 ];
       mem[195] <= i_ini_pkt_data6[31  :24 ];
       mem[196] <= i_ini_pkt_data6[39  :32 ];
       mem[197] <= i_ini_pkt_data6[47  :40 ];
       mem[198] <= i_ini_pkt_data6[55  :48 ];
       mem[199] <= i_ini_pkt_data6[63  :56 ];
       mem[200] <= i_ini_pkt_data6[71  :64 ];
       mem[201] <= i_ini_pkt_data6[79  :72 ];
       mem[202] <= i_ini_pkt_data6[87  :80 ];
       mem[203] <= i_ini_pkt_data6[95  :88 ];
       mem[204] <= i_ini_pkt_data6[103 :96 ];
       mem[205] <= i_ini_pkt_data6[111 :104];
       mem[206] <= i_ini_pkt_data6[119 :112];
       mem[207] <= i_ini_pkt_data6[127 :120];
       mem[208] <= i_ini_pkt_data6[135 :128];
       mem[209] <= i_ini_pkt_data6[143 :136];
       mem[210] <= i_ini_pkt_data6[151 :144];
       mem[211] <= i_ini_pkt_data6[159 :152];
       mem[212] <= i_ini_pkt_data6[167 :160];
       mem[213] <= i_ini_pkt_data6[175 :168];
       mem[214] <= i_ini_pkt_data6[183 :176];
       mem[215] <= i_ini_pkt_data6[191 :184];
       mem[216] <= i_ini_pkt_data6[199 :192];
       mem[217] <= i_ini_pkt_data6[207 :200];
       mem[218] <= i_ini_pkt_data6[215 :208];
       mem[219] <= i_ini_pkt_data6[223 :216];
       mem[220] <= i_ini_pkt_data6[231 :224];
       mem[221] <= i_ini_pkt_data6[239 :232];
       mem[222] <= i_ini_pkt_data6[247 :240];
       mem[223] <= i_ini_pkt_data6[255 :248];

       mem[224] <= i_ini_pkt_data7[7   :0  ];
       mem[225] <= i_ini_pkt_data7[15  :8  ];
       mem[226] <= i_ini_pkt_data7[23  :16 ];
       mem[227] <= i_ini_pkt_data7[31  :24 ];
       mem[228] <= i_ini_pkt_data7[39  :32 ];
       mem[229] <= i_ini_pkt_data7[47  :40 ];
       mem[230] <= i_ini_pkt_data7[55  :48 ];
       mem[231] <= i_ini_pkt_data7[63  :56 ];
       mem[232] <= i_ini_pkt_data7[71  :64 ];
       mem[233] <= i_ini_pkt_data7[79  :72 ];
       mem[234] <= i_ini_pkt_data7[87  :80 ];
       mem[235] <= i_ini_pkt_data7[95  :88 ];
       mem[236] <= i_ini_pkt_data7[103 :96 ];
       mem[237] <= i_ini_pkt_data7[111 :104];
       mem[238] <= i_ini_pkt_data7[119 :112];
       mem[239] <= i_ini_pkt_data7[127 :120];
       mem[240] <= i_ini_pkt_data7[135 :128];
       mem[241] <= i_ini_pkt_data7[143 :136];
       mem[242] <= i_ini_pkt_data7[151 :144];
       mem[243] <= i_ini_pkt_data7[159 :152];
       mem[244] <= i_ini_pkt_data7[167 :160];
       mem[245] <= i_ini_pkt_data7[175 :168];
       mem[246] <= i_ini_pkt_data7[183 :176];
       mem[247] <= i_ini_pkt_data7[191 :184];
       mem[248] <= i_ini_pkt_data7[199 :192];
       mem[249] <= i_ini_pkt_data7[207 :200];
       mem[250] <= i_ini_pkt_data7[215 :208];
       mem[251] <= i_ini_pkt_data7[223 :216];
       mem[252] <= i_ini_pkt_data7[231 :224];
       mem[253] <= i_ini_pkt_data7[239 :232];
       mem[254] <= i_ini_pkt_data7[247 :240];
       mem[255] <= i_ini_pkt_data7[255 :248]; 
       
   end

/////////////////////////////////////////////
always @(posedge clk) begin
   if(~aresetn) begin
       r_val_valid1 <= 0;
   end
   else begin
       if(r_reg_ini_str ) begin
           r_val_valid1   <= w_val1_valid[3:0];
       end
       else begin
           r_val_valid1   <= 4'h0;
       end
   end
end

reg[2:0] state,state_next;
reg [2:0] state_cs;
localparam IDLE=0, DEPARSER_2B= 1,DEPARSER_2B_END=2;
localparam CS_IDLE=0, CS_DEPARSER_2B= 1;
 
always @(posedge clk) begin
   if(~aresetn)begin
       state <= IDLE;
       reg_end <= 1'b0;
   end
   else begin
       state <= state_next;
       reg_end     <= reg_end_nxt; //寄存器数据更新完成
   end
end

///////////////////////////////////////////////////////////////////
always @(*) begin
   state_next = state;
   reg_end_nxt = 0;
   case(state)
       IDLE:begin
           if(r_reg_ini_str == 1'b1)//如果容器逆解析结束，则执行放回
               state_next = DEPARSER_2B;
           else begin
               state_next = IDLE;
           end
       end
       DEPARSER_2B:begin
           `SUB_DEPARSE_2B_ODD(0 )
           `SUB_DEPARSE_2B_EVEN(0 )
           `SUB_DEPARSE_2B_ODD(1 )
           `SUB_DEPARSE_2B_EVEN(1 )
           `SUB_DEPARSE_2B_ODD(2 )
           `SUB_DEPARSE_2B_EVEN(2 )
           `SUB_DEPARSE_2B_ODD(3 )
           `SUB_DEPARSE_2B_EVEN(3 )
           state_next = DEPARSER_2B_END;
       end
       DEPARSER_2B_END:begin
           reg_end_nxt = 1;
           state_next = IDLE;
       end
       default:begin
           state_next = IDLE;
       end
   endcase
end

reg [127:0] i_cs_odd_0,i_cs_odd_1,i_cs_odd_2,i_cs_odd_3;
reg [127:0] i_cs_even_0,i_cs_even_1,i_cs_even_2,i_cs_even_3;
always @(posedge clk ) begin
   if(~aresetn) begin
        state_cs    <= CS_IDLE;
        i_cs_odd_0  <= 128'd0;
        i_cs_even_0 <= 128'd0;
        i_cs_odd_1  <= 128'd0;
        i_cs_even_1 <= 128'd0;
        i_cs_odd_2  <= 128'd0;
        i_cs_even_2 <= 128'd0;
        i_cs_odd_3  <= 128'd0;
        i_cs_even_3 <= 128'd0;
   end
   else begin
       case(state_cs)
           CS_IDLE:begin
           if(r_reg_ini_str == 1'b1)
               state_cs <= CS_DEPARSER_2B;
           else begin
               state_cs    <= CS_IDLE;
               i_cs_odd_0  <= 128'd0;
               i_cs_even_0 <= 128'd0;
               i_cs_odd_1  <= 128'd0;
               i_cs_even_1 <= 128'd0;
               i_cs_odd_2  <= 128'd0;
               i_cs_even_2 <= 128'd0;
               i_cs_odd_3  <= 128'd0;
               i_cs_even_3 <= 128'd0;
           end
       end
        
       CS_DEPARSER_2B: begin
           if(r_val_valid1[0])begin 
               i_cs_odd_0[mem_32breg_addr1_odd[0]]        <= 1'b1;
               i_cs_even_0[mem_32breg_addr1_even[0]]      <= 1'b1;
           end 
           else begin 
               i_cs_odd_0[mem_32breg_addr1_odd[0]]        <= 1'b0;
               i_cs_even_0[mem_32breg_addr1_even[0]]      <= 1'b0;
           end
           if(r_val_valid1[1])begin 
               i_cs_odd_1[mem_32breg_addr1_odd[1]]        <= 1'b1;
               i_cs_even_1[mem_32breg_addr1_even[1]]      <= 1'b1;
           end 
           else begin 
               i_cs_odd_1[mem_32breg_addr1_odd[1]]        <= 1'b0;
               i_cs_even_1[mem_32breg_addr1_even[1]]      <= 1'b0;
           end 
           if(r_val_valid1[2])begin 
               i_cs_odd_2[mem_32breg_addr1_odd[2]]        <= 1'b1;
               i_cs_even_2[mem_32breg_addr1_even[2]]      <= 1'b1;
           end 
           else begin 
               i_cs_odd_2[mem_32breg_addr1_odd[2]]        <= 1'b0;
               i_cs_even_2[mem_32breg_addr1_even[2]]      <= 1'b0;
           end 
           if(r_val_valid1[3])begin 
               i_cs_odd_3[mem_32breg_addr1_odd[3]]        <= 1'b1;
               i_cs_even_3[mem_32breg_addr1_even[3]]      <= 1'b1;
           end 
           else begin 
               i_cs_odd_3[mem_32breg_addr1_odd[3]]        <= 1'b0;
               i_cs_even_3[mem_32breg_addr1_even[3]]      <= 1'b0;
           end  
           state_cs <= CS_IDLE;
       end 
        
       default:begin
           state_cs <= CS_IDLE;
       end
        
       endcase
   end
end

wire [127:0] i_cs1;
wire [127:0] i_cs2;
assign i_cs1 = i_cs_even_0 | i_cs_even_1 | i_cs_even_2 |i_cs_even_3;
assign i_cs2 = i_cs_odd_0 | i_cs_odd_1 | i_cs_odd_2 |i_cs_odd_3;

 wire [7:0]  w_RegRw_00_dout,w_RegRw_01_dout,w_RegRw_02_dout,w_RegRw_03_dout;
 wire [7:0]  w_RegRw_04_dout,w_RegRw_05_dout,w_RegRw_06_dout,w_RegRw_07_dout;
 wire [7:0]  w_RegRw_08_dout,w_RegRw_09_dout,w_RegRw_10_dout,w_RegRw_11_dout;
 wire [7:0]  w_RegRw_12_dout,w_RegRw_13_dout,w_RegRw_14_dout,w_RegRw_15_dout;
 wire [7:0]  w_RegRw_16_dout,w_RegRw_17_dout,w_RegRw_18_dout,w_RegRw_19_dout;
 wire [7:0]  w_RegRw_20_dout,w_RegRw_21_dout,w_RegRw_22_dout,w_RegRw_23_dout;
 wire [7:0]  w_RegRw_24_dout,w_RegRw_25_dout,w_RegRw_26_dout,w_RegRw_27_dout;
 wire [7:0]  w_RegRw_28_dout,w_RegRw_29_dout,w_RegRw_30_dout,w_RegRw_31_dout;
 wire [7:0]  w_RegRw_32_dout,w_RegRw_33_dout,w_RegRw_34_dout,w_RegRw_35_dout;
 wire [7:0]  w_RegRw_36_dout,w_RegRw_37_dout,w_RegRw_38_dout,w_RegRw_39_dout;
 wire [7:0]  w_RegRw_40_dout,w_RegRw_41_dout,w_RegRw_42_dout,w_RegRw_43_dout;
 wire [7:0]  w_RegRw_44_dout,w_RegRw_45_dout,w_RegRw_46_dout,w_RegRw_47_dout;
 wire [7:0]  w_RegRw_48_dout,w_RegRw_49_dout,w_RegRw_50_dout,w_RegRw_51_dout;
 wire [7:0]  w_RegRw_52_dout,w_RegRw_53_dout,w_RegRw_54_dout,w_RegRw_55_dout;
 wire [7:0]  w_RegRw_56_dout,w_RegRw_57_dout,w_RegRw_58_dout,w_RegRw_59_dout;
 wire [7:0]  w_RegRw_60_dout,w_RegRw_61_dout,w_RegRw_62_dout,w_RegRw_63_dout;

 wire [7:0]  w_RegRw_64_dout ,w_RegRw_65_dout ,w_RegRw_66_dout ,w_RegRw_67_dout ;
 wire [7:0]  w_RegRw_68_dout ,w_RegRw_69_dout ,w_RegRw_70_dout ,w_RegRw_71_dout ;
 wire [7:0]  w_RegRw_72_dout ,w_RegRw_73_dout ,w_RegRw_74_dout ,w_RegRw_75_dout ;
 wire [7:0]  w_RegRw_76_dout ,w_RegRw_77_dout ,w_RegRw_78_dout ,w_RegRw_79_dout ;
 wire [7:0]  w_RegRw_80_dout ,w_RegRw_81_dout ,w_RegRw_82_dout ,w_RegRw_83_dout ;
 wire [7:0]  w_RegRw_84_dout ,w_RegRw_85_dout ,w_RegRw_86_dout ,w_RegRw_87_dout ;
 wire [7:0]  w_RegRw_88_dout ,w_RegRw_89_dout ,w_RegRw_90_dout ,w_RegRw_91_dout ;
 wire [7:0]  w_RegRw_92_dout ,w_RegRw_93_dout ,w_RegRw_94_dout ,w_RegRw_95_dout ;
 wire [7:0]  w_RegRw_96_dout ,w_RegRw_97_dout ,w_RegRw_98_dout ,w_RegRw_99_dout ;
 wire [7:0]  w_RegRw_100_dout,w_RegRw_101_dout,w_RegRw_102_dout,w_RegRw_103_dout;
 wire [7:0]  w_RegRw_104_dout,w_RegRw_105_dout,w_RegRw_106_dout,w_RegRw_107_dout;
 wire [7:0]  w_RegRw_108_dout,w_RegRw_109_dout,w_RegRw_110_dout,w_RegRw_111_dout;
 wire [7:0]  w_RegRw_112_dout,w_RegRw_113_dout,w_RegRw_114_dout,w_RegRw_115_dout;
 wire [7:0]  w_RegRw_116_dout,w_RegRw_117_dout,w_RegRw_118_dout,w_RegRw_119_dout;
 wire [7:0]  w_RegRw_120_dout,w_RegRw_121_dout,w_RegRw_122_dout,w_RegRw_123_dout;
 wire [7:0]  w_RegRw_124_dout,w_RegRw_125_dout,w_RegRw_126_dout,w_RegRw_127_dout;

 wire [7:0]  w_RegRw_128_dout ,w_RegRw_129_dout ,w_RegRw_130_dout ,w_RegRw_131_dout;
 wire [7:0]  w_RegRw_132_dout ,w_RegRw_133_dout ,w_RegRw_134_dout ,w_RegRw_135_dout;
 wire [7:0]  w_RegRw_136_dout ,w_RegRw_137_dout ,w_RegRw_138_dout ,w_RegRw_139_dout;
 wire [7:0]  w_RegRw_140_dout ,w_RegRw_141_dout ,w_RegRw_142_dout ,w_RegRw_143_dout;
 wire [7:0]  w_RegRw_144_dout ,w_RegRw_145_dout ,w_RegRw_146_dout ,w_RegRw_147_dout;
 wire [7:0]  w_RegRw_148_dout ,w_RegRw_149_dout ,w_RegRw_150_dout ,w_RegRw_151_dout;
 wire [7:0]  w_RegRw_152_dout ,w_RegRw_153_dout ,w_RegRw_154_dout ,w_RegRw_155_dout;
 wire [7:0]  w_RegRw_156_dout ,w_RegRw_157_dout ,w_RegRw_158_dout ,w_RegRw_159_dout;
 wire [7:0]  w_RegRw_160_dout ,w_RegRw_161_dout ,w_RegRw_162_dout ,w_RegRw_163_dout;
 wire [7:0]  w_RegRw_164_dout ,w_RegRw_165_dout ,w_RegRw_166_dout ,w_RegRw_167_dout;
 wire [7:0]  w_RegRw_168_dout ,w_RegRw_169_dout ,w_RegRw_170_dout ,w_RegRw_171_dout;
 wire [7:0]  w_RegRw_172_dout ,w_RegRw_173_dout ,w_RegRw_174_dout ,w_RegRw_175_dout;
 wire [7:0]  w_RegRw_176_dout ,w_RegRw_177_dout ,w_RegRw_178_dout ,w_RegRw_179_dout;
 wire [7:0]  w_RegRw_180_dout ,w_RegRw_181_dout ,w_RegRw_182_dout ,w_RegRw_183_dout;
 wire [7:0]  w_RegRw_184_dout ,w_RegRw_185_dout ,w_RegRw_186_dout ,w_RegRw_187_dout;
 wire [7:0]  w_RegRw_188_dout ,w_RegRw_189_dout ,w_RegRw_190_dout ,w_RegRw_191_dout;

 wire [7:0]  w_RegRw_192_dout ,w_RegRw_193_dout ,w_RegRw_194_dout ,w_RegRw_195_dout ;
 wire [7:0]  w_RegRw_196_dout ,w_RegRw_197_dout ,w_RegRw_198_dout ,w_RegRw_199_dout ;
 wire [7:0]  w_RegRw_200_dout ,w_RegRw_201_dout ,w_RegRw_202_dout ,w_RegRw_203_dout ;
 wire [7:0]  w_RegRw_204_dout ,w_RegRw_205_dout ,w_RegRw_206_dout ,w_RegRw_207_dout ;
 wire [7:0]  w_RegRw_208_dout ,w_RegRw_209_dout ,w_RegRw_210_dout ,w_RegRw_211_dout ;
 wire [7:0]  w_RegRw_212_dout ,w_RegRw_213_dout ,w_RegRw_214_dout ,w_RegRw_215_dout ;
 wire [7:0]  w_RegRw_216_dout ,w_RegRw_217_dout ,w_RegRw_218_dout ,w_RegRw_219_dout ;
 wire [7:0]  w_RegRw_220_dout ,w_RegRw_221_dout ,w_RegRw_222_dout ,w_RegRw_223_dout ;
 wire [7:0]  w_RegRw_224_dout ,w_RegRw_225_dout ,w_RegRw_226_dout ,w_RegRw_227_dout ;
 wire [7:0]  w_RegRw_228_dout ,w_RegRw_229_dout ,w_RegRw_230_dout ,w_RegRw_231_dout ;
 wire [7:0]  w_RegRw_232_dout ,w_RegRw_233_dout ,w_RegRw_234_dout ,w_RegRw_235_dout ;
 wire [7:0]  w_RegRw_236_dout ,w_RegRw_237_dout ,w_RegRw_238_dout ,w_RegRw_239_dout ;
 wire [7:0]  w_RegRw_240_dout ,w_RegRw_241_dout ,w_RegRw_242_dout ,w_RegRw_243_dout ;
 wire [7:0]  w_RegRw_244_dout ,w_RegRw_245_dout ,w_RegRw_246_dout ,w_RegRw_247_dout ;
 wire [7:0]  w_RegRw_248_dout ,w_RegRw_249_dout ,w_RegRw_250_dout ,w_RegRw_251_dout ;
 wire [7:0]  w_RegRw_252_dout ,w_RegRw_253_dout ,w_RegRw_254_dout ,w_RegRw_255_dout ;

 reg_rw_v1_0  U_RegRw_00 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[  0]),.i_ini_value(mem[  0]),.i_wdat(i_wr_data1[  0]),.o_reg(w_RegRw_00_dout  ));
 reg_rw_v1_0  U_RegRw_01 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[  0]),.i_ini_value(mem[  1]),.i_wdat(i_wr_data2[  0]),.o_reg(w_RegRw_01_dout  ));
 reg_rw_v1_0  U_RegRw_02 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[  1]),.i_ini_value(mem[  2]),.i_wdat(i_wr_data1[  1]),.o_reg(w_RegRw_02_dout  ));//7 open,and 9 close
 reg_rw_v1_0  U_RegRw_03 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[  1]),.i_ini_value(mem[  3]),.i_wdat(i_wr_data2[  1]),.o_reg(w_RegRw_03_dout  ));
 reg_rw_v1_0  U_RegRw_04 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[  2]),.i_ini_value(mem[  4]),.i_wdat(i_wr_data1[  2]),.o_reg(w_RegRw_04_dout  ));
 reg_rw_v1_0  U_RegRw_05 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[  2]),.i_ini_value(mem[  5]),.i_wdat(i_wr_data2[  2]),.o_reg(w_RegRw_05_dout  ));//
 reg_rw_v1_0  U_RegRw_06 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[  3]),.i_ini_value(mem[  6]),.i_wdat(i_wr_data1[  3]),.o_reg(w_RegRw_06_dout  ));//
 reg_rw_v1_0  U_RegRw_07 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[  3]),.i_ini_value(mem[  7]),.i_wdat(i_wr_data2[  3]),.o_reg(w_RegRw_07_dout  ));
 reg_rw_v1_0  U_RegRw_08 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[  4]),.i_ini_value(mem[  8]),.i_wdat(i_wr_data1[  4]),.o_reg(w_RegRw_08_dout  ));
 reg_rw_v1_0  U_RegRw_09 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[  4]),.i_ini_value(mem[  9]),.i_wdat(i_wr_data2[  4]),.o_reg(w_RegRw_09_dout  ));
 reg_rw_v1_0  U_RegRw_10 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[  5]),.i_ini_value(mem[ 10]),.i_wdat(i_wr_data1[  5]),.o_reg(w_RegRw_10_dout  ));
 reg_rw_v1_0  U_RegRw_11 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[  5]),.i_ini_value(mem[ 11]),.i_wdat(i_wr_data2[  5]),.o_reg(w_RegRw_11_dout  ));
 reg_rw_v1_0  U_RegRw_12 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[  6]),.i_ini_value(mem[ 12]),.i_wdat(i_wr_data1[  6]),.o_reg(w_RegRw_12_dout  ));
 reg_rw_v1_0  U_RegRw_13 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[  6]),.i_ini_value(mem[ 13]),.i_wdat(i_wr_data2[  6]),.o_reg(w_RegRw_13_dout  ));
 reg_rw_v1_0  U_RegRw_14 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[  7]),.i_ini_value(mem[ 14]),.i_wdat(i_wr_data1[  7]),.o_reg(w_RegRw_14_dout  ));
 reg_rw_v1_0  U_RegRw_15 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[  7]),.i_ini_value(mem[ 15]),.i_wdat(i_wr_data2[  7]),.o_reg(w_RegRw_15_dout  ));
 reg_rw_v1_0  U_RegRw_16 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[  8]),.i_ini_value(mem[ 16]),.i_wdat(i_wr_data1[  8]),.o_reg(w_RegRw_16_dout  ));
 reg_rw_v1_0  U_RegRw_17 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[  8]),.i_ini_value(mem[ 17]),.i_wdat(i_wr_data2[  8]),.o_reg(w_RegRw_17_dout  ));
 reg_rw_v1_0  U_RegRw_18 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[  9]),.i_ini_value(mem[ 18]),.i_wdat(i_wr_data1[  9]),.o_reg(w_RegRw_18_dout  ));
 reg_rw_v1_0  U_RegRw_19 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[  9]),.i_ini_value(mem[ 19]),.i_wdat(i_wr_data2[  9]),.o_reg(w_RegRw_19_dout  ));
 reg_rw_v1_0  U_RegRw_20 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[ 10]),.i_ini_value(mem[ 20]),.i_wdat(i_wr_data1[ 10]),.o_reg(w_RegRw_20_dout  ));
 reg_rw_v1_0  U_RegRw_21 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[ 10]),.i_ini_value(mem[ 21]),.i_wdat(i_wr_data2[ 10]),.o_reg(w_RegRw_21_dout  ));
 reg_rw_v1_0  U_RegRw_22 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[ 11]),.i_ini_value(mem[ 22]),.i_wdat(i_wr_data1[ 11]),.o_reg(w_RegRw_22_dout  ));
 reg_rw_v1_0  U_RegRw_23 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[ 11]),.i_ini_value(mem[ 23]),.i_wdat(i_wr_data2[ 11]),.o_reg(w_RegRw_23_dout  ));
 reg_rw_v1_0  U_RegRw_24 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[ 12]),.i_ini_value(mem[ 24]),.i_wdat(i_wr_data1[ 12]),.o_reg(w_RegRw_24_dout  ));
 reg_rw_v1_0  U_RegRw_25 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[ 12]),.i_ini_value(mem[ 25]),.i_wdat(i_wr_data2[ 12]),.o_reg(w_RegRw_25_dout  ));
 reg_rw_v1_0  U_RegRw_26 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[ 13]),.i_ini_value(mem[ 26]),.i_wdat(i_wr_data1[ 13]),.o_reg(w_RegRw_26_dout  ));
 reg_rw_v1_0  U_RegRw_27 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[ 13]),.i_ini_value(mem[ 27]),.i_wdat(i_wr_data2[ 13]),.o_reg(w_RegRw_27_dout  ));
 reg_rw_v1_0  U_RegRw_28 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[ 14]),.i_ini_value(mem[ 28]),.i_wdat(i_wr_data1[ 14]),.o_reg(w_RegRw_28_dout  ));
 reg_rw_v1_0  U_RegRw_29 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[ 14]),.i_ini_value(mem[ 29]),.i_wdat(i_wr_data2[ 14]),.o_reg(w_RegRw_29_dout  ));
 reg_rw_v1_0  U_RegRw_30 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[ 15]),.i_ini_value(mem[ 30]),.i_wdat(i_wr_data1[ 15]),.o_reg(w_RegRw_30_dout  ));
 reg_rw_v1_0  U_RegRw_31 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[ 15]),.i_ini_value(mem[ 31]),.i_wdat(i_wr_data2[ 15]),.o_reg(w_RegRw_31_dout  ));
  
 reg_rw_v1_0  U_RegRw_32 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[ 16]),.i_ini_value(mem[ 32]),.i_wdat(i_wr_data1[ 16]),.o_reg(w_RegRw_32_dout  ));
 reg_rw_v1_0  U_RegRw_33 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[ 16]),.i_ini_value(mem[ 33]),.i_wdat(i_wr_data2[ 16]),.o_reg(w_RegRw_33_dout  ));
 reg_rw_v1_0  U_RegRw_34 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[ 17]),.i_ini_value(mem[ 34]),.i_wdat(i_wr_data1[ 17]),.o_reg(w_RegRw_34_dout  ));
 reg_rw_v1_0  U_RegRw_35 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[ 17]),.i_ini_value(mem[ 35]),.i_wdat(i_wr_data2[ 17]),.o_reg(w_RegRw_35_dout  ));
 reg_rw_v1_0  U_RegRw_36 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[ 18]),.i_ini_value(mem[ 36]),.i_wdat(i_wr_data1[ 18]),.o_reg(w_RegRw_36_dout  ));
 reg_rw_v1_0  U_RegRw_37 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[ 18]),.i_ini_value(mem[ 37]),.i_wdat(i_wr_data2[ 18]),.o_reg(w_RegRw_37_dout  ));
 reg_rw_v1_0  U_RegRw_38 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[ 19]),.i_ini_value(mem[ 38]),.i_wdat(i_wr_data1[ 19]),.o_reg(w_RegRw_38_dout  ));
 reg_rw_v1_0  U_RegRw_39 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[ 19]),.i_ini_value(mem[ 39]),.i_wdat(i_wr_data2[ 19]),.o_reg(w_RegRw_39_dout  ));
 reg_rw_v1_0  U_RegRw_40 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[ 20]),.i_ini_value(mem[ 40]),.i_wdat(i_wr_data1[ 20]),.o_reg(w_RegRw_40_dout  ));
 reg_rw_v1_0  U_RegRw_41 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[ 20]),.i_ini_value(mem[ 41]),.i_wdat(i_wr_data2[ 20]),.o_reg(w_RegRw_41_dout  ));
 reg_rw_v1_0  U_RegRw_42 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[ 21]),.i_ini_value(mem[ 42]),.i_wdat(i_wr_data1[ 21]),.o_reg(w_RegRw_42_dout  ));
 reg_rw_v1_0  U_RegRw_43 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[ 21]),.i_ini_value(mem[ 43]),.i_wdat(i_wr_data2[ 21]),.o_reg(w_RegRw_43_dout  ));
 reg_rw_v1_0  U_RegRw_44 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[ 22]),.i_ini_value(mem[ 44]),.i_wdat(i_wr_data1[ 22]),.o_reg(w_RegRw_44_dout  ));
 reg_rw_v1_0  U_RegRw_45 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[ 22]),.i_ini_value(mem[ 45]),.i_wdat(i_wr_data2[ 22]),.o_reg(w_RegRw_45_dout  ));
 reg_rw_v1_0  U_RegRw_46 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[ 23]),.i_ini_value(mem[ 46]),.i_wdat(i_wr_data1[ 23]),.o_reg(w_RegRw_46_dout  ));
 reg_rw_v1_0  U_RegRw_47 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[ 23]),.i_ini_value(mem[ 47]),.i_wdat(i_wr_data2[ 23]),.o_reg(w_RegRw_47_dout  ));
 reg_rw_v1_0  U_RegRw_48 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[ 24]),.i_ini_value(mem[ 48]),.i_wdat(i_wr_data1[ 24]),.o_reg(w_RegRw_48_dout  ));
 reg_rw_v1_0  U_RegRw_49 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[ 24]),.i_ini_value(mem[ 49]),.i_wdat(i_wr_data2[ 24]),.o_reg(w_RegRw_49_dout  ));
 reg_rw_v1_0  U_RegRw_50 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[ 25]),.i_ini_value(mem[ 50]),.i_wdat(i_wr_data1[ 25]),.o_reg(w_RegRw_50_dout  ));
 reg_rw_v1_0  U_RegRw_51 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[ 25]),.i_ini_value(mem[ 51]),.i_wdat(i_wr_data2[ 25]),.o_reg(w_RegRw_51_dout  ));
 reg_rw_v1_0  U_RegRw_52 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[ 26]),.i_ini_value(mem[ 52]),.i_wdat(i_wr_data1[ 26]),.o_reg(w_RegRw_52_dout  ));
 reg_rw_v1_0  U_RegRw_53 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[ 26]),.i_ini_value(mem[ 53]),.i_wdat(i_wr_data2[ 26]),.o_reg(w_RegRw_53_dout  ));
 reg_rw_v1_0  U_RegRw_54 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[ 27]),.i_ini_value(mem[ 54]),.i_wdat(i_wr_data1[ 27]),.o_reg(w_RegRw_54_dout  ));
 reg_rw_v1_0  U_RegRw_55 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[ 27]),.i_ini_value(mem[ 55]),.i_wdat(i_wr_data2[ 27]),.o_reg(w_RegRw_55_dout  ));
 reg_rw_v1_0  U_RegRw_56 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[ 28]),.i_ini_value(mem[ 56]),.i_wdat(i_wr_data1[ 28]),.o_reg(w_RegRw_56_dout  ));
 reg_rw_v1_0  U_RegRw_57 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[ 28]),.i_ini_value(mem[ 57]),.i_wdat(i_wr_data2[ 28]),.o_reg(w_RegRw_57_dout  ));
 reg_rw_v1_0  U_RegRw_58 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[ 29]),.i_ini_value(mem[ 58]),.i_wdat(i_wr_data1[ 29]),.o_reg(w_RegRw_58_dout  ));
 reg_rw_v1_0  U_RegRw_59 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[ 29]),.i_ini_value(mem[ 59]),.i_wdat(i_wr_data2[ 29]),.o_reg(w_RegRw_59_dout  ));
 reg_rw_v1_0  U_RegRw_60 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[ 30]),.i_ini_value(mem[ 60]),.i_wdat(i_wr_data1[ 30]),.o_reg(w_RegRw_60_dout  ));
 reg_rw_v1_0  U_RegRw_61 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[ 30]),.i_ini_value(mem[ 61]),.i_wdat(i_wr_data2[ 30]),.o_reg(w_RegRw_61_dout  ));
 reg_rw_v1_0  U_RegRw_62 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[ 31]),.i_ini_value(mem[ 62]),.i_wdat(i_wr_data1[ 31]),.o_reg(w_RegRw_62_dout  ));
 reg_rw_v1_0  U_RegRw_63 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[ 31]),.i_ini_value(mem[ 63]),.i_wdat(i_wr_data2[ 31]),.o_reg(w_RegRw_63_dout  ));
                                                                
 reg_rw_v1_0  U_RegRw_64 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[ 32]),.i_ini_value(mem[ 64]),.i_wdat(i_wr_data1[ 32]),.o_reg(w_RegRw_64_dout  ));
 reg_rw_v1_0  U_RegRw_65 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[ 32]),.i_ini_value(mem[ 65]),.i_wdat(i_wr_data2[ 32]),.o_reg(w_RegRw_65_dout  ));
 reg_rw_v1_0  U_RegRw_66 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[ 33]),.i_ini_value(mem[ 66]),.i_wdat(i_wr_data1[ 33]),.o_reg(w_RegRw_66_dout  ));//7 open,and 9 close
 reg_rw_v1_0  U_RegRw_67 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[ 33]),.i_ini_value(mem[ 67]),.i_wdat(i_wr_data2[ 33]),.o_reg(w_RegRw_67_dout  ));
 reg_rw_v1_0  U_RegRw_68 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[ 34]),.i_ini_value(mem[ 68]),.i_wdat(i_wr_data1[ 34]),.o_reg(w_RegRw_68_dout  ));
 reg_rw_v1_0  U_RegRw_69 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[ 34]),.i_ini_value(mem[ 69]),.i_wdat(i_wr_data2[ 34]),.o_reg(w_RegRw_69_dout  ));//
 reg_rw_v1_0  U_RegRw_70 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[ 35]),.i_ini_value(mem[ 70]),.i_wdat(i_wr_data1[ 35]),.o_reg(w_RegRw_70_dout  ));//
 reg_rw_v1_0  U_RegRw_71 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[ 35]),.i_ini_value(mem[ 71]),.i_wdat(i_wr_data2[ 35]),.o_reg(w_RegRw_71_dout  ));
 reg_rw_v1_0  U_RegRw_72 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[ 36]),.i_ini_value(mem[ 72]),.i_wdat(i_wr_data1[ 36]),.o_reg(w_RegRw_72_dout  ));
 reg_rw_v1_0  U_RegRw_73 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[ 36]),.i_ini_value(mem[ 73]),.i_wdat(i_wr_data2[ 36]),.o_reg(w_RegRw_73_dout  ));
 reg_rw_v1_0  U_RegRw_74 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[ 37]),.i_ini_value(mem[ 74]),.i_wdat(i_wr_data1[ 37]),.o_reg(w_RegRw_74_dout  ));
 reg_rw_v1_0  U_RegRw_75 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[ 37]),.i_ini_value(mem[ 75]),.i_wdat(i_wr_data2[ 37]),.o_reg(w_RegRw_75_dout  ));
 reg_rw_v1_0  U_RegRw_76 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[ 38]),.i_ini_value(mem[ 76]),.i_wdat(i_wr_data1[ 38]),.o_reg(w_RegRw_76_dout  ));
 reg_rw_v1_0  U_RegRw_77 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[ 38]),.i_ini_value(mem[ 77]),.i_wdat(i_wr_data2[ 38]),.o_reg(w_RegRw_77_dout  ));
 reg_rw_v1_0  U_RegRw_78 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[ 39]),.i_ini_value(mem[ 78]),.i_wdat(i_wr_data1[ 39]),.o_reg(w_RegRw_78_dout  ));
 reg_rw_v1_0  U_RegRw_79 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[ 39]),.i_ini_value(mem[ 79]),.i_wdat(i_wr_data2[ 39]),.o_reg(w_RegRw_79_dout  ));
 reg_rw_v1_0  U_RegRw_80 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[ 40]),.i_ini_value(mem[ 80]),.i_wdat(i_wr_data1[ 40]),.o_reg(w_RegRw_80_dout  ));
 reg_rw_v1_0  U_RegRw_81 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[ 40]),.i_ini_value(mem[ 81]),.i_wdat(i_wr_data2[ 40]),.o_reg(w_RegRw_81_dout  ));
 reg_rw_v1_0  U_RegRw_82 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[ 41]),.i_ini_value(mem[ 82]),.i_wdat(i_wr_data1[ 41]),.o_reg(w_RegRw_82_dout  ));
 reg_rw_v1_0  U_RegRw_83 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[ 41]),.i_ini_value(mem[ 83]),.i_wdat(i_wr_data2[ 41]),.o_reg(w_RegRw_83_dout  ));
 reg_rw_v1_0  U_RegRw_84 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[ 42]),.i_ini_value(mem[ 84]),.i_wdat(i_wr_data1[ 42]),.o_reg(w_RegRw_84_dout  ));
 reg_rw_v1_0  U_RegRw_85 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[ 42]),.i_ini_value(mem[ 85]),.i_wdat(i_wr_data2[ 42]),.o_reg(w_RegRw_85_dout  ));
 reg_rw_v1_0  U_RegRw_86 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[ 43]),.i_ini_value(mem[ 86]),.i_wdat(i_wr_data1[ 43]),.o_reg(w_RegRw_86_dout  ));
 reg_rw_v1_0  U_RegRw_87 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[ 43]),.i_ini_value(mem[ 87]),.i_wdat(i_wr_data2[ 43]),.o_reg(w_RegRw_87_dout  ));
 reg_rw_v1_0  U_RegRw_88 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[ 44]),.i_ini_value(mem[ 88]),.i_wdat(i_wr_data1[ 44]),.o_reg(w_RegRw_88_dout  ));
 reg_rw_v1_0  U_RegRw_89 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[ 44]),.i_ini_value(mem[ 89]),.i_wdat(i_wr_data2[ 44]),.o_reg(w_RegRw_89_dout  ));
 reg_rw_v1_0  U_RegRw_90 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[ 45]),.i_ini_value(mem[ 90]),.i_wdat(i_wr_data1[ 45]),.o_reg(w_RegRw_90_dout  ));
 reg_rw_v1_0  U_RegRw_91 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[ 45]),.i_ini_value(mem[ 91]),.i_wdat(i_wr_data2[ 45]),.o_reg(w_RegRw_91_dout  ));
 reg_rw_v1_0  U_RegRw_92 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[ 46]),.i_ini_value(mem[ 92]),.i_wdat(i_wr_data1[ 46]),.o_reg(w_RegRw_92_dout  ));
 reg_rw_v1_0  U_RegRw_93 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[ 46]),.i_ini_value(mem[ 93]),.i_wdat(i_wr_data2[ 46]),.o_reg(w_RegRw_93_dout  ));
 reg_rw_v1_0  U_RegRw_94 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[ 47]),.i_ini_value(mem[ 94]),.i_wdat(i_wr_data1[ 47]),.o_reg(w_RegRw_94_dout  ));
 reg_rw_v1_0  U_RegRw_95 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[ 47]),.i_ini_value(mem[ 95]),.i_wdat(i_wr_data2[ 47]),.o_reg(w_RegRw_95_dout  ));
                                                                 
 reg_rw_v1_0  U_RegRw_96 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[48 ]),.i_ini_value(mem[96 ]),.i_wdat(i_wr_data1[48 ]),.o_reg(w_RegRw_96_dout  ));
 reg_rw_v1_0  U_RegRw_97 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[48 ]),.i_ini_value(mem[97 ]),.i_wdat(i_wr_data2[48 ]),.o_reg(w_RegRw_97_dout  ));
 reg_rw_v1_0  U_RegRw_98 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[49 ]),.i_ini_value(mem[98 ]),.i_wdat(i_wr_data1[49 ]),.o_reg(w_RegRw_98_dout  ));
 reg_rw_v1_0  U_RegRw_99 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[49 ]),.i_ini_value(mem[99 ]),.i_wdat(i_wr_data2[49 ]),.o_reg(w_RegRw_99_dout  ));
 reg_rw_v1_0  U_RegRw_100(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[50 ]),.i_ini_value(mem[100]),.i_wdat(i_wr_data1[50 ]),.o_reg(w_RegRw_100_dout ));
 reg_rw_v1_0  U_RegRw_101(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[50 ]),.i_ini_value(mem[101]),.i_wdat(i_wr_data2[50 ]),.o_reg(w_RegRw_101_dout ));
 reg_rw_v1_0  U_RegRw_102(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[51 ]),.i_ini_value(mem[102]),.i_wdat(i_wr_data1[51 ]),.o_reg(w_RegRw_102_dout ));
 reg_rw_v1_0  U_RegRw_103(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[51 ]),.i_ini_value(mem[103]),.i_wdat(i_wr_data2[51 ]),.o_reg(w_RegRw_103_dout ));
 reg_rw_v1_0  U_RegRw_104(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[52 ]),.i_ini_value(mem[104]),.i_wdat(i_wr_data1[52 ]),.o_reg(w_RegRw_104_dout ));
 reg_rw_v1_0  U_RegRw_105(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[52 ]),.i_ini_value(mem[105]),.i_wdat(i_wr_data2[52 ]),.o_reg(w_RegRw_105_dout ));
 reg_rw_v1_0  U_RegRw_106(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[53 ]),.i_ini_value(mem[106]),.i_wdat(i_wr_data1[53 ]),.o_reg(w_RegRw_106_dout ));
 reg_rw_v1_0  U_RegRw_107(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[53 ]),.i_ini_value(mem[107]),.i_wdat(i_wr_data2[53 ]),.o_reg(w_RegRw_107_dout ));
 reg_rw_v1_0  U_RegRw_108(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[54 ]),.i_ini_value(mem[108]),.i_wdat(i_wr_data1[54 ]),.o_reg(w_RegRw_108_dout ));
 reg_rw_v1_0  U_RegRw_109(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[54 ]),.i_ini_value(mem[109]),.i_wdat(i_wr_data2[54 ]),.o_reg(w_RegRw_109_dout ));
 reg_rw_v1_0  U_RegRw_110(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[55 ]),.i_ini_value(mem[110]),.i_wdat(i_wr_data1[55 ]),.o_reg(w_RegRw_110_dout ));
 reg_rw_v1_0  U_RegRw_111(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[55 ]),.i_ini_value(mem[111]),.i_wdat(i_wr_data2[55 ]),.o_reg(w_RegRw_111_dout ));
 reg_rw_v1_0  U_RegRw_112(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[56 ]),.i_ini_value(mem[112]),.i_wdat(i_wr_data1[56 ]),.o_reg(w_RegRw_112_dout ));
 reg_rw_v1_0  U_RegRw_113(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[56 ]),.i_ini_value(mem[113]),.i_wdat(i_wr_data2[56 ]),.o_reg(w_RegRw_113_dout ));
 reg_rw_v1_0  U_RegRw_114(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[57 ]),.i_ini_value(mem[114]),.i_wdat(i_wr_data1[57 ]),.o_reg(w_RegRw_114_dout ));
 reg_rw_v1_0  U_RegRw_115(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[57 ]),.i_ini_value(mem[115]),.i_wdat(i_wr_data2[57 ]),.o_reg(w_RegRw_115_dout ));
 reg_rw_v1_0  U_RegRw_116(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[58 ]),.i_ini_value(mem[116]),.i_wdat(i_wr_data1[58 ]),.o_reg(w_RegRw_116_dout ));
 reg_rw_v1_0  U_RegRw_117(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[58 ]),.i_ini_value(mem[117]),.i_wdat(i_wr_data2[58 ]),.o_reg(w_RegRw_117_dout ));
 reg_rw_v1_0  U_RegRw_118(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[59 ]),.i_ini_value(mem[118]),.i_wdat(i_wr_data1[59 ]),.o_reg(w_RegRw_118_dout ));
 reg_rw_v1_0  U_RegRw_119(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[59 ]),.i_ini_value(mem[119]),.i_wdat(i_wr_data2[59 ]),.o_reg(w_RegRw_119_dout ));
 reg_rw_v1_0  U_RegRw_120(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[60 ]),.i_ini_value(mem[120]),.i_wdat(i_wr_data1[60 ]),.o_reg(w_RegRw_120_dout ));
 reg_rw_v1_0  U_RegRw_121(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[60 ]),.i_ini_value(mem[121]),.i_wdat(i_wr_data2[60 ]),.o_reg(w_RegRw_121_dout ));
 reg_rw_v1_0  U_RegRw_122(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[61 ]),.i_ini_value(mem[122]),.i_wdat(i_wr_data1[61 ]),.o_reg(w_RegRw_122_dout ));
 reg_rw_v1_0  U_RegRw_123(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[61 ]),.i_ini_value(mem[123]),.i_wdat(i_wr_data2[61 ]),.o_reg(w_RegRw_123_dout ));
 reg_rw_v1_0  U_RegRw_124(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[62 ]),.i_ini_value(mem[124]),.i_wdat(i_wr_data1[62 ]),.o_reg(w_RegRw_124_dout ));
 reg_rw_v1_0  U_RegRw_125(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[62 ]),.i_ini_value(mem[125]),.i_wdat(i_wr_data2[62 ]),.o_reg(w_RegRw_125_dout ));
 reg_rw_v1_0  U_RegRw_126(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[63 ]),.i_ini_value(mem[126]),.i_wdat(i_wr_data1[63 ]),.o_reg(w_RegRw_126_dout ));
 reg_rw_v1_0  U_RegRw_127(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[63 ]),.i_ini_value(mem[127]),.i_wdat(i_wr_data2[63 ]),.o_reg(w_RegRw_127_dout ));
                                                                 
 reg_rw_v1_0  U_RegRw_128(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[64 ]),.i_ini_value(mem[128]),.i_wdat(i_wr_data1[64 ]),.o_reg(w_RegRw_128_dout ));
 reg_rw_v1_0  U_RegRw_129(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[64 ]),.i_ini_value(mem[129]),.i_wdat(i_wr_data2[64 ]),.o_reg(w_RegRw_129_dout ));
 reg_rw_v1_0  U_RegRw_130(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[65 ]),.i_ini_value(mem[130]),.i_wdat(i_wr_data1[65 ]),.o_reg(w_RegRw_130_dout ));//7 open,and 9 close
 reg_rw_v1_0  U_RegRw_131(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[65 ]),.i_ini_value(mem[131]),.i_wdat(i_wr_data2[65 ]),.o_reg(w_RegRw_131_dout ));
 reg_rw_v1_0  U_RegRw_132(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[66 ]),.i_ini_value(mem[132]),.i_wdat(i_wr_data1[66 ]),.o_reg(w_RegRw_132_dout ));
 reg_rw_v1_0  U_RegRw_133(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[66 ]),.i_ini_value(mem[133]),.i_wdat(i_wr_data2[66 ]),.o_reg(w_RegRw_133_dout ));//
 reg_rw_v1_0  U_RegRw_134(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[67 ]),.i_ini_value(mem[134]),.i_wdat(i_wr_data1[67 ]),.o_reg(w_RegRw_134_dout ));//
 reg_rw_v1_0  U_RegRw_135(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[67 ]),.i_ini_value(mem[135]),.i_wdat(i_wr_data2[67 ]),.o_reg(w_RegRw_135_dout ));
 reg_rw_v1_0  U_RegRw_136(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[68 ]),.i_ini_value(mem[136]),.i_wdat(i_wr_data1[68 ]),.o_reg(w_RegRw_136_dout ));
 reg_rw_v1_0  U_RegRw_137(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[68 ]),.i_ini_value(mem[137]),.i_wdat(i_wr_data2[68 ]),.o_reg(w_RegRw_137_dout ));
 reg_rw_v1_0  U_RegRw_138(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[69 ]),.i_ini_value(mem[138]),.i_wdat(i_wr_data1[69 ]),.o_reg(w_RegRw_138_dout ));
 reg_rw_v1_0  U_RegRw_139(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[69 ]),.i_ini_value(mem[139]),.i_wdat(i_wr_data2[69 ]),.o_reg(w_RegRw_139_dout ));
 reg_rw_v1_0  U_RegRw_140(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[70 ]),.i_ini_value(mem[140]),.i_wdat(i_wr_data1[70 ]),.o_reg(w_RegRw_140_dout ));
 reg_rw_v1_0  U_RegRw_141(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[70 ]),.i_ini_value(mem[141]),.i_wdat(i_wr_data2[70 ]),.o_reg(w_RegRw_141_dout ));
 reg_rw_v1_0  U_RegRw_142(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[71 ]),.i_ini_value(mem[142]),.i_wdat(i_wr_data1[71 ]),.o_reg(w_RegRw_142_dout ));
 reg_rw_v1_0  U_RegRw_143(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[71 ]),.i_ini_value(mem[143]),.i_wdat(i_wr_data2[71 ]),.o_reg(w_RegRw_143_dout ));
 reg_rw_v1_0  U_RegRw_144(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[72 ]),.i_ini_value(mem[144]),.i_wdat(i_wr_data1[72 ]),.o_reg(w_RegRw_144_dout ));
 reg_rw_v1_0  U_RegRw_145(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[72 ]),.i_ini_value(mem[145]),.i_wdat(i_wr_data2[72 ]),.o_reg(w_RegRw_145_dout ));
 reg_rw_v1_0  U_RegRw_146(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[73 ]),.i_ini_value(mem[146]),.i_wdat(i_wr_data1[73 ]),.o_reg(w_RegRw_146_dout ));
 reg_rw_v1_0  U_RegRw_147(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[73 ]),.i_ini_value(mem[147]),.i_wdat(i_wr_data2[73 ]),.o_reg(w_RegRw_147_dout ));
 reg_rw_v1_0  U_RegRw_148(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[74 ]),.i_ini_value(mem[148]),.i_wdat(i_wr_data1[74 ]),.o_reg(w_RegRw_148_dout ));
 reg_rw_v1_0  U_RegRw_149(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[74 ]),.i_ini_value(mem[149]),.i_wdat(i_wr_data2[74 ]),.o_reg(w_RegRw_149_dout ));
 reg_rw_v1_0  U_RegRw_150(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[75 ]),.i_ini_value(mem[150]),.i_wdat(i_wr_data1[75 ]),.o_reg(w_RegRw_150_dout ));
 reg_rw_v1_0  U_RegRw_151(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[75 ]),.i_ini_value(mem[151]),.i_wdat(i_wr_data2[75 ]),.o_reg(w_RegRw_151_dout ));
 reg_rw_v1_0  U_RegRw_152(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[76 ]),.i_ini_value(mem[152]),.i_wdat(i_wr_data1[76 ]),.o_reg(w_RegRw_152_dout ));
 reg_rw_v1_0  U_RegRw_153(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[76 ]),.i_ini_value(mem[153]),.i_wdat(i_wr_data2[76 ]),.o_reg(w_RegRw_153_dout ));
 reg_rw_v1_0  U_RegRw_154(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[77 ]),.i_ini_value(mem[154]),.i_wdat(i_wr_data1[77 ]),.o_reg(w_RegRw_154_dout ));
 reg_rw_v1_0  U_RegRw_155(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[77 ]),.i_ini_value(mem[155]),.i_wdat(i_wr_data2[77 ]),.o_reg(w_RegRw_155_dout ));
 reg_rw_v1_0  U_RegRw_156(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[78 ]),.i_ini_value(mem[156]),.i_wdat(i_wr_data1[78 ]),.o_reg(w_RegRw_156_dout ));
 reg_rw_v1_0  U_RegRw_157(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[78 ]),.i_ini_value(mem[157]),.i_wdat(i_wr_data2[78 ]),.o_reg(w_RegRw_157_dout ));
 reg_rw_v1_0  U_RegRw_158(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[79 ]),.i_ini_value(mem[158]),.i_wdat(i_wr_data1[79 ]),.o_reg(w_RegRw_158_dout ));
 reg_rw_v1_0  U_RegRw_159(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[79 ]),.i_ini_value(mem[159]),.i_wdat(i_wr_data2[79 ]),.o_reg(w_RegRw_159_dout ));
                                                                 
 reg_rw_v1_0  U_RegRw_160(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[80 ]),.i_ini_value(mem[160]),.i_wdat(i_wr_data1[80 ]),.o_reg(w_RegRw_160_dout ));
 reg_rw_v1_0  U_RegRw_161(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[80 ]),.i_ini_value(mem[161]),.i_wdat(i_wr_data2[80 ]),.o_reg(w_RegRw_161_dout ));
 reg_rw_v1_0  U_RegRw_162(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[81 ]),.i_ini_value(mem[162]),.i_wdat(i_wr_data1[81 ]),.o_reg(w_RegRw_162_dout ));
 reg_rw_v1_0  U_RegRw_163(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[81 ]),.i_ini_value(mem[163]),.i_wdat(i_wr_data2[81 ]),.o_reg(w_RegRw_163_dout ));
 reg_rw_v1_0  U_RegRw_164(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[82 ]),.i_ini_value(mem[164]),.i_wdat(i_wr_data1[82 ]),.o_reg(w_RegRw_164_dout ));
 reg_rw_v1_0  U_RegRw_165(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[82 ]),.i_ini_value(mem[165]),.i_wdat(i_wr_data2[82 ]),.o_reg(w_RegRw_165_dout ));
 reg_rw_v1_0  U_RegRw_166(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[83 ]),.i_ini_value(mem[166]),.i_wdat(i_wr_data1[83 ]),.o_reg(w_RegRw_166_dout ));
 reg_rw_v1_0  U_RegRw_167(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[83 ]),.i_ini_value(mem[167]),.i_wdat(i_wr_data2[83 ]),.o_reg(w_RegRw_167_dout ));
 reg_rw_v1_0  U_RegRw_168(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[84 ]),.i_ini_value(mem[168]),.i_wdat(i_wr_data1[84 ]),.o_reg(w_RegRw_168_dout ));
 reg_rw_v1_0  U_RegRw_169(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[84 ]),.i_ini_value(mem[169]),.i_wdat(i_wr_data2[84 ]),.o_reg(w_RegRw_169_dout ));
 reg_rw_v1_0  U_RegRw_170(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[85 ]),.i_ini_value(mem[170]),.i_wdat(i_wr_data1[85 ]),.o_reg(w_RegRw_170_dout ));
 reg_rw_v1_0  U_RegRw_171(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[85 ]),.i_ini_value(mem[171]),.i_wdat(i_wr_data2[85 ]),.o_reg(w_RegRw_171_dout ));
 reg_rw_v1_0  U_RegRw_172(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[86 ]),.i_ini_value(mem[172]),.i_wdat(i_wr_data1[86 ]),.o_reg(w_RegRw_172_dout ));
 reg_rw_v1_0  U_RegRw_173(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[86 ]),.i_ini_value(mem[173]),.i_wdat(i_wr_data2[86 ]),.o_reg(w_RegRw_173_dout ));
 reg_rw_v1_0  U_RegRw_174(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[87 ]),.i_ini_value(mem[174]),.i_wdat(i_wr_data1[87 ]),.o_reg(w_RegRw_174_dout ));
 reg_rw_v1_0  U_RegRw_175(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[87 ]),.i_ini_value(mem[175]),.i_wdat(i_wr_data2[87 ]),.o_reg(w_RegRw_175_dout ));
 reg_rw_v1_0  U_RegRw_176(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[88 ]),.i_ini_value(mem[176]),.i_wdat(i_wr_data1[88 ]),.o_reg(w_RegRw_176_dout ));
 reg_rw_v1_0  U_RegRw_177(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[88 ]),.i_ini_value(mem[177]),.i_wdat(i_wr_data2[88 ]),.o_reg(w_RegRw_177_dout ));
 reg_rw_v1_0  U_RegRw_178(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[89 ]),.i_ini_value(mem[178]),.i_wdat(i_wr_data1[89 ]),.o_reg(w_RegRw_178_dout ));
 reg_rw_v1_0  U_RegRw_179(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[89 ]),.i_ini_value(mem[179]),.i_wdat(i_wr_data2[89 ]),.o_reg(w_RegRw_179_dout ));
 reg_rw_v1_0  U_RegRw_180(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[90 ]),.i_ini_value(mem[180]),.i_wdat(i_wr_data1[90 ]),.o_reg(w_RegRw_180_dout ));
 reg_rw_v1_0  U_RegRw_181(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[90 ]),.i_ini_value(mem[181]),.i_wdat(i_wr_data2[90 ]),.o_reg(w_RegRw_181_dout ));
 reg_rw_v1_0  U_RegRw_182(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[91 ]),.i_ini_value(mem[182]),.i_wdat(i_wr_data1[91 ]),.o_reg(w_RegRw_182_dout ));
 reg_rw_v1_0  U_RegRw_183(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[91 ]),.i_ini_value(mem[183]),.i_wdat(i_wr_data2[91 ]),.o_reg(w_RegRw_183_dout ));
 reg_rw_v1_0  U_RegRw_184(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[92 ]),.i_ini_value(mem[184]),.i_wdat(i_wr_data1[92 ]),.o_reg(w_RegRw_184_dout ));
 reg_rw_v1_0  U_RegRw_185(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[92 ]),.i_ini_value(mem[185]),.i_wdat(i_wr_data2[92 ]),.o_reg(w_RegRw_185_dout ));
 reg_rw_v1_0  U_RegRw_186(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[93 ]),.i_ini_value(mem[186]),.i_wdat(i_wr_data1[93 ]),.o_reg(w_RegRw_186_dout ));
 reg_rw_v1_0  U_RegRw_187(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[93 ]),.i_ini_value(mem[187]),.i_wdat(i_wr_data2[93 ]),.o_reg(w_RegRw_187_dout ));
 reg_rw_v1_0  U_RegRw_188(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[94 ]),.i_ini_value(mem[188]),.i_wdat(i_wr_data1[94 ]),.o_reg(w_RegRw_188_dout ));
 reg_rw_v1_0  U_RegRw_189(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[94 ]),.i_ini_value(mem[189]),.i_wdat(i_wr_data2[94 ]),.o_reg(w_RegRw_189_dout ));
 reg_rw_v1_0  U_RegRw_190(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[95 ]),.i_ini_value(mem[190]),.i_wdat(i_wr_data1[95 ]),.o_reg(w_RegRw_190_dout ));
 reg_rw_v1_0  U_RegRw_191(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[95 ]),.i_ini_value(mem[191]),.i_wdat(i_wr_data2[95 ]),.o_reg(w_RegRw_191_dout ));
                                                                
 reg_rw_v1_0  U_RegRw_192(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[96 ]),.i_ini_value(mem[192]),.i_wdat(i_wr_data1[96 ]),.o_reg(w_RegRw_192_dout ));
 reg_rw_v1_0  U_RegRw_193(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[96 ]),.i_ini_value(mem[193]),.i_wdat(i_wr_data2[96 ]),.o_reg(w_RegRw_193_dout ));
 reg_rw_v1_0  U_RegRw_194(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[97 ]),.i_ini_value(mem[194]),.i_wdat(i_wr_data1[97 ]),.o_reg(w_RegRw_194_dout ));//7 open,and 9 close
 reg_rw_v1_0  U_RegRw_195(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[97 ]),.i_ini_value(mem[195]),.i_wdat(i_wr_data2[97 ]),.o_reg(w_RegRw_195_dout ));
 reg_rw_v1_0  U_RegRw_196(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[98 ]),.i_ini_value(mem[196]),.i_wdat(i_wr_data1[98 ]),.o_reg(w_RegRw_196_dout ));
 reg_rw_v1_0  U_RegRw_197(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[98 ]),.i_ini_value(mem[197]),.i_wdat(i_wr_data2[98 ]),.o_reg(w_RegRw_197_dout ));//
 reg_rw_v1_0  U_RegRw_198(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[99 ]),.i_ini_value(mem[198]),.i_wdat(i_wr_data1[99 ]),.o_reg(w_RegRw_198_dout ));//
 reg_rw_v1_0  U_RegRw_199(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[99 ]),.i_ini_value(mem[199]),.i_wdat(i_wr_data2[99 ]),.o_reg(w_RegRw_199_dout ));
 reg_rw_v1_0  U_RegRw_200(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[100]),.i_ini_value(mem[200]),.i_wdat(i_wr_data1[100]),.o_reg(w_RegRw_200_dout ));
 reg_rw_v1_0  U_RegRw_201(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[100]),.i_ini_value(mem[201]),.i_wdat(i_wr_data2[100]),.o_reg(w_RegRw_201_dout ));
 reg_rw_v1_0  U_RegRw_202(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[101]),.i_ini_value(mem[202]),.i_wdat(i_wr_data1[101]),.o_reg(w_RegRw_202_dout ));
 reg_rw_v1_0  U_RegRw_203(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[101]),.i_ini_value(mem[203]),.i_wdat(i_wr_data2[101]),.o_reg(w_RegRw_203_dout ));
 reg_rw_v1_0  U_RegRw_204(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[102]),.i_ini_value(mem[204]),.i_wdat(i_wr_data1[102]),.o_reg(w_RegRw_204_dout ));
 reg_rw_v1_0  U_RegRw_205(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[102]),.i_ini_value(mem[205]),.i_wdat(i_wr_data2[102]),.o_reg(w_RegRw_205_dout ));
 reg_rw_v1_0  U_RegRw_206(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[103]),.i_ini_value(mem[206]),.i_wdat(i_wr_data1[103]),.o_reg(w_RegRw_206_dout ));
 reg_rw_v1_0  U_RegRw_207(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[103]),.i_ini_value(mem[207]),.i_wdat(i_wr_data2[103]),.o_reg(w_RegRw_207_dout ));
 reg_rw_v1_0  U_RegRw_208(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[104]),.i_ini_value(mem[208]),.i_wdat(i_wr_data1[104]),.o_reg(w_RegRw_208_dout ));
 reg_rw_v1_0  U_RegRw_209(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[104]),.i_ini_value(mem[209]),.i_wdat(i_wr_data2[104]),.o_reg(w_RegRw_209_dout ));
 reg_rw_v1_0  U_RegRw_210(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[105]),.i_ini_value(mem[210]),.i_wdat(i_wr_data1[105]),.o_reg(w_RegRw_210_dout ));
 reg_rw_v1_0  U_RegRw_211(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[105]),.i_ini_value(mem[211]),.i_wdat(i_wr_data2[105]),.o_reg(w_RegRw_211_dout ));
 reg_rw_v1_0  U_RegRw_212(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[106]),.i_ini_value(mem[212]),.i_wdat(i_wr_data1[106]),.o_reg(w_RegRw_212_dout ));
 reg_rw_v1_0  U_RegRw_213(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[106]),.i_ini_value(mem[213]),.i_wdat(i_wr_data2[106]),.o_reg(w_RegRw_213_dout ));
 reg_rw_v1_0  U_RegRw_214(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[107]),.i_ini_value(mem[214]),.i_wdat(i_wr_data1[107]),.o_reg(w_RegRw_214_dout ));
 reg_rw_v1_0  U_RegRw_215(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[107]),.i_ini_value(mem[215]),.i_wdat(i_wr_data2[107]),.o_reg(w_RegRw_215_dout ));
 reg_rw_v1_0  U_RegRw_216(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[108]),.i_ini_value(mem[216]),.i_wdat(i_wr_data1[108]),.o_reg(w_RegRw_216_dout ));
 reg_rw_v1_0  U_RegRw_217(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[108]),.i_ini_value(mem[217]),.i_wdat(i_wr_data2[108]),.o_reg(w_RegRw_217_dout ));
 reg_rw_v1_0  U_RegRw_218(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[109]),.i_ini_value(mem[218]),.i_wdat(i_wr_data1[109]),.o_reg(w_RegRw_218_dout ));
 reg_rw_v1_0  U_RegRw_219(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[109]),.i_ini_value(mem[219]),.i_wdat(i_wr_data2[109]),.o_reg(w_RegRw_219_dout ));
 reg_rw_v1_0  U_RegRw_220(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[110]),.i_ini_value(mem[220]),.i_wdat(i_wr_data1[110]),.o_reg(w_RegRw_220_dout ));
 reg_rw_v1_0  U_RegRw_221(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[110]),.i_ini_value(mem[221]),.i_wdat(i_wr_data2[110]),.o_reg(w_RegRw_221_dout ));
 reg_rw_v1_0  U_RegRw_222(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[111]),.i_ini_value(mem[222]),.i_wdat(i_wr_data1[111]),.o_reg(w_RegRw_222_dout ));
 reg_rw_v1_0  U_RegRw_223(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[111]),.i_ini_value(mem[223]),.i_wdat(i_wr_data2[111]),.o_reg(w_RegRw_223_dout ));
                                                                
 reg_rw_v1_0  U_RegRw_224(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[112]),.i_ini_value(mem[224]),.i_wdat(i_wr_data1[112]),.o_reg(w_RegRw_224_dout ));
 reg_rw_v1_0  U_RegRw_225(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[112]),.i_ini_value(mem[225]),.i_wdat(i_wr_data2[112]),.o_reg(w_RegRw_225_dout ));
 reg_rw_v1_0  U_RegRw_226(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[113]),.i_ini_value(mem[226]),.i_wdat(i_wr_data1[113]),.o_reg(w_RegRw_226_dout ));
 reg_rw_v1_0  U_RegRw_227(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[113]),.i_ini_value(mem[227]),.i_wdat(i_wr_data2[113]),.o_reg(w_RegRw_227_dout ));
 reg_rw_v1_0  U_RegRw_228(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[114]),.i_ini_value(mem[228]),.i_wdat(i_wr_data1[114]),.o_reg(w_RegRw_228_dout ));
 reg_rw_v1_0  U_RegRw_229(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[114]),.i_ini_value(mem[229]),.i_wdat(i_wr_data2[114]),.o_reg(w_RegRw_229_dout ));
 reg_rw_v1_0  U_RegRw_230(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[115]),.i_ini_value(mem[230]),.i_wdat(i_wr_data1[115]),.o_reg(w_RegRw_230_dout ));
 reg_rw_v1_0  U_RegRw_231(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[115]),.i_ini_value(mem[231]),.i_wdat(i_wr_data2[115]),.o_reg(w_RegRw_231_dout ));
 reg_rw_v1_0  U_RegRw_232(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[116]),.i_ini_value(mem[232]),.i_wdat(i_wr_data1[116]),.o_reg(w_RegRw_232_dout ));
 reg_rw_v1_0  U_RegRw_233(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[116]),.i_ini_value(mem[233]),.i_wdat(i_wr_data2[116]),.o_reg(w_RegRw_233_dout ));
 reg_rw_v1_0  U_RegRw_234(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[117]),.i_ini_value(mem[234]),.i_wdat(i_wr_data1[117]),.o_reg(w_RegRw_234_dout ));
 reg_rw_v1_0  U_RegRw_235(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[117]),.i_ini_value(mem[235]),.i_wdat(i_wr_data2[117]),.o_reg(w_RegRw_235_dout ));
 reg_rw_v1_0  U_RegRw_236(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[118]),.i_ini_value(mem[236]),.i_wdat(i_wr_data1[118]),.o_reg(w_RegRw_236_dout ));
 reg_rw_v1_0  U_RegRw_237(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[118]),.i_ini_value(mem[237]),.i_wdat(i_wr_data2[118]),.o_reg(w_RegRw_237_dout ));
 reg_rw_v1_0  U_RegRw_238(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[119]),.i_ini_value(mem[238]),.i_wdat(i_wr_data1[119]),.o_reg(w_RegRw_238_dout ));
 reg_rw_v1_0  U_RegRw_239(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[119]),.i_ini_value(mem[239]),.i_wdat(i_wr_data2[119]),.o_reg(w_RegRw_239_dout ));
 reg_rw_v1_0  U_RegRw_240(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[120]),.i_ini_value(mem[240]),.i_wdat(i_wr_data1[120]),.o_reg(w_RegRw_240_dout ));
 reg_rw_v1_0  U_RegRw_241(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[120]),.i_ini_value(mem[241]),.i_wdat(i_wr_data2[120]),.o_reg(w_RegRw_241_dout ));
 reg_rw_v1_0  U_RegRw_242(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[121]),.i_ini_value(mem[242]),.i_wdat(i_wr_data1[121]),.o_reg(w_RegRw_242_dout ));
 reg_rw_v1_0  U_RegRw_243(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[121]),.i_ini_value(mem[243]),.i_wdat(i_wr_data2[121]),.o_reg(w_RegRw_243_dout ));
 reg_rw_v1_0  U_RegRw_244(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[122]),.i_ini_value(mem[244]),.i_wdat(i_wr_data1[122]),.o_reg(w_RegRw_244_dout ));
 reg_rw_v1_0  U_RegRw_245(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[122]),.i_ini_value(mem[245]),.i_wdat(i_wr_data2[122]),.o_reg(w_RegRw_245_dout ));
 reg_rw_v1_0  U_RegRw_246(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[123]),.i_ini_value(mem[246]),.i_wdat(i_wr_data1[123]),.o_reg(w_RegRw_246_dout ));
 reg_rw_v1_0  U_RegRw_247(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[123]),.i_ini_value(mem[247]),.i_wdat(i_wr_data2[123]),.o_reg(w_RegRw_247_dout ));
 reg_rw_v1_0  U_RegRw_248(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[124]),.i_ini_value(mem[248]),.i_wdat(i_wr_data1[124]),.o_reg(w_RegRw_248_dout ));
 reg_rw_v1_0  U_RegRw_249(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[124]),.i_ini_value(mem[249]),.i_wdat(i_wr_data2[124]),.o_reg(w_RegRw_249_dout ));
 reg_rw_v1_0  U_RegRw_250(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[125]),.i_ini_value(mem[250]),.i_wdat(i_wr_data1[125]),.o_reg(w_RegRw_250_dout ));
 reg_rw_v1_0  U_RegRw_251(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[125]),.i_ini_value(mem[251]),.i_wdat(i_wr_data2[125]),.o_reg(w_RegRw_251_dout ));
 reg_rw_v1_0  U_RegRw_252(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[126]),.i_ini_value(mem[252]),.i_wdat(i_wr_data1[126]),.o_reg(w_RegRw_252_dout ));
 reg_rw_v1_0  U_RegRw_253(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[126]),.i_ini_value(mem[253]),.i_wdat(i_wr_data2[126]),.o_reg(w_RegRw_253_dout ));
 reg_rw_v1_0  U_RegRw_254(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs1[127]),.i_ini_value(mem[254]),.i_wdat(i_wr_data1[127]),.o_reg(w_RegRw_254_dout ));
 reg_rw_v1_0  U_RegRw_255(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_reg_ini_str),.i_cs(i_cs2[127]),.i_ini_value(mem[255]),.i_wdat(i_wr_data2[127]),.o_reg(w_RegRw_255_dout ));


wire [63:0] w_pkt_data0 ,w_pkt_data1 ,w_pkt_data2 ,w_pkt_data3 ,w_pkt_data4 ,w_pkt_data5 ,w_pkt_data6 ,w_pkt_data7 ;
wire [63:0] w_pkt_data8 ,w_pkt_data9 ,w_pkt_data10,w_pkt_data11,w_pkt_data12,w_pkt_data13,w_pkt_data14,w_pkt_data15;
wire [63:0] w_pkt_data16,w_pkt_data17,w_pkt_data18,w_pkt_data19,w_pkt_data20,w_pkt_data21,w_pkt_data22,w_pkt_data23;
wire [63:0] w_pkt_data24,w_pkt_data25,w_pkt_data26,w_pkt_data27,w_pkt_data28,w_pkt_data29,w_pkt_data30,w_pkt_data31;
assign w_pkt_data0  = {w_RegRw_07_dout ,w_RegRw_06_dout ,w_RegRw_05_dout ,w_RegRw_04_dout ,w_RegRw_03_dout ,w_RegRw_02_dout ,w_RegRw_01_dout ,w_RegRw_00_dout };//64bit
assign w_pkt_data1  = {w_RegRw_15_dout ,w_RegRw_14_dout ,w_RegRw_13_dout ,w_RegRw_12_dout ,w_RegRw_11_dout ,w_RegRw_10_dout ,w_RegRw_09_dout ,w_RegRw_08_dout };
assign w_pkt_data2  = {w_RegRw_23_dout ,w_RegRw_22_dout ,w_RegRw_21_dout ,w_RegRw_20_dout ,w_RegRw_19_dout ,w_RegRw_18_dout ,w_RegRw_17_dout ,w_RegRw_16_dout };
assign w_pkt_data3  = {w_RegRw_31_dout ,w_RegRw_30_dout ,w_RegRw_29_dout ,w_RegRw_28_dout ,w_RegRw_27_dout ,w_RegRw_26_dout ,w_RegRw_25_dout ,w_RegRw_24_dout };
assign w_pkt_data4  = {w_RegRw_39_dout ,w_RegRw_38_dout ,w_RegRw_37_dout ,w_RegRw_36_dout ,w_RegRw_35_dout ,w_RegRw_34_dout ,w_RegRw_33_dout ,w_RegRw_32_dout };
assign w_pkt_data5  = {w_RegRw_47_dout ,w_RegRw_46_dout ,w_RegRw_45_dout ,w_RegRw_44_dout ,w_RegRw_43_dout ,w_RegRw_42_dout ,w_RegRw_41_dout ,w_RegRw_40_dout };
assign w_pkt_data6  = {w_RegRw_55_dout ,w_RegRw_54_dout ,w_RegRw_53_dout ,w_RegRw_52_dout ,w_RegRw_51_dout ,w_RegRw_50_dout ,w_RegRw_49_dout ,w_RegRw_48_dout };
assign w_pkt_data7  = {w_RegRw_63_dout ,w_RegRw_62_dout ,w_RegRw_61_dout ,w_RegRw_60_dout ,w_RegRw_59_dout ,w_RegRw_58_dout ,w_RegRw_57_dout ,w_RegRw_56_dout };//512
assign w_pkt_data8  = {w_RegRw_71_dout ,w_RegRw_70_dout ,w_RegRw_69_dout ,w_RegRw_68_dout ,w_RegRw_67_dout ,w_RegRw_66_dout ,w_RegRw_65_dout ,w_RegRw_64_dout };//32bit
assign w_pkt_data9  = {w_RegRw_79_dout ,w_RegRw_78_dout ,w_RegRw_77_dout ,w_RegRw_76_dout ,w_RegRw_75_dout ,w_RegRw_74_dout ,w_RegRw_73_dout ,w_RegRw_72_dout };
assign w_pkt_data10 = {w_RegRw_87_dout ,w_RegRw_86_dout ,w_RegRw_85_dout ,w_RegRw_84_dout ,w_RegRw_83_dout ,w_RegRw_82_dout ,w_RegRw_81_dout ,w_RegRw_80_dout };
assign w_pkt_data11 = {w_RegRw_95_dout ,w_RegRw_94_dout ,w_RegRw_93_dout ,w_RegRw_92_dout ,w_RegRw_91_dout ,w_RegRw_90_dout ,w_RegRw_89_dout ,w_RegRw_88_dout };
assign w_pkt_data12 = {w_RegRw_103_dout,w_RegRw_102_dout,w_RegRw_101_dout,w_RegRw_100_dout,w_RegRw_99_dout ,w_RegRw_98_dout ,w_RegRw_97_dout ,w_RegRw_96_dout };
assign w_pkt_data13 = {w_RegRw_111_dout,w_RegRw_110_dout,w_RegRw_109_dout,w_RegRw_108_dout,w_RegRw_107_dout,w_RegRw_106_dout,w_RegRw_105_dout,w_RegRw_104_dout};
assign w_pkt_data14 = {w_RegRw_119_dout,w_RegRw_118_dout,w_RegRw_117_dout,w_RegRw_116_dout,w_RegRw_115_dout,w_RegRw_114_dout,w_RegRw_113_dout,w_RegRw_112_dout};
assign w_pkt_data15 = {w_RegRw_127_dout,w_RegRw_126_dout,w_RegRw_125_dout,w_RegRw_124_dout,w_RegRw_123_dout,w_RegRw_122_dout,w_RegRw_121_dout,w_RegRw_120_dout};
assign w_pkt_data16 = {w_RegRw_135_dout,w_RegRw_134_dout,w_RegRw_133_dout,w_RegRw_132_dout,w_RegRw_131_dout,w_RegRw_130_dout,w_RegRw_129_dout,w_RegRw_128_dout};//64bit
assign w_pkt_data17 = {w_RegRw_143_dout,w_RegRw_142_dout,w_RegRw_141_dout,w_RegRw_140_dout,w_RegRw_139_dout,w_RegRw_138_dout,w_RegRw_137_dout,w_RegRw_136_dout};
assign w_pkt_data18 = {w_RegRw_151_dout,w_RegRw_150_dout,w_RegRw_149_dout,w_RegRw_148_dout,w_RegRw_147_dout,w_RegRw_146_dout,w_RegRw_145_dout,w_RegRw_144_dout};
assign w_pkt_data19 = {w_RegRw_159_dout,w_RegRw_158_dout,w_RegRw_157_dout,w_RegRw_156_dout,w_RegRw_155_dout,w_RegRw_154_dout,w_RegRw_153_dout,w_RegRw_152_dout};
assign w_pkt_data20 = {w_RegRw_167_dout,w_RegRw_166_dout,w_RegRw_165_dout,w_RegRw_164_dout,w_RegRw_163_dout,w_RegRw_162_dout,w_RegRw_161_dout,w_RegRw_160_dout};
assign w_pkt_data21 = {w_RegRw_175_dout,w_RegRw_174_dout,w_RegRw_173_dout,w_RegRw_172_dout,w_RegRw_171_dout,w_RegRw_170_dout,w_RegRw_169_dout,w_RegRw_168_dout};
assign w_pkt_data22 = {w_RegRw_183_dout,w_RegRw_182_dout,w_RegRw_181_dout,w_RegRw_180_dout,w_RegRw_179_dout,w_RegRw_178_dout,w_RegRw_177_dout,w_RegRw_176_dout};
assign w_pkt_data23 = {w_RegRw_191_dout,w_RegRw_190_dout,w_RegRw_189_dout,w_RegRw_188_dout,w_RegRw_187_dout,w_RegRw_186_dout,w_RegRw_185_dout,w_RegRw_184_dout};//512
assign w_pkt_data24 = {w_RegRw_199_dout,w_RegRw_198_dout,w_RegRw_197_dout,w_RegRw_196_dout,w_RegRw_195_dout,w_RegRw_194_dout,w_RegRw_193_dout,w_RegRw_192_dout};//32bit
assign w_pkt_data25 = {w_RegRw_207_dout,w_RegRw_206_dout,w_RegRw_205_dout,w_RegRw_204_dout,w_RegRw_203_dout,w_RegRw_202_dout,w_RegRw_201_dout,w_RegRw_200_dout};
assign w_pkt_data26 = {w_RegRw_215_dout,w_RegRw_214_dout,w_RegRw_213_dout,w_RegRw_212_dout,w_RegRw_211_dout,w_RegRw_210_dout,w_RegRw_209_dout,w_RegRw_208_dout};
assign w_pkt_data27 = {w_RegRw_223_dout,w_RegRw_222_dout,w_RegRw_221_dout,w_RegRw_220_dout,w_RegRw_219_dout,w_RegRw_218_dout,w_RegRw_217_dout,w_RegRw_216_dout};
assign w_pkt_data28 = {w_RegRw_231_dout,w_RegRw_230_dout,w_RegRw_229_dout,w_RegRw_228_dout,w_RegRw_227_dout,w_RegRw_226_dout,w_RegRw_225_dout,w_RegRw_224_dout};
assign w_pkt_data29 = {w_RegRw_239_dout,w_RegRw_238_dout,w_RegRw_237_dout,w_RegRw_236_dout,w_RegRw_235_dout,w_RegRw_234_dout,w_RegRw_233_dout,w_RegRw_232_dout};
assign w_pkt_data30 = {w_RegRw_247_dout,w_RegRw_246_dout,w_RegRw_245_dout,w_RegRw_244_dout,w_RegRw_243_dout,w_RegRw_242_dout,w_RegRw_241_dout,w_RegRw_240_dout};
assign w_pkt_data31 = {w_RegRw_255_dout,w_RegRw_254_dout,w_RegRw_253_dout,w_RegRw_252_dout,w_RegRw_251_dout,w_RegRw_250_dout,w_RegRw_249_dout,w_RegRw_248_dout}; 


always @(posedge clk) begin
    if(~aresetn) begin
       o_pkt_data0 <= 0;//64bit
       o_pkt_data1 <= 0;
       o_pkt_data2 <= 0;
       o_pkt_data3 <= 0;
       o_pkt_data4 <= 0;
       o_pkt_data5 <= 0;
       o_pkt_data6 <= 0;
       o_pkt_data7 <= 0;//512
       o_pkt_data_valid <= 1'b0;
    end
    if(reg_end) begin
       o_pkt_data0 <= {w_pkt_data3 ,w_pkt_data2 ,w_pkt_data1 ,w_pkt_data0 };//64bit
       o_pkt_data1 <= {w_pkt_data7 ,w_pkt_data6 ,w_pkt_data5 ,w_pkt_data4 };
       o_pkt_data2 <= {w_pkt_data11,w_pkt_data10,w_pkt_data9 ,w_pkt_data8 };
       o_pkt_data3 <= {w_pkt_data15,w_pkt_data14,w_pkt_data13,w_pkt_data12};
       o_pkt_data4 <= {w_pkt_data19,w_pkt_data18,w_pkt_data17,w_pkt_data16};
       o_pkt_data5 <= {w_pkt_data23,w_pkt_data22,w_pkt_data21,w_pkt_data20};
       o_pkt_data6 <= {w_pkt_data27,w_pkt_data26,w_pkt_data25,w_pkt_data24};
       o_pkt_data7 <= {w_pkt_data31,w_pkt_data30,w_pkt_data29,w_pkt_data28};//512
       o_pkt_data_valid <= 1'b1;

    end
    else begin
        o_pkt_data0 <= o_pkt_data0;
        o_pkt_data1 <= o_pkt_data1;
        o_pkt_data2 <= o_pkt_data2;
        o_pkt_data3 <= o_pkt_data3;
        o_pkt_data4 <= o_pkt_data4;
        o_pkt_data5 <= o_pkt_data5;
        o_pkt_data6 <= o_pkt_data6;
        o_pkt_data7 <= o_pkt_data7;
        o_pkt_data_valid <= 1'b0;
    end
end

// ila_2 ila_ram_out2B (
// 	.clk(clk), // input wire clk
//  //catch the data to dma
// 	.probe0 (o_pkt_data6), // input wire [255:0]  probe0   4B
// 	.probe1 (o_pkt_data7), // input wire [255:0]  probe1   4B
	
// 	.probe2 ({w_RegRw_224_dout,w_RegRw_225_dout,w_RegRw_232_dout,w_RegRw_233_dout}), // input wire [255:0]  probe2
//     .probe3 ({w_RegRw_240_dout,w_RegRw_241_dout,w_RegRw_248_dout,w_RegRw_249_dout}), // input wire [0:0] probe3
//     .probe4 (state  ),// input wire [31:0]   probe4
//     .probe5 (reg_end)// input wire [31:0]   probe4

// );



endmodule

// `timescale 1ns / 1ps
// //////////////////////////////////////////////////////////////////////////////////
// // Company: 
// // Engineer: 
// // 
// // Create Date: 2023/10/11 08:16:28
// // Design Name: 
// // Module Name: ram
// // Project Name: 
// // Target Devices: 
// // Tool Versions: 
// // Description: 
// // 
// // Dependencies: 
// // 
// // Revision:
// // Revision 0.01 - File Created
// // Additional Comments:
// // 
// //////////////////////////////////////////////////////////////////////////////////
// //////////////////////////////////////////////////////////////////////////////////
// //只要指令有效，修改指令对应偏移的8个字节
// `define SUB_DEPARSE_2B(index) \
//     case(offset_sect[index]) \
//         0:begin \
//             i_wr_data1[mem_32breg_addr1[index]]      = mem_val1[index][7:0];  \
//             i_wr_data2[mem_32breg_addr2[index]]      = mem_val1[index][15:8]; \
//         end \
//         1:begin \
//             i_wr_data2[mem_32breg_addr1[index]]      = mem_val1[index][7:0];  \
//             i_wr_data1[mem_32breg_addr2[index]]      = mem_val1[index][15:8]; \
//         end \
//     endcase \
  
// module ram(
//     input clk,
//     input aresetn,
//     input [255:0] i_ini_pkt_data0,//寄存器里的数据预先载入
//     input [255:0] i_ini_pkt_data1,
//     input [255:0] i_ini_pkt_data2,
//     input [255:0] i_ini_pkt_data3,
//     input [255:0] i_ini_pkt_data4,
//     input [255:0] i_ini_pkt_data5,
//     input [255:0] i_ini_pkt_data6,
//     input [255:0] i_ini_pkt_data7, 
//     input         i_reg_ini_str  ,//载入寄存器初始值，只保留一个初始值载入的状态，非持续性不变
//     output reg    o_ini_pkt_ready,//什么时候该模块可以载入数据

//     input [64*4-1:0]   i_val,
//     input [2*4-1 :0]   i_val_type,
//     input [8*4-1 :0]   i_val_offset,
//     input [3:0]        i_val_end,//先来一步
//     input [3:0]        i_val_valid,//判断数据是否变更
    

//     output reg [255:0] o_pkt_data0,//组成256b输出
//     output reg [255:0] o_pkt_data1,
//     output reg [255:0] o_pkt_data2,
//     output reg [255:0] o_pkt_data3,
//     output reg [255:0] o_pkt_data4,
//     output reg [255:0] o_pkt_data5,
//     output reg [255:0] o_pkt_data6,
//     output reg [255:0] o_pkt_data7,
//     output reg         o_pkt_data_valid          //寄存器数据更新完成
//     );

// //数据先进来，有效指令后进,后面的模块是数据后进来，指令先暂存
// reg r_val_in;
// always @(posedge clk)begin
//     if(~aresetn)
//         r_val_in <= 1'b0;
//     else if(i_val_end == 4'hf)
//         r_val_in <= 1'b1;
//     else
//         r_val_in <= 1'b0;
// end
// //assign w_val_in = (i_val_end == 4'hf)?1'b1:1'b0;


// reg [7:0]   i_wr_data1 [127:0];
// reg [7:0]   i_wr_data2 [127:0];
// wire [128:0] i_cs1 ;              //寄存器变化使能
// wire [128:0] i_cs2 ; 
// reg [3:0] r_val_valid1 ;
// // reg r_reg_ini_str;
// reg reg_end,reg_end_nxt;

// always @(posedge clk) begin
//     if(~aresetn) 
//         o_ini_pkt_ready <= 1'b1;
//     else if(r_val_in )//当指令有效时候或者执行完该模块，可以更换数据的时候
//         o_ini_pkt_ready <= 1'b1;
//     else
//         o_ini_pkt_ready <= 1'b0; 
// end


// genvar index;
// //24个按32位偏偏移的起始地址
// reg [7:0] mem_32breg_addr1 [3:0] ;//2B
// reg [7:0] mem_32breg_addr2 [3:0] ;//2B
// //reg [7:0] mem_32breg_addr [3:0] ;//2B

// wire [3:0] offset_sect;
// assign offset_sect = {i_val_offset[24],i_val_offset[16],i_val_offset[8],i_val_offset[0]};
//     always @(posedge clk) begin
//         if(~aresetn) begin
//             mem_32breg_addr1[ 0] <= 0;
//             mem_32breg_addr1[ 1] <= 0;
//             mem_32breg_addr1[ 2] <= 0;
//             mem_32breg_addr1[ 3] <= 0;
//         end
//         else if(r_val_in == 1'b1)begin
//             mem_32breg_addr1[ 0] <= i_val_offset[7 :1 ];//只取一半地址
//             mem_32breg_addr1[ 1] <= i_val_offset[15: 9];
//             mem_32breg_addr1[ 2] <= i_val_offset[23:17];
//             mem_32breg_addr1[ 3] <= i_val_offset[31:25];
          
//         end
//         else begin
//             mem_32breg_addr1[ 0] <= mem_32breg_addr1[ 0] ;
//             mem_32breg_addr1[ 1] <= mem_32breg_addr1[ 1] ;
//             mem_32breg_addr1[ 2] <= mem_32breg_addr1[ 2] ;
//             mem_32breg_addr1[ 3] <= mem_32breg_addr1[ 3] ;
           
//         end
//     end

//     //根据初始偏移不同进行不同的第二字节偏移
//     always @(posedge clk) begin
//         if(~aresetn) begin
//             mem_32breg_addr2[ 0] <= 0;
//             mem_32breg_addr2[ 1] <= 0;
//             mem_32breg_addr2[ 2] <= 0;
//             mem_32breg_addr2[ 3] <= 0;
//         end
//         else if(r_val_in == 1'b1)begin
//             if(offset_sect[0] == 1'b0)
//                 mem_32breg_addr2[ 0] <= i_val_offset[7 :1 ];
//             else 
//                 mem_32breg_addr2[ 0] <= i_val_offset[7 :1 ]+1'b1;
//             if(offset_sect[1] == 1'b0)
//                 mem_32breg_addr2[ 1] <= i_val_offset[15: 9];
//             else
//                 mem_32breg_addr2[ 1] <= i_val_offset[15: 9]+1'b1;
//             if(offset_sect[2] == 1'b0)
//                 mem_32breg_addr2[ 2] <= i_val_offset[23:17];
//             else
//                 mem_32breg_addr2[ 2] <= i_val_offset[23:17]+1'b1;
//             if(offset_sect[3] == 1'b0)
//                 mem_32breg_addr2[ 3] <= i_val_offset[31:25];
//             else
//                 mem_32breg_addr2[ 3] <= i_val_offset[31:25]+1'b1;
//         end
//         else begin
//             mem_32breg_addr2[ 0] <= mem_32breg_addr2[ 0] ;
//             mem_32breg_addr2[ 1] <= mem_32breg_addr2[ 1] ;
//             mem_32breg_addr2[ 2] <= mem_32breg_addr2[ 2] ;
//             mem_32breg_addr2[ 3] <= mem_32breg_addr2[ 3] ;
           
//         end
//     end

// //24个按64bit区分的容器数据
// reg [15:0] mem_val1 [3:0] ;
//     always @(posedge clk) begin
//         if(~aresetn)begin
//             mem_val1[ 0] <= 0;
//             mem_val1[ 1] <= 0;
//             mem_val1[ 2] <= 0;
//             mem_val1[ 3] <= 0;
            
//         end
//         else if(r_val_in == 1'b1)begin
//             mem_val1[ 0] <= i_val[63  : 0 ];
//             mem_val1[ 1] <= i_val[127 : 64];
//             mem_val1[ 2] <= i_val[191 :128];
//             mem_val1[ 3] <= i_val[255 :192];
            
//         end
//         else begin
//             mem_val1[ 0] <= mem_val1[ 0];
//             mem_val1[ 1] <= mem_val1[ 1];
//             mem_val1[ 2] <= mem_val1[ 2];
//             mem_val1[ 3] <= mem_val1[ 3];
            
//         end
//     end 

// //原始数据按32bits，分64个放入RAM中
//   reg [7:0] mem [255:0] ;
//     always @(posedge clk) begin
//         mem[ 0] <= i_ini_pkt_data0[7   :0  ];
//         mem[ 1] <= i_ini_pkt_data0[15  :8  ];
//         mem[ 2] <= i_ini_pkt_data0[23  :16 ];
//         mem[ 3] <= i_ini_pkt_data0[31  :24 ];
//         mem[ 4] <= i_ini_pkt_data0[39  :32 ];
//         mem[ 5] <= i_ini_pkt_data0[47  :40 ];
//         mem[ 6] <= i_ini_pkt_data0[55  :48 ];
//         mem[ 7] <= i_ini_pkt_data0[63  :56 ];
//         mem[ 8] <= i_ini_pkt_data0[71  :64 ];
//         mem[ 9] <= i_ini_pkt_data0[79  :72 ];
//         mem[10] <= i_ini_pkt_data0[87  :80 ];
//         mem[11] <= i_ini_pkt_data0[95  :88 ];
//         mem[12] <= i_ini_pkt_data0[103 :96 ];
//         mem[13] <= i_ini_pkt_data0[111 :104];
//         mem[14] <= i_ini_pkt_data0[119 :112];
//         mem[15] <= i_ini_pkt_data0[127 :120];
//         mem[16] <= i_ini_pkt_data0[135 :128];
//         mem[17] <= i_ini_pkt_data0[143 :136];
//         mem[18] <= i_ini_pkt_data0[151 :144];
//         mem[19] <= i_ini_pkt_data0[159 :152];
//         mem[20] <= i_ini_pkt_data0[167 :160];
//         mem[21] <= i_ini_pkt_data0[175 :168];
//         mem[22] <= i_ini_pkt_data0[183 :176];
//         mem[23] <= i_ini_pkt_data0[191 :184];
//         mem[24] <= i_ini_pkt_data0[199 :192];
//         mem[25] <= i_ini_pkt_data0[207 :200];
//         mem[26] <= i_ini_pkt_data0[215 :208];
//         mem[27] <= i_ini_pkt_data0[223:216 ];
//         mem[28] <= i_ini_pkt_data0[231:224 ];
//         mem[29] <= i_ini_pkt_data0[239:232 ];
//         mem[30] <= i_ini_pkt_data0[247:240 ];
//         mem[31] <= i_ini_pkt_data0[255:248 ];

//         mem[32] <= i_ini_pkt_data1[7   :0  ];
//         mem[33] <= i_ini_pkt_data1[15  :8  ];
//         mem[34] <= i_ini_pkt_data1[23  :16 ];
//         mem[35] <= i_ini_pkt_data1[31  :24 ];
//         mem[36] <= i_ini_pkt_data1[39  :32 ];
//         mem[37] <= i_ini_pkt_data1[47  :40 ];
//         mem[38] <= i_ini_pkt_data1[55  :48 ];                
//         mem[39] <= i_ini_pkt_data1[63  :56 ];
//         mem[40] <= i_ini_pkt_data1[71  :64 ];
//         mem[41] <= i_ini_pkt_data1[79  :72 ];
//         mem[42] <= i_ini_pkt_data1[87  :80 ];
//         mem[43] <= i_ini_pkt_data1[95  :88 ];
//         mem[44] <= i_ini_pkt_data1[103 :96 ];
//         mem[45] <= i_ini_pkt_data1[111 :104];
//         mem[46] <= i_ini_pkt_data1[119 :112];
//         mem[47] <= i_ini_pkt_data1[127 :120];
//         mem[48] <= i_ini_pkt_data1[135 :128];
//         mem[49] <= i_ini_pkt_data1[143 :136];
//         mem[50] <= i_ini_pkt_data1[151 :144];
//         mem[51] <= i_ini_pkt_data1[159 :152];
//         mem[52] <= i_ini_pkt_data1[167 :160];
//         mem[53] <= i_ini_pkt_data1[175 :168];
//         mem[54] <= i_ini_pkt_data1[183 :176];
//         mem[55] <= i_ini_pkt_data1[191 :184];
//         mem[56] <= i_ini_pkt_data1[199 :192];
//         mem[57] <= i_ini_pkt_data1[207 :200];
//         mem[58] <= i_ini_pkt_data1[215 :208];
//         mem[59] <= i_ini_pkt_data1[223 :216];
//         mem[60] <= i_ini_pkt_data1[231 :224];
//         mem[61] <= i_ini_pkt_data1[239 :232];
//         mem[62] <= i_ini_pkt_data1[247 :240];
//         mem[63] <= i_ini_pkt_data1[255 :248];

//         mem[64] <= i_ini_pkt_data2[7   :0  ];
//         mem[65] <= i_ini_pkt_data2[15  :8  ];
//         mem[66] <= i_ini_pkt_data2[23  :16 ];
//         mem[67] <= i_ini_pkt_data2[31  :24 ];
//         mem[68] <= i_ini_pkt_data2[39  :32 ];
//         mem[69] <= i_ini_pkt_data2[47  :40 ];
//         mem[70] <= i_ini_pkt_data2[55  :48 ];
//         mem[71] <= i_ini_pkt_data2[63  :56 ];
//         mem[72] <= i_ini_pkt_data2[71  :64 ];
//         mem[73] <= i_ini_pkt_data2[79  :72 ];
//         mem[74] <= i_ini_pkt_data2[87  :80 ];
//         mem[75] <= i_ini_pkt_data2[95  :88 ];
//         mem[76] <= i_ini_pkt_data2[103 :96 ];
//         mem[77] <= i_ini_pkt_data2[111 :104];
//         mem[78] <= i_ini_pkt_data2[119 :112];
//         mem[79] <= i_ini_pkt_data2[127 :120];
//         mem[80] <= i_ini_pkt_data2[135 :128];
//         mem[81] <= i_ini_pkt_data2[143 :136];
//         mem[82] <= i_ini_pkt_data2[151 :144];
//         mem[83] <= i_ini_pkt_data2[159 :152];
//         mem[84] <= i_ini_pkt_data2[167 :160];
//         mem[85] <= i_ini_pkt_data2[175 :168];
//         mem[86] <= i_ini_pkt_data2[183 :176];
//         mem[87] <= i_ini_pkt_data2[191 :184];
//         mem[88] <= i_ini_pkt_data2[199 :192];
//         mem[89] <= i_ini_pkt_data2[207 :200];
//         mem[90] <= i_ini_pkt_data2[215 :208];
//         mem[91] <= i_ini_pkt_data2[223:216 ];
//         mem[92] <= i_ini_pkt_data2[231:224 ];
//         mem[93] <= i_ini_pkt_data2[239:232 ];
//         mem[94] <= i_ini_pkt_data2[247:240 ];
//         mem[95] <= i_ini_pkt_data2[255:248 ];

//         mem[96 ] <= i_ini_pkt_data3[7   :0  ];
//         mem[97 ] <= i_ini_pkt_data3[15  :8  ];
//         mem[98 ] <= i_ini_pkt_data3[23  :16 ];
//         mem[99 ] <= i_ini_pkt_data3[31  :24 ];
//         mem[100] <= i_ini_pkt_data3[39  :32 ];
//         mem[101] <= i_ini_pkt_data3[47  :40 ];
//         mem[102] <= i_ini_pkt_data3[55  :48 ];
//         mem[103] <= i_ini_pkt_data3[63  :56 ];
//         mem[104] <= i_ini_pkt_data3[71  :64 ];
//         mem[105] <= i_ini_pkt_data3[79  :72 ];
//         mem[106] <= i_ini_pkt_data3[87  :80 ];
//         mem[107] <= i_ini_pkt_data3[95  :88 ];
//         mem[108] <= i_ini_pkt_data3[103 :96 ];
//         mem[109] <= i_ini_pkt_data3[111 :104];
//         mem[110] <= i_ini_pkt_data3[119 :112];
//         mem[111] <= i_ini_pkt_data3[127 :120];
//         mem[112] <= i_ini_pkt_data3[135 :128];
//         mem[113] <= i_ini_pkt_data3[143 :136];
//         mem[114] <= i_ini_pkt_data3[151 :144];
//         mem[115] <= i_ini_pkt_data3[159 :152];
//         mem[116] <= i_ini_pkt_data3[167 :160];
//         mem[117] <= i_ini_pkt_data3[175 :168];
//         mem[118] <= i_ini_pkt_data3[183 :176];
//         mem[119] <= i_ini_pkt_data3[191 :184];
//         mem[120] <= i_ini_pkt_data3[199 :192];
//         mem[121] <= i_ini_pkt_data3[207 :200];
//         mem[122] <= i_ini_pkt_data3[215 :208];
//         mem[123] <= i_ini_pkt_data3[223 :216];
//         mem[124] <= i_ini_pkt_data3[231 :224];
//         mem[125] <= i_ini_pkt_data3[239 :232];
//         mem[126] <= i_ini_pkt_data3[247 :240];
//         mem[127] <= i_ini_pkt_data3[255 :248];

//         mem[128] <= i_ini_pkt_data4[7   :0  ];
//         mem[129] <= i_ini_pkt_data4[15  :8  ];
//         mem[130] <= i_ini_pkt_data4[23  :16 ];
//         mem[131] <= i_ini_pkt_data4[31  :24 ];
//         mem[132] <= i_ini_pkt_data4[39  :32 ];
//         mem[133] <= i_ini_pkt_data4[47  :40 ];
//         mem[134] <= i_ini_pkt_data4[55  :48 ];
//         mem[135] <= i_ini_pkt_data4[63  :56 ];
//         mem[136] <= i_ini_pkt_data4[71  :64 ];
//         mem[137] <= i_ini_pkt_data4[79  :72 ];
//         mem[138] <= i_ini_pkt_data4[87  :80 ];
//         mem[139] <= i_ini_pkt_data4[95  :88 ];
//         mem[140] <= i_ini_pkt_data4[103 :96 ];
//         mem[141] <= i_ini_pkt_data4[111 :104];
//         mem[142] <= i_ini_pkt_data4[119 :112];
//         mem[143] <= i_ini_pkt_data4[127 :120];
//         mem[144] <= i_ini_pkt_data4[135 :128];
//         mem[145] <= i_ini_pkt_data4[143 :136];
//         mem[146] <= i_ini_pkt_data4[151 :144];
//         mem[147] <= i_ini_pkt_data4[159 :152];
//         mem[148] <= i_ini_pkt_data4[167 :160];
//         mem[149] <= i_ini_pkt_data4[175 :168];
//         mem[150] <= i_ini_pkt_data4[183 :176];
//         mem[151] <= i_ini_pkt_data4[191 :184];
//         mem[152] <= i_ini_pkt_data4[199 :192];
//         mem[153] <= i_ini_pkt_data4[207 :200];
//         mem[154] <= i_ini_pkt_data4[215 :208];
//         mem[155] <= i_ini_pkt_data4[223 :216];
//         mem[156] <= i_ini_pkt_data4[231 :224];
//         mem[157] <= i_ini_pkt_data4[239 :232];
//         mem[158] <= i_ini_pkt_data4[247 :240];
//         mem[159] <= i_ini_pkt_data4[255 :248];

//         mem[160] <= i_ini_pkt_data5[7   :0  ];
//         mem[161] <= i_ini_pkt_data5[15  :8  ];
//         mem[162] <= i_ini_pkt_data5[23  :16 ];
//         mem[163] <= i_ini_pkt_data5[31  :24 ];
//         mem[164] <= i_ini_pkt_data5[39  :32 ];
//         mem[165] <= i_ini_pkt_data5[47  :40 ];
//         mem[166] <= i_ini_pkt_data5[55  :48 ];
//         mem[167] <= i_ini_pkt_data5[63  :56 ];
//         mem[168] <= i_ini_pkt_data5[71  :64 ];
//         mem[169] <= i_ini_pkt_data5[79  :72 ];
//         mem[170] <= i_ini_pkt_data5[87  :80 ];
//         mem[171] <= i_ini_pkt_data5[95  :88 ];
//         mem[172] <= i_ini_pkt_data5[103 :96 ];
//         mem[173] <= i_ini_pkt_data5[111 :104];
//         mem[174] <= i_ini_pkt_data5[119 :112];
//         mem[175] <= i_ini_pkt_data5[127 :120];
//         mem[176] <= i_ini_pkt_data5[135 :128];
//         mem[177] <= i_ini_pkt_data5[143 :136];
//         mem[178] <= i_ini_pkt_data5[151 :144];
//         mem[179] <= i_ini_pkt_data5[159 :152];
//         mem[180] <= i_ini_pkt_data5[167 :160];
//         mem[181] <= i_ini_pkt_data5[175 :168];
//         mem[182] <= i_ini_pkt_data5[183 :176];
//         mem[183] <= i_ini_pkt_data5[191 :184];
//         mem[184] <= i_ini_pkt_data5[199 :192];
//         mem[185] <= i_ini_pkt_data5[207 :200];
//         mem[186] <= i_ini_pkt_data5[215 :208];
//         mem[187] <= i_ini_pkt_data5[223 :216];
//         mem[188] <= i_ini_pkt_data5[231 :224];
//         mem[189] <= i_ini_pkt_data5[239 :232];
//         mem[190] <= i_ini_pkt_data5[247 :240];
//         mem[191] <= i_ini_pkt_data5[255 :248]; 

//         mem[192] <= i_ini_pkt_data6[7   :0  ];
//         mem[193] <= i_ini_pkt_data6[15  :8  ];
//         mem[194] <= i_ini_pkt_data6[23  :16 ];
//         mem[195] <= i_ini_pkt_data6[31  :24 ];
//         mem[196] <= i_ini_pkt_data6[39  :32 ];
//         mem[197] <= i_ini_pkt_data6[47  :40 ];
//         mem[198] <= i_ini_pkt_data6[55  :48 ];
//         mem[199] <= i_ini_pkt_data6[63  :56 ];
//         mem[200] <= i_ini_pkt_data6[71  :64 ];
//         mem[201] <= i_ini_pkt_data6[79  :72 ];
//         mem[202] <= i_ini_pkt_data6[87  :80 ];
//         mem[203] <= i_ini_pkt_data6[95  :88 ];
//         mem[204] <= i_ini_pkt_data6[103 :96 ];
//         mem[205] <= i_ini_pkt_data6[111 :104];
//         mem[206] <= i_ini_pkt_data6[119 :112];
//         mem[207] <= i_ini_pkt_data6[127 :120];
//         mem[208] <= i_ini_pkt_data6[135 :128];
//         mem[209] <= i_ini_pkt_data6[143 :136];
//         mem[210] <= i_ini_pkt_data6[151 :144];
//         mem[211] <= i_ini_pkt_data6[159 :152];
//         mem[212] <= i_ini_pkt_data6[167 :160];
//         mem[213] <= i_ini_pkt_data6[175 :168];
//         mem[214] <= i_ini_pkt_data6[183 :176];
//         mem[215] <= i_ini_pkt_data6[191 :184];
//         mem[216] <= i_ini_pkt_data6[199 :192];
//         mem[217] <= i_ini_pkt_data6[207 :200];
//         mem[218] <= i_ini_pkt_data6[215 :208];
//         mem[219] <= i_ini_pkt_data6[223 :216];
//         mem[220] <= i_ini_pkt_data6[231 :224];
//         mem[221] <= i_ini_pkt_data6[239 :232];
//         mem[222] <= i_ini_pkt_data6[247 :240];
//         mem[223] <= i_ini_pkt_data6[255 :248];

//         mem[224] <= i_ini_pkt_data7[7   :0  ];
//         mem[225] <= i_ini_pkt_data7[15  :8  ];
//         mem[226] <= i_ini_pkt_data7[23  :16 ];
//         mem[227] <= i_ini_pkt_data7[31  :24 ];
//         mem[228] <= i_ini_pkt_data7[39  :32 ];
//         mem[229] <= i_ini_pkt_data7[47  :40 ];
//         mem[230] <= i_ini_pkt_data7[55  :48 ];
//         mem[231] <= i_ini_pkt_data7[63  :56 ];
//         mem[232] <= i_ini_pkt_data7[71  :64 ];
//         mem[233] <= i_ini_pkt_data7[79  :72 ];
//         mem[234] <= i_ini_pkt_data7[87  :80 ];
//         mem[235] <= i_ini_pkt_data7[95  :88 ];
//         mem[236] <= i_ini_pkt_data7[103 :96 ];
//         mem[237] <= i_ini_pkt_data7[111 :104];
//         mem[238] <= i_ini_pkt_data7[119 :112];
//         mem[239] <= i_ini_pkt_data7[127 :120];
//         mem[240] <= i_ini_pkt_data7[135 :128];
//         mem[241] <= i_ini_pkt_data7[143 :136];
//         mem[242] <= i_ini_pkt_data7[151 :144];
//         mem[243] <= i_ini_pkt_data7[159 :152];
//         mem[244] <= i_ini_pkt_data7[167 :160];
//         mem[245] <= i_ini_pkt_data7[175 :168];
//         mem[246] <= i_ini_pkt_data7[183 :176];
//         mem[247] <= i_ini_pkt_data7[191 :184];
//         mem[248] <= i_ini_pkt_data7[199 :192];
//         mem[249] <= i_ini_pkt_data7[207 :200];
//         mem[250] <= i_ini_pkt_data7[215 :208];
//         mem[251] <= i_ini_pkt_data7[223 :216];
//         mem[252] <= i_ini_pkt_data7[231 :224];
//         mem[253] <= i_ini_pkt_data7[239 :232];
//         mem[254] <= i_ini_pkt_data7[247 :240];
//         mem[255] <= i_ini_pkt_data7[255 :248]; 
//     end

// /////////////////////////////////////////////
// always @(posedge clk) begin
//     if(~aresetn) begin
//         r_val_valid1 <= 0;
//     end
//     else begin
//         if(r_val_in == 1'b1) begin
//             r_val_valid1   <= i_val_valid[3:0];
//         end
//         else begin
//             r_val_valid1   <= 4'h0;
//         end
//     end
// end

// reg[2:0] state,state_next;
// reg [2:0] state_cs,state_cs_nxt;
// localparam IDLE=0, DEPARSER_2B= 1,DEPARSER_2B_END=2;
// localparam CS_IDLE=0, CS_DEPARSER_2B= 1;
 
// always @(posedge clk) begin
//     if(~aresetn)begin
//         state <= IDLE;
//         reg_end <= 1'b0;
//     end
//     else begin
//         state <= state_next;
//         reg_end     <= reg_end_nxt; //寄存器数据更新完成
//     end
// end

// ///////////////////////////////////////////////////////////////////
// always @(*) begin
//     state_next = state;
//     reg_end_nxt = 0;
//     case(state)
//         IDLE:begin
//             if(r_val_in == 1'b1)//如果容器逆解析结束，则执行放回
//                 state_next = DEPARSER_2B;
//             else begin
//                 state_next = IDLE;
//             end
//         end
//         DEPARSER_2B:begin
//             `SUB_DEPARSE_2B(0 )
//             `SUB_DEPARSE_2B(1 )
//             `SUB_DEPARSE_2B(2 )
//             `SUB_DEPARSE_2B(3 )
//             state_next = DEPARSER_2B_END;
//         end
//         DEPARSER_2B_END:begin
//             reg_end_nxt = 1;
//             state_next = IDLE;
//         end
//         default:begin
//             state_next = IDLE;
//         end
//     endcase
// end

// reg [127:0] i_cs_0,i_cs_1,i_cs_2,i_cs_3;
// reg [127:0] i_cs2_0,i_cs2_1,i_cs2_2,i_cs2_3;
// always @(posedge clk ) begin
//     if(~aresetn) begin
//         state_cs <= CS_IDLE;
//          i_cs_0 <= 128'd0;
//          i_cs_1 <= 128'd0;
//          i_cs_2 <= 128'd0;
//          i_cs_3 <= 128'd0;
//     end
//     else begin
//         case(state_cs)
//             CS_IDLE:begin
//             if(r_val_in == 1'b1)
//                 state_cs <= CS_DEPARSER_2B;
//             else begin
//                 state_cs <= CS_IDLE;
//                 i_cs_0 <= 128'd0;
//                 i_cs_1 <= 128'd0;
//                 i_cs_2 <= 128'd0;
//                 i_cs_3 <= 128'd0;
//                 i_cs2_0 <= 128'd0;
//                 i_cs2_1 <= 128'd0;
//                 i_cs2_2 <= 128'd0;
//                 i_cs2_3 <= 128'd0;
//             end
//         end
        
//         CS_DEPARSER_2B: begin
//             if(r_val_valid1[0])begin 
//                 case(offset_sect[0]) 
//                     0:begin 
//                         i_cs_0[mem_32breg_addr1[0]]       <= 1'b1;
//                         i_cs2_0[mem_32breg_addr2[0]]      <= 1'b1; 
//                     end 
//                     1:begin 
//                         i_cs2_0[mem_32breg_addr1[0]]      <= 1'b1;
//                         i_cs_0[mem_32breg_addr2[0]]     <= 1'b1;  
//                     end 
//                 endcase 
//             end 
//             else begin 
//                 i_cs_0[mem_32breg_addr1[0]]       <= 1'b0;
//                 i_cs2_0[mem_32breg_addr2[0]]      <= 1'b0;
//             end

//             if(r_val_valid1[1])begin 
//                 case(offset_sect[1]) 
//                     0:begin 
//                         i_cs_1[mem_32breg_addr1[1]]       <= 1'b1;
//                         i_cs2_1[mem_32breg_addr2[1]]      <= 1'b1; 
//                     end 
//                     1:begin 
//                         i_cs2_1[mem_32breg_addr1[1]]      <= 1'b1;
//                         i_cs_1[mem_32breg_addr2[1]]     <= 1'b1;  
//                     end 
//                 endcase 
//             end 
//             else begin 
//                 i_cs_1[mem_32breg_addr1[1]]       <= 1'b0;
//                 i_cs2_1[mem_32breg_addr2[1]]      <= 1'b0;
//             end 

//             if(r_val_valid1[2])begin 
//                 case(offset_sect[2]) 
//                     0:begin 
//                         i_cs_2[mem_32breg_addr1[2]]       <= 1'b1;
//                         i_cs2_2[mem_32breg_addr2[2]]      <= 1'b1; 
//                     end 
//                     1:begin 
//                         i_cs2_2[mem_32breg_addr1[2]]      <= 1'b1;
//                         i_cs_2[mem_32breg_addr2[2]]     <= 1'b1;  
//                     end 
//                 endcase 
//             end 
//             else begin 
//                 i_cs_2[mem_32breg_addr1[2]]       <= 1'b0;
//                 i_cs2_2[mem_32breg_addr2[2]]      <= 1'b0;
//             end 

//             if(r_val_valid1[3])begin 
//                 case(offset_sect[3]) 
//                     0:begin 
//                         i_cs_3[mem_32breg_addr1[3]]       <= 1'b1;
//                         i_cs2_3[mem_32breg_addr2[3]]      <= 1'b1; 
//                     end 
//                     1:begin 
//                         i_cs2_3[mem_32breg_addr1[3]]      <= 1'b1;
//                         i_cs_3[mem_32breg_addr2[3]]     <= 1'b1;  
//                     end 
//                 endcase 
//             end 
//             else begin 
//                 i_cs_3[mem_32breg_addr1[3]]       <= 1'b0;
//                 i_cs2_3[mem_32breg_addr2[3]]      <= 1'b0;
//             end  
//             state_cs <= CS_IDLE;
//         end 
        
//         default:begin
//             state_cs <= CS_IDLE;
//         end
        
//         endcase
//     end
// end

// assign i_cs1 = i_cs_0 | i_cs_1 | i_cs_2 |i_cs_3;
// assign i_cs2 = i_cs2_0 | i_cs2_1 | i_cs2_2 |i_cs2_3;

//   wire [7:0]  w_RegRw_00_dout,w_RegRw_01_dout,w_RegRw_02_dout,w_RegRw_03_dout;
//   wire [7:0]  w_RegRw_04_dout,w_RegRw_05_dout,w_RegRw_06_dout,w_RegRw_07_dout;
//   wire [7:0]  w_RegRw_08_dout,w_RegRw_09_dout,w_RegRw_10_dout,w_RegRw_11_dout;
//   wire [7:0]  w_RegRw_12_dout,w_RegRw_13_dout,w_RegRw_14_dout,w_RegRw_15_dout;
//   wire [7:0]  w_RegRw_16_dout,w_RegRw_17_dout,w_RegRw_18_dout,w_RegRw_19_dout;
//   wire [7:0]  w_RegRw_20_dout,w_RegRw_21_dout,w_RegRw_22_dout,w_RegRw_23_dout;
//   wire [7:0]  w_RegRw_24_dout,w_RegRw_25_dout,w_RegRw_26_dout,w_RegRw_27_dout;
//   wire [7:0]  w_RegRw_28_dout,w_RegRw_29_dout,w_RegRw_30_dout,w_RegRw_31_dout;
//   wire [7:0]  w_RegRw_32_dout,w_RegRw_33_dout,w_RegRw_34_dout,w_RegRw_35_dout;
//   wire [7:0]  w_RegRw_36_dout,w_RegRw_37_dout,w_RegRw_38_dout,w_RegRw_39_dout;
//   wire [7:0]  w_RegRw_40_dout,w_RegRw_41_dout,w_RegRw_42_dout,w_RegRw_43_dout;
//   wire [7:0]  w_RegRw_44_dout,w_RegRw_45_dout,w_RegRw_46_dout,w_RegRw_47_dout;
//   wire [7:0]  w_RegRw_48_dout,w_RegRw_49_dout,w_RegRw_50_dout,w_RegRw_51_dout;
//   wire [7:0]  w_RegRw_52_dout,w_RegRw_53_dout,w_RegRw_54_dout,w_RegRw_55_dout;
//   wire [7:0]  w_RegRw_56_dout,w_RegRw_57_dout,w_RegRw_58_dout,w_RegRw_59_dout;
//   wire [7:0]  w_RegRw_60_dout,w_RegRw_61_dout,w_RegRw_62_dout,w_RegRw_63_dout;

//   wire [7:0]  w_RegRw_64_dout ,w_RegRw_65_dout ,w_RegRw_66_dout ,w_RegRw_67_dout ;
//   wire [7:0]  w_RegRw_68_dout ,w_RegRw_69_dout ,w_RegRw_70_dout ,w_RegRw_71_dout ;
//   wire [7:0]  w_RegRw_72_dout ,w_RegRw_73_dout ,w_RegRw_74_dout ,w_RegRw_75_dout ;
//   wire [7:0]  w_RegRw_76_dout ,w_RegRw_77_dout ,w_RegRw_78_dout ,w_RegRw_79_dout ;
//   wire [7:0]  w_RegRw_80_dout ,w_RegRw_81_dout ,w_RegRw_82_dout ,w_RegRw_83_dout ;
//   wire [7:0]  w_RegRw_84_dout ,w_RegRw_85_dout ,w_RegRw_86_dout ,w_RegRw_87_dout ;
//   wire [7:0]  w_RegRw_88_dout ,w_RegRw_89_dout ,w_RegRw_90_dout ,w_RegRw_91_dout ;
//   wire [7:0]  w_RegRw_92_dout ,w_RegRw_93_dout ,w_RegRw_94_dout ,w_RegRw_95_dout ;
//   wire [7:0]  w_RegRw_96_dout ,w_RegRw_97_dout ,w_RegRw_98_dout ,w_RegRw_99_dout ;
//   wire [7:0]  w_RegRw_100_dout,w_RegRw_101_dout,w_RegRw_102_dout,w_RegRw_103_dout;
//   wire [7:0]  w_RegRw_104_dout,w_RegRw_105_dout,w_RegRw_106_dout,w_RegRw_107_dout;
//   wire [7:0]  w_RegRw_108_dout,w_RegRw_109_dout,w_RegRw_110_dout,w_RegRw_111_dout;
//   wire [7:0]  w_RegRw_112_dout,w_RegRw_113_dout,w_RegRw_114_dout,w_RegRw_115_dout;
//   wire [7:0]  w_RegRw_116_dout,w_RegRw_117_dout,w_RegRw_118_dout,w_RegRw_119_dout;
//   wire [7:0]  w_RegRw_120_dout,w_RegRw_121_dout,w_RegRw_122_dout,w_RegRw_123_dout;
//   wire [7:0]  w_RegRw_124_dout,w_RegRw_125_dout,w_RegRw_126_dout,w_RegRw_127_dout;

//   wire [7:0]  w_RegRw_128_dout ,w_RegRw_129_dout ,w_RegRw_130_dout ,w_RegRw_131_dout;
//   wire [7:0]  w_RegRw_132_dout ,w_RegRw_133_dout ,w_RegRw_134_dout ,w_RegRw_135_dout;
//   wire [7:0]  w_RegRw_136_dout ,w_RegRw_137_dout ,w_RegRw_138_dout ,w_RegRw_139_dout;
//   wire [7:0]  w_RegRw_140_dout ,w_RegRw_141_dout ,w_RegRw_142_dout ,w_RegRw_143_dout;
//   wire [7:0]  w_RegRw_144_dout ,w_RegRw_145_dout ,w_RegRw_146_dout ,w_RegRw_147_dout;
//   wire [7:0]  w_RegRw_148_dout ,w_RegRw_149_dout ,w_RegRw_150_dout ,w_RegRw_151_dout;
//   wire [7:0]  w_RegRw_152_dout ,w_RegRw_153_dout ,w_RegRw_154_dout ,w_RegRw_155_dout;
//   wire [7:0]  w_RegRw_156_dout ,w_RegRw_157_dout ,w_RegRw_158_dout ,w_RegRw_159_dout;
//   wire [7:0]  w_RegRw_160_dout ,w_RegRw_161_dout ,w_RegRw_162_dout ,w_RegRw_163_dout;
//   wire [7:0]  w_RegRw_164_dout ,w_RegRw_165_dout ,w_RegRw_166_dout ,w_RegRw_167_dout;
//   wire [7:0]  w_RegRw_168_dout ,w_RegRw_169_dout ,w_RegRw_170_dout ,w_RegRw_171_dout;
//   wire [7:0]  w_RegRw_172_dout ,w_RegRw_173_dout ,w_RegRw_174_dout ,w_RegRw_175_dout;
//   wire [7:0]  w_RegRw_176_dout ,w_RegRw_177_dout ,w_RegRw_178_dout ,w_RegRw_179_dout;
//   wire [7:0]  w_RegRw_180_dout ,w_RegRw_181_dout ,w_RegRw_182_dout ,w_RegRw_183_dout;
//   wire [7:0]  w_RegRw_184_dout ,w_RegRw_185_dout ,w_RegRw_186_dout ,w_RegRw_187_dout;
//   wire [7:0]  w_RegRw_188_dout ,w_RegRw_189_dout ,w_RegRw_190_dout ,w_RegRw_191_dout;

//   wire [7:0]  w_RegRw_192_dout ,w_RegRw_193_dout ,w_RegRw_194_dout ,w_RegRw_195_dout ;
//   wire [7:0]  w_RegRw_196_dout ,w_RegRw_197_dout ,w_RegRw_198_dout ,w_RegRw_199_dout ;
//   wire [7:0]  w_RegRw_200_dout ,w_RegRw_201_dout ,w_RegRw_202_dout ,w_RegRw_203_dout ;
//   wire [7:0]  w_RegRw_204_dout ,w_RegRw_205_dout ,w_RegRw_206_dout ,w_RegRw_207_dout ;
//   wire [7:0]  w_RegRw_208_dout ,w_RegRw_209_dout ,w_RegRw_210_dout ,w_RegRw_211_dout ;
//   wire [7:0]  w_RegRw_212_dout ,w_RegRw_213_dout ,w_RegRw_214_dout ,w_RegRw_215_dout ;
//   wire [7:0]  w_RegRw_216_dout ,w_RegRw_217_dout ,w_RegRw_218_dout ,w_RegRw_219_dout ;
//   wire [7:0]  w_RegRw_220_dout ,w_RegRw_221_dout ,w_RegRw_222_dout ,w_RegRw_223_dout ;
//   wire [7:0]  w_RegRw_224_dout ,w_RegRw_225_dout ,w_RegRw_226_dout ,w_RegRw_227_dout ;
//   wire [7:0]  w_RegRw_228_dout ,w_RegRw_229_dout ,w_RegRw_230_dout ,w_RegRw_231_dout ;
//   wire [7:0]  w_RegRw_232_dout ,w_RegRw_233_dout ,w_RegRw_234_dout ,w_RegRw_235_dout ;
//   wire [7:0]  w_RegRw_236_dout ,w_RegRw_237_dout ,w_RegRw_238_dout ,w_RegRw_239_dout ;
//   wire [7:0]  w_RegRw_240_dout ,w_RegRw_241_dout ,w_RegRw_242_dout ,w_RegRw_243_dout ;
//   wire [7:0]  w_RegRw_244_dout ,w_RegRw_245_dout ,w_RegRw_246_dout ,w_RegRw_247_dout ;
//   wire [7:0]  w_RegRw_248_dout ,w_RegRw_249_dout ,w_RegRw_250_dout ,w_RegRw_251_dout ;
//   wire [7:0]  w_RegRw_252_dout ,w_RegRw_253_dout ,w_RegRw_254_dout ,w_RegRw_255_dout ;

//   reg_rw_v1_0  U_RegRw_00 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[  0]),.i_ini_value(mem[  0]),.i_wdat(i_wr_data1[  0]),.o_reg(w_RegRw_00_dout  ));
//   reg_rw_v1_0  U_RegRw_01 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[  0]),.i_ini_value(mem[  1]),.i_wdat(i_wr_data2[  0]),.o_reg(w_RegRw_01_dout  ));
//   reg_rw_v1_0  U_RegRw_02 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[  1]),.i_ini_value(mem[  2]),.i_wdat(i_wr_data1[  1]),.o_reg(w_RegRw_02_dout  ));//7 open,and 9 close
//   reg_rw_v1_0  U_RegRw_03 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[  1]),.i_ini_value(mem[  3]),.i_wdat(i_wr_data2[  1]),.o_reg(w_RegRw_03_dout  ));
//   reg_rw_v1_0  U_RegRw_04 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[  2]),.i_ini_value(mem[  4]),.i_wdat(i_wr_data1[  2]),.o_reg(w_RegRw_04_dout  ));
//   reg_rw_v1_0  U_RegRw_05 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[  2]),.i_ini_value(mem[  5]),.i_wdat(i_wr_data2[  2]),.o_reg(w_RegRw_05_dout  ));//
//   reg_rw_v1_0  U_RegRw_06 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[  3]),.i_ini_value(mem[  6]),.i_wdat(i_wr_data1[  3]),.o_reg(w_RegRw_06_dout  ));//
//   reg_rw_v1_0  U_RegRw_07 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[  3]),.i_ini_value(mem[  7]),.i_wdat(i_wr_data2[  3]),.o_reg(w_RegRw_07_dout  ));
//   reg_rw_v1_0  U_RegRw_08 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[  4]),.i_ini_value(mem[  8]),.i_wdat(i_wr_data1[  4]),.o_reg(w_RegRw_08_dout  ));
//   reg_rw_v1_0  U_RegRw_09 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[  4]),.i_ini_value(mem[  9]),.i_wdat(i_wr_data2[  4]),.o_reg(w_RegRw_09_dout  ));
//   reg_rw_v1_0  U_RegRw_10 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[  5]),.i_ini_value(mem[ 10]),.i_wdat(i_wr_data1[  5]),.o_reg(w_RegRw_10_dout  ));
//   reg_rw_v1_0  U_RegRw_11 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[  5]),.i_ini_value(mem[ 11]),.i_wdat(i_wr_data2[  5]),.o_reg(w_RegRw_11_dout  ));
//   reg_rw_v1_0  U_RegRw_12 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[  6]),.i_ini_value(mem[ 12]),.i_wdat(i_wr_data1[  6]),.o_reg(w_RegRw_12_dout  ));
//   reg_rw_v1_0  U_RegRw_13 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[  6]),.i_ini_value(mem[ 13]),.i_wdat(i_wr_data2[  6]),.o_reg(w_RegRw_13_dout  ));
//   reg_rw_v1_0  U_RegRw_14 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[  7]),.i_ini_value(mem[ 14]),.i_wdat(i_wr_data1[  7]),.o_reg(w_RegRw_14_dout  ));
//   reg_rw_v1_0  U_RegRw_15 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[  7]),.i_ini_value(mem[ 15]),.i_wdat(i_wr_data2[  7]),.o_reg(w_RegRw_15_dout  ));
//   reg_rw_v1_0  U_RegRw_16 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[  8]),.i_ini_value(mem[ 16]),.i_wdat(i_wr_data1[  8]),.o_reg(w_RegRw_16_dout  ));
//   reg_rw_v1_0  U_RegRw_17 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[  8]),.i_ini_value(mem[ 17]),.i_wdat(i_wr_data2[  8]),.o_reg(w_RegRw_17_dout  ));
//   reg_rw_v1_0  U_RegRw_18 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[  9]),.i_ini_value(mem[ 18]),.i_wdat(i_wr_data1[  9]),.o_reg(w_RegRw_18_dout  ));
//   reg_rw_v1_0  U_RegRw_19 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[  9]),.i_ini_value(mem[ 19]),.i_wdat(i_wr_data2[  9]),.o_reg(w_RegRw_19_dout  ));
//   reg_rw_v1_0  U_RegRw_20 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[ 10]),.i_ini_value(mem[ 20]),.i_wdat(i_wr_data1[ 10]),.o_reg(w_RegRw_20_dout  ));
//   reg_rw_v1_0  U_RegRw_21 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[ 10]),.i_ini_value(mem[ 21]),.i_wdat(i_wr_data2[ 10]),.o_reg(w_RegRw_21_dout  ));
//   reg_rw_v1_0  U_RegRw_22 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[ 11]),.i_ini_value(mem[ 22]),.i_wdat(i_wr_data1[ 11]),.o_reg(w_RegRw_22_dout  ));
//   reg_rw_v1_0  U_RegRw_23 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[ 11]),.i_ini_value(mem[ 23]),.i_wdat(i_wr_data2[ 11]),.o_reg(w_RegRw_23_dout  ));
//   reg_rw_v1_0  U_RegRw_24 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[ 12]),.i_ini_value(mem[ 24]),.i_wdat(i_wr_data1[ 12]),.o_reg(w_RegRw_24_dout  ));
//   reg_rw_v1_0  U_RegRw_25 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[ 12]),.i_ini_value(mem[ 25]),.i_wdat(i_wr_data2[ 12]),.o_reg(w_RegRw_25_dout  ));
//   reg_rw_v1_0  U_RegRw_26 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[ 13]),.i_ini_value(mem[ 26]),.i_wdat(i_wr_data1[ 13]),.o_reg(w_RegRw_26_dout  ));
//   reg_rw_v1_0  U_RegRw_27 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[ 13]),.i_ini_value(mem[ 27]),.i_wdat(i_wr_data2[ 13]),.o_reg(w_RegRw_27_dout  ));
//   reg_rw_v1_0  U_RegRw_28 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[ 14]),.i_ini_value(mem[ 28]),.i_wdat(i_wr_data1[ 14]),.o_reg(w_RegRw_28_dout  ));
//   reg_rw_v1_0  U_RegRw_29 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[ 14]),.i_ini_value(mem[ 29]),.i_wdat(i_wr_data2[ 14]),.o_reg(w_RegRw_29_dout  ));
//   reg_rw_v1_0  U_RegRw_30 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[ 15]),.i_ini_value(mem[ 30]),.i_wdat(i_wr_data1[ 15]),.o_reg(w_RegRw_30_dout  ));
//   reg_rw_v1_0  U_RegRw_31 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[ 15]),.i_ini_value(mem[ 31]),.i_wdat(i_wr_data2[ 15]),.o_reg(w_RegRw_31_dout  ));
  
//   reg_rw_v1_0  U_RegRw_32 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[ 16]),.i_ini_value(mem[ 32]),.i_wdat(i_wr_data1[ 16]),.o_reg(w_RegRw_32_dout  ));
//   reg_rw_v1_0  U_RegRw_33 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[ 16]),.i_ini_value(mem[ 33]),.i_wdat(i_wr_data2[ 16]),.o_reg(w_RegRw_33_dout  ));
//   reg_rw_v1_0  U_RegRw_34 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[ 17]),.i_ini_value(mem[ 34]),.i_wdat(i_wr_data1[ 17]),.o_reg(w_RegRw_34_dout  ));
//   reg_rw_v1_0  U_RegRw_35 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[ 17]),.i_ini_value(mem[ 35]),.i_wdat(i_wr_data2[ 17]),.o_reg(w_RegRw_35_dout  ));
//   reg_rw_v1_0  U_RegRw_36 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[ 18]),.i_ini_value(mem[ 36]),.i_wdat(i_wr_data1[ 18]),.o_reg(w_RegRw_36_dout  ));
//   reg_rw_v1_0  U_RegRw_37 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[ 18]),.i_ini_value(mem[ 37]),.i_wdat(i_wr_data2[ 18]),.o_reg(w_RegRw_37_dout  ));
//   reg_rw_v1_0  U_RegRw_38 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[ 19]),.i_ini_value(mem[ 38]),.i_wdat(i_wr_data1[ 19]),.o_reg(w_RegRw_38_dout  ));
//   reg_rw_v1_0  U_RegRw_39 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[ 19]),.i_ini_value(mem[ 39]),.i_wdat(i_wr_data2[ 19]),.o_reg(w_RegRw_39_dout  ));
//   reg_rw_v1_0  U_RegRw_40 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[ 20]),.i_ini_value(mem[ 40]),.i_wdat(i_wr_data1[ 20]),.o_reg(w_RegRw_40_dout  ));
//   reg_rw_v1_0  U_RegRw_41 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[ 20]),.i_ini_value(mem[ 41]),.i_wdat(i_wr_data2[ 20]),.o_reg(w_RegRw_41_dout  ));
//   reg_rw_v1_0  U_RegRw_42 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[ 21]),.i_ini_value(mem[ 42]),.i_wdat(i_wr_data1[ 21]),.o_reg(w_RegRw_42_dout  ));
//   reg_rw_v1_0  U_RegRw_43 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[ 21]),.i_ini_value(mem[ 43]),.i_wdat(i_wr_data2[ 21]),.o_reg(w_RegRw_43_dout  ));
//   reg_rw_v1_0  U_RegRw_44 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[ 22]),.i_ini_value(mem[ 44]),.i_wdat(i_wr_data1[ 22]),.o_reg(w_RegRw_44_dout  ));
//   reg_rw_v1_0  U_RegRw_45 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[ 22]),.i_ini_value(mem[ 45]),.i_wdat(i_wr_data2[ 22]),.o_reg(w_RegRw_45_dout  ));
//   reg_rw_v1_0  U_RegRw_46 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[ 23]),.i_ini_value(mem[ 46]),.i_wdat(i_wr_data1[ 23]),.o_reg(w_RegRw_46_dout  ));
//   reg_rw_v1_0  U_RegRw_47 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[ 23]),.i_ini_value(mem[ 47]),.i_wdat(i_wr_data2[ 23]),.o_reg(w_RegRw_47_dout  ));
//   reg_rw_v1_0  U_RegRw_48 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[ 24]),.i_ini_value(mem[ 48]),.i_wdat(i_wr_data1[ 24]),.o_reg(w_RegRw_48_dout  ));
//   reg_rw_v1_0  U_RegRw_49 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[ 24]),.i_ini_value(mem[ 49]),.i_wdat(i_wr_data2[ 24]),.o_reg(w_RegRw_49_dout  ));
//   reg_rw_v1_0  U_RegRw_50 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[ 25]),.i_ini_value(mem[ 50]),.i_wdat(i_wr_data1[ 25]),.o_reg(w_RegRw_50_dout  ));
//   reg_rw_v1_0  U_RegRw_51 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[ 25]),.i_ini_value(mem[ 51]),.i_wdat(i_wr_data2[ 25]),.o_reg(w_RegRw_51_dout  ));
//   reg_rw_v1_0  U_RegRw_52 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[ 26]),.i_ini_value(mem[ 52]),.i_wdat(i_wr_data1[ 26]),.o_reg(w_RegRw_52_dout  ));
//   reg_rw_v1_0  U_RegRw_53 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[ 26]),.i_ini_value(mem[ 53]),.i_wdat(i_wr_data2[ 26]),.o_reg(w_RegRw_53_dout  ));
//   reg_rw_v1_0  U_RegRw_54 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[ 27]),.i_ini_value(mem[ 54]),.i_wdat(i_wr_data1[ 27]),.o_reg(w_RegRw_54_dout  ));
//   reg_rw_v1_0  U_RegRw_55 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[ 27]),.i_ini_value(mem[ 55]),.i_wdat(i_wr_data2[ 27]),.o_reg(w_RegRw_55_dout  ));
//   reg_rw_v1_0  U_RegRw_56 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[ 28]),.i_ini_value(mem[ 56]),.i_wdat(i_wr_data1[ 28]),.o_reg(w_RegRw_56_dout  ));
//   reg_rw_v1_0  U_RegRw_57 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[ 28]),.i_ini_value(mem[ 57]),.i_wdat(i_wr_data2[ 28]),.o_reg(w_RegRw_57_dout  ));
//   reg_rw_v1_0  U_RegRw_58 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[ 29]),.i_ini_value(mem[ 58]),.i_wdat(i_wr_data1[ 29]),.o_reg(w_RegRw_58_dout  ));
//   reg_rw_v1_0  U_RegRw_59 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[ 29]),.i_ini_value(mem[ 59]),.i_wdat(i_wr_data2[ 29]),.o_reg(w_RegRw_59_dout  ));
//   reg_rw_v1_0  U_RegRw_60 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[ 30]),.i_ini_value(mem[ 60]),.i_wdat(i_wr_data1[ 30]),.o_reg(w_RegRw_60_dout  ));
//   reg_rw_v1_0  U_RegRw_61 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[ 30]),.i_ini_value(mem[ 61]),.i_wdat(i_wr_data2[ 30]),.o_reg(w_RegRw_61_dout  ));
//   reg_rw_v1_0  U_RegRw_62 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[ 31]),.i_ini_value(mem[ 62]),.i_wdat(i_wr_data1[ 31]),.o_reg(w_RegRw_62_dout  ));
//   reg_rw_v1_0  U_RegRw_63 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[ 31]),.i_ini_value(mem[ 63]),.i_wdat(i_wr_data2[ 31]),.o_reg(w_RegRw_63_dout  ));
                                                                
//   reg_rw_v1_0  U_RegRw_64 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[ 32]),.i_ini_value(mem[ 64]),.i_wdat(i_wr_data1[ 32]),.o_reg(w_RegRw_64_dout  ));
//   reg_rw_v1_0  U_RegRw_65 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[ 32]),.i_ini_value(mem[ 65]),.i_wdat(i_wr_data2[ 32]),.o_reg(w_RegRw_65_dout  ));
//   reg_rw_v1_0  U_RegRw_66 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[ 33]),.i_ini_value(mem[ 66]),.i_wdat(i_wr_data1[ 33]),.o_reg(w_RegRw_66_dout  ));//7 open,and 9 close
//   reg_rw_v1_0  U_RegRw_67 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[ 33]),.i_ini_value(mem[ 67]),.i_wdat(i_wr_data2[ 33]),.o_reg(w_RegRw_67_dout  ));
//   reg_rw_v1_0  U_RegRw_68 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[ 34]),.i_ini_value(mem[ 68]),.i_wdat(i_wr_data1[ 34]),.o_reg(w_RegRw_68_dout  ));
//   reg_rw_v1_0  U_RegRw_69 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[ 34]),.i_ini_value(mem[ 69]),.i_wdat(i_wr_data2[ 34]),.o_reg(w_RegRw_69_dout  ));//
//   reg_rw_v1_0  U_RegRw_70 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[ 35]),.i_ini_value(mem[ 70]),.i_wdat(i_wr_data1[ 35]),.o_reg(w_RegRw_70_dout  ));//
//   reg_rw_v1_0  U_RegRw_71 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[ 35]),.i_ini_value(mem[ 71]),.i_wdat(i_wr_data2[ 35]),.o_reg(w_RegRw_71_dout  ));
//   reg_rw_v1_0  U_RegRw_72 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[ 36]),.i_ini_value(mem[ 72]),.i_wdat(i_wr_data1[ 36]),.o_reg(w_RegRw_72_dout  ));
//   reg_rw_v1_0  U_RegRw_73 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[ 36]),.i_ini_value(mem[ 73]),.i_wdat(i_wr_data2[ 36]),.o_reg(w_RegRw_73_dout  ));
//   reg_rw_v1_0  U_RegRw_74 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[ 37]),.i_ini_value(mem[ 74]),.i_wdat(i_wr_data1[ 37]),.o_reg(w_RegRw_74_dout  ));
//   reg_rw_v1_0  U_RegRw_75 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[ 37]),.i_ini_value(mem[ 75]),.i_wdat(i_wr_data2[ 37]),.o_reg(w_RegRw_75_dout  ));
//   reg_rw_v1_0  U_RegRw_76 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[ 38]),.i_ini_value(mem[ 76]),.i_wdat(i_wr_data1[ 38]),.o_reg(w_RegRw_76_dout  ));
//   reg_rw_v1_0  U_RegRw_77 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[ 38]),.i_ini_value(mem[ 77]),.i_wdat(i_wr_data2[ 38]),.o_reg(w_RegRw_77_dout  ));
//   reg_rw_v1_0  U_RegRw_78 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[ 39]),.i_ini_value(mem[ 78]),.i_wdat(i_wr_data1[ 39]),.o_reg(w_RegRw_78_dout  ));
//   reg_rw_v1_0  U_RegRw_79 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[ 39]),.i_ini_value(mem[ 79]),.i_wdat(i_wr_data2[ 39]),.o_reg(w_RegRw_79_dout  ));
//   reg_rw_v1_0  U_RegRw_80 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[ 40]),.i_ini_value(mem[ 80]),.i_wdat(i_wr_data1[ 40]),.o_reg(w_RegRw_80_dout  ));
//   reg_rw_v1_0  U_RegRw_81 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[ 40]),.i_ini_value(mem[ 81]),.i_wdat(i_wr_data2[ 40]),.o_reg(w_RegRw_81_dout  ));
//   reg_rw_v1_0  U_RegRw_82 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[ 41]),.i_ini_value(mem[ 82]),.i_wdat(i_wr_data1[ 41]),.o_reg(w_RegRw_82_dout  ));
//   reg_rw_v1_0  U_RegRw_83 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[ 41]),.i_ini_value(mem[ 83]),.i_wdat(i_wr_data2[ 41]),.o_reg(w_RegRw_83_dout  ));
//   reg_rw_v1_0  U_RegRw_84 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[ 42]),.i_ini_value(mem[ 84]),.i_wdat(i_wr_data1[ 42]),.o_reg(w_RegRw_84_dout  ));
//   reg_rw_v1_0  U_RegRw_85 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[ 42]),.i_ini_value(mem[ 85]),.i_wdat(i_wr_data2[ 42]),.o_reg(w_RegRw_85_dout  ));
//   reg_rw_v1_0  U_RegRw_86 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[ 43]),.i_ini_value(mem[ 86]),.i_wdat(i_wr_data1[ 43]),.o_reg(w_RegRw_86_dout  ));
//   reg_rw_v1_0  U_RegRw_87 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[ 43]),.i_ini_value(mem[ 87]),.i_wdat(i_wr_data2[ 43]),.o_reg(w_RegRw_87_dout  ));
//   reg_rw_v1_0  U_RegRw_88 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[ 44]),.i_ini_value(mem[ 88]),.i_wdat(i_wr_data1[ 44]),.o_reg(w_RegRw_88_dout  ));
//   reg_rw_v1_0  U_RegRw_89 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[ 44]),.i_ini_value(mem[ 89]),.i_wdat(i_wr_data2[ 44]),.o_reg(w_RegRw_89_dout  ));
//   reg_rw_v1_0  U_RegRw_90 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[ 45]),.i_ini_value(mem[ 90]),.i_wdat(i_wr_data1[ 45]),.o_reg(w_RegRw_90_dout  ));
//   reg_rw_v1_0  U_RegRw_91 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[ 45]),.i_ini_value(mem[ 91]),.i_wdat(i_wr_data2[ 45]),.o_reg(w_RegRw_91_dout  ));
//   reg_rw_v1_0  U_RegRw_92 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[ 46]),.i_ini_value(mem[ 92]),.i_wdat(i_wr_data1[ 46]),.o_reg(w_RegRw_92_dout  ));
//   reg_rw_v1_0  U_RegRw_93 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[ 46]),.i_ini_value(mem[ 93]),.i_wdat(i_wr_data2[ 46]),.o_reg(w_RegRw_93_dout  ));
//   reg_rw_v1_0  U_RegRw_94 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[ 47]),.i_ini_value(mem[ 94]),.i_wdat(i_wr_data1[ 47]),.o_reg(w_RegRw_94_dout  ));
//   reg_rw_v1_0  U_RegRw_95 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[ 47]),.i_ini_value(mem[ 95]),.i_wdat(i_wr_data2[ 47]),.o_reg(w_RegRw_95_dout  ));
                                                                 
//   reg_rw_v1_0  U_RegRw_96 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[48 ]),.i_ini_value(mem[96 ]),.i_wdat(i_wr_data1[48 ]),.o_reg(w_RegRw_96_dout  ));
//   reg_rw_v1_0  U_RegRw_97 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[48 ]),.i_ini_value(mem[97 ]),.i_wdat(i_wr_data2[48 ]),.o_reg(w_RegRw_97_dout  ));
//   reg_rw_v1_0  U_RegRw_98 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[49 ]),.i_ini_value(mem[98 ]),.i_wdat(i_wr_data1[49 ]),.o_reg(w_RegRw_98_dout  ));
//   reg_rw_v1_0  U_RegRw_99 (.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[49 ]),.i_ini_value(mem[99 ]),.i_wdat(i_wr_data2[49 ]),.o_reg(w_RegRw_99_dout  ));
//   reg_rw_v1_0  U_RegRw_100(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[50 ]),.i_ini_value(mem[100]),.i_wdat(i_wr_data1[50 ]),.o_reg(w_RegRw_100_dout ));
//   reg_rw_v1_0  U_RegRw_101(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[50 ]),.i_ini_value(mem[101]),.i_wdat(i_wr_data2[50 ]),.o_reg(w_RegRw_101_dout ));
//   reg_rw_v1_0  U_RegRw_102(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[51 ]),.i_ini_value(mem[102]),.i_wdat(i_wr_data1[51 ]),.o_reg(w_RegRw_102_dout ));
//   reg_rw_v1_0  U_RegRw_103(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[51 ]),.i_ini_value(mem[103]),.i_wdat(i_wr_data2[51 ]),.o_reg(w_RegRw_103_dout ));
//   reg_rw_v1_0  U_RegRw_104(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[52 ]),.i_ini_value(mem[104]),.i_wdat(i_wr_data1[52 ]),.o_reg(w_RegRw_104_dout ));
//   reg_rw_v1_0  U_RegRw_105(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[52 ]),.i_ini_value(mem[105]),.i_wdat(i_wr_data2[52 ]),.o_reg(w_RegRw_105_dout ));
//   reg_rw_v1_0  U_RegRw_106(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[53 ]),.i_ini_value(mem[106]),.i_wdat(i_wr_data1[53 ]),.o_reg(w_RegRw_106_dout ));
//   reg_rw_v1_0  U_RegRw_107(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[53 ]),.i_ini_value(mem[107]),.i_wdat(i_wr_data2[53 ]),.o_reg(w_RegRw_107_dout ));
//   reg_rw_v1_0  U_RegRw_108(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[54 ]),.i_ini_value(mem[108]),.i_wdat(i_wr_data1[54 ]),.o_reg(w_RegRw_108_dout ));
//   reg_rw_v1_0  U_RegRw_109(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[54 ]),.i_ini_value(mem[109]),.i_wdat(i_wr_data2[54 ]),.o_reg(w_RegRw_109_dout ));
//   reg_rw_v1_0  U_RegRw_110(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[55 ]),.i_ini_value(mem[110]),.i_wdat(i_wr_data1[55 ]),.o_reg(w_RegRw_110_dout ));
//   reg_rw_v1_0  U_RegRw_111(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[55 ]),.i_ini_value(mem[111]),.i_wdat(i_wr_data2[55 ]),.o_reg(w_RegRw_111_dout ));
//   reg_rw_v1_0  U_RegRw_112(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[56 ]),.i_ini_value(mem[112]),.i_wdat(i_wr_data1[56 ]),.o_reg(w_RegRw_112_dout ));
//   reg_rw_v1_0  U_RegRw_113(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[56 ]),.i_ini_value(mem[113]),.i_wdat(i_wr_data2[56 ]),.o_reg(w_RegRw_113_dout ));
//   reg_rw_v1_0  U_RegRw_114(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[57 ]),.i_ini_value(mem[114]),.i_wdat(i_wr_data1[57 ]),.o_reg(w_RegRw_114_dout ));
//   reg_rw_v1_0  U_RegRw_115(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[57 ]),.i_ini_value(mem[115]),.i_wdat(i_wr_data2[57 ]),.o_reg(w_RegRw_115_dout ));
//   reg_rw_v1_0  U_RegRw_116(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[58 ]),.i_ini_value(mem[116]),.i_wdat(i_wr_data1[58 ]),.o_reg(w_RegRw_116_dout ));
//   reg_rw_v1_0  U_RegRw_117(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[58 ]),.i_ini_value(mem[117]),.i_wdat(i_wr_data2[58 ]),.o_reg(w_RegRw_117_dout ));
//   reg_rw_v1_0  U_RegRw_118(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[59 ]),.i_ini_value(mem[118]),.i_wdat(i_wr_data1[59 ]),.o_reg(w_RegRw_118_dout ));
//   reg_rw_v1_0  U_RegRw_119(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[59 ]),.i_ini_value(mem[119]),.i_wdat(i_wr_data2[59 ]),.o_reg(w_RegRw_119_dout ));
//   reg_rw_v1_0  U_RegRw_120(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[60 ]),.i_ini_value(mem[120]),.i_wdat(i_wr_data1[60 ]),.o_reg(w_RegRw_120_dout ));
//   reg_rw_v1_0  U_RegRw_121(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[60 ]),.i_ini_value(mem[121]),.i_wdat(i_wr_data2[60 ]),.o_reg(w_RegRw_121_dout ));
//   reg_rw_v1_0  U_RegRw_122(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[61 ]),.i_ini_value(mem[122]),.i_wdat(i_wr_data1[61 ]),.o_reg(w_RegRw_122_dout ));
//   reg_rw_v1_0  U_RegRw_123(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[61 ]),.i_ini_value(mem[123]),.i_wdat(i_wr_data2[61 ]),.o_reg(w_RegRw_123_dout ));
//   reg_rw_v1_0  U_RegRw_124(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[62 ]),.i_ini_value(mem[124]),.i_wdat(i_wr_data1[62 ]),.o_reg(w_RegRw_124_dout ));
//   reg_rw_v1_0  U_RegRw_125(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[62 ]),.i_ini_value(mem[125]),.i_wdat(i_wr_data2[62 ]),.o_reg(w_RegRw_125_dout ));
//   reg_rw_v1_0  U_RegRw_126(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[63 ]),.i_ini_value(mem[126]),.i_wdat(i_wr_data1[63 ]),.o_reg(w_RegRw_126_dout ));
//   reg_rw_v1_0  U_RegRw_127(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[63 ]),.i_ini_value(mem[127]),.i_wdat(i_wr_data2[63 ]),.o_reg(w_RegRw_127_dout ));
                                                                 
//   reg_rw_v1_0  U_RegRw_128(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[64 ]),.i_ini_value(mem[128]),.i_wdat(i_wr_data1[64 ]),.o_reg(w_RegRw_128_dout ));
//   reg_rw_v1_0  U_RegRw_129(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[64 ]),.i_ini_value(mem[129]),.i_wdat(i_wr_data2[64 ]),.o_reg(w_RegRw_129_dout ));
//   reg_rw_v1_0  U_RegRw_130(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[65 ]),.i_ini_value(mem[130]),.i_wdat(i_wr_data1[65 ]),.o_reg(w_RegRw_130_dout ));//7 open,and 9 close
//   reg_rw_v1_0  U_RegRw_131(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[65 ]),.i_ini_value(mem[131]),.i_wdat(i_wr_data2[65 ]),.o_reg(w_RegRw_131_dout ));
//   reg_rw_v1_0  U_RegRw_132(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[66 ]),.i_ini_value(mem[132]),.i_wdat(i_wr_data1[66 ]),.o_reg(w_RegRw_132_dout ));
//   reg_rw_v1_0  U_RegRw_133(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[66 ]),.i_ini_value(mem[133]),.i_wdat(i_wr_data2[66 ]),.o_reg(w_RegRw_133_dout ));//
//   reg_rw_v1_0  U_RegRw_134(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[67 ]),.i_ini_value(mem[134]),.i_wdat(i_wr_data1[67 ]),.o_reg(w_RegRw_134_dout ));//
//   reg_rw_v1_0  U_RegRw_135(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[67 ]),.i_ini_value(mem[135]),.i_wdat(i_wr_data2[67 ]),.o_reg(w_RegRw_135_dout ));
//   reg_rw_v1_0  U_RegRw_136(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[68 ]),.i_ini_value(mem[136]),.i_wdat(i_wr_data1[68 ]),.o_reg(w_RegRw_136_dout ));
//   reg_rw_v1_0  U_RegRw_137(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[68 ]),.i_ini_value(mem[137]),.i_wdat(i_wr_data2[68 ]),.o_reg(w_RegRw_137_dout ));
//   reg_rw_v1_0  U_RegRw_138(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[69 ]),.i_ini_value(mem[138]),.i_wdat(i_wr_data1[69 ]),.o_reg(w_RegRw_138_dout ));
//   reg_rw_v1_0  U_RegRw_139(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[69 ]),.i_ini_value(mem[139]),.i_wdat(i_wr_data2[69 ]),.o_reg(w_RegRw_139_dout ));
//   reg_rw_v1_0  U_RegRw_140(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[70 ]),.i_ini_value(mem[140]),.i_wdat(i_wr_data1[70 ]),.o_reg(w_RegRw_140_dout ));
//   reg_rw_v1_0  U_RegRw_141(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[70 ]),.i_ini_value(mem[141]),.i_wdat(i_wr_data2[70 ]),.o_reg(w_RegRw_141_dout ));
//   reg_rw_v1_0  U_RegRw_142(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[71 ]),.i_ini_value(mem[142]),.i_wdat(i_wr_data1[71 ]),.o_reg(w_RegRw_142_dout ));
//   reg_rw_v1_0  U_RegRw_143(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[71 ]),.i_ini_value(mem[143]),.i_wdat(i_wr_data2[71 ]),.o_reg(w_RegRw_143_dout ));
//   reg_rw_v1_0  U_RegRw_144(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[72 ]),.i_ini_value(mem[144]),.i_wdat(i_wr_data1[72 ]),.o_reg(w_RegRw_144_dout ));
//   reg_rw_v1_0  U_RegRw_145(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[72 ]),.i_ini_value(mem[145]),.i_wdat(i_wr_data2[72 ]),.o_reg(w_RegRw_145_dout ));
//   reg_rw_v1_0  U_RegRw_146(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[73 ]),.i_ini_value(mem[146]),.i_wdat(i_wr_data1[73 ]),.o_reg(w_RegRw_146_dout ));
//   reg_rw_v1_0  U_RegRw_147(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[73 ]),.i_ini_value(mem[147]),.i_wdat(i_wr_data2[73 ]),.o_reg(w_RegRw_147_dout ));
//   reg_rw_v1_0  U_RegRw_148(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[74 ]),.i_ini_value(mem[148]),.i_wdat(i_wr_data1[74 ]),.o_reg(w_RegRw_148_dout ));
//   reg_rw_v1_0  U_RegRw_149(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[74 ]),.i_ini_value(mem[149]),.i_wdat(i_wr_data2[74 ]),.o_reg(w_RegRw_149_dout ));
//   reg_rw_v1_0  U_RegRw_150(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[75 ]),.i_ini_value(mem[150]),.i_wdat(i_wr_data1[75 ]),.o_reg(w_RegRw_150_dout ));
//   reg_rw_v1_0  U_RegRw_151(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[75 ]),.i_ini_value(mem[151]),.i_wdat(i_wr_data2[75 ]),.o_reg(w_RegRw_151_dout ));
//   reg_rw_v1_0  U_RegRw_152(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[76 ]),.i_ini_value(mem[152]),.i_wdat(i_wr_data1[76 ]),.o_reg(w_RegRw_152_dout ));
//   reg_rw_v1_0  U_RegRw_153(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[76 ]),.i_ini_value(mem[153]),.i_wdat(i_wr_data2[76 ]),.o_reg(w_RegRw_153_dout ));
//   reg_rw_v1_0  U_RegRw_154(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[77 ]),.i_ini_value(mem[154]),.i_wdat(i_wr_data1[77 ]),.o_reg(w_RegRw_154_dout ));
//   reg_rw_v1_0  U_RegRw_155(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[77 ]),.i_ini_value(mem[155]),.i_wdat(i_wr_data2[77 ]),.o_reg(w_RegRw_155_dout ));
//   reg_rw_v1_0  U_RegRw_156(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[78 ]),.i_ini_value(mem[156]),.i_wdat(i_wr_data1[78 ]),.o_reg(w_RegRw_156_dout ));
//   reg_rw_v1_0  U_RegRw_157(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[78 ]),.i_ini_value(mem[157]),.i_wdat(i_wr_data2[78 ]),.o_reg(w_RegRw_157_dout ));
//   reg_rw_v1_0  U_RegRw_158(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[79 ]),.i_ini_value(mem[158]),.i_wdat(i_wr_data1[79 ]),.o_reg(w_RegRw_158_dout ));
//   reg_rw_v1_0  U_RegRw_159(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[79 ]),.i_ini_value(mem[159]),.i_wdat(i_wr_data2[79 ]),.o_reg(w_RegRw_159_dout ));
                                                                 
//   reg_rw_v1_0  U_RegRw_160(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[80 ]),.i_ini_value(mem[160]),.i_wdat(i_wr_data1[80 ]),.o_reg(w_RegRw_160_dout ));
//   reg_rw_v1_0  U_RegRw_161(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[80 ]),.i_ini_value(mem[161]),.i_wdat(i_wr_data2[80 ]),.o_reg(w_RegRw_161_dout ));
//   reg_rw_v1_0  U_RegRw_162(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[81 ]),.i_ini_value(mem[162]),.i_wdat(i_wr_data1[81 ]),.o_reg(w_RegRw_162_dout ));
//   reg_rw_v1_0  U_RegRw_163(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[81 ]),.i_ini_value(mem[163]),.i_wdat(i_wr_data2[81 ]),.o_reg(w_RegRw_163_dout ));
//   reg_rw_v1_0  U_RegRw_164(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[82 ]),.i_ini_value(mem[164]),.i_wdat(i_wr_data1[82 ]),.o_reg(w_RegRw_164_dout ));
//   reg_rw_v1_0  U_RegRw_165(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[82 ]),.i_ini_value(mem[165]),.i_wdat(i_wr_data2[82 ]),.o_reg(w_RegRw_165_dout ));
//   reg_rw_v1_0  U_RegRw_166(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[83 ]),.i_ini_value(mem[166]),.i_wdat(i_wr_data1[83 ]),.o_reg(w_RegRw_166_dout ));
//   reg_rw_v1_0  U_RegRw_167(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[83 ]),.i_ini_value(mem[167]),.i_wdat(i_wr_data2[83 ]),.o_reg(w_RegRw_167_dout ));
//   reg_rw_v1_0  U_RegRw_168(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[84 ]),.i_ini_value(mem[168]),.i_wdat(i_wr_data1[84 ]),.o_reg(w_RegRw_168_dout ));
//   reg_rw_v1_0  U_RegRw_169(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[84 ]),.i_ini_value(mem[169]),.i_wdat(i_wr_data2[84 ]),.o_reg(w_RegRw_169_dout ));
//   reg_rw_v1_0  U_RegRw_170(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[85 ]),.i_ini_value(mem[170]),.i_wdat(i_wr_data1[85 ]),.o_reg(w_RegRw_170_dout ));
//   reg_rw_v1_0  U_RegRw_171(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[85 ]),.i_ini_value(mem[171]),.i_wdat(i_wr_data2[85 ]),.o_reg(w_RegRw_171_dout ));
//   reg_rw_v1_0  U_RegRw_172(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[86 ]),.i_ini_value(mem[172]),.i_wdat(i_wr_data1[86 ]),.o_reg(w_RegRw_172_dout ));
//   reg_rw_v1_0  U_RegRw_173(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[86 ]),.i_ini_value(mem[173]),.i_wdat(i_wr_data2[86 ]),.o_reg(w_RegRw_173_dout ));
//   reg_rw_v1_0  U_RegRw_174(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[87 ]),.i_ini_value(mem[174]),.i_wdat(i_wr_data1[87 ]),.o_reg(w_RegRw_174_dout ));
//   reg_rw_v1_0  U_RegRw_175(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[87 ]),.i_ini_value(mem[175]),.i_wdat(i_wr_data2[87 ]),.o_reg(w_RegRw_175_dout ));
//   reg_rw_v1_0  U_RegRw_176(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[88 ]),.i_ini_value(mem[176]),.i_wdat(i_wr_data1[88 ]),.o_reg(w_RegRw_176_dout ));
//   reg_rw_v1_0  U_RegRw_177(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[88 ]),.i_ini_value(mem[177]),.i_wdat(i_wr_data2[88 ]),.o_reg(w_RegRw_177_dout ));
//   reg_rw_v1_0  U_RegRw_178(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[89 ]),.i_ini_value(mem[178]),.i_wdat(i_wr_data1[89 ]),.o_reg(w_RegRw_178_dout ));
//   reg_rw_v1_0  U_RegRw_179(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[89 ]),.i_ini_value(mem[179]),.i_wdat(i_wr_data2[89 ]),.o_reg(w_RegRw_179_dout ));
//   reg_rw_v1_0  U_RegRw_180(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[90 ]),.i_ini_value(mem[180]),.i_wdat(i_wr_data1[90 ]),.o_reg(w_RegRw_180_dout ));
//   reg_rw_v1_0  U_RegRw_181(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[90 ]),.i_ini_value(mem[181]),.i_wdat(i_wr_data2[90 ]),.o_reg(w_RegRw_181_dout ));
//   reg_rw_v1_0  U_RegRw_182(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[91 ]),.i_ini_value(mem[182]),.i_wdat(i_wr_data1[91 ]),.o_reg(w_RegRw_182_dout ));
//   reg_rw_v1_0  U_RegRw_183(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[91 ]),.i_ini_value(mem[183]),.i_wdat(i_wr_data2[91 ]),.o_reg(w_RegRw_183_dout ));
//   reg_rw_v1_0  U_RegRw_184(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[92 ]),.i_ini_value(mem[184]),.i_wdat(i_wr_data1[92 ]),.o_reg(w_RegRw_184_dout ));
//   reg_rw_v1_0  U_RegRw_185(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[92 ]),.i_ini_value(mem[185]),.i_wdat(i_wr_data2[92 ]),.o_reg(w_RegRw_185_dout ));
//   reg_rw_v1_0  U_RegRw_186(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[93 ]),.i_ini_value(mem[186]),.i_wdat(i_wr_data1[93 ]),.o_reg(w_RegRw_186_dout ));
//   reg_rw_v1_0  U_RegRw_187(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[93 ]),.i_ini_value(mem[187]),.i_wdat(i_wr_data2[93 ]),.o_reg(w_RegRw_187_dout ));
//   reg_rw_v1_0  U_RegRw_188(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[94 ]),.i_ini_value(mem[188]),.i_wdat(i_wr_data1[94 ]),.o_reg(w_RegRw_188_dout ));
//   reg_rw_v1_0  U_RegRw_189(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[94 ]),.i_ini_value(mem[189]),.i_wdat(i_wr_data2[94 ]),.o_reg(w_RegRw_189_dout ));
//   reg_rw_v1_0  U_RegRw_190(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[95 ]),.i_ini_value(mem[190]),.i_wdat(i_wr_data1[95 ]),.o_reg(w_RegRw_190_dout ));
//   reg_rw_v1_0  U_RegRw_191(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[95 ]),.i_ini_value(mem[191]),.i_wdat(i_wr_data2[95 ]),.o_reg(w_RegRw_191_dout ));
                                                                 
//   reg_rw_v1_0  U_RegRw_192(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[96 ]),.i_ini_value(mem[192]),.i_wdat(i_wr_data1[96 ]),.o_reg(w_RegRw_192_dout ));
//   reg_rw_v1_0  U_RegRw_193(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[96 ]),.i_ini_value(mem[193]),.i_wdat(i_wr_data2[96 ]),.o_reg(w_RegRw_193_dout ));
//   reg_rw_v1_0  U_RegRw_194(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[97 ]),.i_ini_value(mem[194]),.i_wdat(i_wr_data1[97 ]),.o_reg(w_RegRw_194_dout ));//7 open,and 9 close
//   reg_rw_v1_0  U_RegRw_195(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[97 ]),.i_ini_value(mem[195]),.i_wdat(i_wr_data2[97 ]),.o_reg(w_RegRw_195_dout ));
//   reg_rw_v1_0  U_RegRw_196(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[98 ]),.i_ini_value(mem[196]),.i_wdat(i_wr_data1[98 ]),.o_reg(w_RegRw_196_dout ));
//   reg_rw_v1_0  U_RegRw_197(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[98 ]),.i_ini_value(mem[197]),.i_wdat(i_wr_data2[98 ]),.o_reg(w_RegRw_197_dout ));//
//   reg_rw_v1_0  U_RegRw_198(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[99 ]),.i_ini_value(mem[198]),.i_wdat(i_wr_data1[99 ]),.o_reg(w_RegRw_198_dout ));//
//   reg_rw_v1_0  U_RegRw_199(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[99 ]),.i_ini_value(mem[199]),.i_wdat(i_wr_data2[99 ]),.o_reg(w_RegRw_199_dout ));
//   reg_rw_v1_0  U_RegRw_200(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[100]),.i_ini_value(mem[200]),.i_wdat(i_wr_data1[100]),.o_reg(w_RegRw_200_dout ));
//   reg_rw_v1_0  U_RegRw_201(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[100]),.i_ini_value(mem[201]),.i_wdat(i_wr_data2[100]),.o_reg(w_RegRw_201_dout ));
//   reg_rw_v1_0  U_RegRw_202(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[101]),.i_ini_value(mem[202]),.i_wdat(i_wr_data1[101]),.o_reg(w_RegRw_202_dout ));
//   reg_rw_v1_0  U_RegRw_203(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[101]),.i_ini_value(mem[203]),.i_wdat(i_wr_data2[101]),.o_reg(w_RegRw_203_dout ));
//   reg_rw_v1_0  U_RegRw_204(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[102]),.i_ini_value(mem[204]),.i_wdat(i_wr_data1[102]),.o_reg(w_RegRw_204_dout ));
//   reg_rw_v1_0  U_RegRw_205(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[102]),.i_ini_value(mem[205]),.i_wdat(i_wr_data2[102]),.o_reg(w_RegRw_205_dout ));
//   reg_rw_v1_0  U_RegRw_206(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[103]),.i_ini_value(mem[206]),.i_wdat(i_wr_data1[103]),.o_reg(w_RegRw_206_dout ));
//   reg_rw_v1_0  U_RegRw_207(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[103]),.i_ini_value(mem[207]),.i_wdat(i_wr_data2[103]),.o_reg(w_RegRw_207_dout ));
//   reg_rw_v1_0  U_RegRw_208(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[104]),.i_ini_value(mem[208]),.i_wdat(i_wr_data1[104]),.o_reg(w_RegRw_208_dout ));
//   reg_rw_v1_0  U_RegRw_209(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[104]),.i_ini_value(mem[209]),.i_wdat(i_wr_data2[104]),.o_reg(w_RegRw_209_dout ));
//   reg_rw_v1_0  U_RegRw_210(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[105]),.i_ini_value(mem[210]),.i_wdat(i_wr_data1[105]),.o_reg(w_RegRw_210_dout ));
//   reg_rw_v1_0  U_RegRw_211(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[105]),.i_ini_value(mem[211]),.i_wdat(i_wr_data2[105]),.o_reg(w_RegRw_211_dout ));
//   reg_rw_v1_0  U_RegRw_212(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[106]),.i_ini_value(mem[212]),.i_wdat(i_wr_data1[106]),.o_reg(w_RegRw_212_dout ));
//   reg_rw_v1_0  U_RegRw_213(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[106]),.i_ini_value(mem[213]),.i_wdat(i_wr_data2[106]),.o_reg(w_RegRw_213_dout ));
//   reg_rw_v1_0  U_RegRw_214(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[107]),.i_ini_value(mem[214]),.i_wdat(i_wr_data1[107]),.o_reg(w_RegRw_214_dout ));
//   reg_rw_v1_0  U_RegRw_215(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[107]),.i_ini_value(mem[215]),.i_wdat(i_wr_data2[107]),.o_reg(w_RegRw_215_dout ));
//   reg_rw_v1_0  U_RegRw_216(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[108]),.i_ini_value(mem[216]),.i_wdat(i_wr_data1[108]),.o_reg(w_RegRw_216_dout ));
//   reg_rw_v1_0  U_RegRw_217(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[108]),.i_ini_value(mem[217]),.i_wdat(i_wr_data2[108]),.o_reg(w_RegRw_217_dout ));
//   reg_rw_v1_0  U_RegRw_218(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[109]),.i_ini_value(mem[218]),.i_wdat(i_wr_data1[109]),.o_reg(w_RegRw_218_dout ));
//   reg_rw_v1_0  U_RegRw_219(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[109]),.i_ini_value(mem[219]),.i_wdat(i_wr_data2[109]),.o_reg(w_RegRw_219_dout ));
//   reg_rw_v1_0  U_RegRw_220(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[110]),.i_ini_value(mem[220]),.i_wdat(i_wr_data1[110]),.o_reg(w_RegRw_220_dout ));
//   reg_rw_v1_0  U_RegRw_221(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[110]),.i_ini_value(mem[221]),.i_wdat(i_wr_data2[110]),.o_reg(w_RegRw_221_dout ));
//   reg_rw_v1_0  U_RegRw_222(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[111]),.i_ini_value(mem[222]),.i_wdat(i_wr_data1[111]),.o_reg(w_RegRw_222_dout ));
//   reg_rw_v1_0  U_RegRw_223(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[111]),.i_ini_value(mem[223]),.i_wdat(i_wr_data2[111]),.o_reg(w_RegRw_223_dout ));
                                                                 
//   reg_rw_v1_0  U_RegRw_224(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[112]),.i_ini_value(mem[224]),.i_wdat(i_wr_data1[112]),.o_reg(w_RegRw_224_dout ));
//   reg_rw_v1_0  U_RegRw_225(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[112]),.i_ini_value(mem[225]),.i_wdat(i_wr_data2[112]),.o_reg(w_RegRw_225_dout ));
//   reg_rw_v1_0  U_RegRw_226(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[113]),.i_ini_value(mem[226]),.i_wdat(i_wr_data1[113]),.o_reg(w_RegRw_226_dout ));
//   reg_rw_v1_0  U_RegRw_227(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[113]),.i_ini_value(mem[227]),.i_wdat(i_wr_data2[113]),.o_reg(w_RegRw_227_dout ));
//   reg_rw_v1_0  U_RegRw_228(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[114]),.i_ini_value(mem[228]),.i_wdat(i_wr_data1[114]),.o_reg(w_RegRw_228_dout ));
//   reg_rw_v1_0  U_RegRw_229(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[114]),.i_ini_value(mem[229]),.i_wdat(i_wr_data2[114]),.o_reg(w_RegRw_229_dout ));
//   reg_rw_v1_0  U_RegRw_230(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[115]),.i_ini_value(mem[230]),.i_wdat(i_wr_data1[115]),.o_reg(w_RegRw_230_dout ));
//   reg_rw_v1_0  U_RegRw_231(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[115]),.i_ini_value(mem[231]),.i_wdat(i_wr_data2[115]),.o_reg(w_RegRw_231_dout ));
//   reg_rw_v1_0  U_RegRw_232(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[116]),.i_ini_value(mem[232]),.i_wdat(i_wr_data1[116]),.o_reg(w_RegRw_232_dout ));
//   reg_rw_v1_0  U_RegRw_233(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[116]),.i_ini_value(mem[233]),.i_wdat(i_wr_data2[116]),.o_reg(w_RegRw_233_dout ));
//   reg_rw_v1_0  U_RegRw_234(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[117]),.i_ini_value(mem[234]),.i_wdat(i_wr_data1[117]),.o_reg(w_RegRw_234_dout ));
//   reg_rw_v1_0  U_RegRw_235(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[117]),.i_ini_value(mem[235]),.i_wdat(i_wr_data2[117]),.o_reg(w_RegRw_235_dout ));
//   reg_rw_v1_0  U_RegRw_236(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[118]),.i_ini_value(mem[236]),.i_wdat(i_wr_data1[118]),.o_reg(w_RegRw_236_dout ));
//   reg_rw_v1_0  U_RegRw_237(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[118]),.i_ini_value(mem[237]),.i_wdat(i_wr_data2[118]),.o_reg(w_RegRw_237_dout ));
//   reg_rw_v1_0  U_RegRw_238(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[119]),.i_ini_value(mem[238]),.i_wdat(i_wr_data1[119]),.o_reg(w_RegRw_238_dout ));
//   reg_rw_v1_0  U_RegRw_239(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[119]),.i_ini_value(mem[239]),.i_wdat(i_wr_data2[119]),.o_reg(w_RegRw_239_dout ));
//   reg_rw_v1_0  U_RegRw_240(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[120]),.i_ini_value(mem[240]),.i_wdat(i_wr_data1[120]),.o_reg(w_RegRw_240_dout ));
//   reg_rw_v1_0  U_RegRw_241(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[120]),.i_ini_value(mem[241]),.i_wdat(i_wr_data2[120]),.o_reg(w_RegRw_241_dout ));
//   reg_rw_v1_0  U_RegRw_242(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[121]),.i_ini_value(mem[242]),.i_wdat(i_wr_data1[121]),.o_reg(w_RegRw_242_dout ));
//   reg_rw_v1_0  U_RegRw_243(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[121]),.i_ini_value(mem[243]),.i_wdat(i_wr_data2[121]),.o_reg(w_RegRw_243_dout ));
//   reg_rw_v1_0  U_RegRw_244(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[122]),.i_ini_value(mem[244]),.i_wdat(i_wr_data1[122]),.o_reg(w_RegRw_244_dout ));
//   reg_rw_v1_0  U_RegRw_245(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[122]),.i_ini_value(mem[245]),.i_wdat(i_wr_data2[122]),.o_reg(w_RegRw_245_dout ));
//   reg_rw_v1_0  U_RegRw_246(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[123]),.i_ini_value(mem[246]),.i_wdat(i_wr_data1[123]),.o_reg(w_RegRw_246_dout ));
//   reg_rw_v1_0  U_RegRw_247(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[123]),.i_ini_value(mem[247]),.i_wdat(i_wr_data2[123]),.o_reg(w_RegRw_247_dout ));
//   reg_rw_v1_0  U_RegRw_248(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[124]),.i_ini_value(mem[248]),.i_wdat(i_wr_data1[124]),.o_reg(w_RegRw_248_dout ));
//   reg_rw_v1_0  U_RegRw_249(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[124]),.i_ini_value(mem[249]),.i_wdat(i_wr_data2[124]),.o_reg(w_RegRw_249_dout ));
//   reg_rw_v1_0  U_RegRw_250(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[125]),.i_ini_value(mem[250]),.i_wdat(i_wr_data1[125]),.o_reg(w_RegRw_250_dout ));
//   reg_rw_v1_0  U_RegRw_251(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[125]),.i_ini_value(mem[251]),.i_wdat(i_wr_data2[125]),.o_reg(w_RegRw_251_dout ));
//   reg_rw_v1_0  U_RegRw_252(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[126]),.i_ini_value(mem[252]),.i_wdat(i_wr_data1[126]),.o_reg(w_RegRw_252_dout ));
//   reg_rw_v1_0  U_RegRw_253(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[126]),.i_ini_value(mem[253]),.i_wdat(i_wr_data2[126]),.o_reg(w_RegRw_253_dout ));
//   reg_rw_v1_0  U_RegRw_254(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs1[127]),.i_ini_value(mem[254]),.i_wdat(i_wr_data1[127]),.o_reg(w_RegRw_254_dout ));
//   reg_rw_v1_0  U_RegRw_255(.i_clk(clk),.i_rst(aresetn),.i_ini_en(r_val_in),.i_cs(i_cs2[127]),.i_ini_value(mem[255]),.i_wdat(i_wr_data2[127]),.o_reg(w_RegRw_255_dout ));


// wire [63:0] w_pkt_data0 ,w_pkt_data1 ,w_pkt_data2 ,w_pkt_data3 ,w_pkt_data4 ,w_pkt_data5 ,w_pkt_data6 ,w_pkt_data7 ;
// wire [63:0] w_pkt_data8 ,w_pkt_data9 ,w_pkt_data10,w_pkt_data11,w_pkt_data12,w_pkt_data13,w_pkt_data14,w_pkt_data15;
// wire [63:0] w_pkt_data16,w_pkt_data17,w_pkt_data18,w_pkt_data19,w_pkt_data20,w_pkt_data21,w_pkt_data22,w_pkt_data23;
// wire [63:0] w_pkt_data24,w_pkt_data25,w_pkt_data26,w_pkt_data27,w_pkt_data28,w_pkt_data29,w_pkt_data30,w_pkt_data31;
// assign w_pkt_data0  = {w_RegRw_07_dout ,w_RegRw_06_dout ,w_RegRw_05_dout ,w_RegRw_04_dout ,w_RegRw_03_dout ,w_RegRw_02_dout ,w_RegRw_01_dout ,w_RegRw_00_dout };//64bit
// assign w_pkt_data1  = {w_RegRw_15_dout ,w_RegRw_14_dout ,w_RegRw_13_dout ,w_RegRw_12_dout ,w_RegRw_11_dout ,w_RegRw_10_dout ,w_RegRw_09_dout ,w_RegRw_08_dout };
// assign w_pkt_data2  = {w_RegRw_23_dout ,w_RegRw_22_dout ,w_RegRw_21_dout ,w_RegRw_20_dout ,w_RegRw_19_dout ,w_RegRw_18_dout ,w_RegRw_17_dout ,w_RegRw_16_dout };
// assign w_pkt_data3  = {w_RegRw_31_dout ,w_RegRw_30_dout ,w_RegRw_29_dout ,w_RegRw_28_dout ,w_RegRw_27_dout ,w_RegRw_26_dout ,w_RegRw_25_dout ,w_RegRw_24_dout };
// assign w_pkt_data4  = {w_RegRw_39_dout ,w_RegRw_38_dout ,w_RegRw_37_dout ,w_RegRw_36_dout ,w_RegRw_35_dout ,w_RegRw_34_dout ,w_RegRw_33_dout ,w_RegRw_32_dout };
// assign w_pkt_data5  = {w_RegRw_47_dout ,w_RegRw_46_dout ,w_RegRw_45_dout ,w_RegRw_44_dout ,w_RegRw_43_dout ,w_RegRw_42_dout ,w_RegRw_41_dout ,w_RegRw_40_dout };
// assign w_pkt_data6  = {w_RegRw_55_dout ,w_RegRw_54_dout ,w_RegRw_53_dout ,w_RegRw_52_dout ,w_RegRw_51_dout ,w_RegRw_50_dout ,w_RegRw_49_dout ,w_RegRw_48_dout };
// assign w_pkt_data7  = {w_RegRw_63_dout ,w_RegRw_62_dout ,w_RegRw_61_dout ,w_RegRw_60_dout ,w_RegRw_59_dout ,w_RegRw_58_dout ,w_RegRw_57_dout ,w_RegRw_56_dout };//512
// assign w_pkt_data8  = {w_RegRw_71_dout ,w_RegRw_70_dout ,w_RegRw_69_dout ,w_RegRw_68_dout ,w_RegRw_67_dout ,w_RegRw_66_dout ,w_RegRw_65_dout ,w_RegRw_64_dout };//32bit
// assign w_pkt_data9  = {w_RegRw_79_dout ,w_RegRw_78_dout ,w_RegRw_77_dout ,w_RegRw_76_dout ,w_RegRw_75_dout ,w_RegRw_74_dout ,w_RegRw_73_dout ,w_RegRw_72_dout };
// assign w_pkt_data10 = {w_RegRw_87_dout ,w_RegRw_86_dout ,w_RegRw_85_dout ,w_RegRw_84_dout ,w_RegRw_83_dout ,w_RegRw_82_dout ,w_RegRw_81_dout ,w_RegRw_80_dout };
// assign w_pkt_data11 = {w_RegRw_95_dout ,w_RegRw_94_dout ,w_RegRw_93_dout ,w_RegRw_92_dout ,w_RegRw_91_dout ,w_RegRw_90_dout ,w_RegRw_89_dout ,w_RegRw_88_dout };
// assign w_pkt_data12 = {w_RegRw_103_dout,w_RegRw_102_dout,w_RegRw_101_dout,w_RegRw_100_dout,w_RegRw_99_dout ,w_RegRw_98_dout ,w_RegRw_97_dout ,w_RegRw_96_dout };
// assign w_pkt_data13 = {w_RegRw_111_dout,w_RegRw_110_dout,w_RegRw_109_dout,w_RegRw_108_dout,w_RegRw_107_dout,w_RegRw_106_dout,w_RegRw_105_dout,w_RegRw_104_dout};
// assign w_pkt_data14 = {w_RegRw_119_dout,w_RegRw_118_dout,w_RegRw_117_dout,w_RegRw_116_dout,w_RegRw_115_dout,w_RegRw_114_dout,w_RegRw_113_dout,w_RegRw_112_dout};
// assign w_pkt_data15 = {w_RegRw_127_dout,w_RegRw_126_dout,w_RegRw_125_dout,w_RegRw_124_dout,w_RegRw_123_dout,w_RegRw_122_dout,w_RegRw_121_dout,w_RegRw_120_dout};
// assign w_pkt_data16 = {w_RegRw_135_dout,w_RegRw_134_dout,w_RegRw_133_dout,w_RegRw_132_dout,w_RegRw_131_dout,w_RegRw_130_dout,w_RegRw_129_dout,w_RegRw_128_dout};//64bit
// assign w_pkt_data17 = {w_RegRw_143_dout,w_RegRw_142_dout,w_RegRw_141_dout,w_RegRw_140_dout,w_RegRw_139_dout,w_RegRw_138_dout,w_RegRw_137_dout,w_RegRw_136_dout};
// assign w_pkt_data18 = {w_RegRw_151_dout,w_RegRw_150_dout,w_RegRw_149_dout,w_RegRw_148_dout,w_RegRw_147_dout,w_RegRw_146_dout,w_RegRw_145_dout,w_RegRw_144_dout};
// assign w_pkt_data19 = {w_RegRw_159_dout,w_RegRw_158_dout,w_RegRw_157_dout,w_RegRw_156_dout,w_RegRw_155_dout,w_RegRw_154_dout,w_RegRw_153_dout,w_RegRw_152_dout};
// assign w_pkt_data20 = {w_RegRw_167_dout,w_RegRw_166_dout,w_RegRw_165_dout,w_RegRw_164_dout,w_RegRw_163_dout,w_RegRw_162_dout,w_RegRw_161_dout,w_RegRw_160_dout};
// assign w_pkt_data21 = {w_RegRw_175_dout,w_RegRw_174_dout,w_RegRw_173_dout,w_RegRw_172_dout,w_RegRw_171_dout,w_RegRw_170_dout,w_RegRw_169_dout,w_RegRw_168_dout};
// assign w_pkt_data22 = {w_RegRw_183_dout,w_RegRw_182_dout,w_RegRw_181_dout,w_RegRw_180_dout,w_RegRw_179_dout,w_RegRw_178_dout,w_RegRw_177_dout,w_RegRw_176_dout};
// assign w_pkt_data23 = {w_RegRw_191_dout,w_RegRw_190_dout,w_RegRw_189_dout,w_RegRw_188_dout,w_RegRw_187_dout,w_RegRw_186_dout,w_RegRw_185_dout,w_RegRw_184_dout};//512
// assign w_pkt_data24 = {w_RegRw_199_dout,w_RegRw_198_dout,w_RegRw_197_dout,w_RegRw_196_dout,w_RegRw_195_dout,w_RegRw_194_dout,w_RegRw_193_dout,w_RegRw_192_dout};//32bit
// assign w_pkt_data25 = {w_RegRw_207_dout,w_RegRw_206_dout,w_RegRw_205_dout,w_RegRw_204_dout,w_RegRw_203_dout,w_RegRw_202_dout,w_RegRw_201_dout,w_RegRw_200_dout};
// assign w_pkt_data26 = {w_RegRw_215_dout,w_RegRw_214_dout,w_RegRw_213_dout,w_RegRw_212_dout,w_RegRw_211_dout,w_RegRw_210_dout,w_RegRw_209_dout,w_RegRw_208_dout};
// assign w_pkt_data27 = {w_RegRw_223_dout,w_RegRw_222_dout,w_RegRw_221_dout,w_RegRw_220_dout,w_RegRw_219_dout,w_RegRw_218_dout,w_RegRw_217_dout,w_RegRw_216_dout};
// assign w_pkt_data28 = {w_RegRw_231_dout,w_RegRw_230_dout,w_RegRw_229_dout,w_RegRw_228_dout,w_RegRw_227_dout,w_RegRw_226_dout,w_RegRw_225_dout,w_RegRw_224_dout};
// assign w_pkt_data29 = {w_RegRw_239_dout,w_RegRw_238_dout,w_RegRw_237_dout,w_RegRw_236_dout,w_RegRw_235_dout,w_RegRw_234_dout,w_RegRw_233_dout,w_RegRw_232_dout};
// assign w_pkt_data30 = {w_RegRw_247_dout,w_RegRw_246_dout,w_RegRw_245_dout,w_RegRw_244_dout,w_RegRw_243_dout,w_RegRw_242_dout,w_RegRw_241_dout,w_RegRw_240_dout};
// assign w_pkt_data31 = {w_RegRw_255_dout,w_RegRw_254_dout,w_RegRw_253_dout,w_RegRw_252_dout,w_RegRw_251_dout,w_RegRw_250_dout,w_RegRw_249_dout,w_RegRw_248_dout}; 


// always @(posedge clk) begin
//     if(~aresetn) begin
//         o_pkt_data0 <= 0;//64bit
//         o_pkt_data1 <= 0;
//         o_pkt_data2 <= 0;
//         o_pkt_data3 <= 0;
//         o_pkt_data4 <= 0;
//         o_pkt_data5 <= 0;
//         o_pkt_data6 <= 0;
//         o_pkt_data7 <= 0;//512
//         o_pkt_data_valid <= 1'b0;
//     end
//     else if(reg_end) begin
//         o_pkt_data0 <= {w_pkt_data3 ,w_pkt_data2 ,w_pkt_data1 ,w_pkt_data0 };//64bit
//         o_pkt_data1 <= {w_pkt_data7 ,w_pkt_data6 ,w_pkt_data5 ,w_pkt_data4 };
//         o_pkt_data2 <= {w_pkt_data11,w_pkt_data10,w_pkt_data9 ,w_pkt_data8 };
//         o_pkt_data3 <= {w_pkt_data15,w_pkt_data14,w_pkt_data13,w_pkt_data12};
//         o_pkt_data4 <= {w_pkt_data19,w_pkt_data18,w_pkt_data17,w_pkt_data16};
//         o_pkt_data5 <= {w_pkt_data23,w_pkt_data22,w_pkt_data21,w_pkt_data20};
//         o_pkt_data6 <= {w_pkt_data27,w_pkt_data26,w_pkt_data25,w_pkt_data24};
//         o_pkt_data7 <= {w_pkt_data31,w_pkt_data30,w_pkt_data29,w_pkt_data28};//512
//         o_pkt_data_valid <= 1'b1;

//     end
//     else begin
//        o_pkt_data0 <= o_pkt_data0;
//        o_pkt_data1 <= o_pkt_data1;
//        o_pkt_data2 <= o_pkt_data2;
//        o_pkt_data3 <= o_pkt_data3;
//        o_pkt_data4 <= o_pkt_data4;
//        o_pkt_data5 <= o_pkt_data5;
//        o_pkt_data6 <= o_pkt_data6;
//        o_pkt_data7 <= o_pkt_data7;
//        o_pkt_data_valid <= 1'b0;
//     end
// end

// // ila_2 ila_ram_out2B (
// // 	.clk(clk), // input wire clk
// //  //catch the data to dma
// // 	.probe0 (o_pkt_data6), // input wire [255:0]  probe0   4B
// // 	.probe1 (o_pkt_data7), // input wire [255:0]  probe1   4B
	
// // 	.probe2 ({w_RegRw_224_dout,w_RegRw_225_dout,w_RegRw_232_dout,w_RegRw_233_dout}), // input wire [255:0]  probe2
// //     .probe3 ({w_RegRw_240_dout,w_RegRw_241_dout,w_RegRw_248_dout,w_RegRw_249_dout}), // input wire [0:0] probe3
// //     .probe4 (state  ),// input wire [31:0]   probe4
// //     .probe5 (reg_end)// input wire [31:0]   probe4

// // );



// endmodule