%{
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

FILE *output;
FILE *error_output;

int semicolon_expected = 0;
int errors = 0;
int line_number = 1;
int in_declaration = 0;
char current_type[50] = "";
char current_var[50] = "";
int expecting_value = 0;

#define MAX_VARS 100
typedef struct {
    char name[50];
    char type[50];
    int is_initialized;
    int line_declared;
} Variable;

Variable vars[MAX_VARS];
int var_count = 0;

void init_standard_functions() {
    strcpy(vars[var_count].name, "printf");
    strcpy(vars[var_count].type, "function");
    var_count++;
}

void add_var(const char *var, const char *type) {
    for (int i = 0; i < var_count; i++) {
        if (strcmp(vars[i].name, var) == 0) {
            return;
        }
    }
    if (var_count < MAX_VARS) {
        strcpy(vars[var_count].name, var);
        strcpy(vars[var_count].type, type);
        vars[var_count].is_initialized = 0;
        vars[var_count].line_declared = line_number;
        var_count++;
    }
}

Variable* get_var(const char *var) {
    for (int i = 0; i < var_count; i++) {
        if (strcmp(vars[i].name, var) == 0) {
            return &vars[i];
        }
    }
    return NULL;
}

void check_type_mismatch(const char *value) {
    if (current_var[0] != '\0') {
        Variable *v = get_var(current_var);
        if (v != NULL) {
            if (strcmp(v->type, "int") == 0) {
                if (value[0] == '"') {
                    fprintf(error_output, "Line %d: Type mismatch - Cannot assign string to int variable '%s'\n", 
                        line_number, current_var);
                    errors++;
                }
            }
            v->is_initialized = 1;
        }
    }
}

%}

%option noyywrap

KEYWORD int|return|void|if|else|while|for|float|double|char
IDENTIFIER [a-zA-Z_][a-zA-Z0-9_]*
NUMBER [0-9]+
WS [ \t]+
NEWLINE \n
SEMICOLON ;
LPAREN \(
RPAREN \)
LBRACE \{
RBRACE \}
STRING \"[^\"]*\"
EQUALS =

%%

{WS}           { /* skip whitespace */ }

"#include"[ \t]*<[^>]+> {
                    fprintf(output, "Header File: %s (Line %d)\n", yytext, line_number);
                    if (strstr(yytext, "stdio.h")) {
                        init_standard_functions();
                    }
                }

{NEWLINE}      {
                    if (semicolon_expected) {
                        fprintf(error_output, "Line %d: Missing semicolon\n", line_number);
                        semicolon_expected = 0;
                        errors++;
                    }
                    fprintf(output, "Line Number: %d\n", line_number++);
                    in_declaration = 0;
                }

{STRING}       { 
                    fprintf(output, "String Literal: %s (Line %d)\n", yytext, line_number);
                    if (expecting_value) {
                        check_type_mismatch(yytext);
                        expecting_value = 0;
                    }
                }

{KEYWORD}      {
                    fprintf(output, "Keyword: %s (Line %d)\n", yytext, line_number);
                    strcpy(current_type, yytext);
                    in_declaration = 1;
                }

{EQUALS}       {
                    fprintf(output, "Assignment Operator: = (Line %d)\n", line_number);
                    expecting_value = 1;
                }

{IDENTIFIER}   {
                    fprintf(output, "Identifier: %s (Line %d)\n", yytext, line_number);
                    if (in_declaration) {
                        add_var(yytext, current_type);
                        strcpy(current_var, yytext);
                    } else {
                        Variable *v = get_var(yytext);
                        if (!v) {
                            fprintf(error_output, "Line %d: Undeclared identifier '%s'\n", line_number, yytext);
                            errors++;
                        }
                        strcpy(current_var, yytext);
                    }
                }

{NUMBER}       { 
                    fprintf(output, "Number: %s (Line %d)\n", yytext, line_number);
                    if (expecting_value) {
                        expecting_value = 0;
                    }
                }

{SEMICOLON}    { 
                    fprintf(output, "Semicolon Detected (Line %d)\n", line_number);
                    semicolon_expected = 0;
                    in_declaration = 0;
                    expecting_value = 0;
                    strcpy(current_var, "");
                }

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
