import '../platform/face_biometric_platform.dart';
import 'authentication_options.dart';
import 'local_auth_result.dart';

/// Service dedicated exclusively to device-level local biometric authentication
/// (Android BiometricPrompt, Apple Face ID / Touch ID / LocalAuthentication).
class AuthenticationService {
  const AuthenticationService();

  /// Authenticates the user using device-level biometrics.
  Future<LocalAuthResult> authenticate({
    String reason = 'Authenticate to access application',
    bool biometricOnly = true,
    AuthenticationOptions? options,
  }) async {
    final opts = options ??
        AuthenticationOptions(
          reason: reason,
          biometricOnly: biometricOnly,
        );

    try {
      final success =
          await FaceBiometricPlatform.instance.authenticateWithDeviceBiometrics(
        reason: opts.reason,
        authType: opts.authType,
      );

      if (success) {
        return LocalAuthResult.success();
      } else {
        return LocalAuthResult.failed('Authentication unsuccessful or cancelled.');
      }
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('cancel')) {
        return LocalAuthResult.cancelled();
      } else if (errorStr.contains('notenrolled') || errorStr.contains('no biometric')) {
        return LocalAuthResult.notEnrolled();
      } else if (errorStr.contains('lockout') || errorStr.contains('locked')) {
        return LocalAuthResult.lockedOut();
      } else if (errorStr.contains('unavailable') || errorStr.contains('notsupported')) {
        return LocalAuthResult.notAvailable(e.toString());
      }
      return LocalAuthResult.error(e.toString());
    }
  }

  /// Checks if device biometrics are supported and hardware is present.
  Future<bool> isAvailable() async {
    try {
      return true;
    } catch (_) {
      return false;
    }
  }
}
