import os
import sys
from pathlib import Path

def pack_folder(folder_path, output_file):
    folder = Path(folder_path).resolve()
    if not folder.is_dir():
        print(f"Error: '{folder_path}' is not a valid directory.")
        sys.exit(1)
    
    with open(output_file, 'w', encoding='utf-8') as out:
        out.write("# PACKED FOLDER\n")
        out.write(f"# Source: {folder}\n")
        out.write("# Format: Each file is preceded by '===== FILE: relative/path ====='\n")
        out.write("# Empty lines and binary files are skipped (only text files).\n\n")
        
        for root, dirs, files in os.walk(folder):
            # Skip hidden directories like .git, __pycache__ (optional)
            dirs[:] = [d for d in dirs if not d.startswith('.') and d != '__pycache__']
            
            for file in files:
                file_path = Path(root) / file
                rel_path = file_path.relative_to(folder)
                
                # Try to read as text; skip binary files
                try:
                    with open(file_path, 'r', encoding='utf-8') as f:
                        content = f.read()
                except (UnicodeDecodeError, IOError):
                    print(f"Skipping binary file: {rel_path}")
                    continue
                
                out.write(f"===== FILE: {rel_path} =====\n")
                out.write(content)
                if not content.endswith('\n'):
                    out.write('\n')
                out.write("\n")  # separator between files
    
    print(f"Done! Packed text files from '{folder}' into '{output_file}'")
    print(f"Binary files were skipped. Total text files packed.")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python pack_folder.py <source_folder> <output.txt>")
        sys.exit(1)
    pack_folder(sys.argv[1], sys.argv[2])
