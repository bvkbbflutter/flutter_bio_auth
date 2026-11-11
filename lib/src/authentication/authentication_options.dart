import '../device_auth_type.dart';

/// Options for local device biometric authentication.
class AuthenticationOptions {
  const AuthenticationOptions({
    this.reason = 'Authenticate to access application',
    this.biometricOnly = true,
    this.stickyAuth = true,
    this.authType = DeviceAuthType.biometricOnly,
    this.cancelButtonText = 'Cancel',
  });

  /// The reason string shown to the user in the native biometric prompt dialog.
  final String reason;

  /// Whether to only allow strong/weak biometrics without falling back to PIN/Pattern/Password.
  final bool biometricOnly;

  /// Whether to preserve authentication state across app lifecycle changes.
  final bool stickyAuth;

  /// Specific authenticator combination on Android/iOS.
  final DeviceAuthType authType;

  /// Custom text for the cancel/negative button.
  final String cancelButtonText;
}
