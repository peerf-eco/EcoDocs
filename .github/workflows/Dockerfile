FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    libreoffice \
    python3 \
    python3-pip \
    git \
    openssh-client \
    && rm -rf /var/lib/apt/lists/*

# Install Python packages
RUN pip3 install frontmatter

# Copy and install DocExport extension
COPY DocExport.oxt /tmp/DocExport.oxt
RUN unopkg add --shared /tmp/DocExport.oxt
RUN unopkg add /tmp/DocExport.oxt
RUN rm /tmp/DocExport.oxt

# Verify LibreOffice installation and extension
RUN soffice --version
RUN unopkg list --shared | grep -i docexport
RUN unopkg list | grep -i docexport

# Set working directory
WORKDIR /workspace