# Simple build / run for Icarus Verilog
IVERILOG = iverilog
VVP      = vvp
SRC      = src/matmul.v src/softmax.v src/attn_top.v tb/attn_tb.v
OUT      = tb/attn_sim

.PHONY: all sim check clean

all: sim

sim:
	cd tb && $(IVERILOG) -g2012 -o attn_sim ../src/matmul.v ../src/softmax.v ../src/attn_top.v attn_tb.v
	cd tb && $(VVP) attn_sim

check:
	python3 scripts/check_attn.py

clean:
	rm -f tb/attn_sim tb/attn_tb.vcd data/output.txt
