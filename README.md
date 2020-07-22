# Pulse Generator Project
This is a parameterized "*Pulse Generator*" project, it contains three functionality modes (Linear / Exponential / PWM), step up and step down frequency control as well as a manual setup (or selection) of the scaled frequency.

In order to test the functionality of the pulse generator module, an FPGA test is included with a sweep transition effect.

The project is structured as follows:

- rtl: Verilog source code
- tb: Testbench code
- fpga: FPGA test verilog source code
- fpga/build: FPGA test build files (*.qpf, .sof, etc.*)
- build: Output files (*.gtkw, .vcd, etc.*)
- scripts: Tcl scripts used for Quartus synthesis and fitting tasks.

## Linting
##### Lint the rtl code:
```
make lint
```
##### Including the FPGA test rtl code:
```
make lint-fpga
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

## Simulation
The simulation drives the stimulus of the top module, it is in charge of generating the simulation events, then it calculates the output frequency depending on the period of every output pulse. The parameters that can be changed for the simulation are:

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

##### Control
Once running the FPGA test, you can play with the speed up/down buttons assigned in the FPGA:
```
[KEY0] -> Speed up
[KEY1] -> Speed down
```
