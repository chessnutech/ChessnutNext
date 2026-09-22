# Chessnut Flutter

A multi-platform Flutter client for Chessnut electronic chessboards. This
repository contains the application source and native projects required to
build the app for Android, iOS, macOS, Windows, and Linux.

> Firebase configuration, OAuth credentials, and signing material are not
> included in the repository. Use credentials and identifiers owned by your
> organization when building the project.

## Supported Platforms

- Android
- iOS
- macOS
- Windows
- Linux

## Prerequisites

- Git LFS for the Stockfish neural network files and embedded YOLO model
- Flutter with Dart `>=3.3.0 <4.0.0`
- Firebase CLI and FlutterFire CLI
- Android: JDK 17, Android SDK 37, and NDK `28.2.13676358`
- iOS: macOS, Xcode, CocoaPods, and an iOS 15.0 or newer deployment target
- macOS: Xcode, CocoaPods, and a macOS 12.0 or newer deployment target
- Windows or Linux native toolchains when building for those platforms

## Clone and Download Model Files

This repository uses Git LFS for the Stockfish neural network files (`*.nnue`)
and the embedded YOLO model (`third_party/yolov5vision/src/yolov8_bin.h`).
The full model contents are required to build the native engines and vision plugin.

### First-time clone

Install [Git LFS](https://git-lfs.com/) before cloning. The `git lfs install`
command below enables Git LFS for your user account; it does not install the
Git LFS executable.

```bash
git lfs install
git clone https://github.com/chessnutech/ChessnutNext.git
cd ChessnutNext
flutter pub get
```

With Git LFS enabled, a normal `git clone` automatically downloads the model
files. A separate `git lfs pull` is normally unnecessary unless automatic LFS
downloads were disabled or the download failed.

### Already cloned without Git LFS

Without Git LFS enabled, a clone may contain small text pointer files at the
model paths instead of the actual model data. These placeholders cannot be
used to build the project.

Install Git LFS, then run the following from the existing project root to
download the models and replace the pointers. You do not need to clone again.

```bash
git lfs install
git lfs pull
flutter pub get
```

## Local Configuration

### 1. Firebase

The application imports `lib/firebase_options.dart` unconditionally. Generate
a Firebase configuration before attempting to run or build the project:

```bash
dart pub global activate flutterfire_cli
firebase login
flutterfire configure
```

Select your Firebase project and every platform that you intend to build. The
configuration must generate `lib/firebase_options.dart` and the applicable
platform files:

- Project root: `firebase.json`
- Android: `android/app/google-services.json`
- iOS: `ios/Runner/GoogleService-Info.plist`
- macOS: `macos/Runner/GoogleService-Info.plist`

These generated files are local configuration and must not be committed.

### 2. Authentication values

Application service URLs are defined internally and do not need to be supplied
at compile time. Create the local Dart define file from the provided template:

```bash
cp config/dart_defines.example.json config/dart_defines.json
```

Replace every placeholder in `config/dart_defines.json`:

- `CHESSNUT_TURNSTILE_SITE_KEY`: Cloudflare Turnstile site key
- `GOOGLE_SERVER_CLIENT_ID`: Google OAuth client ID used for server-side token
  verification
- `APPLE_SERVICE_ID`: Sign in with Apple service ID
- `APPLE_REDIRECT_URI`: Apple authentication callback URL
- `CHESSNUT_ANDROID_PACKAGE_NAME`: Android application ID

Pass the file to every Flutter run or build command:

```bash
--dart-define-from-file=config/dart_defines.json
```

### 3. Google Sign-In on Apple platforms

Create the local configuration files from their templates:

```bash
cp ios/Flutter/Secrets.xcconfig.example ios/Flutter/Secrets.xcconfig
cp macos/Flutter/Secrets.xcconfig.example macos/Flutter/Secrets.xcconfig
```

Replace the placeholders in both files:

- `GOOGLE_CLIENT_ID`: OAuth client ID for the corresponding Apple platform
- `GOOGLE_REVERSED_CLIENT_ID`: reversed OAuth client ID
- `GOOGLE_SERVER_CLIENT_ID`: Google OAuth client ID used for server-side token
  verification

The values must match the corresponding Firebase and Google Cloud projects.
Keep both generated `Secrets.xcconfig` files out of Git.

### 4. Application identifiers and Apple signing

Before publishing, replace the existing identifiers with identifiers owned by
your organization:

- Android: update `applicationId` in `android/app/build.gradle.kts`
- iOS: update the Runner bundle identifier in Xcode
- macOS: update the Runner bundle identifier in Xcode

Register the same identifiers in Firebase and in the applicable Google and
Apple developer consoles. The checked-in Apple projects do not define a
Developer Team, so select your own team in Xcode for signed builds.

### 5. Android release signing

Debug builds use the standard Android debug key. Release APK and App Bundle
builds require a local release keystore.

Generate a keystore, then copy the configuration template:

```bash
keytool -genkeypair -v \
  -keystore android/release-keystore.jks \
  -alias release \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000

cp android/key.properties.example android/key.properties
```

Set `storeFile`, `storePassword`, `keyAlias`, and `keyPassword` in
`android/key.properties`. Never commit the keystore, passwords, or local
properties file.

## Run Locally

Connect or select a target device, then run:

```bash
flutter run --dart-define-from-file=config/dart_defines.json
```

## Release Builds

Run the commands below from the project root after completing all required
configuration.

### Android

Build an APK:

```bash
flutter build apk --release \
  --dart-define-from-file=config/dart_defines.json
```

Build an Android App Bundle:

```bash
flutter build appbundle --release \
  --dart-define-from-file=config/dart_defines.json
```

### iOS

> **Code signing is mandatory for iOS device and Release builds.** Configure a
> valid Apple Developer Team, signing certificate, and provisioning profile
> for the Runner target in Xcode before building.

```bash
flutter build ios --release \
  --dart-define-from-file=config/dart_defines.json
```

The `--no-codesign` option cannot produce a deployable iOS Release and does not
remove signing requirements from signing-dependent Xcode build phases. Without
an Apple signing setup, compilation can only be checked with an iOS Simulator
Debug build:

```bash
flutter build ios --simulator --debug \
  --dart-define-from-file=config/dart_defines.json
```

### macOS

```bash
flutter build macos --release \
  --dart-define-from-file=config/dart_defines.json
```

### Windows

```bash
flutter build windows --release \
  --dart-define-from-file=config/dart_defines.json
```

### Linux

```bash
flutter build linux --release \
  --dart-define-from-file=config/dart_defines.json
```

iOS and macOS builds must run on macOS, Windows builds must run on Windows,
and Linux builds must run on Linux.

## License

This project is licensed under the GNU General Public License v3.0. See
[`LICENSE`](LICENSE) for the complete license text. Third-party components
remain subject to their respective licenses.
