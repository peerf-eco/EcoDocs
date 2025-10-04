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
echo "🔍 Checking shared extensions (as root)..."

# Count only top-level Identifier lines (not sub-components)
shared_count=$(unopkg list --shared 2>/dev/null | grep "^Identifier:" | grep -i docexport | wc -l)
echo "   Found $shared_count DocExport extension package(s) in shared context"

if [ $shared_count -eq 0 ]; then
  echo "❌ CRITICAL: DocExport extension not found"
  echo "Available extensions:"
  unopkg list --shared 2>/dev/null || echo "No extensions listed"
  echo "❌ CONVERSION SCRIPT TERMINATED: Extension verification failed"
  rm -rf "$temp_odt_dir"
  exit 1
elif [ $shared_count -gt 1 ]; then
  echo "❌ CRITICAL: Multiple DocExport extension packages detected ($shared_count instances)"
  echo "📋 Extension identifiers:"
  unopkg list --shared 2>/dev/null | grep "^Identifier:" | grep -i docexport
  echo "❌ CONVERSION SCRIPT TERMINATED: Multiple extensions will cause conflicts"
  rm -rf "$temp_odt_dir"
  exit 1
else
  echo "✓ DocExport extension found (1 package)"
fi

echo "🔍 LibreOffice environment:"
echo "   Version: $(soffice --version)"
echo "   User: $(whoami) (UID: $(id -u))"

# Convert ODT files to Markdown individually
if [[ ${#odt_files[@]} -gt 0 ]]; then
  echo "=== PHASE 2: ODT TO MARKDOWN CONVERSION ==="
  echo "Converting ${#odt_files[@]} ODT files one by one..."
  
  cd "$temp_odt_dir" || exit 1
  
  # Fast-fail test: Try converting first file with short timeout
  echo ""
  echo "🧪 FAST-FAIL TEST: Testing macro on first file..."
  first_odt=$(ls *.odt | head -1)
  echo "   Test file: $first_odt ($(stat -c%s "$first_odt") bytes)"
  
  pkill -f soffice 2>/dev/null || true
  sleep 1
  
  echo "   Running test conversion (30s timeout)..."
  echo "   Command: timeout 30 soffice --headless --invisible --nologo --norestore \"$first_odt\" 'macro:///DocExport.DocModel.MakeDocHfmView'"
  
  # Capture output for debugging
  test_output=$(timeout 30 soffice --headless --invisible --nologo --norestore "$first_odt" 'macro:///DocExport.DocModel.MakeDocHfmView' 2>&1) || test_exit=$?
  
  if [ ${test_exit:-0} -eq 0 ]; then
    echo "✓ Test conversion command completed"
    if [ -n "$test_output" ]; then
      echo "📋 Command output:"
      echo "$test_output" | head -20
    fi
  else
    if [ $test_exit -eq 124 ]; then
      echo "❌ CRITICAL: Test conversion timed out after 30 seconds"
      echo "❌ This indicates the macro is not working or hanging"
      echo ""
      echo "🔍 DETAILED DEBUGGING INFORMATION:"
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      
      echo "📦 Extension Status:"
      shared_ext=$(unopkg list --shared 2>/dev/null | grep -i docexport | wc -l)
      echo "   - Shared extensions: $shared_ext"
      if [ $shared_ext -gt 1 ]; then
        echo "   ⚠️  PROBLEM: Multiple extensions detected!"
        echo "   📋 All DocExport extensions:"
        unopkg list --shared 2>/dev/null | grep -B 1 -A 3 -i docexport | sed 's/^/      /'
      fi
      
      echo "🖥️  System Information:"
      echo "   - LibreOffice: $(soffice --version)"
      echo "   - User: $(whoami) (UID: $(id -u))"
      echo "   - Working directory: $(pwd)"
      
      echo "📄 Test File:"
      echo "   - Name: $first_odt"
      echo "   - Size: $(stat -c%s "$first_odt") bytes"
      echo "   - Readable: $([ -r "$first_odt" ] && echo 'yes' || echo 'no')"
      
      echo "🔍 LibreOffice Processes:"
      if pgrep -af soffice >/dev/null 2>&1; then
        pgrep -af soffice | sed 's/^/   /'
      else
        echo "   - No soffice processes running"
      fi
      
      echo "📋 Command Output (if any):"
      if [ -n "$test_output" ]; then
        echo "$test_output" | sed 's/^/   /'
      else
        echo "   - No output captured"
      fi
      
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo "❌ ABORTING: Cannot proceed with hanging macro"
      echo "💡 Possible causes:"
      echo "   1. Multiple extension installations causing conflicts"
      echo "   2. Macro path incorrect or macro not accessible"
      echo "   3. LibreOffice unable to execute macros in headless mode"
      echo "   4. Extension not properly registered"
      
      pkill -9 -f soffice 2>/dev/null || true
      cd "$OLDPWD" || exit 1
      rm -rf "$temp_odt_dir"
      exit 1
    else
      echo "⚠️  Test conversion returned exit code: $test_exit"
      if [ -n "$test_output" ]; then
        echo "📋 Command output:"
        echo "$test_output" | head -20
      fi
    fi
  fi
  
  sleep 2
  test_md="${first_odt%.odt}.md"
  if [[ -f "$test_md" ]]; then
    test_size=$(stat -c%s "$test_md" 2>/dev/null || echo '0')
    echo "✅ Test conversion successful: $test_md created ($test_size bytes)"
    echo "✓ Macro is working, proceeding with all files..."
  else
    echo "❌ WARNING: Test conversion did not create markdown file"
    echo "🔍 Files in directory:"
    ls -lh | head -10
    echo "⚠️  Proceeding anyway, but conversions may fail..."
  fi
  echo ""
  
  file_index=0
  for odt_file in *.odt; do
    if [ -f "$odt_file" ]; then
      echo ""
      echo "📄 Processing [$((file_index+1))/${#odt_files[@]}]: $odt_file"
      
      # Clean up any lingering LibreOffice processes
      echo "🧹 Cleaning up LibreOffice processes..."
      pkill -f soffice 2>/dev/null || true
      sleep 1
      
      # Verify no processes remain
      if pgrep -f soffice >/dev/null 2>&1; then
        echo "⚠️  WARNING: LibreOffice processes still running after pkill"
        pgrep -af soffice || true
      else
        echo "✓ No LibreOffice processes running"
      fi
      
      # Run conversion macro with timeout
      echo "🔄 Running conversion macro (60s timeout)..."
      echo "   Command: soffice --headless --invisible --nologo --norestore \"$odt_file\" 'macro:///DocExport.DocModel.MakeDocHfmView'"
      
      if timeout 60 soffice --headless --invisible --nologo --norestore "$odt_file" 'macro:///DocExport.DocModel.MakeDocHfmView' 2>&1; then
        echo "✓ Macro execution completed"
      else
        exit_code=$?
        if [ $exit_code -eq 124 ]; then
          echo "❌ ERROR: Macro execution timed out after 60 seconds"
          echo "🔍 Checking for hung processes..."
          pgrep -af soffice || echo "No soffice processes found"
          pkill -9 -f soffice 2>/dev/null || true
          failed_files_list="$failed_files_list ${original_file_map[$file_index]}"
          ((failed_count++))
          ((file_index++))
          continue
        else
          echo "⚠️  Macro execution returned exit code: $exit_code (may be normal)"
        fi
      fi
      
      # Wait for file system to settle
      echo "⏳ Waiting for file system to settle..."
      sleep 5
      
      # Check if conversion produced output immediately
      echo "🔍 Checking for conversion output..."
      if ls -lh "${odt_file%.odt}.md" 2>/dev/null; then
        echo "✓ Output file detected"
      else
        echo "⚠️  No .md file found yet"
      fi
      
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