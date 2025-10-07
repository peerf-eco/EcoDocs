#!/usr/bin/env python3
import sys
import os
import re

def create_meta(file_path, github_server_url, repository_name, commit_sha):
    """Add VitePress-compatible frontmatter to markdown file"""
    
    # Read the existing content
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Extract the base name for title
    base_name = os.path.basename(file_path)
    name_without_ext = os.path.splitext(base_name)[0]
    
    # Create a proper title from filename
    # Convert underscores to spaces and handle component naming
    title = name_without_ext.replace('_', ' ').replace('.', ' ')
    # Clean up multiple spaces
    title = re.sub(r'\s+', ' ', title).strip()
    
    # Create source URL (assuming original files are in components/ directory)
    original_filename = name_without_ext + '.fodt'
    # Find the component directory structure
    if 'Eco.' in name_without_ext:
        # Extract component ID for directory structure
        component_match = re.search(r'(Eco\.[^_]+)', name_without_ext)
        if component_match:
            component_name = component_match.group(1)
            relative_path = f"components/{component_name}/{original_filename}"
        else:
            relative_path = f"components/{original_filename}"
    else:
        relative_path = f"components/{original_filename}"
    
    source_url = f"{github_server_url}/{repository_name}/blob/{commit_sha}/{relative_path}"
    
    # Check if frontmatter already exists
    if content.startswith('---\n'):
        # Find the end of existing frontmatter
        end_match = re.search(r'\n---\n', content)
        if end_match:
            # Replace existing frontmatter
            existing_content = content[end_match.end():]
        else:
            existing_content = content
    else:
        existing_content = content
    
    # Create VitePress-compatible frontmatter
    frontmatter = f"""---
title: {title}
layout: doc
source: {source_url}
lastUpdated: true
editLink: true
sidebar: true
---

"""
    
    # Combine frontmatter with content
    final_content = frontmatter + existing_content
    
    # Write back to file with LF line endings
    with open(file_path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(final_content)
    
    return True

if __name__ == "__main__":
    if len(sys.argv) != 5:
        print("Usage: create_metadata.py <file> <github_server_url> <repository_name> <commit_sha>")
        sys.exit(1)
    
    file_path = sys.argv[1]
    github_server_url = sys.argv[2] 
    repository_name = sys.argv[3]
    commit_sha = sys.argv[4]
    
    try:
        create_meta(file_path, github_server_url, repository_name, commit_sha)
        print(f"✓ Metadata added to {os.path.basename(file_path)}")
    except Exception as e:
        print(f"❌ Error adding metadata to {file_path}: {e}")
        sys.exit(1)
