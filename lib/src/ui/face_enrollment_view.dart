import 'package:flutter/material.dart';

import '../biometric_error.dart';
import '../face_biometric.dart';
import '../face_biometric_controller.dart';
import '../face_enrollment_result.dart';
import 'face_biometric_scanner.dart';

/// Complete turnkey widget for Face Enrollment.
///
/// Directs the user to align their face, sequences required liveness challenges,
/// captures 5 high-quality aligned samples, normalizes, encrypts, and stores the template.
class FaceEnrollmentView extends StatefulWidget {
  const FaceEnrollmentView({
    super.key,
    required this.userId,
    this.timeout = const Duration(seconds: 45),
    this.enableLiveness = false,
    this.onEnrolled,
    this.onError,
    this.onClose,
  });

  final String userId;
  final Duration timeout;
  final bool enableLiveness;
  final ValueChanged<FaceEnrollmentResult>? onEnrolled;
  final ValueChanged<String>? onError;
  final VoidCallback? onClose;

  @override
  State<FaceEnrollmentView> createState() => _FaceEnrollmentViewState();
}

class _FaceEnrollmentViewState extends State<FaceEnrollmentView> {
  final FaceBiometricController _controller = FaceBiometricController();
  bool _running = false;
  FaceEnrollmentResult? _result;
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
      final FaceEnrollmentResult res = await FaceBiometric.enroll(
        userId: widget.userId,
        enableLiveness: widget.enableLiveness,
      );
      if (!mounted) return;
      setState(() {
        _running = false;
        _result = res;
      });
      widget.onEnrolled?.call(res);
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
        title: 'Enrolling face for ${widget.userId}',
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
                'Enrollment Error',
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
      final bool success = _result!.success;
      final Color color = success ? Colors.green : theme.colorScheme.error;

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
              Icon(success ? Icons.check_circle_outline : Icons.cancel_outlined, size: 64, color: color),
              const SizedBox(height: 16),
              Text(
                success ? 'Enrollment Complete!' : 'Enrollment Incomplete',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                success
                    ? 'Encrypted biometric template stored for user "${_result!.userId}".'
                    : 'Reason: ${_result!.failureReason?.name ?? "Quality check incomplete"}',
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Text(
                'Samples captured: ${_result!.samplesUsed}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _start,
                icon: const Icon(Icons.refresh),
                label: const Text('Enroll Again'),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
