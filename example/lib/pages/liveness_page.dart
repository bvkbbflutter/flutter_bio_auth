import 'package:flutter/material.dart';
import 'package:flutter_bio_auth/flutter_bio_auth.dart';
import 'package:permission_handler/permission_handler.dart';

/// Standalone Active Liveness Verification screen (Feature A).
/// Uses the turnkey [FaceLivenessView] provided directly by flutter_bio_auth.
class LivenessPage extends StatefulWidget {
  const LivenessPage({super.key});

  @override
  State<LivenessPage> createState() => _LivenessPageState();
}

class _LivenessPageState extends State<LivenessPage> {
  bool _verifying = false;
  String? _error;
  LivenessResult? _result;

  final List<LivenessChallenge> _selectedChallenges = <LivenessChallenge>[
    LivenessChallenge.blink,
    LivenessChallenge.turnLeft,
    LivenessChallenge.turnRight,
  ];

  Future<void> _startLiveness() async {
    final PermissionStatus status = await Permission.camera.request();
    if (!status.isGranted) {
      setState(() =>
          _error = 'Camera permission is required for liveness detection.');
      return;
    }

    setState(() {
      _verifying = true;
      _error = null;
      _result = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Liveness'),
        actions: <Widget>[
          if (!_verifying)
            IconButton(
              icon: const Icon(Icons.tune),
              tooltip: 'Configure Challenges',
              onPressed: _showChallengeConfigDialog,
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Card(
                color: theme.colorScheme.primaryContainer.withOpacity(0.4),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                      color: theme.colorScheme.primary.withOpacity(0.2)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.bolt,
                          color: theme.colorScheme.primary, size: 24),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Zero AI Model Dependencies. Runs 100% on-device using native ML Kit / Vision.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_error != null) ...<Widget>[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.error_outline, color: theme.colorScheme.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                              color: theme.colorScheme.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Expanded(
                child: _verifying
                    ? FaceLivenessView(
                        challenges: _selectedChallenges,
                        timeout: const Duration(seconds: 45),
                        onCompleted: (LivenessResult res) {
                          if (mounted) {
                            setState(() {
                              _verifying = false;
                              _result = res;
                            });
                          }
                        },
                        onError: (String err) {
                          if (mounted) {
                            setState(() {
                              _verifying = false;
                              _error = err;
                            });
                          }
                        },
                        onClose: () {
                          if (mounted) {
                            setState(() => _verifying = false);
                          }
                        },
                      )
                    : (_result != null
                        ? _buildResultCard(theme)
                        : _buildIdleCard(theme)),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _verifying ? null : _startLiveness,
                icon: Icon(_verifying ? Icons.hourglass_top : Icons.play_arrow),
                label: Text(
                  _verifying
                      ? 'Verifying Liveness…'
                      : (_result == null
                          ? 'Start Liveness Check'
                          : 'Test Again'),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIdleCard(ThemeData theme) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.face_retouching_natural,
                size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Active Liveness Verification',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Verifies the presence of a live human by prompting random interactive gestures (blinking, head turning, smiling).',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _selectedChallenges.map((LivenessChallenge c) {
                return Chip(
                  avatar: const Icon(Icons.check, size: 16),
                  label: Text(c.name),
                  backgroundColor: theme.colorScheme.surface,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(ThemeData theme) {
    final LivenessResult res = _result!;
    final bool passed = res.passed;
    final Color statusColor = passed ? Colors.green : theme.colorScheme.error;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: statusColor, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              passed ? Icons.verified : Icons.highlight_off,
              color: statusColor,
              size: 64,
            ),
            const SizedBox(height: 12),
            Text(
              passed ? 'Liveness Confirmed' : 'Liveness Verification Failed',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              passed
                  ? 'Real, living human subject verified.'
                  : (res.failedChallenge != null
                      ? 'Failed on challenge: ${res.failedChallenge!.name}'
                      : 'Could not complete challenges.'),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: <Widget>[
                  _MetricRow(
                    label: 'Overall Confidence Score',
                    value: '${(res.overallScore * 100).toStringAsFixed(1)}%',
                    valueColor: statusColor,
                  ),
                  const Divider(height: 16),
                  _MetricRow(
                    label: 'Completed Challenges',
                    value:
                        '${res.completedChallenges.length} of ${_selectedChallenges.length}',
                  ),
                  if (res.failedChallenge != null) ...<Widget>[
                    const Divider(height: 16),
                    _MetricRow(
                      label: 'Failed Challenge',
                      value: res.failedChallenge!.name,
                      valueColor: theme.colorScheme.error,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: res.completedChallenges.map((LivenessChallenge c) {
                return Chip(
                  avatar: const Icon(Icons.check_circle,
                      color: Colors.green, size: 18),
                  label: Text(c.name),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _showChallengeConfigDialog() {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('Configure Challenges'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: LivenessChallenge.values.map((LivenessChallenge c) {
                  final bool isSelected = _selectedChallenges.contains(c);
                  return CheckboxListTile(
                    title: Text(c.name),
                    value: isSelected,
                    onChanged: (bool? val) {
                      setDialogState(() {
                        if (val == true) {
                          _selectedChallenges.add(c);
                        } else if (_selectedChallenges.length > 1) {
                          _selectedChallenges.remove(c);
                        }
                      });
                      setState(() {});
                    },
                  );
                }).toList(),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
