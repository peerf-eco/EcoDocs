# EcoDocs Workflow Documentation

## Current Conversion Workflow

The workflow converts FODT (Flat XML ODT) documentation files in the current repository (which have been changed since previous workflow run) to Markdown using LibreOffice extension DocExport.oxt and syncs them to the target documentation repository.

### Image Folder Handling
When ODT files contain images, the DocExport extension automatically extracts them during conversion:
- **Image Folder Pattern**: `img_` + source ODT filename (e.g., `document.odt` → `img_document/`)
- **Automatic Detection**: Workflow detects image folders and copies them alongside markdown files
- **Target Location**: Image folders are placed in the same directory as their corresponding markdown files in the target repository

### Conversion Process
1. **Extension Installation**: DocExport.oxt is installed in LibreOffice using `unopkg add`
2. **FODT to ODT**: Source FODT files are converted to ODT format using LibreOffice
3. **ODT to Markdown**: LibreOffice macro `DocExport.DocModel.ExportDir(directory,1)` converts ODT files to Markdown
4. **Image Extraction**: Images from ODT files are extracted to folders named `img_` + source filename
5. **Sync to Target**: Converted markdown files and their corresponding image folders are pushed to the target documentation repository

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

## Improvement Plan

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
**Create `.conversion-state.json` in target repository:**
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

### Phase 3: Failure Recovery (PLANNED)
- Handle partial conversion failures gracefully
- Retry failed files on subsequent runs
- Maintain detailed error logs for debugging
- Implement maximum retry limits to prevent infinite loops

### Phase 4: Content Verification (PLANNED)
- Add file hash comparison as backup verification
- Detect when source files are modified but git doesn't catch changes
- Handle edge cases like file renames or moves
- Verify target files match source content

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

### Log Level Meanings
- ✅ **Success**: Operation completed without issues
- ❌ **Error**: Critical failure that stops the workflow
- ⚠️ **Warning**: Non-critical issue that doesn't stop execution
- ℹ️ **Info**: Normal status information
- 🔍 **Debug**: Detailed information for troubleshooting

## Benefits of Improved Approach
- **Complete Coverage**: Processes all changes since last successful conversion
- **Retry Logic**: Failed files automatically retried on next run
- **No Lost Work**: Progress saved even if workflow fails partially
- **Manual Trigger Support**: Works correctly regardless of trigger method
- **Multi-commit Support**: Handles scenarios with multiple commits containing changes
- **Enhanced Debugging**: Comprehensive logging for quick issue resolution (Phase 1 ✅)
- **User-Friendly Feedback**: Clear status messages and troubleshooting guidance (Phase 1 ✅)
- **Visual Status Indicators**: Quick identification of workflow status (Phase 1 ✅)

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