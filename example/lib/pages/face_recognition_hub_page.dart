import 'package:flutter/material.dart';
import 'package:flutter_bio_auth/flutter_bio_auth.dart';

import 'authentication_page.dart';
import 'compare_page.dart';
import 'enrolled_users_page.dart';
import 'enrollment_page.dart';

class FaceRecognitionHubPage extends StatefulWidget {
  const FaceRecognitionHubPage({super.key});

  @override
  State<FaceRecognitionHubPage> createState() => _FaceRecognitionHubPageState();
}

class _FaceRecognitionHubPageState extends State<FaceRecognitionHubPage> {
  Future<List<String>>? _enrolledUsersFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _enrolledUsersFuture = FaceAI.recognition.getEnrolledUsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Recognition & Vault'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          // Vault Status Card
          FutureBuilder<List<String>>(
            future: _enrolledUsersFuture,
            builder: (context, snapshot) {
              final int count = snapshot.data?.length ?? 0;
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      theme.colorScheme.primary,
                      theme.colorScheme.tertiary,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: <Widget>[
                    CircleAvatar(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      radius: 28,
                      child: const Icon(Icons.badge,
                          color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '$count Identities Enrolled',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Encrypted On-Device Biometric Vault (AES-GCM)',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          Text(
            'Recognition & Matching Operations',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          _buildHubOption(
            context,
            icon: Icons.person_add_alt_1,
            color: Colors.indigo,
            title: 'Enroll New Face Identity',
            subtitle:
                'Capture multi-frame embedding and store encrypted template',
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                    builder: (context) => const EnrollmentPage()),
              );
              _refresh();
            },
          ),
          const SizedBox(height: 10),

          _buildHubOption(
            context,
            icon: Icons.verified_user,
            color: Colors.green,
            title: '1:1 Live Face Verification',
            subtitle:
                'High-speed live camera matching against enrolled template',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (context) => const AuthenticationPage()),
            ),
          ),
          const SizedBox(height: 10),

          _buildHubOption(
            context,
            icon: Icons.compare,
            color: Colors.orange,
            title: 'Compare 2 Still Face Images',
            subtitle:
                'Pick two images from gallery and compute cosine similarity',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (context) => const ComparePage()),
            ),
          ),
          const SizedBox(height: 10),

          _buildHubOption(
            context,
            icon: Icons.folder_shared,
            color: Colors.deepPurple,
            title: 'Manage Enrolled Identities Vault',
            subtitle: 'View user IDs, test 1:1 match, or delete enrollments',
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                    builder: (context) => const EnrolledUsersPage()),
              );
              _refresh();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHubOption(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          radius: 24,
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
