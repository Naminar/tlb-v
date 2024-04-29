
NAME=set
cmp:
	iverilog -o $(NAME) $(NAME)_tb.v $(NAME).v
	./$(NAME)

all: cmp
	wine surfer/surfer.exe $(NAME)_tb.vcd