enum FaceBiometricErrorCode {
  cameraPermissionDenied,
  cameraUnavailable,
  faceNotDetected,
  multipleFacesDetected,
  faceTooSmall,
  faceTooLarge,
  faceNotCentered,
  poorFaceQuality,
  modelUnavailable,
  modelInitializationFailed,
  embeddingGenerationFailed,
  templateNotFound,
  templateDecryptionFailed,
  livenessFailed,
  antiSpoofFailed,
  faceMismatch,
  timeout,
  storageError,
  encryptionError,
  platformError,
  invalidConfiguration,
  notInitialized,
}

/// The single exception type thrown across the public Dart API.
/// Native exceptions are always mapped into one of these by the
/// platform interface — raw `PlatformException`s never escape to
/// application code.
class BiometricError implements Exception {
  const BiometricError(this.code, this.message, {this.nativeDetails});

  final FaceBiometricErrorCode code;
  final String message;

  /// Non-sensitive diagnostic string from the native side, if any.
  /// Never contains frame data, embeddings, or key material.
  final Object? nativeDetails;

  @override
  String toString() => 'BiometricError(${code.name}): $message';
}
