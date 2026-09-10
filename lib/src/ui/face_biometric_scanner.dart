import 'dart:async';
import 'package:flutter/material.dart';

import '../face_biometric_controller.dart';
import '../face_biometric_state.dart';
import '../liveness_challenge.dart';
import '../liveness_state.dart';
import 'face_biometric_camera_view.dart';
import 'face_cutout_overlay.dart';

/// Turnkey biometric camera scanning widget.
///
/// Combines the native camera feed, an elliptical cutout mask, an animated
/// glowing reticle, a live countdown timer badge, real-time challenge
/// progress card, and state indicators.
class FaceBiometricScanner extends StatefulWidget {
  const FaceBiometricScanner({
    super.key,
    required this.controller,
    this.timeoutSeconds = 25,
    this.title = 'Position face inside the oval',
    this.showTimer = true,
    this.onClose,
  });

  final FaceBiometricController controller;
  final int timeoutSeconds;
  final String title;
  final bool showTimer;
  final VoidCallback? onClose;

  @override
  State<FaceBiometricScanner> createState() => _FaceBiometricScannerState();
}

class _FaceBiometricScannerState extends State<FaceBiometricScanner> {
  late int _remainingSeconds;
  Timer? _countdownTimer;
  StreamSubscription<LivenessChallengeProgress>? _progressSub;
  String? _lastChallengeName;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.timeoutSeconds;
    _startTimer();

    // Reset challenge countdown when challenge transitions
    _progressSub = widget.controller.challengeProgressStream.listen((LivenessChallengeProgress p) {
      if (p.challenge.name != _lastChallengeName) {
        _lastChallengeName = p.challenge.name;
      }
    });
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) return;
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _progressSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String timerText = '00:${_remainingSeconds.toString().padLeft(2, '0')}';
    final bool isUrgent = _remainingSeconds <= 5;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // 1. Native camera fills available area
          const FaceBiometricCameraView(),

          // 2. Cutout mask with transparent central ellipse & glowing reticle
          StreamBuilder<FaceBiometricState>(
            stream: widget.controller.stateStream,
            builder: (BuildContext context, AsyncSnapshot<FaceBiometricState> snap) {
              return FaceCutoutOverlay(state: snap.data);
            },
          ),

          // 3. Top Header Bar: Guidance & Countdown Timer
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                // Guidance Badge
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(Icons.face_retouching_natural, color: Colors.cyanAccent, size: 16),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            widget.title,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Live Countdown Timer Badge
                if (widget.showTimer)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: isUrgent ? Colors.red.withOpacity(0.85) : Colors.black.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isUrgent ? Colors.redAccent : Colors.white24,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.timer_outlined,
                          size: 14,
                          color: isUrgent ? Colors.white : Colors.amberAccent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          timerText,
                          style: TextStyle(
                            color: isUrgent ? Colors.white : Colors.amberAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                if (widget.onClose != null) ...<Widget>[
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: widget.onClose,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.75),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 4. Bottom Challenge HUD & Status
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                StreamBuilder<LivenessChallengeProgress>(
                  stream: widget.controller.challengeProgressStream,
                  builder: (BuildContext context, AsyncSnapshot<LivenessChallengeProgress> snap) {
                    final LivenessChallengeProgress? p = snap.data;
                    if (p == null || p.completed) return const SizedBox.shrink();
                    return _ChallengeCard(progress: p);
                  },
                ),
                const SizedBox(height: 6),
                StreamBuilder<FaceBiometricState>(
                  stream: widget.controller.stateStream,
                  builder: (BuildContext context, AsyncSnapshot<FaceBiometricState> snap) {
                    return _StatusBadge(state: snap.data);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({required this.progress});

  final LivenessChallengeProgress progress;

  @override
  Widget build(BuildContext context) {
    final IconData icon = _iconFor(progress.challenge);
    final String label = progress.instruction.isNotEmpty
        ? progress.instruction
        : _titleFor(progress.challenge);

    return Card(
      color: Colors.black.withOpacity(0.85),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.amberAccent, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(
                  backgroundColor: Colors.amberAccent.withOpacity(0.2),
                  child: Icon(icon, color: Colors.amberAccent, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Progress ${(progress.progress * 100).toInt()}%',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress.progress.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.amberAccent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(LivenessChallenge c) {
    switch (c) {
      case LivenessChallenge.blink:
        return Icons.visibility;
      case LivenessChallenge.smile:
        return Icons.sentiment_very_satisfied;
      case LivenessChallenge.turnLeft:
        return Icons.arrow_back;
      case LivenessChallenge.turnRight:
        return Icons.arrow_forward;
      case LivenessChallenge.lookUp:
        return Icons.arrow_upward;
      case LivenessChallenge.lookDown:
        return Icons.arrow_downward;
      case LivenessChallenge.moveCloser:
        return Icons.zoom_in;
      case LivenessChallenge.moveAway:
        return Icons.zoom_out;
    }
  }

  String _titleFor(LivenessChallenge c) {
    switch (c) {
      case LivenessChallenge.blink:
        return 'Blink both eyes';
      case LivenessChallenge.smile:
        return 'Smile';
      case LivenessChallenge.turnLeft:
        return 'Turn head left';
      case LivenessChallenge.turnRight:
        return 'Turn head right';
      case LivenessChallenge.lookUp:
        return 'Tilt head up';
      case LivenessChallenge.lookDown:
        return 'Tilt head down';
      case LivenessChallenge.moveCloser:
        return 'Move closer';
      case LivenessChallenge.moveAway:
        return 'Move further away';
    }
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.state});

  final FaceBiometricState? state;

  @override
  Widget build(BuildContext context) {
    if (state == null) return const SizedBox.shrink();

    String label;
    Color color;

    switch (state!) {
      case FaceBiometricState.idle:
      case FaceBiometricState.initializing:
        label = 'Initializing…';
        color = Colors.white70;
        break;
      case FaceBiometricState.cameraReady:
      case FaceBiometricState.detectingFace:
        label = 'Detecting Face…';
        color = Colors.cyanAccent;
        break;
      case FaceBiometricState.faceDetected:
        label = 'Face Detected';
        color = Colors.greenAccent;
        break;
      case FaceBiometricState.validatingFace:
        label = 'Hold steady…';
        color = Colors.greenAccent;
        break;
      case FaceBiometricState.runningLiveness:
      case FaceBiometricState.challengeInProgress:
        label = 'Performing Challenge…';
        color = Colors.amberAccent;
        break;
      case FaceBiometricState.generatingEmbedding:
        label = 'Processing Embedding…';
        color = Colors.lightBlueAccent;
        break;
      case FaceBiometricState.checkingAntiSpoof:
        label = 'Checking Anti-Spoof…';
        color = Colors.lightBlueAccent;
        break;
      case FaceBiometricState.matchingFace:
      case FaceBiometricState.authenticating:
        label = 'Matching Face…';
        color = Colors.lightBlueAccent;
        break;
      case FaceBiometricState.success:
        label = 'Success!';
        color = Colors.greenAccent;
        break;
      case FaceBiometricState.failed:
        label = 'Verification Failed';
        color = Colors.redAccent;
        break;
      case FaceBiometricState.timeout:
        label = 'Timed Out';
        color = Colors.redAccent;
        break;
      case FaceBiometricState.permissionDenied:
        label = 'Camera Permission Denied';
        color = Colors.redAccent;
        break;
      case FaceBiometricState.error:
        label = 'Error Encountered';
        color = Colors.redAccent;
        break;
      case FaceBiometricState.requestingPermission:
        label = 'Requesting Camera…';
        color = Colors.white70;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
