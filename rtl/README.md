# Overview
This directory contains all the synthesisable RTL files.

All the parameters regarding the design can be found inside the `module_top.sv` file. Note that only a subset of them are tunable, as mentioned in the comments inside the file.

Any structs used can be found inside the `structs.sv` file.

## Additional notes

Included to generate an FPGA demo:
- Frame buffer peripheral (address 0xffff0000)
- VGA control logic

Design has been tested on the following tools:
- Questa & Modelsim
- Quartus (RTL needs slight modifications on `main_memory.sv` to load a memory.mif)

### ISA instructions

The list of the currently supported operations (ISA Version 20191213):

|  RV32I Base Instruction Set  | Multiplication and Division  | Compressed |
|:-------------------:|:-------------------:|:-------------------:|
| LUI   | MUL		| C.ADDI4SPN |
| AUIPC | MULH		| C.LW |
| JAL   | MULHSU	| C.SW |
| JALR	| MULHU 	| C.ADDI |
| BEQ	| DIV 		| C.JAL |
| BNE	| DIVU		| C.LI |
| BLT	| REM		| C.ADDI16SP |
| BGE	| REMU		| C.LUI |
| BLTU	|			| C.SRLI |
| BGETU |			| C.SRAI |
| LB 	|			| C.ANDI |
| LH	|			| C.SUB |
| LW	|			| C.XOR |
| LBU	|			| C.OR |
| LHU	|			| C.AND |
| SB	|			| C.J |
| SH	|			| C.BEQZ |
| SW	|			| C.BNEZ |
| ADDI	|			| C.SLLI |
| SLTI	|			| C.LWSP |
| SLTU	|			| C.JR |
| XORI	|			| C.MV |
| ORI	|			| C.JALR |
| ANDI	|			| C.ADD |
| SLLI	|			| C.SWSP |
| SRLI |
| SRAI |
| ADD |
| SUB |
| SLL |
| SLT |
| SLTU |
| XOR |
| SRL |
| SRA |
| OR |
| AND |





