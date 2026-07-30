#!/bin/bash
set -uo pipefail

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
# phase1_failed_count=0  # COMMENTED: No longer needed for direct conversion
converted_count=0
failed_count=0
source_files=()
original_file_map=()
processed_files_list=""
failed_files_list=""

# COMMENTED OUT: FODT TO ODT CONVERSION PHASE
# This phase is no longer needed as LibreOffice macro can handle both .fodt and .odt files directly
# echo "=== PHASE 1: FODT TO ODT CONVERSION ==="
# for file in "$@"; do
#   echo "📄 Processing input file: $file"
#   
#   if [[ ! -f "$file" ]]; then
#     echo "❌ ERROR: File not found: $file"
#     failed_files_list="$failed_files_list $file"
#     ((phase1_failed_count++))
#     continue
#   fi
#   
#   file_size=$(stat -c%s "$file" 2>/dev/null || echo '0')
#   echo "   File size: $file_size bytes"
#   
#   if [[ $file_size -eq 0 ]]; then
#     echo "❌ ERROR: File is empty (0 bytes): $file"
#     failed_files_list="$failed_files_list $file"
#     ((phase1_failed_count++))
#     continue
#   fi
#   
#   base="${file%.*}"
#   filename="${base##*/}"
#   
#   if [[ "$file" == *.fodt ]]; then
#     echo "🔄 Converting FODT to ODT: $file"
#     temp_odt="$temp_odt_dir/${filename}.odt"
#     
#     if soffice --headless --convert-to odt:"writer8" "$file" --outdir "$temp_odt_dir" 2>&1; then
#       if [[ -f "$temp_odt" ]]; then
#         odt_size=$(stat -c%s "$temp_odt" 2>/dev/null || echo '0')
#         echo "✓ Successfully converted FODT to ODT: ${filename}.odt ($odt_size bytes)"
#         odt_files+=("${filename}.odt")
#         original_file_map+=("$file")
#       else
#         echo "❌ ERROR: ODT file not created: $temp_odt"
#         failed_files_list="$failed_files_list $file"
#         ((phase1_failed_count++))
#       fi
#     else
#       echo "❌ ERROR: Failed to convert FODT to ODT: $file"
#       failed_files_list="$failed_files_list $file"
#       ((phase1_failed_count++))
#     fi
#   elif [[ "$file" == *.odt ]]; then
#     temp_odt="$temp_odt_dir/${filename}.odt"
#     if cp "$file" "$temp_odt"; then
#       echo "✓ Copied ODT file to temp directory: ${filename}.odt"
#       odt_files+=("${filename}.odt")
#       original_file_map+=("$file")
#     else
#       echo "❌ ERROR: Failed to copy ODT file: $file"
#       failed_files_list="$failed_files_list $file"
#       ((phase1_failed_count++))
#     fi
#   else
#     echo "⚠️  WARNING: Unsupported file type: $file"
#     failed_files_list="$failed_files_list $file"
#     ((phase1_failed_count++))
#   fi
# done
# echo "📊 Phase 1 Summary: ${#odt_files[@]} ODT files ready, $phase1_failed_count files failed"

# NEW: Direct file validation and preparation
echo "=== PHASE 1: FILE VALIDATION AND PREPARATION ==="
for file in "$@"; do
  echo "📄 Processing input file: $file"
  
  if [[ ! -f "$file" ]]; then
    echo "❌ ERROR: File not found: $file"
    failed_files_list="$failed_files_list $file"
    ((failed_count++))
    continue
  fi
  
  file_size=$(stat -c%s "$file" 2>/dev/null || echo '0')
  echo "   File size: $file_size bytes"
  
  if [[ $file_size -eq 0 ]]; then
    echo "❌ ERROR: File is empty (0 bytes): $file"
    failed_files_list="$failed_files_list $file"
    ((failed_count++))
    continue
  fi
  
  if [[ "$file" == *.fodt || "$file" == *.odt ]]; then
    echo "✓ Valid source file: $file"
    source_files+=("$file")
    original_file_map+=("$file")
  else
    echo "⚠️  WARNING: Unsupported file type: $file"
    failed_files_list="$failed_files_list $file"
    ((failed_count++))
  fi
done

echo "📊 Phase 1 Summary: ${#source_files[@]} source files ready for direct conversion"

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

# Convert source files to Markdown directly
if [[ ${#source_files[@]} -gt 0 ]]; then
  echo "=== PHASE 2: DIRECT SOURCE TO MARKDOWN CONVERSION ==="
  echo "Converting ${#source_files[@]} source files (.fodt/.odt) directly to markdown..."
  
  # Set proper locale and encoding for LibreOffice to handle Cyrillic text
  export LC_ALL=C.UTF-8
  export LANG=C.UTF-8
  export LANGUAGE=C.UTF-8
  echo "✓ Set UTF-8 locale for LibreOffice"
  
  # Fast-fail test: Try converting first file with short timeout
  echo ""
  echo "🧪 FAST-FAIL TEST: Testing macro on first file..."
  first_file="${source_files[0]}"
  echo "   Test file: $first_file ($(stat -c%s "$first_file") bytes)"
  
  # Aggressive process cleanup
  pkill -9 -f soffice 2>/dev/null || true
  sleep 2
  
  echo "   Running test conversion using ExportDir macro..."
  
  # Create single-file directory for test (same as main loop)
  test_single_dir=$(mktemp -d)
  cp "$first_file" "$test_single_dir/"
  echo "   Test directory: $test_single_dir"
  echo "   Command: soffice --headless --invisible --nologo --norestore 'macro:///DocExport.DocModel.ExportDir(\"$test_single_dir\",1)'"
  
  # Use exact timing pattern that works
  pkill -9 -f soffice 2>/dev/null || true
  sleep 2
  soffice --headless --invisible --nologo --norestore "macro:///DocExport.DocModel.ExportDir(\"$test_single_dir\",1)" 2>&1 &
  soffice_pid=$!
  sleep 5
  
  # Check if process completed
  if kill -0 $soffice_pid 2>/dev/null; then
    echo "   Process still running after 5 seconds, killing..."
    kill $soffice_pid 2>/dev/null || true
    test_exit=124
  else
    wait $soffice_pid
    test_exit=$?
  fi
  
  if [ ${test_exit:-0} -eq 0 ]; then
    echo "✓ Test conversion command completed"
  else
    if [ $test_exit -eq 124 ]; then
      echo "❌ CRITICAL: Test conversion timed out after 30 seconds"
      echo "❌ This indicates the macro is not working or hanging"
      echo ""
      echo "🔍 DETAILED DEBUGGING INFORMATION:"
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      
      echo "📦 Extension Status:"
      shared_ext=$(unopkg list --shared 2>/dev/null | grep "^Identifier:" | grep -i docexport | wc -l)
      echo "   - Shared extension packages: $shared_ext"
      if [ $shared_ext -gt 1 ]; then
        echo "   ⚠️  PROBLEM: Multiple extension packages detected!"
        echo "   📋 All DocExport identifiers:"
        unopkg list --shared 2>/dev/null | grep "^Identifier:" | grep -i docexport | sed 's/^/      /'
      fi
      
      echo "🖥️  System Information:"
      echo "   - LibreOffice: $(soffice --version)"
      echo "   - User: $(whoami) (UID: $(id -u))"
      echo "   - Working directory: $(pwd)"
      
      echo "📄 Test File:"
      echo "   - Name: $first_file"
      echo "   - Size: $(stat -c%s "$first_file") bytes"
      echo "   - Readable: $([ -r "$first_file" ] && echo 'yes' || echo 'no')"
      
      echo "🔍 LibreOffice Processes:"
      if pgrep -af soffice >/dev/null 2>&1; then
        pgrep -af soffice | sed 's/^/   /'
      else
        echo "   - No soffice processes running"
      fi
      
      echo "📋 Command Output (if any):"
      echo "   - No output captured (using background process)"
      
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo "❌ ABORTING: Cannot proceed with hanging macro"
      echo ""
      echo "💡 DIAGNOSIS:"
      echo "   The macro 'macro:///DocExport.DocModel.ExportDir' is not responding."
      echo "   This indicates a problem with the DocExport extension in headless mode."
      echo ""
      echo "🔧 RECOMMENDATION:"
      echo "   Try rebuilding the container or check extension installation."
      
      pkill -9 -f soffice 2>/dev/null || true
      cd "$OLDPWD" || exit 1
      rm -rf "$temp_odt_dir"
      exit 1
    else
      echo "⚠️  Test conversion returned exit code: $test_exit"
    fi
  fi
  
  sleep 2
  test_base_name=$(basename "$first_file")
  test_base_name="${test_base_name%.*}"  # Remove extension (.fodt or .odt)
  test_md="$test_single_dir/${test_base_name}.md"
  if [[ -f "$test_md" ]]; then
    test_size=$(stat -c%s "$test_md" 2>/dev/null || echo '0')
    echo "✅ Test conversion successful: ${test_base_name}.md created ($test_size bytes)"
    echo "✓ Macro is working, proceeding with all files..."
  else
    echo "❌ WARNING: Test conversion did not create markdown file"
    echo "🔍 Files in test directory:"
    ls -lh "$test_single_dir/" | head -10
    
    # Check conversion log for clues
    if [[ -f "$test_single_dir/conversion.log" ]]; then
      echo "📋 Conversion log contents:"
      head -10 "$test_single_dir/conversion.log" | sed 's/^/   /'
    fi
    
    echo "⚠️  Proceeding anyway, but conversions may fail..."
  fi
  
  # Cleanup test directory
  rm -rf "$test_single_dir"
  echo ""
  
  file_index=0
  for source_file in "${source_files[@]}"; do
    echo ""
    echo "📄 Processing [$((file_index+1))/${#source_files[@]}]: $source_file"
      
      # Clean up any lingering LibreOffice processes
      echo "🧹 Cleaning up LibreOffice processes..."
      
      # Check for existing processes
      existing_procs=$(pgrep -f soffice 2>/dev/null | wc -l)
      if [ $existing_procs -gt 0 ]; then
        echo "   Found $existing_procs soffice process(es) running"
        pgrep -af soffice | sed 's/^/   - /'
        
        # Kill processes
        echo "   Sending TERM signal..."
        pkill -f soffice 2>/dev/null || true
        sleep 1
        
        # Check if processes are gone
        remaining=$(pgrep -f soffice 2>/dev/null | wc -l)
        if [ $remaining -gt 0 ]; then
          echo "   ⚠️  $remaining process(es) still running, sending KILL signal..."
          pkill -9 -f soffice 2>/dev/null || true
          sleep 1
          
          # Final check
          final_check=$(pgrep -f soffice 2>/dev/null | wc -l)
          if [ $final_check -gt 0 ]; then
            echo "   ⚠️  WARNING: $final_check process(es) still running (non-critical)"
            pgrep -af soffice | sed 's/^/   - /'
          else
            echo "   ✓ All processes killed"
          fi
        else
          echo "   ✓ All processes terminated"
        fi
      else
        echo "   ✓ No LibreOffice processes running"
      fi
      
      # Run conversion using ExportDir macro with exact timing from tested pattern
      echo "🔄 Running conversion macro..."
      
      # Create single-file directory for ExportDir
      single_dir=$(mktemp -d)
      cp "$source_file" "$single_dir/"
      
      echo "   Processing: $source_file"
      pkill -9 -f soffice 2>/dev/null || true
      sleep 2
      soffice --headless --invisible --nologo --norestore "macro:///DocExport.DocModel.ExportDir(\"$single_dir\",1)"
      sleep 5
      echo "   Completed: $source_file"
      
      # Move results back
      base_name=$(basename "$source_file")
      base_name="${base_name%.*}"  # Remove extension (.fodt or .odt)
      if [ -f "$single_dir/${base_name}.md" ]; then
        mv "$single_dir/${base_name}.md" "./"
        echo "✓ Markdown file retrieved"
      else
        echo "❌ ERROR: No markdown file created"
        failed_files_list="$failed_files_list ${original_file_map[$file_index]}"
        ((failed_count++))
        rm -rf "$single_dir"
        ((file_index++))
        continue
      fi
      
      if [ -d "$single_dir/img_${base_name}" ]; then
        mv "$single_dir/img_${base_name}" "./"
        echo "✓ Image folder retrieved"
      fi
      
      rm -rf "$single_dir"
      
      # Wait for file system to settle
      echo "⏳ Waiting for file system to settle..."
      sleep 5
      
      # Check if conversion produced output immediately
      echo "🔍 Checking for conversion output..."
      md_file="${base_name}.md"
      if ls -lh "$md_file" 2>/dev/null; then
        echo "✓ Output file detected"
      else
        echo "⚠️  No .md file found yet"
      fi
      
      original_file="$source_file"
      
      # Detect language from filename prefix
      lang_code="en"  # Default to English
      if [[ "$base_name" =~ ^RU[._-] ]]; then
        lang_code="ru"
      elif [[ "$base_name" =~ ^(US|EN)[._-] ]]; then
        lang_code="en"
      elif [[ "$base_name" =~ ^FR[._-] ]]; then
        lang_code="fr"
      elif [[ "$base_name" =~ ^DE[._-] ]]; then
        lang_code="de"
      fi
      echo "🌐 Detected language: $lang_code (from filename: $base_name)"
      
      # Determine output path based on original source location and language
      if [[ "$original_file" == components/* ]]; then
        # Flatten components structure - all files go to docs/{lang}/components
        mkdir -p "$PWD/converted_docs/$lang_code/components"
        output_file="$PWD/converted_docs/$lang_code/components/${base_name}.md"
        img_output_dir="$PWD/converted_docs/$lang_code/components"
      elif [[ "$original_file" == libraries/* ]]; then
        # Extract relative path within libraries directory
        rel_path="${original_file#libraries/}"
        rel_dir="$(dirname "$rel_path")"
        if [ "$rel_dir" != "." ]; then
          mkdir -p "$PWD/converted_docs/$lang_code/libraries/$rel_dir"
          output_file="$PWD/converted_docs/$lang_code/libraries/$rel_dir/${base_name}.md"
          img_output_dir="$PWD/converted_docs/$lang_code/libraries/$rel_dir"
        else
          mkdir -p "$PWD/converted_docs/$lang_code/libraries"
          output_file="$PWD/converted_docs/$lang_code/libraries/${base_name}.md"
          img_output_dir="$PWD/converted_docs/$lang_code/libraries"
        fi
      elif [[ "$original_file" == guides/* ]]; then
        # Extract relative path within guides directory, stripping language prefix
        rel_path="${original_file#guides/}"
        rel_path="${rel_path#*/}"
        rel_dir="$(dirname "$rel_path")"
        if [ "$rel_dir" != "." ]; then
          mkdir -p "$PWD/converted_docs/$lang_code/guides/$rel_dir"
          output_file="$PWD/converted_docs/$lang_code/guides/$rel_dir/${base_name}.md"
          img_output_dir="$PWD/converted_docs/$lang_code/guides/$rel_dir"
        else
          mkdir -p "$PWD/converted_docs/$lang_code/guides"
          output_file="$PWD/converted_docs/$lang_code/guides/${base_name}.md"
          img_output_dir="$PWD/converted_docs/$lang_code/guides"
        fi
      elif [[ "$original_file" == getting_started/* ]]; then
        # Extract relative path within getting_started directory, stripping language prefix
        rel_path="${original_file#getting_started/}"
        rel_path="${rel_path#*/}"
        rel_dir="$(dirname "$rel_path")"
        if [ "$rel_dir" != "." ]; then
          mkdir -p "$PWD/converted_docs/$lang_code/getting_started/$rel_dir"
          output_file="$PWD/converted_docs/$lang_code/getting_started/$rel_dir/${base_name}.md"
          img_output_dir="$PWD/converted_docs/$lang_code/getting_started/$rel_dir"
        else
          mkdir -p "$PWD/converted_docs/$lang_code/getting_started"
          output_file="$PWD/converted_docs/$lang_code/getting_started/${base_name}.md"
          img_output_dir="$PWD/converted_docs/$lang_code/getting_started"
        fi
      else
        # Fallback to flat structure for unknown paths
        output_file="$PWD/converted_docs/$lang_code/${base_name}.md"
        img_output_dir="$PWD/converted_docs/$lang_code"
      fi
      
      # Check if markdown file was created
      if [[ -f "$md_file" ]]; then
        md_size=$(stat -c%s "$md_file" 2>/dev/null || echo '0')
        echo "✓ Markdown file created: $md_file ($md_size bytes)"
        
        if [[ $md_size -eq 0 ]]; then
          echo "❌ ERROR: Generated markdown file is empty"
          failed_files_list="$failed_files_list $original_file"
          ((failed_count++))
        else
          # Convert to UTF-8 encoding with LF line endings using Python script
          echo "🔄 Converting encoding and line endings..."
          if python3 "$PWD/.github/workflows/convert_encoding.py" "$md_file" "$output_file"; then
            echo "✓ Successfully converted to UTF-8 with LF line endings: $output_file"
          else
            echo "❌ ERROR: Failed to convert encoding, using fallback copy"
            cp "$md_file" "$output_file" || true
            echo "⚠️  WARNING: File may have encoding/line ending issues"
          fi
          
          # Handle image folder
          img_folder="img_${base_name}"
          if [[ -d "$img_folder" ]]; then
            img_count=$(find "$img_folder" -type f | wc -l)
            echo "📁 Found image folder: $img_folder ($img_count images)"
            if mv "$img_folder" "${img_output_dir}/img_${base_name}"; then
              echo "✓ Moved image folder: ${img_output_dir#$PWD/}/img_${base_name}"
            else
              echo "❌ ERROR: Failed to move image folder"
            fi
          else
            echo "ℹ️  No image folder found (this is normal for text-only documents)"
          fi
          
# Determine source directory type
           source_dir_type="components"
           if [[ "$original_file" == libraries/* ]]; then
             source_dir_type="libraries"
           elif [[ "$original_file" == guides/* ]]; then
             source_dir_type="guides"
           elif [[ "$original_file" == getting_started/* ]]; then
             source_dir_type="getting_started"
           fi
          
          # Clean up excessive symbols before adding metadata
          if [[ -f "$PWD/.github/workflows/clean_markdown.py" ]]; then
            echo "🧹 Cleaning markdown content before metadata..."
            python3 "$PWD/.github/workflows/clean_markdown.py" "$output_file" 2>/dev/null || true
          fi

          # Add metadata using dedicated Python script
          if [[ -f "$PWD/.github/workflows/create_metadata.py" ]]; then
            if [[ -n "${GITHUB_SERVER_URL:-}" && -n "${GITHUB_REPOSITORY:-}" && -n "${GITHUB_SHA:-}" ]]; then
              echo "🔄 Processing metadata (source type: $source_dir_type)..."
              if result_file=$(python3 "$PWD/.github/workflows/create_metadata.py" "$output_file" "${GITHUB_SERVER_URL}" "${GITHUB_REPOSITORY}" "${GITHUB_SHA}" "$original_file" "$source_dir_type" 2>&1); then
                echo "✓ Metadata processing completed"
                echo "   Python script output: $result_file"
                # Update output_file path if file was renamed based on CID (components only)
                if [[ "$source_dir_type" == "components" && "$result_file" =~ "✓ Metadata added to" ]]; then
                  renamed_file=$(echo "$result_file" | sed 's/.*✓ Metadata added to //')
                  original_basename=$(basename "$output_file")
                  if [[ "$renamed_file" != "$original_basename" ]]; then
                    new_output_file="$(dirname "$output_file")/$renamed_file"
                    echo "✓ File renamed based on CID: $original_basename → $renamed_file"
                    output_file="$new_output_file"
                  else
                    echo "ℹ️  No CID found - file kept original name: $original_basename"
                  fi
                fi
              else
                echo "⚠️  WARNING: Failed to add metadata (non-critical): $result_file"
              fi
            else
              echo "ℹ️  Skipping metadata (GitHub environment variables not set)"
            fi
          fi
          
          # Verify final output and encoding
          if [[ -f "$output_file" ]]; then
            final_size=$(stat -c%s "$output_file" 2>/dev/null || echo '0')
            
            # Verify UTF-8 encoding
            if python3 -c "import sys; open('$output_file', 'r', encoding='utf-8').read()" 2>/dev/null; then
              echo "✓ UTF-8 encoding verified"
            else
              echo "⚠️  WARNING: File may not be valid UTF-8"
            fi
            
            # Check line endings (should be LF only)
            crlf_count=$(grep -c $'\r' "$output_file" 2>/dev/null || echo '0')
            if [ "$crlf_count" -eq 0 ] 2>/dev/null; then
              echo "✓ LF line endings verified"
            else
              echo "⚠️  WARNING: Found $crlf_count CRLF sequences (should be LF only)"
            fi
            
            echo "✅ SUCCESS: $original_file → $output_file ($final_size bytes, UTF-8, LF)"
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
        failed_files_list="$failed_files_list $original_file"
        ((failed_count++))
      fi
      
      ((file_index++))
      echo "🔄 Continuing to next file..."
  done
  
  echo "🏁 Completed processing all source files"
else
  echo "⚠️  No source files to convert"
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
echo "   Direct conversion failures: $failed_count"
echo "   Successfully converted: $converted_count"
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