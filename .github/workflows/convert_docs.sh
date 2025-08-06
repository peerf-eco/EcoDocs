#!/bin/bash
# Create the output directory if it doesn't exist
mkdir -p converted_docs
# Loop through all changed files and convert them
for file in "$@"; do
  base="${file%.*}"
  pandoc "$file" -f odt -t markdown -o "converted_docs/${base##*/}.md"
  # Call the external Python script to update frontmatter
  python create_metadata.py "converted_docs/${base##*/}.md" "${GITHUB_SERVER_URL}" "${GITHUB_REPOSITORY}" "${GITHUB_SHA}"
done
