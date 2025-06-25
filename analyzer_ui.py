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
        self.root.geometry("800x600")
        
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
        
        # Results area
        results_frame = ttk.LabelFrame(self.root, text="Analysis Results", padding=10)
        results_frame.pack(fill="both", expand=True, padx=20, pady=5)
        
        self.results_text = scrolledtext.ScrolledText(
            results_frame, 
            wrap=tk.WORD,
            width=70,
            height=15,
            font=("Consolas", 10)
        )
        self.results_text.pack(fill="both", expand=True)
        
        # Configure tags for messages
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
            
            # Get the language
            lang = detect_language_from_extension(file_path)
            
            # Create output directory if it doesn't exist
            os.makedirs("output", exist_ok=True)
            
            # Run lexical analysis based on language
            analyzer_exe = ""
            if lang == "C":
                analyzer_exe = "lex_c.exe"
            elif lang == "C++":
                analyzer_exe = "lex_cpp.exe"
            elif lang == "Python":
                analyzer_exe = "lex_python.exe"
            else:
                self.results_text.delete(1.0, tk.END)
                self.results_text.insert(tk.END, f"Unsupported file type: {lang}", "error")
                return

            # Check if analyzer exists
            if not os.path.exists(analyzer_exe):
                self.results_text.delete(1.0, tk.END)
                self.results_text.insert(tk.END, f"Error: {analyzer_exe} not found!\n", "error")
                self.results_text.insert(tk.END, "Please make sure all analyzers are compiled correctly.", "error")
                return

            # Run the appropriate analyzer
            try:
                result = subprocess.run(
                    [os.path.join(".", analyzer_exe), file_path],
                    capture_output=True,
                    text=True,
                    check=True
                )
                
                # Display any stdout messages
                if result.stdout:
                    self.results_text.insert(tk.END, "Output:\n", "info")
                    self.results_text.insert(tk.END, result.stdout + "\n")
                
            except subprocess.CalledProcessError as e:
                self.results_text.insert(tk.END, f"Analysis failed: {str(e)}\n", "error")
                if e.stdout:
                    self.results_text.insert(tk.END, "Output:\n", "info")
                    self.results_text.insert(tk.END, e.stdout + "\n")
                if e.stderr:
                    self.results_text.insert(tk.END, "Errors:\n", "error")
                    self.results_text.insert(tk.END, e.stderr + "\n", "error")
                return
                
            # Read and display errors
            try:
                with open("output/errors.txt", "r") as f:
                    error_content = f.read().strip()
                    if error_content:
                        # Remove the end marker if present
                        error_content = error_content.replace("\n--- End of Compile-Time Error Report ---", "")
                        if error_content.strip():
                            self.results_text.insert(tk.END, "\nCompile-Time Errors:\n", "error")
                            self.results_text.insert(tk.END, error_content + "\n", "error")
                        else:
                            self.results_text.insert(tk.END, "\nNo compile-time errors found.\n", "success")
                
                # Read and display analysis results
                with open("output/result.txt", "r") as f:
                    result_content = f.read().strip()
                    if result_content:
                        self.results_text.insert(tk.END, "\nAnalysis Results:\n", "info")
                        self.results_text.insert(tk.END, result_content + "\n")
                        
            except FileNotFoundError as e:
                self.results_text.insert(tk.END, f"\nWarning: Could not read analysis files: {str(e)}\n", "error")
                
        except Exception as e:
            self.results_text.delete(1.0, tk.END)
            self.results_text.insert(tk.END, f"Unexpected error: {str(e)}\n", "error")
            
    def run(self):
        self.root.mainloop()

if __name__ == "__main__":
    app = StaticCodeAnalyzerUI()
    app.run() 