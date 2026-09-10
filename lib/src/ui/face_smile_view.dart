import 'package:flutter/material.dart';

import '../biometric_error.dart';
import '../face_biometric.dart';
import '../face_biometric_controller.dart';
import '../liveness_challenge.dart';
import '../liveness_state.dart';
import 'face_biometric_scanner.dart';

/// Turnkey Smile-Triggered Verification widget.
///
/// Runs active smile detection on click, and invokes [onSmiled] the instant
/// a genuine smile is detected. Perfect for positive-action navigation flows
/// (such as unlocking a "Happy Page").
class FaceSmileView extends StatefulWidget {
  const FaceSmileView({
    super.key,
    required this.onSmiled,
    this.timeout = const Duration(seconds: 45),
    this.onCancel,
    this.onError,
    this.title = 'Show your smile to continue!',
  });

  /// Called the moment a smile is successfully detected and verified.
  final ValueChanged<double> onSmiled;

  final Duration timeout;
  final VoidCallback? onCancel;
  final ValueChanged<String>? onError;
  final String title;

  @override
  State<FaceSmileView> createState() => _FaceSmileViewState();
}

class _FaceSmileViewState extends State<FaceSmileView> {
  final FaceBiometricController _controller = FaceBiometricController();
  bool _scanning = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startSmileCheck();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _startSmileCheck() async {
    setState(() {
      _scanning = true;
      _errorMessage = null;
    });

    try {
      final LivenessResult result = await FaceBiometric.verifyLiveness(
        challenges: const <LivenessChallenge>[LivenessChallenge.smile],
        timeout: widget.timeout,
      );

      if (!mounted) return;

      if (result.passed) {
        setState(() => _scanning = false);
        widget.onSmiled(result.overallScore);
      } else {
        setState(() {
          _scanning = false;
          _errorMessage = 'Could not detect a smile. Tap retry to try again!';
        });
        widget.onError?.call(_errorMessage!);
      }
    } on BiometricError catch (e) {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _errorMessage = e.message;
      });
      widget.onError?.call(e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _errorMessage = e.toString();
      });
      widget.onError?.call(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_scanning) {
      return FaceBiometricScanner(
        controller: _controller,
        title: widget.title,
        timeoutSeconds: widget.timeout.inSeconds,
        onClose: widget.onCancel,
      );
    }

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(Icons.sentiment_dissatisfied, size: 64, color: Colors.orange),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Smile check ended',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _startSmileCheck,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
            if (widget.onCancel != null) ...<Widget>[
              const SizedBox(height: 8),
              TextButton(
                onPressed: widget.onCancel,
                child: const Text('Cancel'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
