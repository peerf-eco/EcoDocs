#!/bin/bash
set -euo pipefail

echo "=== CONVERT_DOCS_EXTENSION.SH START ==="
echo "Script received arguments: $#"
echo "Files to process: $@"

# Create the output directory if it doesn't exist
mkdir -p converted_docs
echo "✓ Output directory created: converted_docs/"

# Create temporary directory for ODT files
temp_odt_dir=$(mktemp -d)
echo "✓ Temporary ODT directory created: $temp_odt_dir"

# Tracking arrays and lists
converted_count=0
failed_count=0
odt_files=()
original_file_map=()
processed_files_list=""
failed_files_list=""

# First pass: Convert FODT files to ODT and collect all ODT files
echo "=== PHASE 1: FODT TO ODT CONVERSION ==="
for file in "$@"; do
  echo "📄 Processing input file: $file"
  
  if [[ ! -f "$file" ]]; then
    echo "❌ ERROR: File not found: $file"
    ((failed_count++))
    continue
  fi
  
  file_size=$(stat -c%s "$file" 2>/dev/null || echo '0')
  echo "   File size: $file_size bytes"
  
  if [[ $file_size -eq 0 ]]; then
    echo "❌ ERROR: File is empty (0 bytes): $file"
    ((failed_count++))
    continue
  fi
  
  base="${file%.*}"
  filename="${base##*/}"
  
  if [[ "$file" == *.fodt ]]; then
    echo "🔄 Converting FODT to ODT: $file"
    temp_odt="$temp_odt_dir/${filename}.odt"
    
    if soffice --headless --convert-to odt:"writer8" "$file" --outdir "$temp_odt_dir" 2>&1; then
      if [[ -f "$temp_odt" ]]; then
        odt_size=$(stat -c%s "$temp_odt" 2>/dev/null || echo '0')
        echo "✓ Successfully converted FODT to ODT: ${filename}.odt ($odt_size bytes)"
        odt_files+=("${filename}.odt")
        original_file_map+=("$file")
      else
        echo "❌ ERROR: ODT file not created: $temp_odt"
        ((failed_count++))
      fi
    else
      echo "❌ ERROR: Failed to convert FODT to ODT: $file"
      ((failed_count++))
    fi
  elif [[ "$file" == *.odt ]]; then
    temp_odt="$temp_odt_dir/${filename}.odt"
    if cp "$file" "$temp_odt"; then
      echo "✓ Copied ODT file to temp directory: ${filename}.odt"
      odt_files+=("${filename}.odt")
      original_file_map+=("$file")
    else
      echo "❌ ERROR: Failed to copy ODT file: $file"
      ((failed_count++))
    fi
  else
    echo "⚠️  WARNING: Unsupported file type: $file"
    ((failed_count++))
  fi
done

echo "📊 Phase 1 Summary: ${#odt_files[@]} ODT files ready, $failed_count files failed"

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

# Convert ODT files to Markdown individually
if [[ ${#odt_files[@]} -gt 0 ]]; then
  echo "=== PHASE 2: ODT TO MARKDOWN CONVERSION ==="
  echo "Converting ${#odt_files[@]} ODT files one by one..."
  
  cd "$temp_odt_dir" || exit 1
  
  file_index=0
  for odt_file in *.odt; do
    if [ -f "$odt_file" ]; then
      echo ""
      echo "📄 Processing [$((file_index+1))/${#odt_files[@]}]: $odt_file"
      
      # Clean up any lingering LibreOffice processes
      pkill -f soffice 2>/dev/null || true
      sleep 1
      
      # Run conversion macro
      echo "🔄 Running conversion macro..."
      if soffice --headless --invisible --nologo --norestore "$odt_file" 'macro:///DocExport.DocModel.MakeDocHfmView' 2>&1; then
        echo "✓ Macro execution completed"
      else
        echo "⚠️  Macro execution returned non-zero exit code (may be normal)"
      fi
      
      # Wait for file system to settle
      sleep 5
      
      base_name=$(basename "$odt_file" .odt)
      md_file="${base_name}.md"
      output_file="$OLDPWD/converted_docs/${base_name}.md"
      original_file="${original_file_map[$file_index]}"
      
      # Check if markdown file was created
      if [[ -f "$md_file" ]]; then
        md_size=$(stat -c%s "$md_file" 2>/dev/null || echo '0')
        echo "✓ Markdown file created: $md_file ($md_size bytes)"
        
        if [[ $md_size -eq 0 ]]; then
          echo "❌ ERROR: Generated markdown file is empty"
          ((failed_count++))
        else
          # Convert to UTF-8 encoding
          if python3 -c "import sys; open('$output_file','wb').write(open('$md_file','rb').read().decode(errors='ignore').encode('utf-8'))" 2>/dev/null; then
            echo "✓ Converted to UTF-8: $output_file"
          else
            cp "$md_file" "$output_file"
            echo "✓ Copied (fallback): $output_file"
          fi
          
          # Handle image folder
          img_folder="img_${base_name}"
          if [[ -d "$img_folder" ]]; then
            img_count=$(find "$img_folder" -type f | wc -l)
            echo "📁 Found image folder: $img_folder ($img_count images)"
            if mv "$img_folder" "$OLDPWD/converted_docs/img_${base_name}"; then
              echo "✓ Moved image folder: converted_docs/img_${base_name}"
            else
              echo "❌ ERROR: Failed to move image folder"
            fi
          else
            echo "ℹ️  No image folder found (this is normal for text-only documents)"
          fi
          
          # Add metadata
          if [[ -f "$OLDPWD/.github/workflows/create_metadata.py" ]]; then
            if python3 "$OLDPWD/.github/workflows/create_metadata.py" "$output_file" "${GITHUB_SERVER_URL}" "${GITHUB_REPOSITORY}" "${GITHUB_SHA}" 2>&1; then
              echo "✓ Metadata added"
            else
              echo "⚠️  WARNING: Failed to add metadata (non-critical)"
            fi
          fi
          
          # Verify final output
          if [[ -f "$output_file" ]]; then
            final_size=$(stat -c%s "$output_file" 2>/dev/null || echo '0')
            echo "✅ SUCCESS: $original_file → $output_file ($final_size bytes)"
            ((converted_count++))
            processed_files_list="$processed_files_list $original_file"
          else
            echo "❌ ERROR: Output file verification failed"
            ((failed_count++))
            failed_files_list="$failed_files_list $original_file"
          fi
        fi
      else
        echo "❌ ERROR: Markdown file not created: $md_file"
        echo "🔍 Files in temp directory:"
        ls -la | head -10
        ((failed_count++))
        failed_files_list="$failed_files_list $original_file"
      fi
      
      ((file_index++))
    fi
  done
  
  cd "$OLDPWD" || exit 1
else
  echo "⚠️  No ODT files to convert"
fi

# Cleanup temporary directory
echo ""
echo "=== CLEANUP ==="
if rm -rf "$temp_odt_dir"; then
  echo "✓ Temporary directory cleaned up"
else
  echo "⚠️  WARNING: Failed to clean up temporary directory"
fi

# Final cleanup of LibreOffice processes
pkill -f soffice 2>/dev/null || true

# Export processed and failed files for state tracking
echo ""
echo "=== STATE TRACKING EXPORT ==="
if [[ -n "$processed_files_list" ]]; then
  echo "PROCESSED_FILES=$processed_files_list" >> "${GITHUB_ENV:-/dev/null}"
  echo "✓ Exported processed files: $processed_files_list"
else
  echo "PROCESSED_FILES=" >> "${GITHUB_ENV:-/dev/null}"
  echo "ℹ️  No processed files to export"
fi

if [[ -n "$failed_files_list" ]]; then
  echo "FAILED_FILES=$failed_files_list" >> "${GITHUB_ENV:-/dev/null}"
  echo "✓ Exported failed files: $failed_files_list"
else
  echo "FAILED_FILES=" >> "${GITHUB_ENV:-/dev/null}"
  echo "ℹ️  No failed files to export"
fi

echo ""
echo "=== CONVERT_DOCS_EXTENSION.SH SUMMARY ==="
echo "📊 Conversion Statistics:"
echo "   Input files received: $#"
echo "   Successfully converted: $converted_count"
echo "   Failed conversions: $failed_count"
echo "   Success rate: $(( converted_count * 100 / $# ))%"

echo ""
echo "📁 Output directory contents:"
if [[ -d "converted_docs" ]]; then
  md_count=$(find converted_docs -name "*.md" -type f 2>/dev/null | wc -l)
  img_count=$(find converted_docs -type d -name "img_*" 2>/dev/null | wc -l)
  echo "   Markdown files: $md_count"
  echo "   Image folders: $img_count"
  
  if [[ $md_count -gt 0 ]]; then
    echo ""
    echo "📄 Generated files:"
    find converted_docs -name "*.md" -type f -exec bash -c 'echo "   - $(basename {}) ($(stat -c%s {} 2>/dev/null || echo 0) bytes)"' \; 2>/dev/null | sort
  fi
else
  echo "   ❌ ERROR: Output directory not found"
fi

echo ""
# Exit with error if no files were successfully converted
if [[ $converted_count -eq 0 ]]; then
  echo "❌ RESULT: No files were successfully converted. Aborting workflow."
  echo "=== CONVERT_DOCS_EXTENSION.SH FAILED ==="
  exit 1
fi

echo "✅ RESULT: Successfully converted $converted_count out of $# files"
echo "=== CONVERT_DOCS_EXTENSION.SH COMPLETE ==="