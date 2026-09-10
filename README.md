# Flutter Bio Auth — Example

This directory contains the example Flutter application for **Flutter Bio Auth**.

The example demonstrates how to integrate the plugin into a Flutter application and test the available authentication features.

---

## Features Demonstrated

The example application demonstrates:

* Device biometric authentication
* Fingerprint authentication
* Face authentication
* Face enrollment
* Face recognition
* Face liveness detection
* Pattern authentication
* Password authentication
* Authentication fallback flows
* Authentication state handling
* Error handling
* Custom Flutter authentication UI

Some features may require compatible device hardware, operating-system capabilities, permissions, and AI models.

---

## Requirements

### Flutter

```text
Flutter >= 3.24.3
Dart >= 3.5.0
```

### Android

```text
Android SDK 21+
```

A physical Android device is recommended for testing camera and biometric functionality.

### iOS

```text
iOS 13.0+
```

A physical iOS device is recommended for testing Face ID, Touch ID, camera, and face-authentication functionality.

---

## Running the Example

From the plugin root directory:

```bash
cd example
```

Install dependencies:

```bash
flutter pub get
```

Run the application:

```bash
flutter run
```

To select a connected device:

```bash
flutter devices
```

Then:

```bash
flutter run -d <device-id>
```

# Dependencies

Flutter Bio Auth uses a small number of open-source packages for its core plugin architecture and cryptographic operations.

### Core Dependencies

| Package                                                                           |  Version | Purpose                                                                                                           |
| --------------------------------------------------------------------------------- | -------: | ----------------------------------------------------------------------------------------------------------------- |
| [`plugin_platform_interface`](https://pub.dev/packages/plugin_platform_interface) | `^2.1.8` | Provides the platform interface architecture used to define and implement platform-specific plugin functionality. |
| [`crypto`](https://pub.dev/packages/crypto)                                       | `^3.0.5` | Provides cryptographic primitives used by the Dart layer for secure authentication-related operations.            |

These dependencies are included automatically when you add `flutter_bio_auth` to your application. You do **not** need to add them separately to your application's `pubspec.yaml`.

```yaml
dependencies:
  flutter_bio_auth: ^0.1.0
```

The plugin's platform-specific implementations may also use native Android and iOS frameworks and libraries for camera processing, face detection, biometrics, secure storage, and AI model execution.


---

# Android Setup

Make sure camera permission is available.

The application requires:

```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.USE_BIOMETRIC"/>
```

For device biometric authentication, configure the test device with at least one supported biometric credential.

For example:

```text
Settings
   ↓
Security
   ↓
Biometrics
   ↓
Enroll Fingerprint / Face
```

The exact settings vary by Android device manufacturer.

---

# iOS Setup

Add the required camera permission to:

```text
ios/Runner/Info.plist
```

```xml
<key>NSCameraUsageDescription</key>
<string>
Camera access is required for face authentication and liveness detection.
</string>
```

For Face ID testing, configure Face ID on the physical device.

The exact behavior depends on the iOS version and device hardware.

---

# Running Tests

From the plugin root:

```bash
flutter analyze
```

Run package tests:

```bash
flutter test
```

You can also run tests from this example directory if example-specific tests are added.

---

# Example Authentication Flow

The example application demonstrates a typical authentication flow:

```text
             Start
               │
               ▼
      ┌─────────────────┐
      │ Choose Method   │
      └────────┬────────┘
               │
       ┌───────┼────────┐
       │       │        │
       ▼       ▼        ▼
    Biometric Face    Pattern
       │       │        │
       │       ▼        │
       │    Liveness    │
       │       │        │
       │       ▼        │
       │    Matching    │
       │       │        │
       └───────┼────────┘
               │
               ▼
          Authentication
               │
        ┌──────┴──────┐
        │             │
        ▼             ▼
      Success       Failure
```

---

# AI Models

Face recognition and passive anti-spoofing require compatible AI models.

The example application may contain model integration points rather than distributing a model.

Before distributing any AI model with your application, verify:

* Model license
* Commercial-use permissions
* Redistribution permissions
* Model input/output requirements
* Accuracy
* Performance
* Security characteristics

Do not assume that a model found online is automatically free to redistribute.

---

# Troubleshooting

### Camera does not start

Check:

1. Camera permission.
2. Physical device connection.
3. Android/iOS permissions.
4. Application logs.
5. Camera availability.

---

### Face recognition is unavailable

Check that a compatible face embedding model has been configured.

Recognition cannot work without a compatible embedding engine/model.

---

### Anti-spoofing is unavailable

Check that a compatible anti-spoofing model has been configured.

If anti-spoofing is enabled and the configured engine is unavailable, authentication may intentionally fail closed.

---

### Device biometric authentication does not appear

Check:

* Device supports biometric authentication.
* A fingerprint/face credential is enrolled.
* Device security credentials are configured.
* Application has the required platform configuration.
* The authentication API is available on the current OS version.

---

# Package Documentation

For complete plugin documentation, configuration, architecture, security information, and API examples, see the main project README:

[`../README.md`](../README.md)

---

# Development

The example application is intended for development and demonstration.

Before using Flutter Bio Auth in a production authentication system, perform appropriate:

* Security testing
* Device testing
* Biometric accuracy testing
* Liveness testing
* Anti-spoofing testing
* Privacy review
* Regulatory review

---

## License

The example application is distributed under the same license as the main Flutter Bio Auth project.

See:

MIT License

Copyright (c) 2026 Vinay Kumar Bantubilli

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.



