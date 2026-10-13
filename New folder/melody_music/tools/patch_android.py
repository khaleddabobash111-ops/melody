#!/usr/bin/env python3
"""يهيّئ مجلد android المُولَّد بـ `flutter create` لخدمة تشغيل الصوت في الخلفية.
الاستخدام (من جذر المشروع):  python tools/patch_android.py
آمن لإعادة التشغيل (idempotent)."""
import re, sys, pathlib

root = pathlib.Path('android/app/src/main')
manifest = root / 'AndroidManifest.xml'
if not manifest.exists():
    sys.exit('AndroidManifest.xml غير موجود. شغّل أولًا: flutter create . --org com.melodymusic --project-name melody_music --platforms android')

m = manifest.read_text(encoding='utf-8')

if 'xmlns:tools=' not in m:
    m = m.replace('<manifest ', '<manifest xmlns:tools="http://schemas.android.com/tools" ', 1)

perms = [
    'android.permission.WAKE_LOCK',
    'android.permission.FOREGROUND_SERVICE',
    'android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK',
    'android.permission.POST_NOTIFICATIONS',
]
add = ''.join(f'    <uses-permission android:name="{p}"/>\n' for p in perms if p not in m)
if add:
    m = re.sub(r'(\s*)<application', lambda mo: '\n' + add + '    <application', m, count=1)

m = re.sub(r'android:label="[^"]*"', 'android:label="Melody Music"', m, count=1)

if 'com.ryanheise.audioservice.AudioService' not in m:
    block = '''
        <service android:name="com.ryanheise.audioservice.AudioService"
            android:foregroundServiceType="mediaPlayback"
            android:exported="true" tools:ignore="Instantiatable">
            <intent-filter>
                <action android:name="android.media.browse.MediaBrowserService" />
            </intent-filter>
        </service>
        <receiver android:name="com.ryanheise.audioservice.MediaButtonReceiver"
            android:exported="true" tools:ignore="Instantiatable">
            <intent-filter>
                <action android:name="android.intent.action.MEDIA_BUTTON" />
            </intent-filter>
        </receiver>
'''
    m = m.replace('</application>', block + '    </application>', 1)

manifest.write_text(m, encoding='utf-8')

# MainActivity -> AudioServiceActivity
done = False
for f in list(root.glob('kotlin/**/MainActivity.kt')) + list(root.glob('java/**/MainActivity.java')):
    s = f.read_text(encoding='utf-8')
    if 'AudioServiceActivity' in s:
        done = True
        continue
    s = s.replace('import io.flutter.embedding.android.FlutterActivity', 'import com.ryanheise.audioservice.AudioServiceActivity')
    s = s.replace('FlutterActivity', 'AudioServiceActivity')
    f.write_text(s, encoding='utf-8')
    done = True
if not done:
    print('تحذير: لم أجد MainActivity، عدّلها يدويًا لتمتد من AudioServiceActivity')
print('تم تهيئة android بنجاح')
