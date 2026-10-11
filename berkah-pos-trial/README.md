# Berkah POS — PT Berkah Tiga Puteri

Flutter Android trial POS with email entry, subscription-status lookup, SQLite product CRUD, local cashier checkout/reports, and external browser/WhatsApp links.

## Android requirements
- Package: `id.co.berkahtigaputeri.berkahpos`
- compileSdk 35, targetSdk 35, minSdk 24
- versionCode 1, versionName 1.0.0
- Manifest permission allowlist: CAMERA, BLUETOOTH, BLUETOOTH_CONNECT, BLUETOOTH_SCAN, INTERNET, ACCESS_NETWORK_STATE
- No payment checkout integration. The app remains usable in local trial mode when account status is inactive or unavailable.

The login email is used for status lookup and local attribution; this scaffold does not implement password authentication because no authentication API was provided. GET `https://api.berkahtigaputeri.co.id/check-status?email=...` should return JSON such as `{"status":"active"}` or `{"status":"inactive"}`.

## Run locally
Install Flutter stable, Android SDK Platform 35, and JDK 17. This repository does not commit the Gradle Wrapper JAR binary; generate the standard wrapper support files without overwriting the app configuration, then validate and test:\n\n```bash\nbash tool/prepare_gradle_wrapper.sh\nflutter pub get\npython3 tool/verify_project.py\nflutter analyze\nflutter test\n```\n\nSet the authorized sales number using `--dart-define=BERKAH_WHATSAPP_NUMBER=62XXXXXXXXXXX`.

## Release signing
Generate your own private key:
```bash
keytool -genkeypair -v -keystore android/app/berkah-pos-release.jks -alias berkahpos -keyalg RSA -keysize 2048 -validity 10000
```
Copy `android/key.properties.template` to `android/key.properties`, fill the passwords, then run `flutter build appbundle --release`. Expected AAB: `build/app/outputs/bundle/release/app-release.aab`. Never commit release credentials or the keystore.

The source is not compiled in the current editing environment because Flutter and Android SDK are unavailable here; no signed AAB has been generated. A new public Play submission also needs API 36 or higher as of 31 August 2026; API 35 is retained here only because it was explicitly requested, so public review compliance is not guaranteed.
