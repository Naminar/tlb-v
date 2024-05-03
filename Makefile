
TLB=tlb
PMU=pmu
WAY=way
FOLDER=build
cmp:
	if test -d $(FOLDER); then echo ; else mkdir $(FOLDER); fi
	iverilog -o $(FOLDER)/$(TLB) $(TLB)_tb.v $(TLB).v  $(WAY).v $(PMU).v
	./$(FOLDER)/$(TLB)

all: cmp
	wine surfer/surfer.exe $(TLB)_tb.vcd