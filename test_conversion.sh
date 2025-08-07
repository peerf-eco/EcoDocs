#!/bin/bash
# Test script to verify FODT conversion works locally

echo "=== TESTING FODT CONVERSION FIX ==="

# Check if required tools are installed
echo "Checking required tools..."
command -v soffice >/dev/null 2>&1 || { echo "LibreOffice (soffice) not found. Please install LibreOffice."; exit 1; }
command -v pandoc >/dev/null 2>&1 || { echo "Pandoc not found. Please install pandoc."; exit 1; }

# Test file
TEST_FILE="components/000000000000000000000000000000AA/en/Eco.Core1_EN.fodt"

if [[ ! -f "$TEST_FILE" ]]; then
  echo "ERROR: Test file not found: $TEST_FILE"
  exit 1
fi

echo "Test file found: $TEST_FILE"

# Create test directory
mkdir -p test_output
rm -f test_output/*

# Test the new conversion approach
echo ""
echo "=== TESTING NEW CONVERSION STRATEGY ==="
echo "Step 1: FODT -> HTML using LibreOffice"

if soffice --headless --convert-to html:"HTML (StarWriter)" "$TEST_FILE" --outdir "test_output/"; then
  echo "✓ LibreOffice conversion successful"
  
  # Check if HTML file was created
  HTML_FILE="test_output/Eco.Core1_EN.html"
  if [[ -f "$HTML_FILE" ]]; then
    echo "✓ HTML file created: $HTML_FILE ($(stat -c%s "$HTML_FILE" 2>/dev/null || echo "size unknown") bytes)"
    
    echo ""
    echo "Step 2: HTML -> Markdown using Pandoc"
    
    MD_FILE="test_output/Eco.Core1_EN.md"
    if pandoc "$HTML_FILE" -f html -t markdown -o "$MD_FILE"; then
      echo "✓ Pandoc conversion successful"
      
      if [[ -f "$MD_FILE" ]]; then
        echo "✓ Markdown file created: $MD_FILE ($(stat -c%s "$MD_FILE" 2>/dev/null || echo "size unknown") bytes)"
        
        echo ""
        echo "=== CONVERSION SUMMARY ==="
        echo "Original file: $TEST_FILE"
        echo "Intermediate: $HTML_FILE"
        echo "Final output: $MD_FILE"
        
        echo ""
        echo "First 10 lines of converted markdown:"
        echo "---"
        head -10 "$MD_FILE" 2>/dev/null || echo "Could not read file"
        echo "---"
        
        # Clean up
        rm -f "$HTML_FILE"
        
        echo ""
        echo "✅ TEST PASSED: Conversion strategy works correctly!"
        exit 0
      else
        echo "❌ ERROR: Markdown file not created"
        exit 1
      fi
    else
      echo "❌ ERROR: Pandoc conversion failed"
      exit 1
    fi
  else
    echo "❌ ERROR: HTML file not created by LibreOffice"
    exit 1
  fi
else
  echo "❌ ERROR: LibreOffice conversion failed"
  exit 1
fi