#!/bin/bash

echo "=== TESTING END-TO-END CONVERSION ==="
cd /tmp

echo "1. Files available:"
ls -la *.fodt *.py

echo "2. Converting FODT to Markdown..."
soffice --headless --invisible --nologo --norestore "macro:///DocExport.DocModel.ExportDir(\"/tmp\",1)"
sleep 5

echo "3. Checking conversion results..."
ls -la *.md

if [ -f "US.ECO.00016-01_90.md" ]; then
    echo "✓ Markdown file created successfully"
    
    echo "4. Adding enhanced metadata..."
    python3 create_metadata.py "US.ECO.00016-01_90.md" "https://github.com" "peerf-eco/EcoDocs" "test123"
    
    echo "5. Final results:"
    ls -la *.md
    
    echo ""
    echo "Generated frontmatter and content:"
    head -40 *.md
else
    echo "❌ Conversion failed - no markdown file created"
    echo "Available files:"
    ls -la
fi

echo "=== END-TO-END TEST COMPLETE ==="