
TLB=tlb
PMU=pmu
WAY=way
FOLDER=build

cmp:
	if test -d $(FOLDER); then echo ; else mkdir $(FOLDER); fi
	iverilog -o $(FOLDER)/$(TLB) $(TLB)_tb.v stlb.v $(TLB).v  $(WAY).v $(PMU).v mmu.v
	./$(FOLDER)/$(TLB)

validate:
	 verilator --lint-only tlb.v stlb.v mmu.v pmu.v

d:
	iverilog stlb.v way.v -E -o debug.v

s: 
	iverilog -o stlb tlb_tb.v stlb.v tlb.v way.v pmu.v

all: validate cmp
	wine surfer/surfer.exe $(TLB)_tb.vcd