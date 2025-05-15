import tkinter as tk
from tkinter import filedialog
import os

def detect_language_from_extension(file_path):
    extension = os.path.splitext(file_path)[1].lower()
    if extension == ".c":
        return "C"
    elif extension == ".cpp":
        return "C++"
    elif extension == ".py":
        return "Python"
    else:
        return "Unknown"

def main():
    # Hide the root window
    root = tk.Tk()
    root.withdraw()

    print("Launching file selection dialog...")
    file_path = filedialog.askopenfilename(
        title="Select a code file",
        filetypes=[("Code Files", "*.c *.cpp *.py"), ("All Files", "*.*")]
    )

    if not file_path:
        print("No file selected.")
        return

    language = detect_language_from_extension(file_path)
    print(f"Selected file: {file_path}")
    print(f"Detected language: {language}")
    
    with open("temp.txt", "w") as f:
        f.write(f"{language}\n{file_path}")


    # You can call external tools based on detected language here
    # For example:
    # if language == "C":
    #     subprocess.run(["main.exe", file_path])

if __name__ == "__main__":
    main()

