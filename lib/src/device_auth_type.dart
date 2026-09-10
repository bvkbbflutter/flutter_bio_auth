/// Device-level authentication modality for [FaceBiometric.authenticateWithDeviceBiometrics].
///
/// Under Android and iOS operating system security frameworks:
/// - [biometricOnly]: Any available hardware biometric (Fingerprint or Face).
/// - [strongBiometricOnly]: Class 3 (Strong) biometrics only. On typical Android phones,
///   this is the physical/optical fingerprint sensor and excludes weak 2D face unlock.
/// - [deviceCredentialOnly]: Device lock screen PIN, Pattern, or Password ONLY.
///   Does not prompt for biometrics.
/// - [biometricWithCredential]: Biometrics with fallback to device PIN/Pattern/Password.
enum DeviceAuthType {
  /// Any enrolled biometric (Fingerprint or Face).
  biometricOnly,

  /// Class 3 (Strong) biometrics only. Excludes Class 2 (Weak) 2D camera face unlock.
  strongBiometricOnly,

  /// Device lock credentials only (Pattern, PIN, or Password). Never prompts for biometrics.
  deviceCredentialOnly,

  /// Biometrics with fallback to Pattern, PIN, or Password.
  biometricWithCredential,
}
