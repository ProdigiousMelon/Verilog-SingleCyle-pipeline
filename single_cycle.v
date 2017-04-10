// basic sizes of things
`define WORD	[15:0]
`define Opcode	[15:12]
`define Dest	[11:6]
`define Src	[5:0]
`define Sign [15]
`define Exponent [14:7]
`define Mantissa [6:0]
`define STATE	[4:0]
`define REGSIZE [63:0]
`define MEMSIZE [65535:0]

// opcode values, also state numbers
`define OPadd	4'b0000
`define OPinvf	4'b0001
`define OPaddf	4'b0010
`define OPmulf	4'b0011
`define OPand	4'b0100
`define OPor	4'b0101
`define OPxor	4'b0110
`define OPany	4'b0111
`define OPdup	4'b1000
`define OPshr	4'b1001
`define OPf2i	4'b1010
`define OPi2f	4'b1011
`define OPld	4'b1100
`define OPst	4'b1101
`define OPjzsz	4'b1110
`define OPli	4'b1111

// state numbers only
`define OPjz	`OPjzsz
`define OPsys	5'b10000
`define OPsz	5'b10001
`define Start	5'b11111
`define Start1	5'b11110

// source field values for sys and sz
`define SRCsys	6'b000000
`define SRCsz	6'b000001



module processor(halt, reset, clk);
  output reg halt;
  input reset, clk;

  reg `WORD regfile `REGSIZE;
  reg `WORD mainmem `MEMSIZE;
  reg `WORD instmem `MEMSIZE;
  reg `WORD s1buffermem [4:0];
  reg `WORD s2buffermem [1:0];
  reg `WORD s3buffermem [8:0];
  
  reg `WORD pc;
  reg `WORD ir;
  reg gotImm;
  wire gotImmOut;
  reg `STATE s;
  integer a;
 // wire s1Ready, s2Ready, s3Ready;

  always @(reset) begin
    halt = 0;
    pc = 0;
    s = 0;
	//s1Ready=0;
	//s2Ready=0;
	//s3Ready=0;
    $readmemh("reginit.txt",regfile);
    $readmemh("testinst.txt",instmem);
  end
  
  //buffer for the first register
  IF_RR ifrr(clk, ir, gotImmOut);

  //stage 1
  always @(posedge clk) begin
    ir <= instmem[pc];
  end
  always @(negedge clk) begin
	gotImm <= gotImmOut;
	s1buffermem[0] <= ir `Opcode; //Opcode field
	s1buffermem[1] <= ir `Src; //Src field
	s1buffermem[2] <= ir `Dest; //Dest field
	
	//flag for the li value
	if(gotImm)
		//the
		s1buffermem[4] = ir;
	else
		s1buffermem[3] = 0;
  end

  
  //stage 2
  always @(posedge clk) begin
   pc <= pc + 1;             // bump pc
    case (s1buffermem[0])
      `OPjzsz:
        case (s1buffermem[1])	   // use Src as extended opcode
          `SRCsys: s <= `OPsys; // sys call
          `SRCsz: s <= `OPsz;   // sz
          default: s <= `OPjz;  // jz
        endcase
      default: s <= ir `Opcode; // most instructions, state # is opcode
    endcase
   end

   //stage 3
	always @(negedge clk)begin
    case (s)
      `OPadd: begin s2buffermem[ir `Dest] <= regfile[ir `Dest] + regfile[ir `Src]; end
      `OPand: begin s2buffermem[ir `Dest] <= regfile[ir `Dest] & regfile[ir `Src]; end
      `OPany: begin s2buffermem[ir `Dest] <= |regfile[ir `Src]; end
      `OPdup: begin s2buffermem[ir `Dest] <= regfile[ir `Src]; end
      `OPjz: begin if (regfile[ir `Dest] == 0) pc <= regfile[ir `Src]; end
      `OPld: begin s2buffermem[ir `Dest] <= mainmem[regfile[ir `Src]]; end 
	  `OPli: begin s2buffermem[ir `Dest] <= mainmem[pc]; pc <= pc + 1; end
	  `OPor: begin s2buffermem[ir `Dest] <= regfile[ir `Dest] | regfile[ir `Src]; end
      `OPsz: begin if (regfile[ir `Dest] == 0) pc <= pc + 1; end
      `OPshr: begin s2buffermem[ir `Dest] <= regfile[ir `Src] >> 1; end
      `OPst: begin s2buffermem[regfile[ir `Src]] <= regfile[ir `Dest]; end
      `OPxor: begin s2buffermem[ir `Dest] <= regfile[ir `Dest] ^ regfile[ir `Src]; end
    endcase
   end
   
   //stage 4
   always@(posedge clk)begin
	case(s2buffermem[ir `Dest])
	  `OPadd: begin regfile[ir `Dest] <= s2buffermem[ir `Dest]; end
      `OPand:begin regfile[ir `Dest] <= s2buffermem[ir `Dest]; end
      `OPany:begin regfile[ir `Dest] <= s2buffermem[ir `Dest]; end
      `OPdup:begin regfile[ir `Dest] <= s2buffermem[ir `Dest]; end
      `OPld: begin regfile[ir `Dest] <= s2buffermem[ir `Dest]; end
	  `OPli: begin regfile[ir `Dest] <= s2buffermem[ir `Dest]; end
	  `OPor: begin regfile[ir `Dest] <= s2buffermem[ir `Dest]; end
      `OPshr:begin regfile[ir `Dest] <= s2buffermem[ir `Dest]; end
      `OPst: begin mainmem[ir `Dest] <= s2buffermem[regfile[ir `Src]]; end
      `OPxor:begin regfile[ir `Dest] <= s2buffermem[ir `Dest]; end
	endcase
   end       
endmodule

//Instruction Fetch ~> Register Read(IF_RR)
module IF_RR(clk, instIn, got_imm_o);
	
	//define input signals
	input clk;
	input `WORD instIn;
	reg `WORD instOutReg;
    output got_imm_o;
	reg imm_temp;
	
	//checks to see if you got an immediate value
	always @(posedge clk) begin
		if(instIn `Opcode == `OPli)
			begin
				#1;
				imm_temp = 1;
			end
		else
			begin
				imm_temp = 0;
			end
	end 
	assign got_imm_o = imm_temp;
endmodule

module floatHandle(aVal, bVal, out);
	input `WORD aVal, bVal;
	output `WORD out;
	reg `WORD tempOut;
	
	always @(posedge clk) begin;
		case(aVal `Opcode)
			`OPi2f:
				begin
					tempOut = 
				end
	end
	
	
endmodule

module testbench;
  reg reset = 0;
  reg clk = 0;
  wire halted;
  processor PE(halted, reset, clk);
  initial begin
    $dumpfile("output.txt");
    $dumpvars(0, PE);
    #10 reset = 1;
    #10 reset = 0;
    while (!halted) begin
      #10 clk = 1;
      #10 clk = 0;
    end
    $finish;
  end
endmodule