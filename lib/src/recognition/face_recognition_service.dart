import 'dart:typed_data';

import '../face_authentication_result.dart';
import '../face_enrollment_result.dart';
import '../face_match_result.dart';
import '../platform/face_biometric_platform.dart';
import 'face_comparison_result.dart';
import 'recognition_options.dart';

/// Service for 1:1 face verification, enrollment, and direct image comparison.
class FaceRecognitionService {
  const FaceRecognitionService();

  /// Enrolls a user's face identity into encrypted on-device template storage.
  Future<FaceEnrollmentResult> enrollFace({
    required String userId,
    RecognitionOptions? options,
  }) {
    return FaceBiometricPlatform.instance.enroll(
      userId: userId,
      enableLiveness: options?.enableLiveness,
    );
  }

  /// Verifies a captured face against the previously enrolled template of [userId].
  Future<FaceAuthenticationResult> verifyFace({
    required String userId,
    RecognitionOptions? options,
  }) {
    return FaceBiometricPlatform.instance.authenticate(
      userId: userId,
      enableLiveness: options?.enableLiveness,
    );
  }

  /// Compares two still face images directly (JPEG/PNG bytes) through the
  /// face recognition embedding model without using the live camera.
  Future<FaceComparisonResult> compareFaces({
    required Uint8List firstImage,
    required Uint8List secondImage,
    double threshold = 0.68,
  }) async {
    final FaceMatchResult result =
        await FaceBiometricPlatform.instance.compare(
      firstImage: firstImage,
      secondImage: secondImage,
    );
    return FaceComparisonResult.fromMatchResult(result);
  }

  /// Checks if [userId] is enrolled in the local template database.
  Future<bool> isEnrolled({required String userId}) {
    return FaceBiometricPlatform.instance.isEnrolled(userId: userId);
  }

  /// Lists all enrolled user identifiers.
  Future<List<String>> getEnrolledUsers() {
    return FaceBiometricPlatform.instance.getEnrolledUsers();
  }

  /// Deletes enrollment for [userId].
  Future<void> deleteEnrollment({required String userId}) {
    return FaceBiometricPlatform.instance.deleteEnrollment(userId: userId);
  }

  /// Clears all stored face templates.
  Future<void> clearAllEnrollments() {
    return FaceBiometricPlatform.instance.clearAllEnrollments();
  }
}
