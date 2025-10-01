#!/usr/bin/env python3
import json
import sys

try:
    with open('current-state.json') as f:
        state = json.load(f)
    print(state.get('lastProcessedCommit', ''))
except:
    print('')