import 'dart:async';

import 'face_biometric_config.dart';
import 'face_biometric_state.dart';
import 'liveness_state.dart';
import 'platform/face_biometric_platform.dart';

/// Session-oriented controller for screens that need to render live
/// progress (camera preview + challenge state) rather than just
/// awaiting a final result.
///
/// Owns the lifecycle of one native session: create it when entering
/// an enroll/authenticate screen, call [retry] to reset a failed
/// attempt without leaking camera resources, and always call
/// [dispose] when leaving the screen.
class FaceBiometricController {
  FaceBiometricController({FaceBiometricPlatform? platform})
      : _platform = platform ?? FaceBiometricPlatform.instance {
    _subscription = _platform.stateStream.listen(
      (FaceBiometricState state) {
        if (!_stateController.isClosed) {
          _stateController.add(state);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!_stateController.isClosed) {
          _stateController.add(FaceBiometricState.error);
        }
      },
    );
  }

  final FaceBiometricPlatform _platform;

  StreamSubscription<FaceBiometricState>? _subscription;
  final StreamController<FaceBiometricState> _stateController =
      StreamController<FaceBiometricState>.broadcast();

  bool _disposed = false;

  /// Current session state. UI should build off this stream rather
  /// than the state returned by the one-shot [FaceBiometric] calls, so
  /// it can render intermediate states like "runningLiveness" or
  /// "checkingAntiSpoof".
  Stream<FaceBiometricState> get stateStream => _stateController.stream;

  /// Stream of active liveness challenge progress.
  Stream<LivenessChallengeProgress> get challengeProgressStream =>
      _platform.challengeProgressStream;

  bool get isDisposed => _disposed;

  Future<void> initialize(FaceBiometricConfig config) async {
    _throwIfDisposed();
    config.validate();
    await _platform.initialize(config);
  }

  /// Resets challenge/temporal/camera-analysis state for a fresh
  /// attempt after a failure. Does not tear down the camera session or
  /// create a duplicate one.
  Future<void> retry() async {
    _throwIfDisposed();
    await _platform.retry();
  }

  /// Releases the camera, ML interpreters, event subscription, and any
  /// native platform view. Safe to call multiple times.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _subscription?.cancel();
    _subscription = null;
    await _stateController.close();
    await _platform.dispose();
  }

  void _throwIfDisposed() {
    if (_disposed) {
      throw StateError(
        'This FaceBiometricController has been disposed and cannot be '
        'reused. Create a new instance instead.',
      );
    }
  }
}
