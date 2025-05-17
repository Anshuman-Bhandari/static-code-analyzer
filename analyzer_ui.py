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
            self.results_text.insert(tk.END, "Please select a file first!")
            return
            
        try:
            # Run the analysis using the existing tools
            self.results_text.delete(1.0, tk.END)
            self.results_text.insert(tk.END, "Analyzing...\n\n")
            self.root.update()
            
            # Call the main analyzer executable
            result = subprocess.run(
                ["main.exe", file_path],
                capture_output=True,
                text=True
            )
            
            # Display results
            if result.stdout:
                self.results_text.insert(tk.END, result.stdout)
            if result.stderr:
                self.results_text.insert(tk.END, "\nErrors:\n" + result.stderr)
                
        except Exception as e:
            self.results_text.delete(1.0, tk.END)
            self.results_text.insert(tk.END, f"Error during analysis: {str(e)}")
            
    def run(self):
        self.root.mainloop()

if __name__ == "__main__":
    app = StaticCodeAnalyzerUI()
    app.run() 