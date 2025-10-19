#!/bin/bash

echo "=== TESTING END-TO-END CONVERSION WITH REAL FODT FILE ==="
cd /tmp
rm -rf e2e_test
mkdir -p e2e_test
cd e2e_test

echo "1. Copying real FODT file..."
cp /workspace/components/0000000000000000000000004D656D31/US.ECO.00016-01_90.fodt ./

echo "2. Converting FODT to Markdown..."
soffice --headless --invisible --nologo --norestore "macro:///DocExport.DocModel.ExportDir(\"$(pwd)\",1)"
sleep 5

echo "3. Checking conversion results..."
ls -la *.md

if [ -f "US.ECO.00016-01_90.md" ]; then
    echo "✓ Markdown file created successfully"
    
    echo "4. Adding enhanced metadata..."
    cp /workspace/.github/workflows/create_metadata.py ./
    
    python3 create_metadata.py "US.ECO.00016-01_90.md" "https://github.com" "peerf-eco/EcoDocs" "test123"
    
    echo "5. Showing results..."
    echo "Files created:"
    ls -la *.md
    
    echo ""
    echo "Generated frontmatter:"
    for md_file in *.md; do
        if [ -f "$md_file" ]; then
            echo "=== $md_file ==="
            head -30 "$md_file"
            echo ""
        fi
    done
else
    echo "❌ Conversion failed - no markdown file created"
fi

echo "=== END-TO-END TEST COMPLETE ==="