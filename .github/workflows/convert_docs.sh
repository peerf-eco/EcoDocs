#!/bin/bash
echo "=== CONVERT_DOCS.SH START ==="
echo "Script received arguments: $#"
echo "Files to process: $@"

# Create the output directory if it doesn't exist
mkdir -p converted_docs
echo "Output directory created: converted_docs/"

# Counter for tracking conversions
converted_count=0

# Loop through all changed files and convert them
for file in "$@"; do
  echo "Processing file: $file"
  
  if [[ ! -f "$file" ]]; then
    echo "ERROR: File not found: $file"
    continue
  fi
  
  base="${file%.*}"
  filename="${base##*/}"
  output_file="converted_docs/${filename}.md"
  
  echo "Converting: $file -> $output_file"
  
  # Check file extension and use appropriate conversion
  if [[ "$file" == *.fodt ]]; then
    echo "Detected FODT format, attempting direct FODT->Markdown conversion..."
    
    # Try direct FODT to Markdown conversion using LibreOffice
    if soffice --headless --convert-to markdown "$file" --outdir "$(dirname "$output_file")"; then
      temp_md="${file%.fodt}.md"
      if [[ -f "$temp_md" ]]; then
        mv "$temp_md" "$output_file"
        echo "✓ Successfully converted FODT directly to Markdown: $filename"
        ((converted_count++))
      else
        echo "ERROR: LibreOffice conversion succeeded but output file not found"
      fi
    else
      echo "ERROR: Direct FODT->Markdown conversion failed, trying FODT->ODT->MD..."
      
      # Fallback: FODT->ODT->MD conversion
      temp_odt="${file%.fodt}.odt"
      if soffice --headless --convert-to odt:"writer8" "$file" --outdir "$(dirname "$file")"; then
        echo "✓ Converted FODT to ODT: $temp_odt"
        if pandoc "$temp_odt" -f odt -t markdown -o "$output_file"; then
          echo "✓ Successfully converted ODT to MD: $filename"
          ((converted_count++))
        else
          echo "ERROR: Failed to convert ODT to MD: $temp_odt"
        fi
        rm -f "$temp_odt"
      else
        echo "ERROR: Failed to convert FODT to ODT: $file"
      fi
    fi
  else
    # Original ODT conversion for regular .odt files
    if pandoc "$file" -f odt -t markdown -o "$output_file"; then
      echo "✓ Successfully converted: $filename"
      
      # Check if Python script exists
      if [[ -f ".github/workflows/create_metadata.py" ]]; then
        echo "Adding metadata to: $output_file"
        python .github/workflows/create_metadata.py "$output_file" "${GITHUB_SERVER_URL}" "${GITHUB_REPOSITORY}" "${GITHUB_SHA}"
      else
        echo "WARNING: create_metadata.py not found"
      fi
      
      # Verify output file exists
      if [[ -f "$output_file" ]]; then
        echo "✓ Output file created: $output_file ($(stat -c%s "$output_file") bytes)"
        ((converted_count++))
      else
        echo "ERROR: Output file not created: $output_file"
      fi
    else
      echo "ERROR: Failed to convert: $file"
    fi
  fi
  
  echo "---"
done

echo "=== CONVERT_DOCS.SH SUMMARY ==="
echo "Total files processed: $#"
echo "Successfully converted: $converted_count"
echo "Final files in converted_docs/:"
ls -la converted_docs/ 2>/dev/null || echo "No files found"

# Exit with error if no files were successfully converted
if [[ $converted_count -eq 0 ]]; then
  echo "ERROR: No files were successfully converted. Aborting workflow."
  exit 1
fi

echo "=== CONVERT_DOCS.SH COMPLETE ==="
