# QCM Prof – fichiers du projet

1. `flutter create qcm_app && cd qcm_app`
2. `flutter pub add sqflite path path_provider file_picker image_picker pdf printing google_mlkit_text_recognition image`
3. Remplacer le dossier `lib/` par celui de cette archive.
4. Android : dans `android/app/build.gradle(.kts)`, mettre `minSdk = 23`.
5. iOS : dans `ios/Podfile`, `platform :ios, '15.5'`, et dans `ios/Runner/Info.plist` ajouter
   `NSCameraUsageDescription` et `NSPhotoLibraryUsageDescription` (texte au choix).
6. `flutter run`

`web/qcm_editor.html` : interface Web de préparation, exporte le JSON que l'application importe.
Format JSON : {"title": "...", "questions": [{"text": "...", "options": [{"text": "...", "correct": true}]}]}
