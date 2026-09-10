# Flutter Bio Auth

<p align="center">
  <img src="assets/flutter_bio_auth_banner.png" alt="Flutter Bio Auth" width="100%">
</p>

<p align="center">
  <strong>Advanced authentication and biometric security for Flutter.</strong>
</p>

<p align="center">
  Face recognition • Liveness detection • Fingerprint • Face ID • Pattern • Password
</p>

<p align="center">

[![pub package](https://img.shields.io/pub/v/flutter_bio_auth.svg)](https://pub.dev/packages/flutter_bio_auth)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-%3E%3D3.24.3-blue.svg)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-%3E%3D3.5.0-blue.svg)](https://dart.dev)

</p>

---

## Overview

**Flutter Bio Auth** is a Flutter authentication plugin designed for applications that require multiple secure authentication methods.

It combines platform-native device authentication with optional on-device face recognition and liveness detection, while allowing the application to provide its own Flutter-based authentication experience.

### Supported authentication methods

* Fingerprint authentication
* Face ID / device face authentication
* Android device biometrics
* iOS Local Authentication
* Face enrollment
* 1:1 face recognition
* Active face liveness detection
* Optional passive anti-spoofing
* Pattern authentication
* Password authentication
* Authentication fallback chains
* Secure local biometric template storage

The plugin is designed with an **offline-first architecture**. Face processing and biometric template operations are intended to remain on the device.

---

## Features

### 🔐 Device Biometrics

Use the secure biometric authentication APIs provided by Android and iOS.

Supported platform authentication may include:

* Fingerprint
* Face authentication
* Touch ID
* Face ID
* Device passcode / PIN / pattern / password fallback where supported by the platform

> Native platform biometric authentication is controlled by the operating system. The plugin does not expose raw fingerprint or Face ID data to Flutter.

---

### 👤 Face Recognition

The plugin provides APIs for:

1. Face enrollment
2. Face template generation
3. Face template storage
4. Face detection
5. Face embedding generation
6. 1:1 face comparison
7. Authentication using a previously enrolled face

A face recognition model can be injected through the plugin's model interfaces.

Example supported model architecture:

```text
Input:
1 × 112 × 112 × 3 RGB

Normalization:
(pixel - 127.5) / 127.5

Output:
192-dimensional embedding

Comparison:
Cosine similarity
```

The recognition model is **not assumed to be part of the platform face detector**.

---

### 🛡️ Liveness Detection

Active liveness challenges can be used to reduce simple presentation attacks.

Example challenges:

* Blink
* Smile
* Turn left
* Turn right
* Look up
* Look down
* Head movement
* Randomized challenge sequences

Example authentication flow:

```text
Camera
   ↓
Face Detection
   ↓
Face Quality Check
   ↓
Liveness Challenge
   ↓
Face Embedding
   ↓
Face Matching
   ↓
Authentication Result
```

> Liveness detection is not a certified Presentation Attack Detection (PAD) system. Security-sensitive applications should independently evaluate the implementation against their threat model.

---

### 🛡️ Passive Anti-Spoofing

An optional anti-spoofing model can be integrated into the authentication pipeline.

The authentication gate can require:

```text
Recognition
    AND
Liveness
    AND
Anti-Spoof
```

If a required security component is unavailable, the authentication flow can fail closed instead of silently bypassing the security gate.

---

### 🔢 Pattern Authentication

Applications can implement a pattern-based authentication fallback.

Example:

```text
Biometric
   ↓
Failed / unavailable
   ↓
Pattern
   ↓
Authenticated
```

Pattern data should be stored securely and should not be stored as plain text.

---

### 🔑 Password Authentication

Password authentication can be used as another fallback mechanism.

Example:

```text
Face / Fingerprint
       ↓
   unavailable
       ↓
     Pattern
       ↓
   unavailable
       ↓
    Password
```

Applications should use secure password hashing rather than storing plaintext passwords.

---

## Architecture

The plugin separates the Flutter API from platform-specific authentication and computer-vision components.

```text
┌──────────────────────────────────────┐
│             Flutter App              │
│                                      │
│   Flutter UI / Authentication Flow   │
└──────────────────┬───────────────────┘
                   │
                   ▼
┌──────────────────────────────────────┐
│          Flutter Bio Auth             │
│                                      │
│  FaceBiometric                       │
│  FaceBiometricController             │
│  FaceBiometricConfig                 │
│  AuthenticationEngine               │
└───────────────┬───────────┬──────────┘
                │           │
        ┌───────▼──────┐ ┌──▼──────────┐
        │   Android    │ │     iOS     │
        │              │ │             │
        │ CameraX      │ │ AVFoundation│
        │ ML Kit       │ │ Vision      │
        │ TFLite       │ │ Core ML     │
        │ Keystore     │ │ Keychain    │
        └──────────────┘ └─────────────┘
```

---

# Installation

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_bio_auth: ^0.1.0
```

Then run:

```bash
flutter pub get
```

---

# Platform Support

| Platform | Support |
| -------- | ------- |
| Android  | ✅       |
| iOS      | ✅       |
| Web      | ❌       |
| Windows  | ❌       |
| macOS    | ❌       |
| Linux    | ❌       |

The current implementation focuses on Android and iOS.

---

# Android Setup

## Minimum requirements

The plugin targets:

```text
Android minSdk: 21
compileSdk: 34
```

Ensure your application has camera permission:

```xml
<uses-permission android:name="android.permission.CAMERA" />
```

Request the camera permission at runtime before starting face authentication.

---

# iOS Setup

Add the following permission to:

```text
ios/Runner/Info.plist
```

```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required for face authentication and liveness detection.</string>
```

Recommended deployment target:

```text
iOS 13.0+
```

---

# Basic Usage

Import the package:

```dart
import 'package:flutter_bio_auth/flutter_bio_auth.dart';
```

Create a configuration:

```dart
final config = FaceBiometricConfig(
  recognitionThreshold: 0.82,
  livenessThreshold: 0.80,
  antiSpoofThreshold: 0.80,
  enableLiveness: true,
  enableAntiSpoofing: true,
);
```

Initialize the authentication controller:

```dart
final controller = FaceBiometricController(
  config: config,
);
```

---

# Device Biometric Authentication

For Android/iOS system biometrics:

```dart
final result =
    await FaceBiometric.authenticateWithDeviceBiometrics();

if (result.isAuthenticated) {
  // Authentication successful
} else {
  // Authentication failed
}
```

The underlying platform authentication UI and secure biometric operation remain controlled by Android/iOS.

---

# Face Enrollment

A typical enrollment flow is:

```text
Start Enrollment
       ↓
Open Camera
       ↓
Detect Face
       ↓
Check Face Quality
       ↓
Perform Liveness
       ↓
Generate Face Embedding
       ↓
Encrypt Template
       ↓
Store Template
```

Example:

```dart
final result = await FaceBiometric.enroll(
  userId: 'user-123',
);

if (result.isSuccess) {
  print('Face enrolled successfully');
}
```

> Exact API signatures may change during the 0.x development releases.

---

# Face Authentication

After enrollment:

```dart
final result = await FaceBiometric.authenticate(
  userId: 'user-123',
);

if (result.isAuthenticated) {
  print('Face authentication successful');
}
```

The authentication pipeline can evaluate:

```text
Face Detection
      ↓
Face Quality
      ↓
Liveness
      ↓
Anti-Spoof
      ↓
Embedding
      ↓
1:1 Matching
      ↓
Authentication
```

---

# Face Comparison

The package provides a face matching abstraction for comparing face embeddings.

Conceptually:

```text
Enrolled Template
       +
Current Face
       ↓
Face Embedding
       ↓
Cosine Similarity
       ↓
Threshold
       ↓
Match / No Match
```

Example:

```dart
final similarity = FaceMatcher.cosineSimilarity(
  enrolledEmbedding,
  currentEmbedding,
);

final matched = similarity >= 0.82;
```

---

# Authentication Fallback

Multiple authentication methods can be combined into a fallback strategy.

For example:

```text
┌─────────────────┐
│ Face / Biometric│
└────────┬────────┘
         │
    Failed/Unavailable
         ↓
┌─────────────────┐
│     Pattern     │
└────────┬────────┘
         │
    Failed/Unavailable
         ↓
┌─────────────────┐
│     Password    │
└─────────────────┘
```

Applications can customize the authentication order according to their requirements.

---

# Secure Storage

Biometric templates should never be stored as raw face images unless the application explicitly requires this for another purpose.

The intended storage architecture is:

```text
Face
 ↓
Embedding
 ↓
Encryption
 ↓
Secure Local Storage
```

### Android

```text
Android Keystore
       ↓
Encryption Key
       ↓
AES-GCM
       ↓
Encrypted Template
       ↓
SharedPreferences
```

### iOS

```text
iOS Keychain
      ↓
Encryption Key
      ↓
AES-GCM
      ↓
Encrypted Template
      ↓
Local Storage
```

The plugin is designed to avoid storing raw facial images as biometric templates.

---

# AI Model Integration

Face recognition and passive anti-spoofing are model-dependent components.

The plugin provides injectable interfaces so applications can integrate compatible models.

Example:

```text
FaceEmbeddingEngine
        │
        └── TensorFlow Lite / Core ML model

AntiSpoofEngine
        │
        └── TensorFlow Lite / Core ML model
```

### Android

Possible model runtime:

```text
TensorFlow Lite
```

### iOS

Possible model runtime:

```text
Core ML
```

The application must ensure that any model it distributes has appropriate licensing and redistribution rights.

---

# Recognition Threshold

Face recognition typically uses cosine similarity.

For example:

```dart
recognitionThreshold: 0.82
```

The appropriate threshold depends on:

* Recognition model
* Dataset
* Camera quality
* Lighting
* Enrollment process
* Device characteristics
* False acceptance requirements
* False rejection requirements

**Do not treat `0.82` as a universal biometric security threshold.**

Applications handling sensitive authentication should calibrate the threshold against representative data and their required security level.

---

# Security

The plugin follows a security-oriented architecture:

* On-device processing
* Encrypted biometric templates
* Android Keystore integration
* iOS Keychain integration
* AES-GCM encrypted storage
* Fail-closed model availability
* Explicit authentication gates
* No requirement to upload face data to a server
* No raw face image storage for biometric templates

### Authentication Gate

A strong authentication configuration can require:

```text
Recognition == PASS
        AND
Liveness == PASS
        AND
AntiSpoof == PASS
```

If any required condition fails:

```text
Authentication = FAILED
```

---

# Privacy

Face recognition and liveness processing are designed to operate locally on the device.

The plugin does not require a cloud service for its core face authentication pipeline.

Applications are responsible for:

* Obtaining appropriate user consent
* Providing privacy disclosures
* Handling biometric data according to applicable laws
* Implementing appropriate data deletion mechanisms
* Choosing suitable retention policies

---

# UI

The plugin is designed to work with a Flutter-controlled authentication experience.

A typical face authentication interface may include:

```text
┌──────────────────────────────┐
│                              │
│       Face Authentication    │
│                              │
│        ┌────────────┐        │
│        │            │        │
│        │    FACE    │        │
│        │            │        │
│        └────────────┘        │
│                              │
│       Blink to continue      │
│                              │
│       ● ● ○ ○ ○              │
│                              │
└──────────────────────────────┘
```

Applications can build their own Flutter UI around the authentication controller and state/result APIs.

> Android system biometric authentication remains subject to Android's native biometric UI and security model.

---

# Error Handling

Authentication operations should always be treated as potentially unsuccessful.

Example:

```dart
final result = await FaceBiometric.authenticate(
  userId: 'user-123',
);

switch (result.status) {
  case AuthenticationStatus.authenticated:
    // Success
    break;

  case AuthenticationStatus.failed:
    // Authentication failed
    break;

  case AuthenticationStatus.cancelled:
    // User cancelled
    break;

  case AuthenticationStatus.unavailable:
    // Authentication method unavailable
    break;

  default:
    // Handle other states
    break;
}
```

---

# Testing

Run static analysis:

```bash
flutter analyze
```

Run tests:

```bash
flutter test
```

Run the example application:

```bash
cd example
flutter pub get
flutter run
```

For release validation, test on physical Android and iOS devices with:

* Different camera conditions
* Different lighting conditions
* Multiple face angles
* Multiple users
* Enrolled and non-enrolled users
* Authentication cancellation
* Camera permission denial
* Biometric lockout
* Device biometric changes
* Model unavailable scenarios
* Network disabled scenarios

---

# Example Project

The repository contains an example application demonstrating the plugin.

```text
example/
├── lib/
│   └── main.dart
├── android/
├── ios/
└── pubspec.yaml
```

Run it with:

```bash
cd example
flutter run
```

---

# Project Structure

```text
flutter_bio_auth/
│
├── android/
│   └── src/main/
│       └── kotlin/
│
├── ios/
│   └── Classes/
│
├── lib/
│   ├── flutter_bio_auth.dart
│   ├── src/
│   │   ├── models/
│   │   ├── services/
│   │   ├── engines/
│   │   ├── storage/
│   │   └── ...
│
├── example/
│
├── test/
│
├── assets/
│   └── flutter_bio_auth_banner.png
│
├── CHANGELOG.md
├── LICENSE
├── README.md
└── pubspec.yaml
```

---

# Limitations

This package is currently in the **0.x development stage**.

Some functionality may require additional platform-specific testing or compatible AI models.

In particular:

* Face recognition requires a compatible embedding model.
* Passive anti-spoofing requires a compatible anti-spoofing model.
* Model accuracy depends on the selected model and threshold calibration.
* Active liveness detection should not be considered a certified security product.
* Platform biometric authentication behavior is controlled by Android and iOS.
* Physical-device testing should be performed before production deployment.

---

# Roadmap

Planned improvements may include:

* [ ] Improved face alignment
* [ ] Additional face recognition model integrations
* [ ] Additional anti-spoofing model integrations
* [ ] Improved liveness challenge detection
* [ ] More authentication fallback strategies
* [ ] Improved biometric template lifecycle management
* [ ] Expanded Android device compatibility
* [ ] Expanded iOS device compatibility
* [ ] More comprehensive physical-device test coverage
* [ ] Performance optimizations
* [ ] Improved developer documentation

---

# Contributing

Contributions, bug reports, feature requests, and improvements are welcome.

Before submitting a pull request:

```bash
flutter analyze
flutter test
```

Please include appropriate tests for new functionality.

---

# Security Issues

Please do not publicly disclose security vulnerabilities through GitHub issues.

For security-related issues, please contact the project maintainer privately.

See [`SECURITY.md`](SECURITY.md) for the security reporting process.

---

# License

This project is licensed under the **MIT License**.

See the [`LICENSE`](LICENSE) file for details.

---

# Disclaimer

This package is provided as an open-source software library and is not a certified biometric security product.

Applications using this package for high-security authentication should perform their own:

* Security assessment
* Threat modeling
* Biometric accuracy evaluation
* Presentation-attack evaluation
* Device compatibility testing
* Privacy and regulatory review

The package should not be represented as providing certified biometric authentication unless the complete deployed system has been independently evaluated and certified.

---

## Support

If you find a bug or have a feature request, please open an issue in the project repository.

If you find this package useful, consider giving the project a ⭐ on GitHub.
