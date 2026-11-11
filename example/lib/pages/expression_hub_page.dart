import 'package:flutter/material.dart';
import 'package:flutter_bio_auth/flutter_bio_auth.dart';

class ExpressionHubPage extends StatefulWidget {
  const ExpressionHubPage({super.key});

  @override
  State<ExpressionHubPage> createState() => _ExpressionHubPageState();
}

class _ExpressionHubPageState extends State<ExpressionHubPage> {
  void _openLiveMeter() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ExpressionMeterView(
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  void _openSmileChallenge() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => FaceSmileView(
          onSmiled: (confidence) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Smile verified! Confidence: ${(confidence * 100).toInt()}% 😊'),
                backgroundColor: Colors.green,
              ),
            );
          },
          onCancel: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text('Facial Expression & Sentiment AI'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          // Hero Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[Color(0xFFE91E63), Color(0xFFFF9800)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text('😊', style: TextStyle(fontSize: 32)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'On-Device Emotion & Mood Analytics',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Text(
                  'Continuous real-time classification for smiling, neutral, blinking, and winking expressions running purely on-device.',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Features
          _buildActionCard(
            context,
            icon: Icons.sentiment_very_satisfied,
            color: Colors.amber,
            title: 'Live Mood & Expression Stream',
            subtitle: 'Real-time floating emotion meter & confidence gauges',
            onTap: _openLiveMeter,
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            context,
            icon: Icons.add_reaction,
            color: Colors.pink,
            title: 'Interactive Smile Verification',
            subtitle: 'Guided turnaround smile challenge with animated progress',
            onTap: _openSmileChallenge,
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            context,
            icon: Icons.camera_front,
            color: Colors.purple,
            title: 'Instant Snapshot Sentiment Analysis',
            subtitle: 'Single-frame snapshot classification and sentiment probabilities',
            onTap: () async {
              final result = await FaceAI.detectExpression();
              if (!context.mounted) return;
              showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Snapshot Expression Result'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Dominant: ${result.expression.name.toUpperCase()}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('Confidence: ${(result.confidence * 100).toInt()}%'),
                      const SizedBox(height: 12),
                      Text('Smile: ${((result.smilingProbability ?? 0.0) * 100).toInt()}%'),
                      Text('Left Eye Open: ${((result.leftEyeOpenProbability ?? 1.0) * 100).toInt()}%'),
                      Text('Right Eye Open: ${((result.rightEyeOpenProbability ?? 1.0) * 100).toInt()}%'),
                    ],
                  ),
                  actions: <Widget>[
                    TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
