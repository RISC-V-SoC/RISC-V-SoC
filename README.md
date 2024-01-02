# Introduction
This project is intended to be a synthesizable system-on-a-chip with a 32-bit RISC-V processor in the center of it all. The project itself does not contain mechanisms to synthesize it for any FPGA, it only contains the testbenches.
Therefore, it should be possible to synthesize this project for any sufficently-able FPGA. In practice, this project is only tested for the Arty s7-50 platform, which contains the AMD (Xilinx) XC7S50-1CSGA324C FPGA.

# Prerequisites
In order to run the testbenches, some software is required:
1) VUnit (https://vunit.github.io/). VUnit manages the tests and provides some testing framework.
2) GHDL (https://github.com/ghdl/ghdl). GHDL is the motor behind the testing itself: it compiles the tests to executables, which in turn are managed by VUnit.
3) GTKWave (https://gtkwave.sourceforge.net/). GTKWave is used to display the waveforms, useful in debugging.

# Running the tests
The tests can be run simply by executing
```
python run.py
```
in the root of this repository. VUnit supports multithreading with `-p`, this can significantly improve the test runtime. For more details, see the VUnit documentation.

# A short explanation of the contents
* bus: The central interconnect between the components in the SoC. It is a master-slave setup, based on the TU Delfts' ρ-VEX bus with some inspiration taken from the AXI4 bus. `bus/bus_pkg.vhd` contains all the details about how this bus works.
* common: Some VHDL entities which are used across the other components.
* complete_system: Contains testing of the `main_file.vhd`.
* gtkwave: Contains a TCL script used to make waveform reading more bearable.
* riscv32_processor: Contains the actual RISC-V processor, which is also a bus master. It also contains a bus slave, which can be used to operate on/read the CPU states.
* triple_23lc1024_controller: Contains a driver for a PCB which contains three `23lc1024` SRAM chips. It is a bus slave and a normal memory from the perspective of the bus.
* uart_bus_master: A bus master which allows access to all slaves on the bus trough a self-rolled protocol on top of UART. Used in practice to program and start the CPU.
* uart_bus_slave: A simple UART device which can be operated from the bus.
