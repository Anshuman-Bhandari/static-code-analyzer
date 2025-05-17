<<<<<<< HEAD
# Static Code Analyzer Project

A modern static code analyzer with a graphical user interface that helps detect potential issues in C, C++, and Python code files.

## Features

- Modern graphical user interface built with Tkinter
- Support for analyzing C, C++, and Python files
- Automatic language detection
- Real-time analysis feedback
- Clean and intuitive results display

## Prerequisites

- Python 3.x
- GCC compiler (for C/C++ analysis)
- Make utility

## Installation

1. Clone the repository:
```bash
git clone https://github.com/DivyanshuDhasmana/Static-Code-Analyzer-Project.git
cd Static-Code-Analyzer-Project
```

2. Install the required Python dependencies:
```bash
pip install -r requirements.txt
```

3. Build the project:
```bash
make
```

## Usage

There are two ways to use the Static Code Analyzer:

### 1. Graphical User Interface (Recommended)

Run the GUI version:
```bash
python analyzer_ui.py
```

With the GUI you can:
- Click "Browse" to select a code file
- View the automatically detected programming language
- Click "Analyze Code" to run the analysis
- View results in the scrollable text area

### 2. Command Line Interface

For command-line usage:
```bash
main.exe <path_to_file>
```

## Supported File Types

- C files (*.c)
- C++ files (*.cpp)
- Python files (*.py)

## Project Structure

- `analyzer_ui.py` - The main GUI application
- `detect_lang.py` - Language detection module
- `main.c` - Core analyzer implementation
- `lex_c.l`, `lex_cpp.l`, `lex_python.l` - Lexical analyzers for different languages
- `Makefile` - Build configuration

## Building from Source

The project uses Make for building the C/C++ components:

```bash
make clean  # Clean previous builds
make        # Build the project
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details. 
=======
# Static-Code-Analyzer-Project
>>>>>>> 11a32da2a3cce4896f6d02ccef49dd9145ccf1db
