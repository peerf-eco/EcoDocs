#!/usr/bin/env python3
import os
import re
from pathlib import Path

def extract_metadata_from_markdown(filepath):
    """Extract USPD, Name, CID, and Description from markdown file"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read(5000)  # Read first 5KB for metadata
        
        uspd = None
        name = None
        cid = None
        description = None
        
        # Extract USPD - look for pattern like "USPD: US.ECO.00023-01"
        uspd_match = re.search(r'USPD:\s*([A-Z]{2}\.ECO\.\d{5}-\d{2})', content)
        if uspd_match:
            uspd = uspd_match.group(1)
        
        # Extract Name - look for pattern like "Name: Eco.COFF1"
        name_match = re.search(r'Name:\s*(.+?)(?:\n|$)', content)
        if name_match:
            name = name_match.group(1).strip()
        
        # Extract CID - look for 32-character hex string after "CID:"
        cid_match = re.search(r'CID:\s*([A-F0-9]{32})', content, re.IGNORECASE)
        if cid_match:
            cid = cid_match.group(1).upper()
        
        # Extract Short Description
        desc_match = re.search(r'Short Description[^:]*:\s*(.+?)(?:\n|$)', content)
        if desc_match:
            description = desc_match.group(1).strip()
        
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
    """Generate USPD registry from target repo + newly converted files"""
    entries_dict = {}
    
    # Read from target repository (all existing files)
    target_dir = 'docs-vitepress/docs'
    if os.path.exists(target_dir):
        for root, dirs, files in os.walk(target_dir):
            for file in files:
                if file.endswith('.md'):
                    filepath = os.path.join(root, file)
                    uspd, name, cid, description = extract_metadata_from_markdown(filepath)
                    if uspd:
                        entries_dict[uspd] = {
                            'uspd': uspd,
                            'name': name or 'N/A',
                            'cid': cid or 'N/A',
                            'description': description or 'N/A'
                        }
    
    # Override with newly converted files (if any)
    if os.path.exists('converted_docs'):
        for root, dirs, files in os.walk('converted_docs'):
            for file in files:
                if file.endswith('.md'):
                    filepath = os.path.join(root, file)
                    uspd, name, cid, description = extract_metadata_from_markdown(filepath)
                    if uspd:
                        entries_dict[uspd] = {
                            'uspd': uspd,
                            'name': name or 'N/A',
                            'cid': cid or 'N/A',
                            'description': description or 'N/A'
                        }
    
    if not entries_dict:
        print("⚠️  No markdown files found")
        return
    
    entries = list(entries_dict.values())
    
    entries.sort(key=lambda x: sort_uspd_key(x['uspd']))
    
    lines = ['# ECOOS DOCUMENTS REGISTRY', '', '## Format USPD number : Product\'s Name : Component\'s CID : Short description', '']
    for entry in entries:
        lines.append(f"{entry['uspd']} : {entry['name']} : {entry['cid']} : {entry['description']}")
    
    with open('USPD_REGISTRY.md', 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(lines) + '\n')
    
    print(f"✓ Generated USPD_REGISTRY.md with {len(entries)} entries")

if __name__ == '__main__':
    generate_registry()
