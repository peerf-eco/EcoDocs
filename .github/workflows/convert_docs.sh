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
  
  # Convert with pandoc
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
  
  echo "---"
done

echo "=== CONVERT_DOCS.SH SUMMARY ==="
echo "Total files processed: $#"
echo "Successfully converted: $converted_count"
echo "Final files in converted_docs/:"
ls -la converted_docs/ 2>/dev/null || echo "No files found"
echo "=== CONVERT_DOCS.SH COMPLETE ==="
