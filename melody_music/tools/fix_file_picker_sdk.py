#!/usr/bin/env python3
"""Work around file_picker Android Gradle module compiling with SDK 34."""
from pathlib import Path
import os, re, sys
pubcache = Path(os.environ.get('PUB_CACHE', str(Path.home()/'.pub-cache')))
files = list(pubcache.glob('hosted/*/file_picker-*/android/build.gradle')) + list(pubcache.glob('hosted/*/file_picker-*/android/build.gradle.kts'))
if not files:
    sys.exit('Cannot find file_picker Android Gradle build file in pub cache')
for f in files:
    source=f.read_text()
    result,n=re.subn(r'(compileSdk(?:Version)?\s*(?:=\s*)?)34\b',r'\g<1>36',source)
    if not n:
        result,n=re.subn(r'(compileSdk(?:Version)?\s*(?:=\s*)?)flutter\.compileSdkVersion',r'\g<1>36',source)
    if not n and not re.search(r'compileSdk(?:Version)?\s*(?:=\s*)?36\b',source):
        sys.exit(f'Cannot locate compileSdk in {f}; inspect plugin build configuration')
    f.write_text(result)
    print(f'file_picker compileSdk configured: {f}')
