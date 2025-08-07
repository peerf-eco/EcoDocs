#!/usr/bin/env python3
"""
Script to convert FODT files to Markdown using 4 different conversion variants.

PREREQUISITES:
To use this script, you need to install:
1. LibreOffice - for FODT/ODT/DOC/RTF conversions
2. Pandoc - for HTML/ODT/DOC/RTF to Markdown conversions

INSTALLATION ON WINDOWS:
Using Chocolatey package manager:
   choco install libreoffice
   choco install pandoc

Using official installers:
1. LibreOffice: https://www.libreoffice.org/download/download/
2. Pandoc: https://pandoc.org/installing.html

After installation, ensure both 'soffice' and 'pandoc' are in your system PATH.
You can verify this by running in command prompt:
   soffice --version
   pandoc --version

USAGE:
   python convert_test.py [directory] [--output-dir output_directory]

If no directory is specified, it will search for FODT files in the current directory.
"""

import os
import sys
import subprocess
import logging
import argparse
import glob
import shutil
import zipfile
from pathlib import Path


# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


def check_executable(executable):
    """Check if an executable is available in the system PATH."""
    try:
        subprocess.run([executable, "--version"], 
                      capture_output=True, check=True)
        return True
    except (subprocess.SubprocessError, FileNotFoundError):
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
    
    # Check if required tools are available
    if not check_executable("soffice"):
        logger.error("LibreOffice (soffice) not found in PATH. Please install LibreOffice.")
        return False
        
    if not check_executable("pandoc"):
        logger.error("Pandoc not found in PATH. Please install Pandoc.")
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
        cmd = [
            "soffice",
            "--headless",
            "--convert-to", "html:HTML (StarWriter)",
            "--outdir", output_dir,
            fodt_file
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            logger.error(f"LibreOffice conversion failed: {result.stderr}")
            return False
            
        # Check if HTML file was created
        if not os.path.exists(html_file):
            logger.error(f"HTML file not found: {html_file}")
            return False
            
        # Convert HTML to Markdown using Pandoc
        logger.info(f"Converting {html_file} to Markdown...")
        cmd = [
            "pandoc",
            html_file,
            "-f", "html",
            "-t", "markdown",
            "-o", md_file
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            logger.error(f"Pandoc conversion failed: {result.stderr}")
            return False
            
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
    
    # Check if required tools are available
    if not check_executable("soffice"):
        logger.error("LibreOffice (soffice) not found in PATH. Please install LibreOffice.")
        return False
        
    if not check_executable("pandoc"):
        logger.error("Pandoc not found in PATH. Please install Pandoc.")
        return False
    
    try:
        # Create output directory if it doesn't exist
        os.makedirs(output_dir, exist_ok=True)
        
        # Get base filename without extension
        base_name = os.path.splitext(os.path.basename(fodt_file))[0]
        odt_file = os.path.join(os.path.dirname(fodt_file), f"{base_name}.odt")
        md_file = os.path.join(output_dir, f"{base_name}_2.md")
        
        # Convert FODT to ODT using LibreOffice
        logger.info(f"Converting {fodt_file} to ODT...")
        cmd = [
            "soffice",
            "--headless",
            "--convert-to", "odt:writer8",
            "--outdir", os.path.dirname(fodt_file),
            fodt_file
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            logger.error(f"LibreOffice conversion failed: {result.stderr}")
            return False
            
        # Check if ODT file was created
        if not os.path.exists(odt_file):
            logger.error(f"ODT file not found: {odt_file}")
            return False
            
        # Convert ODT to Markdown using Pandoc
        logger.info(f"Converting {odt_file} to Markdown...")
        cmd = [
            "pandoc",
            odt_file,
            "-f", "odt",
            "-t", "markdown",
            "-o", md_file
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            logger.error(f"Pandoc conversion failed: {result.stderr}")
            # Clean up intermediate ODT file
            if os.path.exists(odt_file):
                os.remove(odt_file)
            return False
            
        # Clean up intermediate ODT file
        if os.path.exists(odt_file):
            os.remove(odt_file)
        
        logger.info(f"Variant 2 conversion completed: {md_file}")
        return True
        
    except Exception as e:
        logger.error(f"Variant 2 conversion failed: {str(e)}")
        # Try to clean up intermediate ODT file if it exists
        odt_file = os.path.join(os.path.dirname(fodt_file), f"{base_name}.odt")
        if os.path.exists(odt_file):
            os.remove(odt_file)
        return False


def convert_fodt_zip_variant(fodt_file, output_dir="converted_docs"):
    """
    Variant 3: Zip FODT file, rename archive with .odt extension, then apply Pandoc.
    """
    logger.info(f"Starting Variant 3 conversion for: {fodt_file}")
    
    # Check if required tools are available
    if not check_executable("pandoc"):
        logger.error("Pandoc not found in PATH. Please install Pandoc.")
        return False
    
    try:
        # Create output directory if it doesn't exist
        os.makedirs(output_dir, exist_ok=True)
        
        # Get base filename without extension
        base_name = os.path.splitext(os.path.basename(fodt_file))[0]
        odt_file = os.path.join(output_dir, f"{base_name}.odt")
        md_file = os.path.join(output_dir, f"{base_name}_3.md")
        
        # Create a zip archive of the FODT file with .odt extension
        logger.info(f"Zipping {fodt_file} as {odt_file}...")
        shutil.copy2(fodt_file, odt_file)
        
        # Convert ODT to Markdown using Pandoc
        logger.info(f"Converting {odt_file} to Markdown...")
        cmd = [
            "pandoc",
            odt_file,
            "-f", "odt",
            "-t", "markdown",
            "-o", md_file
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            logger.error(f"Pandoc conversion failed: {result.stderr}")
            # Clean up intermediate ODT file
            if os.path.exists(odt_file):
                os.remove(odt_file)
            return False
            
        # Clean up intermediate ODT file
        if os.path.exists(odt_file):
            os.remove(odt_file)
        
        logger.info(f"Variant 3 conversion completed: {md_file}")
        return True
        
    except Exception as e:
        logger.error(f"Variant 3 conversion failed: {str(e)}")
        return False


def convert_fodt_to_doc_variant(fodt_file, output_dir="converted_docs"):
    """
    Variant 4: Convert FODT to DOC (or RTF) using LibreOffice, then apply Pandoc.
    """
    logger.info(f"Starting Variant 4 conversion for: {fodt_file}")
    
    # Check if required tools are available
    if not check_executable("soffice"):
        logger.error("LibreOffice (soffice) not found in PATH. Please install LibreOffice.")
        return False
        
    if not check_executable("pandoc"):
        logger.error("Pandoc not found in PATH. Please install Pandoc.")
        return False
    
    try:
        # Create output directory if it doesn't exist
        os.makedirs(output_dir, exist_ok=True)
        
        # Get base filename without extension
        base_name = os.path.splitext(os.path.basename(fodt_file))[0]
        doc_file = os.path.join(os.path.dirname(fodt_file), f"{base_name}.doc")
        md_file = os.path.join(output_dir, f"{base_name}_4.md")
        
        # Convert FODT to DOC using LibreOffice
        logger.info(f"Converting {fodt_file} to DOC...")
        cmd = [
            "soffice",
            "--headless",
            "--convert-to", "doc",
            "--outdir", os.path.dirname(fodt_file),
            fodt_file
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            logger.warning(f"DOC conversion failed, trying RTF: {result.stderr}")
            # Try RTF as fallback
            rtf_file = os.path.join(os.path.dirname(fodt_file), f"{base_name}.rtf")
            cmd = [
                "soffice",
                "--headless",
                "--convert-to", "rtf",
                "--outdir", os.path.dirname(fodt_file),
                fodt_file
            ]
            
            result = subprocess.run(cmd, capture_output=True, text=True)
            if result.returncode != 0:
                logger.error(f"RTF conversion also failed: {result.stderr}")
                return False
                
            # Use RTF file for Pandoc conversion
            doc_file = rtf_file
        else:
            logger.info("Successfully converted to DOC")
            
        # Check if DOC/RTF file was created
        if not os.path.exists(doc_file):
            logger.error(f"DOC/RTF file not found: {doc_file}")
            return False
            
        # Convert DOC/RTF to Markdown using Pandoc
        logger.info(f"Converting {doc_file} to Markdown...")
        input_format = "doc" if doc_file.endswith(".doc") else "rtf"
        cmd = [
            "pandoc",
            doc_file,
            "-f", input_format,
            "-t", "markdown",
            "-o", md_file
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            logger.error(f"Pandoc conversion failed: {result.stderr}")
            # Clean up intermediate DOC/RTF file
            if os.path.exists(doc_file):
                os.remove(doc_file)
            return False
            
        # Clean up intermediate DOC/RTF file
        if os.path.exists(doc_file):
            os.remove(doc_file)
        
        logger.info(f"Variant 4 conversion completed: {md_file}")
        return True
        
    except Exception as e:
        logger.error(f"Variant 4 conversion failed: {str(e)}")
        # Try to clean up intermediate DOC/RTF file if it exists
        doc_file = os.path.join(os.path.dirname(fodt_file), f"{base_name}.doc")
        rtf_file = os.path.join(os.path.dirname(fodt_file), f"{base_name}.rtf")
        if os.path.exists(doc_file):
            os.remove(doc_file)
        if os.path.exists(rtf_file):
            os.remove(rtf_file)
        return False


def process_fodt_files(directory=".", output_dir="converted_docs"):
    """Process all FODT files in the specified directory using all 4 variants."""
    logger.info(f"Searching for FODT files in: {directory}")
    
    # Find FODT files
    fodt_files = find_fodt_files(directory)
    
    if not fodt_files:
        logger.warning(f"No FODT files found in: {directory}")
        logger.info("Please provide a directory containing FODT files or add FODT files to the current directory.")
        return False
    
    logger.info(f"Found {len(fodt_files)} FODT files")
    
    # Check if required tools are available
    tools_available = True
    if not check_executable("soffice") and not check_executable("pandoc"):
        logger.error("Neither LibreOffice nor Pandoc found. Please install both tools.")
        tools_available = False
    elif not check_executable("soffice"):
        logger.warning("LibreOffice not found. Variants 1, 2, and 4 will not work.")
    elif not check_executable("pandoc"):
        logger.warning("Pandoc not found. All variants will not work.")
        tools_available = False
    
    if not tools_available:
        logger.info("Please install LibreOffice and Pandoc to use all conversion variants.")
        logger.info("INSTALLATION ON WINDOWS:")
        logger.info("Using Chocolatey package manager:")
        logger.info("   choco install libreoffice")
        logger.info("   choco install pandoc")
        logger.info("")
        logger.info("Using official installers:")
        logger.info("1. LibreOffice: https://www.libreoffice.org/download/download/")
        logger.info("2. Pandoc: https://pandoc.org/installing.html")
        return False
    
    # Process each FODT file with all 4 variants
    for fodt_file in fodt_files:
        logger.info(f"Processing file: {fodt_file}")
        
        # Variant 1: FODT -> HTML -> Markdown
        convert_fodt_to_html_variant(fodt_file, output_dir)
        
        # Variant 2: FODT -> ODT -> Markdown
        convert_fodt_to_odt_variant(fodt_file, output_dir)
        
        # Variant 3: Zip FODT -> rename to ODT -> Markdown
        convert_fodt_zip_variant(fodt_file, output_dir)
        
        # Variant 4: FODT -> DOC/RTF -> Markdown
        convert_fodt_to_doc_variant(fodt_file, output_dir)
        
        logger.info(f"Completed processing: {fodt_file}")
        print("-" * 50)
    
    return True


def main():
    """Main function to run the conversion script."""
    parser = argparse.ArgumentParser(description="Convert FODT files to Markdown using 4 variants")
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
    
    logger.info("=== CONVERT_TEST.PY START ===")
    
    # Process FODT files
    success = process_fodt_files(args.directory, args.output_dir)
    
    if success:
        logger.info("=== CONVERT_TEST.PY COMPLETE ===")
        print(f"Converted files are in: {args.output_dir}/")
    else:
        logger.error("=== CONVERT_TEST.PY FAILED ===")
        sys.exit(1)


if __name__ == "__main__":
    main()