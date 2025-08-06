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
    echo "Detected FODT format, attempting FODT->HTML->Markdown conversion..."
    
    # Use HTML as intermediate format since LibreOffice doesn't support direct Markdown export
    echo "Attempting LibreOffice FODT->HTML conversion..."
    temp_html="converted_docs/${filename}.html"
    
    if soffice --headless --convert-to html:"HTML (StarWriter)" "$file" --outdir "converted_docs/"; then
      echo "✓ Successfully converted FODT to HTML: ${filename}.html"
      
      # Now convert HTML to Markdown using pandoc
      if [[ -f "converted_docs/${filename}.html" ]]; then
        if pandoc "converted_docs/${filename}.html" -f html -t markdown -o "$output_file"; then
          echo "✓ Successfully converted HTML to Markdown: $filename"
          
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
            
            # Clean up intermediate HTML file
            rm -f "converted_docs/${filename}.html"
          else
            echo "ERROR: Output file not created: $output_file"
          fi
        else
          echo "ERROR: Failed to convert HTML to Markdown: ${filename}.html"
          # Keep HTML file for debugging
        fi
      else
        echo "ERROR: HTML file not found after LibreOffice conversion"
      fi
    else
      echo "ERROR: LibreOffice FODT->HTML conversion failed, trying FODT->ODT->MD..."
      
      # Fallback: FODT->ODT->MD conversion
      temp_odt="${file%.fodt}.odt"
      if soffice --headless --convert-to odt:"writer8" "$file" --outdir "$(dirname "$file")"; then
        echo "✓ Converted FODT to ODT: $temp_odt"
        if pandoc "$temp_odt" -f odt -t markdown -o "$output_file"; then
          echo "✓ Successfully converted ODT to MD: $filename"
          
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
          echo "ERROR: Failed to convert ODT to MD: $temp_odt"
        fi
        rm -f "$temp_odt"
      else
        echo "ERROR: Failed to convert FODT to ODT: $file"
      fi
    fi
  else
    # Original ODT conversion for regular .odt files
    echo "Processing ODT file: $file"
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
