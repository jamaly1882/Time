# منظم وقتي — Flutter Android

تطبيق بسيط لجدولك الأسبوعي مع إشعارات Android وتنبيه صوتي للاختبار عبر TTS.

## المتطلبات
- Flutter حديث (يفضل 3.32+)
- Android SDK
- JDK المتوافق مع Flutter/Android Gradle Plugin

## التشغيل
```bash
flutter pub get
flutter run
```

## بناء APK
```bash
flutter build apk --release
```
الملف الناتج غالبًا:
`build/app/outputs/flutter-apk/app-release.apk`

## ملاحظات مهمة
- التطبيق يحفظ الجدول محليًا باستخدام SharedPreferences.
- لا يحتاج Firebase.
- يجب السماح بالإشعارات والتنبيهات الدقيقة عند أول تشغيل.
- زر السماعة في أعلى الشاشة يختبر نطق TTS.
- إشعار Android المجدول نفسه يظهر في الوقت المحدد. تشغيل الكلام تلقائيًا من داخل عملية إشعار Android قد يتطلب إضافة BroadcastReceiver/Foreground service في نسخة متقدمة؛ لذلك النسخة الحالية تضمن الإشعار الصوتي، وتوفر TTS للاختبار داخل التطبيق.
