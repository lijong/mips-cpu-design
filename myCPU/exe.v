`timescale 1ns / 1ps
//*************************************************************************
//   > �ļ���: exe.v
//   > ����  :�弶��ˮCPU��ִ��ģ��
//*************************************************************************
module exe(                         // ִ�м�
    input              EXE_valid,   // ִ�м���Ч�ź�
    input      [174:0] ID_EXE_bus_r,// ID->EXE����+1
    output             EXE_over,    // EXEģ��ִ�����
    output     [158:0] EXE_MEM_bus, // EXE->MEM����+1
    input              clk,       // ʱ��
    output     [  4:0] EXE_wdest,   // EXE��Ҫд�ؼĴ����ѵ�Ŀ���ַ��
 	output     [  3:0] fuhao,
    //ʾPC
    output     [ 31:0] EXE_pc
);
//-----{ID->EXE����}begin
    //EXE��Ҫ�õ�����Ϣ
    wire multiply;          //�˷�
	wire multiplyu;         //�޷��ų˷�
	wire divsion;          //����
	wire divsionu;         //�޷��ų���
    wire mthi;             //MTHI
    wire mtlo;             //MTLO
    wire [11:0] alu_control;
    wire [31:0] alu_operand1;
    wire [31:0] alu_operand2;
  
    //�ô���Ҫ�õ���load/store��Ϣ
    wire [4:0] mem_control;  //MEM��Ҫʹ�õĿ����ź�+1
    wire [31:0] store_data;  //store�����Ĵ������
                          
    //д����Ҫ�õ�����Ϣ
    wire mfhi;
    wire mflo;
    wire mtc0;
    wire mfc0;
    wire [7 :0] cp0r_addr;
    wire       syscall;   //syscall��eret��д�ؼ�������Ĳ��� 
    wire       eret;
    wire       rf_wen;    //д�صļĴ���дʹ��
    wire [4:0] rf_wdest;  //д�ص�Ŀ�ļĴ���
    
    //pc
    wire [31:0] pc;
	wire br;
    wire flage_out ; //�Ƿ�ΪҪ�ж������ָ��
	wire flag;    //  �����־
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
//-----{ID->EXE����}end

//-----{ALU}begin
    wire [31:0] alu_result;
    
    alu alu_module(
        .alu_control  (alu_control ),  // I, 12, ALU�����ź�
        .alu_src1     (alu_operand1),  // I, 32, ALU������1
        .alu_src2     (alu_operand2),  // I, 32, ALU������2
        .alu_result   (alu_result  ) // O, 32, ALU���
    );
    wire zheng1,zheng2,fu1,fu2;

	
	//����ж�
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
//-----{�˷���}begin
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
//-----{�˷���}end

//-----{������}begin
    wire        div_begin;
	wire [31:0]temp_shang;
	wire [31:0]temp_yushu;

	wire        div_end;
	assign div_begin = (divsion | divsionu) & EXE_valid;
//����������ʱ����a��b��������ʱ����Դ������
	wire [31:0] a;
	wire [31:0]  b;
	assign a = alu_operand1; 
	assign b = alu_operand2;
//�������������������Դ�������ľ���ֵ��������ֻ�������ֵ	
	reg[31:0]div_operand1;
	reg[31:0]div_operand2;
//��������ű�����1��¼����������0��¼��������  ���ڽ�����ֵ����֮��Ľ�����϶�Ӧ�ķ���	
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
//-----{��������}end	
/* reg [31:0] shang;
reg [31:0] yushu;
  always @ (*)
  begin
    shang <= rshang;
	yushu <= ryushu;
  end */
  



//-----{EXEִ�����}begin
    //����ALU����������1�Ŀ���ɣ�
    //�����ڳ˷���������Ҫ�������
    //assign EXE_over = EXE_valid & (~multiply | ~multiplyu | ~divsion | ~divsionu | mult_end | div_end);
	assign EXE_over = (multiply|multiplyu) ? (EXE_valid&mult_end) :
					  (divsion|divsionu)  ?  (EXE_valid&div_end)  :
					   EXE_valid;
//-----{EXEִ�����}end

//-----{EXEģ���destֵ}begin
   //ֻ����EXEģ����Чʱ����д��Ŀ�ļĴ����Ų�������
    assign EXE_wdest = rf_wdest & {5{EXE_valid}};
//-----{EXEģ���destֵ}end

//-----{EXE->MEM����}begin
    wire [31:0] exe_result;   //��exe����ȷ��������д�ؽ��
    wire [31:0] lo_result;
    wire        hi_write;
    wire        lo_write;
	wire cheng,chu;
	assign cheng = multiply | multiplyu;
	assign chu = divsion |divsionu;
    //Ҫд��HI��ֵ����exe_result�����MULT��MTHIָ��,
    //Ҫд��LO��ֵ����lo_result�����MULT��MTLOָ��,
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
	
    
    assign EXE_MEM_bus = {mem_control,store_data,          //load/store��Ϣ��store����
                          exe_result,                      //exe������
                          lo_result,                       //�˷���32λ���������
                          hi_write,lo_write,               //HI/LOдʹ�ܣ�����
                          mfhi,mflo,                       //WB���õ��ź�,����
                          mtc0,mfc0,cp0r_addr,syscall,eret,//WB���õ��ź�,����
                          rf_wen,rf_wdest,                 //WB���õ��ź�
                          pc,br,true_flagout,notinst,ri};                             //PC
//-----{EXE->MEM����}end

//-----{չʾEXEģ���PCֵ}begin
    assign EXE_pc = pc;
//-----{չʾEXEģ���PCֵ}end
endmodule
