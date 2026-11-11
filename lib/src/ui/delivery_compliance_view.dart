import 'dart:async';
import 'package:flutter/material.dart';

import '../compliance/compliance_options.dart';
import '../compliance/delivery_compliance_result.dart';
import '../compliance/uniform_preset.dart';
import '../face_ai.dart';
import '../face_biometric_controller.dart';
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
  final FaceBiometricController _controller = FaceBiometricController();
  StreamSubscription<DeliveryComplianceResult>? _subscription;
  DeliveryComplianceResult? _latestResult;
  bool _simulatingNonCompliantColor = false;

  @override
  void initState() {
    super.initState();
    _startInspection();
  }

  void _startInspection() {
    FaceAI.compliance.startLiveComplianceSession();
    _subscription?.cancel();
    _subscription = FaceAI.compliance
        .startComplianceStream(
          options: widget.options,
          // null allows live camera frame color sampling; non-null overrides for simulation
          clothingColor: _simulatingNonCompliantColor
              ? const Color(0xFF2E7D32) // Contrasting green clothing
              : null,
        )
        .listen((result) {
      if (mounted) {
        setState(() {
          _latestResult = result;
        });
      }
    });
  }

  void _toggleSimulatedColor() {
    setState(() {
      _simulatingNonCompliantColor = !_simulatingNonCompliantColor;
    });
    _startInspection();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _controller.dispose();
    FaceAI.compliance.stopLiveComplianceSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = _latestResult;

    final bool helmetPassed = result?.isWearingHelmet ?? false;
    final bool uniformPassed = result?.isWearingUniform ?? false;
    final bool facePassed = result?.faceVerified ?? false;
    final bool motorcyclePassed = result?.isMotorcycleVerified ?? false;
    final bool maskCheckPassed = widget.options.requireMask
        ? (result?.isWearingMask ?? false)
        : !(result?.isWearingMask ?? false);

    final bool allReady = result?.isReady ?? false;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // 1. Clear Camera Preview Feed
          const Positioned.fill(
            child: FaceBiometricCameraView(),
          ),

          // 2. Cutout Overlay with bright green reticle when detected
          Positioned.fill(
            child: FaceCutoutOverlay(
              state: allReady ? FaceBiometricState.success : FaceBiometricState.faceDetected,
            ),
          ),

          // 3. Top Header Bar: Brand Badge & Close
          Positioned(
            top: 48,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.85),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                children: <Widget>[
                  CircleAvatar(
                    backgroundColor: widget.options.targetUniform.primaryColor,
                    radius: 18,
                    child: const Icon(Icons.two_wheeler, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          'Rider Safety & Uniform Inspection',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Required: ${widget.options.targetUniform.displayName}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.onCancel != null)
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: widget.onCancel,
                    ),
                ],
              ),
            ),
          ),

          // 4. Live Inspection Checklist & Action Panel
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.90),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: allReady ? const Color(0xFF00E676) : Colors.white24,
                  width: 2,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: (allReady ? const Color(0xFF00E676) : Colors.black)
                        .withOpacity(0.35),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Overall Status
                  Row(
                    children: <Widget>[
                      Icon(
                        allReady ? Icons.check_circle : Icons.shield_outlined,
                        color: allReady ? const Color(0xFF00E676) : Colors.orangeAccent,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          allReady
                              ? 'All Checks Compliant — Ready for Shift!'
                              : 'Live Scanning Rider Safety Gear…',
                          style: TextStyle(
                            color: allReady ? const Color(0xFF00E676) : Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Gate Checklist Cards
                  _buildCheckRow(
                    icon: Icons.person_outline,
                    title: 'Face Identity',
                    passed: facePassed,
                    reason: result?.faceReason ?? 'Align face in camera',
                    required: widget.options.requireFaceVerification,
                  ),
                  const SizedBox(height: 6),
                  _buildCheckRow(
                    icon: Icons.sports_motorsports_outlined,
                    title: 'Safety Helmet',
                    passed: helmetPassed,
                    reason: result?.helmetReason ?? 'Helmet not detected',
                    required: widget.options.requireHelmet,
                  ),
                  const SizedBox(height: 6),
                  _buildCheckRow(
                    icon: Icons.two_wheeler,
                    title: 'Motorcycle Check',
                    passed: motorcyclePassed,
                    reason: result?.motorcycleReason ?? 'Two-wheeler context pending',
                    required: widget.options.requireMotorcycle,
                  ),
                  const SizedBox(height: 6),
                  _buildCheckRow(
                    icon: Icons.checkroom_outlined,
                    title: 'Uniform (${widget.options.targetUniform.displayName})',
                    passed: uniformPassed,
                    reason: result?.uniformReason ?? 'Matching uniform color…',
                    required: true,
                  ),
                  if (widget.options.requireMask) ...<Widget>[
                    const SizedBox(height: 6),
                    _buildCheckRow(
                      icon: Icons.masks_outlined,
                      title: 'Face Mask',
                      passed: maskCheckPassed,
                      reason: result?.maskReason ?? 'Mask evaluation',
                      required: true,
                    ),
                  ],

                  // Live Detected Shirt Color vs Brand Swatch
                  if (result?.detectedUniformColor != null) ...<Widget>[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: uniformPassed
                              ? const Color(0xFF00E676)
                              : Colors.redAccent.withOpacity(0.6),
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: result!.detectedUniformColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Detected Shirt: ${UniformPresetExtension.describeColor(result.detectedUniformColor!)} (${UniformPresetExtension.colorToHex(result.detectedUniformColor!)})',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Target: ${widget.options.targetUniform.displayName} (${widget.options.targetUniform.primaryColorHex})',
                                  style: TextStyle(
                                    color: uniformPassed
                                        ? const Color(0xFF00E676)
                                        : Colors.orangeAccent,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (uniformPassed ? const Color(0xFF00E676) : Colors.redAccent)
                                  .withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              uniformPassed ? 'MATCH' : 'MISMATCH',
                              style: TextStyle(
                                color: uniformPassed ? const Color(0xFF00E676) : Colors.redAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // Testing Uniform Toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      InkWell(
                        onTap: _toggleSimulatedColor,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          child: Row(
                            children: <Widget>[
                              Icon(
                                _simulatingNonCompliantColor ? Icons.error_outline : Icons.palette_outlined,
                                size: 14,
                                color: _simulatingNonCompliantColor ? Colors.redAccent : Colors.white60,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _simulatingNonCompliantColor
                                    ? 'Simulating Non-Compliant Clothing'
                                    : 'Test Non-Compliant Uniform',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _simulatingNonCompliantColor ? Colors.redAccent : Colors.white60,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Text(
                        'Confidence: ${((result?.uniformConfidence ?? 0.8) * 100).toInt()}%',
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: allReady
                            ? const Color(0xFF00E676)
                            : widget.options.targetUniform.primaryColor,
                        foregroundColor: allReady ? Colors.black : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: allReady && result != null
                          ? () => widget.onComplete(result)
                          : null,
                      icon: Icon(allReady ? Icons.check_circle : Icons.camera_alt),
                      label: Text(
                        allReady ? 'Complete Shift Check-In' : 'Waiting for Safety Compliance…',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckRow({
    required IconData icon,
    required String title,
    required bool passed,
    required String reason,
    required bool required,
  }) {
    final Color stateColor = passed ? const Color(0xFF00E676) : (required ? Colors.redAccent : Colors.white38);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(
          passed ? Icons.check_circle : (required ? Icons.cancel : Icons.remove_circle_outline),
          color: stateColor,
          size: 16,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: stateColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      passed ? 'PASS' : (required ? 'FAIL' : 'OPTIONAL'),
                      style: TextStyle(color: stateColor, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              Text(
                reason,
                style: TextStyle(
                  color: passed ? Colors.white70 : Colors.red.shade200,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
