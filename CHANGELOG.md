# Changelog

All notable changes to this project will be documented in this file.

## [0.1.0] - Initial Release

### Dart API

* Added the core `FaceBiometric` API.
* Added `FaceBiometricController` for managing authentication flows.
* Added `FaceBiometricConfig` with configuration validation.
* Added comprehensive result, error, and authentication-state types.
* Added pure-Dart reference implementations for:

  * `FaceMatcher`
  * `ChallengeSequencer`
* Added unit tests covering the core Dart components.

### Android

* Added ML Kit-based:

  * Face detection
  * Face tracking
  * Face landmarks
  * Active liveness detection
* Added CameraX-based camera processing pipeline.
* Added injectable TensorFlow Lite interfaces for:

  * `FaceEmbeddingEngine`
  * `AntiSpoofEngine`
* Added fail-closed `Unavailable*` implementations when required AI models are unavailable.
* Added Android Keystore-backed encryption for biometric templates.
* Added AES-GCM encrypted local template storage using `SharedPreferences`.
* Added explicit authentication gates through `AuthenticationEngine`.

### iOS

* Added Vision-based:

  * Face detection
  * Face tracking
  * Face landmarks
  * Active liveness detection
* Added AVFoundation-based camera processing pipeline.
* Added injectable Core ML interfaces for:

  * `FaceEmbeddingEngine`
  * `AntiSpoofEngine`
* Added fail-closed `Unavailable*` implementations when required AI models are unavailable.
* Added iOS Keychain-backed encryption for biometric templates.
* Added AES-GCM encrypted local template storage using `UserDefaults`.
* Added explicit authentication gates through `AuthenticationEngine`.

### Security & Privacy

* Designed biometric processing to run locally on the device.
* Added encrypted biometric template storage.
* Added platform-secure key management using:

  * Android Keystore
  * iOS Keychain
* Added fail-closed behavior when required recognition or anti-spoofing components are unavailable.
* No raw face images are required for biometric template storage.

### Known Limitations

The following items remain incomplete in this initial release:

* `compare()` still-image detection entry point is currently stubbed.
* iOS `lookUp` / `lookDown` pitch support is currently incomplete.
* Recognition and anti-spoofing require compatible AI models to be provided or integrated.
* The implementation still requires validation against real Flutter, Android, and iOS production toolchains and physical devices.

See the **Status / Limitations** section in the README for additional details.
