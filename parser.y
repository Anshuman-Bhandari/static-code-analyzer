%{
#include <stdio.h>
#include <stdlib.h>

extern int yylex();
void yyerror(const char *s);
extern FILE *output;
extern FILE *error_output;
extern int line_number;
extern int errors;
%}

%union {
    char* str;
    int num;
}

%token <str> IDENTIFIER
%token <str> STRING
%token <num> NUMBER
%token DEF CLASS IF ELIF ELSE WHILE FOR TRY EXCEPT FINALLY WITH RETURN PASS BREAK CONTINUE IMPORT FROM AS GLOBAL NONLOCAL LAMBDA RAISE ASSERT IN
%token COLON NEWLINE INDENT DEDENT
%token EQ PLUS MINUS STAR SLASH
%token LPAREN RPAREN COMMA

%start program

%%

program:
    stmt_list
    ;

stmt_list:
    stmt
    | stmt_list stmt
    ;

stmt:
    simple_stmt
    | compound_stmt
    ;

simple_stmt:
    assignment_stmt
    | expr_stmt
    ;

assignment_stmt:
    IDENTIFIER '=' expr NEWLINE {
        fprintf(output, "Assignment: %s = ... (Line %d)\n", $1, line_number);
    }
    ;

expr_stmt:
    expr NEWLINE {
        fprintf(output, "Expression statement (Line %d)\n", line_number);
    }
    ;

compound_stmt:
    func_def
    | class_def
    | if_stmt
    ;

func_def:
    DEF IDENTIFIER LPAREN RPAREN COLON NEWLINE INDENT stmt_list DEDENT {
        fprintf(output, "Function Definition Parsed: %s (Line %d)\n", $2, line_number);
    }
    ;

class_def:
    CLASS IDENTIFIER COLON NEWLINE INDENT stmt_list DEDENT {
        fprintf(output, "Class Definition Parsed: %s (Line %d)\n", $2, line_number);
    }
    ;

if_stmt:
    IF expr COLON NEWLINE INDENT stmt_list DEDENT {
        fprintf(output, "If Statement Parsed (Line %d)\n", line_number);
    }
    ;

expr:
    IDENTIFIER
    | NUMBER
    | STRING
    | expr PLUS expr
    | expr MINUS expr
    | expr STAR expr
    | expr SLASH expr
    ;

%%

void yyerror(const char *s) {
    fprintf(error_output, "Parse error at line %d: %s\n", line_number, s);
    errors++;
}