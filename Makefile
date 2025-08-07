# Check for $WALLY environment variable
ifndef WALLY
$(error WALLY is not set. Source setup.tcl in your local cvw, and then run make)
endif

SRC_DIR := src

.PHONY: all install clean sim gui

all: clean install

install: src/*.sv src/*.vh

$(SRC_DIR):
	@mkdir -p $(SRC_DIR)
	@mkdir -p $(SRC_DIR)/include

src/*.sv: $(WALLY)/src/debug/*.sv | $(SRC_DIR)
	@cp $(WALLY)/src/debug/*.sv $(SRC_DIR)/
	@cp $(WALLY)/src/generic/flop/synchronizer.sv $(SRC_DIR)/

src/*.vh: $(WALLY)/src/debug/*.vh | $(SRC_DIR)
	@cp $(WALLY)/src/debug/*.vh $(SRC_DIR)/include

clean:
	@rm -rf $(SRC_DIR)

sim:
	vsim -do setup.tcl -c

gui:
	vsim -do setup.tcl
