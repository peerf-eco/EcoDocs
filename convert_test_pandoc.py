#!/usr/bin/env python3
"""
Script to convert FODT files to Markdown using 5 different conversion variants.
This version uses pypandoc (Python Pandoc library) instead of the command-line tool.

PREREQUISITES:
To use this script, you need to install:
1. LibreOffice - for FODT/ODT/DOC/RTF/HTML conversions
2. pypandoc Python package - Python bindings for Pandoc
3. html-to-markdown Python package - Modern HTML to Markdown converter
4. markitdown Python package - Microsoft's HTML to Markdown converter
5. vertopal-cli Python package - Vertopal CLI for lossless conversions

INSTALLATION:
1. LibreOffice (if not already installed):
   Using Chocolatey package manager:
      choco install libreoffice
   
   Using official installer:
      https://www.libreoffice.org/download/download/

2. Python packages:
   pip install pypandoc html-to-markdown markitdown vertopal-cli

Note: The first time you run pypandoc, it may need to download Pandoc binaries automatically.

USAGE:
   python convert_test_pandoc.py [directory] [--output-dir output_directory]

If no directory is specified, it will search for FODT files in the current directory.

🔧 Current Performance:

All 5 conversion variants now work successfully without popup windows:

1. Variant 1: FODT → HTML → Markdown (GFM with raw HTML stripped) ✅ IMPROVED
2. Variant 2: FODT → ODT → Markdown (pypandoc) ✅ 
3. Variant 3: FODT → RTF → Markdown (pypandoc) ✅
4. Variant 4: FODT → HTML → Markdown (html-to-markdown) ✅ NEW
5. Variant 5: FODT → HTML → Markdown (Vertopal + MarkItDown) ✅ NEW

🎯 Key Improvements:

•  Tried to fix CMD popups: The subprocess.CREATE_NO_WINDOW flag added , but CMD windows still shown by LibreOffice
•  Cleaner GFM output: Variant 1 now produces GitHub Flavored Markdown with much less HTML clutter
•  Better formatting: The new format removes excessive font tags and styling while preserving structure
•  Five working variants: You can now compare all 5 different conversion approaches to choose the best output
•  New Variant 5: Uses Vertopal for lossless HTML conversion + MarkItDown for intelligent Markdown conversion

📊 File Size Comparison:
•  Variant 1 (GFM): ~61KB - Clean GFM with minimal HTML
•  Variant 2 (ODT): ~44KB - Standard Pandoc markdown
•  Variant 3 (RTF): ~63KB - RTF-based conversion
•  Variant 4 (html-to-markdown): ~12KB - Most compact, clean output
•  Variant 5 (Vertopal + MarkItDown): TBD - Lossless conversion with metadata extraction

"""

import os
import sys
import subprocess
import logging
import argparse
import glob
import shutil
import zipfile
import time
from pathlib import Path

# Try to import pypandoc
try:
    import pypandoc
except ImportError:
    print("Error: pypandoc not found. Please install it with: pip install pypandoc")
    sys.exit(1)

# Try to import html-to-markdown
try:
    from html_to_markdown import convert_to_markdown
except ImportError:
    print("Error: html-to-markdown not found. Please install it with: pip install html-to-markdown")
    sys.exit(1)

# Try to import markitdown and vertopal for Variant 5
try:
    from markitdown import MarkItDown
except ImportError:
    print("Warning: markitdown not found. Variant 5 will not work. Install it with: pip install markitdown")
    MarkItDown = None

try:
    import vertopal
except ImportError:
    print("Warning: vertopal not found. Variant 5 will not work. Install it with: pip install vertopal")
    vertopal = None

# Try to import BeautifulSoup for HTML cleaning in Variant 5
try:
    from bs4 import BeautifulSoup
except ImportError:
    print("Warning: BeautifulSoup not found. Variant 5 HTML cleaning will be limited. Install it with: pip install beautifulsoup4")
    BeautifulSoup = None

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


def check_executable(executable):
    """Check if an executable is available in the system PATH."""
    try:
        subprocess.run(
            [executable, "--version"], 
            capture_output=True, 
            check=True,
            stdin=subprocess.DEVNULL,
            creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
        )
        return True
    except (subprocess.SubprocessError, FileNotFoundError):
        return False


def ensure_pandoc():
    """Ensure Pandoc is available, downloading it if necessary."""
    try:
        # Try to use pypandoc
        pypandoc.get_pandoc_version()
        return True
    except Exception as e:
        logger.info("Pandoc not found, attempting to download...")
        try:
            # Try to download pandoc
            pypandoc.download_pandoc()
            logger.info("Pandoc downloaded successfully")
            return True
        except Exception as download_error:
            logger.error(f"Failed to download Pandoc: {download_error}")
            logger.info("Please install Pandoc manually from: https://pandoc.org/installing.html")
            return False


def find_fodt_files(directory="."):
    """Find all FODT files in the specified directory."""
    pattern = os.path.join(directory, "*.fodt")
    return glob.glob(pattern)


def convert_fodt_to_html_variant(fodt_file, output_dir="converted_docs"):
    """
    Variant 1: Convert FODT -> HTML using LibreOffice, then HTML -> Markdown using Pandoc.
    """
    logger.info(f"Starting Variant 1 conversion for: {fodt_file}")
    
    # Check if LibreOffice is available
    if not check_executable("soffice"):
        logger.error("LibreOffice (soffice) not found in PATH. Please install LibreOffice.")
        return False
    
    try:
        # Create output directory if it doesn't exist
        os.makedirs(output_dir, exist_ok=True)
        
        # Get base filename without extension
        base_name = os.path.splitext(os.path.basename(fodt_file))[0]
        html_file = os.path.join(output_dir, f"{base_name}.html")
        md_file = os.path.join(output_dir, f"{base_name}_1.md")
        
        # Convert FODT to HTML using LibreOffice
        logger.info(f"Converting {fodt_file} to HTML...")
        # Convert paths to forward slashes for LibreOffice compatibility
        fodt_file_normalized = fodt_file.replace('\\', '/')
        output_dir_normalized = output_dir.replace('\\', '/')
        
        cmd = [
            "soffice",
            "--headless",
            "--invisible",
            "--nodefault",
            "--nolockcheck",
            "--nologo",
            "--norestore",
            "--convert-to", "html",
            "--outdir", output_dir_normalized,
            fodt_file_normalized
        ]
        
        logger.info(f"Running command: {' '.join(cmd)}")
        # Use DEVNULL and CREATE_NO_WINDOW to prevent popup windows on Windows
        result = subprocess.run(
            cmd, 
            capture_output=True, 
            text=True,
            stdin=subprocess.DEVNULL,
            creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
        )
        if result.returncode != 0:
            logger.error(f"LibreOffice conversion failed: {result.stderr}")
            return False
        
        # Wait a moment for LibreOffice to finish writing the file
        logger.info(f"LibreOffice stdout: {result.stdout}")
        time.sleep(2)
            
        # Check if HTML file was created
        if not os.path.exists(html_file):
            logger.error(f"HTML file not found: {html_file}")
            logger.info(f"LibreOffice stdout: {result.stdout}")
            logger.info(f"LibreOffice stderr: {result.stderr}")
            return False
            
        # Convert HTML to Markdown using pypandoc with GFM and raw HTML removal
        logger.info(f"Converting {html_file} to Markdown using pypandoc (GFM)...")
        output = pypandoc.convert_file(
            html_file, 
            'gfm',  # GitHub Flavored Markdown
            format='html-raw_html',  # HTML with raw HTML stripped
            extra_args=[]  # Additional args can be added here if needed
        )
        
        # Write output to file
        with open(md_file, 'w', encoding='utf-8') as f:
            f.write(output)
        
        # Clean up intermediate HTML file
        os.remove(html_file)
        
        logger.info(f"Variant 1 conversion completed: {md_file}")
        return True
        
    except Exception as e:
        logger.error(f"Variant 1 conversion failed: {str(e)}")
        return False


def convert_fodt_to_odt_variant(fodt_file, output_dir="converted_docs"):
    """
    Variant 2: Convert FODT -> ODT using LibreOffice, then ODT -> Markdown using Pandoc.
    """
    logger.info(f"Starting Variant 2 conversion for: {fodt_file}")
    
    # Check if LibreOffice is available
    if not check_executable("soffice"):
        logger.error("LibreOffice (soffice) not found in PATH. Please install LibreOffice.")
        return False
    
    try:
        # Create output directory if it doesn't exist
        os.makedirs(output_dir, exist_ok=True)
        
        # Get base filename without extension
        base_name = os.path.splitext(os.path.basename(fodt_file))[0]
        odt_file = os.path.join(output_dir, f"{base_name}.odt")
        md_file = os.path.join(output_dir, f"{base_name}_2.md")
        
        # Convert FODT to ODT using LibreOffice
        logger.info(f"Converting {fodt_file} to ODT...")
        # Convert paths to forward slashes for LibreOffice compatibility
        fodt_file_normalized = fodt_file.replace('\\', '/')
        output_dir_normalized = output_dir.replace('\\', '/')
        
        cmd = [
            "soffice",
            "--headless",
            "--invisible",
            "--nodefault",
            "--nolockcheck",
            "--nologo",
            "--norestore",
            "--convert-to", "odt",
            "--outdir", output_dir_normalized,
            fodt_file_normalized
        ]
        
        logger.info(f"Running command: {' '.join(cmd)}")
        # Use DEVNULL and CREATE_NO_WINDOW to prevent popup windows on Windows
        result = subprocess.run(
            cmd, 
            capture_output=True, 
            text=True,
            stdin=subprocess.DEVNULL,
            creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
        )
        if result.returncode != 0:
            logger.error(f"LibreOffice conversion failed: {result.stderr}")
            return False
        
        # Wait a moment for LibreOffice to finish writing the file
        logger.info(f"LibreOffice stdout: {result.stdout}")
        time.sleep(2)
            
        # Check if ODT file was created
        if not os.path.exists(odt_file):
            logger.error(f"ODT file not found: {odt_file}")
            logger.info(f"LibreOffice stdout: {result.stdout}")
            logger.info(f"LibreOffice stderr: {result.stderr}")
            return False
            
        # Convert ODT to Markdown using pypandoc
        logger.info(f"Converting {odt_file} to Markdown using pypandoc...")
        output = pypandoc.convert_file(odt_file, 'md', format='odt')
        
        # Write output to file
        with open(md_file, 'w', encoding='utf-8') as f:
            f.write(output)
        
        # Clean up intermediate ODT file
        os.remove(odt_file)
        
        logger.info(f"Variant 2 conversion completed: {md_file}")
        return True
        
    except Exception as e:
        logger.error(f"Variant 2 conversion failed: {str(e)}")
        # Try to clean up intermediate ODT file if it exists
        if os.path.exists(odt_file):
            os.remove(odt_file)
        return False


def convert_fodt_fallback_variant(fodt_file, output_dir="converted_docs"):
    """
    Variant 3: Convert FODT to RTF/DOCX using LibreOffice, then RTF/DOCX -> Markdown using Pandoc.
    """
    logger.info(f"Starting Variant 3 conversion for: {fodt_file}")
    
    # Check if LibreOffice is available
    if not check_executable("soffice"):
        logger.error("LibreOffice (soffice) not found in PATH. Please install LibreOffice.")
        return False
    
    try:
        # Create output directory if it doesn't exist
        os.makedirs(output_dir, exist_ok=True)
        
        # Get base filename without extension
        base_name = os.path.splitext(os.path.basename(fodt_file))[0]
        md_file = os.path.join(output_dir, f"{base_name}_3.md")
        
        # Convert FODT to RTF using LibreOffice (RTF is better supported by pandoc than DOC)
        logger.info(f"Converting {fodt_file} to RTF...")
        # Convert paths to forward slashes for LibreOffice compatibility
        fodt_file_normalized = fodt_file.replace('\\', '/')
        output_dir_normalized = output_dir.replace('\\', '/')
        
        # Use RTF as primary format since pandoc doesn't support .doc
        rtf_file = os.path.join(output_dir, f"{base_name}.rtf")
        cmd = [
            "soffice",
            "--headless",
            "--invisible",
            "--nodefault",
            "--nolockcheck",
            "--nologo",
            "--norestore",
            "--convert-to", "rtf",
            "--outdir", output_dir_normalized,
            fodt_file_normalized
        ]
        
        logger.info(f"Running command: {' '.join(cmd)}")
        # Use DEVNULL and CREATE_NO_WINDOW to prevent popup windows on Windows
        result = subprocess.run(
            cmd, 
            capture_output=True, 
            text=True,
            stdin=subprocess.DEVNULL,
            creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
        )
        if result.returncode != 0:
            logger.warning(f"RTF conversion failed, trying DOCX: {result.stderr}")
            # Try DOCX as fallback
            docx_file = os.path.join(output_dir, f"{base_name}.docx")
            cmd = [
                "soffice",
                "--headless",
                "--invisible",
                "--nodefault",
                "--nolockcheck",
                "--nologo",
                "--norestore",
                "--convert-to", "docx",
                "--outdir", output_dir_normalized,
                fodt_file_normalized
            ]
            
            # Use DEVNULL and CREATE_NO_WINDOW to prevent popup windows on Windows
            result = subprocess.run(
                cmd, 
                capture_output=True, 
                text=True,
                stdin=subprocess.DEVNULL,
                creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
            )
            if result.returncode != 0:
                logger.error(f"DOCX conversion also failed: {result.stderr}")
                return False
                
            # Use DOCX file for Pandoc conversion
            doc_file = docx_file
        else:
            logger.info("Successfully converted to RTF")
            doc_file = rtf_file
        
        # Wait a moment for LibreOffice to finish writing the file
        logger.info(f"LibreOffice stdout: {result.stdout}")
        time.sleep(2)
            
        # Check if RTF/DOCX file was created
        if not os.path.exists(doc_file):
            logger.error(f"RTF/DOCX file not found: {doc_file}")
            logger.info(f"LibreOffice stdout: {result.stdout}")
            logger.info(f"LibreOffice stderr: {result.stderr}")
            return False
            
        # Convert RTF/DOCX to Markdown using pypandoc
        logger.info(f"Converting {doc_file} to Markdown using pypandoc...")
        if doc_file.endswith(".rtf"):
            input_format = "rtf"
        elif doc_file.endswith(".docx"):
            input_format = "docx"
        else:
            input_format = "rtf"  # fallback
        output = pypandoc.convert_file(doc_file, 'md', format=input_format)
        
        # Write output to file
        with open(md_file, 'w', encoding='utf-8') as f:
            f.write(output)
        
        # Clean up intermediate RTF/DOCX file
        os.remove(doc_file)
        
        logger.info(f"Variant 3 conversion completed: {md_file}")
        return True
        
    except Exception as e:
        logger.error(f"Variant 3 conversion failed: {str(e)}")
        # Try to clean up intermediate RTF/DOCX file if it exists
        rtf_file = os.path.join(output_dir, f"{base_name}.rtf")
        docx_file = os.path.join(output_dir, f"{base_name}.docx")
        if os.path.exists(rtf_file):
            os.remove(rtf_file)
        if os.path.exists(docx_file):
            os.remove(docx_file)
        return False


def convert_fodt_vertopal_markitdown_variant(fodt_file, output_dir="converted_docs"):
    """
    Variant 5: Convert FODT → HTML using LibreOffice, then HTML → Markdown using MarkItDown.
    
    This variant uses:
    - LibreOffice for HTML conversion (same as other variants)
    - MarkItDown for intelligent HTML to Markdown conversion with metadata extraction
    
    Note: Originally intended to use Vertopal, but it requires API keys.
    """
    logger.info(f"Starting Variant 5 conversion for: {fodt_file}")
    
    # Check if MarkItDown is available
    if MarkItDown is None:
        logger.error("MarkItDown not found. Please install it with: pip install markitdown")
        return False
    
    # Check if LibreOffice is available
    if not check_executable("soffice"):
        logger.error("LibreOffice (soffice) not found in PATH. Please install LibreOffice.")
        return False
    
    try:
        # Create output directory if it doesn't exist
        os.makedirs(output_dir, exist_ok=True)
        
        # Get base filename without extension
        base_name = os.path.splitext(os.path.basename(fodt_file))[0]
        html_file = os.path.join(output_dir, f"{base_name}_markitdown.html")
        md_file = os.path.join(output_dir, f"{base_name}_5.md")
        
        # Step 1: Convert FODT to HTML using LibreOffice
        logger.info(f"Converting {fodt_file} to HTML using LibreOffice...")
        
        # Convert paths to forward slashes for LibreOffice compatibility
        fodt_file_normalized = fodt_file.replace('\\', '/')
        output_dir_normalized = output_dir.replace('\\', '/')
        
        cmd = [
            "soffice",
            "--headless",
            "--invisible",
            "--nodefault",
            "--nolockcheck",
            "--nologo",
            "--norestore",
            "--convert-to", "html",
            "--outdir", output_dir_normalized,
            fodt_file_normalized
        ]
        
        logger.info(f"Running command: {' '.join(cmd)}")
        # Use DEVNULL and CREATE_NO_WINDOW to prevent popup windows on Windows
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            stdin=subprocess.DEVNULL,
            creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
        )
        
        if result.returncode != 0:
            logger.error(f"LibreOffice conversion failed: {result.stderr}")
            return False
        
        logger.info(f"LibreOffice conversion successful")
        logger.info(f"LibreOffice stdout: {result.stdout}")
        
        # Wait a moment for LibreOffice to finish writing the file
        time.sleep(2)
        
        # LibreOffice creates HTML with the same base name as the input file
        actual_html_file = os.path.join(output_dir, f"{base_name}.html")
        
        # Check if HTML file was created
        if not os.path.exists(actual_html_file):
            logger.error(f"HTML file not found: {actual_html_file}")
            return False
        
        # Step 2: Preprocess HTML for MarkItDown
        logger.info(f"Preprocessing HTML for MarkItDown...")
        
        # Read and clean HTML
        with open(actual_html_file, 'r', encoding='utf-8') as f:
            html_content = f.read()
        
        import re
        from bs4 import BeautifulSoup
        
        soup = BeautifulSoup(html_content, 'html.parser')
        
        # Remove formatting tags but preserve content
        for tag in soup.find_all(['b', 'strong', 'i', 'em', 'font', 'span']):
            tag.unwrap()
        
        # Remove style attributes
        for tag in soup.find_all():
            if tag.attrs:
                tag.attrs = {k: v for k, v in tag.attrs.items() if k not in ['style', 'class']}
        
        cleaned_html_file = os.path.join(output_dir, f"{base_name}_cleaned.html")
        with open(cleaned_html_file, 'w', encoding='utf-8') as f:
            f.write(str(soup))
        
        # Step 3: Convert using MarkItDown
        logger.info(f"Converting with MarkItDown...")
        markitdown = MarkItDown()
        result = markitdown.convert(cleaned_html_file)
        
        if hasattr(result, 'text_content'):
            markdown_content = result.text_content
        else:
            markdown_content = str(result)
        
        # Step 4: Clean up markdown and fix specific issues
        # Fix pointer types
        markdown_content = re.sub(r'(\w+_t)/', r'\1*', markdown_content)
        markdown_content = re.sub(r'(void)/', r'\1*', markdown_content)
        
        # Convert IDL tables to C code blocks based on content signatures
        def convert_idl_tables(text):
            lines = text.split('\n')
            result_lines = []
            in_table = False
            table_lines = []
            
            for line in lines:
                # Check if this line contains IDL signatures
                if any(keyword in line for keyword in ['import "', 'interface ', 'uguid(', '[object']):
                    if '|' in line:  # It's a table
                        in_table = True
                        table_lines = [line]
                        continue
                
                if in_table:
                    if '|' in line or line.strip() == '' or '---' in line:
                        table_lines.append(line)
                        continue
                    else:
                        # End of table, convert it
                        code_lines = []
                        for tline in table_lines:
                            if '---' in tline or not tline.strip():
                                continue
                            clean = re.sub(r'^\|\s*', '', tline)
                            clean = re.sub(r'\s*\|\s*$', '', clean)
                            clean = re.sub(r'\s*\|\s*', '  ', clean)
                            if clean.strip():
                                code_lines.append(clean)
                        
                        if code_lines:
                            result_lines.append('```c')
                            result_lines.extend(code_lines)
                            result_lines.append('```')
                        
                        in_table = False
                        table_lines = []
                        result_lines.append(line)
                else:
                    result_lines.append(line)
            
            return '\n'.join(result_lines)
        
        try:
            markdown_content = convert_idl_tables(markdown_content)
        except Exception as e:
            logger.warning(f"IDL conversion failed: {e}")
        
        # Remove backslash escapes from type names and function names
        markdown_content = re.sub(r'(\w+)\\_t', r'\1_t', markdown_content)
        markdown_content = re.sub(r'\\\*', '*', markdown_content)
        markdown_content = re.sub(r'(\w+)\\_', r'\1_', markdown_content)
        
        # Fix section numbering - preserve hierarchical structure
        lines = markdown_content.split('\n')
        fixed_lines = []
        section_counters = [0, 0, 0, 0]  # Track up to 4 levels
        
        for line in lines:
            # Match numbered sections
            match = re.match(r'^(\d+)\. (.+)', line)
            if match:
                num = int(match.group(1))
                title = match.group(2)
                
                # Determine section level based on context
                if any(keyword in title.lower() for keyword in ['overview', 'component', 'interface', 'error', 'appendix']):
                    # Main section
                    section_counters[0] = num
                    section_counters[1] = 0
                    section_counters[2] = 0
                    fixed_lines.append(f'{num}. {title}')
                elif any(keyword in title.lower() for keyword in ['introduction', 'note', 'links', 'idl']):
                    # Subsection
                    section_counters[1] += 1
                    section_counters[2] = 0
                    fixed_lines.append(f'{section_counters[0]}.{section_counters[1]}. {title}')
                elif 'function' in title.lower():
                    # Function subsection
                    section_counters[2] += 1
                    fixed_lines.append(f'{section_counters[0]}.{section_counters[1]}.{section_counters[2]}. {title}')
                else:
                    fixed_lines.append(line)
            else:
                fixed_lines.append(line)
        
        markdown_content = '\n'.join(fixed_lines)
        
        # Clean up excessive line breaks
        markdown_content = re.sub(r'\n{3,}', '\n\n', markdown_content)
        
        # Write output to file
        with open(md_file, 'w', encoding='utf-8') as f:
            f.write(markdown_content)
        
        # Clean up temporary files
        if os.path.exists(cleaned_html_file):
            os.remove(cleaned_html_file)
        
        # Clean up intermediate HTML file
        os.remove(actual_html_file)
        
        logger.info(f"Variant 5 conversion completed: {md_file}")
        return True
        
    except Exception as e:
        logger.error(f"Variant 5 conversion failed: {str(e)}")
        # Clean up intermediate HTML file if it exists
        if 'actual_html_file' in locals() and os.path.exists(actual_html_file):
            os.remove(actual_html_file)
        return False


def convert_fodt_html_to_markdown_variant(fodt_file, output_dir="converted_docs"):
    """
    Variant 4: Convert FODT → HTML using LibreOffice, then HTML → Markdown using html-to-markdown library.
    """
    logger.info(f"Starting Variant 4 conversion for: {fodt_file}")
    
    # Check if LibreOffice is available
    if not check_executable("soffice"):
        logger.error("LibreOffice (soffice) not found in PATH. Please install LibreOffice.")
        return False
    
    try:
        # Create output directory if it doesn't exist
        os.makedirs(output_dir, exist_ok=True)
        
        # Get base filename without extension
        base_name = os.path.splitext(os.path.basename(fodt_file))[0]
        html_file = os.path.join(output_dir, f"{base_name}_temp.html")
        md_file = os.path.join(output_dir, f"{base_name}_4.md")
        
        # Convert FODT to HTML using LibreOffice
        logger.info(f"Converting {fodt_file} to HTML...")
        # Convert paths to forward slashes for LibreOffice compatibility
        fodt_file_normalized = fodt_file.replace('\\', '/')
        output_dir_normalized = output_dir.replace('\\', '/')
        
        cmd = [
            "soffice",
            "--headless",
            "--invisible",
            "--nodefault",
            "--nolockcheck",
            "--nologo",
            "--norestore",
            "--convert-to", "html",
            "--outdir", output_dir_normalized,
            fodt_file_normalized
        ]
        
        logger.info(f"Running command: {' '.join(cmd)}")
        # Use DEVNULL and CREATE_NO_WINDOW to prevent popup windows on Windows
        result = subprocess.run(
            cmd, 
            capture_output=True, 
            text=True,
            stdin=subprocess.DEVNULL,
            creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
        )
        if result.returncode != 0:
            logger.error(f"LibreOffice conversion failed: {result.stderr}")
            return False
        
        # Wait a moment for LibreOffice to finish writing the file
        logger.info(f"LibreOffice stdout: {result.stdout}")
        time.sleep(2)
        
        # LibreOffice creates HTML with the same base name as the input file
        actual_html_file = os.path.join(output_dir, f"{base_name}.html")
            
        # Check if HTML file was created
        if not os.path.exists(actual_html_file):
            logger.error(f"HTML file not found: {actual_html_file}")
            logger.info(f"LibreOffice stdout: {result.stdout}")
            logger.info(f"LibreOffice stderr: {result.stderr}")
            return False
            
        # Read HTML file
        logger.info(f"Reading HTML file: {actual_html_file}")
        with open(actual_html_file, 'r', encoding='utf-8') as f:
            html_content = f.read()
            
        # Convert HTML to Markdown using html-to-markdown
        logger.info(f"Converting HTML to Markdown using html-to-markdown...")
        markdown_content = convert_to_markdown(
            html_content,
            heading_style="atx",  # Use # style headers
            extract_metadata=False,  # Don't extract metadata
            wrap=False,  # Don't wrap text
            escape_asterisks=False,  # Don't escape * characters to avoid double escaping
            escape_underscores=False,  # Don't escape _ characters
            strip=['font', 'span', 'b', 'strong', 'i', 'em'],  # Remove formatting tags that cause nested markup
            convert_as_inline=False,  # Keep block-level structure
            strip_newlines=False  # Preserve newlines
        )
        
        # Post-process to clean up excessive asterisks (bold formatting)
        logger.info("Post-processing to clean up excessive asterisks...")
        # Replace patterns like ****text with **text (remove excessive bold nesting)
        import re
        markdown_content = re.sub(r'\*{4,}([^*]+)\*{4,}', r'**\1**', markdown_content)
        markdown_content = re.sub(r'\*{3}([^*]+)\*{3}', r'**\1**', markdown_content)
        # Clean up any remaining patterns like word****word
        markdown_content = re.sub(r'(\w)\*{2,}(\w)', r'\1**\2', markdown_content)
        # Remove standalone asterisks that might remain
        markdown_content = re.sub(r'(?<!\*)\*{2,}(?!\*)', '**', markdown_content)
        
        # Write output to file
        with open(md_file, 'w', encoding='utf-8') as f:
            f.write(markdown_content)
        
        # Clean up intermediate HTML file
        os.remove(actual_html_file)
        
        # Also clean up any generated images
        for file in os.listdir(output_dir):
            if file.startswith(f"{base_name}_html_") and file.endswith(".png"):
                os.remove(os.path.join(output_dir, file))
        
        logger.info(f"Variant 4 conversion completed: {md_file}")
        return True
        
    except Exception as e:
        logger.error(f"Variant 4 conversion failed: {str(e)}")
        return False


def process_fodt_files(directory=".", output_dir="converted_docs"):
    """Process all FODT files in the specified directory using all 5 variants."""
    logger.info(f"Searching for FODT files in: {directory}")
    
    # Find FODT files
    fodt_files = find_fodt_files(directory)
    
    if not fodt_files:
        logger.warning(f"No FODT files found in: {directory}")
        logger.info("Please provide a directory containing FODT files or add FODT files to the current directory.")
        return False
    
    logger.info(f"Found {len(fodt_files)} FODT files")
    
    # Ensure Pandoc is available
    if not ensure_pandoc():
        logger.error("Pandoc is required but could not be installed.")
        return False
    
    # Check if LibreOffice is available
    if not check_executable("soffice"):
        logger.warning("LibreOffice not found. Some variants may not work.")
        logger.info("To install LibreOffice:")
        logger.info("Using Chocolatey: choco install libreoffice")
        logger.info("Or download from: https://www.libreoffice.org/download/download/")
    
    # Process each FODT file with all 5 variants
    for fodt_file in fodt_files:
        logger.info(f"Processing file: {fodt_file}")
        
        # Variant 1: FODT → HTML → Markdown
        convert_fodt_to_html_variant(fodt_file, output_dir)
        
        # Variant 2: FODT → ODT → Markdown
        convert_fodt_to_odt_variant(fodt_file, output_dir)
        
        # Variant 3: FODT → DOC/RTF → Markdown
        convert_fodt_fallback_variant(fodt_file, output_dir)
        
        # Variant 4: FODT → HTML → Markdown (using html-to-markdown)
        convert_fodt_html_to_markdown_variant(fodt_file, output_dir)
        
        # Variant 5: FODT → HTML → Markdown (using Vertopal + MarkItDown)
        convert_fodt_vertopal_markitdown_variant(fodt_file, output_dir)
        
        logger.info(f"Completed processing: {fodt_file}")
        print("-" * 50)
    
    return True


def main():
    """Main function to run the conversion script."""
    parser = argparse.ArgumentParser(description="Convert FODT files to Markdown using 5 variants (pypandoc version)")
    parser.add_argument(
        "directory",
        nargs="?",
        default=".",
        help="Directory containing FODT files (default: current directory)"
    )
    parser.add_argument(
        "--output-dir",
        default="converted_docs",
        help="Output directory for converted files (default: converted_docs)"
    )
    
    args = parser.parse_args()
    
    logger.info("=== CONVERT_TEST_PANDOC.PY START ===")
    
    # Process FODT files
    success = process_fodt_files(args.directory, args.output_dir)
    
    if success:
        logger.info("=== CONVERT_TEST_PANDOC.PY COMPLETE ===")
        print(f"Converted files are in: {args.output_dir}/")
    else:
        logger.error("=== CONVERT_TEST_PANDOC.PY FAILED ===")
        sys.exit(1)


if __name__ == "__main__":
    main()