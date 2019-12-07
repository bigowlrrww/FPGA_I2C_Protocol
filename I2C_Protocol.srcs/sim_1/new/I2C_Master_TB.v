`timescale 1ns / 1ns
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/14/2019 08:26:27 PM
// Design Name: 
// Module Name: I2C_Master_TB
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


module I2C_Master_TB();
    reg clk;			//system clock
    reg reset_n;		//active low reset
    reg ena;			//enable data transfer
    reg [6:0] addr;			//address of target slave
    reg rw;			//0 is write, 1 is read
    reg [7:0] data_wr;		//data to write to slave
    wire busy;		//inicates transmission in progress
    wire [7:0] data_rd;		//data read from slave
    wire ack_error;	//flag if improper acknowledgement from slave
    wire sda;		//Serial data output of i2c bus
    wire scl;		//Serial clock output of i2c bus
    
    //TB Variables
    reg ctrl;
    reg sdas;
    
    always
        #5 clk = !clk;
    
//    pullup(sda);
//    pullup(scl);
        
    initial
    begin
        
        clk = 0;
        reset_n = 0;
        ena = 0;
        addr = 7'b1101000; //or 7'b1101001;
        rw = 0; //Write operation
        data_wr = 8'b1010_1010;
        #10
        @(posedge clk)
        $display("starting...");
        reset_n = 1;
        #100 @(posedge clk)
        ena = 1;
//        #40;
//        ena = 0;
        
        //$finish;
    end
    
    always @(negedge sda)
        ena = 0;
    
    always @(posedge clk)
    begin
        if (sda == 1'bz)
        begin
            sdas = 0;
            ctrl = 1;
        end
        else
        begin
            sdas = 1;
            ctrl = 0;
        end
    end
    
    assign sda = ctrl ? sdas : 1'bz;
    //UUT
    I2C_Master i2c0(.clk(clk),.reset_n(reset_n),.ena(ena),.addr(addr),.rw(rw),.data_wr(data_wr),.busy(busy),.data_rd(data_rd),.ack_error(ack_error),.sda(sda),.scl(scl));
endmodule