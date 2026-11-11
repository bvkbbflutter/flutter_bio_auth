# Changelog

All notable changes to this project will be documented in this file.

## [0.2.0] - Modular Face Intelligence & Zepto Compliance Release

### Core Recognition Engine Fixes & Optimizations

* **Continuous Multi-Frame Scanning with Early Exit**:
  * Fixed premature single-frame authentication failure in `AuthenticationSession.kt` and `BiometricSessions.swift`.
  * Live face verification now scans continuously with immediate early exit upon reaching the confidence threshold (~100–200ms) and tracks the best similarity score across frames.
* **Robust Eye Landmark Geometry Fallback**:
  * Implemented anatomical bounding box eye position fallback (`35%` & `65%` width, `38%` height) in `FaceAlignment.kt`, `FaceAnalyzer.kt`, and `FaceAnalyzer.swift`.
  * Guarantees that face crops never rotate 90° sideways when an eye landmark is obscured by lighting, glasses, or head tilt.
* **Eliminated False Blur Rejections (Frame Starvation)**:
  * Optimized Laplacian blur variance calculation on face crops rather than over-downscaled frames.
  * Calibrated default blur variance threshold to `4.0` so normal live camera frames are never discarded.
* **Calibrated Threshold Alignment**:
  * Unified default recognition threshold to `0.68` across Dart, Android, and iOS.

### Modular `FaceAI` Facade & Developer-Friendly APIs

* Introduced the unified, modular **`FaceAI`** entry point with dedicated subsystems:
  * **`FaceAI.auth` (`AuthenticationService`)**: Local device biometric authentication (Android BiometricPrompt, Apple Face ID / Touch ID) with typed `LocalAuthResult` (`success`, `cancelled`, `lockedOut`, `notEnrolled`, `notAvailable`).
  * **`FaceAI.recognition` (`FaceRecognitionService`)**: 1:1 Live Verification, Template Enrollment, Direct 2-Photo Cosine Matching, and Enrolled Identities Vault.
  * **`FaceAI.expression` (`ExpressionService`)**: Real-time emotion streaming, smile confidence detection, and winking/blinking classification.
  * **`FaceAI.liveness` (`LivenessService`)**: Interactive challenge sequencer (Blink, Turn Left, Turn Right, Smile) and passive anti-spoof checks.
  * **`FaceAI.compliance` (`DeliveryComplianceService`)**: Delivery partner shift onboarding and safety gear inspection.
  * **`FaceAI.models` (`FaceModelManager`)**: Model-agnostic registry supporting bundled asset models, downloaded local models, SHA-256 checksum validation, and on-device latency benchmarking.
  * **`FaceAI.diagnostics`**: Hardware backend delegate reporting (CPU, NNAPI, GPU, Metal/CoreML).

### Zepto / Rider Safety & Uniform Compliance Subsystem

* Added multi-factor rider shift check-in:
  * **Face Verification**: Confirms identity against registered delivery partner profile.
  * **Helmet Detection**: Detects motorcycle helmet presence and headgear coverage.
  * **Mask Detection**: Inspects lower face for mask presence or facial obstruction.
  * **Brand Uniform Detection**: Analyzes torso dominant color profile against presets (`UniformPreset.zeptoPurple` `#5200FF`, `swiggyOrange`, `zomatoRed`, `blinkitYellow`, or custom colors).
* Added turnkey [`DeliveryComplianceView`](lib/src/ui/delivery_compliance_view.dart) widget with live floating status pills and pass/fail cards.

### Turnkey UI & Emotion Widgets

* Added [`DeliveryComplianceView`](lib/src/ui/delivery_compliance_view.dart) for turnkey delivery partner check-in.
* Added [`ExpressionMeterView`](lib/src/ui/expression_meter_view.dart) with live emotion progress bars and emoji indicators.
* Redesigned the example application into 6 dedicated, uncluttered navigation hubs:
  * 🛵 **Zepto / Rider Safety Hub**
  * 👤 **Face Recognition Hub**
  * 😊 **Facial Expression & Mood Hub**
  * 🛡️ **Active & Passive Liveness Hub**
  * 📱 **Local Device Biometrics Hub**
  * ⚙️ **AI Models & Hardware Diagnostics Hub**

---

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
