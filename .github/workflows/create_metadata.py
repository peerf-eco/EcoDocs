#!/usr/bin/env python3
import sys
import os
import re
from datetime import datetime

def extract_metadata_field(content, field_name):
    """Extract metadata field value from content"""
    patterns = [
        rf'^\*\*{re.escape(field_name)}:\*\*\s*(.+)$',
        rf'^\*\*{re.escape(field_name)}\*\*:\s*(.+)$',
        rf'^{re.escape(field_name)}:\s*(.+)$',
        rf'^{re.escape(field_name)}\s*:\s*(.+)$'
    ]
    
    for pattern in patterns:
        match = re.search(pattern, content, re.MULTILINE | re.IGNORECASE)
        if match:
            return match.group(1).strip()
    return None

def extract_document_title(content):
    """Extract document title from content, looking for 'title' keyword"""
    # Look for first line containing 'title' (case-insensitive) and extract text after colon
    match = re.search(r'title\s*:\s*(.+)', content, re.IGNORECASE)
    if match:
        return match.group(1).strip()
    
    return None

def determine_document_type(title):
    """Determine document type from title"""
    title_lower = title.lower()
    if any(word in title_lower for word in ['guide', 'tutorial', 'how-to']):
        return 'Guide'
    elif any(word in title_lower for word in ['paper', 'research', 'study']):
        return 'Paper'
    elif any(word in title_lower for word in ['tutorial', 'walkthrough']):
        return 'Tutorial'
    else:
        return 'Specification'

def create_meta(file_path, github_server_url, repository_name, commit_sha, original_source_path=None, source_dir_type='components'):
    """Add VitePress-compatible frontmatter to markdown file"""
    
    # Read the existing content
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Extract the base name for fallback title
    base_name = os.path.basename(file_path)
    name_without_ext = os.path.splitext(base_name)[0]
    
    # Try to extract actual document title from content
    title = extract_document_title(content)
    
    # Fallback to filename-based title if no document title found
    if not title:
        title = name_without_ext.replace('_', ' ').replace('.', ' ')
        title = re.sub(r'\s+', ' ', title).strip()
    
    # Extract metadata fields from content
    uspd = extract_metadata_field(content, 'USPD') or extract_metadata_field(content, 'ЕСПД')
    component_name = extract_metadata_field(content, 'Name')
    short_description = extract_metadata_field(content, 'Short Description (max 300 char.)')
    use_category = extract_metadata_field(content, 'Category')
    component_type = extract_metadata_field(content, 'Type')
    cid = extract_metadata_field(content, 'CID')
    marketplace_id = extract_metadata_field(content, 'Marketplace ID')
    marketplace_url = extract_metadata_field(content, 'Marketplace URL')
    version = extract_metadata_field(content, 'Version')
    modified_date = extract_metadata_field(content, 'Modified Date') or extract_metadata_field(content, '**Modified **Date')
    tags = extract_metadata_field(content, 'tags')
    
    # Determine document type
    document_type = determine_document_type(title)
    
    # Use current date for lastModified
    last_modified = datetime.now().strftime('%Y-%m-%d')
    
    # Create source URL using original source path if provided
    if original_source_path:
        source_url = f"{github_server_url}/{repository_name}/blob/{commit_sha}/{original_source_path}"
    else:
        # Fallback to reconstructed path (legacy behavior)
        original_filename = name_without_ext + '.fodt'
        if 'Eco.' in name_without_ext:
            component_match = re.search(r'(Eco\.[^_]+)', name_without_ext)
            if component_match:
                component_name_from_file = component_match.group(1)
                relative_path = f"components/{component_name_from_file}/{original_filename}"
            else:
                relative_path = f"components/{original_filename}"
        else:
            relative_path = f"components/{original_filename}"
        source_url = f"{github_server_url}/{repository_name}/blob/{commit_sha}/{relative_path}"
    
    # Check if frontmatter already exists
    if content.startswith('---\n'):
        end_match = re.search(r'\n---\n', content)
        if end_match:
            existing_content = content[end_match.end():]
        else:
            existing_content = content
    else:
        existing_content = content
    
    # Build frontmatter with all fields
    frontmatter_lines = ['---']
    frontmatter_lines.append(f'title: "{title}"')
    frontmatter_lines.append('layout: doc')
    
    # Custom EcoOS Component Fields
    frontmatter_lines.append(f'documentType: "{document_type}"')
    
    if uspd:
        frontmatter_lines.append(f'documentUspd: "{uspd}"')
    
    if tags:
        frontmatter_lines.append(f'tags: "{tags}"')
    
    if version:
        frontmatter_lines.append(f'version: "{version}"')
    
    frontmatter_lines.append(f'lastModified: "{last_modified}"')
    
    # Custom ECoOS Component Specific Fields
    if component_name:
        frontmatter_lines.append(f'componentName: "{component_name}"')
    
    if cid:
        frontmatter_lines.append(f'CID: "{cid}"')
    
    if short_description:
        frontmatter_lines.append(f'description: "{short_description}"')
    
    if use_category:
        frontmatter_lines.append(f'useCategory: "{use_category.upper()}"')
    
    if component_type:
        frontmatter_lines.append(f'type: "{component_type.upper()}"')
    
    if marketplace_id:
        frontmatter_lines.append(f'registryId: "{marketplace_id.upper()}"')
    
    if marketplace_url:
        frontmatter_lines.append(f'registryUrl: "{marketplace_url}"')
    
    # Optional VitePress fields
    frontmatter_lines.append(f'source: "{source_url}"')
    frontmatter_lines.append('lastUpdated: true')
    frontmatter_lines.append('editLink: true')
    frontmatter_lines.append('sidebar: true')
    frontmatter_lines.append('---')
    frontmatter_lines.append('')
    
    frontmatter = '\n'.join(frontmatter_lines)
    
    # Combine frontmatter with content
    final_content = frontmatter + existing_content
    
    # Determine output file path based on CID (only for components)
    if cid and source_dir_type == 'components':
        file_dir = os.path.dirname(file_path)
        clean_cid = cid.strip('"').strip("'")
        new_file_path = os.path.join(file_dir, f"{clean_cid}.md")
    else:
        new_file_path = file_path
    
    # Write to the new file with LF line endings
    with open(new_file_path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(final_content)
    
    # Remove original file if renamed
    if new_file_path != file_path and os.path.exists(file_path):
        os.remove(file_path)
    
    return new_file_path

if __name__ == "__main__":
    if len(sys.argv) < 5 or len(sys.argv) > 7:
        print("Usage: create_metadata.py <file> <github_server_url> <repository_name> <commit_sha> [original_source_path] [source_dir_type]")
        sys.exit(1)
    
    file_path = sys.argv[1]
    github_server_url = sys.argv[2] 
    repository_name = sys.argv[3]
    commit_sha = sys.argv[4]
    original_source_path = sys.argv[5] if len(sys.argv) >= 6 else None
    source_dir_type = sys.argv[6] if len(sys.argv) == 7 else 'components'
    
    try:
        result_path = create_meta(file_path, github_server_url, repository_name, commit_sha, original_source_path, source_dir_type)
        print(f"✓ Metadata added to {os.path.basename(result_path)}")
    except Exception as e:
        print(f"❌ Error adding metadata to {file_path}: {e}")
        sys.exit(1)
