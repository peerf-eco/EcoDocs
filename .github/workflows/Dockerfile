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

# Install DocExport extension (shared only)
RUN unopkg add --shared /tmp/DocExport.oxt && rm /tmp/DocExport.oxt

# Verify LibreOffice and extension
RUN soffice --version
RUN unopkg list --shared | grep -i docexport || (echo "ERROR: Extension not installed" && exit 1)

# Set working directory
WORKDIR /workspace