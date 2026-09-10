/// Normalized [0,1] bounding box, relative to frame width/height, so
/// Dart never needs to know the native frame resolution.
class FaceBoundingBox {
  const FaceBoundingBox({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  factory FaceBoundingBox.fromMap(Map<Object?, Object?> map) {
    return FaceBoundingBox(
      left: (map['left']! as num).toDouble(),
      top: (map['top']! as num).toDouble(),
      width: (map['width']! as num).toDouble(),
      height: (map['height']! as num).toDouble(),
    );
  }

  final double left;
  final double top;
  final double width;
  final double height;
}

/// A single 2D landmark point, normalized [0,1].
class FaceLandmarkPoint {
  const FaceLandmarkPoint(this.x, this.y);

  factory FaceLandmarkPoint.fromMap(Map<Object?, Object?> map) {
    return FaceLandmarkPoint(
      (map['x']! as num).toDouble(),
      (map['y']! as num).toDouble(),
    );
  }

  final double x;
  final double y;
}

/// Raw per-frame face detection output from the native face detector
/// (ML Kit / Vision — no bundled model required). [FaceTracker]
/// consumes a stream of these to produce smoothed, debounced signals.
class FaceDetectionResult {
  const FaceDetectionResult({
    required this.faceCount,
    required this.trackingId,
    required this.boundingBox,
    required this.landmarks,
    required this.yawDegrees,
    required this.pitchDegrees,
    required this.rollDegrees,
    required this.leftEyeOpenProbability,
    required this.rightEyeOpenProbability,
    required this.smilingProbability,
  });

  factory FaceDetectionResult.fromMap(Map<Object?, Object?> map) {
    return FaceDetectionResult(
      faceCount: map['faceCount']! as int,
      trackingId: map['trackingId'] as int?,
      boundingBox: map['boundingBox'] != null
          ? FaceBoundingBox.fromMap(
              map['boundingBox']! as Map<Object?, Object?>)
          : null,
      landmarks: (map['landmarks'] as List<Object?>?)
              ?.map((Object? e) =>
                  FaceLandmarkPoint.fromMap(e! as Map<Object?, Object?>))
              .toList() ??
          const <FaceLandmarkPoint>[],
      yawDegrees: (map['yawDegrees'] as num?)?.toDouble(),
      pitchDegrees: (map['pitchDegrees'] as num?)?.toDouble(),
      rollDegrees: (map['rollDegrees'] as num?)?.toDouble(),
      leftEyeOpenProbability:
          (map['leftEyeOpenProbability'] as num?)?.toDouble(),
      rightEyeOpenProbability:
          (map['rightEyeOpenProbability'] as num?)?.toDouble(),
      smilingProbability: (map['smilingProbability'] as num?)?.toDouble(),
    );
  }

  final int faceCount;
  final int? trackingId;
  final FaceBoundingBox? boundingBox;
  final List<FaceLandmarkPoint> landmarks;
  final double? yawDegrees;
  final double? pitchDegrees;
  final double? rollDegrees;
  final double? leftEyeOpenProbability;
  final double? rightEyeOpenProbability;
  final double? smilingProbability;

  bool get hasSingleFace => faceCount == 1;
  bool get hasMultipleFaces => faceCount > 1;
  bool get hasNoFace => faceCount == 0;
}

/// Deterministic quality checks run on a detected face before it is
/// eligible for embedding generation. Every field here is computed
/// from bounding-box geometry, landmark geometry, and pixel-level
/// blur/exposure heuristics — no model required.
class FaceQualityResult {
  const FaceQualityResult({
    required this.overallScore,
    required this.isBlurry,
    required this.isTooSmall,
    required this.isTooLarge,
    required this.isCentered,
    required this.isFrontal,
    required this.brightness,
  });

  factory FaceQualityResult.fromMap(Map<Object?, Object?> map) {
    return FaceQualityResult(
      overallScore: (map['overallScore']! as num).toDouble(),
      isBlurry: map['isBlurry']! as bool,
      isTooSmall: map['isTooSmall']! as bool,
      isTooLarge: map['isTooLarge']! as bool,
      isCentered: map['isCentered']! as bool,
      isFrontal: map['isFrontal']! as bool,
      brightness: (map['brightness']! as num).toDouble(),
    );
  }

  final double overallScore;
  final bool isBlurry;
  final bool isTooSmall;
  final bool isTooLarge;
  final bool isCentered;
  final bool isFrontal;

  /// 0.0 (black) - 1.0 (blown out) mean luma of the face crop.
  final double brightness;

  bool get isAcceptable =>
      !isBlurry && !isTooSmall && !isTooLarge && isCentered && isFrontal;
}
