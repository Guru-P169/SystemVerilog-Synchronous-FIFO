//interface

interface fifo_if;

    logic clk;
    logic rst_n;

    logic wr_en;
    logic rd_en;

    logic [31:0] wr_data;
    logic [31:0] rd_data;

    logic full;
    logic empty;
     
    logic almost_empty;
    logic almost_full;

endinterface

//transation

class fifo_transaction;

    rand bit wr_en;
    rand bit rd_en;

    rand bit [31:0] wr_data;

    bit [31:0] rd_data;

    bit full;
    bit empty;

    bit almost_full;
    bit almost_empty;

    constraint op_c
    {
        {wr_en,rd_en} inside
        {
            2'b10,
            2'b01,
            2'b11            
        };
    }
endclass

//generator

class generator;

    mailbox #(fifo_transaction) mbx;

    fifo_transaction tr;

    int count=100;

    event done;

    function new(mailbox #(fifo_transaction) mbx);
        this.mbx =mbx;
    endfunction

    task run();

        repeat(count)
        begin   
            tr = new();

            assert(tr.randomize())
            else
                $fatal("randomization Failed");
            
            mbx.put(tr);

            $display("[GEN] wr=%0d rd=%0d data=%0h",tr.wr_en,tr.rd_en,tr.wr_data);

            end

            ->done;

    endtask

endclass


//driver

class driver;

    virtual fifo_if vif;

    mailbox #(fifo_transaction) mbx;

    fifo_transaction tr;

    function new(mailbox#(fifo_transaction) mbx,virtual fifo_if vif);

        this.mbx = mbx;
        this.vif = vif;

    endfunction

    task reset();

        vif.rst_n <= 0;
        vif.wr_en <= 0;
        vif.rd_en <= 0;
        vif.wr_data<= 0;

        repeat(5) @(posedge vif.clk);

        vif.rst_n <= 1;
         
        $display("[DRV] RESET DONE");

    endtask

    task run();

        forever
        begin

            mbx.get(tr);

            @(posedge vif.clk);

            vif.wr_en <= tr.wr_en;
            vif.rd_en <= tr.rd_en;
            vif.wr_data <= tr.wr_data;

            @(posedge vif.clk);

            vif.wr_en <=0;
            vif.rd_en <=0;

        end
    endtask
endclass

//monitor

class monitor;

    virtual fifo_if vif;

    mailbox #(fifo_transaction) mbx;

    fifo_transaction tr;

    function new(mailbox #(fifo_transaction) mbx,virtual fifo_if vif);
        this.mbx =mbx;
        this.vif = vif;

    endfunction

    task run();

        forever
        begin

            @(posedge vif.clk);
            #1;
            tr = new();

            tr.wr_en = vif.wr_en;
            tr.rd_en = vif.rd_en;

            tr.wr_data = vif.wr_data;
            tr.rd_data = vif.rd_data;

            tr.full = vif.full;
            tr.empty = vif.empty;

            tr.almost_empty =vif.almost_empty;
            tr.almost_full = vif.almost_full;

            mbx.put(tr);

            $display("[MON] wr=%0d rd=%0d din=%0h dout=%0h full=%0d empty=%0d af=%0d ae=%0d", tr.wr_en, tr.rd_en, tr.wr_data, tr.rd_data, tr.full, tr.empty, tr.almost_full, tr.almost_empty);
        end
    endtask
endclass

//scoreboard
            
class scoreboard;
    mailbox #(fifo_transaction) mbx; 
    
    fifo_transaction tr; 
    
    bit [31:0] model_fifo[$]; 
    
    bit [31:0] exp_data; 
    
    int pass_count; 
    int fail_count; 
    function new(mailbox #(fifo_transaction) mbx); 
        
        this.mbx = mbx; 
    
    endfunction 
    
    task run(); 
        
        forever 
        begin
            mbx.get(tr);
            
            if(tr.wr_en && !tr.full) 
            begin 
                model_fifo.push_back(tr.wr_data); 
                
                $display("[SCO] PUSH %0h",tr.wr_data); 
            
            end 
            
            
            if(tr.rd_en && !tr.empty) 
            begin 
                if(model_fifo.size() != 0) 
                begin 
                    exp_data = model_fifo.pop_front(); 
                    if(exp_data === tr.rd_data) 
                    begin 
                        pass_count++; 
                    
                        $display("[PASS] EXP=%0h GOT=%0h", exp_data, tr.rd_data); 
                    end 
                    else 
                    begin 
                        fail_count++; 
                        
                        $display("[FAIL] EXP=%0h GOT=%0h", exp_data, tr.rd_data); 
                    
                    end 
                end 
            end
        end 
    endtask 
endclass

//environment

class environment;
    generator gen; 
    driver drv; 
    monitor mon; 
    scoreboard sco; 
    
    mailbox #(fifo_transaction) gen2drv; 
    mailbox #(fifo_transaction) mon2sco; 
    
    virtual fifo_if vif; 
    
    function new(virtual fifo_if vif); 
        this.vif = vif; 
        
        gen2drv = new(); 
        mon2sco = new(); 
        
        gen = new(gen2drv); 
        drv = new(gen2drv,vif); 
        
        mon = new(mon2sco,vif); 
        sco = new(mon2sco); 
    endfunction 
    task run(); 
        drv.reset(); 
        fork
            gen.run(); 
            drv.run(); 
            mon.run(); 
            sco.run(); 
        join_none 
            
        wait(gen.done.triggered); 
         wait(gen2drv.num() == 0);

        repeat(30) @(posedge vif.clk); 
        $display("================================="); 
        $display("PASS COUNT = %0d",sco.pass_count); 
        $display("FAIL COUNT = %0d",sco.fail_count); 
        $display("=================================");
        
         
        
        $finish; 
            
    endtask 
endclass

//tb_env_fifo

module tb_env_fifo; 
    fifo_if vif();
    initial 
    begin 
        vif.clk = 0; 
        forever #5 vif.clk = ~vif.clk; 
        end 
        
        
        sync_fifo #( .DATA_WIDTH(32), .ADDR_WIDTH(4) ) dut ( .clk(vif.clk), .rst_n(vif.rst_n), .wr_en(vif.wr_en), .wr_data(vif.wr_data), .rd_en(vif.rd_en), .full(vif.full), .almost_full(vif.almost_full), .rd_data(vif.rd_data), .empty(vif.empty), .almost_empty(vif.almost_empty) );
        
        
        environment env; 
        
        initial 
        begin 
            env = new(vif); 
            
            env.gen.count = 500; 
            
            env.run(); 
        end
    initial begin
        $shm_open("waves.shm");
        $shm_probe("AS");
    end
        
       
    endmodule