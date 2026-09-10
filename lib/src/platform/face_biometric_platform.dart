import 'dart:async';

import 'package:flutter/services.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../biometric_error.dart';
import '../device_auth_type.dart';
import '../face_authentication_result.dart';
import '../face_biometric_config.dart';
import '../face_biometric_state.dart';
import '../face_enrollment_result.dart';
import '../face_match_result.dart';
import '../liveness_challenge.dart';
import '../liveness_state.dart';

/// The platform-agnostic contract Android/iOS implementations satisfy.
///
/// Kept intentionally thin and typed rather than exposing raw
/// method-channel calls to the rest of the package, so a future
/// federated/Pigeon-based implementation can replace
/// [MethodChannelFaceBiometric] without touching `FaceBiometric` or
/// `FaceBiometricController`.
abstract class FaceBiometricPlatform extends PlatformInterface {
  FaceBiometricPlatform() : super(token: _token);

  static final Object _token = Object();

  static FaceBiometricPlatform _instance = MethodChannelFaceBiometric();

  static FaceBiometricPlatform get instance => _instance;

  static set instance(FaceBiometricPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<void> initialize(FaceBiometricConfig config);

  Future<FaceEnrollmentResult> enroll({required String userId});

  Future<FaceAuthenticationResult> authenticate({required String userId});

  /// Standalone active liveness verification without requiring any AI
  /// face recognition model. Tests active challenges (blink, smile, head turns)
  /// and returns a [LivenessResult].
  Future<LivenessResult> verifyLiveness({
    List<LivenessChallenge>? challenges,
    Duration? timeout,
  });

  Future<FaceMatchResult> compare({
    required Uint8List firstImage,
    required Uint8List secondImage,
  });

  Future<bool> isEnrolled({required String userId});

  Future<void> deleteEnrollment({required String userId});

  Future<List<String>> getEnrolledUsers();

  Future<void> clearAllEnrollments();

  Future<bool> authenticateWithDeviceBiometrics({
    String? reason,
    DeviceAuthType authType = DeviceAuthType.biometricOnly,
  });

  /// Cancels and resets any in-flight enroll/authenticate session
  /// without disposing native resources.
  Future<void> retry();

  /// Releases camera, ML interpreters, event streams, and platform
  /// views held natively.
  Future<void> dispose();

  /// Structured, model-free per-frame state used to drive UI (never
  /// raw camera frames).
  Stream<FaceBiometricState> get stateStream;

  /// Stream of real-time active liveness challenge progress.
  Stream<LivenessChallengeProgress> get challengeProgressStream;
}

/// Default implementation backed by a [MethodChannel] +
/// [EventChannel] pair.
class MethodChannelFaceBiometric extends FaceBiometricPlatform {
  MethodChannelFaceBiometric({
    MethodChannel? methodChannel,
    EventChannel? stateEventChannel,
  })  : _methodChannel =
            methodChannel ?? const MethodChannel('flutter_bio_auth/methods'),
        _stateEventChannel = stateEventChannel ??
            const EventChannel('flutter_bio_auth/state_events');

  final MethodChannel _methodChannel;
  final EventChannel _stateEventChannel;

  StreamController<FaceBiometricState>? _stateStreamController;
  StreamController<LivenessChallengeProgress>? _challengeStreamController;

  void _ensureStreams() {
    if (_stateStreamController != null) return;
    _stateStreamController = StreamController<FaceBiometricState>.broadcast();
    _challengeStreamController =
        StreamController<LivenessChallengeProgress>.broadcast();

    _stateEventChannel.receiveBroadcastStream().listen(
      (Object? event) {
        if (event is String) {
          final FaceBiometricState state = _parseState(event);
          _stateStreamController?.add(state);
        } else if (event is Map) {
          if (event.containsKey('state')) {
            final FaceBiometricState state =
                _parseState(event['state'] as String);
            _stateStreamController?.add(state);
          }
          if (event.containsKey('challenge')) {
            try {
              final LivenessChallengeProgress progress =
                  LivenessChallengeProgress.fromMap(
                      event as Map<Object?, Object?>);
              _challengeStreamController?.add(progress);
            } catch (_) {}
          }
        }
      },
      onError: (Object error) {
        _stateStreamController?.add(FaceBiometricState.error);
      },
    );
  }

  @override
  Stream<FaceBiometricState> get stateStream {
    _ensureStreams();
    return _stateStreamController!.stream;
  }

  @override
  Stream<LivenessChallengeProgress> get challengeProgressStream {
    _ensureStreams();
    return _challengeStreamController!.stream;
  }

  FaceBiometricState _parseState(String raw) {
    return FaceBiometricState.values.firstWhere(
      (FaceBiometricState s) => s.name == raw,
      orElse: () => FaceBiometricState.error,
    );
  }

  @override
  Future<void> initialize(FaceBiometricConfig config) async {
    await _invoke<void>('initialize', config.toMap());
  }

  @override
  Future<FaceEnrollmentResult> enroll({required String userId}) async {
    final Map<Object?, Object?> result = await _invoke(
      'enroll',
      <String, Object?>{'userId': userId},
    );
    return FaceEnrollmentResult.fromMap(result);
  }

  @override
  Future<FaceAuthenticationResult> authenticate({
    required String userId,
  }) async {
    final Map<Object?, Object?> result = await _invoke(
      'authenticate',
      <String, Object?>{'userId': userId},
    );
    return FaceAuthenticationResult.fromMap(result);
  }

  @override
  Future<LivenessResult> verifyLiveness({
    List<LivenessChallenge>? challenges,
    Duration? timeout,
  }) async {
    final Map<Object?, Object?> result = await _invoke(
      'verifyLiveness',
      <String, Object?>{
        if (challenges != null)
          'challenges':
              challenges.map((LivenessChallenge c) => c.name).toList(),
        if (timeout != null) 'timeoutMs': timeout.inMilliseconds,
      },
    );
    return LivenessResult.fromMap(result);
  }

  @override
  Future<FaceMatchResult> compare({
    required Uint8List firstImage,
    required Uint8List secondImage,
  }) async {
    final Map<Object?, Object?> result = await _invoke(
      'compare',
      <String, Object?>{
        'firstImage': firstImage,
        'secondImage': secondImage,
      },
    );
    return FaceMatchResult.fromMap(result);
  }

  @override
  Future<bool> isEnrolled({required String userId}) async {
    return _invoke<bool>('isEnrolled', <String, Object?>{'userId': userId});
  }

  @override
  Future<void> deleteEnrollment({required String userId}) async {
    await _invoke<void>(
      'deleteEnrollment',
      <String, Object?>{'userId': userId},
    );
  }

  @override
  Future<List<String>> getEnrolledUsers() async {
    final List<Object?> users = await _invoke('getEnrolledUsers', null);
    return users.cast<String>();
  }

  @override
  Future<void> clearAllEnrollments() async {
    await _invoke<void>('clearAllEnrollments', null);
  }

  @override
  Future<bool> authenticateWithDeviceBiometrics({
    String? reason,
    DeviceAuthType authType = DeviceAuthType.biometricOnly,
  }) async {
    return _invoke<bool>(
      'authenticateWithDeviceBiometrics',
      <String, Object?>{
        'reason': reason,
        'authType': authType.name,
      },
    );
  }

  @override
  Future<void> retry() async {
    await _invoke<void>('retry', null);
  }

  @override
  Future<void> dispose() async {
    await _invoke<void>('dispose', null);
  }

  Future<T> _invoke<T>(String method, Object? arguments) async {
    try {
      final T? result = await _methodChannel.invokeMethod<T>(
        method,
        arguments,
      );
      return result as T;
    } on PlatformException catch (e) {
      throw _mapPlatformException(e);
    } on MissingPluginException {
      throw const BiometricError(
        FaceBiometricErrorCode.platformError,
        'flutter_bio_auth is not implemented on this platform.',
      );
    }
  }

  BiometricError _mapPlatformException(PlatformException e) {
    final FaceBiometricErrorCode code =
        FaceBiometricErrorCode.values.firstWhere(
      (FaceBiometricErrorCode c) => c.name == e.code,
      orElse: () => FaceBiometricErrorCode.platformError,
    );
    return BiometricError(
      code,
      e.message ?? 'Unknown native error.',
      nativeDetails: e.details,
    );
  }
}
