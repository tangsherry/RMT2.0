`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/02/24 16:21:02
// Design Name: 
// Module Name: deparser_bram_cfg
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


module deparser_bram_cfg
#(
    parameter	C_AXIS_DATA_WIDTH = 256,
	parameter	C_AXIS_TUSER_WIDTH = 128,
	parameter	DEPARSER_MOD_ID = 3'b101,
	parameter   C_PARSER_RAM_WIDTH = 384
)
(
    input axis_clk,
    input aresetn,

    input      [C_AXIS_DATA_WIDTH-1:0  ]       ctrl_s_axis_tdata      ,
    input      [C_AXIS_TUSER_WIDTH-1:0 ]       ctrl_s_axis_tuser      ,
    input      [C_AXIS_DATA_WIDTH/8-1:0]       ctrl_s_axis_tkeep      ,
    input                                      ctrl_s_axis_tvalid     ,
    input                                      ctrl_s_axis_tlast      ,

	input 									   i_phv_fifo_empty_n     ,
    input      [8:0]                           i_deparser_addrb       ,
    output [C_PARSER_RAM_WIDTH-1:0]            bram_out               ,
	output reg 								   o_bram_out_valid       

    );


    /*================Control Path====================*/
wire [C_AXIS_DATA_WIDTH-1:0] ctrl_s_axis_tdata_swapped;

assign ctrl_s_axis_tdata_swapped = {	ctrl_s_axis_tdata[0+:8],
										ctrl_s_axis_tdata[8+:8],
										ctrl_s_axis_tdata[16+:8],
										ctrl_s_axis_tdata[24+:8],
										ctrl_s_axis_tdata[32+:8],
										ctrl_s_axis_tdata[40+:8],
										ctrl_s_axis_tdata[48+:8],
										ctrl_s_axis_tdata[56+:8],
										ctrl_s_axis_tdata[64+:8],
										ctrl_s_axis_tdata[72+:8],
										ctrl_s_axis_tdata[80+:8],
										ctrl_s_axis_tdata[88+:8],
										ctrl_s_axis_tdata[96+:8],
										ctrl_s_axis_tdata[104+:8],
										ctrl_s_axis_tdata[112+:8],
										ctrl_s_axis_tdata[120+:8],
										ctrl_s_axis_tdata[128+:8],
										ctrl_s_axis_tdata[136+:8],
										ctrl_s_axis_tdata[144+:8],
										ctrl_s_axis_tdata[152+:8],
										ctrl_s_axis_tdata[160+:8],
										ctrl_s_axis_tdata[168+:8],
										ctrl_s_axis_tdata[176+:8],
										ctrl_s_axis_tdata[184+:8],
										ctrl_s_axis_tdata[192+:8],
										ctrl_s_axis_tdata[200+:8],
										ctrl_s_axis_tdata[208+:8],
										ctrl_s_axis_tdata[216+:8],
										ctrl_s_axis_tdata[224+:8],
										ctrl_s_axis_tdata[232+:8],
										ctrl_s_axis_tdata[240+:8],
										ctrl_s_axis_tdata[248+:8]};


reg [8:0]						ctrl_wr_ram_addr;//0-512
reg	[C_PARSER_RAM_WIDTH-1:0]	ctrl_wr_ram_data;
reg								ctrl_wr_ram_en  ;

wire [3:0] deparser_mod_id;
assign deparser_mod_id = ctrl_s_axis_tdata[112+:4];

localparam	WAIT_FIRST_PKT = 0,
			WAIT_SECOND_PKT = 1,
			WAIT_THIRD_PKT = 2,
			WAIT_FOURTH_PKT = 3,
			WRITE_RAM = 4,
			FLUSH_REST_C = 5;

reg [3:0] ctrl_ram_state;


always @(posedge axis_clk) begin
	if(!aresetn) begin
		ctrl_wr_ram_addr <= 0;
		ctrl_wr_ram_data <= 0;
		ctrl_wr_ram_en   <= 0;
		ctrl_ram_state   <= WAIT_FIRST_PKT;
	end
	else begin
		case (ctrl_ram_state)
			WAIT_FIRST_PKT: begin
				// 1st ctrl packet
				ctrl_wr_ram_en <= 1'b0;
				if (ctrl_s_axis_tvalid) 
					ctrl_ram_state <= WAIT_SECOND_PKT;
				else 
					ctrl_ram_state <= WAIT_FIRST_PKT ;
			end
			WAIT_SECOND_PKT: begin
				// 2nd ctrl packet, we can check module ID
				if (ctrl_s_axis_tvalid) begin
					if (deparser_mod_id== DEPARSER_MOD_ID) begin
						ctrl_ram_state <= WAIT_THIRD_PKT;
					end
					else begin
						ctrl_ram_state <= FLUSH_REST_C;
					end
				end
			end
			WAIT_THIRD_PKT: begin // first half of ctrl_wr_ram_data
				ctrl_wr_ram_en <= 1'b0;
				if (ctrl_s_axis_tvalid) begin
					ctrl_wr_ram_data[383-:256] <= ctrl_s_axis_tdata_swapped[255-:256];//16条指令
					if(ctrl_s_axis_tlast) begin
						ctrl_ram_state <= WRITE_RAM;
					end
					else begin
						ctrl_ram_state <= WAIT_FOURTH_PKT;
					end
				end
				else begin
					ctrl_ram_state <= WAIT_THIRD_PKT;
					ctrl_wr_ram_data <= ctrl_wr_ram_data;
				end
			end
			WAIT_FOURTH_PKT: begin // first half of ctrl_wr_ram_data
				if (ctrl_s_axis_tvalid) begin
					ctrl_wr_ram_data[127-:128] <= ctrl_s_axis_tdata_swapped[239-:128];//8条指令
					ctrl_wr_ram_addr <= ctrl_s_axis_tdata_swapped[248-:9];
					ctrl_wr_ram_en <= 1'b1;
					if(ctrl_s_axis_tlast) begin //如果是最后一拍数据，则写入ram，否则跳回接收数据的一拍
						ctrl_ram_state <= WRITE_RAM;
					end
					else begin
						ctrl_ram_state <= WAIT_THIRD_PKT;
					end
				end
				else begin
					ctrl_ram_state <= WAIT_FOURTH_PKT;
					ctrl_wr_ram_data <= ctrl_wr_ram_data;
				end
			end
			WRITE_RAM: begin // second half of ctrl_wr_ram_data
				// if (ctrl_s_axis_tvalid) begin
					ctrl_wr_ram_en <= 1'b0;
					ctrl_ram_state <= WAIT_FIRST_PKT;
					// if (ctrl_s_axis_tlast) 
					// 	ctrl_ram_state <= WAIT_FIRST_PKT;
					// else
					// 	ctrl_ram_state <= FLUSH_REST_C;
				// end
			end
			FLUSH_REST_C: begin
				ctrl_wr_ram_en <= 1'b0;
				if (ctrl_s_axis_tvalid && ctrl_s_axis_tlast) begin
					ctrl_ram_state <= WAIT_FIRST_PKT;
				end
				else 
					ctrl_ram_state <= FLUSH_REST_C;

			end
		endcase
	end
end

reg r1_phv_fifo_empty_n;
wire w_bram_out_valid;
reg r1_bram_out_valid;
// reg o_bram_out_valid;
always @(posedge axis_clk) begin//抓phv非空的边沿，bram会在非空两拍后输出
	if(!aresetn) begin
		r1_phv_fifo_empty_n <= 1'b0;
	end
	else begin
		r1_phv_fifo_empty_n <= i_phv_fifo_empty_n;
	end
end

assign w_bram_out_valid = ~r1_phv_fifo_empty_n & i_phv_fifo_empty_n;

always @(posedge axis_clk) begin
	if(!aresetn) begin
		r1_bram_out_valid <= 1'b0;
		o_bram_out_valid <= 1'b0;
	end
	else begin 
		r1_bram_out_valid <= w_bram_out_valid;
		o_bram_out_valid <= r1_bram_out_valid;
	end
end

//====================该段工程将非本配置模块的控制信号输出=======================
//将控制报文寄存一拍，用于判别第二拍数据里
reg [C_AXIS_DATA_WIDTH-1:0]              r1_ctrl_s_axis_tdata      ;
reg [C_AXIS_TUSER_WIDTH-1:0]             r1_ctrl_s_axis_tuser      ;
reg [C_AXIS_DATA_WIDTH/8-1:0]            r1_ctrl_s_axis_tkeep      ;
reg                                      r1_ctrl_s_axis_tvalid     ;
reg                                      r1_ctrl_s_axis_tlast      ;
always @(posedge axis_clk) begin
    if(!aresetn) begin
        r1_ctrl_s_axis_tdata  <= 0 ;
        r1_ctrl_s_axis_tuser  <= 0 ;
        r1_ctrl_s_axis_tkeep  <= 0 ;
        r1_ctrl_s_axis_tvalid <= 0 ;
        r1_ctrl_s_axis_tlast  <= 0 ;
    end
    else begin
        r1_ctrl_s_axis_tdata  <= ctrl_s_axis_tdata  ;
        r1_ctrl_s_axis_tuser  <= ctrl_s_axis_tuser  ;
        r1_ctrl_s_axis_tkeep  <= ctrl_s_axis_tkeep  ;
        r1_ctrl_s_axis_tvalid <= ctrl_s_axis_tvalid ;
        r1_ctrl_s_axis_tlast  <= ctrl_s_axis_tlast  ;
    end
end

// //该输出跳转状态机没有考虑控制报文连续发出的问题，这个问题暂时不考虑
// reg [2:0] ctrl_data_o_state;
// localparam CTRL_O_IDLE  = 0,
// 		   CTRL_O_JUDGE = 1,
// 		   CTRL_O_FLUSH = 2,
// 		   CTRL_O_STAY  = 3;
// always @(posedge axis_clk) begin
//     if(!aresetn) begin
//         ctrl_m_axis_tdata  <= 0 ;
//         ctrl_m_axis_tuser  <= 0 ;
//         ctrl_m_axis_tkeep  <= 0 ;
//         ctrl_m_axis_tvalid <= 0 ;
//         ctrl_m_axis_tlast  <= 0 ;
// 		ctrl_data_o_state  <= CTRL_O_IDLE;
//     end
//     else begin
// 		case(ctrl_data_o_state)
// 			CTRL_O_IDLE:begin
// 				ctrl_m_axis_tvalid <= 0 ;
//         		if(ctrl_s_axis_tvalid) begin
// 					ctrl_data_o_state  <= CTRL_O_JUDGE ;
// 				end
// 				else begin
// 					ctrl_data_o_state  <= CTRL_O_IDLE ;
// 				end
// 			end
// 			CTRL_O_JUDGE:begin
// 				if(ctrl_s_axis_tvalid) begin
// 					if( parser_mod_id == 4'h1) begin //如果是该模块的配置报文，则不输出
//         			    ctrl_m_axis_tdata  <= 0 ;
//         			    ctrl_m_axis_tuser  <= 0 ;
//         			    ctrl_m_axis_tkeep  <= 0 ;
//         			    ctrl_m_axis_tvalid <= 0 ;
//         			    ctrl_m_axis_tlast  <= 0 ;
// 						ctrl_data_o_state  <= CTRL_O_STAY ;
//         			end
//         			else begin
//         			    ctrl_m_axis_tdata  <= r1_ctrl_s_axis_tdata  ; //如果不是该模块的配置报文，则输出
//         			    ctrl_m_axis_tuser  <= r1_ctrl_s_axis_tuser  ;
//         			    ctrl_m_axis_tkeep  <= r1_ctrl_s_axis_tkeep  ;
//         			    ctrl_m_axis_tvalid <= r1_ctrl_s_axis_tvalid ;
//         			    ctrl_m_axis_tlast  <= r1_ctrl_s_axis_tlast  ;
// 						ctrl_data_o_state <= CTRL_O_FLUSH;
//         			end
// 				end
// 				else begin
// 					ctrl_data_o_state  <= CTRL_O_JUDGE ;
// 					ctrl_m_axis_tdata  <= ctrl_m_axis_tdata ;
// 					ctrl_m_axis_tuser  <= ctrl_m_axis_tuser ;
// 					ctrl_m_axis_tkeep  <= ctrl_m_axis_tkeep ;
// 					ctrl_m_axis_tvalid <= ctrl_m_axis_tvalid;
// 					ctrl_m_axis_tlast  <= ctrl_m_axis_tlast ;
// 				end
// 			end
// 			CTRL_O_FLUSH:begin
// 				ctrl_m_axis_tdata  <= r1_ctrl_s_axis_tdata  ; //如果不是该模块的配置报文，则输出
//         		ctrl_m_axis_tuser  <= r1_ctrl_s_axis_tuser  ;
//         		ctrl_m_axis_tkeep  <= r1_ctrl_s_axis_tkeep  ;
//         		ctrl_m_axis_tvalid <= r1_ctrl_s_axis_tvalid ;
//         		ctrl_m_axis_tlast  <= r1_ctrl_s_axis_tlast  ;
// 				if(r1_ctrl_s_axis_tlast)begin
// 					ctrl_data_o_state  <= CTRL_O_IDLE;
// 				end
// 				else begin
// 					ctrl_data_o_state  <= CTRL_O_FLUSH;
// 				end
// 			end
// 			CTRL_O_STAY:begin
// 				ctrl_m_axis_tdata  <= 0 ;
//         		ctrl_m_axis_tuser  <= 0 ;
//         		ctrl_m_axis_tkeep  <= 0 ;
//         		ctrl_m_axis_tvalid <= 0 ;
//         		ctrl_m_axis_tlast  <= 0 ;
// 				if(r1_ctrl_s_axis_tlast)begin
// 					ctrl_data_o_state  <= CTRL_O_IDLE;
// 				end
// 				else begin
// 					ctrl_data_o_state  <= CTRL_O_STAY;
// 				end
// 			end
// 		endcase
//     end
// end


// =============================================================== //

deparse_act_ram_ip
deparse_act_ram
(
	// write port
	.clka		(axis_clk),
	.addra		(ctrl_wr_ram_addr[8:0]),
	.dina		(ctrl_wr_ram_data),
	.ena		(1'b1),
	.wea		(ctrl_wr_ram_en),

	//
	.clkb		(axis_clk),
	.addrb		(i_deparser_addrb), // [NOTICE:] note that we may change due to little or big endian
	.doutb		(bram_out),
	.enb		(1'b1) // always set to 1
);

endmodule
