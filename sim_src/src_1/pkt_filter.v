//过滤器的一拍延迟已经消除，该过滤器支持数据一旦进入之后，可以连续读出。
//整个流水除必要中断外，fifo可以连续读出。
//三段的控制报文没有从过滤器输出
`timescale 1ns / 1ps
`define ETH_TYPE_IPV4   16'h0008 //0800
`define IPPROT_UDP      8'h11
`define CONTROL_PORT    16'hf2f1
`define ETH_TYPE_IPV6	16'hdd86 //86dd
`define TPID            16'h0081

module pkt_filter #(
	parameter C_S_AXIS_DATA_WIDTH = 256,
	parameter C_S_AXIS_TUSER_WIDTH = 128
)(
    input  wire                                 clk,
    input  wire                                 aresetn,

// input Slave AXI Stream
    input  wire [C_S_AXIS_DATA_WIDTH-1:0]       s_axis_tdata,
    input  wire [((C_S_AXIS_DATA_WIDTH/8))-1:0] s_axis_tkeep,
    input  wire [C_S_AXIS_TUSER_WIDTH-1:0]      s_axis_tuser,
    input  wire                                 s_axis_tvalid,
    input  wire                                 s_axis_tlast,
    output wire                                 s_axis_tready,
    
// output Master AXI Stream(data)
    output reg [C_S_AXIS_DATA_WIDTH-1:0]        m_axis_tdata,
    output reg[((C_S_AXIS_DATA_WIDTH/8))-1:0]   m_axis_tkeep,
    output reg[C_S_AXIS_TUSER_WIDTH-1:0]        m_axis_tuser,
    output reg                                  m_axis_tvalid,
    output reg                                  m_axis_tlast,
    input  wire                                 m_axis_tready,	
// output Master AXI Stream(control)
    output reg [C_S_AXIS_DATA_WIDTH-1:0]        ctrl_m_axis_tdata,
    output reg [((C_S_AXIS_DATA_WIDTH/8))-1:0]  ctrl_m_axis_tkeep,
    output reg [C_S_AXIS_TUSER_WIDTH-1:0]       ctrl_m_axis_tuser,
    output reg                                  ctrl_m_axis_tvalid,
    output reg                                  ctrl_m_axis_tlast
);

localparam  WAIT_FIRST_PKT  = 3'b000,
            WAIT_SECOND_PKT = 3'b001,
            BUFFER_CTL      = 3'b010,
            BUFFER_DATA     = 3'b011;

localparam  FIL_OUT_IDLE    = 3'b000,//起始状态机跳转
			FIL_OUT_SWITCH  = 3'b001,//一包数据后状态机跳转
            FLUSH_CTL       = 3'b010,
            FLUSH_DATA      = 3'b011;
			

assign s_axis_tready = (m_axis_tready &&!pkt_fifo_nearly_full);

// reg  [3:0] vlan_id;
// wire [11:0] w_vlan_id;
// assign  w_vlan_id = tdata_fifo[116+:12];

wire [C_S_AXIS_DATA_WIDTH-1:0]		tdata_fifo;
wire [C_S_AXIS_TUSER_WIDTH-1:0]		tuser_fifo;
wire [C_S_AXIS_DATA_WIDTH/8-1:0]	tkeep_fifo;
wire								tlast_fifo;

reg                                 pkt_fifo_wr_en  ;
reg                                 pkt_fifo_rd_en  ;
reg [C_S_AXIS_DATA_WIDTH-1:0]       r_s_axis_tdata_0;
reg [((C_S_AXIS_DATA_WIDTH/8))-1:0] r_s_axis_tkeep_0;
reg [C_S_AXIS_TUSER_WIDTH-1:0]      r_s_axis_tuser_0;
reg                                 r_s_axis_tvalid_0;
reg                                 r_s_axis_tlast_0;
reg                                 rd_fifo_flag; 
reg [1:0]                           c_switch;

fallthrough_small_fifo #(
	.WIDTH(C_S_AXIS_DATA_WIDTH + C_S_AXIS_TUSER_WIDTH + C_S_AXIS_DATA_WIDTH/8 + 1),
	.MAX_DEPTH_BITS(5)
)
filter_fifo
(
	.din									({r_s_axis_tdata_0, r_s_axis_tuser_0, r_s_axis_tkeep_0, r_s_axis_tlast_0}),
	.wr_en									(pkt_fifo_wr_en),
	.rd_en									(pkt_fifo_rd_en),
	.dout									({tdata_fifo, tuser_fifo, tkeep_fifo, tlast_fifo}),
	.full									(),
	.prog_full								(),
	.nearly_full							(pkt_fifo_nearly_full),
	.empty									(pkt_fifo_empty),
	.reset									(~aresetn),
	.clk									(clk)
);


always @(posedge clk) begin
	if(!aresetn)begin
		r_s_axis_tdata_0  <= 0;
		r_s_axis_tkeep_0  <= 0;
		r_s_axis_tuser_0  <= 0;
		r_s_axis_tvalid_0 <= 0;
		r_s_axis_tlast_0  <= 0;
	end
	else if(s_axis_tvalid)begin
        r_s_axis_tdata_0  <= s_axis_tdata ;
        r_s_axis_tkeep_0  <= s_axis_tkeep ;
        r_s_axis_tuser_0  <= s_axis_tuser ;
        r_s_axis_tvalid_0 <= s_axis_tvalid;
        r_s_axis_tlast_0  <= s_axis_tlast ;  
	end
	else begin
		r_s_axis_tdata_0  <= 0;
        r_s_axis_tkeep_0  <= 0;
        r_s_axis_tuser_0  <= 0;
        r_s_axis_tvalid_0 <= 0;
        r_s_axis_tlast_0  <= 0; 
	end
end

reg [2:0] fil_in_state;

always @(posedge clk) begin
	 if(!aresetn)begin
		pkt_fifo_wr_en <= 1'b0;
		c_switch <= 2'b00;
		rd_fifo_flag <= 1'b0;
		fil_in_state <= WAIT_FIRST_PKT;
	 end
	 else begin
		case(fil_in_state)
			WAIT_FIRST_PKT:begin
				c_switch   <= 2'd0;
				rd_fifo_flag <= 1'b0;
				if(s_axis_tvalid)begin
					if((s_axis_tdata[143:128]==`ETH_TYPE_IPV4)&&(s_axis_tdata[223:216]==`IPPROT_UDP)&&(s_axis_tdata[111:96]==`TPID)) begin
						pkt_fifo_wr_en <= 1'b1;
						fil_in_state <= WAIT_SECOND_PKT;//当是ipv4报文是时候要判别是控制报文还是数据报文
					end
					else if((s_axis_tdata[143:128]==`ETH_TYPE_IPV6 )&& (s_axis_tdata[111:96]==`TPID)&&(s_axis_tdata[199:192]==`IPPROT_UDP))begin
						rd_fifo_flag <= 1'b1;
						pkt_fifo_wr_en <= 1'b1;
						fil_in_state <= BUFFER_DATA;//当是ipv6报文时候确定是数据报文，可以直接启动读取的状态机
					end
					else begin
						pkt_fifo_wr_en <= 1'b0;//既不是数据报文又不是控制报文时候，等待新的数据到来
						fil_in_state <= WAIT_FIRST_PKT;
					end
				end
				else begin
					pkt_fifo_wr_en <= 1'b0;
					fil_in_state <= WAIT_FIRST_PKT;
				end
			end

			WAIT_SECOND_PKT:begin //第2包报文有效时候，读取第一段报文，同时判别该报文是控制报文还是数据报文
				if(s_axis_tvalid) begin
					rd_fifo_flag <= 1'b1;
					pkt_fifo_wr_en <= 1'b1;
					if (s_axis_tdata[64+:16]==`CONTROL_PORT) begin
						c_switch <= 2'b11;
						fil_in_state <= BUFFER_CTL;
					end
					else begin
						c_switch <= 2'b01; 
						fil_in_state <= BUFFER_DATA;
					end
				end
				else begin
					pkt_fifo_wr_en <= 1'b0;
					fil_in_state <= WAIT_SECOND_PKT;
				end
			end

			BUFFER_CTL:begin
				rd_fifo_flag <= 1'b1;
				c_switch <= 2'b11;
				if(s_axis_tvalid && s_axis_tlast) begin//控制报文写到最后
					pkt_fifo_wr_en <= 1'b1;
					fil_in_state <= WAIT_FIRST_PKT;
				end
				else if(s_axis_tvalid) begin //控制报文继续写入
					pkt_fifo_wr_en <= 1'b1;
					fil_in_state <= BUFFER_CTL;
				end
				else begin
					pkt_fifo_wr_en <= 1'b0;//报文段中断不写入无效报文
					fil_in_state <= BUFFER_CTL;
				end
			end

			BUFFER_DATA:begin 
				rd_fifo_flag <= 1'b1;
				c_switch <= 2'b01;
				if(s_axis_tvalid && s_axis_tlast) begin
					pkt_fifo_wr_en <= 1'b1;
					fil_in_state <= WAIT_FIRST_PKT;
				end
				else if(s_axis_tvalid) begin
					pkt_fifo_wr_en <= 1'b1;
					fil_in_state <= BUFFER_DATA;
				end
				else begin
					pkt_fifo_wr_en <= 1'b0;
					fil_in_state <= BUFFER_DATA;
				end
			end

		endcase
	 end
end

reg [2:0] fil_out_state;
reg r_tlast_fifo;

always @(posedge clk) begin
	if(!aresetn)
		r_tlast_fifo <= 1'b0;
	else
		r_tlast_fifo <= tlast_fifo;
end

always @(posedge clk) begin
	 if(!aresetn)begin
		pkt_fifo_rd_en <= 1'b0;
		ctrl_m_axis_tdata  <= 0;
		ctrl_m_axis_tkeep  <= 0;
		ctrl_m_axis_tuser  <= 0;
		ctrl_m_axis_tvalid <= 0;
		ctrl_m_axis_tlast  <= 0;
		fil_out_state <= FIL_OUT_IDLE;
		m_axis_tdata  <= 0;
		m_axis_tkeep  <= 0;
		m_axis_tuser  <= 0;
		m_axis_tvalid <= 0;
		m_axis_tlast  <= 0;
	 end
	 else begin
		case(fil_out_state)
			FIL_OUT_IDLE:begin//fifo不是一开始就有数据，要等待3包数据之后才有数据
				m_axis_tdata   <= 0 ;
				m_axis_tkeep   <= 0 ;
				m_axis_tuser   <= 0 ;
				m_axis_tvalid  <= 0 ;
				m_axis_tlast   <= 0 ;
				ctrl_m_axis_tdata  <= 0;
				ctrl_m_axis_tkeep  <= 0;
				ctrl_m_axis_tuser  <= 0;
				ctrl_m_axis_tvalid <= 0;
				ctrl_m_axis_tlast  <= 0;
				if(c_switch == 2'b11) begin
					fil_out_state <= FLUSH_CTL;
					pkt_fifo_rd_en <= 1'b1;
				end
				else if(c_switch == 2'b01)begin
					fil_out_state <= FLUSH_DATA;
					pkt_fifo_rd_en <= 1'b1;
				end
				else begin
					fil_out_state <= FIL_OUT_IDLE;
					pkt_fifo_rd_en <= 1'b0;
				end
			end

			FIL_OUT_SWITCH:begin
				if(!pkt_fifo_empty) begin //连续读第二包数据，因为空状态置高比tdata输出要慢一拍
					pkt_fifo_rd_en <= 1'b1;
					if(c_switch == 2'b11) begin
						fil_out_state <= FLUSH_CTL;
						ctrl_m_axis_tdata  <= tdata_fifo;
						ctrl_m_axis_tkeep  <= tkeep_fifo;
						ctrl_m_axis_tuser  <= tuser_fifo;
						ctrl_m_axis_tvalid <= 1'b1;
						ctrl_m_axis_tlast  <= tlast_fifo;
					end
					else if(c_switch == 2'b01)begin
						fil_out_state <= FLUSH_DATA;
						m_axis_tdata  <= tdata_fifo;
						m_axis_tkeep  <= tkeep_fifo;
						m_axis_tuser  <= tuser_fifo;
						m_axis_tvalid <= 1'b1;
						m_axis_tlast  <= tlast_fifo;
					end
					else begin
						fil_out_state <= FIL_OUT_IDLE;
						ctrl_m_axis_tdata  <= 0;
						ctrl_m_axis_tkeep  <= 0;
						ctrl_m_axis_tuser  <= 0;
						ctrl_m_axis_tvalid <= 0;
						ctrl_m_axis_tlast  <= 0;
						m_axis_tdata   <= 0 ;
						m_axis_tkeep   <= 0 ;
						m_axis_tuser   <= 0 ;
						m_axis_tvalid  <= 0 ;
						m_axis_tlast   <= 0 ;
					end
				end
				else begin //回到初始状态
					pkt_fifo_rd_en <= 1'b0;
					fil_out_state <= FIL_OUT_IDLE; //fifo空了一定可以回到初始状态去取数据，因为要至少有三拍，空的状态置高
					ctrl_m_axis_tdata  <= 0;//最后一拍读取的数据无效
					ctrl_m_axis_tkeep  <= 0;
					ctrl_m_axis_tuser  <= 0;
					ctrl_m_axis_tvalid <= 0;
					ctrl_m_axis_tlast  <= 0;
					m_axis_tdata   <= 0 ;
					m_axis_tkeep   <= 0 ;
					m_axis_tuser   <= 0 ;
					m_axis_tvalid  <= 0 ;
					m_axis_tlast   <= 0 ;
				end
			end

			FLUSH_CTL:begin
				if(m_axis_tready)begin //下一个模块准备好了
					if(tlast_fifo & !r_tlast_fifo) begin //读报文结束
						ctrl_m_axis_tdata  <= tdata_fifo;
						ctrl_m_axis_tkeep  <= tkeep_fifo;
						ctrl_m_axis_tuser  <= tuser_fifo;
						ctrl_m_axis_tvalid <= 1'b1;
						ctrl_m_axis_tlast  <= tlast_fifo;
						fil_out_state <= FIL_OUT_SWITCH;
						pkt_fifo_rd_en <= 1'b1;//最后一拍仍可以读取，但是可以由下一状态的空满判定报文是否有效
					end
					else begin
						fil_out_state <= FLUSH_CTL;
						if(pkt_fifo_empty)begin //读报文没有结束但是fifo空了
							pkt_fifo_rd_en <= 1'b1;
							ctrl_m_axis_tdata  <= 0;
						    ctrl_m_axis_tkeep  <= 0;
						    ctrl_m_axis_tuser  <= 0;
						    ctrl_m_axis_tvalid <= 0;
						    ctrl_m_axis_tlast  <= 0;
						end
						else begin //fifo没有空，继续读
							if(pkt_fifo_rd_en)begin
								ctrl_m_axis_tdata  <= tdata_fifo;
								ctrl_m_axis_tkeep  <= tkeep_fifo;
								ctrl_m_axis_tuser  <= tuser_fifo;
								ctrl_m_axis_tvalid <= 1'b1;
								ctrl_m_axis_tlast  <= tlast_fifo;
							end
							else begin
								ctrl_m_axis_tdata  <= 0;
								ctrl_m_axis_tkeep  <= 0;
								ctrl_m_axis_tuser  <= 0;
								ctrl_m_axis_tvalid <= 0;
								ctrl_m_axis_tlast  <= 0;
							end
							pkt_fifo_rd_en <= 1'b1;
						end
					end
				end
				else begin
					pkt_fifo_rd_en <= 1'b0;
					ctrl_m_axis_tdata  <= 0;
					ctrl_m_axis_tkeep  <= 0;
					ctrl_m_axis_tuser  <= 0;
					ctrl_m_axis_tvalid <= 0;
					ctrl_m_axis_tlast  <= 0;
					fil_out_state <= FLUSH_CTL;
				end
			end

			FLUSH_DATA:begin
				if(m_axis_tready)begin
					if(!r_tlast_fifo & tlast_fifo) begin
						m_axis_tdata  <= tdata_fifo;
						m_axis_tkeep  <= tkeep_fifo;
						m_axis_tuser  <= tuser_fifo;
						m_axis_tvalid <= 1'b1;
						m_axis_tlast  <= tlast_fifo;
						fil_out_state <= FIL_OUT_SWITCH;
						pkt_fifo_rd_en <= 1'b1;
					end
					else begin
						fil_out_state <= FLUSH_DATA;
						if(pkt_fifo_empty)begin
							pkt_fifo_rd_en <= 1'b1;
							m_axis_tdata  <= 0;
						    m_axis_tkeep  <= 0;
						    m_axis_tuser  <= 0;
						    m_axis_tvalid <= 0;
						    m_axis_tlast  <= 0;
						end
						else begin
							if(pkt_fifo_rd_en)begin
								m_axis_tdata  <= tdata_fifo;
								m_axis_tkeep  <= tkeep_fifo;
								m_axis_tuser  <= tuser_fifo;
								m_axis_tvalid <= 1'b1;
								m_axis_tlast  <= tlast_fifo;
							end
							else begin
								m_axis_tdata  <= 0;
						    	m_axis_tkeep  <= 0;
						    	m_axis_tuser  <= 0;
						    	m_axis_tvalid <= 0;
						    	m_axis_tlast  <= 0;
							end
							pkt_fifo_rd_en <= 1'b1;
						end
					end
				end
				else begin
					pkt_fifo_rd_en <= 1'b0;
					m_axis_tdata   <= 0 ;
					m_axis_tkeep   <= 0 ;
					m_axis_tuser   <= 0 ;
					m_axis_tvalid  <= 0 ;
					m_axis_tlast   <= 0 ;
				end
			end
		endcase
	 end
end

endmodule
