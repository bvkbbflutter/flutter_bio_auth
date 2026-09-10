import 'package:flutter/material.dart';

import '../biometric_error.dart';
import '../face_biometric.dart';
import '../face_biometric_controller.dart';
import '../liveness_challenge.dart';
import '../liveness_state.dart';
import 'face_biometric_scanner.dart';

/// Complete turnkey widget for Active Liveness Verification.
///
/// Handles the camera preview, oval cutout mask, live countdown timer,
/// real-time challenge progression, and completion feedback.
class FaceLivenessView extends StatefulWidget {
  const FaceLivenessView({
    super.key,
    this.challenges = const <LivenessChallenge>[
      LivenessChallenge.blink,
      LivenessChallenge.turnLeft,
      LivenessChallenge.turnRight,
    ],
    this.timeout = const Duration(seconds: 45),
    this.onCompleted,
    this.onError,
    this.onClose,
  });

  final List<LivenessChallenge> challenges;
  final Duration timeout;
  final ValueChanged<LivenessResult>? onCompleted;
  final ValueChanged<String>? onError;
  final VoidCallback? onClose;

  @override
  State<FaceLivenessView> createState() => _FaceLivenessViewState();
}

class _FaceLivenessViewState extends State<FaceLivenessView> {
  final FaceBiometricController _controller = FaceBiometricController();
  bool _running = false;
  LivenessResult? _result;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _running = true;
      _result = null;
      _errorMessage = null;
    });

    try {
      final LivenessResult res = await FaceBiometric.verifyLiveness(
        challenges: widget.challenges,
        timeout: widget.timeout,
      );
      if (!mounted) return;
      setState(() {
        _running = false;
        _result = res;
      });
      widget.onCompleted?.call(res);
    } on BiometricError catch (e) {
      if (!mounted) return;
      setState(() {
        _running = false;
        _errorMessage = e.message;
      });
      widget.onError?.call(e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _running = false;
        _errorMessage = e.toString();
      });
      widget.onError?.call(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_running) {
      return FaceBiometricScanner(
        controller: _controller,
        timeoutSeconds: widget.timeout.inSeconds,
        title: 'Fit face inside the oval',
        onClose: widget.onClose,
      );
    }

    final ThemeData theme = Theme.of(context);

    if (_errorMessage != null) {
      return Card(
        elevation: 0,
        color: theme.colorScheme.errorContainer.withOpacity(0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(Icons.error_outline, size: 60, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text(
                'Liveness Error',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _start,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_result != null) {
      final bool passed = _result!.passed;
      final Color color = passed ? Colors.green : theme.colorScheme.error;

      return Card(
        elevation: 0,
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: color.withOpacity(0.5), width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(passed ? Icons.verified_user : Icons.cancel_outlined, size: 64, color: color),
              const SizedBox(height: 16),
              Text(
                passed ? 'Liveness Confirmed!' : 'Liveness Incomplete',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                passed
                    ? 'All challenges passed successfully.'
                    : (_result!.failedChallenge != null
                        ? 'Failed on challenge: ${_result!.failedChallenge!.name}'
                        : 'Verification timed out.'),
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Text(
                'Overall Score: ${(_result!.overallScore * 100).toStringAsFixed(0)}%',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _start,
                icon: const Icon(Icons.refresh),
                label: const Text('Test Again'),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
