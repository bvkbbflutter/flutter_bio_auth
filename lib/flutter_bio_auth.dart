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

// Modular Face Intelligence SDK (FaceAI)
export 'src/face_ai.dart';
export 'src/face_ai_config.dart';
export 'src/authentication/authentication_service.dart';
export 'src/authentication/authentication_options.dart';
export 'src/authentication/local_auth_result.dart';
export 'src/recognition/face_recognition_service.dart';
export 'src/recognition/recognition_options.dart';
export 'src/recognition/face_comparison_result.dart';
export 'src/expression/expression_service.dart';
export 'src/expression/expression_options.dart';
export 'src/expression/expression_result.dart';
export 'src/expression/facial_expression.dart';
export 'src/liveness/liveness_service.dart';
export 'src/liveness/liveness_options.dart';
export 'src/compliance/delivery_compliance_service.dart';
export 'src/compliance/compliance_options.dart';
export 'src/compliance/delivery_compliance_result.dart';
export 'src/compliance/uniform_preset.dart';
export 'src/models/model_manager.dart';
export 'src/models/model_config.dart';
export 'src/models/model_type.dart';
export 'src/models/model_source.dart';
export 'src/models/benchmark_result.dart';
export 'src/diagnostics/device_capabilities.dart';

// Turnkey UI Widgets
export 'src/ui/face_cutout_overlay.dart';
export 'src/ui/face_biometric_camera_view.dart';
export 'src/ui/face_biometric_scanner.dart';
export 'src/ui/face_liveness_view.dart';
export 'src/ui/face_authentication_view.dart';
export 'src/ui/face_enrollment_view.dart';
export 'src/ui/face_smile_view.dart';
export 'src/ui/delivery_compliance_view.dart';
export 'src/ui/expression_meter_view.dart';
