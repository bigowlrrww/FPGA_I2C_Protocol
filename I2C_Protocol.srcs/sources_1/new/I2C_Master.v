`timescale 1ns / 1ps

//I2C_Master I2CM(.clk(clk), .reset_n(reset_n), .ena(ena), .addr(addr), .rw(rw), .data_wr(data_wr), 
//                  .busy(busy), .data_rd(data_rd), .ack_error(ack_error), .sda(sda), .scl(scl));
//input clk,                    system clock                               
//input reset_n,                active low reset                           
//input ena,                    enable data transfer                       
//input [6:0] addr,             address of target slave                    
//input rw,                     0 is write, 1 is read                      
//input [7:0] data_wr,          data to write to slave                     
//output reg busy,              inicates transmission in progress          
//output reg [7:0] data_rd,     data read from slave                       
//output reg ack_error,         flag if improper acknowledgement from slave
//inout sda,                    Serial data output of i2c bus              
//inout scl                     Serial clock output of i2c bus

module I2C_Master(
    input clk,   //system clock
    input reset_n,  //active low reset
    input ena,   //enable data transfer
    input [6:0] addr,   //address of target slave
    input rw,   //0 is write, 1 is read
    input [7:0] data_wr,  //data to write to slave
    output reg busy,  //inicates transmission in progress
    output reg [7:0] data_rd,  //data read from slave
    output reg ack_error, //flag if improper acknowledgement from slave
    inout sda,   //Serial data output of i2c bus
    inout scl   //Serial clock output of i2c bus
    );
    //ensure that the results of the calculation will result in a even bus speed.
    parameter input_clk = 100_000_000;  //frequency of input clk in Hz
    parameter bus_clk = 396_825;  //frequency of the i2c bus (scl) in Hz 
    parameter divider = (input_clk/bus_clk)/4;  //number of clocks in 1/4 cycle of scl
    
    reg data_clk;  //data clock for sda
    reg data_clk_prev; //data clock during pervious system clock
    reg scl_clk;  //constant internal serial clock
    reg scl_ena;  //enables internal scl to output
    reg sda_int;  //internal sda
    wire sda_ena_n;  //enables internal sda to output
    reg stretch;  //identifies if a slave is stretching scl
    
    reg [7:0] addr_rw; //latched in address and read/write {addr,rw}
    reg [7:0] data_tx; //latched in data to write to slave
    reg [7:0] data_rx; //data recived from slave
    reg [divider*4:0] count; //counter for clock devision
    
    integer bit_cnt; //tracks bit number in transmission
    reg [3:0] state;
    
    initial
    begin
        data_clk = 0;
        data_clk_prev = 0;
        scl_clk = 0;
        scl_ena = 0;
        sda_int = 1;
        stretch = 0;
        addr_rw = 0;
        data_tx = 0;
        data_rx = 0;
        count = 0;
        state = 4'b0000; //Start in init state
        busy = 0;
        ack_error = 0;
        data_rd = 0;
    end
    
    
    always @(posedge clk, negedge reset_n)
    begin
        if(reset_n == 1'b0)   //Reset Asserted
        begin
            stretch <= 1'b0;
            count <= 0;
        end
        else if(clk == 1'b1)
        begin
            data_clk_prev <= data_clk; //store previous value of data clock
            if (count == divider*4-1) //end of timing cycle
                count <= 0;    //reset timer
            else if (stretch == 1'b0) //clock stretching from slave not detected
                count <= count + 1;  //continue clock generation
            
            if (count > 0 && count < divider-1)    //first 1/4 cycle of clocking
            begin
                scl_clk <= 1'b0;
                data_clk <= 1'b0;
            end
            else if (count > divider && count < divider*2-1) //second 1/4 cycle of clocking
            begin
                scl_clk <= 1'b0;
                data_clk <= 1'b1;
            end
            else if (count > divider*2 && count < divider*3-1) //third 1/4 cycle of clocking
            begin
                scl_clk <= 1;  //release scl
                if (scl == 1'b0)
                    stretch <= 1'b1;
                else
                    stretch <= 1'b0;                        
                data_clk <= 1'b1;
            end
            else if (count > divider*3 && count < divider*4-1)    //last 1/4 cycle of clocking.
            begin
                scl_clk <= 1'b1;
                data_clk <= 1'b0;
            end
        end
    end
    
    always @(posedge clk, negedge reset_n)
    begin
        if(reset_n == 1'b0)
        begin
            state       <= 4'b0000;  //Ready state
            busy        <= 1'b1;   //indicate not available
            scl_ena     <= 1'b0;   //set scl high impedance
            sda_int     <= 1'b0;   //set sda high impedance
            ack_error   <=  1'b0;   //clear acknowledgement error flag
            bit_cnt     <=  7;    //restarts data bitcounter
            data_rd     <=  8'b0000_0000; //clear the read port
        end
        else if (clk == 1)
        begin
            if(data_clk == 1'b1 && data_clk_prev == 1'b0)
            begin
                case(state)
                4'b0000:  //Ready state
                begin
                    if (ena == 1'b1)   //transfer request
                    begin
                        busy    <= 1'b1;   //flag busy
                        addr_rw <= {addr, rw}; //collect requested slave address and command
                        data_tx <= data_wr;  //collect requested data to write
                        state <= 4'b0001;  //go to start state
                    end
                    else
                    begin
                        busy <= 1'b0;   //unflag busy
                        state <= 4'b0000;  //remain idle
                    end
                end
                
                4'b0001:  //Start State 
                begin
                    busy <= 1'b1;    //resume busy if continuous mode
                    sda_int <= addr_rw[bit_cnt];//set first address bit on bus
                    state <= 4'b0010;   //set state to command
                end
                
                4'b0010:  //Command State
                begin
                    if(bit_cnt == 0)
                    begin
                        sda_int <= 1'b1;  //release sda control
                        bit_cnt <= 7;   //reset bit counter for "byte" state
                        state <= 4'b0011;  //go to slave acknowledgement
                    end
                    else
                    begin
                        bit_cnt <= bit_cnt - 1;   //keep track of transmission bits
                        sda_int <= addr_rw[bit_cnt - 1];//write address/ command bit to bus
                        state <= 4'b0010;    //got to command
                    end
                end
                
                4'b0011:  //slv_ack1 state 
                begin
                    if(addr_rw[0] == 1'b0)    //slave acknowledge bit
                    begin
                        sda_int <= data_tx[bit_cnt]; //write first bit of data
                        state <= 4'b0100;    //go to write state
                    end
                    else
                    begin
                        sda_int <= 1'b1;    //release sda from incoming data
                        state <= 4'b0101;     //go to read state
                    end
                end
                
                4'b0100:  //wr State
                begin
                    busy <= 1'b1;     //resume busy if continous mode
                    if (bit_cnt == 0)    //write byte transmit finished
                    begin
                        sda_int <= 1'b1;   //release sda for slave acknowledgement
                        bit_cnt <= 7;    //reset bit counter for byte state
                        state <= 4'b0110;   //got to slv_ack1
                    end
                    else
                    begin
                        bit_cnt <= bit_cnt - 1;   //keep track of ransaction bits
                        sda_int <= data_tx[bit_cnt-1]; //write next bit to bus
                        state <= 4'b0100;    //continue writing/ go to wr state
                    end
                end
                
                4'b0101:  //rd State
                begin
                    busy <= 1'b1;     //resume busy if continous mode
                    if (bit_cnt == 0)    //read byte receive finished
                    begin
                        if (ena == 1'b1 && addr_rw == {addr, rw}) //continue with another read
                            sda_int <= 1'b0;  //acknowledge the byte has been recived
                        else
                            sda_int <= 1'b1;  //send a no-acknowledge (before stop or repeated start)
                        
                        bit_cnt <= 7;    //reset bit counter for byte states
                        data_rd <= data_rx;   //output recived data
                        state <= 4'b0111;   //got to mstr_ack
                    end
                    else
                    begin
                        bit_cnt <= bit_cnt - 1;  //keep track of transfer bit
                        state <= 4'b0101;   //go to rd state
                    end
                end
                
                4'b0110:  //slv_ack2
                begin
                    if (ena == 1'b1)    //continue transaction
                    begin
                        busy <= 1'b0;    //continue is accepted
                        addr_rw <= {addr, rw};  //collect requested slave address and command
                        data_tx <= data_wr;   //collected requested data to write
                        if (addr_rw == {addr, rw}) //continue with another write
                        begin
                            sda_int <= data_wr[bit_cnt];//write first bit of data
                            state <= 4'b0100;  //go to write state
                        end
                        else      //continue with a new slave
                            state <= 4'b0001;  //go to repeated start
                    end
                    else
                        state <= 4'b1000;   //go to Stop state
                end
                
                4'b0111:  //mstr_ack
                begin
                    if (ena == 1'b1)    //continue transaction
                    begin
                        busy <= 1'b0;    //continue is accepted and data recived is avaliable on bus
                        addr_rw <= {addr, rw};  //collect requested slave address and command
                        data_tx <= data_wr;   //collect requested data to write
                        if (addr_rw == {addr, rw}) //cointinue transaction with another read
                        begin
                            sda_int <= 1'b1;  //release sda from incoming data
                            state <= 4'b0101;  //go to read state
                        end
                        else       //continue with a new slave
                            state <= 4'b0001;  //repeated start
                    end
                    else
                        state <= 4'b1000;   //go to stop state
                end
                
                4'b1000:  //stop state
                begin
                    busy <= 1'b0;  //unflag busy
                    state <= 4'b0000; //go to ready state
                end
                
            endcase
            
            end
            else if (data_clk == 1'b0 && data_clk_prev == 1'b1)
            begin
                case(state)
                    4'b0001:  //start
                    begin
                        if(scl_ena == 1'b0)   //start new tranaction
                        begin
                            scl_ena <= 1'b1;  //enable scl output
                            ack_error <= 1'b0;  //reset acknowledge error output
                        end
                    end
                    
                    4'b0011:  //slv_ack1
                    begin
                        if(sda != 0 || ack_error == 1'b1) //no acknowledge or previous no-acknowledge
                        ack_error <= 1'b1;    //set error output if no-acknowledge
                    end
                    
                    4'b0101:  //rd state
                        data_rx[bit_cnt] <= sda; //receive current slave data bit
                    
                    4'b0110:  //slv_ack2
                    begin
                        if(sda != 1'b0 || ack_error == 1'b1) //no acknowledge or previous no-acknowleedge
                        ack_error <= 1'b1;     //set error output if no-acknowledge
                    end
                    
                    4'b1000:  //stop state
                        scl_ena <= 1'b0;   //disable scl
                    default:;
                endcase
            end
        end
    end
    
    //set sda output
    assign sda_ena_n = (state == 4'b0001) ? data_clk_prev :((state == 4'b1000) ? !data_clk_prev : sda_int);
    
    //set scl and sda outputs
    assign scl = (scl_ena == 1'b1 && scl_clk == 1'b0) ? 0 : 1'bz;
    assign sda = sda_ena_n ? 1'bz : 1'b0;
endmodule

module Start_i2c(
    input clk25MHz, start, wire[19:0] cmp,
    output reg Pend
    );
    
    reg [19:0] cnt; //large enough for any delay 0 to 534378
    reg started;
    
    initial
    begin
        started = 0;
        Pend = 0; //Pulse End
        cnt = 0; //Counter
        cnt = 20'hfffff;
    end
        
    always @(posedge clk25MHz)
    begin
        //add 1 every clock signal
        if(cnt != 20'hfffff)
            cnt <= cnt + 1; //increament but dont roll over.
        if(start && started == 0) //Reset the counter to zero
        begin    
            cnt <= 0;
            started = 1;
        end
        if(start == 0)
            started = 0;
        
        //If the counter is equal to the comparison value
        if(cnt[19:0] >= cmp[19:0])
            Pend <= 0; //End the pulse (toggles the R on SRlatch)
        else
            Pend <= 1;
        //Send the Pulse end(Pend) signal out
    end
endmodule
