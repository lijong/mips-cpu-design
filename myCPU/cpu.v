`timescale 1ns / 1ps
//*************************************************************************
//   > �ļ���: pipeline_cpu.v
//   > ����  :�弶��ˮCPUģ�飬��ʵ��XX��ָ��
//   >        ָ��rom������ram��ʵ����xilinx IP�õ���Ϊͬ����д
//*************************************************************************
module mycpu_top(  // ������cpu
    input clk,           // ʱ��
    input resetn,        // ��λ�źţ��͵�ƽ��
	input [5:0]int,
    
    output inst_sram_en,
    output [3 :0] inst_sram_wen,
    output [31:0] inst_sram_addr,
    output [31:0] inst_sram_wdata,
    input [31:0]  inst_sram_rdata,
   
    output data_sram_en,
    output [3 :0] data_sram_wen,
    output [31:0] data_sram_addr,
    output [31:0] data_sram_wdata,
    input [31:0] data_sram_rdata,
    output [31:0] IF_pc,
    output [31:0] IF_inst,
	output [31:0] decode_pc,
	output [31:0] EXE_pc,
    output [31:0] MEM_pc,
	output [3:0] fuhao,/////
	output [31:0] cp0r_count,
	output [31:0] cp0r_compare,
    output [31:0] debug_wb_pc,
    output [3 :0] debug_wb_rf_wen,
    output [4 :0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata
   
    );
//------------------------{5����ˮ�����ź�}begin-------------------------//
    assign data_sram_en = 1'b1;
	assign inst_sram_en = 1'b1;
	assign inst_sram_wen = 4'b0;
	assign inst_sram_wdata = 32'b0;
   
	
    //5ģ���valid�ź�
    reg IF_valid;
    reg ID_valid;
    reg EXE_valid;
    reg MEM_valid;
    reg WB_valid;
    //5ģ��ִ������ź�,���Ը�ģ������
    wire IF_over;
    wire ID_over;
    wire EXE_over;
    wire MEM_over;
    wire WB_over;
    //5ģ��������һ��ָ�����
    wire IF_allow_in;
    wire ID_allow_in;
    wire EXE_allow_in;
    wire MEM_allow_in;
    wire WB_allow_in;
    
    // syscall��eret����д�ؼ�ʱ�ᷢ��cancel�źţ�
    wire cancel;    // ȡ���Ѿ�ȡ��������������ˮ��ִ�е�ָ��
	/* wire mem_isbadaddr;
     reg  isbadaddr=1'b0;
	always @ (posedge clk)
	begin
		if (mem_isbadaddr)
			begin
			isbadaddr=1'b1;
			end
		else 
		    isbadaddr=1'b0;
	end */
	 
	
	
    //�������������ź�:������Ч���򱾼�ִ��������¼���������
    assign IF_allow_in  = (IF_over & ID_allow_in) | cancel;
    assign ID_allow_in  = ~ID_valid  | (ID_over  & EXE_allow_in);
    assign EXE_allow_in = ~EXE_valid | (EXE_over & MEM_allow_in);
    assign MEM_allow_in = ~MEM_valid | (MEM_over & WB_allow_in )   ;
    assign WB_allow_in  = ~WB_valid  | WB_over;
   
    //IF_valid���ڸ�λ��һֱ��Ч
   always @(posedge clk)
    begin
        if (!resetn)
        begin
            IF_valid <= 1'b0;
        end
        else
        begin
            IF_valid <= 1'b1;
        end
    end
    
    //ID_valid
    always @(posedge clk)
    begin
        if (!resetn || cancel)
        begin
            ID_valid <= 1'b0;
        end
        else if (ID_allow_in)
        begin
            ID_valid <= IF_over;
        end
    end
    
    //EXE_valid
    always @(posedge clk)
    begin
        if (!resetn || cancel)
        begin
            EXE_valid <= 1'b0;
        end
        else if (EXE_allow_in)
        begin
            EXE_valid <= ID_over;
        end
    end
    
    //MEM_valid
    always @(posedge clk)
    begin
        if (!resetn || cancel )
        begin
            MEM_valid <= 1'b0;
        end
        else if (MEM_allow_in)
        begin
            MEM_valid <= EXE_over;
        end
    end
    
    //WB_valid
    always @(posedge clk)
    begin
        if (!resetn || cancel)
        begin
            WB_valid <= 1'b0;
        end
        else if (WB_allow_in)
        begin
            WB_valid <= MEM_over;
        end
    end
    
    //չʾ5����valid�ź�
    /* assign cpu_5_valid = {12'd0         ,{4{IF_valid }},{4{ID_valid}},
                          {4{EXE_valid}},{4{MEM_valid}},{4{WB_valid}}}; */
//-------------------------{5����ˮ�����ź�}end--------------------------//

//--------------------------{5���������}begin---------------------------//
    wire [ 64:0] IF_ID_bus;   // IF->ID������
    wire [174:0] ID_EXE_bus;  // ID->EXE������
    wire [158:0] EXE_MEM_bus; // EXE->MEM������
    wire [156:0] MEM_WB_bus;  // MEM->WB������
    
    //�������������ź�
    reg [ 64:0] IF_ID_bus_r;
    reg [174:0] ID_EXE_bus_r;
    reg [158:0] EXE_MEM_bus_r;
    reg [156:0] MEM_WB_bus_r;
    
    //IF��ID�������ź�
    always @(posedge clk)
    begin
        if(IF_over && ID_allow_in)
        begin
            IF_ID_bus_r <= IF_ID_bus;
        end
    end
    //ID��EXE�������ź�
    always @(posedge clk)
    begin
        if(ID_over && EXE_allow_in)
        begin
            ID_EXE_bus_r <= ID_EXE_bus;
        end
    end
    //EXE��MEM�������ź�
    always @(posedge clk)
    begin
        if(EXE_over && MEM_allow_in)
        begin
            EXE_MEM_bus_r <= EXE_MEM_bus;
        end
    end    
    //MEM��WB�������ź�
    always @(posedge clk)
    begin
        if(MEM_over && WB_allow_in)
        begin
            MEM_WB_bus_r <= MEM_WB_bus;
        end
    end
//---------------------------{5���������}end----------------------------//

//--------------------------{���������ź�}begin--------------------------//
    //��ת����
    wire [ 32:0] jbr_bus;

    // ��֧�ӳٲ�pc
    // wire [ 31:0] bd_pc;    
    // wire         judge_pc;    

    //IF��inst_ram����
    wire [31:0] inst_addr;
    wire [31:0] inst;
    assign inst = inst_sram_rdata;
	 assign inst_sram_addr = inst_addr;
	

    //ID��EXE��MEM��WB����
    wire [ 4:0] EXE_wdest;
    wire [ 4:0] MEM_wdest;
    wire [ 4:0] WB_wdest;
    
    //MEM��data_ram����    
    wire [ 3:0] dm_wen;
    wire [31:0] dm_addr;
    wire [31:0] dm_wdata;
    wire [31:0] dm_rdata;
		
	assign dm_rdata = data_sram_rdata;

	assign data_sram_wen = dm_wen;
	assign data_sram_addr = dm_addr;
	assign data_sram_wdata = dm_wdata;

    //ID��regfile����
    wire [ 4:0] rs;
    wire [ 4:0] rt;   
    wire [31:0] rs_value;
    wire [31:0] rt_value;
    
    //WB��regfile����
    wire        rf_wen;
	assign debug_wb_rf_wen = {rf_wen,rf_wen,rf_wen,rf_wen};
    wire [ 4:0] rf_wdest;
	assign debug_wb_rf_wnum = rf_wdest;
    wire [31:0] rf_wdata;    
    assign debug_wb_rf_wdata = rf_wdata;
    //WB��IF��Ľ����ź�
    wire [32:0] exc_bus;
//---------------------------{���������ź�}end---------------------------//

//-------------------------{��ģ��ʵ����}begin---------------------------//
    wire next_fetch; //��������ȡָģ�飬��Ҫ������PCֵ
    //IF��������ʱ��������PCֵ��ȡ��һ��ָ��
    assign next_fetch = IF_allow_in;
    fetch IF_module(             // ȡָ��
        .clk       (clk       ),  // I, 1
        .resetn    (resetn    ),  // I, 1
        .IF_valid  (IF_valid  ),  // I, 1
        .next_fetch(next_fetch),  // I, 1
        .inst      (inst      ),  // I, 32
        .jbr_bus   (jbr_bus   ),  // I, 33
        .inst_addr (inst_addr ),  // O, 32
        .IF_over   (IF_over   ),  // O, 1
        .IF_ID_bus (IF_ID_bus ),  // O, 64
        .IF_inst(IF_inst),
		.IF_pc     (IF_pc     ), 
        .exc_bus   (exc_bus   )  // I, 32
        
      /*   //չʾPC��ȡ����ָ��
        // O, 32
         // O, 32 */
    );

    decode ID_module(               // ���뼶
        .ID_valid   (ID_valid   ),  // I, 1
        .IF_ID_bus_r(IF_ID_bus_r),  // I, 64
        .rs_value   (rs_value   ),  // I, 32
        .rt_value   (rt_value   ),  // I, 32
        .rs         (rs         ),  // O, 5
        .rt         (rt         ),  // O, 5
        .jbr_bus    (jbr_bus    ),  // O, 33
//        .inst_jbr   (inst_jbr   ),  // O, 1
        .ID_over    (ID_over    ),  // O, 1
        .ID_EXE_bus (ID_EXE_bus ),  // O, 167
        .IF_over     (IF_over     ),// I, 1
        .EXE_wdest   (EXE_wdest   ),// I, 5
        .MEM_wdest   (MEM_wdest   ),// I, 5
        .WB_wdest    (WB_wdest    ),// I, 5
		/* .bd_pc       (bd_pc       ),// O, 32
		.judge_pc    (judge_pc    ),// O, 1 */
        .ID_pc       (decode_pc       ) // O, 32 */
    ); 

    exe EXE_module(                   // ִ�м�
        .EXE_valid   (EXE_valid   ),  // I, 1
        .ID_EXE_bus_r(ID_EXE_bus_r),  // I, 167
        .EXE_over    (EXE_over    ),  // O, 1 
        .EXE_MEM_bus (EXE_MEM_bus ),  // O, 154
        .clk         (clk         ),  // I, 1
        .EXE_wdest   (EXE_wdest   ),  // O, 5
        .fuhao       (fuhao ),
        .EXE_pc      (EXE_pc      )   // O, 32 */
    );

    mem MEM_module(                     // �ô漶
        .clk          (clk          ),  // I, 1 
        .MEM_valid    (MEM_valid    ),  // I, 1
        .EXE_MEM_bus_r(EXE_MEM_bus_r),  // I, 154
        .dm_rdata     (dm_rdata     ),  // I, 32
        .dm_addr      (dm_addr      ),  // O, 32
        .dm_wen       (dm_wen       ),  // O, 4 
        .dm_wdata     (dm_wdata     ),  // O, 32
        .MEM_over     (MEM_over     ),  // O, 1
        .MEM_WB_bus   (MEM_WB_bus   ),  // O, 118
        .MEM_allow_in (MEM_allow_in ),  // I, 1
        .MEM_wdest    (MEM_wdest    ), // O, 5
       
        //չʾPC
         .MEM_pc       (MEM_pc       )   // O, 32 */
    );          
 
    wb WB_module(                     // д�ؼ�
        .WB_valid    (WB_valid    ),  // I, 1
        .MEM_WB_bus_r(MEM_WB_bus_r),  // I, 118
        .rf_wen      (rf_wen      ),  // O, 1
        .rf_wdest    (rf_wdest    ),  // O, 5
        .rf_wdata    (rf_wdata    ),  // O, 32
          .WB_over     (WB_over     ),  // O, 1
        .clk         (clk         ),  // I, 1
      .resetn      (resetn      ),  // I, 1
        .exc_bus     (exc_bus     ),  // O, 32
        .WB_wdest    (WB_wdest    ),  // O, 5
        .cancel      (cancel      ),  // O, 1
        .cp0r_count(cp0r_count),
		.cp0r_compare(cp0r_compare),
         //չʾPC��HI/LOֵ
        .WB_pc       (debug_wb_pc      )  // O, 32
        /* .HI_data     (HI_data     ),  // O, 32
        .LO_data     (LO_data     )   // O, 32  */
    );

//    inst_rom inst_rom_module(         // ָ��洢��
//        .clka       (clk           ),  // I, 1 ,ʱ��
//        .addra      (inst_addr[9:2]),  // I, 8 ,ָ���ַ
//        .douta      (inst          )   // O, 32,ָ��
//    );
 
    regfile rf_module(        // �Ĵ�����ģ��
        .clk    (clk      ),  // I, 1
        .wen    (rf_wen   ),  // I, 1
        .raddr1 (rs       ),  // I, 5
        .raddr2 (rt       ),  // I, 5
        .waddr  (rf_wdest ),  // I, 5
        .wdata  (rf_wdata ),  // I, 32
        .rdata1 (rs_value ),  // O, 32
        .rdata2 (rt_value ) // O, 32
		/* .bd_pc       (bd_pc    ),  // I, 32
		.judge_pc    (judge_pc    ) // I, 1 */

      /*   //display rf
        .test_addr(rf_addr),  // I, 5
        .test_data(rf_data)   // O, 32 */
    );
    
//    data_ram data_ram_module(   // ���ݴ洢ģ��
//        .clka   (clk         ),  // I, 1,  ʱ��
//        .wea    (dm_wen      ),  // I, 1,  дʹ��
//        .addra  (dm_addr[9:2]),  // I, 8,  ����ַ
//        .dina   (dm_wdata    ),  // I, 32, д����
//        .douta  (dm_rdata    ),  // O, 32, ������

//        //display mem
//        .clkb   (clk          ),  // I, 1,  ʱ��
//        .web    (4'd0         ),  // ��ʹ�ö˿�2��д����
//        .addrb  (mem_addr[9:2]),  // I, 8,  ����ַ
//        .doutb  (mem_data     ),  // I, 32, д����
//        .dinb   (32'd0        )   // ��ʹ�ö˿�2��д����
//    );
//--------------------------{��ģ��ʵ����}end----------------------------//
endmodule