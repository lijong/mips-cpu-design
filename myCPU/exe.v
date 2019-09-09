`timescale 1ns / 1ps
//*************************************************************************
//   > 文件名: exe.v
//   > 描述  :五级流水CPU的执行模块
//*************************************************************************
module exe(                         // 执行级
    input              EXE_valid,   // 执行级有效信号
    input      [174:0] ID_EXE_bus_r,// ID->EXE总线+1
    output             EXE_over,    // EXE模块执行完成
    output     [158:0] EXE_MEM_bus, // EXE->MEM总线+1
    input              clk,       // 时钟
    output     [  4:0] EXE_wdest,   // EXE级要写回寄存器堆的目标地址号
 	output     [  3:0] fuhao,
    //示PC
    output     [ 31:0] EXE_pc
);
//-----{ID->EXE总线}begin
    //EXE需要用到的信息
    wire multiply;          //乘法
	wire multiplyu;         //无符号乘法
	wire divsion;          //除法
	wire divsionu;         //无符号除法
    wire mthi;             //MTHI
    wire mtlo;             //MTLO
    wire [11:0] alu_control;
    wire [31:0] alu_operand1;
    wire [31:0] alu_operand2;
  
    //访存需要用到的load/store信息
    wire [4:0] mem_control;  //MEM需要使用的控制信号+1
    wire [31:0] store_data;  //store操作的存的数据
                          
    //写回需要用到的信息
    wire mfhi;
    wire mflo;
    wire mtc0;
    wire mfc0;
    wire [7 :0] cp0r_addr;
    wire       syscall;   //syscall和eret在写回级有特殊的操作 
    wire       eret;
    wire       rf_wen;    //写回的寄存器写使能
    wire [4:0] rf_wdest;  //写回的目的寄存器
    
    //pc
    wire [31:0] pc;
	wire br;
    wire flage_out ; //是否为要判断溢出的指令
	wire flag;    //  溢出标志
	wire notinst;
	wire ri;
    assign {multiply,
			multiplyu,
			mthi,
			mtlo,
			divsion,
			divsionu,  
            alu_control,
            alu_operand1,
            alu_operand2,
            mem_control,
            store_data,
            mfhi,
            mflo,
            mtc0,
            mfc0,
            cp0r_addr,
            syscall,
            eret,
            rf_wen,
            rf_wdest,
            pc,br,flage_out ,notinst ,ri       } = ID_EXE_bus_r;
//-----{ID->EXE总线}end

//-----{ALU}begin
    wire [31:0] alu_result;
    
    alu alu_module(
        .alu_control  (alu_control ),  // I, 12, ALU控制信号
        .alu_src1     (alu_operand1),  // I, 32, ALU操作数1
        .alu_src2     (alu_operand2),  // I, 32, ALU操作数2
        .alu_result   (alu_result  ) // O, 32, ALU结果
    );
    wire zheng1,zheng2,fu1,fu2;

	
	//溢出判断
	// wire fuhao1,fuhao2;
	// assign fuhao1 = alu_operand1[31];
	// assign fuhao2 = alu_operand2[31];
	// wire fuhao_result;
	// assign fuhao_result = alu_result[31];
	// assign zheng1 = fuhao1&fuhao2&(~fuhao_result)&alu_control[11];
	
	assign  zheng1 = alu_operand1[31]&alu_operand2[31]&(~alu_result[31])&alu_control[11]&1'b1;
	assign  zheng2 = (~alu_operand1[31])&(~alu_operand2[31])&alu_result[31]&alu_control[11];
	assign  fu1 = (~alu_operand1[31])&alu_operand2[31]&alu_result[31]&alu_control[10];
	assign  fu2 = alu_operand1[31]&(~alu_operand2[31])&(~alu_result[31])&alu_control[10];        
     assign  flag = zheng1 | zheng2 | fu1 | fu2;
    assign fuhao = {zheng1,zheng2,fu1,fu2};
//-----{ALU}end
	wire true_flagout;
	assign true_flagout  = flag & flage_out;
//-----{乘法器}begin
    wire        mult_begin; 
    wire [63:0] product; 
    wire        mult_end;
    wire signal;
	assign signal= multiplyu ? 1'b1 : 1'b0;
    assign mult_begin = (multiply|multiplyu) & EXE_valid;
    multiply multiply_module (
        .clk       (clk       ),
		.signal(signal),
        .mult_begin(mult_begin  ),
        .mult_op1  (alu_operand1), 
        .mult_op2  (alu_operand2),
        .product   (product   ),
        .mult_end  (mult_end  )
    );
//-----{乘法器}end

//-----{除法器}begin
    wire        div_begin;
	wire [31:0]temp_shang;
	wire [31:0]temp_yushu;

	wire        div_end;
	assign div_begin = (divsion | divsionu) & EXE_valid;
//定义两个临时变量a，b，用来暂时保存源操作数
	wire [31:0] a;
	wire [31:0]  b;
	assign a = alu_operand1; 
	assign b = alu_operand2;
//定义两个变量保存的是源操作数的绝对值，除法器只能算绝对值	
	reg[31:0]div_operand1;
	reg[31:0]div_operand2;
//定义个符号变量，1记录被除数符号0记录除数符号  用于将绝对值算完之后的结果加上对应的符号	
	reg [1:0]flage;
	reg[31:0]  shang;
	
	reg[31:0]  yushu;
	always @(*)
begin
	if (divsion)
	begin
		if (a[31] == 1'b1 )
			begin
			div_operand1 = ~a +1'b1;
			flage[1] = 1'b1;
			end
		else
			begin
			div_operand1 = a;
			flage[1] = 1'b0;
			end
		if (b[31] == 1'b1)
			begin
			div_operand2 = ~b +1'b1;
			flage[0] = 1'b1;
			end
		else
			begin
			div_operand2 = b;
			flage[0] = 1'b0;
			end
	end		
	else
	   begin 
		 div_operand1 = a;
		 div_operand2 = b;
	    end
	end    
	
	always @(*)
	if (divsion)
	begin
		case(flage)
		2'b00:
			begin
			shang = temp_shang;
			yushu =temp_yushu;
			end
 		2'b01:
			begin
			shang = ~temp_shang +1'b1;
			yushu =temp_yushu;
			end
		2'b10:
			begin
			shang = ~temp_shang + 1'b1;
			yushu =~temp_yushu + 1'b1;
			end
		2'b11:
		    begin
			shang = temp_shang;
			yushu =~temp_yushu + 1'b1;
			end 
		endcase
	end
	else
		begin 
		shang = temp_shang;
		yushu =temp_yushu;
		end
	

	div_rill div_rill_module (
        .clk       (clk       ),
		.rst       ( ~(divsion | divsionu)),
        .enable    (div_begin  ),
        .a         (div_operand1), 
        .b         (div_operand2),
        .yshang    (temp_shang   ),
		.yyushu    (temp_yushu   ),
        .done      (div_end  )
    );
//-----{除法结束}end	
/* reg [31:0] shang;
reg [31:0] yushu;
  always @ (*)
  begin
    shang <= rshang;
	yushu <= ryushu;
  end */
  



//-----{EXE执行完成}begin
    //对于ALU操作，都是1拍可完成，
    //但对于乘法操作，需要多拍完成
    //assign EXE_over = EXE_valid & (~multiply | ~multiplyu | ~divsion | ~divsionu | mult_end | div_end);
	assign EXE_over = (multiply|multiplyu) ? (EXE_valid&mult_end) :
					  (divsion|divsionu)  ?  (EXE_valid&div_end)  :
					   EXE_valid;
//-----{EXE执行完成}end

//-----{EXE模块的dest值}begin
   //只有在EXE模块有效时，其写回目的寄存器号才有意义
    assign EXE_wdest = rf_wdest & {5{EXE_valid}};
//-----{EXE模块的dest值}end

//-----{EXE->MEM总线}begin
    wire [31:0] exe_result;   //在exe级能确定的最终写回结果
    wire [31:0] lo_result;
    wire        hi_write;
    wire        lo_write;
	wire cheng,chu;
	assign cheng = multiply | multiplyu;
	assign chu = divsion |divsionu;
    //要写入HI的值放在exe_result里，包括MULT和MTHI指令,
    //要写入LO的值放在lo_result里，包括MULT和MTLO指令,
    assign exe_result = mthi     ? alu_operand1 :
                        mtc0     ? alu_operand2 : 
                        cheng    ? product[63:32] :
						chu      ? yushu : 
						~notinst ?  pc    :
						          alu_result;
    assign lo_result  = mtlo    ? alu_operand1 : 
	                    chu     ? shang:
						product[31:0];
						                       
    assign hi_write   = multiply | multiplyu | divsion | divsionu | mthi;
    assign lo_write   = multiply | multiplyu | divsion | divsionu | mtlo;
	
    
    assign EXE_MEM_bus = {mem_control,store_data,          //load/store信息和store数据
                          exe_result,                      //exe运算结果
                          lo_result,                       //乘法低32位结果，新增
                          hi_write,lo_write,               //HI/LO写使能，新增
                          mfhi,mflo,                       //WB需用的信号,新增
                          mtc0,mfc0,cp0r_addr,syscall,eret,//WB需用的信号,新增
                          rf_wen,rf_wdest,                 //WB需用的信号
                          pc,br,true_flagout,notinst,ri};                             //PC
//-----{EXE->MEM总线}end

//-----{展示EXE模块的PC值}begin
    assign EXE_pc = pc;
//-----{展示EXE模块的PC值}end
endmodule
