# Wally Debug Test
This repository contains a series of testbenches made for testing the RISCV Debug extension implementation in Wally. This repository will likely rapidly change.

First clone my fork of wally, checkout the debug branch, and source `setup.sh`:

```bash
git clone --recurse-submodules https://www.github.com/jacobpease/cvw.git
cd cvw
git fetch debug
git checkout debug
source setup.sh
```
Next, run `make` to copy all debug modules from my debug branch to this repository. Then run:

```bash
vsim -do setup.tcl
```
This is my custom automatic recompiling setup for QuestaSim. It will dynamically recompile design libraries based on when they were last modified. I will probably put them in their own repo at some point.
