%{
#include <stdio.h>
#include <string.h>

FILE *output;
FILE *error_output;

int semicolon_expected = 0;
int errors = 0;
int last_was_type = 0;
int line_number = 1;

#define MAX_VARS 100
char declared_vars[MAX_VARS][50];
int var_count = 0;

void add_var(char *var) {
    for (int i = 0; i < var_count; i++) {
        if (strcmp(declared_vars[i], var) == 0) return;
    }
    if (var_count < MAX_VARS) {
        strcpy(declared_vars[var_count++], var);
    }
}

int is_declared(char *var) {
    for (int i = 0; i < var_count; i++) {
        if (strcmp(declared_vars[i], var) == 0) return 1;
    }
    return 0;
}
%}

%option noyywrap

KEYWORD int|return|void|if|else|while|for|float|double|char|long|short|unsigned
IDENTIFIER [a-zA-Z_][a-zA-Z0-9_]*
NUMBER [0-9]+
WS [ \t]+
NEWLINE \n
SEMICOLON ;
LPAREN \(
RPAREN \)
LBRACE \{
RBRACE \}

%%

{WS}           { /* skip whitespace */ }

"#include"[ \t]*<[^>]+> {
                    fprintf(output, "Header File: %s (Line %d)\n", yytext, line_number);
                }

{NEWLINE}      {
                    if (semicolon_expected) {
                        fprintf(error_output, "Line %d: Missing semicolon\n", line_number);
                        semicolon_expected = 0;
                        errors++;
                    }
                    fprintf(output, "Line Number: %d\n", line_number++);
                }

{KEYWORD}{WS}+{IDENTIFIER}{WS}*{LPAREN}{RPAREN} {
                    fprintf(output, "Function Declaration: %s (Line %d)\n", yytext, line_number);
                    last_was_type = 0;
                    semicolon_expected = 0;
                }

{KEYWORD}      {
                    fprintf(output, "Keyword: %s (Line %d)\n", yytext, line_number);
                    last_was_type = (strcmp(yytext, "int") == 0 || strcmp(yytext, "void") == 0 ||
                                     strcmp(yytext, "char") == 0 || strcmp(yytext, "float") == 0 ||
                                     strcmp(yytext, "double") == 0 || strcmp(yytext, "long") == 0 ||
                                     strcmp(yytext, "short") == 0 || strcmp(yytext, "unsigned") == 0);
                }

{IDENTIFIER}   {
                    if (last_was_type) {
                        fprintf(output, "Variable Declaration: %s (Line %d)\n", yytext, line_number);
                        add_var(yytext);
                        semicolon_expected = 1;
                        last_was_type = 0;
                    } else {
                        fprintf(output, "Identifier: %s (Line %d)\n", yytext, line_number);
                        if (!is_declared(yytext)) {
                            fprintf(error_output, "Line %d: Undeclared variable '%s'\n", line_number, yytext);
                            errors++;
                        }
                        semicolon_expected = 1;
                    }
                }

{NUMBER}       { fprintf(output, "Number: %s (Line %d)\n", yytext, line_number); semicolon_expected = 1; }

"="            { fprintf(output, "Assignment Operator: = (Line %d)\n", line_number); semicolon_expected = 1; }

{SEMICOLON}    { fprintf(output, "Semicolon Detected (Line %d)\n", line_number); semicolon_expected = 0; }

{LPAREN}       { fprintf(output, "Left Parenthesis (Line %d)\n", line_number); }
{RPAREN}       { fprintf(output, "Right Parenthesis (Line %d)\n", line_number); }
{LBRACE}       { fprintf(output, "Left Brace (Line %d)\n", line_number); }
{RBRACE}       { fprintf(output, "Right Brace (Line %d)\n", line_number); }

.              { fprintf(output, "Unknown Token: %s (Line %d)\n", yytext, line_number); }

%%

int main(int argc, char *argv[]) {
    if (argc < 2) {
        printf("Usage: ./lex_c <input_file>\n");
        return 1;
    }

    FILE *input = fopen(argv[1], "r");
    if (!input) {
        perror("Error opening input file");
        return 1;
    }

    output = fopen("output/result.txt", "w");
    error_output = fopen("output/errors.txt", "w");

    if (!output || !error_output) {
        perror("Error opening output files");
        fclose(input);
        return 1;
    }

    yyin = input;
    yylex();

    fprintf(output, "\n--- End of Token List ---\n");
    fprintf(error_output, "\n--- End of Compile-Time Error Report ---\n");

    fclose(input);
    fclose(output);
    fclose(error_output);

    return 0;
}