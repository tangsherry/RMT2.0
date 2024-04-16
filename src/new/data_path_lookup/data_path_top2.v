`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/01/10 09:19:05
// Design Name: 
// Module Name: data_path_top
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


module data_path_top2 #(
    parameter C_AXIS_DATA_WIDTH      = 256,
    parameter C_AXIS_TUSER_WIDTH     = 128,
    parameter C_PARSER_RAM_WIDTH     = 384,
    parameter CFG_ORDER_NUM          = 128,
    parameter CFG_S_ORDER_WID        = 16 ,
    parameter CFG_TCAM_DEPTH         = 32 ,
    parameter CFG_TCAM_MA_ADDR_WIDTH = 5  ,
    parameter CFG_BIT_MOD_ID         = 12 ,
    parameter CFG_TCAM_MOD_ID        = 8  

)(
    input axis_clk                                          , 
    input aresetn                                           , 
    
	input [C_AXIS_DATA_WIDTH-1:0]       i_dp_segs_tdata	    ,	
	input                               i_dp_segs_valid     ,       
	input                               i_dp_segs_wea	    ,		
	input [2:0]                         i_dp_segs_addra	    ,

    input [7:0]                         i_offset_byte       ,
    input                               i_offset_byte_valid ,

    input [11:0]                        i_wait_vlan         ,
    input                               i_wait_vlan_valid   ,

	input [C_AXIS_DATA_WIDTH-1:0]       ctrl_s_axis_tdata	,	
	input [C_AXIS_TUSER_WIDTH-1:0]      ctrl_s_axis_tuser	,	
	input [C_AXIS_DATA_WIDTH/8-1:0]     ctrl_s_axis_tkeep	,	
	input                               ctrl_s_axis_tvalid	,	
	input                               ctrl_s_axis_tlast	,	

	output [C_AXIS_DATA_WIDTH-1:0]      ctrl_m_axis_tdata	,	
	output [C_AXIS_TUSER_WIDTH-1:0]     ctrl_m_axis_tuser	,	
	output [C_AXIS_DATA_WIDTH/8-1:0]    ctrl_m_axis_tkeep	,	
	output                              ctrl_m_axis_tvalid	,	
	output                              ctrl_m_axis_tlast	,	

	output  [C_PARSER_RAM_WIDTH-1:0]    o_bram              ,
    output                              o_bram_valid        ,
    output  [8:0]                       o_bram_addrb             
    // output reg [C_AXIS_DATA_WIDTH-1:0]  o_dp_segs_tdata	    ,	
	// output reg                          o_dp_segs_valid     ,       
	// output reg                          o_dp_segs_wea	    ,		
	// output reg [2:0]                    o_dp_segs_addra	
    );


wire [CFG_ORDER_NUM*CFG_S_ORDER_WID-1:0] w_cfg_bit_info  ;
wire                                     w_cfg_bit_updata;

//几个需要控制报文的模块串行配置
//数据报文路径解析关键bit位配置模块，输入配置报文，用寄存器的方式输出128X12b的数据
wire [C_AXIS_DATA_WIDTH-1:0  ]    w_ctrl_m_axis_tdata1   ;
wire [C_AXIS_TUSER_WIDTH-1:0 ]    w_ctrl_m_axis_tuser1   ;
wire [C_AXIS_DATA_WIDTH/8-1:0]    w_ctrl_m_axis_tkeep1   ;
wire                              w_ctrl_m_axis_tvalid1  ;
wire                              w_ctrl_m_axis_tlast1   ;
reg [C_AXIS_DATA_WIDTH-1:0  ]     r_ctrl_m_axis_tdata1   ;
reg [C_AXIS_TUSER_WIDTH-1:0 ]     r_ctrl_m_axis_tuser1   ;
reg [C_AXIS_DATA_WIDTH/8-1:0]     r_ctrl_m_axis_tkeep1   ;
reg                               r_ctrl_m_axis_tvalid1  ;
reg                               r_ctrl_m_axis_tlast1   ;

data_path_bit_cfg #(
    .C_AXIS_DATA_WIDTH      (256                    ),
    .C_AXIS_TUSER_WIDTH     (128                    ),
    .CFG_ORDER_NUMBER       (CFG_ORDER_NUM          ),
    .CFG_ORDER_WIDTH        (CFG_S_ORDER_WID        ),
    .CFG_BIT_MOD_ID             (CFG_BIT_MOD_ID         )
)
 data_path_bit_cfg(
    .axis_clk               (axis_clk               ),
    .aresetn                (aresetn                ),
   
    .ctrl_s_axis_tdata      (ctrl_s_axis_tdata      ),
    .ctrl_s_axis_tuser      (ctrl_s_axis_tuser      ),
    .ctrl_s_axis_tkeep      (ctrl_s_axis_tkeep      ),
    .ctrl_s_axis_tvalid     (ctrl_s_axis_tvalid     ),
    .ctrl_s_axis_tlast      (ctrl_s_axis_tlast      ),

    .ctrl_m_axis_tdata      (w_ctrl_m_axis_tdata1   ),
    .ctrl_m_axis_tuser      (w_ctrl_m_axis_tuser1   ),
    .ctrl_m_axis_tkeep      (w_ctrl_m_axis_tkeep1   ),
    .ctrl_m_axis_tvalid     (w_ctrl_m_axis_tvalid1  ),
    .ctrl_m_axis_tlast      (w_ctrl_m_axis_tlast1   ),

    .o_cfg_bit_info         (w_cfg_bit_info         ),//CFG_ORDER_NUM*CFG_S_ORDER_WID
    .o_cfg_bit_updata       (w_cfg_bit_updata       )
    
);

always @(posedge axis_clk)begin
    if(!aresetn) begin
        r_ctrl_m_axis_tdata1  <=   0;
        r_ctrl_m_axis_tuser1  <=   0;
        r_ctrl_m_axis_tkeep1  <=   0;
        r_ctrl_m_axis_tvalid1 <=   0;
        r_ctrl_m_axis_tlast1  <=   0;
    end
    else begin
        r_ctrl_m_axis_tdata1  <=   w_ctrl_m_axis_tdata1 ;
        r_ctrl_m_axis_tuser1  <=   w_ctrl_m_axis_tuser1 ;
        r_ctrl_m_axis_tkeep1  <=   w_ctrl_m_axis_tkeep1 ;
        r_ctrl_m_axis_tvalid1 <=   w_ctrl_m_axis_tvalid1;
        r_ctrl_m_axis_tlast1  <=   w_ctrl_m_axis_tlast1 ;
    end
end

//控制报文配置TCAM，128b数据提取出的关键字查找TCAM，输出匹配地址
//128bX32的TCAM数据，加128bX1的掩码
wire [C_AXIS_DATA_WIDTH-1:0  ]    w_ctrl_m_axis_tdata2   ;
wire [C_AXIS_TUSER_WIDTH-1:0 ]    w_ctrl_m_axis_tuser2   ;
wire [C_AXIS_DATA_WIDTH/8-1:0]    w_ctrl_m_axis_tkeep2   ;
wire                              w_ctrl_m_axis_tvalid2  ;
wire                              w_ctrl_m_axis_tlast2   ;
reg [C_AXIS_DATA_WIDTH-1:0  ]     r_ctrl_m_axis_tdata2   ;
reg [C_AXIS_TUSER_WIDTH-1:0 ]     r_ctrl_m_axis_tuser2   ;
reg [C_AXIS_DATA_WIDTH/8-1:0]     r_ctrl_m_axis_tkeep2   ;
reg                               r_ctrl_m_axis_tvalid2  ;
reg                               r_ctrl_m_axis_tlast2   ;

wire [CFG_ORDER_NUM-1:0]    w_dp_bit            ;
wire                        w_dp_bit_valid      ;
wire [CFG_ORDER_NUM-1:0]    w_dp_bit_mask       ;

wire                                   w_dp_tcam_match     ;
wire [CFG_TCAM_MA_ADDR_WIDTH-1:0]      w_dp_tcam_match_addr;

data_path_tcam_cfg #(
    .C_AXIS_DATA_WIDTH      (C_AXIS_DATA_WIDTH      ),
    .C_AXIS_TUSER_WIDTH     (C_AXIS_TUSER_WIDTH     ),
    .FEATURE_BIT_WIDTH      (CFG_ORDER_NUM          ),//提取特征bit位
    .TCAM_MATCH_ADDR        (CFG_TCAM_MA_ADDR_WIDTH ),
    .TCAM_DEPTH             (CFG_TCAM_DEPTH         ),
    .CFG_TCAM_MOD_ID        (CFG_TCAM_MOD_ID        )
) data_path_tcam_cfg(
    .axis_clk               (axis_clk               ),
    .aresetn                (aresetn                ),
// in
    .ctrl_s_axis_tdata      (r_ctrl_m_axis_tdata1   ),
    .ctrl_s_axis_tuser      (r_ctrl_m_axis_tuser1   ),
    .ctrl_s_axis_tkeep      (r_ctrl_m_axis_tkeep1   ),
    .ctrl_s_axis_tvalid     (r_ctrl_m_axis_tvalid1  ),
    .ctrl_s_axis_tlast      (r_ctrl_m_axis_tlast1   ),

    .ctrl_m_axis_tdata      (w_ctrl_m_axis_tdata2   ),
    .ctrl_m_axis_tuser      (w_ctrl_m_axis_tuser2   ),
    .ctrl_m_axis_tkeep      (w_ctrl_m_axis_tkeep2   ),
    .ctrl_m_axis_tvalid     (w_ctrl_m_axis_tvalid2  ),
    .ctrl_m_axis_tlast      (w_ctrl_m_axis_tlast2   ),
//  
    .i_dp_bit               (w_dp_bit               ),
    .i_dp_bit_valid         (w_dp_bit_valid         ),
    .i_dp_bit_mask          (w_dp_bit_mask          ),
// out     
    .o_dp_tcam_match        (w_dp_tcam_match        ),
    .o_dp_tcam_match_addr   (w_dp_tcam_match_addr   )

);

always @(posedge axis_clk)begin
    if(!aresetn) begin
        r_ctrl_m_axis_tdata2  <=   0;
        r_ctrl_m_axis_tuser2  <=   0;
        r_ctrl_m_axis_tkeep2  <=   0;
        r_ctrl_m_axis_tvalid2 <=   0;
        r_ctrl_m_axis_tlast2  <=   0;
    end
    else begin
        r_ctrl_m_axis_tdata2  <=   w_ctrl_m_axis_tdata2 ;
        r_ctrl_m_axis_tuser2  <=   w_ctrl_m_axis_tuser2 ;
        r_ctrl_m_axis_tkeep2  <=   w_ctrl_m_axis_tkeep2 ;
        r_ctrl_m_axis_tvalid2 <=   w_ctrl_m_axis_tvalid2;
        r_ctrl_m_axis_tlast2  <=   w_ctrl_m_axis_tlast2 ;
    end
end

//输入1024b待提取报文头，输入提取指令，输出128b提取字段
data_path_lookup#(
    .C_AXIS_DATA_WIDTH     (C_AXIS_DATA_WIDTH   ),
    .SEG_ADDR              (3                   ),
    .CFG_ORDER_NUM         (CFG_ORDER_NUM       ),
    .CFG_S_ORDER_WID       (CFG_S_ORDER_WID     )
)
data_path_lookup(
    .axis_clk              (axis_clk            ),
    .aresetn               (aresetn             ),
    
    .i_offset_byte         (i_offset_byte       ),
    .i_offset_byte_valid   (i_offset_byte_valid ),

    .i_dp_segs_tdata       (i_dp_segs_tdata     ),
    .i_dp_segs_valid       (i_dp_segs_valid     ),
    .i_dp_segs_wea         (i_dp_segs_wea       ),
    .i_dp_segs_addra       (i_dp_segs_addra     ),
  
    .i_cfg_bit_info        (w_cfg_bit_info      ),
    .i_cfg_bit_updata      (w_cfg_bit_updata    ),
  
    .o_dp_bit              (w_dp_bit            ),//提取128b关键协议数据
    .o_dp_bit_valid        (w_dp_bit_valid      ),
    .o_dp_bit_mask         (w_dp_bit_mask       ),
     
    .o_dp_segs_tdata  	   (w_dp_segs_tdata     ),
    .o_dp_segs_valid  	   (w_dp_segs_valid     ),
    .o_dp_segs_wea    	   (w_dp_segs_wea       ),
    .o_dp_segs_addra  	   (w_dp_segs_addra     )	
);
// always @(posedge axis_clk) begin
//     if(!aresetn) begin
//         o_dp_segs_tdata <= 0;
//         o_dp_segs_valid <= 0;
//         o_dp_segs_wea   <= 0;
//         o_dp_segs_addra <= 0;
//     end
//     else begin
//         o_dp_segs_tdata <= w_dp_segs_tdata ;
//         o_dp_segs_valid <= w_dp_segs_valid ;
//         o_dp_segs_wea   <= w_dp_segs_wea   ;
//         o_dp_segs_addra <= w_dp_segs_addra ;
//     end
// end

//数据报文parser table配置模块,输入控制报文配置parser_table,同时输入匹配地址及vlan_id,得到输出的控制指令
//bram查找大小 16bX32(每个vlan-id数据路径)X16(vlan_id个数)
parser_bram_cfg#(
    .C_AXIS_DATA_WIDTH      (256                    ),
    .C_AXIS_TUSER_WIDTH     (128                    ),
    .TCAM_MATCH_ADDR        (5                      ),
    .VLAN_ID_WIDTH          (12                     ),
    .C_PARSER_RAM_WIDTH     (16*24                  ),
    .PARSER_MOD_ID          (1                      )
) parser_bram_cfg(
    .axis_clk               (axis_clk               ),
    .aresetn                (aresetn                ),

    .ctrl_s_axis_tdata      (r_ctrl_m_axis_tdata2   ),
    .ctrl_s_axis_tuser      (r_ctrl_m_axis_tuser2   ),
    .ctrl_s_axis_tkeep      (r_ctrl_m_axis_tkeep2   ),
    .ctrl_s_axis_tvalid     (r_ctrl_m_axis_tvalid2  ),
    .ctrl_s_axis_tlast      (r_ctrl_m_axis_tlast2   ),

    .ctrl_m_axis_tdata      (ctrl_m_axis_tdata      ),
    .ctrl_m_axis_tuser      (ctrl_m_axis_tuser      ),
    .ctrl_m_axis_tkeep      (ctrl_m_axis_tkeep      ),
    .ctrl_m_axis_tvalid     (ctrl_m_axis_tvalid     ),
    .ctrl_m_axis_tlast      (ctrl_m_axis_tlast      ),
   
    .i_dp_tcam_match        (w_dp_tcam_match        ),
    .i_dp_tcam_match_addr   (w_dp_tcam_match_addr   ),

    .i_wait_vlan            (i_wait_vlan            ),
    .i_wait_vlan_valid      (i_wait_vlan_valid      ),

    .o_bram_parser          (o_bram                 ),
    .o_bram_parser_valid    (o_bram_valid           ),
    .o_bram_parser_addrb    (o_bram_addrb           )

);


endmodule
