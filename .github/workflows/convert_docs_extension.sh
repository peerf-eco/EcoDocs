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

# Verify extension is installed
echo "=== VERIFYING DOCEXPORT EXTENSION ==="
if unopkg list --shared | grep -i docexport; then
  echo "✓ DocExport extension found"
else
  echo "❌ CRITICAL: DocExport extension not found"
  echo "Available extensions:"
  unopkg list --shared || echo "No extensions listed"
  echo "❌ CONVERSION SCRIPT TERMINATED: Extension verification failed"
  rm -rf "$temp_odt_dir"
  exit 1
fi

# Second pass: Use LibreOffice extension to convert all ODT files to Markdown
if [[ ${#odt_files[@]} -gt 0 ]]; then
  echo "=== BATCH CONVERSION WITH LIBREOFFICE EXTENSION ==="
  echo "Converting ${#odt_files[@]} ODT files using DocExport extension..."
  
  # List files before conversion for debugging
  echo "Files in temp directory before conversion:"
  echo "ODT files to convert:"
  find "$temp_odt_dir" -type f -name "*.odt" -exec basename {} \;
  odt_count=$(find "$temp_odt_dir" -type f -name "*.odt" | wc -l)
  echo "Total ODT files: $odt_count"
  
  # Run LibreOffice macro with timeout to prevent hanging
  echo "Executing macro: macro:///DocExport.DocModel.ExportDir($temp_odt_dir,1)"
  
  # Kill any existing LibreOffice processes
  pkill -f soffice || true
  sleep 2
  
  # Run with timeout (5 minutes max)
  if timeout 300 soffice --invisible --nofirststartwizard --headless --norestore "macro:///DocExport.DocModel.ExportDir(\"$temp_odt_dir\",1)"; then
    echo "✓ LibreOffice macro execution completed"
    
    # List files after conversion for debugging
    echo "Files in temp directory after conversion:"
    echo "Markdown files:"
    find "$temp_odt_dir" -type f -name "*.md" -exec basename {} \;
    echo "Image folders:"
    find "$temp_odt_dir" -type d -name "img_*" -exec basename {} \;
    md_count=$(find "$temp_odt_dir" -type f -name "*.md" | wc -l)
    echo "Total MD files: $md_count"
    
    # Move converted markdown files to output directory
    for odt_file in "${odt_files[@]}"; do
      base_name=$(basename "$odt_file" .odt)
      md_file="$temp_odt_dir/${base_name}.md"
      output_file="converted_docs/${base_name}.md"
      
      if [[ -f "$md_file" ]]; then
        # Convert to UTF-8 encoding
        python3 -c "import sys; open('$output_file','wb').write(open('$md_file','rb').read().decode(errors='ignore').encode('utf-8'))" 2>/dev/null || cp "$md_file" "$output_file"
        echo "✓ Moved converted file: $output_file (UTF-8)"
        
        # Find and move image folder
        correct_img="$temp_odt_dir/img_${base_name}"
        if [[ -d "$correct_img" ]]; then
          mv "$correct_img" "converted_docs/img_${base_name}"
          echo "✓ Moved image folder: converted_docs/img_${base_name}"
        else
          # Fallback: find folder with full path prefix (old macro behavior)
          img_folder=$(find "$temp_odt_dir" -type d -name "img_*${base_name}*" | head -1)
          if [[ -n "$img_folder" && -d "$img_folder" ]]; then
            mv "$img_folder" "converted_docs/img_${base_name}"
            echo "✓ Moved image folder: converted_docs/img_${base_name} (renamed from old format)"
            sed -i "s|img_[^/]*/|img_${base_name}/|g" "$output_file"
          fi
        fi
        
        # Add metadata if script exists
        if [[ -f ".github/workflows/create_metadata.py" ]]; then
          echo "Adding metadata to: $output_file"
          python3 .github/workflows/create_metadata.py "$output_file" "${GITHUB_SERVER_URL}" "${GITHUB_REPOSITORY}" "${GITHUB_SHA}"
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
    
    # Try alternative macro execution method with timeout
    echo "Trying alternative macro execution..."
    pkill -f soffice || true
    sleep 2
    timeout 300 soffice --headless --invisible --nologo --norestore "macro:///DocExport.DocModel.ExportDir(\"$temp_odt_dir\",1)" || true
    
    # List files after alternative attempt
    echo "Files after alternative attempt:"
    echo "Markdown files:"
    find "$temp_odt_dir" -type f -name "*.md" -exec basename {} \;
    echo "Image folders:"
    find "$temp_odt_dir" -type d -name "img_*" -exec basename {} \;
    md_count=$(find "$temp_odt_dir" -type f -name "*.md" | wc -l)
    echo "Total MD files: $md_count"
    
    # Fallback: Try individual file conversion
    echo "Attempting individual file conversion as fallback..."
    for odt_file in "${odt_files[@]}"; do
      base_name=$(basename "$odt_file" .odt)
      output_file="converted_docs/${base_name}.md"
      individual_dir=$(mktemp -d)
      
      echo "Converting individual file: $odt_file"
      # Copy single file to individual directory
      cp "$odt_file" "$individual_dir/"
      
      pkill -f soffice || true
      sleep 1
      
      echo "Running individual macro on: $individual_dir"
      if timeout 120 soffice --invisible --nofirststartwizard --headless --norestore "macro:///DocExport.DocModel.ExportDir(\"$individual_dir\",1)"; then
        md_file="$individual_dir/${base_name}.md"
        if [[ -f "$md_file" ]]; then
          # Convert to UTF-8 encoding
          python3 -c "import sys; open('$output_file','wb').write(open('$md_file','rb').read().decode(errors='ignore').encode('utf-8'))" 2>/dev/null || cp "$md_file" "$output_file"
          echo "✓ Individual conversion successful: $output_file (UTF-8)"
          
          # Find and move image folder
          correct_img="$individual_dir/img_${base_name}"
          if [[ -d "$correct_img" ]]; then
            mv "$correct_img" "converted_docs/img_${base_name}"
            echo "✓ Moved image folder: converted_docs/img_${base_name}"
          else
            # Fallback: find folder with full path prefix (old macro behavior)
            img_folder=$(find "$individual_dir" -type d -name "img_*${base_name}*" | head -1)
            if [[ -n "$img_folder" && -d "$img_folder" ]]; then
              mv "$img_folder" "converted_docs/img_${base_name}"
              echo "✓ Moved image folder: converted_docs/img_${base_name} (renamed from old format)"
              sed -i "s|img_[^/]*/|img_${base_name}/|g" "$output_file"
            fi
          fi
          
          # Add metadata if script exists
          if [[ -f ".github/workflows/create_metadata.py" ]]; then
            python3 .github/workflows/create_metadata.py "$output_file" "${GITHUB_SERVER_URL}" "${GITHUB_REPOSITORY}" "${GITHUB_SHA}"
          fi
          
          if [[ -f "$output_file" ]]; then
            ((converted_count++))
          fi
        else
          echo "ERROR: Markdown file not created: $md_file"
          echo "Files in individual directory after conversion:"
          find "$individual_dir" -type f -name "*.md" -o -name "*.odt" -exec basename {} \;
          echo "Folders in individual directory:"
          find "$individual_dir" -type d -name "img_*" -exec basename {} \;
        fi
      else
        echo "ERROR: Individual conversion failed for: $odt_file"
      fi
      
      rm -rf "$individual_dir"
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
final_count=$(find converted_docs -type f 2>/dev/null | wc -l)
echo "Total files: $final_count"
find converted_docs -type f -exec basename {} \; 2>/dev/null || echo "No files found"

# Exit with error if no files were successfully converted
if [[ $converted_count -eq 0 ]]; then
  echo "ERROR: No files were successfully converted. Aborting workflow."
  exit 1
fi

echo "=== CONVERT_DOCS_EXTENSION.SH COMPLETE ==="