# بناء APK من GitHub والهاتف فقط

1. أنشئ Repository جديدًا على GitHub.
2. ارفع محتويات هذا المجلد إلى الفرع `main`.
3. افتح تبويب Actions.
4. اختر `Build Android APK`.
5. اضغط `Run workflow`.
6. بعد نجاح البناء افتح العملية الناجحة.
7. من قسم Artifacts نزّل `time-reminder-apk`.
8. فك الضغط عن artifact وستجد `app-release.apk`.

لا تحتاج إلى Flutter على الهاتف؛ GitHub Actions يقوم بالبناء على خوادم GitHub.
