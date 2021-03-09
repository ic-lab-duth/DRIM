# Overview
A 6-stage core, implementing the RiscV ISA (RV32IMC).
Features:
- Dual Fetch & Dual Issue for Compressed instructions
- Dynamic Branch Prediction
- Partial Register Renaming Scheme
- OoO Execution
- Non-blocking data cache

| ![overview](/images/riscv_rr.png) |
|:--:|
| *Overview of the pipeline* |


### Directory Hierarchy

The folder hierarchy is organised as follows:
- `images` : schematics
- `rtl` : contains all the synthesisable RTL files
- `sva` : contains related x-checks and assertions for the design
- `sim` : contains the provided testbench and example codes


## Repo State

### Current State & Limitations
- Support for “RV32I” Base Integer Instruction Set
- Support for “M” Standard Extension for Integer Multiplication and Division
- Support for “C” Standard Extension for Compressed Instructions
- Verification status: Unit verification & Top level verification has taken place
- Partially implemented: Decode for additional instructions that are not yet supported (System, floating point, CSR) and exception detection
- The svas present have only been using in simulation and not in any formal verification process

### Future Optimisations
- Replace MUL/DIV units with optimised hardware, to reduce execution latency and decompress a lot of the paths

### Future Work
- Floating Point & Fixed point arithmetic
- CSR, SYSTEM instructions and Priviledged ISA
- Exception detection and Interrupt handling
- Virtual Memory
- 64bit support
- Align to future versions of the RISC-V ISA. Current document version supported is *20191213* of the Unpriviledged ISA manual



## How to Compile

The `/sim` directory is used for the simulation flow and it contains detailed instructions for both the flow and compiling C code. That way you can generate your own executable file and convert it to a memory file suitable for the CPU. Examples (code and precompiled files) are included in the `/sim/examples` directory.

_**To compile:**_
- include a compiled `memory.txt` file inside the `/sim` directory
- run the `compile.do` in questa with: "`do compile.do`"


The testbench hierarchy can be seen below:

_**TB Level Hierarchy:**_
->`tb` -> `module_top` -> `Processor_Top`


|  Hierarchy Name  | Details                                                                                             |
|:----------------:|-----------------------------------------------------------------------------------------------------|
| tb   | top level of the TB, instantiating the datapath |
| module_top    | The top level of the cpu datapath, connecting the memories and the surrounding logic with the core |
| Processor_Top       | The top level of the core datapath |


## Reference

The architecture and performance is presented in Microprocessors and Microsystems, Elsevier, Sept.2018.  You can find the
[paper](https://gdimitrak.github.io/papers/micropro18.pdf) here.
To cite this work please use
```
@article{PATSIDIS20181,
author = {K. {Patsidis} and D. {Konstantinou} and C. {Nicopoulos} and G. {Dimitrakopoulos}},
title = {A low-cost synthesizable RISC-V dual-issue processor core leveraging the compressed Instruction Set Extension},
journal = {Microprocessors and Microsystems},
volume = {61},
pages = {1-10},
year = {2018},
issn = {0141-9331},
doi = {https://doi.org/10.1016/j.micpro.2018.05.007},
url = {https://www.sciencedirect.com/science/article/pii/S0141933118300048} }
```


## License
This project is licensed under the [MIT License](./LICENSE).
