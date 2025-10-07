#!/usr/bin/env python3
import sys
import os

def convert_to_utf8_lf(input_path, output_path):
    """Convert file to UTF-8 encoding with LF line endings"""
    
    # Try multiple encodings to handle various source formats
    encodings = ['utf-8', 'windows-1251', 'cp1251', 'iso-8859-1', 'latin1']
    content = None
    used_encoding = None
    
    for encoding in encodings:
        try:
            with open(input_path, 'r', encoding=encoding) as f:
                content = f.read()
            used_encoding = encoding
            break
        except (UnicodeDecodeError, UnicodeError):
            continue
    
    if content is None:
        # Fallback: read as binary and decode with error handling
        with open(input_path, 'rb') as f:
            raw_data = f.read()
        content = raw_data.decode('utf-8', errors='replace')
        used_encoding = 'utf-8-fallback'
    
    # Normalize line endings to LF (Unix style)
    content = content.replace('\r\n', '\n').replace('\r', '\n')
    
    # Write as UTF-8 with LF line endings
    with open(output_path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(content)
    
    return used_encoding

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: convert_encoding.py <input_file> <output_file>")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_file = sys.argv[2]
    
    try:
        used_encoding = convert_to_utf8_lf(input_file, output_file)
        print(f"SUCCESS: Converted from {used_encoding} to UTF-8 with LF endings")
    except Exception as e:
        print(f"ERROR: {e}")
        sys.exit(1)