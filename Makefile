#################################################################
# Author:       Abraham J. Ruiz R. (https://github.com/m4j0rt0m)
# Description:  Blinking LED Project Makefile
#################################################################

MKFILE_PATH         = $(abspath $(lastword $(MAKEFILE_LIST)))
TOP_DIR             = $(shell dirname $(MKFILE_PATH))

### DIRECTORIES ###
SOURCE_DIR          = $(TOP_DIR)/rtl
OUTPUT_DIR          = $(TOP_DIR)/build
TESTBENCH_DIR       = $(TOP_DIR)/tb
SCRIPT_DIR          = $(TOP_DIR)/scripts
FPGA_RTL_DIR        = $(TOP_DIR)/fpga/rtl
FPGA_BUILD_DIR      = $(TOP_DIR)/fpga/build

### RTL WILDCARDS ###
PRJ_SRC             = $(wildcard $(shell find $(SOURCE_DIR) -type f \( -iname \*.v -o -iname \*.sv -o -iname \*.vhdl \)))
PRJ_DIRS            = $(wildcard $(shell find $(SOURCE_DIR) -type d))
PRJ_HEADERS         = $(wildcard $(shell find $(SOURCE_DIR) -type f \( -iname \*.h -o -iname \*.vh -o -iname \*.svh \)))
TESTBENCH_SRC       = $(wildcard $(shell find $(TESTBENCH_DIR) -type f \( -iname \*.v \)))
PRJ_INCLUDES        = $(addprefix -I, $(PRJ_DIRS))

### FPGA RTL WILDCARDS ###
FPGA_TOP            = fpga_top
FPGA_RTL_SRC        = $(wildcard $(shell find $(FPGA_RTL_DIR) -type f \( -iname \*.v -o -iname \*.sv -o -iname \*.vhdl \)))
FPGA_RTL_DIRS       = $(wildcard $(shell find $(FPGA_RTL_DIR) -type d))
FPGA_RTL_HEADERS    = $(wildcard $(shell find $(FPGA_RTL_DIR) -type f \( -iname \*.h -o -iname \*.vh -o -iname \*.svh \)))
FPGA_RTL_INCLUDES   = $(addprefix -I, $(FPGA_RTL_DIRS))

### PROJECT ###
PROJECT             = blink_led
TOP_MODULE          = blink_led
RTL_SRC             = $(PRJ_SRC) $(FPGA_RTL_SRC)
RTL_INCLUDES        = $(PRJ_INCLUDES) $(FPGA_RTL_INCLUDES)

### LINTER ###
LINT                = verilator
LINT_FLAGS          = --lint-only --top-module $(TOP_MODULE) -Wall $(PRJ_INCLUDES)
LINT_FLAGS_FPGA     = --lint-only --top-module $(FPGA_TOP) -Wall $(RTL_INCLUDES)

### SIMULATION ###
TOP_MODULE_SIM      = blink_led
NAME_MODULE_SIM     = $(TOP_MODULE_SIM)_tb
SIM                 = iverilog
SIM_FLAGS           = -o $(OUTPUT_DIR)/$(TOP_MODULE).tb -s $(NAME_MODULE_SIM) -DSIMULATION $(PRJ_INCLUDES)
RUN                 = vvp
RUN_FLAGS           =

### FUNCTION DEFINES ###
define set_source_file_tcl
echo "set_global_assignment -name SOURCE_FILE $(1)" >> $(CREATE_PROJECT_TCL);
endef
define set_sdc_file_tcl
echo "set_global_assignment -name SDC_FILE $(1)" >> $(CREATE_PROJECT_TCL);
endef

### ALTERA FPGA COMPILATION ###
CLOCK_PORT          = clk_i
CLOCK_PERIOD        = 10
SOF_FILE            = $(FPGA_BUILD_DIR)/$(PROJECT).sof
CREATE_PROJECT_TCL  = $(SCRIPT_DIR)/create_project.tcl
PROJECT_SDC         = $(SCRIPT_DIR)/$(PROJECT).sdc
DEVICE_FAMILY       = "Cyclone IV E"
DEVICE_PART         = "EP4CE22F17C6"
MIN_CORE_TEMP       = 0
MAX_CORE_TEMP       = 85
PACKING_OPTION      = "normal"
PINOUT_TCL          = $(SCRIPT_DIR)/set_pinout.tcl
FPGA_CABLE          = usb-blaster
PROGRAM_MODE        = jtag
CONNECT_USB_BLASTER = $(SCRIPT_DIR)/connect_usb_blaster

### QUARTUS CLI ###
QUARTUS_SH          = quartus_sh
QUARTUS_PGM         = quartus_pgm

all: lint project sim

lint: $(PRJ_SRC)
	$(LINT) $(LINT_FLAGS) $^

lint-fpga: $(RTL_SRC)
	$(LINT) $(LINT_FLAGS_FPGA) $^

sim: $(OUTPUT_DIR)/$(TOP_MODULE_SIM).tb
	$(RUN) $(RUN_FLAGS) $<
	@(mv $(TOP_MODULE_SIM).vcd $(OUTPUT_DIR)/$(TOP_MODULE_SIM).vcd)

vcd: $(OUTPUT_DIR)/$(TOP_MODULE_SIM).vcd

gtkwave: $(OUTPUT_DIR)/$(TOP_MODULE_SIM).vcd $(TESTBENCH_SRC)
	@(gtkwave $< > /dev/null 2>&1 &)

run-sim: $(TESTBENCH_SRC) $(PRJ_SRC) $(PRJ_HEADERS)
	mkdir -p $(OUTPUT_DIR)
	$(SIM) $(SIM_FLAGS) $^
	$(RUN) $(RUN_FLAGS) $(OUTPUT_DIR)/$(TOP_MODULE_SIM).tb
	mv $(TOP_MODULE_SIM).vcd $(OUTPUT_DIR)/$(TOP_MODULE_SIM).vcd

project: create-project set-pinout compile-flow

compile-flow:
	cd $(FPGA_BUILD_DIR); \
	$(QUARTUS_SH) --flow compile $(PROJECT)

set-pinout:
	cd $(FPGA_BUILD_DIR); \
	$(QUARTUS_SH) -t $(PINOUT_TCL) $(PROJECT)

connect:
	$(CONNECT_USB_BLASTER)

scan:
	$(QUARTUS_PGM) --auto

sof: $(SOF_FILE) $(PRJ_SRC) $(PRJ_HEADERS) $(FPGA_RTL_SRC) $(FPGA_RTL_HEADERS)

flash-fpga: $(SOF_FILE) $(PRJ_SRC) $(PRJ_HEADERS) $(FPGA_RTL_SRC) $(FPGA_RTL_HEADERS)
	$(QUARTUS_PGM) -m $(PROGRAM_MODE) -c $(FPGA_CABLE) -o "p;$(SOF_FILE)@1"

$(SOF_FILE): $(PRJ_SRC) $(PRJ_HEADERS) $(FPGA_RTL_SRC) $(FPGA_RTL_HEADERS)
	$(MAKE) project

create-project: create-project-tcl
	rm -rf $(FPGA_BUILD_DIR)/$(PROJECT).qpf; \
	rm -rf $(FPGA_BUILD_DIR)/$(PROJECT).qsf; \
	mkdir -p $(FPGA_BUILD_DIR); \
	cd $(FPGA_BUILD_DIR); \
	$(QUARTUS_SH) -t $(CREATE_PROJECT_TCL)

create-project-tcl: create-sdc
	rm -rf $(CREATE_PROJECT_TCL)
	@(echo "# Automatically created by Makefile #" > $(CREATE_PROJECT_TCL))
	@(echo "set project_name $(PROJECT)" >> $(CREATE_PROJECT_TCL))
	@(echo "if [catch {project_open $(PROJECT)}] {project_new $(PROJECT)}" >> $(CREATE_PROJECT_TCL))
	@(echo "set_global_assignment -name MIN_CORE_JUNCTION_TEMP $(MIN_CORE_TEMP)" >> $(CREATE_PROJECT_TCL))
	@(echo "set_global_assignment -name MAX_CORE_JUNCTION_TEMP $(MAX_CORE_TEMP)" >> $(CREATE_PROJECT_TCL))
	@(echo "set_global_assignment -name FAMILY \"$(DEVICE_FAMILY)\"" >> $(CREATE_PROJECT_TCL))
	@(echo "set_global_assignment -name TOP_LEVEL_ENTITY $(FPGA_TOP)" >> $(CREATE_PROJECT_TCL))
	@(echo "set_global_assignment -name DEVICE \"$(DEVICE_PART)\"" >> $(CREATE_PROJECT_TCL))
	@(echo "set_global_assignment -name ERROR_CHECK_FREQUENCY_DIVISOR 256" >> $(CREATE_PROJECT_TCL))
	$(foreach SRC,$(PRJ_SRC),$(call set_source_file_tcl,$(SRC)))
	$(foreach SRC,$(PRJ_HEADERS),$(call set_source_file_tcl,$(SRC)))
	$(foreach SRC,$(FPGA_RTL_SRC),$(call set_source_file_tcl,$(SRC)))
	$(foreach SRC,$(FPGA_RTL_HEADERS),$(call set_source_file_tcl,$(SRC)))
	@(echo "set_global_assignment -name SDC_FILE $(PROJECT_SDC)" >> $(CREATE_PROJECT_TCL))
	@(echo "project_close" >> $(CREATE_PROJECT_TCL))
	@(echo "qexit -success" >> $(CREATE_PROJECT_TCL))

create-sdc:
	rm -rf $(PROJECT_SDC)
	@(echo "create_clock -name $(CLOCK_PORT) -period $(CLOCK_PERIOD) [get_ports {$(CLOCK_PORT)}]" > $(PROJECT_SDC))
	@(echo "derive_clock_uncertainty" >> $(PROJECT_SDC))

del-bak:
	find ./* -name "*~" -delete
	find ./* -name "*.bak" -delete

clean: del-bak
	rm -rf ./build/*.tb
	rm -rf ./build/*.vcd
	rm -rf ./fpga/build/*
	rm -rf ./scripts/create_project.tcl

$(OUTPUT_DIR)/$(TOP_MODULE_SIM).tb: $(TESTBENCH_SRC) $(PRJ_SRC) $(PRJ_HEADERS)
	@(mkdir -p $(OUTPUT_DIR))
	$(SIM) $(SIM_FLAGS) $^

$(OUTPUT_DIR)/$(TOP_MODULE_SIM).vcd: $(OUTPUT_DIR)/$(TOP_MODULE_SIM).tb $(PRJ_SRC) $(PRJ_HEADERS)
	$(RUN) $(RUN_FLAGS) $<
	@(mv $(TOP_MODULE_SIM).vcd $(OUTPUT_DIR)/$(TOP_MODULE_SIM).vcd)

.PHONY: all lint sim clean project compile-flow set-pinout connect scan flash-fpga create-project create-project-tcl del-bak create-sdc
