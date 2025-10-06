#!/bin/bash

echo "=== TESTING PRODUCTION WORKFLOW LOCALLY ==="
cd /tmp
rm -rf production_test
mkdir -p production_test
cd production_test

echo "1. Creating multiple test ODT files (simulating production)..."
echo "Test document 1 with some content" > doc1.txt
echo "Test document 2 with more detailed content and multiple lines
This is line 2 of document 2
And this is line 3" > doc2.txt  
echo "Test document 3 final version" > doc3.txt
echo "Document 4 with special characters: àáâãäå" > doc4.txt
echo "Document 5 short" > doc5.txt

# Convert to ODT
soffice --headless --convert-to odt doc1.txt
soffice --headless --convert-to odt doc2.txt
soffice --headless --convert-to odt doc3.txt
soffice --headless --convert-to odt doc4.txt
soffice --headless --convert-to odt doc5.txt

echo "Created ODT files:"
ls -la *.odt

echo ""
echo "2. FAST-FAIL TEST (like production)..."
first_odt=$(ls *.odt | head -1)
echo "   Test file: $first_odt ($(stat -c%s "$first_odt") bytes)"

# Aggressive process cleanup (like production)
pkill -9 -f soffice 2>/dev/null || true
sleep 2

echo "   Running test conversion using ExportDir macro..."

# Create single-file directory for test (same as production)
test_single_dir=$(mktemp -d)
cp "$first_odt" "$test_single_dir/"
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
  echo "❌ Test conversion failed with exit code: $test_exit"
fi

sleep 2
test_base_name=$(basename "$first_odt" .odt)
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

echo "3. MAIN CONVERSION LOOP (like production)..."
converted_count=0
failed_count=0
processed_files_list=""
failed_files_list=""

file_index=0
for odt_file in *.odt; do
  if [ -f "$odt_file" ]; then
    echo ""
    echo "📄 Processing [$((file_index+1))/5]: $odt_file"
    
    # Clean up any lingering LibreOffice processes (like production)
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
    cp "$odt_file" "$single_dir/"
    
    echo "   Processing: $odt_file"
    pkill -f soffice 2>/dev/null
    sleep 1
    soffice --headless --invisible --nologo --norestore "macro:///DocExport.DocModel.ExportDir(\"$single_dir\",1)"
    sleep 5
    echo "   Completed: $odt_file"
    
    # Move results back
    base_name=$(basename "$odt_file" .odt)
    if [ -f "$single_dir/${base_name}.md" ]; then
      mv "$single_dir/${base_name}.md" "./"
      echo "✓ Markdown file retrieved"
    else
      echo "❌ ERROR: No markdown file created"
      failed_files_list="$failed_files_list $odt_file"
      ((failed_count++))
      rm -rf "$single_dir"
      ((file_index++))
      echo "🔄 Continuing to next file..."
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
    if ls -lh "${odt_file%.odt}.md" 2>/dev/null; then
      echo "✓ Output file detected"
    else
      echo "⚠️  No .md file found yet"
    fi
    
    base_name=$(basename "$odt_file" .odt)
    md_file="${base_name}.md"
    
    # Check if markdown file was created
    if [[ -f "$md_file" ]]; then
      md_size=$(stat -c%s "$md_file" 2>/dev/null || echo '0')
      echo "✓ Markdown file created: $md_file ($md_size bytes)"
      
      if [[ $md_size -eq 0 ]]; then
        echo "❌ ERROR: Generated markdown file is empty"
        failed_files_list="$failed_files_list $odt_file"
        ((failed_count++))
      else
        echo "✅ SUCCESS: $odt_file → $md_file ($md_size bytes)"
        ((converted_count++))
        processed_files_list="$processed_files_list $odt_file"
      fi
    else
      echo "❌ ERROR: Markdown file not created: $md_file"
      echo "🔍 Files in temp directory:"
      ls -la | head -10
      failed_files_list="$failed_files_list $odt_file"
      ((failed_count++))
    fi
    
    ((file_index++))
    echo "🔄 Continuing to next file..."
  fi
done

echo ""
echo "🏁 Completed processing all ODT files in directory"

echo ""
echo "4. FINAL RESULTS:"
echo "📊 Conversion Statistics:"
total_files=5
echo "   Input files processed: $total_files"
echo "   Successfully converted: $converted_count"
echo "   Failed conversions: $failed_count"
echo "   Success rate: $(( converted_count * 100 / total_files ))%"

echo ""
echo "📄 Generated files:"
ls -la *.md 2>/dev/null || echo "No .md files found"

echo ""
echo "📁 Image folders:"
ls -la img_* 2>/dev/null || echo "No image folders found"

echo ""
echo "📋 Processed files: $processed_files_list"
echo "❌ Failed files: $failed_files_list"

echo ""
echo "5. CONTENT CHECK:"
for md in *.md; do
  if [ -f "$md" ]; then
    echo "=== $md ($(stat -c%s "$md") bytes) ==="
    head -3 "$md"
    echo ""
  fi
done

echo ""
echo "6. FINAL PROCESS CHECK:"
final_procs=$(pgrep -f soffice 2>/dev/null | wc -l)
echo "LibreOffice processes remaining: $final_procs"
if [ $final_procs -gt 0 ]; then
  pgrep -af soffice
fi

# Final cleanup
pkill -f soffice 2>/dev/null || true

echo ""
if [[ $converted_count -eq 0 ]]; then
  echo "❌ RESULT: No files were successfully converted. Test failed."
  echo "=== PRODUCTION WORKFLOW TEST FAILED ==="
  exit 1
fi

echo "✅ RESULT: Successfully converted $converted_count out of $total_files files"
echo "=== PRODUCTION WORKFLOW TEST COMPLETE ==="