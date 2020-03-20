# Blinking LED test
This is a simple test for the DE0 Nano FPGA, the project constructs and test the FPGA with a module that blinks an LED. The speed of the blinking can be controlled by the SWs in the DE0 Nano Board. For simplicity, the project has a Makefile in order to handle the Quartus project creation, mapping, fitting, synthesis, and FPGA programming tasks.

The project is structured as follows:

- rtl: Verilog source code
- tb: Testbench code
- build: Output files (*gtkwave, vcd, sof, etc.*)
- script: Tcl scripts used for Quartus synthesis and fitting tasks.

## Build
##### Create, synthesize and assign pins to the project (*default*).
```
make all
```

## FPGA
##### Program
```
make fpga
```
##### Control
```
[SW0] -> Speed up
[SW1] -> Speed down
```
