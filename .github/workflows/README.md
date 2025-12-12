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
- Multi-language support with automatic routing based on filename prefixes (RU, US/EN, FR, DE)

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
3. **Language Detection**: Analyzes filename prefixes to determine target language directory
4. **Conversion**: Processes files through direct FODT/ODT→Markdown pipeline
5. **State Update**: Creates new state file with success/failure tracking
6. **Deployment**: Copies markdown files to language-specific directories and updates state

### Conversion Pipeline
1. **Direct Processing**: LibreOffice DocExport extension handles both .fodt and .odt files directly
2. **Language Detection**: Filename prefix analysis to determine target language directory
3. **ODT→Markdown**: DocExport extension using `ExportDir` macro
4. **UTF-8 Encoding**: Python-based encoding normalization
5. **Metadata Addition**: VitePress frontmatter injection with CID-based renaming
6. **Image Handling**: Automatic extraction to `img_filename/` folders

### Language Detection Mechanism

**Automatic Language Routing**: The workflow automatically detects the document language from filename prefixes and routes files to appropriate language subdirectories in the target repository.

**Supported Language Prefixes**:
- `RU` - Russian (Cyrillic) → `docs/ru/`
- `US` or `EN` - English → `docs/en/`
- `FR` - French → `docs/fr/`
- `DE` - German → `docs/de/`

**Detection Pattern**: The script uses regex matching on the base filename:
```bash
# Examples of detected patterns:
RU.ECO.Component.fodt  # Matches ^RU[._-] → ru
RU_ECO_Component.fodt  # Matches ^RU[._-] → ru
US.ECO.Component.fodt  # Matches ^(US|EN)[._-] → en
EN-ECO-Component.fodt  # Matches ^(US|EN)[._-] → en
FR.ECO.Component.fodt  # Matches ^FR[._-] → fr
DE.ECO.Component.fodt  # Matches ^DE[._-] → de
ECO.Component.fodt     # No prefix match → en (default)
```

**Directory Routing Rules**:
1. **Components** (flat structure):
   - Source: `components/{CID}/*.fodt`
   - Target: `docs/{language}/components/{CID}.md`
   - Example: `components/1CE95396008F46EAB4374010C8B58383\RU.ECO.00005-01_90.fodt` → `docs/ru/components/1CE95396008F46EAB4374010C8B58383.md`
   and images are extracted into: `docs/ru/components/IMG_RU.ECO.00005-01_90/*` folder

2. **Libraries** (preserves structure):
   - Source: `libraries/**/*.fodt`
   - Target: `docs/{language}/libraries/{subfolder}/filename.md`
   - Example: `libraries/auth/US.Library.fodt` → `docs/en/libraries/auth/US.Library.md`

3. **Guides** (preserves structure):
   - Source: `guides/**/*.fodt`
   - Target: `docs/{language}/guides/{subfolder}/filename.md`
   - Example: `guides/tutorials/FR.Guide.fodt` → `docs/fr/guides/tutorials/FR.Guide.md`

**Image Folder Routing**: Image folders (`img_filename/`) are placed in the same directory as their corresponding markdown file, following the same language routing.

**Default Behavior**: Files without a recognized language prefix default to English (`en`) directory.

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
- `components/**/*.fodt` - Any nesting level, flattened to `docs/{language}/components/`
- `libraries/**/*.fodt` - Any nesting level, preserves structure in `docs/{language}/libraries/`
- `guides/**/*.fodt` - Any nesting level, preserves structure in `docs/{language}/guides/`

**Directory Structure Handling**:
```bash
# Components: Flat structure (all files in root)
components/subfolder/file.fodt → docs/{language}/components/file.md
components/deep/nested/file.fodt → docs/{language}/components/file.md

# Libraries & Guides: Preserve nested structure
libraries/subfolder/file.fodt → docs/{language}/libraries/subfolder/file.md
guides/deep/nested/file.fodt → docs/{language}/guides/deep/nested/file.md
```

**Implementation Changes**:
- **Workflow Triggers**: Added `libraries/**/*.fodt` and `guides/**/*.fodt` patterns
- **File Detection**: Updated git diff patterns to include new directories
- **Conversion Script**: Modified output path logic based on source directory
- **Deployment**: Simplified to copy entire directory trees while maintaining structure

**Pattern Matching Fix**: Changed from `components/*/*.fodt` (exactly one level) to `components/**/*.fodt` (zero or multiple levels) to allow files directly in root directories.

### Multi-Language Support (Current Session)
**Enhancement**: Added automatic language detection and routing based on filename prefixes

**Language Detection Logic**:
Files are automatically routed to language-specific subdirectories based on their filename prefix:
- **RU prefix** (e.g., `RU.ECO.Component.fodt`) → `docs/ru/{section}/`
- **US or EN prefix** (e.g., `US.ECO.Component.fodt`, `EN.ECO.Component.fodt`) → `docs/en/{section}/`
- **FR prefix** (e.g., `FR.ECO.Component.fodt`) → `docs/fr/{section}/`
- **DE prefix** (e.g., `DE.ECO.Component.fodt`) → `docs/de/{section}/`
- **No prefix or unknown prefix** → defaults to `docs/en/{section}/`

**Target Directory Structure**:
```bash
# Components (flattened)
RU.ECO.Component.fodt → docs/ru/components/RU.ECO.Component.md
US.ECO.Component.fodt → docs/en/components/US.ECO.Component.md
FR.ECO.Component.fodt → docs/fr/components/FR.ECO.Component.md

# Libraries (preserves structure)
RU.Library.fodt in libraries/subfolder/ → docs/ru/libraries/subfolder/RU.Library.md
US.Library.fodt in libraries/subfolder/ → docs/en/libraries/subfolder/US.Library.md

# Guides (preserves structure)
RU.Guide.fodt in guides/subfolder/ → docs/ru/guides/subfolder/RU.Guide.md
EN.Guide.fodt in guides/subfolder/ → docs/en/guides/subfolder/EN.Guide.md
```

**Implementation Details**:
- **Prefix Detection**: Uses regex pattern matching on filename (e.g., `^RU[._-]`, `^(US|EN)[._-]`)
- **Automatic Directory Creation**: Creates language-specific directories (`docs/{lang}/components/`, etc.)
- **Image Folder Handling**: Image folders follow the same language routing as their parent markdown files
- **Deployment**: Copies all language directories while preserving structure (`docs/*/components/`, `docs/*/libraries/`, `docs/*/guides/`)

### VitePress Frontmatter Integration (Current Session)
**Enhancement**: Inlined metadata processing with CID-based file renaming

**Key Changes**:
- **Separation of Concerns**: Maintained clean separation between conversion (`convert_docs_extension.sh`) and metadata processing (`create_metadata.py`)
- **CID-Based Renaming**: Files automatically renamed using CID metadata field value
- **Source URL Accuracy**: Fixed source URL generation to use actual original file paths instead of reconstructed paths
- **Enhanced Logging**: Added detailed output showing metadata processing results and file renaming

**VitePress Frontmatter Fields**:
```yaml
---
title: "Name"
layout: doc
documentType: "Specification"
documentUspd: "USPD Value"
version: "1.0"
componentName: "Software Component Name"
CID: "0000000000000000000000004D656D31"
description: "Short description"
useCategory: "CATEGORY"
type: "TYPE"
marketplaceId: "e71f846d-89dc-425f-b3f8-e1884a84b77a"
registryUrl: "https://marketplace.url"
source: "https://github.com/repo/blob/commit/actual/path/file.fodt"
lastUpdated: true
editLink: true
sidebar: true
---
```

**File Renaming Logic**:
- **With CID**: `US.ECO.00016-01_90.md` → `0000000000000000000000004D656D31.md`
- **Without CID**: File keeps original name
- **Source URL**: Uses actual original file path for accurate GitHub links

### Shell Script Fixes (Current Session)
**Problem**: Multiple shell syntax errors causing workflow failures

**Fixed Issues**:
1. **OLDPWD Unbound Variable**: Replaced `$OLDPWD` with `$PWD` (GitHub Actions doesn't set OLDPWD)
2. **Workflow Condition Logic**: Fixed "No Changes Detected" condition from `!= 'true'` to `== 'false'`
3. **File Copy Syntax**: Removed problematic `2>/dev/null` redirections causing syntax errors
4. **Glob Pattern Handling**: Added existence checks before loops to prevent errors when no matching files exist
5. **CRLF Count Check**: Fixed malformed condition causing integer expression errors

**Shell Compatibility Improvements**:
```bash
# Before (problematic)
for file in converted_docs/*.md 2>/dev/null; do

# After (fixed)
if ls converted_docs/*.md >/dev/null 2>&1; then
  for file in converted_docs/*.md; do
```

### Workflow Simplification (Current Session)
**Removed**: npm-based manifest generation step

**Rationale**: 
- The VitePress frontmatter in each .md file serves as the metadata/manifest
- No need for separate `components.json` file generation
- Eliminates Node.js dependency and related failures
- Simplifies workflow and reduces potential failure points

**Result**: Cleaner workflow focused on core functionality without confusing "skipping manifest generation" messagesment**: Extended workflow to process .fodt files from multiple source directories



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
- **Language Detection Issues**: Verify filename follows prefix pattern (e.g., `RU.`, `US.`, `EN.`, `FR.`, `DE.`)
- **Wrong Language Directory**: Check that filename prefix uses supported language codes and proper separators (`.`, `_`, or `-`)

### Debug Commands
```bash
# Check workflow logs for specific patterns
grep -E "(✅|❌|⚠️)" workflow.log

# Verify container extension
docker exec container unopkg list --shared | grep -i docexport

# Test macro in isolation
docker exec container timeout 10 soffice --headless "macro:///DocExport.DocModel.ExportDir(\"/test\",1)"

# Check language detection in logs
grep "🌐 Detected language" workflow.log

# Verify target directory structure
ls -la docs-vitepress/docs/*/components/
ls -la docs-vitepress/docs/*/libraries/
ls -la docs-vitepress/docs/*/guides/
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
