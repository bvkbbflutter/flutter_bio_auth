import 'package:flutter/material.dart';
import 'package:flutter_bio_auth/flutter_bio_auth.dart';

import 'delivery_compliance_page.dart';
import 'device_biometrics_page.dart';
import 'expression_hub_page.dart';
import 'face_recognition_hub_page.dart';
import 'liveness_page.dart';
import 'models_diagnostics_page.dart';

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
      _enrolledUsersFuture = FaceAI.recognition.getEnrolledUsers();
    });
  }

  void _navigate(Widget page) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (context) => page),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: <Widget>[
            Icon(Icons.auto_awesome, size: 24, color: Color(0xFF5200FF)),
            SizedBox(width: 10),
            Text('Face Intelligence SDK',
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
            // SDK Overview Header Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: <Color>[Color(0xFF2C3E50), Color(0xFF4CA1AF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        'Modular AI Face Intelligence',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Chip(
                        label: Text('v0.2.0',
                            style:
                                TextStyle(fontSize: 11, color: Colors.white)),
                        backgroundColor: Colors.white24,
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'One Flutter plugin · Multiple AI models · Independent subsystems · Zero backend needed',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  FutureBuilder<List<String>>(
                    future: _enrolledUsersFuture,
                    builder: (context, snapshot) {
                      final count = snapshot.data?.length ?? 0;
                      return Row(
                        children: <Widget>[
                          const Icon(Icons.shield_outlined,
                              color: Colors.greenAccent, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            '$count Enrolled Identities in Vault',
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Section 1: Zepto / Delivery Compliance Hub (Highlighted)
            _buildSectionTitle('DELIVERY PARTNER AI (ZEPTO / RIDER)'),
            _buildHubCard(
              icon: Icons.two_wheeler,
              accentColor: const Color(0xFF5200FF),
              title: '🛵 Zepto / Rider Safety & Uniform Hub',
              subtitle:
                  'Multi-factor shift check-in: Face match, Helmet detection, Mask check, and Zepto Purple Uniform verification.',
              badge: 'Specialized',
              onTap: () => _navigate(const DeliveryCompliancePage()),
            ),
            const SizedBox(height: 16),

            // Section 2: Recognition & Identity Vault
            _buildSectionTitle('FACE RECOGNITION & BIOMETRIC VAULT'),
            _buildHubCard(
              icon: Icons.fingerprint,
              accentColor: Colors.indigo,
              title: '👤 Face Recognition Hub',
              subtitle:
                  '1:1 Live Verification, Template Enrollment, Direct 2-Photo Cosine Matching, and Enrolled Identities Manager.',
              badge: 'Model-Driven',
              onTap: () => _navigate(const FaceRecognitionHubPage()),
            ),
            const SizedBox(height: 16),

            // Section 3: Expression & Sentiment AI
            _buildSectionTitle('FACIAL EXPRESSIONS & MOOD AI'),
            _buildHubCard(
              icon: Icons.sentiment_very_satisfied,
              accentColor: Colors.pink,
              title: '😊 Facial Expression & Mood Hub',
              subtitle:
                  'Real-time emotion stream, continuous smile confidence meter, and winking/blinking analytics.',
              badge: 'Real-Time',
              onTap: () => _navigate(const ExpressionHubPage()),
            ),
            const SizedBox(height: 16),

            // Section 4: Liveness & Anti-Spoofing
            _buildSectionTitle('ACTIVE & PASSIVE LIVENESS'),
            _buildHubCard(
              icon: Icons.face_retouching_natural,
              accentColor: Colors.teal,
              title: '🛡️ Liveness & Anti-Spoofing Hub',
              subtitle:
                  'Interactive challenge sequencer (Blink, Turn Left/Right, Smile) and presentation attack protection.',
              badge: 'Zero Models',
              onTap: () => _navigate(const LivenessPage()),
            ),
            const SizedBox(height: 16),

            // Section 5: Local Device Biometrics
            _buildSectionTitle('LOCAL DEVICE AUTHENTICATION'),
            _buildHubCard(
              icon: Icons.security,
              accentColor: Colors.deepPurple,
              title: '📱 Local Device Biometrics Hub',
              subtitle:
                  'OS-level Android BiometricPrompt & Apple Face ID / Touch ID with typed success, lockout, and cancel results.',
              badge: 'OS Native',
              onTap: () => _navigate(const DeviceBiometricsPage()),
            ),
            const SizedBox(height: 16),

            // Section 6: AI Models & Diagnostics
            _buildSectionTitle('PLUGGABLE AI MODELS & RUNTIME'),
            _buildHubCard(
              icon: Icons.memory,
              accentColor: Colors.teal.shade700,
              title: '⚙️ AI Models & Hardware Diagnostics',
              subtitle:
                  'Model registry, on-device latency benchmarking (ms), hardware delegate inspection (CPU, NNAPI, GPU).',
              badge: 'Model Manager',
              onTap: () => _navigate(const ModelsDiagnosticsPage()),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildHubCard({
    required IconData icon,
    required Color accentColor,
    required String title,
    required String subtitle,
    required String badge,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              CircleAvatar(
                radius: 24,
                backgroundColor: accentColor.withOpacity(0.14),
                child: Icon(icon, color: accentColor, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              color: accentColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child:
                    Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
