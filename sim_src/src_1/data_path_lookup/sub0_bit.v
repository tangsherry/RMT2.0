`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/10/02 15:02:26
// Design Name: 
// Module Name: pre_get_segs
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
//1，5，3，3，2
//[15] tvalid
//[12:8] Bytes offset 0-255,0-111:11111
//[7:5] Byte_in_seg
//[4:2] val_index
//[1:0] val_type,01:2B;10:4B;11:8B
//简单双端口ram可以一边写入一边读出吗？

module sub0_bit #(
    parameter BIT_GROUP_NUM = 4,
    parameter BIT_WIDTH = 16
)(
    input axis_clk,
    input aresetn,

    input [BIT_GROUP_NUM*BIT_WIDTH-1:0]  i_bit_bram,
    input [7:0]   i_offset_byte,
    input         i_offset_byte_valid,

    input [255:0] i_seg_tdata,
    input         i_seg_wea,
    input  [1:0]  i_seg_addra,
    input         i_wait_segs_end,

    output reg [2:0]  o_bit_act_low,//没处理完的指令也输出一下
    output reg        o_bit_act_low_valid,
    output  [7:0]     o_bit_8,         //因为是连续四拍，所以要数据有效信号跟随一下
    output  [3:0]     o_bit_mask
);



reg [2:0] pre_seg_state;
reg [7:0] addrb;
reg [2:0] r_bit_act_low;
reg       r_bit_act_low_valid;

wire [BIT_WIDTH-1:0] bit_order [BIT_GROUP_NUM-1:0];

wire [7:0] mem_addrb [BIT_GROUP_NUM-1:0];
wire  [BIT_GROUP_NUM-1:0] bit_en;
assign o_bit_mask = bit_en;
assign bit_order[3] = i_bit_bram[BIT_WIDTH*4-1:BIT_WIDTH*3];//81
assign bit_order[2] = i_bit_bram[BIT_WIDTH*3-1:BIT_WIDTH*2];
assign bit_order[1] = i_bit_bram[BIT_WIDTH*2-1:BIT_WIDTH*1];//81
assign bit_order[0] = i_bit_bram[BIT_WIDTH*1-1:0];

assign mem_addrb[0] = bit_order[0][10:3];
assign mem_addrb[1] = bit_order[1][10:3];
assign mem_addrb[2] = bit_order[2][10:3];
assign mem_addrb[3] = bit_order[3][10:3];

wire [2:0]mem_addr_low [3:0];
assign mem_addr_low[0] = bit_order[0][2:0];
assign mem_addr_low[1] = bit_order[1][2:0];
assign mem_addr_low[2] = bit_order[2][2:0];
assign mem_addr_low[3] = bit_order[3][2:0];

assign bit_en[0] = bit_order[0][15];
assign bit_en[1] = bit_order[1][15];
assign bit_en[2] = bit_order[2][15];
assign bit_en[3] = bit_order[3][15];

reg r_h_ram_addr;//因为写入和取出ram有冲突，所以分高地址8个ram和低地址8个ram
wire [2:0] w_seg_addra;
assign w_seg_addra = {r_h_ram_addr,i_seg_addra};//存入ram的高位地址或着存入低位地址

//----------- Begin Cut here for INSTANTIATION Template ---// INST_TAG
//256b，深度8进，8b出
ram_d8_w256_d256_w8 O_1B_0 (
  .clka (axis_clk   ),    // input wire clka
  .ena  (1'b1       ),    // input wire ena
  .wea  (i_seg_wea  ),    // input wire [0 : 0] wea
  .addra(w_seg_addra),    // input wire [2 : 0] addra
  .dina (i_seg_tdata),    // input wire [255 : 0] dina
  .clkb (axis_clk   ),    // input wire clkb
  .enb  (1          ),    // input wire enb
  .addrb(addrb      ),    // input wire [4 : 0] addrb
  .doutb(o_bit_8    )     // output wire [63 : 0] doutb
);

// INST_TAG_END ------ End INSTANTIATION Template ---------

// INST_TAG_END ------ End INSTANTIATION Template ---------
localparam IDLE = 3'd0;
localparam O_1ST_PARSER = 3'd1;//第一个parser指令解析
localparam O_2ND_PARSER = 3'd2;//第二个parser指令解析
localparam O_3RD_PARSER = 3'd3;//第三个parser指令解析
localparam O_4TH_PARSER = 3'd4;//第四个parser指令解析
localparam O_5TH_PARSER = 3'd5;
localparam WAIT_RAM     = 3'd6;
localparam WAIT_OFF_BYTE= 3'd7;//等待偏移字节
//here is a state to get the segs_8B_1 and segs_8B_2
//由于24条指令分了两组进sub0_parser模块，但是ram一次只能读取一个地址的数据，
//所以这里的ram取数据逻辑按照parser指令分两拍
always @(posedge axis_clk) begin
	if(!aresetn)begin
        addrb <= 8'd0;
        pre_seg_state <= IDLE;
        r_bit_act_low <= 3'd0;
        r_bit_act_low_valid <= 0;
	end
	else begin
		case(pre_seg_state)
            IDLE:begin
                r_bit_act_low_valid <= 1'b0;
                if(i_wait_segs_end ) begin//因为这里其实会有两拍中断，所以逻辑上还是等一下报文会比较好
                    pre_seg_state <= WAIT_OFF_BYTE;
                end
                else begin
                    pre_seg_state <= IDLE;
                end
            end
            WAIT_OFF_BYTE:begin          //等前一级的偏移字节出来之后再启动读数据
                if(i_offset_byte_valid) begin
                    pre_seg_state <= O_1ST_PARSER;
                end
                else begin
                    pre_seg_state <= WAIT_OFF_BYTE;
                end
            end
			O_1ST_PARSER:begin 
                if(bit_en[0]) begin
                    if(r_h_ram_addr) begin
                        addrb <= mem_addrb[0]+i_offset_byte;//往高位传输，取低位数据
                    end
                    else begin
                        addrb <= mem_addrb[0]+8'd128+i_offset_byte; //跳过读出低的位置取数据
                    end
                    pre_seg_state <= O_2ND_PARSER;
                end
                else begin
                    pre_seg_state <= O_2ND_PARSER;
                    addrb <= 8'd0;
                end
			end
            O_2ND_PARSER:begin 
                r_bit_act_low <= mem_addr_low[0];
                r_bit_act_low_valid <= 1'b1;
                if(bit_en[1]) begin
                    if(r_h_ram_addr) begin
                        addrb <= mem_addrb[1]+i_offset_byte;
                    end
                    else begin
                        addrb <= mem_addrb[1]+8'd128+i_offset_byte; //跳过低的位置取数据
                    end
                    pre_seg_state <= O_3RD_PARSER;
                end
                else begin
                    pre_seg_state <= O_3RD_PARSER;
                    addrb <= 8'd0;
                end
			end
            O_3RD_PARSER:begin 
                r_bit_act_low <= mem_addr_low[1];
                r_bit_act_low_valid <= 1'b1;
                if(bit_en[2]) begin
                    if(r_h_ram_addr) begin
                        addrb <= mem_addrb[2]+i_offset_byte;
                    end
                    else begin
                        addrb <= mem_addrb[2]+8'd128+i_offset_byte; //跳过低的位置取数据
                    end
                    pre_seg_state <= O_4TH_PARSER;
                end
                else begin
                    pre_seg_state <= O_4TH_PARSER;
                    addrb <= 8'd0;
                end
			end
			O_4TH_PARSER:begin
                r_bit_act_low <= mem_addr_low[2];
                r_bit_act_low_valid <= 1'b1;
                if(bit_en[3]) begin//如果parser指令有效，则数据输出
                    if(r_h_ram_addr) begin
                        addrb <= mem_addrb[3]+i_offset_byte;
                    end
                    else begin
                        addrb <= mem_addrb[3]+8'd128+i_offset_byte;
                    end
                    pre_seg_state <= WAIT_RAM;
                end
                else begin //如果parser指令无效，则无数据输出
                    pre_seg_state <= WAIT_RAM;
                    addrb <= 8'd0;
                end
			end
            WAIT_RAM:begin //考虑有效数据报文至少8拍，所以可以加这个状态，不用立即回转
                    r_bit_act_low <= mem_addr_low[3];
                    r_bit_act_low_valid <= 1'b1;
                    pre_seg_state <= IDLE;
            end
            default: begin
				pre_seg_state <= IDLE;
			end
		endcase
	end
end

//每次数据写入完之后存向不同的地址
always @(posedge axis_clk) begin
    if(!aresetn)begin
       r_h_ram_addr <= 1'b0;
	end
    else begin
        if(i_wait_segs_end)//传完4拍数据，接着往哪个位置传输
            r_h_ram_addr <= ~r_h_ram_addr;
        else
            r_h_ram_addr <= r_h_ram_addr;
    end
end

// ila_2 parser_top (
// 	.clk(axis_clk), // input wire clk
//   //catch the data to dma
// 	.probe0 (pre_seg_state  ), // input wire [2:0]  probe0  
// 	.probe1 (addrb ), // input wire [4:0]  probe1 
// 	.probe2 (addrb1  ), // input wire [4:0]  probe2
//     .probe3 (enb      ), // input wire [0:0]  probe3
 
//     .probe4 (o_segs_8B_1      ), // input wire [63:0]    probe7
//     .probe5 (o_segs_8B_2      ) // input wire [63:0]    probe8
// );

always @(posedge axis_clk)begin
    if(!aresetn) begin
        o_bit_act_low <= 8'b0;
        o_bit_act_low_valid <= 1'b0;
    end
    else begin
        o_bit_act_low <= r_bit_act_low;
        o_bit_act_low_valid <= r_bit_act_low_valid;
    end
end

endmodule
