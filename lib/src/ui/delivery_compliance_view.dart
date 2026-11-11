import 'dart:async';
import 'package:flutter/material.dart';

import '../compliance/compliance_options.dart';
import '../compliance/delivery_compliance_result.dart';
import '../compliance/uniform_preset.dart';
import '../face_ai.dart';
import '../face_biometric_state.dart';
import 'face_biometric_camera_view.dart';
import 'face_cutout_overlay.dart';

/// Full turnkey UI widget for Zepto / Delivery Partner shift check-in.
///
/// Inspects:
/// - Face Verification (Identity Match)
/// - Helmet Detection (Safety Helmet Worn)
/// - Mask Status (Wearing Mask / No Mask)
/// - Uniform Detection (Zepto Purple / Custom Uniform)
class DeliveryComplianceView extends StatefulWidget {
  const DeliveryComplianceView({
    super.key,
    this.userId,
    this.options = const ComplianceOptions(),
    required this.onComplete,
    this.onCancel,
  });

  final String? userId;
  final ComplianceOptions options;
  final ValueChanged<DeliveryComplianceResult> onComplete;
  final VoidCallback? onCancel;

  @override
  State<DeliveryComplianceView> createState() => _DeliveryComplianceViewState();
}

class _DeliveryComplianceViewState extends State<DeliveryComplianceView> {
  StreamSubscription<DeliveryComplianceResult>? _subscription;
  DeliveryComplianceResult? _latestResult;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _startInspection();
  }

  void _startInspection() {
    _subscription = FaceAI.compliance
        .startComplianceStream(options: widget.options)
        .listen((result) {
      if (mounted) {
        setState(() {
          _latestResult = result;
        });

        if (result.isReady && _isChecking) {
          _isChecking = false;
          Future.delayed(const Duration(milliseconds: 900), () {
            if (mounted) widget.onComplete(result);
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = _latestResult;

    final bool helmetPassed = result?.isWearingHelmet ?? false;
    final bool uniformPassed = result?.isWearingUniform ?? false;
    final bool facePassed = result?.faceVerified ?? false;
    final bool maskCheckPassed = widget.options.requireMask
        ? (result?.isWearingMask ?? false)
        : !(result?.isWearingMask ?? false);

    final bool allReady = result?.isReady ?? false;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: <Widget>[
          // Camera Preview
          const Positioned.fill(
            child: FaceBiometricCameraView(),
          ),

          // Cutout Overlay
          Positioned.fill(
            child: FaceCutoutOverlay(
              state: allReady ? FaceBiometricState.success : FaceBiometricState.validatingFace,
            ),
          ),

          // Top Header & Brand Bar
          Positioned(
            top: 48,
            left: 16,
            right: 16,
            child: Row(
              children: <Widget>[
                CircleAvatar(
                  backgroundColor: widget.options.targetUniform.primaryColor,
                  radius: 20,
                  child: const Icon(Icons.two_wheeler, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Rider Safety & Uniform Inspection',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.options.targetUniform.displayName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.onCancel != null)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: widget.onCancel,
                  ),
              ],
            ),
          ),

          // Live Checklist Floating Cards
          Positioned(
            bottom: 32,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.85),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: allReady ? Colors.greenAccent : Colors.white24,
                  width: 2,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: (allReady ? Colors.greenAccent : Colors.black)
                        .withOpacity(0.35),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // Status Banner
                  Row(
                    children: <Widget>[
                      Icon(
                        allReady ? Icons.check_circle : Icons.sync,
                        color: allReady ? Colors.greenAccent : Colors.orangeAccent,
                        size: 26,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          allReady
                              ? 'Verified & Ready for Duty!'
                              : 'Align your head and upper body...',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Pill Checklist Grid
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      _buildStatusPill(
                        icon: Icons.person_outline,
                        label: 'Face Verified',
                        passed: facePassed,
                      ),
                      _buildStatusPill(
                        icon: Icons.sports_motorsports_outlined,
                        label: 'Helmet',
                        passed: helmetPassed,
                      ),
                      _buildStatusPill(
                        icon: Icons.checkroom_outlined,
                        label: widget.options.targetUniform == UniformPreset.zeptoPurple
                            ? 'Zepto Uniform'
                            : 'Uniform',
                        passed: uniformPassed,
                      ),
                      _buildStatusPill(
                        icon: Icons.masks_outlined,
                        label: widget.options.requireMask ? 'Mask On' : 'No Mask',
                        passed: maskCheckPassed,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill({
    required IconData icon,
    required String label,
    required bool passed,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: passed
            ? Colors.green.withOpacity(0.2)
            : Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: passed ? Colors.greenAccent : Colors.white24,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            passed ? Icons.check : icon,
            size: 16,
            color: passed ? Colors.greenAccent : Colors.white60,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: passed ? Colors.greenAccent : Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}
