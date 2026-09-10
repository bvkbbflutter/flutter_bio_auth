import 'package:flutter/material.dart';
import 'package:flutter_bio_auth/flutter_bio_auth.dart';
import 'package:permission_handler/permission_handler.dart';

import 'result_page.dart';

class EnrollmentPage extends StatefulWidget {
  const EnrollmentPage({super.key});

  @override
  State<EnrollmentPage> createState() => _EnrollmentPageState();
}

class _EnrollmentPageState extends State<EnrollmentPage> {
  final TextEditingController _userIdController = TextEditingController();

  bool _enrolling = false;
  String? _error;

  @override
  void dispose() {
    _userIdController.dispose();
    super.dispose();
  }

  Future<void> _startEnrollment() async {
    final String userId = _userIdController.text.trim();
    if (userId.isEmpty) {
      setState(() => _error = 'Enter a user ID first.');
      return;
    }

    final PermissionStatus status = await Permission.camera.request();
    if (!status.isGranted) {
      setState(() => _error = 'Camera permission is required to enroll.');
      return;
    }

    setState(() {
      _enrolling = true;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enroll Face')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            TextField(
              controller: _userIdController,
              enabled: !_enrolling,
              decoration: const InputDecoration(
                labelText: 'User ID',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 16),
            Expanded(
              child: _enrolling
                  ? FaceEnrollmentView(
                      userId: _userIdController.text.trim(),
                      onEnrolled: (FaceEnrollmentResult result) async {
                        if (!mounted) return;
                        setState(() => _enrolling = false);
                        final NavigatorState navigator = Navigator.of(context);
                        await navigator.push(
                          MaterialPageRoute<void>(
                            builder: (_) => ResultPage(
                              success: result.success,
                              title: result.success
                                  ? 'Enrollment successful'
                                  : 'Enrollment failed',
                              details: result.success
                                  ? <String, String>{
                                      'User ID': result.userId,
                                      'Samples used': '${result.samplesUsed}',
                                      'Duration':
                                          '${result.duration.inMilliseconds} ms',
                                    }
                                  : <String, String>{
                                      'Reason': result.failureReason?.name ??
                                          'unknown',
                                    },
                            ),
                          ),
                        );
                        if (mounted) navigator.pop();
                      },
                      onError: (String err) {
                        if (!mounted) return;
                        setState(() {
                          _enrolling = false;
                          _error = err;
                        });
                      },
                      onClose: () {
                        if (!mounted) return;
                        setState(() => _enrolling = false);
                      },
                    )
                  : const Center(
                      child: Text(
                          'Enter a user ID and start enrollment.\nYou will be asked to blink and turn your head.'),
                    ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _enrolling ? null : _startEnrollment,
              child: Text(_enrolling ? 'Enrolling…' : 'Start Enrollment'),
            ),
          ],
        ),
      ),
    );
  }
}
