#!/usr/bin/env python3
import os
import re
from pathlib import Path

def extract_uspd_from_filename(filename):
    """Extract USPD from filename like RU.ECO.00005-01_90.fodt"""
    match = re.match(r'([A-Z]{2}\.ECO\.\d{5}-\d{2})_\d+', filename)
    return match.group(1) if match else None

def extract_metadata_from_fodt(filepath):
    """Extract USPD, Name, CID, and Description from .fodt file"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read(5000)  # Read first 5KB for metadata
        
        uspd = None
        name = None
        cid = None
        description = None
        
        # Extract USPD
        uspd_match = re.search(r'<text:span[^>]*>USPD:</text:span><text:span[^>]*>\s*([A-Z]{2}\.ECO\.\d{5}-\d{2})', content)
        if uspd_match:
            uspd = uspd_match.group(1)
        
        # Extract Name
        name_match = re.search(r'<text:span[^>]*>Name</text:span><text:span[^>]*>:</text:span><text:span[^>]*>\s*([^<]+)</text:span>', content)
        if name_match:
            name = name_match.group(1).strip()
        
        # Extract CID
        cid_match = re.search(r'<text:span[^>]*>CID</text:span><text:span[^>]*>:</text:span><text:span[^>]*>\s*([A-F0-9]{32})</text:span>', content)
        if cid_match:
            cid = cid_match.group(1)
        
        # Extract Short Description
        desc_match = re.search(r'Short Description[^:]*:</text:span>\s*<text:span[^>]*>\s*([^<]+)</text:span>', content)
        if desc_match:
            description = desc_match.group(1).strip()
        
        # Fallback: extract from filename if not found in content
        if not uspd:
            uspd = extract_uspd_from_filename(os.path.basename(filepath))
        
        return uspd, name, cid, description
    except Exception as e:
        print(f"Error reading {filepath}: {e}")
        return None, None, None, None

def sort_uspd_key(uspd):
    """Create sort key from USPD like RU.ECO.00005-01"""
    match = re.match(r'([A-Z]{2})\.ECO\.(\d{5})-(\d{2})', uspd)
    if match:
        lang, num1, num2 = match.groups()
        return (lang, int(num1), int(num2))
    return (uspd, 0, 0)

def generate_registry():
    """Generate USPD registry from all .fodt files"""
    entries = []
    
    # Scan components, libraries, and guides directories
    for directory in ['components', 'libraries', 'guides']:
        if not os.path.exists(directory):
            continue
        
        for root, dirs, files in os.walk(directory):
            for file in files:
                if file.endswith('.fodt'):
                    filepath = os.path.join(root, file)
                    uspd, name, cid, description = extract_metadata_from_fodt(filepath)
                    
                    if uspd:
                        entries.append({
                            'uspd': uspd,
                            'name': name or 'N/A',
                            'cid': cid or 'N/A',
                            'description': description or 'N/A'
                        })
    
    # Sort entries by USPD
    entries.sort(key=lambda x: sort_uspd_key(x['uspd']))
    
    # Generate markdown content
    lines = ['# ECOOS DOCUMENTS REGISTRY', '', '## Format USPD number : Product\'s Name : Component\'s CID : Short description', '']
    
    for entry in entries:
        line = f"{entry['uspd']} : {entry['name']} : {entry['cid']} : {entry['description']}"
        lines.append(line)
    
    # Write to file
    with open('USPD_REGISTRY.md', 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(lines) + '\n')
    
    print(f"✓ Generated USPD_REGISTRY.md with {len(entries)} entries")

if __name__ == '__main__':
    generate_registry()
