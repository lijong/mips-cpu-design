`timescale 1ns / 1ps
//*************************************************************************
//   > 文件名: adder.v
//   > 描述  ：加法器，直接使用"+"，会自动调用库里的加法器
//*************************************************************************
module adder(
    input  [31:0] operand1,
    input  [31:0] operand2,
    input         cin,
    output [31:0] result,
    output        cout
	//output overflow
    );
    assign {cout,result} = operand1 + operand2 + cin;
    // assign overflow =  (operand1[31] == operand2[31] == 1'b1 & result[31] == 1'b0 )  ?  1'b1 :
						// (operand1[31] == operand2[31] == 1'b0 & result[31] == 1'b1 ) ?  1'b1 :
						// 1'b0;
endmodule
