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
int in_class = 0;
char current_type[50] = "";
char current_var[50] = "";
char current_class[50] = "";
int expecting_value = 0;
int access_specifier = 0;  // 0: private, 1: public, 2: protected
int in_namespace_std = 0;  // Track if 'using namespace std' is active
int in_template = 0;      // Track if we're in a template declaration
int in_function = 0;
int expecting_colon = 0;
char current_scope[50] = "global";
int has_iostream = 0;
int has_string = 0;

#define MAX_VARS 1000
#define MAX_STD_SYMBOLS 100
#define MAX_STD_HEADERS 20

typedef struct {
    char name[50];
    char type[50];
    int is_initialized;
    int line_declared;
    char class_name[50];  // For class members
    int is_const;
    int access_level;     // 0: private, 1: public, 2: protected
    int is_template;      // Whether this is a template type
    char scope[50];        // Added for scope tracking
} Variable;

Variable vars[MAX_VARS];
int var_count = 0;

// Standard library headers
char std_headers[MAX_STD_HEADERS][50] = {
    "iostream", "string", "vector", "map", "set",
    "algorithm", "memory", "utility", "cmath", "cstdlib",
    "ctime", "fstream", "sstream", "iomanip", "array",
    "deque", "queue", "stack", "list", "bitset"
};

// Standard library symbols
char std_symbols[MAX_STD_SYMBOLS][50] = {
    // IO streams
    "cout", "cin", "cerr", "clog", "endl", "flush", "ws",
    // String operations
    "string", "getline", "to_string", "stoi", "stol", "stof", "stod",
    // Containers
    "vector", "map", "set", "list", "queue", "stack", "deque", 
    "pair", "array", "forward_list", "multiset", "multimap",
    "unordered_map", "unordered_set", "priority_queue", "bitset",
    // Algorithms
    "sort", "find", "reverse", "count", "max", "min", "swap",
    // Memory
    "shared_ptr", "unique_ptr", "weak_ptr", "make_shared", "make_unique",
    // Types
    "size_t", "string_view", "nullptr_t", "initializer_list",
    // Stream types
    "ostream", "istream", "fstream", "stringstream", "ofstream", "ifstream",
    // Additional common symbols
    "begin", "end", "rbegin", "rend", "push_back", "pop_back", "emplace_back",
    "insert", "erase", "clear", "size", "empty", "front", "back"
};

void add_std_symbols() {
    if (in_namespace_std) {
        for(int i = 0; i < MAX_STD_SYMBOLS; i++) {
            if(strlen(std_symbols[i]) > 0) {
                strcpy(vars[var_count].name, std_symbols[i]);
                strcpy(vars[var_count].type, "std");
                vars[var_count].is_initialized = 1;
                strcpy(vars[var_count].scope, "global");
                var_count++;
            }
        }
    }
}

void add_var(const char *var, const char *type) {
    // Don't add if it's already in std namespace
    if(in_namespace_std) {
        for(int i = 0; i < MAX_STD_SYMBOLS; i++) {
            if(strcmp(std_symbols[i], var) == 0) {
                return;
            }
        }
    }

    // Check for redefinition
    for (int i = 0; i < var_count; i++) {
        if (strcmp(vars[i].name, var) == 0) {
            return;  // Allow redefinition in C++
        }
    }

    if (var_count < MAX_VARS) {
        strcpy(vars[var_count].name, var);
        strcpy(vars[var_count].type, type);
        vars[var_count].is_initialized = 1;
        vars[var_count].line_declared = line_number;
        strcpy(vars[var_count].class_name, current_class);
        vars[var_count].access_level = access_specifier;
        var_count++;
    }
}

Variable* get_var(const char *var) {
    // Check if using iostream without include
    if (!has_iostream && (strcmp(var, "cout") == 0 || strcmp(var, "endl") == 0 || strcmp(var, "cin") == 0)) {
        fprintf(error_output, "Line %d: Using iostream symbols without #include <iostream>\n", line_number);
        errors++;
        return NULL;
    }

    // Check if using string without include
    if (!has_string && strcmp(var, "string") == 0) {
        fprintf(error_output, "Line %d: Using string without #include <string>\n", line_number);
        errors++;
        return NULL;
    }

    // Check if it's a standard symbol and we're using namespace std
    if(in_namespace_std) {
        for(int i = 0; i < MAX_STD_SYMBOLS; i++) {
            if(strcmp(std_symbols[i], var) == 0) {
                return NULL;  // Allow use of std symbols
            }
        }
    }

    // Check if it's a std:: qualified name
    char std_prefix[] = "std::";
    if (strncmp(var, std_prefix, strlen(std_prefix)) == 0) {
        const char *symbol = var + strlen(std_prefix);
        for(int i = 0; i < MAX_STD_SYMBOLS; i++) {
            if(strcmp(std_symbols[i], symbol) == 0) {
                return NULL;  // Allow use of std:: qualified symbols
            }
        }
    }

    // Check variables in current scope
    for (int i = 0; i < var_count; i++) {
        if (strcmp(vars[i].name, var) == 0) {
            return &vars[i];
        }
    }

    // If we get here and the symbol is in std but we're not using namespace std
    for(int i = 0; i < MAX_STD_SYMBOLS; i++) {
        if(strcmp(std_symbols[i], var) == 0) {
            fprintf(error_output, "Line %d: '%s' is not declared. Did you forget 'using namespace std' or 'std::'?\n", 
                line_number, var);
            errors++;
            return NULL;
        }
    }

    fprintf(error_output, "Line %d: Undeclared identifier '%s'\n", line_number, var);
    errors++;
    return NULL;
}

void check_type_mismatch(const char *value) {
    if (current_var[0] != '\0') {
        Variable *v = get_var(current_var);
        if (v != NULL) {
            if (strcmp(v->type, "int") == 0 || strcmp(v->type, "float") == 0 || 
                strcmp(v->type, "double") == 0) {
                if (value[0] == '"') {
                    fprintf(error_output, "Line %d: Type mismatch - Cannot assign string to %s variable '%s'\n", 
                        line_number, v->type, current_var);
                    errors++;
                }
            }
            if (v->is_const && v->is_initialized) {
                fprintf(error_output, "Line %d: Assignment to const variable '%s'\n", 
                    line_number, current_var);
                errors++;
            }
            v->is_initialized = 1;
        }
    }
}

void check_access_violation(const char *var) {
    Variable *v = get_var(var);
    if (v != NULL && strlen(v->class_name) > 0) {
        if (v->access_level == 0) {  // private
            fprintf(error_output, "Line %d: Accessing private member '%s'\n", line_number, var);
            errors++;
        }
    }
}

%}

%option noyywrap

KEYWORD class|struct|public|private|protected|const|int|float|double|char|bool|void|string|return|if|else|while|for|try|catch|throw|new|delete|template|typename|namespace|using|auto|static|virtual|override|final|explicit|friend|operator|sizeof|typedef|volatile|mutable|constexpr|noexcept|nullptr|static_cast|dynamic_cast|const_cast|reinterpret_cast
IDENTIFIER [a-zA-Z_][a-zA-Z0-9_]*
NUMBER [0-9]+(\.[0-9]+)?([eE][+-]?[0-9]+)?|0[xX][0-9a-fA-F]+
WS [ \t]+
NEWLINE \n
SEMICOLON ;
LPAREN \(
RPAREN \)
LBRACE \{
RBRACE \}
STRING \"([^\"\\]|\\.)*\"|\'([^\'\\]|\\.)*\'
EQUALS =
OPERATOR [+\-*/%@]|==|!=|<=|>=|<|>|&&|\|\||!|&|\||\^|~|\+=|\-=|\*=|\/=|%=|<<=|>>=|&=|\|=|\^=|\+\+|\-\-|->|\[\]|\(\)|,|;|\.|\?|:
COMPARISON ==|!=|<=|>=|<|>
SCOPE ::
REFERENCE [&]
TEMPLATE_START "template"[ \t]*"<"
TEMPLATE_END ">"
NAMESPACE_START "namespace"[ \t]+[a-zA-Z_][a-zA-Z0-9_]*
INCLUDE ^[ \t]*#[ \t]*include[ \t]*<[^>]+>
COMMENT \/\/.*$|\/\*([^*]|\*[^\/])*\*\/

%%

{WS}           { /* skip whitespace */ }

{INCLUDE}      {
                fprintf(output, "Include directive: %s (Line %d)\n", yytext, line_number);
                if (strstr(yytext, "<iostream>")) {
                    has_iostream = 1;
                }
                if (strstr(yytext, "<string>")) {
                    has_string = 1;
                }
            }

"using"[ \t]+"namespace"[ \t]+"std" {
                    fprintf(output, "Using namespace std (Line %d)\n", line_number);
                    in_namespace_std = 1;
                    add_std_symbols();
                }

"std::"       {
                    fprintf(output, "Std Namespace Access (Line %d)\n", line_number);
                }

"namespace"   {
                    fprintf(output, "Namespace Keyword (Line %d)\n", line_number);
                }

{TEMPLATE_START} {
                    fprintf(output, "Template Declaration Start (Line %d)\n", line_number);
                }

{TEMPLATE_END} {
                    fprintf(output, "Template Declaration End (Line %d)\n", line_number);
                }

{NAMESPACE_START} {
                    fprintf(output, "Namespace Declaration (Line %d)\n", line_number);
                }

"new"         {
                    fprintf(output, "Dynamic Memory Allocation (Line %d)\n", line_number);
                }

"delete"      {
                    fprintf(output, "Dynamic Memory Deallocation (Line %d)\n", line_number);
                }

{REFERENCE}   {
                    fprintf(output, "Reference Type (Line %d)\n", line_number);
                    strcat(current_type, "&");
                }

"class"        {
                    fprintf(output, "Class Declaration (Line %d)\n", line_number);
                    in_class = 1;
                    access_specifier = 0;  // default is private
                }

"public:"      {
                    fprintf(output, "Public Access Specifier (Line %d)\n", line_number);
                    access_specifier = 1;
                }

"private:"     {
                    fprintf(output, "Private Access Specifier (Line %d)\n", line_number);
                    access_specifier = 0;
                }

"protected:"   {
                    fprintf(output, "Protected Access Specifier (Line %d)\n", line_number);
                    access_specifier = 2;
                }

"const"        {
                    fprintf(output, "Const Qualifier (Line %d)\n", line_number);
                    strcat(current_type, "const ");
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
                    if (strcmp(yytext, "class") != 0 && strcmp(yytext, "public") != 0 && 
                        strcmp(yytext, "private") != 0 && strcmp(yytext, "protected") != 0 &&
                        strcmp(yytext, "const") != 0) {
                        strcpy(current_type, yytext);
                        in_declaration = 1;
                    }
                }

{EQUALS}       {
                    fprintf(output, "Assignment Operator: = (Line %d)\n", line_number);
                    expecting_value = 1;
                }

{SCOPE}        {
                    fprintf(output, "Scope Resolution Operator (Line %d)\n", line_number);
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
                        } else {
                            check_access_violation(yytext);
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
{RBRACE}       { 
                    fprintf(output, "Right Brace (Line %d)\n", line_number);
                    if (in_class) {
                        in_class = 0;
                        strcpy(current_class, "");
                    }
                }

{OPERATOR}     {
                    fprintf(output, "Operator: %s (Line %d)\n", yytext, line_number);
                }

{COMMENT}      {
                    fprintf(output, "Comment: %s (Line %d)\n", yytext, line_number);
                }

.              { fprintf(output, "Unknown Token: %s (Line %d)\n", yytext, line_number); }

%%

int main(int argc, char *argv[]) {
    if (argc < 2) {
        printf("Usage: %s <input_file>\n", argv[0]);
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
