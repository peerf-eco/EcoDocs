#!/usr/bin/env python3
import sys
import os
import re
import glob

def clean_markdown_content(content):
    lines = content.split('\n')
    cleaned_lines = []
    in_code_block = False
    in_table = False

    for line in lines:
        stripped = line.strip()

        if stripped.startswith('```'):
            in_code_block = not in_code_block
            cleaned_lines.append(line)
            continue

        if in_code_block:
            cleaned_lines.append(line)
            continue

        if stripped.startswith('|') and '---' in stripped:
            in_table = True
            cleaned_lines.append(line)
            continue

        if in_table and stripped.startswith('|'):
            cleaned_lines.append(line)
            continue

        if in_table and not stripped.startswith('|'):
            in_table = False

        if in_table:
            cleaned_lines.append(line)
            continue

        cleaned = line

        cleaned = re.sub(r'\*\*\*\*', '**', cleaned)

        cleaned = re.sub(r'\*\* \*\*', '**', cleaned)

        cleaned = re.sub(r'\* \*\s+', '**', cleaned)

        cleaned = re.sub(r' {2,}', ' ', cleaned)

        cleaned = cleaned.rstrip()

        cleaned_lines.append(cleaned)

    result = '\n'.join(cleaned_lines)

    result = re.sub(r'\n{4,}', '\n\n\n', result)

    return result


def process_file(filepath):
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
    except Exception as e:
        print(f"  ❌ Failed to read {filepath}: {e}")
        return False

    original = content
    cleaned = clean_markdown_content(content)

    if cleaned != original:
        try:
            with open(filepath, 'w', encoding='utf-8', newline='\n') as f:
                f.write(cleaned)
            print(f"  ✓ Cleaned: {filepath}")
            return True
        except Exception as e:
            print(f"  ❌ Failed to write {filepath}: {e}")
            return False
    else:
        print(f"  ℹ️  No changes needed: {filepath}")
        return True


def main():
    if len(sys.argv) < 2:
        print("Usage: clean_markdown.py <file_or_directory> [file_or_directory ...]")
        print("  Cleans excessive asterisks and spaces from generated markdown files.")
        print("  Processes single files or all .md files in specified directories.")
        sys.exit(1)

    files_to_process = []

    for path in sys.argv[1:]:
        if os.path.isfile(path):
            files_to_process.append(path)
        elif os.path.isdir(path):
            files_to_process.extend(glob.glob(os.path.join(path, '**', '*.md'), recursive=True))
        else:
            print(f"  ⚠️  Path not found: {path}")

    if not files_to_process:
        print("No markdown files to process.")
        sys.exit(1)

    print(f"=== CLEANING MARKDOWN FILES ===")
    print(f"Found {len(files_to_process)} file(s) to process")

    cleaned_count = 0
    unchanged_count = 0
    failed_count = 0

    for filepath in sorted(files_to_process):
        print(f"Processing: {filepath}")
        if process_file(filepath):
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
            if content.strip():
                cleaned_count += 1
            else:
                unchanged_count += 1
        else:
            failed_count += 1

    print(f"\n=== CLEANUP SUMMARY ===")
    print(f"  Total files: {len(files_to_process)}")
    print(f"  Cleaned: {cleaned_count}")
    print(f"  Unchanged: {unchanged_count}")
    print(f"  Failed: {failed_count}")

    if failed_count > 0:
        sys.exit(1)


if __name__ == "__main__":
    main()