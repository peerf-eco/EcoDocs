#!/usr/bin/env python3
import json
import sys

try:
    with open('current-state.json') as f:
        state = json.load(f)
    failed = state.get('failedFiles', {})
    if failed:
        print(f'Found {len(failed)} previously failed files')
        for file_path, details in failed.items():
            attempt_count = details.get('attemptCount', 0)
            print(f'  - {file_path} (attempt #{attempt_count + 1})')
except:
    pass