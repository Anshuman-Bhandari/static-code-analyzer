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
int in_template = 0;
int in_function = 0;
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
    char class_name[50];
    int is_const;
    int access_level;
    int is_template;
    char scope[50];
} Variable;

Variable vars[MAX_VARS];
int var_count = 0;

char std_headers[MAX_STD_HEADERS][50] = {
    "iostream", "string", "vector", "map", "set",
    "algorithm", "memory", "utility", "cmath", "cstdlib",
    "ctime", "fstream", "sstream", "iomanip", "array",
    "deque", "queue", "stack", "list", "bitset"
};

char std_symbols[MAX_STD_SYMBOLS][50] = {
    "cout", "cin", "cerr", "clog", "endl", "flush", "ws",
    "string", "getline", "to_string", "stoi", "stol", "stof", "stod",
    "vector", "map", "set", "list", "queue", "stack", "deque", 
    "pair", "array", "forward_list", "multiset", "multimap",
    "unordered_map", "unordered_set", "priority_queue", "bitset",
    "sort", "find", "reverse", "count", "max", "min", "swap",
    "shared_ptr", "unique_ptr", "weak_ptr", "make_shared", "make_unique",
    "size_t", "string_view", "nullptr_t", "initializer_list",
    "ostream", "istream", "fstream", "stringstream", "ofstream", "ifstream",
    "begin", "end", "rbegin", "rend", "push_back", "pop_back", "emplace_back",
    "insert", "erase", "clear", "size", "empty", "front", "back"
};

void add_std_symbols() {
    static int std_symbols_added = 0;
    if (in_namespace_std && !std_symbols_added) {
        for(int i = 0; i < MAX_STD_SYMBOLS; i++) {
            if(strlen(std_symbols[i]) > 0) {
                int exists = 0;
                for(int j = 0; j < var_count; j++) {
                    if(strcmp(vars[j].name, std_symbols[i]) == 0 && 
                       strcmp(vars[j].scope, "global") == 0) {
                        exists = 1;
                        break;
                    }
                }
                if(!exists) {
                    strcpy(vars[var_count].name, std_symbols[i]);
                    strcpy(vars[var_count].type, "std");
                    vars[var_count].is_initialized = 1;
                    vars[var_count].line_declared = line_number;
                    strcpy(vars[var_count].scope, "global");
                    var_count++;
                }
            }
        }
        std_symbols_added = 1;
    }
}

void add_var(const char *var, const char *type) {
    if(in_namespace_std) {
        for(int i = 0; i < MAX_STD_SYMBOLS; i++) {
            if(strcmp(std_symbols[i], var) == 0) {
                return;
            }
        }
    }

    for (int i = 0; i < var_count; i++) {
        if (strcmp(vars[i].name, var) == 0 && strcmp(vars[i].scope, current_scope) == 0) {
            fprintf(error_output, "Line %d: Redefinition of '%s'\n", line_number, var);
            errors++;
            return;
        }
    }

    if (var_count < MAX_VARS) {
        strcpy(vars[var_count].name, var);
        strcpy(vars[var_count].type, type);
        vars[var_count].is_initialized = 0;
        vars[var_count].line_declared = line_number;
        strcpy(vars[var_count].class_name, current_class);
        vars[var_count].access_level = access_specifier;
        strcpy(vars[var_count].scope, current_scope);
        var_count++;
    }
}

Variable* get_var(const char *var) {
    if(in_namespace_std) {
        for(int i = 0; i < MAX_STD_SYMBOLS; i++) {
            if(strcmp(std_symbols[i], var) == 0) {
                if ((strcmp(var, "cout") == 0 || strcmp(var, "cin") == 0 || 
                    strcmp(var, "endl") == 0) && !has_iostream) {
                    fprintf(error_output, "Line %d: Using iostream symbols without #include <iostream>\n", line_number);
                    errors++;
                    return NULL;
                }
                if (strcmp(var, "string") == 0 && !has_string) {
                    fprintf(error_output, "Line %d: Using string without #include <string>\n", line_number);
                    errors++;
                    return NULL;
                }
                return NULL;
            }
        }
    }

    char std_prefix[] = "std::";
    if (strncmp(var, std_prefix, strlen(std_prefix)) == 0) {
        const char *symbol = var + strlen(std_prefix);
        for(int i = 0; i < MAX_STD_SYMBOLS; i++) {
            if(strcmp(std_symbols[i], symbol) == 0) {
                return NULL;
            }
        }
    }

    for (int i = 0; i < var_count; i++) {
        if (strcmp(vars[i].name, var) == 0 && strcmp(vars[i].scope, current_scope) == 0) {
            return &vars[i];
        }
    }

    if (strcmp(current_scope, "global") != 0) {
        for (int i = 0; i < var_count; i++) {
            if (strcmp(vars[i].name, var) == 0 && strcmp(vars[i].scope, "global") == 0) {
                return &vars[i];
            }
        }
    }

    for(int i = 0; i < MAX_STD_SYMBOLS; i++) {
        if(strcmp(std_symbols[i], var) == 0) {
            fprintf(error_output, "Line %d: '%s' is not declared. Did you forget 'using namespace std' or 'std::'?\n", 
                line_number, var);
            errors++;
            return NULL;
        }
    }
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
        if (v->access_level == 0 && strcmp(current_scope, v->class_name) != 0) {
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
                    semicolon_expected = 1;
                }

"std::"       {
                    fprintf(output, "Std Namespace Access (Line %d)\n", line_number);
                }

"namespace"   {
                    fprintf(output, "Namespace Keyword (Line %d)\n", line_number);
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



"class"        {
                    fprintf(output, "Class Declaration (Line %d)\n", line_number);
                    in_class = 1;
                    access_specifier = 0;
                }

"struct"       {
                    fprintf(output, "Struct Declaration (Line %d)\n", line_number);
                    in_class = 1;
                    access_specifier = 1;
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

{NEWLINE} {
    fprintf(output, "Line Number: %d\n", line_number++);
    if (!in_function) {
        in_declaration = 0;
    }
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
                    if (strcmp(yytext, "class") != 0 && strcmp(yytext, "struct") != 0 &&
                        strcmp(yytext, "public") != 0 && strcmp(yytext, "private") != 0 && 
                        strcmp(yytext, "protected") != 0 && strcmp(yytext, "const") != 0) {
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

{IDENTIFIER} {
                fprintf(output, "Identifier: %s (Line %d)\n", yytext, line_number);
                if (in_declaration) {
                    add_var(yytext, current_type);
                    strcpy(current_var, yytext);
                    semicolon_expected = 1; // Expect semicolon after declaration
                } else {
                    Variable *v = get_var(yytext);
                    if (!v) {
                        int is_type = 0;
                        for (int i = 0; i < var_count; i++) {
                            if (strcmp(vars[i].type, yytext) == 0) {
                                is_type = 1;
                                break;
                            }
                        }
                        if (!is_type) {
                            fprintf(error_output, "Line %d: Undeclared identifier '%s'\n", line_number, yytext);
                            errors++;
                        }
                    } else {
                        check_access_violation(yytext);
                    }
                    strcpy(current_var, yytext);
                    semicolon_expected = 1; // Also expect semicolon in expressions
                }
            }


{NUMBER}       { 
                    fprintf(output, "Number: %s (Line %d)\n", yytext, line_number);
                    if (expecting_value) {
                        expecting_value = 0;
                    }
                }

{SEMICOLON} {
                fprintf(output, "Semicolon Detected (Line %d)\n", line_number);
                semicolon_expected = 0;
                in_declaration = 0;
                expecting_value = 0;
                strcpy(current_var, "");
                strcpy(current_type, "");
                if (in_namespace_std) {
                    add_std_symbols();
                }
            }


{LPAREN} {
    fprintf(output, "Left Parenthesis (Line %d)\n", line_number);
    if (in_declaration) {
        in_function = 1;
        strcpy(current_scope, current_var);
        semicolon_expected = 0;  
    }
}

{RPAREN}       { 
                    fprintf(output, "Right Parenthesis (Line %d)\n", line_number);
                    if (in_function) {
                        in_function = 0;
                        strcpy(current_scope, "global");
                    }
                }
{LBRACE}       { 
                    fprintf(output, "Left Brace (Line %d)\n", line_number);
                    if (in_class) {
                        strcpy(current_scope, current_class);
                    }
                }
{RBRACE}       { 
                    fprintf(output, "Right Brace (Line %d)\n", line_number);
                    if (in_class) {
                        in_class = 0;
                        strcpy(current_class, "");
                        strcpy(current_scope, "global");
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
    fprintf(error_output, "Total errors: %d\n", errors);

    fclose(input);
    fclose(output);
    fclose(error_output);

    return 0;
}