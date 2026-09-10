import 'package:flutter/material.dart';
import 'package:flutter_bio_auth/flutter_bio_auth.dart';
import 'package:permission_handler/permission_handler.dart';

import 'result_page.dart';

class AuthenticationPage extends StatefulWidget {
  const AuthenticationPage({super.key});

  @override
  State<AuthenticationPage> createState() => _AuthenticationPageState();
}

class _AuthenticationPageState extends State<AuthenticationPage> {
  final TextEditingController _userIdController = TextEditingController();

  bool _authenticating = false;
  String? _error;
  List<String> _enrolledUsers = <String>[];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final List<String> users = await FaceBiometric.getEnrolledUsers();
    if (mounted) setState(() => _enrolledUsers = users);
  }

  @override
  void dispose() {
    _userIdController.dispose();
    super.dispose();
  }

  Future<void> _authenticate() async {
    final String userId = _userIdController.text.trim();
    if (userId.isEmpty) {
      setState(() => _error = 'Enter or select a user ID first.');
      return;
    }

    final PermissionStatus status = await Permission.camera.request();
    if (!status.isGranted) {
      setState(() => _error = 'Camera permission is required to authenticate.');
      return;
    }

    setState(() {
      _authenticating = true;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Authenticate')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            if (_enrolledUsers.isNotEmpty && !_authenticating)
              DropdownButtonFormField<String>(
                value: _userIdController.text.isEmpty
                    ? null
                    : _userIdController.text,
                decoration: const InputDecoration(
                    labelText: 'Select enrolled user',
                    border: OutlineInputBorder()),
                items: _enrolledUsers
                    .map((String u) =>
                        DropdownMenuItem<String>(value: u, child: Text(u)))
                    .toList(),
                onChanged: (String? value) =>
                    setState(() => _userIdController.text = value ?? ''),
              )
            else
              TextField(
                controller: _userIdController,
                enabled: !_authenticating,
                decoration: const InputDecoration(
                    labelText: 'User ID', border: OutlineInputBorder()),
              ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 16),
            Expanded(
              child: _authenticating
                  ? FaceAuthenticationView(
                      userId: _userIdController.text.trim(),
                      onAuthenticated: (FaceAuthenticationResult result) async {
                        if (!mounted) return;
                        setState(() => _authenticating = false);
                        final NavigatorState navigator = Navigator.of(context);
                        await navigator.push(
                          MaterialPageRoute<void>(
                            builder: (_) => ResultPage(
                              success: result.authenticated,
                              title: result.authenticated
                                  ? 'Authentication successful'
                                  : 'Authentication failed',
                              details: result.authenticated
                                  ? <String, String>{
                                      'Similarity':
                                          result.similarity.toStringAsFixed(2),
                                      'Liveness': result.livenessScore
                                          .toStringAsFixed(2),
                                      'Anti-spoof': result.antiSpoofScore
                                          .toStringAsFixed(2),
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
                          _authenticating = false;
                          _error = err;
                        });
                      },
                      onClose: () {
                        if (!mounted) return;
                        setState(() => _authenticating = false);
                      },
                    )
                  : const Center(
                      child: Text(
                          'Select or enter a user ID, then authenticate.')),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _authenticating ? null : _authenticate,
              child: Text(_authenticating ? 'Authenticating…' : 'Authenticate'),
            ),
          ],
        ),
      ),
    );
  }
}
