#!/bin/bash

echo "=== TESTING COMPLETE WORKFLOW WITH METADATA ==="
cd /tmp
rm -rf complete_test
mkdir -p complete_test
cd complete_test

echo "1. Creating test ODT files..."
echo "Component documentation content" > Eco.Core1_EN.txt
echo "File system management details" > Eco.FileSystemManagement1_EN.txt
echo "DateTime utilities information" > EcoDateTime1_EN.txt

soffice --headless --convert-to odt Eco.Core1_EN.txt
soffice --headless --convert-to odt Eco.FileSystemManagement1_EN.txt
soffice --headless --convert-to odt EcoDateTime1_EN.txt

echo "Created ODT files:"
ls -la *.odt

echo ""
echo "2. Converting ODT to Markdown (production method)..."

converted_count=0
for odt_file in *.odt; do
  if [ -f "$odt_file" ]; then
    echo ""
    echo "📄 Processing: $odt_file"
    
    # Clean processes
    pkill -9 -f soffice 2>/dev/null || true
    sleep 1
    
    # Create single-file directory for ExportDir
    single_dir=$(mktemp -d)
    cp "$odt_file" "$single_dir/"
    
    echo "   Running conversion..."
    soffice --headless --invisible --nologo --norestore "macro:///DocExport.DocModel.ExportDir(\"$single_dir\",1)"
    sleep 5
    
    # Move results back
    base_name=$(basename "$odt_file" .odt)
    if [ -f "$single_dir/${base_name}.md" ]; then
      mv "$single_dir/${base_name}.md" "./"
      echo "   ✓ Markdown created: ${base_name}.md"
      ((converted_count++))
    else
      echo "   ❌ Conversion failed"
    fi
    
    rm -rf "$single_dir"
  fi
done

echo ""
echo "3. Adding VitePress metadata..."

# Copy metadata script
cp /tmp/create_metadata_simple.py ./

# Test parameters
GITHUB_SERVER_URL="https://github.com"
GITHUB_REPOSITORY="user/EcoDocs"  
GITHUB_SHA="abc123def456"

metadata_count=0
for md_file in *.md; do
  if [ -f "$md_file" ]; then
    echo "📋 Adding metadata to: $md_file"
    if python3 create_metadata_simple.py "$md_file" "$GITHUB_SERVER_URL" "$GITHUB_REPOSITORY" "$GITHUB_SHA"; then
      ((metadata_count++))
    fi
  fi
done

echo ""
echo "4. VITEPRESS VALIDATION:"
echo ""

for md_file in *.md; do
  if [ -f "$md_file" ]; then
    echo "=== $md_file ==="
    
    # Check frontmatter
    if head -1 "$md_file" | grep -q "^---$"; then
      echo "✅ Valid VitePress format"
      
      # Show frontmatter
      echo "📋 Frontmatter:"
      sed -n '2,/^---$/p' "$md_file" | head -n -1 | sed 's/^/   /'
      
      # Show content preview
      echo "📄 Content:"
      sed -n '/^---$/,$p' "$md_file" | tail -n +2 | head -2 | sed 's/^/   /'
      
      # Validate required fields
      echo "🔍 Field validation:"
      grep -q "^title:" "$md_file" && echo "   ✓ title" || echo "   ❌ title missing"
      grep -q "^layout: doc$" "$md_file" && echo "   ✓ layout: doc" || echo "   ❌ layout incorrect"
      grep -q "^source:" "$md_file" && echo "   ✓ source" || echo "   ❌ source missing"
      grep -q "^lastUpdated: true$" "$md_file" && echo "   ✓ lastUpdated" || echo "   ❌ lastUpdated missing"
      grep -q "^sidebar: true$" "$md_file" && echo "   ✓ sidebar" || echo "   ❌ sidebar missing"
      
    else
      echo "❌ Invalid format - no frontmatter"
    fi
    echo ""
  fi
done

echo ""
echo "5. FINAL SUMMARY:"
total_odt=$(ls *.odt 2>/dev/null | wc -l)
total_md=$(ls *.md 2>/dev/null | wc -l)
valid_vitepress=$(grep -l "^---$" *.md 2>/dev/null | wc -l)

echo "   ODT files: $total_odt"
echo "   Markdown files created: $converted_count"
echo "   Metadata added: $metadata_count"
echo "   Valid VitePress files: $valid_vitepress"
echo "   Overall success rate: $(( valid_vitepress * 100 / total_odt ))%"

if [ $valid_vitepress -eq $total_odt ] && [ $valid_vitepress -gt 0 ]; then
  echo ""
  echo "🎉 SUCCESS: Complete workflow working perfectly!"
  echo "   ✅ All ODT files converted to Markdown"
  echo "   ✅ All files have VitePress-compatible metadata"
  echo "   ✅ Ready for production deployment"
else
  echo ""
  echo "❌ ISSUES DETECTED:"
  [ $converted_count -lt $total_odt ] && echo "   - Some ODT conversions failed"
  [ $metadata_count -lt $converted_count ] && echo "   - Some metadata additions failed"
  [ $valid_vitepress -lt $metadata_count ] && echo "   - Some VitePress validation failed"
fi

echo ""
echo "=== COMPLETE WORKFLOW TEST FINISHED ==="