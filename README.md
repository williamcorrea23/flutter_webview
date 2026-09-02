# Master ABAP Mobile App

A professional Flutter WebView application for Android and iOS with AdMob monetization and Firebase integration.

## 📱 Features

- 🌐 **WebView Integration** - Seamless loading of https://supabapnew.vercel.app
- 💰 **AdMob Monetization** - Banner and interstitial ads with remote control
- 🔥 **Firebase Integration** - Analytics, Remote Config, and real-time updates
- ⚙️ **Admin Dashboard** - Remote configuration management
- 📱 **Cross-Platform** - Works on Android and iOS
- 🚀 **Auto-Build** - GitHub Actions for analysis, tests and APK generation

## 🔧 Technical Stack

- **Flutter 3.44.1** with null safety
- **Firebase Core** for backend services
- **Google Mobile Ads** for monetization
- **WebView Flutter** for web content
- **Riverpod** for state management
- **Connectivity Plus** for network detection

## 🚀 Quick Start

This app is ready to build! Choose your preferred method:

### 📱 Android APK
1. **GitHub Actions** (Recommended) - Automatic builds on every commit
2. **Local Build** - Requires Android Studio installation
3. **Online Services** - Use Codemagic.io or App Center

### 🍎 iOS App
1. **Xcode** - Requires macOS and Xcode installation
2. **Online Services** - Use Codemagic.io for cloud builds

## 📁 Project Structure

```
lib/
├── main.dart                    # App entry point
├── core/
│   ├── config/
│   │   ├── app_config.dart     # Environment configuration
│   │   └── firebase_options.dart
│   └── services/
│       ├── ads_service.dart     # AdMob integration
│       ├── consent_service.dart # GDPR compliance
│       └── remote_config_service.dart
├── features/
│   ├── webview/
│   │   ├── pages/
│   │   │   └── webview_page.dart
│   │   └── widgets/
│   │       ├── banner_ad_widget.dart
│   │       ├── offline_page_widget.dart
│   │       └── progress_indicator_widget.dart
│   └── about/
│       └── pages/
│           └── about_page.dart
└── shared/
    ├── constants/
    │   └── app_constants.dart
    └── theme/
        └── app_theme.dart
```

## 🔧 Configuration

### Firebase Setup
1. Add your `google-services.json` to `android/app/`
2. Add your `GoogleService-Info.plist` to `ios/Runner/`
3. Configure Firebase project in console

### AdMob Setup
1. Replace `ca-app-pub-3940256099942544~3347511713` with your AdMob App ID
2. Update banner and interstitial ad unit IDs
3. Configure ad frequency via Firebase Remote Config

## 🚀 Building

### Android
```bash
flutter analyze
flutter test
flutter build appbundle --release
```

Play upload identity: **Master ABAP**, package `co.supabap.android`.
Version `1.21.0+21` follows the published `1.20 (20)` verified on 2026-09-02.
Flutter requires three numeric segments in the build name.
Before every upload, recheck all uploaded versions in Play Console (including
drafts); a versionCode cannot be reused. Update `pubspec.yaml` and the baseline
in `android/play-release.properties` after each successful upload.

Configure the **existing Play upload keystore** using
`android/key.properties.example` as a reference for the gitignored
`android/key.properties`. Do not overwrite existing private configuration
without backing it up. `storeFile` is relative to `android/app/`; an absolute
path with forward slashes works on Windows. Never commit passwords or keystores.
CI uses all four `ANDROID_KEYSTORE_*` / `ANDROID_KEY_*` secrets instead.
Pushes and pull requests run tests and generate only a clearly labelled debug
APK. Signed AAB generation and the GitHub Release require manually dispatching
the Android workflow with `release=true` from `main`. Do that only after the
active Play upload certificate, the local pin and all four CI signing secrets
have been verified. Missing or partial secrets fail that manual release run.
The build job has read-only repository permission; only the separate, gated
GitHub Release job can publish an artifact. Neither job uploads to Google Play.

`verifyPlayRelease` automatically checks the package, versionCode and actual
keystore certificate for every release build. An absent, partial or wrong key
fails the build; it never falls back to a debug signature. To run just the
preflight, run `./gradlew :app:verifyPlayRelease` from `android/`
(`.\gradlew.bat :app:verifyPlayRelease` in PowerShell).

Successful output: `build/app/outputs/bundle/release/app-release.aab`.
On Windows, use an Android SDK path without spaces. The SDK's `apkanalyzer.bat`
does not quote one JVM argument correctly when its own path contains spaces;
Flutter then reports a misleading native debug-symbol stripping failure after
Gradle has already created the bundle. A directory junction can expose the same
SDK without moving it. Flutter's global `android-sdk` setting takes precedence
over `ANDROID_HOME` / `ANDROID_SDK_ROOT` and can overwrite `sdk.dir` in the
gitignored `android/local.properties`. Changing only those environment variables
does not fix that case. To leave other projects and the global Flutter setting
untouched, set `sdk.dir` locally to the no-space junction and run
`.\gradlew.bat :app:verifyPlayRelease :app:bundleRelease --console=plain --max-workers=2`
from `android/`. Then verify the AAB signature and manifest, run
`bundletool validate`, and use the junction's `apkanalyzer.bat files list` to confirm both
`libapp.so.sym` and `libflutter.so.sym` metadata are present. This is a direct
Gradle build with separate post-build checks, not a successful `flutter build`
invocation. Do not modify Flutter's checks or discard debug-symbol metadata.
Without the registered key, use `flutter build apk --debug` only for local
testing. Debug and upload-signed APKs are not replacements for a Play-signed
installation. CI separates debug APK artifacts from upload-ready AAB artifacts;
GitHub release names use the actual version in `pubspec.yaml`.

### Signing verification status (2026-09-02)

- Play upload SHA-256: `FA:0C:F6:AD:3C:0A:2A:A7:47:5E:17:C7:02:B7:15:35:B9:EC:BA:42:47:C4:97:95:A1:A5:FF:04:58:32:F5:B7`.
- Play distribution SHA-256: `CD:F9:FE:77:74:2E:C3:89:DD:C0:A0:7D:DB:B5:28:FE:26:18:C1:DE:E9:4C:14:70:A9:DC:D8:4F:F3:3E:03:E2`.
- The repo-root `android.keystore` is **not** the registered upload key (SHA-256 starts `90:86:1D:4D`) and remains unused. The owner recovered the original keystore on 2026-09-02; its private key was validated and its certificate matches the upload pin exactly. The pending reset was cancelled with owner approval, and a refreshed Play Console again displays `FA:0C:F6:AD:…:F5:B7`. The previous 2026-09-04 activation wait no longer applies. Local signing now points to a protected copy outside Git, and all four GitHub signing secrets have been updated. The unused replacement key is retained separately, not selected for builds.
- The owner also upgraded the Play distribution key on 2026-09-02. The original key still covers 100% of the installed base; the upgraded key is shown as in use with 0% of installations. Upgraded SHA-256: `A0:EC:9D:4F:97:E7:61:48:11:F6:7D:01:D2:29:27:C0:1F:68:5B:10:F1:59:CC:31:95:62:F1:48:91:27:2F:16`.
- Firebase Android app `1:838743198796:android:2cfa3b92d3c0241eb6b8e9` in `abap-aed31` now contains SHA-1 and SHA-256 for both the original and upgraded Play signers. Original SHA-1: `DC:0A:18:50:A8:7E:FB:E4:5E:45:F6:EB:4F:DF:61:5C:97:17:D0:6A`. Upgraded SHA-1: `4C:AA:E9:42:49:6F:C1:9E:6A:7C:0C:8C:3B:9D:9E:EC:B7:D3:A1:AE`, copied from Play and supplied by the owner after both download buttons returned the original certificate. All four additions were read back successfully, and both pre-existing Firebase fingerprints were preserved (six total).
- The official Firebase export now includes Android OAuth clients for both Play SHA-1 fingerprints, including client `838743198796-47qelpjq33adlpme9n4f9sd144dld2re.apps.googleusercontent.com` for the upgraded signer. Registration is complete; real Google sign-in on a Play-installed build still requires device testing.
- Both local and CI `google-services.json` files have been refreshed from the official Firebase export. The existing web OAuth client and Firebase app/project identifiers are unchanged. The exported Android OAuth clients replace stale entries in the local JSON; no existing server-side certificate or OAuth client was deleted. Test Google login in a Play-installed build after the next Play release.
- Subscription IDs remain `supabap_premium_monthly` and `supabap_premium_annual`; changing the display name does not rename existing billing products.

The earlier native/build peer review followed the Karpathy surgical-change
guideline. The earlier Firebase follow-up only added verified fingerprints and updated
public configuration, documentation and regression tests. It did not change
private signing material, Play settings or billing prices at that stage.
Earlier validation: 47 Flutter tests passed, including four release-identity checks;
static analysis passed. The real release command rejected the incompatible
local certificate as expected; partial signing environment values were also
rejected. The debug APK built successfully, and Android manifest inspection
confirmed `Master ABAP`, `co.supabap.android`, `1.21.0 (21)` and target SDK 36.
This debug APK is not an upload artifact. At that stage, successful AAB signing
and Play acceptance remained unverified because the registered upload key was
not yet configured.

Firebase follow-up validation: 49 Flutter tests passed, including checks that
the local and CI configurations are identical, both Play SHA-1 fingerprints have
Android OAuth clients, and the existing web OAuth client is preserved. Both JSON
files match the official Firebase export. No release was uploaded or published;
the device sign-in test remains pending.
`dart analyze lib test` reported no issues. Gradle
`:app:processDebugGoogleServices` succeeded, and its generated Android resources
contain the expected Firebase app ID and unchanged web OAuth client. Existing
Kotlin/Gradle deprecation warnings remain outside this certificate-only change.

Original-key recovery validation: all 49 Flutter tests passed again. The direct
Gradle `:app:verifyPlayRelease :app:bundleRelease` build succeeded, including
release lint and signing. The final AAB identifies `Master ABAP`,
`co.supabap.android`, `1.21.0 (21)` and the registered original upload certificate.
`jarsigner -verify` and `bundletool validate` both exited successfully. The
no-space SDK junction's `apkanalyzer` also succeeded and confirmed the app and
Flutter native libraries and symbol metadata for arm64-v8a, armeabi-v7a and x86_64.
The JDK verifier still reports the self-signed certificate, missing timestamp
and a JarFile/JarInputStream manifest-order warning; these checks do not establish
Play acceptance. The bundle was not repacked or manually re-signed.
The verified local bundle is 58,648,656 bytes, SHA-256
`86CC173970EBB57C7DF221A72E13C79E9DAEFC236832257C0DB867F0F7D2C59C`.
A byte-identical copy was saved as `Downloads/Master-ABAP-1.21.0-21.aab`.
No AAB has been uploaded to Play in this follow-up, no signed CI release was
dispatched, and device Google sign-in and purchase/restore remain untested.
The global Windows Flutter SDK-path issue described above is still present;
only the direct Gradle route with separate validation succeeded.

Sources: [Play Console certificates](https://play.google.com/console/u/0/developers/7596077406209875742/app/4975246817148948313/keymanagement),
[Play App Signing](https://support.google.com/googleplay/android-developer/answer/9842756),
[Flutter Android release guide](https://docs.flutter.dev/deployment/android).

### iOS
```bash
flutter build ios --release
```

## 📊 Analytics

The app includes comprehensive analytics:
- Screen views and user interactions
- Ad performance metrics
- Crash reporting
- Custom events for business insights

## 🎯 Monetization

AdMob integration includes:
- **Banner Ads** - Non-intrusive bottom banners
- **Interstitial Ads** - Full-screen ads at natural breaks
- **Remote Control** - Enable/disable ads via Firebase
- **GDPR Compliance** - UMP consent management

## 🔒 Privacy

- GDPR compliant with UMP consent forms
- Privacy policy integration
- Data protection measures
- User consent management

## 📱 Supported Platforms

- **Android** 5.0+ (API level 21+)
- **iOS** 11.0+

## 🏗️ Architecture

Built with clean architecture principles:
- **Separation of Concerns** - Clear layer separation
- **Dependency Injection** - Using Riverpod
- **State Management** - Reactive programming
- **Error Handling** - Comprehensive error management

## 🚀 Deployment

### Google Play Store
1. Build signed AAB: `flutter build appbundle --release`
2. Upload to Google Play Console
3. Configure store listing and pricing

### App Store
1. Build iOS archive in Xcode
2. Upload to App Store Connect
3. Configure app metadata and submit for review

## 📈 Performance

Optimized for performance:
- Lazy loading of web content
- Efficient memory management
- Minimal app size
- Fast startup times

## 🔧 Maintenance

The app includes:
- Remote configuration capabilities
- Over-the-air updates for web content
- Analytics for monitoring performance
- Crash reporting for quick issue resolution

## 📞 Support

For support and updates:
- Repository: https://github.com/williamcorrea23/flutter_webview
- Website: https://supabapnew.vercel.app
- Issues: GitHub Issues tracker

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

**Built with ❤️ for Master ABAP**
