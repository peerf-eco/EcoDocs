FROM ubuntu:22.04

# Metadata
LABEL org.opencontainers.image.title="LibreOffice DocExport Container"
LABEL org.opencontainers.image.description="Pre-built container with LibreOffice and DocExport extension for document conversion"
LABEL org.opencontainers.image.source="https://github.com/peerf-eco/EcoDocs"

# Install dependencies
RUN apt-get update && apt-get install -y \
    libreoffice \
    python3 \
    python3-pip \
    git \
    openssh-client \
    && rm -rf /var/lib/apt/lists/*

# Configure SSH for GitHub
RUN mkdir -p /root/.ssh && \
    ssh-keyscan -t rsa,ed25519 github.com >> /root/.ssh/known_hosts && \
    chmod 700 /root/.ssh && \
    chmod 644 /root/.ssh/known_hosts

# Install Python packages and clean pip cache
RUN pip3 install --no-cache-dir frontmatter

# Copy and install DocExport extension
COPY DocExport.oxt /tmp/DocExport.oxt

# Remove any existing DocExport extensions to prevent duplicates
RUN unopkg list --shared 2>/dev/null | grep -i "org.openoffice.legacy.DocExport" | while read -r line; do \
        ext_id=$(echo "$line" | awk '{print $2}'); \
        if [ -n "$ext_id" ]; then \
            echo "Removing existing extension: $ext_id"; \
            unopkg remove --shared "$ext_id" 2>/dev/null || true; \
        fi; \
    done || true

# Install DocExport extension (shared only, no user installation)
RUN unopkg add --shared /tmp/DocExport.oxt && \
    rm /tmp/DocExport.oxt

# Verify LibreOffice installation and extension
RUN soffice --version && \
    echo "Installed extensions:" && \
    unopkg list --shared && \
    echo "DocExport extension check:" && \
    unopkg list --shared | grep -i docexport && \
    ext_count=$(unopkg list --shared | grep -i docexport | wc -l) && \
    echo "Total DocExport extensions: $ext_count" && \
    if [ "$ext_count" -ne 1 ]; then \
        echo "ERROR: Expected 1 extension, found $ext_count"; \
        exit 1; \
    fi

# Set working directory
WORKDIR /workspace