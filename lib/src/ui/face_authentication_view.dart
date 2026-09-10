import 'package:flutter/material.dart';

import '../biometric_error.dart';
import '../face_authentication_result.dart';
import '../face_biometric.dart';
import '../face_biometric_controller.dart';
import 'face_biometric_scanner.dart';

/// Complete turnkey widget for In-App Face Authentication.
///
/// Runs 100% on-device live camera face matching and liveness verification
/// with ZERO native OS prompt dialogs.
class FaceAuthenticationView extends StatefulWidget {
  const FaceAuthenticationView({
    super.key,
    required this.userId,
    this.timeout = const Duration(seconds: 30),
    this.onAuthenticated,
    this.onError,
    this.onClose,
  });

  final String userId;
  final Duration timeout;
  final ValueChanged<FaceAuthenticationResult>? onAuthenticated;
  final ValueChanged<String>? onError;
  final VoidCallback? onClose;

  @override
  State<FaceAuthenticationView> createState() => _FaceAuthenticationViewState();
}

class _FaceAuthenticationViewState extends State<FaceAuthenticationView> {
  final FaceBiometricController _controller = FaceBiometricController();
  bool _running = false;
  FaceAuthenticationResult? _result;
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
      final FaceAuthenticationResult res = await FaceBiometric.authenticate(
        userId: widget.userId,
      );
      if (!mounted) return;
      setState(() {
        _running = false;
        _result = res;
      });
      widget.onAuthenticated?.call(res);
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
        title: 'Authenticating for ${widget.userId}',
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
                'Authentication Error',
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
      final bool auth = _result!.authenticated;
      final Color color = auth ? Colors.green : theme.colorScheme.error;

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
              Icon(auth ? Icons.verified_user : Icons.cancel_outlined, size: 64, color: color),
              const SizedBox(height: 16),
              Text(
                auth ? 'Identity Verified!' : 'Authentication Failed',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                auth
                    ? 'User "${_result!.userId}" confirmed.'
                    : 'Failure: ${_result!.failureReason?.name ?? "Face mismatch"}',
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Text(
                'Similarity Score: ${(_result!.similarity * 100).toStringAsFixed(1)}%',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _start,
                icon: const Icon(Icons.refresh),
                label: const Text('Authenticate Again'),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
