# Blinking LED test
This is a simple test for the DE0 Nano FPGA, the project constructs and test the FPGA with a module that blinks an LED. The speed of the blinking can be controlled by the SWs in the DE0 Nano Board. For simplicity, the project has a Makefile in order to handle the Quartus project creation, mapping, fitting, synthesis, and FPGA programming tasks.

The project is structured as follows:

- rtl: Verilog source code
- tb: Testbench code
- fpga: FPGA test verilog source code
- build: Output files (*gtkwave, vcd, sof, etc.*)
- scripts: Tcl scripts used for Quartus synthesis and fitting tasks.

## Build
##### Create, synthesize and assign pins to the project (*default*).
```
make all
```

## Simulation
The simulation drives the stimulus of the top module, it is in charge of generating the speed_up and speed_dwn events, then it calculates the output frequency depending on the period of every output pulse. The parameters that can be changed for the simulation are:

```
/* dut parameters */
CLK_FREQ    : FPGA's clock frequency
FREQ_STEPS  : Amount of frequency up <-> down steps
MAX_FREQ    : Maximum output frequency
MIN_FREQ    : Minimum output frequency
SCALE_DIV   : Output frequency divider

/* sim parameters */
SIM_PULSES  : Number of output full cycles before a frequency step change
SIM_CYCLES  : Amount of minimum <-> maximum frequency steps full sweeps for the whole simulation
INT_CYCLES  : Maximum amount of cycles for the simulation (timeout)
```

In order to simulate the RTL and generate the VCD file, run:
```
make sim
```

## FPGA
The rtl code for the FPGA test is located inside the "fpga" directory, this handles the switch debouncing logic, as well as some parameters regarding the FPGA synthesis. The parameters and rtl code can be used to modify the synthesis for other FPGAs (default: DE0-Nano with an Altera Cyclone IV FPGA).

Create project:
```
make project
```

Scan for a connected Altera FPGA:
```
make scan
```

To retry connection of the FPGA (this will retry the jtagd and jtagconfig scripts, must have Quartus in the PATH):
```
make connect
```

Program FPGA (once you have the SOF file):
```
make flash-fpga
```

##### Control
Once running the FPGA test, you can play with the speed up/down buttons assigned in the FPGA:
```
[KEY0] -> Speed up
[KEY1] -> Speed down
```
