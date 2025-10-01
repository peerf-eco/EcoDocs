#!/usr/bin/env python3
import json
import sys

try:
    with open('current-state.json') as f:
        state = json.load(f)
    failed = state.get('failedFiles', {})
    retry_files = [f for f, d in failed.items() if d.get('attemptCount', 0) < 3]
    print(' '.join(retry_files))
except:
    print('')