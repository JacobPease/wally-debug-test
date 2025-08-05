# Check for $WALLY environment variable
ifndef WALLY
$(error WALLY is not set. Source setup.tcl in your local cvw, and then run make)
endif

SRC_DIR := src

.PHONY: all install clean

install: src/*.sv

$(SRC_DIR):
	@mkdir -p $(SRC_DIR)

src/*.sv: $(WALLY)/src/debug/*.sv | $(SRC_DIR)
	@cp $(WALLY)/src/debug/*.sv $(SRC_DIR)/
	@cp $(WALLY)/src/debug/*.vh $(SRC_DIR)/

clean:
	@rm -rf $(SRC_DIR)
