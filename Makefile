# Check for $WALLY environment variable
ifndef WALLY
$(error WALLY is not set. Source setup.sh in your local cvw, and then run make)
endif

SRC_DIR := src

.PHONY: all install clean sim gui lint

all: clean install

install: src/*.sv src/*.vh

$(SRC_DIR):
	@mkdir -p $(SRC_DIR)
	@mkdir -p $(SRC_DIR)/include

src/*.sv: $(WALLY)/src/debug/*.sv | $(SRC_DIR)
	@cp $(WALLY)/src/debug/*.sv $(SRC_DIR)/
	@cp $(WALLY)/src/generic/flop/synchronizer.sv $(SRC_DIR)/
	@cp $(WALLY)/src/generic/flop/flop.sv $(SRC_DIR)/

src/*.vh: $(WALLY)/src/debug/*.vh | $(SRC_DIR)
	@cp $(WALLY)/src/debug/*.vh $(SRC_DIR)/include

clean:
	@rm -rf $(SRC_DIR)
	@rm -rf ./debugfpga
	@rm -rf *.jou
	@rm -rf vivado_*.log
	@rm -rf vivado_*.str

sim:
	vsim -do setup.tcl -c

gui:
	vsim -do setup.tcl

lint: src/*.sv
	verilator --lint-only src/*.sv tb/*.sv -Isrc/include --top-module debug_tb
