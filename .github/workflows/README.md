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

### Shell Compatibility Tips
- GitHub Actions uses POSIX shell (`/bin/sh`), not bash
- Use `[ "$var" = "value" ]` instead of `[ "$var" == "value" ]`
- Always quote variables in shell comparisons

### State File Management
- **Temporary**: `new-state.json` (created during workflow)
- **Persistent**: `.conversion-state.json` (committed to target repository)
- **Location**: Target repository root (peerf-eco/docs-vitepress)

### Encoding Handling
**UTF-8 Normalization**: Essential for multi-platform compatibility
```python
python3 -c "import sys; open('output.md','wb').write(open('input.md','rb').read().decode(errors='ignore').encode('utf-8'))"
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
**Problem**: Contradictory messages about file changes and boolean comparison errors
**Root Cause**: Shell syntax errors and non-existent workflow outputs
**Solution**: 
- Fixed boolean comparisons (`==` → `=`)
- Removed references to non-existent outputs
- Added git ownership configuration

### Process Management Enhancement
**Finding**: Aggressive process cleanup essential for workflow reliability
**Implementation**: `pkill -9 -f soffice` with proper timing intervals
**Result**: Eliminated hanging LibreOffice processes and conversion failures

## Troubleshooting

### Common Issues
- **Hanging Conversions**: Check LibreOffice process cleanup and macro compatibility
- **Missing State File**: Verify workflow step order and file permissions
- **Encoding Problems**: Ensure UTF-8 conversion step is working
- **Image Folder Issues**: Check DocExport macro output and folder naming

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
