`timescale 1ns / 1ps
//*************************************************************************
//   > 文件名: wb.v
//   > 描述  :五级流水CPU的写回模块
//*************************************************************************
`define EXC_ENTER_ADDR 32'hbfc00380    // Excption入口地址，
                                 // 此处实现的Exception只有SYSCALL
module wb(                       // 写回级
    input          WB_valid,     // 写回级有效
    input  [156:0] MEM_WB_bus_r, // MEM->WB总线
    output         rf_wen,       // 寄存器写使能
    output [  4:0] rf_wdest,     // 寄存器写地址
    output [ 31:0] rf_wdata,     // 寄存器写数据
    output         WB_over,      // WB模块执行完成
    input             clk,       // 时钟
    input             resetn,    // 复位信号，低电平有效
    output [ 32:0] exc_bus,      // Exception pc总线
    output [  4:0] WB_wdest,     // WB级要写回寄存器堆的目标地址号
    output         cancel,       // syscall和eret到达写回级时会发出cancel信号，取消已经取出的正在其他流水级执行的指令
    output reg [31:0] cp0r_count=32'b0,
	output reg [31:0] cp0r_compare,
     //示PC和HI/LO值
     output [ 31:0] WB_pc,
     output [ 31:0] HI_data,
     output [ 31:0] LO_data
);
//-----{MEM->WB总线}begin    
    //MEM传来的result
    wire [31:0] mem_result;
    //HI/LO数据
    wire [31:0] lo_result;
    wire        hi_write;
    wire        lo_write;
   
    //寄存器堆写使能和写地址
    wire wen;
    wire [4:0] wdest;
    
    //写回需要用到的信息
    wire mfhi;
    wire mflo;
    wire mtc0;
    wire mfc0;
    wire [7 :0] cp0r_addr;
    wire       syscall;   //syscall和eret在写回级有特殊的操作 
    wire       eret;
    wire  br;
    //pc
    wire [31:0] pc;  
	wire true_flagout;	
	wire isbadaddr;
	wire [31:0] badaddr;
	wire stop;
	wire store_isbadaddr;
	wire notinst;
	wire ri;
    assign {wen,
            wdest,
            mem_result,
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
            pc, br, true_flagout,isbadaddr,badaddr,stop,store_isbadaddr,notinst,ri} = MEM_WB_bus_r;
//-----{MEM->WB总线}end




//-----{HI/LO寄存器}begin
    //HI用于存放乘法结果的高32位
    //LO用于存放乘法结果的低32位
    reg [31:0] hi;
    reg [31:0] lo;
    
    //要写入HI的数据存放在mem_result里
    always @(posedge clk)
    begin
        if (hi_write)
        begin
            hi <= mem_result;
        end
    end
    //要写入LO的数据存放在lo_result里
    always @(posedge clk)
    begin
        if (lo_write)
        begin
            lo <= lo_result;
        end
    end
//-----{HI/LO寄存器}end

//-----{cp0寄存器}begin
// cp0寄存器即是协处理器0寄存器
// 由于目前设计的CPU并不完备，所用到的cp0寄存器也很少
// 故暂时只实现STATUS(12.0),CAUSE(13.0),EPC(14.0)这三个
// 每个CP0寄存器都是使用5位的cp0号
   reg count_clk=1'b1;
   always@(posedge clk)
   begin
   count_clk=~count_clk;
   end
   wire [31:0] cp0r_status;
   wire [31:0] cp0r_cause;
   wire [31:0] cp0r_epc;
   reg [31:0] cp0r_badvaddr;
   //reg [31:0] cp0r_count=32'b0;
  // reg [31:0] cp0r_compare = 32'hffffffff;
   always@(posedge count_clk)
 
   begin
   if(~ti)
   begin 
   cp0r_count = cp0r_count +1'b1;
   end
   else
   begin
   cp0r_count = 32'b0;
   end
   end
   //写使能
   wire status_wen;
   //wire cause_wen;
   wire epc_wen;
   wire badvaddr_wen;
   wire count_wen;
   wire compare_wen;
   assign count_wen = mtc0 & (cp0r_addr=={5'd9,3'd0});
   assign compare_wen = mtc0 & (cp0r_addr=={5'd11,3'd0});
   assign status_wen = mtc0 & (cp0r_addr=={5'd12,3'd0});
   
   assign epc_wen    = mtc0 & (cp0r_addr=={5'd14,3'd0})&~stop;
   assign badvaddr_wen= isbadaddr|store_isbadaddr|~notinst|~ri;
   //cp0寄存器读
   wire [31:0] cp0r_rdata;
   assign cp0r_rdata = (cp0r_addr=={5'd12,3'd0}) ? cp0r_status :
                       (cp0r_addr=={5'd13,3'd0}) ? cp0r_cause  :
                       (cp0r_addr=={5'd14,3'd0}) ? cp0r_epc :
					   (cp0r_addr=={5'd08,3'd0}) ?  cp0r_badvaddr: 32'd0;
   reg ti = 0 ;
   //STATUS寄存器
   //目前只实现STATUS[1]位，即EXL域
   //EXL域为软件可读写，故需要statu_wen
   reg status_exl_r;
   reg [7:0] IM=8'b0;
   wire ie ;
   assign ie = ((cp0r_compare[7:0]==cp0r_count[7:0])&cp0r_count[7:0]!= 8'b0) ? 1'b1:1'b0;
   assign cp0r_status = {16'h0040,IM,6'b0,status_exl_r,ie};
   always @(posedge clk)
   begin
       if (!resetn || eret)
       begin
           status_exl_r <= 1'b0;
       end
       else if (syscall)
       begin
           status_exl_r <= 1'b1;
       end
	   else if (br)
       begin
           status_exl_r <= 1'b1;
       end
	   else if (true_flagout)
       begin
           status_exl_r <= 1'b1;
       end
	   else if (ti)
       begin
           status_exl_r <= 1'b1;
       end
	    else if (isbadaddr|store_isbadaddr|~notinst|~ri)
       begin
           status_exl_r <= 1'b1;
       end 
       else if (status_wen)
       begin
           status_exl_r <= mem_result[1];
       end
	  
   end
   
   //badaddr寄存器
   always @(*)
      begin
			if (badvaddr_wen)
			begin
				cp0r_badvaddr <= badaddr ;
			end
	  end
	  
   always @(*)
      begin
			if (count_wen)
			begin
				cp0r_count <= mem_result ;
			end
	  end
   always @(*)
	  begin
			if (compare_wen)
			begin
				cp0r_compare <= mem_result ;
			end
	  end
	     always @(*)
	  begin
			if ((cp0r_compare[7:0]==cp0r_count[7:0])&cp0r_count[7:0]!= 8'b0)
			begin
				ti = 1'b1 ;
				IM = 8'hff;
			end
			else
			begin
			   ti = 1'b0;
			end
	  end

	  // always @( posedge clk)
	  // begin
	  // if (ie!=1'b1)
		  // begin
		  // iee = 1'b0;
		  // end
	  // else
			// begin
		  // iee = 1'b1;
		  // end
	  
	  // end 
   //CAUSE寄存器
   //目前只实现CAUSE[6:2]位，即ExcCode域,存放Exception编码
   //ExcCode域为软件只读，不可写，故不需要cause_wen
   reg [4:0] cause_exc_code_r;
   assign cp0r_cause = {1'b0,ti,23'd0,cause_exc_code_r,2'd0};
   always @(posedge clk)
   begin
       if (syscall)
       begin
           cause_exc_code_r <= 5'd8;
       end
	   else if (br)
	   begin
			cause_exc_code_r <= 5'd9;
	   end
	   else if (true_flagout)
	   begin
			cause_exc_code_r <= 5'd12;
	   end
	    else if (isbadaddr|~notinst)
	   begin
			cause_exc_code_r <= 5'd4;
	   end 
	   else if (store_isbadaddr)
	   begin
			cause_exc_code_r <= 5'd5;
	   end 
	   else if (ti)
	   begin
			cause_exc_code_r <= 5'd0;
	   end 
	   else if (~ri)
	   begin
			cause_exc_code_r <= 5'd10;
	   end 
   end
   
   //EPC寄存器
   //存放产生例外的地址
   //EPC整个域为软件可读写的，故需要epc_wen
   reg [31:0] epc_r;
   assign cp0r_epc = epc_r;
   always @(posedge clk)
   begin
       if (syscall)
       begin
           epc_r <= pc;
       end
	   else if (br)
       begin
           epc_r <= pc;
       end
	   else if (true_flagout)
       begin
           epc_r <= pc;
       end
	    else if (isbadaddr|store_isbadaddr|~notinst|~ri|ti)
        begin
            epc_r <= pc;
        end
       else if (epc_wen&~isbadaddr&~store_isbadaddr&notinst&ri&~ti)
       begin
           epc_r <= mem_result;
       end
   end
   
   //syscall和eret发出的cancel信号
   assign cancel = (syscall | br | eret | true_flagout|isbadaddr|store_isbadaddr|~notinst|~ri|ti) & WB_over;
//-----{cp0寄存器}begin

//-----{WB执行完成}begin
    //WB模块所有操作都可在一拍内完成
    //故WB_valid即是WB_over信号
    assign WB_over = WB_valid;
//-----{WB执行完成}end

//-----{WB->regfile信号}begin
    assign rf_wen   = wen & WB_over& ~true_flagout&~isbadaddr&~store_isbadaddr&notinst&ri;
    assign rf_wdest = wdest;
    
    assign rf_wdata = mfhi ? hi :
                      mflo ? lo :
                      mfc0 ? cp0r_rdata : mem_result;
//-----{WB->regfile信号}end

//-----{Exception pc信号}begin
    wire        exc_valid;
    wire [31:0] exc_pc;
    assign exc_valid = (syscall | br | eret | true_flagout |  isbadaddr | store_isbadaddr |~notinst|~ri|ti) & WB_valid;
    //eret返回地址为EPC寄存器的值
    //SYSCALL的excPC应该为{EBASE[31:10],10'h180},
    //但作为实验，先设置EXC_ENTER_ADDR为0，方便测试程序的编写
    assign exc_pc = (syscall | br | true_flagout | isbadaddr | store_isbadaddr|~notinst|~ri|ti) ? `EXC_ENTER_ADDR : cp0r_epc;
    
    assign exc_bus = {exc_valid,exc_pc};
//-----{Exception pc信号}end

//-----{WB模块的dest值}begin
   //只有在WB模块有效时，其写回目的寄存器号才有意义
    assign WB_wdest = rf_wdest & {5{WB_valid}};
//-----{WB模块的dest值}end

//-----{展示WB模块的PC值和HI/LO寄存器的值}begin
    assign WB_pc = pc;
    assign HI_data = hi;
    assign LO_data = lo;
//-----{展示WB模块的PC值和HI/LO寄存器的值}end
endmodule

