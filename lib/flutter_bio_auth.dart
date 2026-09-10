/// On-device face biometric enrollment, 1:1 verification, active liveness,
/// and an injectable anti-spoof pipeline for Flutter.
library flutter_bio_auth;

export 'src/face_biometric.dart';
export 'src/face_biometric_controller.dart';
export 'src/face_biometric_config.dart';
export 'src/face_biometric_state.dart';
export 'src/face_enrollment_result.dart';
export 'src/face_authentication_result.dart';
export 'src/face_match_result.dart';
export 'src/face_matcher.dart';
export 'src/challenge_sequencer.dart';
export 'src/face_template.dart';
export 'src/liveness_challenge.dart';
export 'src/liveness_state.dart';
export 'src/anti_spoof_result.dart';
export 'src/face_detection_result.dart';
export 'src/face_quality_result.dart';
export 'src/biometric_error.dart';
export 'src/biometric_failure_reason.dart';
export 'src/face_authentication_mode.dart';
export 'src/device_auth_type.dart';

// Turnkey UI Widgets
export 'src/ui/face_cutout_overlay.dart';
export 'src/ui/face_biometric_camera_view.dart';
export 'src/ui/face_biometric_scanner.dart';
export 'src/ui/face_liveness_view.dart';
export 'src/ui/face_authentication_view.dart';
export 'src/ui/face_enrollment_view.dart';
export 'src/ui/face_smile_view.dart';
