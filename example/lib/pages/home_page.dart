import 'package:flutter/material.dart';
import 'package:flutter_bio_auth/flutter_bio_auth.dart';

import 'authentication_page.dart';
import 'compare_page.dart';
import 'device_biometrics_page.dart';
import 'enrolled_users_page.dart';
import 'enrollment_page.dart';
import 'liveness_page.dart';
import 'smile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Future<List<String>>? _enrolledUsersFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _enrolledUsersFuture = FaceBiometric.getEnrolledUsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: <Widget>[
            Icon(Icons.shield_outlined, size: 26),
            SizedBox(width: 10),
            Text('Face Biometrics Demo',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Status',
            onPressed: _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: <Widget>[
            // Status Card
            FutureBuilder<List<String>>(
              future: _enrolledUsersFuture,
              builder:
                  (BuildContext context, AsyncSnapshot<List<String>> snapshot) {
                final int count = snapshot.data?.length ?? 0;
                return Card(
                  elevation: 0,
                  color: theme.colorScheme.primaryContainer.withOpacity(0.35),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                        color: theme.colorScheme.primary.withOpacity(0.2)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            CircleAvatar(
                              backgroundColor:
                                  theme.colorScheme.primary.withOpacity(0.15),
                              radius: 24,
                              child: Icon(Icons.fingerprint,
                                  color: theme.colorScheme.primary, size: 28),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    '$count User(s) Enrolled',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Encrypted AES-GCM On-Device Storage',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.outline),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Colors.green.withOpacity(0.4)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(Icons.check_circle,
                                      color: Colors.green, size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    'Ready',
                                    style: TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // Section 1: Non-AI Native Features
            _SectionHeader(
              title: 'Native & Non-AI Biometrics',
              badge: 'Zero Models Required',
              badgeColor: theme.colorScheme.primary,
            ),
            const SizedBox(height: 10),
            _FeatureCard(
              icon: Icons.face_retouching_natural,
              iconColor: Colors.teal,
              title: 'Active Liveness Verification',
              subtitle:
                  'Interactive challenge-response (Blink, Turn, Smile) via native ML Kit / Vision',
              highlightChip: 'Feature A',
              onTap: () => _push(const LivenessPage()),
            ),
            const SizedBox(height: 8),
            _FeatureCard(
              icon: Icons.security,
              iconColor: Colors.deepPurple,
              title: 'Device Biometrics Auth',
              subtitle:
                  'Authenticate using native OS prompt (Android BiometricPrompt & iOS LocalAuth)',
              highlightChip: 'System Dialog',
              onTap: () => _push(const DeviceBiometricsPage()),
            ),
            const SizedBox(height: 8),
            _FeatureCard(
              icon: Icons.sentiment_very_satisfied,
              iconColor: Colors.amber.shade700,
              title: 'Smile to Enter Happy Page',
              subtitle:
                  'Click to trigger smile detection — automatically enters Happy Page when smiled',
              highlightChip: 'On-Click Smile',
              onTap: () => _push(const SmilePage()),
            ),
            const SizedBox(height: 24),

            // Section 2: AI Face Recognition Pipeline
            const _SectionHeader(
              title: 'AI Face Recognition Pipeline',
              badge: 'MobileFaceNet 112×112',
              badgeColor: Colors.indigo,
            ),
            const SizedBox(height: 10),
            _FeatureCard(
              icon: Icons.person_add_alt_1,
              iconColor: Colors.blue,
              title: 'Enroll Face',
              subtitle:
                  'Capture 5 quality samples, eye alignment, normalize & store encrypted template',
              onTap: () => _push(const EnrollmentPage()),
            ),
            const SizedBox(height: 8),
            _FeatureCard(
              icon: Icons.verified_user,
              iconColor: Colors.green,
              title: 'In-App Face Authentication',
              subtitle:
                  'Camera scan with liveness check & face recognition — ZERO native OS dialogs',
              highlightChip: 'No OS Dialog',
              onTap: () => _push(const AuthenticationPage()),
            ),
            const SizedBox(height: 8),
            _FeatureCard(
              icon: Icons.compare,
              iconColor: Colors.orange,
              title: 'Compare Two Images',
              subtitle:
                  'Select two gallery photos to align landmarks and calculate embedding similarity',
              onTap: () => _push(const ComparePage()),
            ),
            const SizedBox(height: 8),
            _FeatureCard(
              icon: Icons.people_alt_outlined,
              iconColor: Colors.blueGrey,
              title: 'Enrolled Users',
              subtitle:
                  'View, inspect, and delete enrolled face templates on this device',
              onTap: () => _push(const EnrolledUsersPage()),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _push(Widget page) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
    _refresh();
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.badge,
    required this.badgeColor,
  });

  final String title;
  final String badge;
  final Color badgeColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: badgeColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            badge,
            style: TextStyle(
              color: badgeColor,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.highlightChip,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? highlightChip;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: theme.colorScheme.outlineVariant.withOpacity(0.7)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              CircleAvatar(
                backgroundColor: iconColor.withOpacity(0.12),
                radius: 24,
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                        if (highlightChip != null) ...<Widget>[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              highlightChip!,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: theme.colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
