# Static Code Analyzer

A static code analyzer that can analyze C, C++, and Python code for potential errors and code quality issues.

## Features

- Support for multiple programming languages:
  - C
  - C++
  - Python
- Modern GUI interface
- Real-time error detection
- Syntax highlighting
- Type checking
- Variable declaration and usage analysis

## Prerequisites

1. GCC (GNU Compiler Collection)
2. Flex (Fast Lexical Analyzer)
3. Python 3.x
4. Required Python packages:
   ```
   pip install -r requirements.txt
   ```

## Installation

1. Install Flex:
   - Download from: http://gnuwin32.sourceforge.net/packages/flex.htm
   - Or install using winget: `winget install GnuWin32.Flex`
   - Default installation path: `C:\Program Files (x86)\GnuWin32\bin`

2. Install Python dependencies:
   ```powershell
   pip install -r requirements.txt
   ```

## Compilation Instructions

### If Flex is installed and in PATH:

```powershell
# Compile C Analyzer
flex lex_c.l
gcc lex.yy.c -o lex_c.exe

# Compile C++ Analyzer
flex lex_cpp.l
gcc lex.yy.c -o lex_cpp.exe

# Compile Python Analyzer
flex lex_python.l
gcc lex.yy.c -o lex_python.exe
```

### If Flex is installed but not in PATH:

```powershell
# Compile C Analyzer
& 'C:\Program Files (x86)\GnuWin32\bin\flex.exe' 'lex_c.l'
gcc lex.yy.c -o lex_c.exe

# Compile C++ Analyzer
& 'C:\Program Files (x86)\GnuWin32\bin\flex.exe' 'lex_cpp.l'
gcc lex.yy.c -o lex_cpp.exe

# Compile Python Analyzer
& 'C:\Program Files (x86)\GnuWin32\bin\flex.exe' 'lex_python.l'
gcc lex.yy.c -o lex_python.exe
```

## Running the Application

1. **Using the GUI (Recommended)**:
   ```powershell
   python analyzer_ui.py
   ```

2. **Using Individual Analyzers**:
   ```powershell
   # For C files
   ./lex_c.exe <input_file.c>

   # For C++ files
   ./lex_cpp.exe <input_file.cpp>

   # For Python files
   ./lex_python.exe <input_file.py>
   ```

## Output Files

The analyzers generate two output files in the `output` directory:
- `result.txt`: Contains the token analysis
- `errors.txt`: Contains any errors found during analysis

## Example Usage

1. **C++ Example**:
   ```cpp
   #include <iostream>
   using namespace std;

   int main() {
       string name = "Alice";
       cout << "Hello, " << name << endl;
       return 0;
   }
   ```

2. **Python Example**:
   ```python
   def greet(name):
       print("Hello,", name)

   greet("World")
   ```

## Features Supported

### C++ Analyzer
- Standard library support (iostream, string, etc.)
- Namespace handling
- Class and object-oriented features
- Template syntax
- Access specifiers (public, private, protected)
- Stream operators
- Reference types

### Python Analyzer
- Built-in functions and types
- Indentation-based scope handling
- Dynamic typing
- Function definitions
- Class definitions
- Import statements
- String literals (both single and double quotes)

### C Analyzer
- Standard library functions
- Type checking
- Variable declarations
- Function definitions
- Preprocessor directives

## Troubleshooting

1. **Flex not found error**:
   - Make sure Flex is installed
   - Use the full path to flex.exe as shown in the compilation instructions

2. **Output directory issues**:
   - Ensure the `output` directory exists
   - Make sure you have write permissions

3. **Compilation errors**:
   - Make sure GCC is installed and in your PATH
   - Check that all source files are in the correct location

## Project Structure

```
.
├── analyzer_ui.py      # GUI interface
├── lex_c.l            # C lexical analyzer
├── lex_cpp.l          # C++ lexical analyzer
├── lex_python.l       # Python lexical analyzer
├── detect_lang.py     # Language detection module
├── requirements.txt   # Python dependencies
└── output/           # Analysis output directory
    ├── result.txt    # Token analysis results
    └── errors.txt    # Error reports
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
