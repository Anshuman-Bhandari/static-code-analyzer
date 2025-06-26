%{
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

FILE *output;
FILE *error_output;

int errors = 0;
int line_number = 1;
int indent_level = 0;
int previous_indent_level = 0;
int in_function = 0;
int in_class = 0;
int expecting_colon = 0;
int spaces_per_indent = -1;  // Will be set on first indent
char current_scope[50] = "global";
int is_empty_line = 1;
int in_multiline_string = 0;
char multiline_quote_type = '\0';

#define MAX_VARS 100
#define MAX_INDENT_STACK 100
#define MAX_BUILTINS 50
#define MAX_SCOPE_STACK 50

typedef struct {
    char name[50];
    char type[50];
    int is_initialized;
    int line_declared;
    char scope[50];
} Variable;

Variable vars[MAX_VARS];
int var_count = 0;
int indent_stack[MAX_INDENT_STACK];
int indent_stack_ptr = 0;

// Scope stack for nested blocks
char scope_stack[MAX_SCOPE_STACK][50];
int scope_stack_ptr = 0;

// Initialize Python built-in functions and keywords
char builtins[MAX_BUILTINS][50] = {
    // Built-in functions
    "print", "input", "len", "str", "int", "float", "list", "dict", "set", "tuple",
    "range", "sum", "min", "max", "abs", "all", "any", "enumerate", "zip", "map",
    // Built-in types
    "object", "bool", "bytes", "bytearray", "complex", "frozenset",
    // Built-in exceptions
    "Exception", "TypeError", "ValueError", "IndexError", "KeyError",
    // Special names
    "__init__", "__main__", "__name__", "__file__", "__dict__"
};
int builtin_count = 35;

int last_token_was_def = 0;
int last_token_was_block = 0;
int block_name_seen = 0;
char last_block_type[50] = "";

void push_scope(const char *scope) {
    if (scope_stack_ptr < MAX_SCOPE_STACK) {
        strcpy(scope_stack[scope_stack_ptr++], scope);
        strcpy(current_scope, scope);
    }
}

void pop_scope() {
    if (scope_stack_ptr > 0) {
        scope_stack_ptr--;
        if (scope_stack_ptr > 0) {
            strcpy(current_scope, scope_stack[scope_stack_ptr - 1]);
        } else {
            strcpy(current_scope, "global");
        }
    }
}

void init_builtins() {
    for(int i = 0; i < builtin_count; i++) {
        strcpy(vars[var_count].name, builtins[i]);
        strcpy(vars[var_count].type, "builtin");
        vars[var_count].is_initialized = 1;
        strcpy(vars[var_count].scope, "builtin");
        var_count++;
    }
}

void add_var(const char *var, const char *scope) {
    // Check if it's a built-in
    for (int i = 0; i < builtin_count; i++) {
        if (strcmp(builtins[i], var) == 0) {
            return;  // Don't add built-ins to variable list
        }
    }

    // Variables can be redefined in Python, so we don't check for redefinition
    if (var_count < MAX_VARS) {
        strcpy(vars[var_count].name, var);
        strcpy(vars[var_count].type, "dynamic");  // Python uses dynamic typing
        vars[var_count].is_initialized = 1;  // In Python, declaration is initialization
        vars[var_count].line_declared = line_number;
        strcpy(vars[var_count].scope, scope);
        var_count++;
    }
}

Variable* get_var(const char *var) {
    // Check if it's a built-in
    for (int i = 0; i < builtin_count; i++) {
        if (strcmp(builtins[i], var) == 0) {
            return NULL;  // Built-ins are always valid
        }
    }

    // Check variables in current and global scope
    for (int i = 0; i < var_count; i++) {
        if (strcmp(vars[i].name, var) == 0 && 
            (strcmp(vars[i].scope, current_scope) == 0 || strcmp(vars[i].scope, "global") == 0)) {
            return &vars[i];
        }
    }
    return NULL;  // In Python, we don't warn about undefined variables until runtime
}

void handle_indentation(int spaces) {
    if (is_empty_line) return;  // Skip indentation check for empty lines
    
    previous_indent_level = indent_level;
    
    // Set spaces_per_indent on first indent
    if (spaces_per_indent == -1 && spaces > 0) {
        spaces_per_indent = spaces;
    }
    
    // Validate indentation
    if (spaces > 0 && spaces_per_indent > 0) {
        if (spaces % spaces_per_indent != 0) {
            fprintf(error_output, "Line %d: Inconsistent indentation. Expected multiple of %d spaces\n",
                    line_number, spaces_per_indent);
            errors++;
            return;
        }
    }
    
    indent_level = spaces / (spaces_per_indent > 0 ? spaces_per_indent : 1);

    if (indent_level > previous_indent_level) {
        if (!expecting_colon) {
            fprintf(error_output, "Line %d: Unexpected indentation\n", line_number);
            errors++;
        }
        if (indent_level > previous_indent_level + 1) {
            fprintf(error_output, "Line %d: Too many indentation levels at once\n", line_number);
            errors++;
        }
        if (indent_stack_ptr < MAX_INDENT_STACK) {
            indent_stack[indent_stack_ptr++] = indent_level;
        }
        fprintf(output, "Indent Level Increased to %d (Line %d)\n", indent_level, line_number);
    } else if (indent_level < previous_indent_level) {
        while (indent_stack_ptr > 0 && indent_stack[indent_stack_ptr - 1] > indent_level) {
            indent_stack_ptr--;
            pop_scope();
        }
        if (indent_level < indent_stack[indent_stack_ptr - 1]) {
            fprintf(error_output, "Line %d: Unindent does not match any outer indentation level\n", line_number);
            errors++;
        }
        fprintf(output, "Indent Level Decreased to %d (Line %d)\n", indent_level, line_number);
    }
    
    expecting_colon = 0;
}

void check_block_syntax() {
    if ((last_token_was_def || last_token_was_block) && !expecting_colon) {
        fprintf(error_output, "Line %d: Missing colon ':' after '%s' statement\n", 
            line_number, last_block_type);
        errors++;
    }
}

%}

%option noyywrap

KEYWORD def|class|if|elif|else|while|for|in|try|except|finally|with|return|pass|break|continue|import|from|as|global|nonlocal|lambda|raise|assert
IDENTIFIER [a-zA-Z_][a-zA-Z0-9_]*
NUMBER [0-9]+(\.[0-9]+)?([eE][+-]?[0-9]+)?|0[xX][0-9a-fA-F]+|0[oO][0-7]+|0[bB][01]+
STRING \"\"\"([^\\]|\\.)*?\"\"\"|\'\'\'([^\\]|\\.)*?\'\'\'|\"([^\"\\]|\\.)*\"|\'([^\'\\]|\\.)*\'
INDENT ^[ ]*
OPERATOR [+\-*/%@]|==|!=|<=|>=|<|>|and|or|not|is|in|\+=|\-=|\*=|\/=|\/\/=|%=|@=|\*\*=|&=|\|=|\^=|>>=|<<=|\*\*|\/\/
COMMENT #.*$

%%

{INDENT}       { 
                if (yytext[0] != '\n') {
                    handle_indentation(strlen(yytext));
                }
            }

\n          { 
                check_block_syntax();  // Check for missing colon before newline
                fprintf(output, "End of Line %d\n", line_number++);
                is_empty_line = 1;
                last_token_was_def = 0;
                last_token_was_block = 0;
                block_name_seen = 0;
                BEGIN(INITIAL);
            }

":"         {
                if (!expecting_colon) {
                    fprintf(error_output, "Line %d: Unexpected colon\n", line_number);
                    errors++;
                }
                fprintf(output, "Block Start Colon (Line %d)\n", line_number);
                expecting_colon = 0;
                last_token_was_def = 0;
                last_token_was_block = 0;
                block_name_seen = 0;
            }

"def"       {
                fprintf(output, "Function Definition (Line %d)\n", line_number);
                in_function = 1;
                expecting_colon = 1;
                last_token_was_def = 1;
                strcpy(last_block_type, "def");
                is_empty_line = 0;
            }

"class"     {
                fprintf(output, "Class Definition (Line %d)\n", line_number);
                in_class = 1;
                expecting_colon = 1;
                last_token_was_block = 1;
                strcpy(last_block_type, "class");
                is_empty_line = 0;
            }

"if"|"elif"|"else"|"while"|"for"|"try"|"except"|"finally"|"with" {
                fprintf(output, "Block Keyword: %s (Line %d)\n", yytext, line_number);
                expecting_colon = 1;
                last_token_was_block = 1;
                strcpy(last_block_type, yytext);
                is_empty_line = 0;
            }

{KEYWORD}   {
                fprintf(output, "Keyword: %s (Line %d)\n", yytext, line_number);
                is_empty_line = 0;
            }

{STRING}    {
                fprintf(output, "String Literal: %s (Line %d)\n", yytext, line_number);
                is_empty_line = 0;
                
                // Handle multi-line strings
                if (strncmp(yytext, "\"\"\"", 3) == 0 || strncmp(yytext, "'''", 3) == 0) {
                    in_multiline_string = !in_multiline_string;
                    multiline_quote_type = yytext[0];
                }
            }

{NUMBER}    {
                fprintf(output, "Number: %s (Line %d)\n", yytext, line_number);
                is_empty_line = 0;
            }

{IDENTIFIER}\(  {
                char func_name[50];
                strncpy(func_name, yytext, strlen(yytext)-1);
                func_name[strlen(yytext)-1] = '\0';
                
                if (in_function && !block_name_seen) {
                    push_scope(func_name);
                    in_function = 0;
                    block_name_seen = 1;
                }
                
                fprintf(output, "Function Call/Definition: %s (Line %d)\n", func_name, line_number);
                add_var(func_name, current_scope);
                is_empty_line = 0;
            }

{IDENTIFIER} {
                fprintf(output, "Identifier: %s (Line %d)\n", yytext, line_number);
                if (last_token_was_def || last_token_was_block) {
                    block_name_seen = 1;
                }
                add_var(yytext, current_scope);
                is_empty_line = 0;
            }

{OPERATOR}  {
                fprintf(output, "Operator: %s (Line %d)\n", yytext, line_number);
                is_empty_line = 0;
            }

{COMMENT}   {
                fprintf(output, "Comment: %s (Line %d)\n", yytext, line_number);
            }

[\(\)\[\]\{\},] {
                fprintf(output, "Delimiter: %s (Line %d)\n", yytext, line_number);
                is_empty_line = 0;
            }

[ \t]       ; /* Skip other whitespace */

.          {
                fprintf(output, "Unknown Token: %s (Line %d)\n", yytext, line_number);
                is_empty_line = 0;
            }

%%

int main(int argc, char *argv[]) {
    if (argc < 2) {
        printf("Usage: ./lex_python <input_file>\n");
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

    // Initialize built-in functions and types
    init_builtins();

    yyin = input;
    yylex();

    fprintf(output, "\n--- End of Token List ---\n");
    fprintf(error_output, "\n--- End of Compile-Time Error ---\n");

    fclose(input);
    fclose(output);
    fclose(error_output);

    return 0;
}
