import tkinter as tk
from tkinter import ttk, filedialog, scrolledtext
import os
import subprocess
from detect_lang import detect_language_from_extension
import sys
from ttkthemes import ThemedTk

class StaticCodeAnalyzerUI:
    def __init__(self):
        self.root = ThemedTk(theme="arc")  # Modern theme
        self.root.title("Static Code Analyzer")
        self.root.geometry("1000x600")
        
        # Configure style
        self.style = ttk.Style()
        self.style.configure("Title.TLabel", font=("Helvetica", 16, "bold"))
        self.style.configure("Info.TLabel", font=("Helvetica", 10))
        self.style.configure("Error.TLabel", foreground="red")
        self.style.configure("Success.TLabel", foreground="green")
        
        self.create_widgets()
        
    def create_widgets(self):
        # Title
        title = ttk.Label(
            self.root, 
            text="Static Code Analyzer", 
            style="Title.TLabel"
        )
        title.pack(pady=20)
        
        # File selection frame
        file_frame = ttk.LabelFrame(self.root, text="File Selection", padding=10)
        file_frame.pack(fill="x", padx=20, pady=5)
        
        self.file_path = tk.StringVar()
        file_entry = ttk.Entry(file_frame, textvariable=self.file_path, width=50)
        file_entry.pack(side="left", padx=5)
        
        browse_btn = ttk.Button(
            file_frame, 
            text="Browse", 
            command=self.browse_file
        )
        browse_btn.pack(side="left", padx=5)
        
        # Language detection frame
        lang_frame = ttk.LabelFrame(self.root, text="Language", padding=10)
        lang_frame.pack(fill="x", padx=20, pady=5)
        
        self.detected_lang = tk.StringVar(value="No file selected")
        lang_label = ttk.Label(
            lang_frame, 
            textvariable=self.detected_lang,
            style="Info.TLabel"
        )
        lang_label.pack()
        
        # Analysis button
        analyze_btn = ttk.Button(
            self.root, 
            text="Analyze Code",
            command=self.analyze_code
        )
        analyze_btn.pack(pady=10)
        
        # Results area split into 2 sections: Code View and Error View
        results_frame = ttk.LabelFrame(self.root, text="Analysis Results", padding=10)
        results_frame.pack(fill="both", expand=True, padx=20, pady=5)
        
        content_frame = ttk.Frame(results_frame)
        content_frame.pack(fill="both", expand=True)
        
        # Source Code Display
        self.code_text = scrolledtext.ScrolledText(
            content_frame,
            wrap=tk.WORD,
            width=60,
            height=20,
            font=("Consolas", 10)
        )
        self.code_text.pack(side="left", fill="both", expand=True, padx=(0, 5))
        self.code_text.insert(tk.END, "Selected file content will appear here...")
        self.code_text.config(state=tk.DISABLED)
        
        # Error Output Display
        self.results_text = scrolledtext.ScrolledText(
            content_frame,
            wrap=tk.WORD,
            width=60,
            height=20,
            font=("Consolas", 10)
        )
        self.results_text.pack(side="left", fill="both", expand=True)
        
        self.results_text.tag_configure("error", foreground="red")
        self.results_text.tag_configure("success", foreground="green")
        self.results_text.tag_configure("info", foreground="blue")
        
    def browse_file(self):
        file_path = filedialog.askopenfilename(
            filetypes=[
                ("All Code Files", "*.c;*.cpp;*.py"),
                ("C Files", "*.c"),
                ("C++ Files", "*.cpp"),
                ("Python Files", "*.py"),
                ("All Files", "*.*")
            ]
        )
        if file_path:
            self.file_path.set(file_path)
            lang = detect_language_from_extension(file_path)
            self.detected_lang.set(f"Detected Language: {lang}")
            
            # Display the source code in left pane
            try:
                with open(file_path, "r") as file:
                    code = file.read()
                self.code_text.config(state=tk.NORMAL)
                self.code_text.delete(1.0, tk.END)
                self.code_text.insert(tk.END, code)
                self.code_text.config(state=tk.DISABLED)
            except Exception as e:
                self.code_text.config(state=tk.NORMAL)
                self.code_text.delete(1.0, tk.END)
                self.code_text.insert(tk.END, f"Failed to read file: {str(e)}")
                self.code_text.config(state=tk.DISABLED)
            
    def analyze_code(self):
        file_path = self.file_path.get()
        if not file_path:
            self.results_text.delete(1.0, tk.END)
            self.results_text.insert(tk.END, "Please select a file first!", "error")
            return

        try:
            # Clear previous results
            self.results_text.delete(1.0, tk.END)
            self.results_text.insert(tk.END, "Analyzing...\n\n", "info")
            self.root.update()

            lang = detect_language_from_extension(file_path)

            os.makedirs("output", exist_ok=True)

            # Choose analyzer
            analyzer_exe = {
                "C": "lex_c.exe",
                "C++": "lex_cpp.exe",
                "Python": "lex_python.exe"
            }.get(lang, None)

            if not analyzer_exe:
                self.results_text.delete(1.0, tk.END)
                self.results_text.insert(tk.END, f"Unsupported file type: {lang}", "error")
                return

            if not os.path.exists(analyzer_exe):
                self.results_text.delete(1.0, tk.END)
                self.results_text.insert(tk.END, f"Error: {analyzer_exe} not found!\n", "error")
                self.results_text.insert(tk.END, "Please make sure all analyzers are compiled correctly.", "error")
                return

            # Run the analyzer
            subprocess.run(
                [os.path.join(".", analyzer_exe), file_path],
                capture_output=True,
                text=True,
                check=False
            )

            # Only show compile-time errors
            self.results_text.delete(1.0, tk.END)
            try:
                with open("output/errors.txt", "r") as f:
                    error_content = f.read().strip()
                    if error_content:
                        self.results_text.insert(tk.END, "Compile-Time Errors:\n\n", "error")
                        self.results_text.insert(tk.END, error_content + "\n", "error")
                    else:
                        self.results_text.insert(tk.END, "No compile-time errors found.\n", "success")
            except FileNotFoundError:
                self.results_text.insert(tk.END, "No compile-time error report found.\n", "info")

        except Exception as e:
            self.results_text.delete(1.0, tk.END)
            self.results_text.insert(tk.END, f"Unexpected error: {str(e)}\n", "error")

    def run(self):
        self.root.mainloop()

if __name__ == "__main__":
    app = StaticCodeAnalyzerUI()
    app.run()
