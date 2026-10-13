# Melody Music

مشغّل موسيقى محلي (Offline-first) لأندرويد بـ Flutter. كتبتُ الكود كاملًا لكن **لم يُبنَ ولم يُشغَّل** (لا Flutter ولا إنترنت في بيئتي). ما تحققتُ منه فعليًا: صحة استيرادات الملفات، توازن الأقواس، ومخطط SQL والاستعلامات على SQLite حقيقي، وسكربت تهيئة أندرويد على manifest تجريبي.

## التشغيل (مرة واحدة)
المتطلبات: Flutter SDK + Android SDK + (VS Code مع إضافة Flutter).

```powershell
cd melody_music
flutter create . --org com.melodymusic --project-name melody_music --platforms android
python tools/patch_android.py        # يضيف الأذونات وخدمة الصوت ويغيّر MainActivity واسم التطبيق
flutter pub get
dart run flutter_launcher_icons      # أيقونة التطبيق (assets/icon)
flutter analyze
flutter test
flutter run                          # على هاتف موصول
flutter build apk --release          # build/app/outputs/flutter-apk/app-release.apk
```
(أو `bash setup.sh` دفعة واحدة.)

**إن فشل `pub get`:** الإصدارات كتبتُها من الذاكرة. جرّب `flutter pub upgrade --major-versions` وأرسل لي الخطأ.
**الخط:** نزّل Cairo (OFL) إلى `assets/fonts/` وفعّل قسم fonts في pubspec. بدونه يعمل التطبيق بخط النظام.
**التوقيع للنشر:** أنشئ keystore وضع بياناته في `android/key.properties` (مستبعد من Git). بدونه يُوقَّع الـ APK بمفتاح debug وهو صالح للتثبيت الشخصي فقط.

## البنية
```
lib/
  core/        theme (Melody Design System) + l10n (عربي/إنجليزي)
  data/        models + database (SQLite) + repositories
  services/    audio_handler (just_audio + audio_service) · import_service · playback_service · metadata_reader
  providers/   Riverpod: مكتبة، قوائم، بحث، إعدادات
  features/    home · library · playlists · search · settings · player/ui (المشغل الكامل + الخلفية الديناميكية + Mini)
  shared/      widgets + flows (استيراد، رابط، قوائم سياقية، Queue)
```

## ما نُفِّذ
- **الصوت:** مشغل مركزي، خلفية، إشعار وشاشة قفل (Media Session)، Shuffle/Repeat، Queue حقيقية (حذف، إعادة ترتيب، التشغيل التالي، مسح القادم)، استعادة آخر قائمة وموضع.
- **المكتبة:** استيراد عدة ملفات، قراءة الوسوم والغلاف المضمّن، منع التكرار ببصمة، عرض شبكة/قائمة، ترتيب، 7 أقسام، قوائم سياقية، تعديل العنوان.
- **قوائم التشغيل والمفضلة:** إنشاء/تسمية/حذف/إعادة ترتيب، المفضلة متزامنة في كل الشاشات، سجل تشغيل ومسحه.
- **بحث محلي** مع سجل بحث محفوظ. **إعدادات:** سمة، لغة، تقليل الحركة، عرض، ترتيب، استئناف.
- **الخلفية الديناميكية** من غلاف الأغنية الحقيقي مع كاش (انظر `features/player/ui`).
- **رابط مباشر:** يقبل https لملف صوتي مباشر فقط، ويرفض YouTube/Spotify وغيرها برسالة واضحة، دون أي تجاوز للحماية.

## قرارات يجب أن تعرفها
- الملفات المستوردة **تُنسخ** إلى مساحة التطبيق (لأن المسارات المؤقتة من منتقي الملفات لا تبقى صالحة). وهذا مكتوب في الإعدادات. لذلك «إزالة من المكتبة» تحذف نسخة التطبيق فقط، **والملف الأصلي على هاتفك لا يُمس**، فخياري Remove وDelete Local Copy صارا خيارًا واحدًا.
- قراءة الوسوم معزولة في `services/metadata_reader.dart`؛ واجهة مكتبة `audio_metadata_reader` كتبتها من الذاكرة، فإن اختلفت عدّل ذلك الملف فقط.

## غير مكتمل / يحتاج اختبارًا على هاتفك
- **لم يُختبر أي شيء على جهاز:** الإشعار، شاشة القفل، الخلفية، الأداء، الصيغ (FLAC وغيرها حسب الجهاز).
- إشعار أندرويد 13+ يحتاج إذن POST_NOTIFICATIONS؛ أضفته في manifest لكن لم أبنِ شاشة طلب الإذن وقت التشغيل (يلزم `permission_handler`).
- صورة مخصصة لقائمة التشغيل (الحقل موجود في قاعدة البيانات دون واجهة تغييرها)، وتعديل الفنان/الألبوم من الواجهة (التعديل الحالي للعنوان فقط).
- لا يوجد اختبار تكامل (integration_test) ولا Widget test للمشغل المصغر؛ الموجود اختبارات وحدة للنماذج وقاعدة البيانات والألوان والروابط، وWidget test واحد.
- لم أقِس الأداء، فلا أدّعي أرقامًا.
