/// Detailed status of a local device biometric authentication attempt
/// (Android BiometricPrompt or iOS LocalAuthentication).
enum LocalAuthStatus {
  success,
  failed,
  cancelled,
  notAvailable,
  notEnrolled,
  lockedOut,
  error,
}

/// Typed result returned by local device biometric authentication.
class LocalAuthResult {
  const LocalAuthResult({
    required this.status,
    this.message,
    this.authenticatedAt,
  });

  final LocalAuthStatus status;
  final String? message;
  final DateTime? authenticatedAt;

  bool get isSuccess => status == LocalAuthStatus.success;

  factory LocalAuthResult.success() => LocalAuthResult(
        status: LocalAuthStatus.success,
        authenticatedAt: DateTime.now(),
      );

  factory LocalAuthResult.failed([String? message]) => LocalAuthResult(
        status: LocalAuthStatus.failed,
        message: message,
      );

  factory LocalAuthResult.cancelled() => const LocalAuthResult(
        status: LocalAuthStatus.cancelled,
        message: 'Authentication was cancelled by user or system.',
      );

  factory LocalAuthResult.notEnrolled() => const LocalAuthResult(
        status: LocalAuthStatus.notEnrolled,
        message: 'No biometrics or credentials are enrolled on this device.',
      );

  factory LocalAuthResult.lockedOut() => const LocalAuthResult(
        status: LocalAuthStatus.lockedOut,
        message:
            'Device biometric authentication is locked out due to too many failed attempts.',
      );

  factory LocalAuthResult.notAvailable([String? message]) => LocalAuthResult(
        status: LocalAuthStatus.notAvailable,
        message:
            message ?? 'Biometric authentication hardware is not available.',
      );

  factory LocalAuthResult.error(String message) => LocalAuthResult(
        status: LocalAuthStatus.error,
        message: message,
      );

  @override
  String toString() => 'LocalAuthResult(status: $status, message: $message)';
}
