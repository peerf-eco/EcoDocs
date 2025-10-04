#!/bin/bash

echo "=== TESTING NEW APPROACH: ExportDir + Tested Timing ==="
cd /tmp
rm -rf new_approach_test
mkdir -p new_approach_test
cd new_approach_test

echo "1. Creating test ODT files..."
echo "Test content 1" > test1.txt
echo "Test content 2 with more text" > test2.txt  
echo "Test content 3 final" > test3.txt

soffice --headless --convert-to odt test1.txt
soffice --headless --convert-to odt test2.txt
soffice --headless --convert-to odt test3.txt

echo "Created ODT files:"
ls -la *.odt

echo ""
echo "2. Testing new approach (ExportDir + exact timing)..."

file_index=0
for odt_file in *.odt; do
    if [ -f "$odt_file" ]; then
        echo ""
        echo "Processing [$((file_index+1))/3]: $odt_file"
        
        # Create single-file directory for ExportDir
        single_dir=$(mktemp -d)
        cp "$odt_file" "$single_dir/"
        base_name=$(basename "$odt_file" .odt)
        
        echo "  Temp dir: $single_dir"
        echo "  Processing: $odt_file"
        
        # Use exact timing pattern
        pkill -f soffice 2>/dev/null
        sleep 1
        soffice --headless --invisible --nologo --norestore "macro:///DocExport.DocModel.ExportDir(\"$single_dir\",1)"
        sleep 5
        echo "  Completed: $odt_file"
        
        # Check results
        echo "  Files in temp dir:"
        ls -la "$single_dir/"
        
        if [ -f "$single_dir/${base_name}.md" ]; then
            mv "$single_dir/${base_name}.md" "./"
            md_size=$(stat -c%s "${base_name}.md")
            echo "  ✓ Retrieved markdown: ${base_name}.md ($md_size bytes)"
        else
            echo "  ❌ No markdown file created"
        fi
        
        if [ -d "$single_dir/img_${base_name}" ]; then
            mv "$single_dir/img_${base_name}" "./"
            echo "  ✓ Retrieved image folder: img_${base_name}"
        else
            echo "  ℹ️  No image folder found"
        fi
        
        rm -rf "$single_dir"
        ((file_index++))
        
        # Check processes
        procs=$(pgrep -f soffice 2>/dev/null | wc -l)
        echo "  LibreOffice processes: $procs"
    fi
done

echo ""
echo "3. Final results:"
echo "Markdown files:"
ls -la *.md 2>/dev/null || echo "No .md files found"

echo ""
echo "Content check:"
for md in *.md; do
    if [ -f "$md" ]; then
        echo "=== $md ($(stat -c%s "$md") bytes) ==="
        head -2 "$md"
        echo ""
    fi
done

echo "Final process check:"
pgrep -af soffice || echo "No soffice processes running"

echo ""
echo "=== NEW APPROACH TEST COMPLETE ==="