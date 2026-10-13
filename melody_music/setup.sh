#!/usr/bin/env bash
# تشغيل من جذر المشروع (Git Bash / macOS / Linux). على ويندوز PowerShell نفّذ الأوامر يدويًا من README.
set -e
flutter create . --org com.melodymusic --project-name melody_music --platforms android
python tools/patch_android.py || python3 tools/patch_android.py
flutter pub get
dart run flutter_launcher_icons
flutter analyze
flutter test
