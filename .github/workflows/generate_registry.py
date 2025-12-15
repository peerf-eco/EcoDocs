#!/usr/bin/env python3
import os
import re
from pathlib import Path

def extract_metadata_from_markdown(filepath):
    """Extract USPD, Name, CID, and Description from markdown frontmatter"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read(3000)
        
        # Extract YAML frontmatter
        fm_match = re.search(r'^---\s*\n(.*?)\n---', content, re.DOTALL)
        if not fm_match:
            return None, None, None, None
        
        frontmatter = fm_match.group(1)
        
        # Extract USPD from documentUspd field
        uspd_match = re.search(r'documentUspd:\s*["\']?([A-Z]{2}\.ECO\.\d{5}-\d{2})', frontmatter)
        uspd = uspd_match.group(1) if uspd_match else None
        
        # Extract Name from componentName field
        name_match = re.search(r'componentName:\s*["\']?([^"\n]+)', frontmatter)
        name = name_match.group(1).strip('"\' ') if name_match else None
        
        # Extract CID
        cid_match = re.search(r'CID:\s*["\']?([A-F0-9]{32})', frontmatter, re.IGNORECASE)
        cid = cid_match.group(1).upper() if cid_match else None
        
        # Extract description
        desc_match = re.search(r'description:\s*["\']?([^"\n]+)', frontmatter)
        description = desc_match.group(1).strip('"\' ') if desc_match else None
        
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
    """Generate USPD registry from target repository with frontmatter"""
    entries_dict = {}
    
    target_dir = 'docs-vitepress/docs'
    if not os.path.exists(target_dir):
        print("⚠️  Target repository not found")
        return
    
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
    
    if not entries_dict:
        print("⚠️  No entries found")
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
