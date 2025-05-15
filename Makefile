# Makefile for C/C++/Python code checker project

# Compiler
CC = gcc
FLEX = flex

# Output binaries
MAIN_EXE = main.exe
LEX_C_EXE = lex_c.exe
LEX_CPP_EXE = lex_cpp.exe
LEX_PY_EXE = lex_python.exe

# Lex source files
LEX_C = lex_c.l
LEX_CPP = lex_cpp.l
LEX_PY = lex_python.l

.PHONY: all clean run

all: $(MAIN_EXE) $(LEX_C_EXE) $(LEX_CPP_EXE) $(LEX_PY_EXE)

$(MAIN_EXE): main.c
	$(CC) main.c -o $(MAIN_EXE)

$(LEX_C_EXE): $(LEX_C)
	$(FLEX) $(LEX_C)
	$(CC) lex.yy.c -o $(LEX_C_EXE)

$(LEX_CPP_EXE): $(LEX_CPP)
	$(FLEX) $(LEX_CPP)
	$(CC) lex.yy.c -o $(LEX_CPP_EXE)

$(LEX_PY_EXE): $(LEX_PY)
	$(FLEX) $(LEX_PY)
	$(CC) lex.yy.c -o $(LEX_PY_EXE)

run: all
	./$(MAIN_EXE)

clean:
	del $(MAIN_EXE) $(LEX_C_EXE) $(LEX_CPP_EXE) $(LEX_PY_EXE) lex.yy.c output\result.txt temp.txt 2>nul
