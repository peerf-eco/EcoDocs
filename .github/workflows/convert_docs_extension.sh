#!/bin/bash
echo "=== CONVERT_DOCS_EXTENSION.SH START ==="
echo "Script received arguments: $#"
echo "Files to process: $@"

# Create the output directory if it doesn't exist
mkdir -p converted_docs
echo "Output directory created: converted_docs/"

# Create temporary directory for ODT files
temp_odt_dir=$(mktemp -d)
echo "Temporary ODT directory created: $temp_odt_dir"

# Counter for tracking conversions
converted_count=0
odt_files=()

# First pass: Convert FODT files to ODT and collect all ODT files
for file in "$@"; do
  echo "Processing file: $file"
  
  if [[ ! -f "$file" ]]; then
    echo "ERROR: File not found: $file"
    continue
  fi
  
  base="${file%.*}"
  filename="${base##*/}"
  
  if [[ "$file" == *.fodt ]]; then
    echo "Converting FODT to ODT: $file"
    temp_odt="$temp_odt_dir/${filename}.odt"
    
    if soffice --headless --convert-to odt:"writer8" "$file" --outdir "$temp_odt_dir"; then
      echo "✓ Successfully converted FODT to ODT: ${filename}.odt"
      odt_files+=("$temp_odt")
    else
      echo "ERROR: Failed to convert FODT to ODT: $file"
    fi
  elif [[ "$file" == *.odt ]]; then
    # Copy existing ODT files to temp directory
    temp_odt="$temp_odt_dir/${filename}.odt"
    cp "$file" "$temp_odt"
    echo "✓ Copied ODT file to temp directory: ${filename}.odt"
    odt_files+=("$temp_odt")
  fi
done

# Second pass: Use LibreOffice extension to convert all ODT files to Markdown
if [[ ${#odt_files[@]} -gt 0 ]]; then
  echo "=== BATCH CONVERSION WITH LIBREOFFICE EXTENSION ==="
  echo "Converting ${#odt_files[@]} ODT files using DocExport extension..."
  
  # Run LibreOffice macro to export all ODT files in the directory to Markdown
  if soffice --invisible --nofirststartwizard --headless --norestore "macro:///DocExport.DocModel.ExportDir(&quot;$temp_odt_dir&quot;,1)"; then
    echo "✓ LibreOffice macro execution completed"
    
    # Move converted markdown files to output directory
    for odt_file in "${odt_files[@]}"; do
      base_name=$(basename "$odt_file" .odt)
      md_file="$temp_odt_dir/${base_name}.md"
      output_file="converted_docs/${base_name}.md"
      
      if [[ -f "$md_file" ]]; then
        mv "$md_file" "$output_file"
        echo "✓ Moved converted file: $output_file"
        
        # Add metadata if script exists
        if [[ -f ".github/workflows/create_metadata.py" ]]; then
          echo "Adding metadata to: $output_file"
          python .github/workflows/create_metadata.py "$output_file" "${GITHUB_SERVER_URL}" "${GITHUB_REPOSITORY}" "${GITHUB_SHA}"
        else
          echo "WARNING: create_metadata.py not found"
        fi
        
        # Verify output file exists and count
        if [[ -f "$output_file" ]]; then
          echo "✓ Output file created: $output_file ($(stat -c%s "$output_file") bytes)"
          ((converted_count++))
        else
          echo "ERROR: Output file not created: $output_file"
        fi
      else
        echo "ERROR: Markdown file not found after conversion: $md_file"
      fi
    done
  else
    echo "ERROR: LibreOffice macro execution failed"
    
    # Fallback: Try individual file conversion
    echo "Attempting individual file conversion as fallback..."
    for odt_file in "${odt_files[@]}"; do
      base_name=$(basename "$odt_file" .odt)
      output_file="converted_docs/${base_name}.md"
      
      echo "Converting individual file: $odt_file"
      if soffice --invisible --nofirststartwizard --headless --norestore "macro:///DocExport.DocModel.ExportDir(&quot;$(dirname "$odt_file")&quot;,1)"; then
        md_file="$(dirname "$odt_file")/${base_name}.md"
        if [[ -f "$md_file" ]]; then
          mv "$md_file" "$output_file"
          echo "✓ Individual conversion successful: $output_file"
          
          # Add metadata if script exists
          if [[ -f ".github/workflows/create_metadata.py" ]]; then
            python .github/workflows/create_metadata.py "$output_file" "${GITHUB_SERVER_URL}" "${GITHUB_REPOSITORY}" "${GITHUB_SHA}"
          fi
          
          if [[ -f "$output_file" ]]; then
            ((converted_count++))
          fi
        fi
      else
        echo "ERROR: Individual conversion failed for: $odt_file"
      fi
    done
  fi
else
  echo "No ODT files to convert"
fi

# Cleanup temporary directory
rm -rf "$temp_odt_dir"
echo "Temporary directory cleaned up"

echo "=== CONVERT_DOCS_EXTENSION.SH SUMMARY ==="
echo "Total files processed: $#"
echo "Successfully converted: $converted_count"
echo "Final files in converted_docs/:"
ls -la converted_docs/ 2>/dev/null || echo "No files found"

# Exit with error if no files were successfully converted
if [[ $converted_count -eq 0 ]]; then
  echo "ERROR: No files were successfully converted. Aborting workflow."
  exit 1
fi

echo "=== CONVERT_DOCS_EXTENSION.SH COMPLETE ==="