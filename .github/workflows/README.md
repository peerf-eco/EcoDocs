# EcoDocs Workflow Documentation

## Current Conversion Workflow

The workflow converts FODT (Flat XML ODT) documentation files in the current repository (which have been changed since previous workflow run) to Markdown using LibreOffice extension DocExport.oxt and syncs them to the target documentation repository.

### Conversion Process
1. **Extension Installation**: DocExport.oxt is installed in LibreOffice using `unopkg add`
2. **FODT to ODT**: Source FODT files are converted to ODT format using LibreOffice
3. **ODT to Markdown**: LibreOffice macro `DocExport.DocModel.ExportDir(directory,1)` converts ODT files to Markdown
4. **Sync to Target**: Converted files are pushed to the target documentation repository

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

## Improvement Plan

### Phase 1: Enhanced Logging
- Add explicit file count and names in workflow logs
- Output a clear "no changes made" messages when no changed files are detected
- Debug output showing which commits are being compared and which file were found as changed
- Better error reporting for conversion failures

### Phase 2: State Tracking Implementation
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

**New Workflow Logic:**
1. Load state from target repo's `.conversion-state.json`
2. Identify files to process:
   - All files changed since `lastProcessedCommit`
   - All files in `failedFiles` list (retry failed conversions)
3. Process files and track results
4. Update state:
   - Move successful conversions from `failedFiles` to `successfulFiles`
   - Add new failures to `failedFiles`
   - Update `lastProcessedCommit` to current HEAD
   - Increment `attemptCount` for retry failures

### Phase 3: Failure Recovery
- Handle partial conversion failures gracefully
- Retry failed files on subsequent runs
- Maintain detailed error logs for debugging
- Implement maximum retry limits to prevent infinite loops

### Phase 4: Content Verification
- Add file hash comparison as backup verification
- Detect when source files are modified but git doesn't catch changes
- Handle edge cases like file renames or moves
- Verify target files match source content

## Benefits of Improved Approach
- **Complete Coverage**: Processes all changes since last successful conversion
- **Retry Logic**: Failed files automatically retried on next run
- **No Lost Work**: Progress saved even if workflow fails partially
- **Manual Trigger Support**: Works correctly regardless of trigger method
- **Multi-commit Support**: Handles scenarios with multiple commits containing changes

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