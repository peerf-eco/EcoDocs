#!/usr/bin/env python3
import json
import os
from datetime import datetime

try:
    with open('current-state.json') as f:
        state = json.load(f)
except:
    state = {}

if 'failedFiles' not in state:
    state['failedFiles'] = {}

current_commit = os.environ.get('GITHUB_SHA', '')
current_time = datetime.utcnow().isoformat() + 'Z'
processed_files = [f.strip() for f in os.environ.get('PROCESSED_FILES', '').split() if f.strip()]
failed_files = [f.strip() for f in os.environ.get('FAILED_FILES', '').split() if f.strip()]

successful_files_current_session = {}
for file_path in processed_files:
    if file_path and file_path not in failed_files:
        if file_path in state['failedFiles']:
            del state['failedFiles'][file_path]
        successful_files_current_session[file_path] = {
            'convertedAt': current_time,
            'sourceCommit': current_commit,
            'sourceHash': 'sha256-placeholder'
        }

for file_path in failed_files:
    if file_path:
        if file_path in state['failedFiles']:
            state['failedFiles'][file_path]['attemptCount'] += 1
        else:
            state['failedFiles'][file_path] = {'attemptCount': 1}
        state['failedFiles'][file_path].update({
            'lastAttempt': current_time,
            'lastError': 'conversion failed',
            'sourceCommit': current_commit
        })

state['successfulFiles'] = successful_files_current_session
state['lastProcessedCommit'] = current_commit
state['lastSuccessfulRun'] = current_time

with open('new-state.json', 'w') as f:
    json.dump(state, f, indent=2)

print(f"State updated: {len(successful_files_current_session)} successful, {len(state['failedFiles'])} failed")