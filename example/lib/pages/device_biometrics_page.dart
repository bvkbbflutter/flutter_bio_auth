import 'package:flutter/material.dart';
import 'package:flutter_bio_auth/flutter_bio_auth.dart';

import 'authentication_page.dart';

/// Standalone Device Biometrics Authentication screen (Feature B).
/// Uses native Android BiometricPrompt and iOS LocalAuthentication.
/// Operates 100% on-device at the OS level with zero AI model dependencies.
class DeviceBiometricsPage extends StatefulWidget {
  const DeviceBiometricsPage({super.key});

  @override
  State<DeviceBiometricsPage> createState() => _DeviceBiometricsPageState();
}

class _DeviceBiometricsPageState extends State<DeviceBiometricsPage> {
  final TextEditingController _reasonController = TextEditingController(
    text: 'Authenticate to access secure area',
  );

  bool _authenticating = false;
  bool? _lastSuccess;
  String? _statusMessage;
  DateTime? _lastAttemptTime;
  DeviceAuthType _selectedAuthType = DeviceAuthType.strongBiometricOnly;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _authenticate([DeviceAuthType? type]) async {
    final DeviceAuthType authType = type ?? _selectedAuthType;
    final String reason = _reasonController.text.trim().isNotEmpty
        ? _reasonController.text.trim()
        : 'Authenticate to proceed';

    setState(() {
      _authenticating = true;
      _statusMessage = null;
      _selectedAuthType = authType;
    });

    try {
      final bool success = await FaceBiometric.authenticateWithDeviceBiometrics(
        reason: reason,
        authType: authType,
      );
      if (mounted) {
        setState(() {
          _lastSuccess = success;
          _lastAttemptTime = DateTime.now();
          _statusMessage = success
              ? 'Authentication succeeded with ${_describeAuthType(authType)}!'
              : 'Authentication was canceled or not recognized.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _lastSuccess = false;
          _lastAttemptTime = DateTime.now();
          _statusMessage = 'Biometric error: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _authenticating = false);
      }
    }
  }

  String _describeAuthType(DeviceAuthType type) {
    switch (type) {
      case DeviceAuthType.strongBiometricOnly:
        return 'Fingerprint / Strong Biometric';
      case DeviceAuthType.deviceCredentialOnly:
        return 'Pattern / PIN Only';
      case DeviceAuthType.biometricWithCredential:
        return 'Biometrics with PIN Fallback';
      case DeviceAuthType.biometricOnly:
        return 'Any Device Biometric';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Device Biometrics')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Information banner
              Card(
                color: theme.colorScheme.secondaryContainer.withOpacity(0.5),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                      color: theme.colorScheme.secondary.withOpacity(0.2)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.fingerprint,
                          color: theme.colorScheme.secondary, size: 28),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Native OS Biometrics & Lock Credentials. You can explicitly test Fingerprint only, Pattern/PIN only, or Biometrics with PIN fallback.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Mode Selection Card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Select Authentication Modality',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      RadioListTile<DeviceAuthType>(
                        title:
                            const Text('Fingerprint / Strong Biometrics Only'),
                        subtitle:
                            const Text('Hardware Class 3 sensor (Fingerprint)'),
                        value: DeviceAuthType.strongBiometricOnly,
                        groupValue: _selectedAuthType,
                        onChanged: _authenticating
                            ? null
                            : (DeviceAuthType? val) {
                                if (val != null)
                                  setState(() => _selectedAuthType = val);
                              },
                        contentPadding: EdgeInsets.zero,
                      ),
                      const Divider(height: 1),
                      RadioListTile<DeviceAuthType>(
                        title: const Text('Pattern / PIN / Password Only'),
                        subtitle: const Text(
                            'Device lock credentials without biometrics'),
                        value: DeviceAuthType.deviceCredentialOnly,
                        groupValue: _selectedAuthType,
                        onChanged: _authenticating
                            ? null
                            : (DeviceAuthType? val) {
                                if (val != null)
                                  setState(() => _selectedAuthType = val);
                              },
                        contentPadding: EdgeInsets.zero,
                      ),
                      const Divider(height: 1),
                      RadioListTile<DeviceAuthType>(
                        title: const Text('Biometrics + PIN Fallback'),
                        subtitle: const Text(
                            'Prompts biometrics with option to use PIN/Pattern'),
                        value: DeviceAuthType.biometricWithCredential,
                        groupValue: _selectedAuthType,
                        onChanged: _authenticating
                            ? null
                            : (DeviceAuthType? val) {
                                if (val != null)
                                  setState(() => _selectedAuthType = val);
                              },
                        contentPadding: EdgeInsets.zero,
                      ),
                      const Divider(height: 1),
                      RadioListTile<DeviceAuthType>(
                        title: const Text('Any Device Biometric'),
                        subtitle: const Text(
                            'Either Fingerprint or Face lock screen biometrics'),
                        value: DeviceAuthType.biometricOnly,
                        groupValue: _selectedAuthType,
                        onChanged: _authenticating
                            ? null
                            : (DeviceAuthType? val) {
                                if (val != null)
                                  setState(() => _selectedAuthType = val);
                              },
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Prompt configuration
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Prompt Title',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _reasonController,
                        enabled: !_authenticating,
                        decoration: const InputDecoration(
                          labelText: 'Authentication Reason',
                          hintText: 'e.g., Confirm payment or unlock app',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.security),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Main trigger button
              FilledButton.icon(
                onPressed: _authenticating ? null : () => _authenticate(),
                icon: Icon(_authenticating
                    ? Icons.hourglass_top
                    : Icons.verified_user),
                label: Text(
                  _authenticating
                      ? 'Prompting…'
                      : 'Trigger ${_describeAuthType(_selectedAuthType)}',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 12),

              // Quick action buttons for convenience
              Text(
                'Quick Tests:',
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  ActionChip(
                    avatar: const Icon(Icons.pattern, size: 18),
                    label: const Text('Pattern / PIN Only'),
                    onPressed: _authenticating
                        ? null
                        : () =>
                            _authenticate(DeviceAuthType.deviceCredentialOnly),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.fingerprint, size: 18),
                    label: const Text('Fingerprint Only'),
                    onPressed: _authenticating
                        ? null
                        : () =>
                            _authenticate(DeviceAuthType.strongBiometricOnly),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.lock_reset, size: 18),
                    label: const Text('Biometrics + PIN Fallback'),
                    onPressed: _authenticating
                        ? null
                        : () => _authenticate(
                            DeviceAuthType.biometricWithCredential),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Result display
              if (_lastSuccess != null)
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: _lastSuccess!
                          ? Colors.green
                          : theme.colorScheme.error,
                      width: 2,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: <Widget>[
                        Icon(
                          _lastSuccess! ? Icons.check_circle : Icons.cancel,
                          size: 56,
                          color: _lastSuccess!
                              ? Colors.green
                              : theme.colorScheme.error,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _lastSuccess! ? 'Authenticated' : 'Not Authenticated',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: _lastSuccess!
                                ? Colors.green
                                : theme.colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _statusMessage ?? '',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium,
                        ),
                        if (_lastAttemptTime != null) ...<Widget>[
                          const SizedBox(height: 10),
                          Text(
                            'Timestamp: ${_lastAttemptTime!.toLocal().toIso8601String().substring(11, 19)}',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: theme.colorScheme.outline),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 24),

              // Alternative: In-app face authentication without system dialog
              Card(
                elevation: 0,
                color:
                    theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(Icons.face, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Authenticate Without System Dialog',
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Prefer camera-based face verification directly inside the app without any OS system popups?',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) => const AuthenticationPage()),
                        ),
                        icon: const Icon(Icons.verified_user),
                        label: const Text('Open In-App Face Authentication'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
