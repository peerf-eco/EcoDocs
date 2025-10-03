# EcoDocs Workflow Documentation

## Current Conversion Workflow

The workflow converts FODT (Flat XML ODT) documentation files in the current repository (which have been changed since previous workflow run) to Markdown using LibreOffice extension DocExport.oxt and syncs them to the target documentation repository.

### Image Folder Handling
When ODT files contain images, the DocExport extension automatically extracts them during conversion:
- **Image Folder Pattern**: `img_` + source ODT filename (e.g., `document.odt` → `img_document/`)
- **Automatic Detection**: Workflow detects image folders and copies them alongside markdown files
- **Target Location**: Image folders are placed in the same directory as their corresponding markdown files in the target repository

#### Filename Dependencies
1. **Image Folder Detection**: Uses markdown filename to construct expected image folder name (`img_` + base filename)
2. **File Processing**: Copies any `.md` files found, regardless of specific names
3. **Image-Markdown Pairing**: Correct pairing requires matching filenames (wrong filename = missing images)
4. **Workflow Robustness**: Missing image folders don't cause failures, just skip image copying
5. **State Tracking**: Tracks source files, not generated markdown filenames
6. **Path Correction**: Automatically handles and corrects legacy image folder naming from macro

### Conversion Process
1. **Pre-built Container**: Uses containerized environment with LibreOffice and DocExport.oxt pre-installed
2. **FODT to ODT**: Source FODT files are converted to ODT format using LibreOffice
3. **ODT to Markdown**: LibreOffice macro `DocExport.DocModel.ExportDir(directory,1)` converts ODT files to Markdown
4. **UTF-8 Encoding**: All generated markdown files are converted to UTF-8 encoding using Python (handles various source encodings like Windows CP1251)
5. **Image Extraction**: Images from ODT files are extracted to folders; workflow handles both correct naming (`img_filename`) and legacy full-path naming
6. **Image Path Correction**: Markdown image references are automatically corrected to use proper relative paths
7. **Sync to Target**: Converted markdown files and their corresponding image folders are pushed to the target documentation repository

### Character Encoding Handling
**Problem**: Source ODT/FODT files may be created on different systems with various text encodings (Windows CP1251, ISO-8859-1, etc.)

**Solution**: Post-conversion UTF-8 normalization
- All markdown files are converted to UTF-8 after LibreOffice export
- Uses Python's built-in encoding detection and conversion
- Handles encoding errors gracefully with `errors='ignore'`
- Ensures GitHub markdown viewer compatibility
- No additional dependencies required (Python3 already in container)

### Image Folder Naming
**Expected Format**: `img_<filename>/` (e.g., `document.odt` → `img_document/`)

**Workflow Compatibility**:
- **Correct Format**: Directly moves `img_filename/` folders without modification
- **Legacy Format**: Detects and renames folders with full path prefixes (e.g., `img_/tmp/tmp.xxx/filename/`)
- **Path Correction**: Automatically fixes markdown image references using `sed` when renaming occurs
- **Backward Compatible**: Works with both old and new DocExport macro versions

**Implementation Details**:
1. First checks for correctly named folder (`img_<basename>`)
2. Falls back to pattern search if not found (`img_*<basename>*`)
3. Renames to correct format and updates markdown paths
4. Logs which path was taken for debugging

## Containerized Environment

### Pre-built Container Benefits
- **Fast Startup**: No LibreOffice installation time (reduces from ~5 minutes to ~30 seconds)
- **Consistent Environment**: Same container image every workflow run
- **Cached Layers**: GitHub Container Registry caches Docker layers
- **Pre-installed Extension**: DocExport.oxt ready to use immediately

### Container Setup Process

#### 1. Build Container Image
The `build-container.yml` workflow creates a pre-built container with:
- Ubuntu 22.04 base image
- LibreOffice pre-installed
- Python 3 and required packages
- DocExport.oxt extension installed (both shared and user contexts)
- Git and SSH client tools

#### 2. Container Registry
- **Registry**: GitHub Container Registry (`ghcr.io`)
- **Image Name**: `ghcr.io/{repository}/libreoffice-docexport:latest`
- **Automatic Rebuild**: Triggers when Dockerfile or DocExport.oxt changes
- **Caching**: Uses GitHub Actions cache for faster builds

#### 3. Main Workflow Integration
- **Container Usage**: Main workflow runs inside pre-built container
- **Authentication**: Uses GitHub token for container registry access
- **Verification**: Quick environment check instead of full installation

### Setting Up Container Build

#### Step 1: Create Container Build Workflow
The `build-container.yml` workflow is triggered:
- Manual workflow dispatch only (prevents unnecessary builds)
- Optimized for GitHub Container Registry with caching

#### Step 2: Initial Container Build
1. **Trigger Build**: Push changes to Dockerfile or run workflow manually
2. **Build Process**: 
   - Installs LibreOffice and dependencies
   - Installs DocExport extension in both shared and user contexts
   - Verifies extension accessibility
   - Pushes to GitHub Container Registry
3. **Build Time**: ~3-5 minutes (one-time setup)

#### Step 3: Use Pre-built Container
1. **Main Workflow**: Automatically uses latest container image
2. **Fast Startup**: Environment ready in ~30 seconds
3. **Consistent Results**: Same environment every run

### Container Configuration

#### Dockerfile Structure
```dockerfile
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
```

#### Extension Installation Strategy
- **Dual Installation**: Extension installed both as shared (`--shared`) and user-level
- **Root Build**: Container builds as root, enabling shared installation
- **User Compatibility**: User-level installation ensures access regardless of runtime user
- **Verification**: Both installation contexts verified during build

### Container Workflow Integration

#### Main Workflow Changes
```yaml
jobs:
  convert-and-sync:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/${{ github.repository }}/libreoffice-docexport:latest
      credentials:
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}
    permissions:
      contents: write
      id-token: write
      packages: read   # For container registry
```

#### Environment Verification
- **Quick Check**: Verifies LibreOffice version and extension availability
- **No Installation**: Skips lengthy installation steps
- **Ready to Use**: Environment immediately ready for conversion

### Troubleshooting Container Issues

#### Container Build Failures
- **Check Dockerfile syntax**: Ensure valid Docker commands
- **Verify DocExport.oxt**: Ensure extension file exists and is valid
- **Registry Permissions**: Verify GitHub token has package write permissions

#### Container Runtime Issues
- **Extension Not Found**: Check both shared and user extension lists
- **Permission Issues**: Verify container runs with appropriate user permissions
- **LibreOffice Failures**: Check if LibreOffice can start in headless mode

#### Container Update Process
1. **Modify Files**: Update Dockerfile or DocExport.oxt
2. **Manual Build**: Trigger container rebuild manually (workflow_dispatch only)
3. **New Image**: Updated image available for next workflow run
4. **Gradual Rollout**: New workflows use updated container automatically

### GitHub CI Container Optimization Tips

#### Build Optimization Strategies
1. **Layer Caching**: 
   - Use `--cache-from type=gha --cache-to type=gha,mode=max` for GitHub Actions cache
   - Order Dockerfile commands from least to most frequently changing
   - Combine related RUN commands to reduce layers

2. **Package Management**:
   - Use `rm -rf /var/lib/apt/lists/*` instead of `apt-get clean` for better cleanup
   - Add `--no-cache-dir` flag to pip installs to prevent cache buildup
   - Combine package installation and cleanup in single RUN command

3. **Image Size Reduction**:
   - Remove temporary files immediately after use
   - Use multi-stage builds if needed for complex setups
   - Avoid installing unnecessary packages or documentation

4. **Security and Metadata**:
   - Add container labels for better organization and tracking
   - Pre-configure SSH known_hosts to avoid runtime setup
   - Use specific package versions for reproducible builds

#### Dockerfile Best Practices Applied
```dockerfile
# Metadata for container identification
LABEL org.opencontainers.image.title="LibreOffice DocExport Container"
LABEL org.opencontainers.image.description="Pre-built container with LibreOffice and DocExport extension"
LABEL org.opencontainers.image.source="https://github.com/peerf-eco/EcoDocs"

# Efficient package installation with cleanup
RUN apt-get update && apt-get install -y \
    libreoffice \
    python3 \
    python3-pip \
    git \
    openssh-client \
    && rm -rf /var/lib/apt/lists/*

# Pre-configure SSH to avoid runtime setup
RUN mkdir -p /root/.ssh && \
    ssh-keyscan -t rsa,ed25519 github.com >> /root/.ssh/known_hosts && \
    chmod 700 /root/.ssh && \
    chmod 644 /root/.ssh/known_hosts

# Optimized Python package installation
RUN pip3 install --no-cache-dir frontmatter

# Extension installation with proper cleanup
COPY DocExport.oxt /tmp/DocExport.oxt
RUN unopkg add --shared /tmp/DocExport.oxt && rm /tmp/DocExport.oxt
```

#### Registry and Caching Configuration
1. **GitHub Container Registry**:
   - Use lowercase repository names: `ghcr.io/owner/repo-name:tag`
   - Leverage GitHub Actions built-in GITHUB_TOKEN for authentication
   - Enable package read permissions for workflow access

2. **Build Triggers**:
   - Manual-only triggers (`workflow_dispatch`)

## Recent Improvements

### Issue #1: UTF-8 Character Encoding (Fixed)
**Problem**: Generated markdown files inherited encoding from source ODT files, causing display issues with non-ASCII characters.

**Solution**: Added Python-based UTF-8 conversion after markdown generation:
```python
python3 -c "import sys; open('output.md','wb').write(open('input.md','rb').read().decode(errors='ignore').encode('utf-8'))"
```
- Portable solution using Python3 (already in Docker image)
- Handles any source encoding automatically
- Graceful error handling for invalid characters
- Applied to both batch and individual conversion paths

### Issue #2: Image Folder Path Correction (Fixed)
**Problem**: DocExport macro created image folders with full temp path prefix (`img_/tmp/tmp.xxx/filename/`) instead of simple name (`img_filename/`).

**Root Cause**: Macro uses full ODT file path to construct image folder name.

**Solution**: Dual-path handling in workflow:
1. **Primary Path**: Check for correctly named folder first (fast, no modification needed)
2. **Fallback Path**: Search for legacy format, rename to correct format, fix markdown paths
3. **Logging Improvements**: 
   - Show only relevant files (`.odt` before conversion, `.md` and `img_*` after)
   - Separate counts for ODT files vs total files (excludes lock files, temp files)
   - Clear indication of which path was taken

**Benefits**:
- Works with updated macro (when fixed to output correct names)
- Maintains backward compatibility with current macro
- No workflow changes needed when macro is updated

### Issue #3: Workflow Summary Corrections (Fixed)
**Problem**: Shell syntax errors and incorrect status reporting in workflow summary.

**Errors Found**:
1. Using `==` instead of `=` in POSIX shell `[ ]` tests (caused "unexpected operator" errors)
2. Reference to non-existent step (`steps.install-libreoffice.outcome`)

**Solution**: 
- Changed all `[ "$var" == "value" ]` to `[ "$var" = "value" ]` (POSIX compliant)
- Removed invalid step reference
- Summary now correctly displays state tracking from `new-state.json`

**Result**: Accurate reporting of:
- Files in scope (from change detection)
- Successful conversions (from state file)
- Failed conversions (from state file)
- Step execution status

## Technical Notes

### Shell Compatibility
- GitHub Actions uses `/bin/sh` (POSIX shell), not bash
- Use `=` for string comparison in `[ ]` tests, not `==`
- Use `[ "$var" = "value" ]` syntax for portability

### File Listing Best Practices
- Filter by file type when counting (`.odt`, `.md`) to avoid including temp files
- Use `find` with `-name` pattern for accurate counts
- List files separately by type for better debugging

### Encoding Tools Available
- `iconv`: Available by default in Ubuntu 22.04 (part of glibc)
- Python3: More portable, already required in container
- Recommendation: Use Python for encoding tasks (better error handling)) prevent unnecessary rebuilds
   - Automatic rebuilds only when Dockerfile or extension files change
   - Version tagging with both `latest` and commit SHA for flexibility

3. **Performance Optimizations**:
   - GitHub Actions cache integration reduces build times
   - Layer reuse across builds when dependencies don't change
   - Parallel builds when multiple architectures needed

#### Troubleshooting Container Optimization Issues
1. **Build Time Issues**:
   - Check cache hit rates in build logs
   - Verify layer ordering for optimal caching
   - Monitor package download times and consider mirrors

2. **Image Size Issues**:
   - Use `docker history` to identify large layers
   - Verify cleanup commands are effective
   - Consider using distroless or alpine base images for smaller footprint

3. **Runtime Performance**:
   - Pre-install and configure all dependencies at build time
   - Avoid runtime package installations
   - Use health checks to verify container readiness

#### Container Security Considerations
1. **Extension Installation**:
   - Install extensions as shared (system-wide) for better security
   - Verify extension integrity during build
   - Use specific extension versions when possible

2. **SSH Configuration**:
   - Pre-configure known hosts to prevent MITM attacks
   - Use proper file permissions for SSH directories
   - Avoid storing private keys in container images

3. **Package Management**:
   - Keep base image updated with security patches
   - Use official package repositories
   - Regularly rebuild containers to include latest updates

## Current Change Detection Logic

### How It Works Now
The workflow uses `tj-actions/changed-files@v41` with `fetch-depth: 2`:
- Fetches only the last 2 commits from Git history
- Compares current commit (HEAD) with previous commit (HEAD~1)
- Only detects files changed between these 2 specific commits

### Problems Identified
1. **Limited Scope**: Only sees changes from the last single commit
2. **No Persistence**: No memory of what was previously converted successfully
3. **Manual Triggers**: Don't work as expected for accumulated changes
4. **No Failure Recovery**: If conversion fails, those changes are lost on next run
5. **Multi-commit Scenarios**: If 5 commits contain changes, only the last commit's changes are processed

## Phase 1 Implementation Details

### Enhanced Logging Features Implemented

#### 1. Git State Debugging
- **Debug Git State** step shows current and previous commit hashes
- Displays git log for context
- Lists available .fodt files in components directory
- Helps diagnose change detection issues
- **Edge cases covered**: Single commit repositories, missing components directory

#### 2. Comprehensive Change Detection Results
- **Process Change Detection Results** step provides detailed analysis:
  - Shows exactly which files were added, modified, or deleted
  - Displays file count with visual indicators (✅ for changes, ℹ️ for no changes)
  - Validates file existence and readability
  - Shows file sizes for context
  - Clear messaging when no changes are detected
  - **Edge cases covered**: Deleted files, empty files (0 bytes), very small files, path filter mismatches, repository commit count

#### 3. Enhanced Conversion Logging
- **Convert to Markdown** step includes:
  - File count confirmation before processing
  - Success/failure status for conversion script
  - Partial results checking on failure
  - Clear error reporting with exit codes
  - **Edge cases covered**: Script execution failures, partial conversion results, missing conversion script

#### 4. Conversion Verification
- **Verify Conversion Results** step provides:
  - Directory contents listing
  - Markdown file count verification
  - File size information for generated files
  - Warning messages for unexpected results
  - Error handling for missing directories
  - **Edge cases covered**: Missing converted_docs directory, no markdown files generated, unexpected file types created

#### 5. Deployment Status Tracking
- **Clone, copy files, and push** step includes:
  - Source and target directory confirmation
  - File-by-file copy status with size information
  - Copy summary with success/failure counts
  - Git status checking before commits
  - Push success/failure confirmation
  - **Edge cases covered**: SSH setup failures, repository clone failures, file copy failures, git push failures, no files to copy

#### 6. No-Changes Handling
- **No Changes Detected** step (runs when no changes found):
  - Clear explanation of why no conversion is needed
  - Troubleshooting guidance for users
  - Path filter information for debugging

#### 7. Workflow Summary
- **Workflow Summary** step (always runs):
  - Execution timestamp and repository information
  - Trigger method identification
  - Processing status summary
  - File count and target repository status
  - Reference to detailed logs

#### 8. LibreOffice Installation Verification
- **Install LibreOffice and extension** step includes:
  - Package update status verification
  - LibreOffice installation confirmation
  - Python dependency installation status
  - DocExport extension file validation
  - Extension installation success/failure
  - LibreOffice version verification
  - **Edge cases covered**: Package update failures, LibreOffice installation failures, missing extension file, extension installation failures, unopkg command failures

#### 9. SSH and Repository Access Validation
- **SSH setup and repository cloning** includes:
  - SSH directory creation verification
  - GitHub host key addition confirmation
  - SSH agent startup validation
  - SSH key addition success/failure
  - Repository clone status with contents preview
  - **Edge cases covered**: SSH directory creation failures, host key failures, SSH agent failures, invalid SSH keys, repository access denied, clone failures

#### 10. Comprehensive Workflow Summary
- **Workflow Summary** step (always runs) provides:
  - Individual step execution outcomes
  - Overall workflow status (success/failure/cancelled)
  - File processing results with conversion and deployment status
  - Troubleshooting guidance for failures
  - **Edge cases covered**: Step failures, workflow cancellation, partial successes, dependency failures

#### 11. Visual Status Indicators
Using emojis for quick status identification:
- ✅ Success/completion
- ❌ Error/failure
- ⚠️ Warning/attention needed
- ℹ️ Information/normal status
- 🔄 Processing/in progress
- 🚀 Deployment/push operations
- 🔍 Debugging/investigation
- 📊 Statistics/metrics
- 📁 Directory/file operations
- 🎯 Target/destination

### Benefits Achieved
1. **Immediate Problem Diagnosis**: Users can quickly identify why workflows succeed or fail
2. **No Silent Failures**: Every step provides clear status and error information
3. **Debugging Support**: Comprehensive information for troubleshooting issues
4. **User-Friendly Messages**: Clear explanations for both technical and non-technical users
5. **Progress Tracking**: Visual indicators show workflow progress and status

## Phase 2 Implementation Details

### State Tracking Features Implemented

#### 1. Persistent State Management
- **Load Conversion State** step loads `.conversion-state.json` from target repository
- Tracks `lastProcessedCommit` to enable multi-commit change detection
- Maintains `successfulFiles` and `failedFiles` collections
- Creates initial state if none exists

#### 2. Enhanced Change Detection
- **State-Based Change Detection** compares against `lastProcessedCommit` instead of just HEAD~1
- Automatically includes previously failed files for retry
- Combines changed files and failed files for comprehensive processing
- Handles repositories with no previous state gracefully

#### 3. File-Level Success/Failure Tracking
- **Individual File Processing** tracks each file's conversion status
- Successful conversions move from `failedFiles` to `successfulFiles`
- Failed conversions increment `attemptCount` and update `lastError`
- Partial failures don't stop the entire workflow

#### 4. State Persistence
- **Update Conversion State** step creates new state after processing
- **State Deployment** copies state file to target repository
- State survives workflow failures and is available for next run
- Includes timestamps, commit hashes, and error details

#### 5. Retry Logic
- Previously failed files automatically included in next run (up to 3 attempts)
- Maximum retry limit prevents infinite retry loops
- Files exceeding retry limit are permanently excluded
- Failed files retain error information for debugging
- Success moves files from failed to successful state
- **Edge cases covered**: Corrupted state files, missing commits, single commit repositories, state validation failures

### State File Structure (Implemented)
```json
{
  "lastProcessedCommit": "abc123...",
  "lastSuccessfulRun": "2024-01-15T10:30:00Z",
  "successfulFiles": {
    "components/path/file1.fodt": {
      "convertedAt": "2024-01-15T10:30:00Z",
      "sourceCommit": "abc123...",
      "sourceHash": "sha256-placeholder"
    }
  },
  "failedFiles": {
    "components/path/file2.fodt": {
      "lastAttempt": "2024-01-15T10:30:00Z",
      "attemptCount": 2,
      "lastError": "conversion failed",
      "sourceCommit": "def456..."
    }
  }
}
```

**Key State Management Rules:**
- `successfulFiles`: Contains **ONLY** files from the most recent successful conversion session
- `failedFiles`: **Cumulative** list of all failed files until they are successfully processed
- `attemptCount`: Tracks retry attempts with maximum limit of 3 attempts
- Files exceeding retry limit are excluded from future processing
- Successful conversion moves files from `failedFiles` to `successfulFiles`

### Benefits Achieved
1. **Complete Coverage**: Processes all changes since last successful conversion
2. **Retry Logic**: Failed files automatically retried on next run
3. **No Lost Work**: Progress saved even if workflow fails partially
4. **Manual Trigger Support**: Works correctly regardless of trigger method
5. **Multi-commit Support**: Handles scenarios with multiple commits containing changes
6. **Failure Recovery**: Individual file failures don't prevent other files from processing

## Implementation Status

### Phase 0: Containerization ✅ IMPLEMENTED
- ✅ Pre-built container with LibreOffice and DocExport extension
- ✅ GitHub Container Registry integration
- ✅ Automatic container rebuilds on changes
- ✅ Fast workflow startup (~30 seconds vs ~5 minutes)
- ✅ Consistent environment across all runs
- ✅ Dual extension installation (shared and user contexts)

### Phase 1: Enhanced Logging ✅ IMPLEMENTED
- ✅ Add explicit file count and names in workflow logs
- ✅ Output clear "no changes made" messages when no changed files are detected
- ✅ Debug output showing which commits are being compared and which files were found as changed
- ✅ Better error reporting for conversion failures
- ✅ Visual indicators (emojis) for different log levels and status messages
- ✅ Comprehensive workflow summary with execution details
- ✅ File-by-file processing status with size information
- ✅ Enhanced error handling with detailed diagnostics

### Phase 2: State Tracking Implementation ✅ IMPLEMENTED
**State File Location:** `.conversion-state.json` in target repository root

**State File Structure:**
```json
{
  "lastProcessedCommit": "abc123...",
  "lastSuccessfulRun": "2024-01-15T10:30:00Z",
  "successfulFiles": {
    "components/path/file1.fodt": {
      "convertedAt": "2024-01-15T10:30:00Z",
      "sourceCommit": "abc123...",
      "sourceHash": "sha256hash..."
    }
  },
  "failedFiles": {
    "components/path/file2.fodt": {
      "lastAttempt": "2024-01-15T10:30:00Z",
      "attemptCount": 2,
      "lastError": "conversion failed",
      "sourceCommit": "def456..."
    }
  }
}
```

**Implemented Workflow Logic:** ✅
1. ✅ Load state from target repo's `.conversion-state.json`
2. ✅ Identify files to process:
   - All files changed since `lastProcessedCommit`
   - All files in `failedFiles` list (retry failed conversions)
3. ✅ Process files and track results individually
4. ✅ Update state:
   - Move successful conversions from `failedFiles` to `successfulFiles`
   - Add new failures to `failedFiles`
   - Update `lastProcessedCommit` to current HEAD
   - Increment `attemptCount` for retry failures
5. ✅ Deploy updated state back to target repository

### Phase 2.5: Individual File Conversion ✅ IMPLEMENTED
**Conversion Strategy: One-by-one Processing**

**Implementation Details:**
- **Removed**: Bulk batch conversion using `ExportDir` macro
- **Implemented**: Individual file conversion loop with process isolation
- **Conversion Method**: `MakeDocHfmView` macro for single ODT files
- **Process Management**: 
  - `pkill -f soffice` before each conversion (clears lingering processes)
  - 1 second sleep after process cleanup
  - 5 second sleep after conversion (allows file system to settle)
- **File Tracking**: Maps original source files to conversion results for accurate state reporting
- **Error Handling**: Individual file failures don't stop processing of remaining files

**Conversion Flow:**
```bash
for odt_file in *.odt; do
  pkill -f soffice 2>/dev/null
  sleep 1
  soffice --headless --invisible --nologo --norestore "$odt_file" 'macro:///DocExport.DocModel.MakeDocHfmView'
  sleep 5
  # Process results and track success/failure
done
```

**Enhanced Logging:**
- Phase 1: FODT→ODT conversion with file size validation
- Phase 2: ODT→Markdown conversion with detailed progress tracking
- File-by-file status: Processing [N/Total], success/failure indicators
- Empty file detection (0 bytes) with error reporting
- Image folder detection and copy status
- Metadata addition status (non-critical failures logged)
- Final statistics: Success rate, file counts, output sizes

**State Tracking Integration:**
- Exports `PROCESSED_FILES` list (successfully converted source files)
- Exports `FAILED_FILES` list (failed source files for retry)
- Environment variables used by `update_state.py` for state file generation
- Accurate tracking enables retry logic and failure recovery

**Edge Cases Handled:**
- Empty input files (0 bytes)
- Missing files (skipped with error)
- Failed FODT→ODT conversions
- Failed ODT→Markdown conversions
- Missing image folders (normal for text-only documents)
- Metadata addition failures (non-critical, logged as warning)
- LibreOffice process cleanup failures (non-blocking)

### Phase 3: Target Repository Deployment ✅ IMPLEMENTED
**Deployment Strategy: Complete Overwrite**

**Current Behavior:**
- **No Diff Calculation**: Workflow does NOT compare new vs existing markdown files
- **Overwrite Strategy**: All generated markdown files copied to target repository
- **Git-Level Detection**: Git determines if content actually changed
- **Commit Only If Changed**: Empty commits prevented by git diff check

**Deployment Flow:**
```bash
# Copy all generated files (overwrites existing)
cp "$src" "$targetDir/"

# Git detects actual changes
git add docs/components/
if ! git diff --staged --quiet; then
  git commit -m "Auto-update docs from ${sha}"
  git push
fi
```

**What IS Tracked:**
- Source file changes (which `.fodt` files changed)
- Conversion success/failure (state tracking)
- Last processed commit (for change detection)

**What is NOT Tracked:**
- Target markdown content hashes
- Incremental markdown updates
- Content differences between old and new markdown
- Manual edits in target repository (will be overwritten)

**Implications:**
- ✅ Simple, predictable behavior
- ✅ Git handles change detection automatically
- ✅ Always ensures target matches source
- ✅ No stale content issues
- ⚠️ Always copies files even if unchanged
- ⚠️ Manual edits in target repo get overwritten
- ⚠️ No detection if conversion output changed for same input

**State File Deployment:**
- `.conversion-state.json` validated before copying
- JSON syntax checked to prevent corruption
- Existing state preserved if new state is invalid
- State file committed alongside markdown files

### Phase 4: Content Verification (PLANNED)
**Proposed Enhancements:**
- Add file hash comparison for target markdown files
- Detect when source files unchanged but conversion output differs
- Handle edge cases like file renames or moves
- Verify target files match expected source content
- Skip copying if markdown content identical (optimization)
- Detect and warn about manual edits in target repository

## Troubleshooting with Enhanced Logging

### Common Scenarios and Log Interpretation

#### Scenario 1: "No changes detected" but files were modified
**Look for these log sections:**
- **Debug Git State**: Check if your files are in the expected location
- **Process Change Detection Results**: Verify the path filter matches your files
- **Additional checks**: Repository commit count, actual vs expected path filters
- **Solution**: Ensure files are in `components/**/*.fodt` path pattern

#### Scenario 2: LibreOffice installation fails
**Look for these log sections:**
- **Install LibreOffice and extension**: Check package update, LibreOffice install, extension setup
- **Specific indicators**: Package list update failures, LibreOffice install errors, missing DocExport.oxt
- **Solution**: Check system dependencies and extension file availability

#### Scenario 3: Conversion script fails
**Look for these log sections:**
- **Convert to Markdown**: Check the exit code and error message
- **Verify Conversion Results**: See if partial files were created
- **Solution**: Check LibreOffice installation and extension loading

#### Scenario 4: SSH/Repository access fails
**Look for these log sections:**
- **Clone, copy files, and push**: Check SSH setup steps and repository clone
- **Specific indicators**: SSH directory creation, host key addition, SSH agent startup, key addition
- **Solution**: Verify SSH key validity and repository permissions

#### Scenario 5: Files converted but not pushed to target repo
**Look for these log sections:**
- **Verify Conversion Results**: Confirm .md files were created
- **Clone, copy files, and push**: Check copy summary and git status
- **Solution**: Verify SSH key permissions and target repository access

#### Scenario 6: Empty or corrupted files detected
**Look for these log sections:**
- **Process Change Detection Results**: Check file size warnings
- **Specific indicators**: "File is empty (0 bytes)" or "File is very small" warnings
- **Solution**: Verify source file integrity and completeness

#### Scenario 7: Manifest generation fails
**Look for these log sections:**
- **Generate and update components manifest**: Check npm installation and script execution
- **Specific indicators**: package.json validation, npm install failures, script execution errors
- **Solution**: Verify package.json exists and contains required scripts

#### Scenario 8: Workflow partially succeeds
**Look for these log sections:**
- **Workflow Summary**: Check individual step outcomes and overall status
- **Specific indicators**: Step-by-step success/failure status, troubleshooting guidance
- **Solution**: Address failed steps individually based on their specific error messages

#### Scenario 9: State tracking issues (Phase 2)
**Look for these log sections:**
- **Load Conversion State**: Check if state file was found and loaded
- **Update Conversion State**: Verify state update completed successfully
- **Specific indicators**: State file size, successful/failed file counts, commit tracking
- **Solution**: Check target repository permissions and state file integrity

#### Scenario 10: Files not retrying after previous failure (Phase 2)
**Look for these log sections:**
- **State-Based Change Detection**: Check if failed files are included
- **Workflow Summary**: Review state summary showing failed file counts
- **Specific indicators**: "Files to process" should include previously failed files
- **Solution**: Verify state file contains failed files and is accessible

#### Scenario 11: State file corruption or validation failures (Phase 2)
**Look for these log sections:**
- **Load Conversion State**: Check for "State file is corrupted" or "State file is empty" warnings
- **Clone, copy files, and push**: Look for "State file validation failed" messages
- **Specific indicators**: State file size of 0 bytes, JSON parsing errors
- **Solution**: Corrupted state files are automatically recreated, but previous failure history is lost

#### Scenario 12: Maximum retry limit exceeded (Phase 2)
**Look for these log sections:**
- **State-Based Change Detection**: Check for "Skipping [file] - exceeded max retries" messages
- **Specific indicators**: Files with attemptCount >= 3 are excluded from processing
- **Solution**: Files exceeding retry limit require manual intervention or workflow modification

#### Scenario 13: Git commit not found or single commit repository (Phase 2)
**Look for these log sections:**
- **State-Based Change Detection**: Check for "Last processed commit not found" or "Single commit repository" messages
- **Specific indicators**: Fallback to HEAD~1 comparison or all .fodt files processing
- **Solution**: Normal behavior for new repositories or when commit history is modified

#### Scenario 14: Individual file conversion failures (Phase 2.5)
**Look for these log sections:**
- **PHASE 2: ODT TO MARKDOWN CONVERSION**: Check per-file processing status
- **Specific indicators**: "ERROR: Markdown file not created", "ERROR: Generated markdown file is empty"
- **Solution**: Check LibreOffice macro execution, verify ODT file integrity, review temp directory contents

#### Scenario 15: Process cleanup issues (Phase 2.5)
**Look for these log sections:**
- **Processing [N/Total]**: Check for pkill warnings or sleep interruptions
- **Specific indicators**: Multiple LibreOffice processes running, conversion timeouts
- **Solution**: Verify process cleanup between conversions, check system resource availability

#### Scenario 16: State export failures (Phase 2.5)
**Look for these log sections:**
- **STATE TRACKING EXPORT**: Check if PROCESSED_FILES and FAILED_FILES exported
- **Specific indicators**: "No processed files to export", "No failed files to export"
- **Solution**: Verify conversion script completed, check GITHUB_ENV availability

### Log Level Meanings
- ✅ **Success**: Operation completed without issues
- ❌ **Error**: Critical failure that stops the workflow
- ⚠️ **Warning**: Non-critical issue that doesn't stop execution
- ℹ️ **Info**: Normal status information
- 🔍 **Debug**: Detailed information for troubleshooting

## Benefits of Improved Approach
- **Complete Coverage**: Processes all changes since last successful conversion (Phase 2 ✅)
- **Retry Logic**: Failed files automatically retried on next run (Phase 2 ✅)
- **No Lost Work**: Progress saved even if workflow fails partially (Phase 2 ✅)
- **Manual Trigger Support**: Works correctly regardless of trigger method (Phase 2 ✅)
- **Multi-commit Support**: Handles scenarios with multiple commits containing changes (Phase 2 ✅)
- **Enhanced Debugging**: Comprehensive logging for quick issue resolution (Phase 1 ✅)
- **User-Friendly Feedback**: Clear status messages and troubleshooting guidance (Phase 1 ✅)
- **Visual Status Indicators**: Quick identification of workflow status (Phase 1 ✅)
- **Reliable Conversion**: Individual file processing with process isolation (Phase 2.5 ✅)
- **Accurate State Tracking**: File-level success/failure tracking for retry logic (Phase 2.5 ✅)
- **Predictable Deployment**: Simple overwrite strategy with git-level change detection (Phase 3 ✅)

## Workflow Triggers

### 1. Using Workflow Dispatch
Manual triggering via GitHub UI:

```yaml
name: Convert Documentation
on:
  push:
    branches: [ main ]
    paths:
      - 'components/**/*.fodt'
  workflow_dispatch:  # Allow manual triggering
```

### 2. Using Push Events
Automatic triggering on file changes:

```yaml
on:
  push:
    branches: [ main ]
    paths:
      - 'components/**/*.fodt'
```

### 3. Using Repository Dispatch
Triggering from external systems:

```yaml
on:
  repository_dispatch:
    types: [run-workflow]
```

Trigger with curl:
```bash
curl -X POST \
     -H "Accept: application/vnd.github.v3+json" \
     -H "Authorization: token YOUR_GITHUB_TOKEN" \
     https://api.github.com/repos/YOUR_USERNAME/YOUR_REPO/dispatches \
     -d '{"event_type": "run-workflow"}'
```

### 4. Using Scheduled Events
Periodic execution:

```yaml
on:
  schedule:
    - cron: '0 * * * *'  # Runs every hour
```