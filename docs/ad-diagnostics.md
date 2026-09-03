# Ad diagnostics and optional support ad — 2026-09-03

> Updated owner instruction: remove diagnostic controls before Play upload.
> `AppConfig.diagnosticsEnabled` is now `kDebugMode` only. Release builds cannot
> enable the panel with a Dart define. The earlier diagnostic artifact below is
> superseded and must not be uploaded. Banner/configuration fixes remain.
>
> Replacement: `C:\Users\William Correa\Downloads\Master-ABAP-1.22.0-22.aab`
> (58,558,405 bytes), SHA-256
> `86433DBFF09D4664BB517CE4E0C088EED42509A14518BBAAE13A2EC908ECDC17`.
> Build and bundletool validation passed; upload certificate verified. Binary
> inspection confirms both diagnostic buttons and the internal-build notice are
> absent while the neutral interstitial notice remains. Static analysis passed.
>
> Play upload completed 2026-09-03: version 22 accepted and saved as internal
> release draft 4. Review reports ready to launch, with zero compatibility losses
> versus v21. Not published; awaiting owner choice to release to internal testers.
> Review URL: https://play.google.com/console/u/0/developers/7596077406209875742/app/4975246817148948313/tracks/4701589961207993959/releases/4/review
> Version code 22 is now consumed. Future bundles must use 23 or higher.

## Confirmed findings

- Internal v21 reports ads enabled and consent allowed, but no loaded banner.
- Firebase Remote Config v11 uses `banner_ad_id` / `ad_unit_banner`, ending in
  `1922881632`. The previous shell only read `ads.banner.adUnitId.android`, so
  it used the bundled unit ending in `5430581499` instead. The new resolver
  prioritizes explicit remote values over defaults and supports legacy aliases.
- This proves configuration drift, **not** that either AdMob unit is invalid.
  The actual SDK error must still be collected on the affected device.
- No remote configuration or credentials were changed during this work.

## Changes

- Preserve error code, domain, sanitized message, response ID and attempt times.
- Distinguish loading from loaded; mount only a successfully loaded banner.
- Cancel stale callbacks; time out a banner without SDK callback after 30 seconds.
- Manual retry and process-local Google test-banner comparison. No global test
  mode switch, repeated automatic requests, or live-ad clicks for testing.
- Remove the unrestricted Remote Config dump from About. Diagnostics use an
  allowlist, not a blacklist of credential names.
- The ad is a regular interstitial, **not rewarded**. Neutral notice,
  decline option, Premium check and 90-second cooldown remain enforced.
- Offer it only on `/practice` → `/practice/results` at the trusted app origin,
  not on launch, back navigation or ordinary tab browsing. About contains a
  separate informational disclosure that ads/subscriptions fund the app.
- Removed the proposed "watch to support" CTA before release: AdMob's
  non-rewarded-inventory rules prohibit asking users to view ads for support.
- Enable interstitials in bundled defaults. An explicit remote disable wins.

## Internal build versus production

Diagnostics require `--dart-define=MASTER_ABAP_DIAGNOSTICS=true` in release.
The default release omits them. **Do not promote the diagnostic AAB to production**;
build a higher version without that define after on-device validation.
Play's internal track does not automatically imply a debug build or test ads.

For scoped direct Gradle builds, pass the base64 encoding of
`MASTER_ABAP_DIAGNOSTICS=true` as `-Pdart-defines=...`.

## Device verification

1. Install the new internal build; confirm build 22 in About.
2. In Diagnostics, record `bannerUnit`, `banner.state`, `banner.errorCode`,
   `banner.errorDomain`, `banner.errorMessage`, and `banner.responseId`.
3. Compare with Google test banner. If the test loads but the configured unit
   fails, investigate AdMob unit format, readiness, app-ads.txt and serving limits.
   If both fail, use the SDK error to investigate network/SDK issues. These are
   investigation paths, not confirmed diagnoses.
4. Restore the configured banner with Retry configured banner.
5. Complete a practice session and test ad decline, acceptance and Premium suppression with test ads
   or an AdMob-registered test device. Never click your live ads.

The legacy Remote Config token observed in the user's screenshot must be
reviewed by its owner and revoked if valid. Hiding diagnostics does not make
client-distributed Remote Config a safe place for secrets.

References: [load errors](https://developers.google.com/admob/flutter/ad-load-errors),
[banners](https://developers.google.com/admob/flutter/banner),
[test ads](https://developers.google.com/admob/flutter/test-ads).

Placement wording reviewed against [AdMob program policies](https://support.google.com/admob/answer/48182?hl=en).

## Peer review and validation

- Configuration precedence: explicit remote names beat legacy aliases; aliases
  beat bundled defaults. Missing values preserve defaults. Covered by tests.
- Lifecycle: banner remains absent during loading; errors and missing callbacks
  remain diagnosable; retries invalidate old callbacks; disposal cancels timeout.
- Consent/global disable continue to block requests or display. Premium is
  checked before and after the interstitial notice. No rewards or purchases changed.
- Placement: trusted practice-to-results transition only; unrelated origins,
  launch, Profile-to-results and reverse transitions rejected in tests.
- Full Flutter suite: **60 tests passed**. No physical Android device connected;
  real ad delivery, final layout on-device and the reported production SDK error
  still require installation of the new internal build.
- Final `flutter analyze` and direct `dart analyze lib test`: no issues.
- Gradle release build succeeded; bundletool validation passed; manifest is
  `co.supabap.android`, version `1.22.0` / `22`; upload signer matches the pinned
  original certificate. Jarsigner verified the bundle (same self-signed / JAR
  streaming warnings as the previously accepted v21; bundle not repacked).
- Final AAB binary includes the neutral notice and test-banner controls, and
  does not include the removed "watch to support" invitation.
- Artifact: `C:\Users\William Correa\Downloads\Master-ABAP-1.22.0-22-diagnostics.aab`
  (60,419,104 bytes).
- SHA-256: `30C121AA659D5FAAADCFE6FD1E8DE3CFD784BE67A458398841950C114FF400EE`.
- **Not uploaded or published to Play in this change.** Diagnostic build only.
