# EcoDocs Workflow Documentation

## Overview

Automated workflow that converts FODT (Flat XML ODT) documentation files to Markdown using LibreOffice DocExport extension and syncs them to a VitePress documentation site.

**Key Features:**
- Containerized LibreOffice environment with pre-installed DocExport extension
- State-based change detection (processes only modified files)
- Individual file processing with proper LibreOffice process management
- UTF-8 encoding normalization and VitePress-compatible metadata
- Automatic image extraction and folder handling
- Retry logic for failed conversions

## Workflow Architecture

### File Responsibilities
- **`.github/workflows/convert-docs.yml`**: Main workflow orchestration
- **`.github/workflows/convert_docs_extension.sh`**: Core conversion script (FODT→ODT→Markdown)
- **`.github/workflows/create_metadata.py`**: Adds VitePress-compatible frontmatter
- **`.github/workflows/update_state.py`**: Manages conversion state tracking
- **`.github/workflows/DocExport.oxt`**: LibreOffice extension for ODT→Markdown conversion

### Workflow Sequence
1. **Load State**: Retrieves `.conversion-state.json` from target repository
2. **Change Detection**: Identifies modified FODT files since last successful run
3. **Conversion**: Processes files through FODT→ODT→Markdown pipeline
4. **State Update**: Creates new state file with success/failure tracking
5. **Deployment**: Copies markdown files and state to target repository
6. **Manifest Generation**: Updates VitePress component manifest

### Conversion Pipeline
1. **FODT→ODT**: LibreOffice built-in converter
2. **ODT→Markdown**: DocExport extension using `ExportDir` macro
3. **UTF-8 Encoding**: Python-based encoding normalization
4. **Metadata Addition**: VitePress frontmatter injection
5. **Image Handling**: Automatic extraction to `img_filename/` folders

### State Tracking
- **State File**: `.conversion-state.json` in target repository root
- **Tracks**: Last processed commit, successful files, failed files with retry counts
- **Retry Logic**: Failed files automatically retried (max 3 attempts)
- **Change Detection**: Compares against `lastProcessedCommit` instead of HEAD~1

## Container Environment

**Pre-built Container**: `ghcr.io/{repository}/ecodocs-libreoffice:latest`
- Ubuntu 22.04 with LibreOffice pre-installed
- DocExport.oxt extension (shared and user contexts)
- Python 3 with required packages
- Fast startup (~30 seconds vs ~5 minutes installation)

**Container Build**: Manual trigger via `build-container.yml` workflow
- Rebuilds when Dockerfile or DocExport.oxt changes
- Uses GitHub Container Registry with layer caching

## Key Technical Insights

### LibreOffice Macro Compatibility
**Critical Finding**: Not all DocExport macros work in headless mode
- **MakeDocHfmView**: Requires GUI interaction, hangs in `--headless` mode
- **ExportDir**: Works correctly in headless mode for batch processing
- **Solution**: Use `ExportDir` macro with individual file processing in temp directories

### Process Management Requirements
**LibreOffice Process Isolation**: Essential for reliable conversions
```bash
# Critical pattern for each file:
pkill -9 -f soffice 2>/dev/null || true
sleep 2
soffice --headless --invisible --nologo --norestore "macro:///DocExport.DocModel.ExportDir(\"$single_dir\",1)"
sleep 5
```

### Shell Compatibility Requirements
**GitHub Actions Environment**: Uses POSIX shell (`/bin/sh`), not bash
- **Pattern Matching**: Use `case` statements instead of `[[ ]]` bash extensions
- **Comparisons**: Use `[ "$var" = "value" ]` instead of `[ "$var" == "value" ]`
- **Variable Quoting**: Always quote variables in shell comparisons
- **Arithmetic**: Use `[ "$count" -eq 0 ]` instead of `[[ $count -eq 0 ]]`

```bash
# ❌ Bash-specific (fails in GitHub Actions)
if [[ "$file" == components/*/*.fodt ]]; then

# ✅ POSIX-compatible
case "$file" in
  components/*/*.fodt) echo "Match" ;;
esac
```

### State File Management
- **Temporary**: `new-state.json` (created during workflow)
- **Persistent**: `.conversion-state.json` (committed to target repository)
- **Location**: Target repository root (peerf-eco/docs-vitepress)

### Encoding and Locale Handling
**UTF-8 Normalization**: Essential for multi-platform compatibility
- **Locale Settings**: LibreOffice requires UTF-8 locale for proper Cyrillic text handling
- **Python Encoding**: Dedicated script handles multiple source encodings (Windows-1251, CP1251, ISO-8859-1)
- **Line Endings**: Automatic CRLF→LF conversion for Unix compatibility

```bash
# Set UTF-8 locale for LibreOffice (prevents Cyrillic → question marks)
export LC_ALL=C.UTF-8
export LANG=C.UTF-8
export LANGUAGE=C.UTF-8
```

```python
# Python encoding conversion script
python3 convert_encoding.py input.md output.md
# Handles: utf-8, windows-1251, cp1251, iso-8859-1, latin1 → UTF-8 + LF
```

## Local Container Testing

### Prerequisites
- Docker installed and running
- DocExport.oxt extension file available

### Test Scripts Available
- **`test_production_workflow.sh`**: **Production Logic Testing** - Simulates exact GitHub Actions workflow steps including fast-fail test, process cleanup, loop continuation, and error handling. Tests 8 files with production-identical logging and state tracking.
- **`test_complete_workflow.sh`**: **Metadata Integration Testing** - Focuses on ODT→Markdown conversion pipeline with VitePress metadata generation. Tests 3 files with emphasis on frontmatter validation and encoding normalization.

users should:

* Use test_production_workflow.sh when debugging workflow logic or process management issues
* Use test_complete_workflow.sh when validating conversion output quality or metadata generation

### Running Local Tests

#### 1. Build Test Container
```bash
# Build container from Dockerfile
docker build -t libreoffice_test .github/workflows/

# Or run existing container
docker run -it --name libreoffice_test libreoffice_test bash
```

#### 2. Copy Test Files
```bash
# Copy test script to container
docker cp test_production_workflow.sh libreoffice_test:/tmp/

# Copy updated extension if needed
docker cp .github/workflows/DocExport.oxt libreoffice_test:/tmp/
```

#### 3. Execute Tests
```bash
# Run production workflow test
docker exec libreoffice_test bash /tmp/test_production_workflow.sh

# Update extension in container
docker exec libreoffice_test bash -c "unopkg remove --shared org.openoffice.legacy.DocExport.oxt 2>/dev/null || true && unopkg add --shared /tmp/DocExport.oxt"
```

#### 4. Key Test Commands
```bash
# Check extension status
docker exec libreoffice_test unopkg list --shared | grep -i docexport

# Monitor LibreOffice processes
docker exec libreoffice_test pgrep -af soffice

# Test macro directly
docker exec libreoffice_test soffice --headless --invisible --nologo --norestore "macro:///DocExport.DocModel.ExportDir(\"/tmp\",1)"
```

### Test Results Validation
- **Success Indicators**: All ODT files converted to markdown with proper file sizes
- **Process Management**: No hanging LibreOffice processes after completion
- **Image Handling**: Proper `img_filename/` folder creation and content
- **Metadata**: VitePress-compatible frontmatter in generated markdown files

## Current Session Findings

### State File Deployment Issue (Fixed)
**Problem**: `.conversion-state.json` not being committed to target repository
**Root Cause**: Workflow step order - state update ran after deployment
**Solution**: Moved `Update Conversion State` step before deployment step
**Result**: State file now properly maintained in target repository

### Macro Parameter Quoting (Fixed)
**Problem**: Directory paths with spaces caused macro failures
**Solution**: Proper shell escaping in macro calls
```bash
# Before: "macro:///DocExport.DocModel.ExportDir($single_dir,1)"
# After:  "macro:///DocExport.DocModel.ExportDir(\"$single_dir\",1)"
```

### Change Detection Logic (Fixed)
**Problem**: Git diff not detecting .fodt file changes between commits
**Root Causes**: 
1. Quoted glob patterns preventing shell expansion (`'components/**/*.fodt'`)
2. Bash-specific `[[ ]]` pattern matching failing in POSIX shell
3. Insufficient git history depth for state-based comparisons

**Solutions**:
- Removed quotes from git diff path patterns
- Replaced `[[ ]]` with POSIX `case` statements
- Progressive fetch depth increase (50→100→500→1000→unshallow)
- Added detailed debug output for commit range verification

### UTF-8 Encoding Implementation (Fixed)
**Problem**: Cyrillic text converted to question marks in markdown output
**Root Cause**: LibreOffice locale not set to UTF-8 during conversion
**Solution**: 
- Set `LC_ALL=C.UTF-8` environment variables before LibreOffice execution
- Created dedicated Python script for encoding detection and conversion
- Replaced complex bash encoding logic with reliable Python implementation

**Result**: Proper Cyrillic text preservation in UTF-8 markdown with LF line endings

### Process Management Enhancement
**Finding**: Aggressive process cleanup essential for workflow reliability
**Implementation**: `pkill -9 -f soffice` with proper timing intervals
**Result**: Eliminated hanging LibreOffice processes and conversion failures

### Container Locale Configuration
**Recommendation**: Set UTF-8 locale at container build time for additional robustness
```dockerfile
# Add to Dockerfile for permanent UTF-8 locale
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8
ENV LANGUAGE=C.UTF-8
RUN locale-gen C.UTF-8
```
**Note**: Most modern Linux containers default to UTF-8, but explicit setting ensures consistency across different base images and environments.

### Multi-Directory Support (Current Session)
**Enhancement**: Extended workflow to process .fodt files from multiple source directories

**Source Directory Patterns**:
- `components/**/*.fodt` - Any nesting level, flattened to `docs/components/`
- `libraries/**/*.fodt` - Any nesting level, preserves structure in `docs/libraries/`
- `guides/**/*.fodt` - Any nesting level, preserves structure in `docs/guides/`

**Directory Structure Handling**:
```bash
# Components: Flat structure (all files in root)
components/subfolder/file.fodt → docs/components/file.md
components/deep/nested/file.fodt → docs/components/file.md

# Libraries & Guides: Preserve nested structure
libraries/subfolder/file.fodt → docs/libraries/subfolder/file.md
guides/deep/nested/file.fodt → docs/guides/deep/nested/file.md
```

**Implementation Changes**:
- **Workflow Triggers**: Added `libraries/**/*.fodt` and `guides/**/*.fodt` patterns
- **File Detection**: Updated git diff patterns to include new directories
- **Conversion Script**: Modified output path logic based on source directory
- **Deployment**: Simplified to copy entire directory trees while maintaining structure

**Pattern Matching Fix**: Changed from `components/*/*.fodt` (exactly one level) to `components/**/*.fodt` (zero or multiple levels) to allow files directly in root directories.

## Troubleshooting

### Common Issues
- **Hanging Conversions**: Check LibreOffice process cleanup and macro compatibility
- **Missing State File**: Verify workflow step order and file permissions
- **Encoding Problems**: Verify UTF-8 locale settings and Python encoding script
- **Image Folder Issues**: Check DocExport macro output and folder naming
- **Shell Syntax Errors**: Use POSIX-compatible syntax, avoid bash-specific features
- **Git Change Detection**: Ensure sufficient fetch depth and proper glob pattern handling
- **Directory Structure Issues**: Verify source directory patterns match expected nesting levels
- **File Path Conflicts**: Check for filename collisions when flattening components structure

### Debug Commands
```bash
# Check workflow logs for specific patterns
grep -E "(✅|❌|⚠️)" workflow.log

# Verify container extension
docker exec container unopkg list --shared | grep -i docexport

# Test macro in isolation
docker exec container timeout 10 soffice --headless "macro:///DocExport.DocModel.ExportDir(\"/test\",1)"

```

## PS

The execution of Libreoffice Writer macros from command line is not an obvious task. There are several sources on Internet discussing this:

### References

https://forum.openoffice.org/en/forum/viewtopic.php?f=20&t=8232#p38910

https://superuser.com/questions/1135850/how-do-i-run-a-libreoffice-macro-from-the-command-line-without-the-gui

https://ask.libreoffice.org/t/execute-macro-in-calc-from-terminal/32101/6

https://stackoverflow.com/questions/52623426/how-to-run-a-single-macro-for-all-xls-xlsx-files-for-libreoffice

https://stackoverflow.com/questions/71244677/how-do-i-run-a-libreoffice-macro-from-the-command-line-without-gui

youtube: https://www.youtube.com/watch?v=my1QIFNgNhY


and even using Python: https://christopher5106.github.io/office/2015/12/06/openoffice-libreoffice-automate-your-office-tasks-with-python-macros.html

At the moment the problem of bulk libreoffice documents processing under linux cli is not fully understood / investigated and working. It looks there is an inherent libreoffice macro limitation as application proccess is tied to the context of one file only (may be its is for Basic language only?). That's why the current approach is to organize a loop with filenames given as a parameter to the macro.
