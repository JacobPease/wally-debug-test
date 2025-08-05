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
Next, run `make` to copy all debug modules from
