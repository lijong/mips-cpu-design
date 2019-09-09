`timescale 1ns / 1ps
//*************************************************************************
//   > �ļ���: mem.v
//   > ����  :�弶��ˮCPU�ķô�ģ��
//*************************************************************************
`define CONF_ADDR 16'hbfaf
module mem(                          // �ô漶
    input              clk,          // ʱ��
    input              MEM_valid,    // �ô漶��Ч�ź�
    input      [158:0] EXE_MEM_bus_r,// EXE->MEM����+1
    input      [ 31:0] dm_rdata,     // �ô������
    output     [ 31:0] dm_addr,      // �ô��д��ַ
    output reg [  3:0] dm_wen,       // �ô�дʹ��
    output reg [ 31:0] dm_wdata,     // �ô�д����
    output             MEM_over,     // MEMģ��ִ�����
    output     [156:0] MEM_WB_bus,   // MEM->WB����
    input              MEM_allow_in, // MEM�������¼�����
    output     [  4:0] MEM_wdest,    // MEM��Ҫд�ؼĴ����ѵ�Ŀ���ַ��
   
    //��ʾPC
    output     [ 31:0] MEM_pc
);

   wire  isbadaddr;
   wire  store_isbadaddr;
// -----�ж��Ƿ��ǵ�ַ������ź�
	
	reg stop = 0 ;
	wire [31:0]badaddr;
//-----{EXE->MEM����}begin
    //�ô���Ҫ�õ���load/store��Ϣ
    wire [4 :0] mem_control;  //MEM��Ҫʹ�õĿ����ź�
    wire [31:0] store_data;   //store�����Ĵ������
    
    //EXE�����HI/LO����
    wire [31:0] exe_result;
    wire [31:0] lo_result;
    wire        hi_write;
    wire        lo_write;
    
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
	wire true_flagout;
	wire notinst;
	wire ri;
    assign {mem_control,
            store_data,
            exe_result,
            lo_result,
            hi_write,
            lo_write,
            mfhi,
            mflo,
            mtc0,
            mfc0,
            cp0r_addr,
            syscall,
            eret,
            rf_wen,
            rf_wdest,
            pc,br  ,true_flagout,notinst,ri } = EXE_MEM_bus_r;  
//-----{EXE->MEM����}end
    





//-----{load/store�ô�}begin
    wire inst_load;  //load����
    wire inst_store; //store����
    wire [1:0]ls_word;    //load/storeΪ�ֽڻ�����,00:byte;10:word;01:halfword
    wire lb_sign;    //loadһ�ֽ�Ϊ�з���load
  
    assign {inst_load,inst_store,ls_word,lb_sign} = mem_control;

    //�ô��д��ַ
   
	
	///bfafת��Ϊ1faf
	wire [31:0] dm_addr_temp1;
    wire [31:0] dm_addr_temp2;
	assign dm_addr_temp1 = {4'b1000,exe_result[27:0]};
    assign dm_addr_temp2 = {4'b0001,exe_result[27:0]};
   
     assign dm_addr =(exe_result[31:16] == `CONF_ADDR) ?dm_addr_temp2 :
						~notinst ? exe_result :dm_addr_temp1;
    //store������дʹ��
	assign isbadaddr = (inst_load&ls_word==2'b10&dm_addr[1:0]!=2'b00)|(inst_load&ls_word==2'b01&(dm_addr[1:0]==2'b01|dm_addr[1:0]==2'b11));
    assign store_isbadaddr = (inst_store&ls_word==2'b10&dm_addr[1:0]!=2'b00)|(inst_store&ls_word==2'b01&(dm_addr[1:0]==2'b01|dm_addr[1:0]==2'b11));
	assign badaddr = dm_addr;
	always @(posedge clk)
	begin 
		if (isbadaddr | store_isbadaddr)
			begin
			stop  = 1'b1;
			end
		else
		begin
			stop  = 1'b0;
			end
		
	end
	
	
     always @ (*)    // �ڴ�дʹ���ź�
    begin
        if (MEM_valid && inst_store && ~stop) // �ô漶��Чʱ,��Ϊstore����
			begin
				if (ls_word == 2'b10)
					begin
						case (dm_addr[1:0])
							2'b00   : dm_wen <= 4'b1111; // �洢��ָ�дʹ��ȫ1
							default : dm_wen <= 4'b0000;
						endcase
					end
				else if ( ls_word == 2'b01)
					begin
						case (dm_addr[1:0])
							2'b00   : dm_wen <= 4'b0011;
							2'b10   : dm_wen <= 4'b1100;
							default : dm_wen <= 4'b0000;//���������Ӧ�ô������ǵ�ַ������ ��Ӧ����0000
						endcase
					end
				else 
					begin // SBָ���Ҫ���ݵ�ַ����λ��ȷ����Ӧ��дʹ��
						case (dm_addr[1:0])
							2'b00   : dm_wen <= 4'b0001;
							2'b01   : dm_wen <= 4'b0010;
							2'b10   : dm_wen <= 4'b0100;
							2'b11   : dm_wen <= 4'b1000;
							default : dm_wen <= 4'b0000;
						endcase
					end
			end
        else
			begin
				dm_wen <= 4'b0000;
			end
    end 
    
    //store������д����
   always @ (*)  // ����SBָ���Ҫ���ݵ�ַ����λ���ƶ�store���ֽ�����Ӧλ��
    begin
	    if (ls_word[1:0] == 2'b00)
		begin
            case (dm_addr[1:0])
                2'b00   : dm_wdata <= store_data;
                2'b01   : dm_wdata <= {16'd0, store_data[7:0], 8'd0};
                2'b10   : dm_wdata <= {8'd0, store_data[7:0], 16'd0};
                2'b11   : dm_wdata <= {store_data[7:0], 24'd0};
                default : dm_wdata <= store_data;
            endcase
		end
		else if (ls_word[1:0] == 2'b01)
		begin
		    case (dm_addr[1:0])
			    2'b00   : dm_wdata <= store_data;
				2'b10   : dm_wdata <= {store_data[15:0],16'd0};
				default : dm_wdata <= store_data;//��ʵӦ���ǵ�ַ������
		    endcase
		end   
		else 
		begin
			dm_wdata <= store_data;
		end
    end
    
     //load����������
	 wire        load_sign1,load_sign2;
	 reg [31:0] load_result;
	 assign load_sign1 = (dm_addr[1:0]==2'd0) ? dm_rdata[7] :
                       (dm_addr[1:0]==2'd1) ? dm_rdata[15] :
                       (dm_addr[1:0]==2'd2) ? dm_rdata[23] : dm_rdata[31];
	assign load_sign2 = (dm_addr[1:0]==2'd0) ? dm_rdata[15] : dm_rdata[31];
	
	always @ (*)  // ����SBָ���Ҫ���ݵ�ַ����λ���ƶ�store���ֽ�����Ӧλ��
    begin
	    if (ls_word[1:0] == 2'b00)
		begin
            case (dm_addr[1:0])
                2'b00   : load_result <= {{24{lb_sign & load_sign1}}, dm_rdata[7:0]};
                2'b01   : load_result <= {{24{lb_sign & load_sign1}}, dm_rdata[15:8]};
                2'b10   : load_result <= {{24{lb_sign & load_sign1}}, dm_rdata[23:16]};
                2'b11   : load_result <= {{24{lb_sign & load_sign1}}, dm_rdata[31:24]};
                default : load_result <= dm_rdata;
            endcase
		end
		else if (ls_word[1:0] == 2'b01)
		begin
		    case (dm_addr[1:0])
			    2'b00   : load_result <= {{16{lb_sign & load_sign2}}, dm_rdata[15:0]};
				2'b10   : load_result <= {{16{lb_sign & load_sign2}}, dm_rdata[31:16]};
				default : load_result <= dm_rdata;
		    endcase
		end   
		else 
		begin
			load_result <= dm_rdata;
		end
    end
	 
   /*   wire        load_sign;
     wire [31:0] load_result;
    assign load_sign = (dm_addr[1:0]==2'd0) ? dm_rdata[ 7] :
                       (dm_addr[1:0]==2'd1) ? dm_rdata[15] :
                       (dm_addr[1:0]==2'd2) ? dm_rdata[23] : dm_rdata[31] ;
    assign load_result[7:0] = (dm_addr[1:0]==2'd0) ? dm_rdata[ 7:0 ] :
                               (dm_addr[1:0]==2'd1) ? dm_rdata[15:8 ] :
                               (dm_addr[1:0]==2'd2) ? dm_rdata[23:16] :
                                                      dm_rdata[31:24] ;
     assign load_result[31:8]= (ls_word==2'b10) ? dm_rdata[31:8] :
							   (ls_word==2'b01)	? :
							   {24{lb_sign & load_sign}};			 */				                   
//-----{load/store�ô�}end

//-----{MEMִ�����}begin
    //��������RAMΪͬ����д��,
    //�ʶ�loadָ�ȡ����ʱ����һ����ʱ
    //������ַ����һ��ʱ�Ӳ��ܵõ�load������
    //��mem�ڽ���load����ʱ����Ҫ����ʱ�����ȡ������
    //����������������ֻ��Ҫһ��ʱ��
    reg MEM_valid_r;
    always @(posedge clk)
    begin
        if (MEM_allow_in)
        begin
            MEM_valid_r <= 1'b0;
        end
        else
        begin
            MEM_valid_r <= MEM_valid;
        end
    end
    assign MEM_over = inst_load ? MEM_valid_r : MEM_valid;
    //�������ramΪ�첽���ģ���MEM_valid����MEM_over�źţ�
    //��loadһ�����
//-----{MEMִ�����}end


// always @(posedge clk)
// begin 
	// if (stop)
		// begin
		// dm_wen  = 4'b0000;
		// end
// end






//-----{MEMģ���destֵ}begin
   //ֻ����MEMģ����Чʱ����д��Ŀ�ļĴ����Ų�������
    assign MEM_wdest = rf_wdest & {5{MEM_valid}};
//-----{MEMģ���destֵ}end

//-----{MEM->WB����}begin
    wire [31:0] mem_result; //MEM����WB��resultΪload�����EXE���
    assign mem_result = inst_load ? load_result : exe_result;
    
    assign MEM_WB_bus = {rf_wen,rf_wdest,                   // WB��Ҫʹ�õ��ź�
                         mem_result,                        // ����Ҫд�ؼĴ���������
                         lo_result,                         // �˷���32λ���������
                         hi_write,lo_write,                 // HI/LOдʹ�ܣ�����
                         mfhi,mflo,                         // WB��Ҫʹ�õ��ź�,����
                         mtc0,mfc0,cp0r_addr,syscall,eret,  // WB��Ҫʹ�õ��ź�,����
                         pc,br,true_flagout,isbadaddr,badaddr,stop,store_isbadaddr,notinst,ri};                               // PCֵ
//-----{MEM->WB����}begin

//-----{չʾMEMģ���PCֵ}begin
    assign MEM_pc = pc;
//-----{չʾMEMģ���PCֵ}end
endmodule

