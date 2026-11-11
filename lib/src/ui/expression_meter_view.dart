import 'dart:async';
import 'package:flutter/material.dart';

import '../expression/expression_result.dart';
import '../expression/facial_expression.dart';
import '../face_ai.dart';
import '../face_biometric_state.dart';
import 'face_biometric_camera_view.dart';
import 'face_cutout_overlay.dart';

/// Turnkey widget displaying live facial expressions, smile progress, and emotion bars.
class ExpressionMeterView extends StatefulWidget {
  const ExpressionMeterView({
    super.key,
    this.title = 'Real-Time Facial Expression AI',
    this.onClose,
  });

  final String title;
  final VoidCallback? onClose;

  @override
  State<ExpressionMeterView> createState() => _ExpressionMeterViewState();
}

class _ExpressionMeterViewState extends State<ExpressionMeterView> {
  StreamSubscription<ExpressionResult>? _sub;
  ExpressionResult _current = const ExpressionResult(
    expression: FacialExpression.neutral,
    confidence: 0.85,
    expressions: {
      FacialExpression.smile: 0.10,
      FacialExpression.neutral: 0.85,
      FacialExpression.blink: 0.05,
    },
    smilingProbability: 0.10,
    leftEyeOpenProbability: 0.95,
    rightEyeOpenProbability: 0.95,
  );

  @override
  void initState() {
    super.initState();
    _startLive();
  }

  Future<void> _startLive() async {
    await FaceAI.expression.startLiveExpressionSession();
    _sub = FaceAI.startExpressionStream().listen((result) {
      if (mounted) {
        setState(() {
          _current = result;
        });
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    FaceAI.expression.stopLiveExpressionSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: FaceBiometricCameraView()),
          const Positioned.fill(
            child: FaceCutoutOverlay(
              state: FaceBiometricState.faceDetected,
            ),
          ),

          // Header
          Positioned(
            top: 48,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (widget.onClose != null)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: widget.onClose,
                  ),
              ],
            ),
          ),

          // Bottom Expression Dashboard
          Positioned(
            bottom: 32,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.85),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        _getEmoji(_current.expression),
                        style: const TextStyle(fontSize: 36),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              _current.expression.name.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Confidence: ${(_current.confidence * 100).toInt()}%',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildProgressBar(
                    'Smile',
                    _current.expressions[FacialExpression.smile] ?? 0.0,
                    const Color(0xFF00E676),
                  ),
                  const SizedBox(height: 8),
                  _buildProgressBar(
                    'Neutral',
                    _current.expressions[FacialExpression.neutral] ?? 0.0,
                    Colors.cyanAccent,
                  ),
                  const SizedBox(height: 8),
                  _buildProgressBar(
                    'Eye Openness',
                    ((_current.leftEyeOpenProbability ?? 0.9) +
                            (_current.rightEyeOpenProbability ?? 0.9)) /
                        2.0,
                    Colors.amberAccent,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getEmoji(FacialExpression exp) {
    switch (exp) {
      case FacialExpression.smile:
        return '😊';
      case FacialExpression.neutral:
        return '😐';
      case FacialExpression.blink:
        return '😑';
      case FacialExpression.wink:
        return '😉';
      case FacialExpression.surprised:
        return '😲';
      case FacialExpression.sad:
        return '😢';
      case FacialExpression.angry:
        return '😠';
      case FacialExpression.unknown:
        return '🤔';
    }
  }

  Widget _buildProgressBar(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            Text('${(value * 100).toInt()}%',
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            backgroundColor: Colors.white12,
            color: color,
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}
