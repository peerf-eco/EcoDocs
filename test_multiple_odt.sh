#!/bin/bash
set -e

echo "=== TESTING MULTIPLE ODT FILES PROCESSING ==="
cd /tmp
rm -rf multi_test
mkdir -p multi_test
cd multi_test

echo "1. Creating multiple test ODT files..."
echo "Test content 1" > test1.txt
echo "Test content 2 with more text" > test2.txt  
echo "Test content 3 final" > test3.txt

soffice --headless --convert-to odt test1.txt
soffice --headless --convert-to odt test2.txt
soffice --headless --convert-to odt test3.txt

echo "Created ODT files:"
ls -la *.odt

echo ""
echo "2. Testing individual file processing (new method)..."
file_index=0
for odt_file in *.odt; do
    if [ -f "$odt_file" ]; then
        echo ""
        echo "Processing [$((file_index+1))/3]: $odt_file"
        
        # Clean processes
        echo "  Cleaning LibreOffice processes..."
        existing=$(pgrep -f soffice 2>/dev/null | wc -l)
        if [ $existing -gt 0 ]; then
            echo "    Found $existing processes, killing..."
            pkill -f soffice 2>/dev/null || true
            sleep 1
        else
            echo "    No processes running"
        fi
        
        # Process single file
        echo "  Running conversion macro..."
        single_dir=$(mktemp -d)
        cp "$odt_file" "$single_dir/"
        
        echo "    Command: soffice --headless --invisible --nologo --norestore \"macro:///DocExport.DocModel.ExportDir($single_dir,1)\""
        
        if timeout 30 soffice --headless --invisible --nologo --norestore "macro:///DocExport.DocModel.ExportDir($single_dir,1)" 2>&1; then
            echo "    ✓ Macro completed"
            
            # Check results
            base_name=$(basename "$odt_file" .odt)
            if [ -f "$single_dir/${base_name}.md" ]; then
                mv "$single_dir/${base_name}.md" "./"
                md_size=$(stat -c%s "${base_name}.md")
                echo "    ✓ Retrieved markdown: ${base_name}.md ($md_size bytes)"
            else
                echo "    ❌ No markdown file created"
                echo "    Files in temp dir:"
                ls -la "$single_dir/"
            fi
            
            if [ -d "$single_dir/img_${base_name}" ]; then
                mv "$single_dir/img_${base_name}" "./"
                echo "    ✓ Retrieved image folder: img_${base_name}"
            else
                echo "    ℹ️  No image folder (normal for simple text)"
            fi
        else
            exit_code=$?
            echo "    ❌ Macro failed with exit code: $exit_code"
        fi
        
        rm -rf "$single_dir"
        ((file_index++))
        
        # Check for hung processes
        remaining=$(pgrep -f soffice 2>/dev/null | wc -l)
        if [ $remaining -gt 0 ]; then
            echo "    ⚠️  $remaining processes still running"
            pgrep -af soffice
        fi
    fi
done

echo ""
echo "3. Final results:"
echo "Markdown files created:"
ls -la *.md 2>/dev/null || echo "No .md files"

echo ""
echo "Image folders created:"
ls -la img_* 2>/dev/null || echo "No image folders"

echo ""
echo "4. Content check:"
for md in *.md; do
    if [ -f "$md" ]; then
        echo "=== $md ==="
        head -5 "$md"
        echo ""
    fi
done

echo ""
echo "5. Process cleanup check:"
final_procs=$(pgrep -f soffice 2>/dev/null | wc -l)
echo "LibreOffice processes remaining: $final_procs"
if [ $final_procs -gt 0 ]; then
    pgrep -af soffice
    pkill -9 -f soffice 2>/dev/null || true
fi

echo ""
echo "=== TEST COMPLETE ==="