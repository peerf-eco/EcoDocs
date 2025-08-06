import sys
import frontmatter
def create_meta(file):
    # Load the markdown file with frontmatter
    post = frontmatter.load(file)
    
    # Extract the base name for title and source URL
    base_name = file.split('/')[-1]
    title = base_name.replace('_', ' ').title()
    source_url = f"{sys.argv[1]}/{sys.argv[2]}/blob/{sys.argv[3]}/{file}"
    # Update frontmatter
    post.metadata.update({
        'title': title,
        'layout': 'component',
        'source': source_url
    })
    # Write the updated frontmatter back to the file
    with open(file, 'wb') as f:
        frontmatter.dump(post, f)
if __name__ == "__main__":
    # Expecting filename, github server URL, repository name, and commit SHA as arguments
    if len(sys.argv) != 4:
        print("Usage: create_meta.py <file> <github_server_url> <repository_name> <commit_sha>")
        sys.exit(1)
    create_meta(sys.argv[1])
