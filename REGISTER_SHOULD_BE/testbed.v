`timescale 1ns/100ps
`define CYCLE       10.0
`define HCYCLE      (`CYCLE/2)
`define MAX_CYCLE   120000

`define PAT_NUM 200
`define DM_word(addr) u_data_mem.mem_r[addr]
`define DM_golden(addr) golden_IM_DM[addr]

module testbed;
  
	logic                               clk;
	logic                             rst_n;
	logic                           dmem_we;
	logic [ 31 : 0 ]              dmem_addr;
	logic [ 31 : 0 ]             dmem_wdata;
	logic [ 31 : 0 ]             dmem_rdata;
	logic [  2 : 0 ]            mips_status;
	logic                 mips_status_valid;

	logic [ 31 : 0 ]  golden_IM_DM [0:2048];
	logic [  2 : 0 ] golden_Status [0:1023];

	logic [ 31 : 0 ] reg_signed_golden [31:0];
	logic [ 31 : 0 ] reg_float_golden  [31:0];

	logic [ 31 : 0 ] reg_signed_core [31:0];
	logic [ 31 : 0 ] reg_float_core  [31:0];
	
	integer      IM_addr;
	integer      errorDM;
	integer  errorStatus;
	string          sTmp;
	
	integer file, status;
	integer cnt;
	`ifndef ALL
		`define times 1
		string pattern_num;
		initial $value$plusargs("pattern_num=%s", pattern_num);
	`else
		`define times `PAT_NUM
	`endif

	core u_core (
		.i_clk         (              clk),
		.i_rst_n       (            rst_n),
		.o_status      (      mips_status),
		.o_status_valid(mips_status_valid),
		.o_we          (          dmem_we),
		.o_addr        (        dmem_addr),
		.o_wdata       (       dmem_wdata),
		.i_rdata       (       dmem_rdata),
		.RDS_reg         (reg_signed_core),
		.RFS_reg         ( reg_float_core)
	);

	data_mem  u_data_mem (
		.i_clk  (       clk),
		.i_rst_n(     rst_n),
		.i_we   (   dmem_we),
		.i_addr ( dmem_addr),
		.i_wdata(dmem_wdata),
		.o_rdata(dmem_rdata)
	);

	always #(`HCYCLE) clk = ~clk;

	initial begin
		$fsdbDumpfile("core.fsdb");
		$fsdbDumpvars(0, testbed, "+mda");
  end

	always begin
		wait(rst_n == 1'b0);
		@(negedge clk);
		if((dmem_addr !== 0)||(dmem_we !== 0)||(dmem_wdata !== 0)||(mips_status !== 0)||(mips_status_valid !== 0)) begin
			$display("**************************************************************");
			$display("*   Output signal should be 0 after initial RESET at %4t     *",$time);
			$display("**************************************************************");
			$finish;
		end
	end


	// load data memory
	initial begin 
		clk         = 0;
		IM_addr     = 0;
		errorDM     = 0;
		errorStatus = 0;

		

		for(int pat_idx=0;pat_idx<`times;pat_idx++)begin

				if(`times != 1)sTmp.itoa(pat_idx);

				IM_addr = 0;
				errorDM = 0;
				resetTask();
				//for(int test=0;test<20;test++)$display("u_data_mem[%d] = %h", test*4, `DM_word(test));
				
				cnt = 0;
				while(1)begin//IM_addr < 1024 && mips_status !== 3'd4 && mips_status !== 3'd5
					@(negedge clk);
					if(mips_status_valid == 1)begin
						
						for(int reg_loc = 0 ; reg_loc < 32 ; reg_loc = reg_loc + 1)begin
							status = $fscanf(file, "%d", reg_signed_golden[reg_loc]);
						end
						for(int reg_loc = 0 ; reg_loc < 32 ; reg_loc = reg_loc + 1)begin
							status = $fscanf(file, "%d", reg_float_golden[reg_loc]);
						end
						
						$display("EXCUTED INSTRUCTION CNT: %d	,IM_addr: %d", cnt, IM_addr);
						cnt = cnt+1;
						
						for(int reg_loc = 0 ; reg_loc < 32 ; reg_loc = reg_loc + 1)begin
							if(reg_signed_core[reg_loc] !== reg_signed_golden[reg_loc])begin
								`ifdef ALL
									$display("	Pattern : %3s ", sTmp);
								`else
									$display("	Pattern : %3s ", pattern_num);
								`endif
								$write("%c[1;31m",27);
								$display("Reg[%0d]: Error! Golden = %d ,Yours = %d", reg_loc, reg_signed_golden[reg_loc], reg_signed_core[reg_loc]);
								$write("%c[0m",27);
								errorStatus = errorStatus + 1;
								$finish;
							end
							if(reg_float_core[reg_loc] !== reg_float_golden[reg_loc])begin
								`ifdef ALL
									$display("	Pattern : %3s ", sTmp);
								`else
									$display("	Pattern : %3s ", pattern_num);
								`endif
								$write("%c[1;31m",27);
								$display("Reg[%0d]: Error! Golden = %d ,Yours = %d", reg_loc, reg_float_golden[reg_loc], reg_float_core[reg_loc]);
								$write("%c[0m",27);
								errorStatus = errorStatus + 1;
								$finish;
							end
						end
						
						if(golden_Status[IM_addr] !== mips_status && golden_Status[IM_addr] !== 3'bxxx)begin
							$write("%c[1;34m",27);
							$display ("Status[%0d]: Error! Golden = %b ,Yours = %b", IM_addr, golden_Status[IM_addr], mips_status);
							$write("%c[0m",27);
							errorStatus = errorStatus + 1;
							//$finish;
						end
						if(IM_addr >= 1024 || mips_status === 3'd4 || mips_status === 3'd5 || golden_Status[IM_addr+1] === 3'bxxx)break;
						IM_addr = IM_addr + 1;
					end
				end

				#(`CYCLE);
				force clk = 0;

				// if(errorStatus === 0)begin
				// 	$write("%c[1;34m",27);
				// 	$display("	Status ALL PASS !!!!");
				// 	$write("%c[0m",27);
				// end

				// Check Data Memory
				for(int i=0;i<2048;i++) begin
					if(`DM_word(i) !== `DM_golden(i)) begin
						$write("%c[1;31m",27);
						$display("Data[%0d]: Error! Golden = %b ,Yours = %b", i*4, `DM_golden(i), `DM_word(i)); 
						$write("%c[0m",27);
						errorDM = errorDM + 1;
					end
				end
				`ifdef ALL
					resultTask_simple(errorStatus, errorDM);
				`else
					resultTask(errorStatus, errorDM);
				`endif
				#100;
				release clk;
		end
		$finish;

	end
	
	//================================================================
	// task
	//================================================================
	// << resetTask  >>
	task resetTask; 
	begin
		rst_n = 1;
		#(0.25 * `CYCLE) rst_n = 0;
		#(`CYCLE) rst_n = 1;
		//$readmemb(`Inst, u_data_mem.mem_r);
		`ifdef ALL
			$readmemb({"../00_TB/PATTERN/p", sTmp, "/inst.dat"}, u_data_mem.mem_r);
			$readmemb({"../00_TB/PATTERN/p", sTmp, "/data.dat"}, golden_IM_DM);
			$readmemb({"../00_TB/PATTERN/p", sTmp, "/status.dat"}, golden_Status);
			file = $fopen({"../00_TB/split/p", sTmp, "/reg_trace.dat"}, "r");
		`else
			$readmemb({"../00_TB/PATTERN/", pattern_num, "/inst.dat"}, u_data_mem.mem_r);
			$readmemb({"../00_TB/PATTERN/", pattern_num, "/data.dat"}, golden_IM_DM);
			$readmemb({"../00_TB/PATTERN/", pattern_num, "/status.dat"}, golden_Status);
			$display({"../00_TB/PATTERN/", pattern_num, "/reg_trace.dat"});
			file = $fopen({"../00_TB/split", pattern_num, "/reg_trace.dat"}, "r");
		`endif
	end
	endtask


	// << resultTask  >>
	task resultTask;
	input integer errorSt;
	input integer errorDM;
	begin
		if(errorSt === 0 && errorDM === 0) begin
				$write("%c[1;32m",27);
				$display("");
				`ifdef ALL
					$display("	Pattern : %3s ", sTmp);
				`else
					$display("	Pattern : %3s ", pattern_num);
				`endif
				$display("	*******************************               ");
				$display("	**                          **       |\__||  ");
				$display("	**    Congratulations !!    **      / O.O  | ");
				$display("	**                          **    /_____   | ");
				$display("	**    Simulation PASS!!     **   /^ ^ ^ \\  |");
				$display("	**                          **  |^ ^ ^ ^ |w| ");
				$display("	******************************   \\m___m__|_|");
				$display("");
				$write("%c[0m",27);
		end
		else begin
				$write("%c[1;31m",27);
				$display("");
				`ifdef ALL
					$display("	Pattern : %3s ", sTmp);
				`else
					$display("	Pattern : %3s ", pattern_num);
				`endif
				$display("	******************************               ");
				$display("	**                          **       |\__||  ");
				$display("	**    OOPS!!                **      / X,X  | ");
				$display("	**                          **    /_____   | ");
				$display("	**    Simulation Failed!!   **   /^ ^ ^ \\  |");
				$display("	**                          **  |^ ^ ^ ^ |w| ");
				$display("	******************************   \\m___m__|_|");
				$display("");
				$display("	Totally has %d errors (Status)               ", errorSt); 
				$display("	Totally has %d errors (Data Memory)        \n", errorDM); 
				$write("%c[0m",27);
		end
	end
	endtask


	// << resultTask  >>
	task resultTask_simple;
	input integer errorSt;
	input integer errorDM;
	begin
		if(errorSt === 0 && errorDM === 0) begin
				$write("%c[1;32m",27);
				`ifdef ALL
					$display("	Pattern : %3s Simulation PASS!!", sTmp);
				`else
					$display("	Pattern : %3s Simulation PASS!!", pattern_num);
				`endif
				$write("%c[0m",27);
		end
		else begin
				$write("%c[1;31m",27);
				`ifdef ALL
					$display("	Pattern : %3s Simulation Failed..........", sTmp);
				`else
					$display("	Pattern : %3s Simulation Failed..........", pattern_num);
				`endif
				$display("	Totally has %d errors (Status)               ", errorSt); 
				$display("	Totally has %d errors (Data Memory)        \n", errorDM); 
				$write("%c[0m",27);
		end
	end
	endtask


endmodule