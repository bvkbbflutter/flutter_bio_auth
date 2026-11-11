# Changelog

All notable changes to this project will be documented in this file.

## [0.2.1] - Face Enrollment, Mood Hub, Delivery Compliance & Pluggable Models Overhaul

### Face Enrollment & Detection Status
* **Vibrant Green Face Detection Reticle**: Replaced yellow indicator with high-visibility vibrant green bounding reticle (`#00E676` / `Colors.greenAccent`) immediately upon face detection and throughout enrollment.
* **Resolved Enrollment Challenge Freeze**: Fixed issue where `EnrollmentSession` was waiting for liveness challenges without emitting instructions to Flutter. `emitChallengeProgress` is now wired properly.
* **Fast vs. Guided Enrollment**: Added `enableLiveness` flag (`false` by default for rapid 5-sample enrollment, or `true` for guided liveness challenges).
* **Calibrated Face Quality Gates**: Widened centering tolerance to 0.40 and frontal yaw/pitch thresholds to 36° to eliminate false rejections under normal lighting and angles.

### Facial Expressions & Mood Hub
* **Native Face Telemetry Stream**: Implemented real-time face detection stream (`startFaceDetection` / `stopFaceDetection` and `detectionStream`) bridging native ML Kit face analysis (smiling probability, left/right eye openness, head angles) directly into Flutter.
* **Live Emotion Pipeline**: Updated `ExpressionService` to consume live telemetry with accurate classification of `smile`, `neutral`, `blink`, and `wink` with dynamic confidence scoring.
* **Interactive Mood UI**: Wired `ExpressionMeterView` with dynamic progress bars, dominant emotion gauge, and real-time response.

### Automatic Unique ID Generation
* **Automatic ID Generation**: Implemented automatic unique ID generation (`USR_<timestamp_base36>_<random>`) for every new user entry.
* **Flexible Custom Names**: Custom user name field is now optional; if provided, it is automatically concatenated as `"${custom}_${autoId}"`, or uses `autoId` directly if left empty.
* **Regenerate & Inspect**: Added instant ID regeneration action and dedicated ID badge UI card in the enrollment screen.

### Delivery Partner Compliance Overhaul
* **Live Camera Torso Color Sampling**: Implemented real-time sampling of the rider's chest/torso region directly below the chin in `FaceBiometricPlugin.kt`. Native engine now calculates true upright RGB values (`torsoR`, `torsoG`, `torsoB`) and streams them live to Flutter.
* **Strict Brand Uniform Verification**: Fixed issue where the target uniform color was previously being fed back as the observed color. Live clothing color is now evaluated against calibrated HSV ranges; non-compliant clothing (such as blue shirts) is strictly rejected for Zepto (Purple), Swiggy (Orange), Zomato (Red), and Blinkit (Yellow).
* **Live Detected Shirt vs. Target Swatch**: Added a real-time comparison card in `DeliveryComplianceView` displaying a circular swatch of the detected clothing color, human-readable color family description, hex code, and a dynamic `[MATCH]` or `[MISMATCH]` status badge.
* **Visible Camera Feed**: Redesigned the inspection view to keep the live camera feed clearly visible with green face reticle throughout the check-in process.
* **No Premature Auto-Dismiss**: Eliminated arbitrary 1.2s auto-dismiss timer; requires explicit "Complete Shift Check-In" tap after passing all safety checks.
* **Motorcycle Presence Detection**: Added motorcycle stance and vehicle presence validation with configurable thresholds (`requireMotorcycle`, `minMotorcycleConfidence`).
* **Granular Results & Reasons**: Added detailed reason strings (`uniformReason`, `helmetReason`, `motorcycleReason`, `faceReason`, `maskReason`) and status badges for each compliance gate.
* **Live Test Mode**: Added an interactive "Simulate Non-Compliant Uniform" toggle in the UI to verify real-time rejection handling.

### Turnkey UI & Material Tree Hardening
* **Material Hierarchy Fix**: Wrapped `FaceBiometricScanner` in `Material(color: Colors.black, ...)` and wrapped its close button in `Material(color: Colors.transparent, shape: const CircleBorder(), child: InkWell(...))` to permanently eliminate `No Material widget found` exceptions when opened in standalone routes or dialogs.
* **Header Flex Overflow Fix**: Restructured the guidance header bar using `Expanded` and `Text(overflow: TextOverflow.ellipsis, maxLines: 1)` to prevent `RenderFlex` layout overflow across all screen sizes.
* **Turnkey View Resilience**: Wrapped `FaceSmileView`'s error and result cards in `Material` and safe area.
* **Upfront Camera Permission**: Added upfront `Permission.camera.request()` during initial application launch in `example/lib/main.dart` so all camera features are immediately accessible without secondary prompts.

### AI Models & Diagnostics Hub & Model Selection
* **Multi-Model Catalog**: Registered multiple AI models out of the box (MobileFaceNet 192-d, ArcFace Mobile 512-d, FaceNet Mobile 128-d, MiniVision Anti-Spoof, EmotionNet Expression).
* **Interactive Model Switcher**: Added a model selection bottom sheet allowing users to view metadata, switch active models, and benchmark inference latency.
* **Persistent Model Preference**: Persisted selected active model across app restarts via `SharedPreferences`.
* **Native Runtime Sync**: Connected `switchModel` across platform channels so native TFLite interpreters dynamically update input shapes and embedding dimensions.
* **Responsive Layouts**: Replaced fixed button rows with responsive `Wrap` layouts to prevent UI overflow across all mobile screen sizes.

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
