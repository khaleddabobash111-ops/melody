#!/usr/bin/env python3
"""Force Android compileSdk 36 in file_picker Gradle plugin source and verify."""
from pathlib import Path
import os,re,sys
roots=[Path(os.environ.get('PUB_CACHE',str(Path.home()/'.pub-cache'))),Path.home()/'.pub-cache']
files=set()
for root in roots:
    files.update(root.glob('hosted/*/file_picker-*/android/build.gradle'))
    files.update(root.glob('hosted/*/file_picker-*/android/build.gradle.kts'))
if not files:
    sys.exit('ERROR: file_picker Android Gradle source not found in Pub cache')
for p in sorted(files):
    s=p.read_text()
    # Groovy: compileSdkVersion 34 / compileSdk 34 / compileSdkVersion flutter.compileSdkVersion
    # Kotlin: compileSdk = 34 / compileSdk = flutter.compileSdkVersion
    pattern=r'(?m)^(\s*compileSdk(?:Version)?\s*(?:=\s*)?)(?:[0-9]+|flutter\.compileSdkVersion)(\s*(?://[^\n]*)?)$'
    updated,n=re.subn(pattern,lambda m:m.group(1)+'36'+m.group(2),s)
    if not n and not re.search(r'\bcompileSdk(?:Version)?\s*(?:=\s*)?36\b',s):
        sys.exit(f'ERROR: Cannot find compileSdk in {p}; inspect manually')
    p.write_text(updated)
    print(f'PATCHED {p} (replacements={n})')
    for line in updated.splitlines():
        if re.search(r'\bcompileSdk(?:Version)?\b',line): print('  ',line.strip())
