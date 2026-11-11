import 'package:flutter/material.dart';
import '../face_biometric_state.dart';

/// Draws a semi-transparent or dark scrim over the entire viewport with an
/// elliptical transparent hole cut out in the center, and paints an animated
/// biometric glowing border along the perimeter of the ellipse.
class FaceCutoutOverlay extends StatelessWidget {
  const FaceCutoutOverlay({
    super.key,
    required this.state,
    this.scrimColor = const Color(0xCC000000),
    this.ovalWidthFactor = 0.64,
    this.ovalAspectRatio = 1.30,
    this.borderWidth = 3.5,
  });

  final FaceBiometricState? state;
  final Color scrimColor;
  final double ovalWidthFactor;
  final double ovalAspectRatio;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final double ovalWidth = (size.width * ovalWidthFactor).clamp(210.0, 270.0);
    final double ovalHeight = ovalWidth * ovalAspectRatio;

    final Color borderColor = _colorForState(state);

    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _CutoutPainter(
          ovalWidth: ovalWidth,
          ovalHeight: ovalHeight,
          scrimColor: scrimColor,
          borderColor: borderColor,
          borderWidth: borderWidth,
        ),
      ),
    );
  }

  Color _colorForState(FaceBiometricState? s) {
    switch (s) {
      case null:
      case FaceBiometricState.idle:
      case FaceBiometricState.initializing:
      case FaceBiometricState.requestingPermission:
        return Colors.white38;
      case FaceBiometricState.cameraReady:
      case FaceBiometricState.detectingFace:
        return Colors.cyanAccent;
      case FaceBiometricState.faceDetected:
      case FaceBiometricState.validatingFace:
      case FaceBiometricState.runningLiveness:
      case FaceBiometricState.challengeInProgress:
      case FaceBiometricState.generatingEmbedding:
      case FaceBiometricState.checkingAntiSpoof:
      case FaceBiometricState.matchingFace:
      case FaceBiometricState.authenticating:
      case FaceBiometricState.success:
        // Always display a vibrant green indicator when a face is detected
        return const Color(0xFF00E676);
      case FaceBiometricState.failed:
      case FaceBiometricState.timeout:
      case FaceBiometricState.permissionDenied:
      case FaceBiometricState.error:
        return Colors.redAccent;
    }
  }
}

class _CutoutPainter extends CustomPainter {
  _CutoutPainter({
    required this.ovalWidth,
    required this.ovalHeight,
    required this.scrimColor,
    required this.borderColor,
    required this.borderWidth,
  });

  final double ovalWidth;
  final double ovalHeight;
  final Color scrimColor;
  final Color borderColor;
  final double borderWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect fullRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final double left = (size.width - ovalWidth) / 2;
    // Position slightly above vertical center to account for bottom HUD
    final double top = ((size.height - ovalHeight) / 2) - 24;
    final Rect ovalRect = Rect.fromLTWH(left, top, ovalWidth, ovalHeight);

    // 1. Draw scrim with transparent elliptical hole
    final Path backgroundPath = Path()..addRect(fullRect);
    final Path holePath = Path()..addOval(ovalRect);
    final Path combinedPath = Path.combine(PathOperation.difference, backgroundPath, holePath);

    final Paint scrimPaint = Paint()
      ..color = scrimColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(combinedPath, scrimPaint);

    // 2. Draw outer glow
    final Paint glowPaint = Paint()
      ..color = borderColor.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth + 8
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawOval(ovalRect, glowPaint);

    // 3. Draw solid sharp border on perimeter
    final Paint borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;
    canvas.drawOval(ovalRect, borderPaint);

    // 4. Draw corner bracket accents
    _drawBracketAccents(canvas, ovalRect, borderColor);
  }

  void _drawBracketAccents(Canvas canvas, Rect r, Color color) {
    final Paint bracketPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final double len = 18.0;
    final double inset = 4.0;

    // Top-left
    canvas.drawLine(Offset(r.left - inset, r.top + len), Offset(r.left - inset, r.top - inset), bracketPaint);
    canvas.drawLine(Offset(r.left - inset, r.top - inset), Offset(r.left + len, r.top - inset), bracketPaint);

    // Top-right
    canvas.drawLine(Offset(r.right + inset, r.top + len), Offset(r.right + inset, r.top - inset), bracketPaint);
    canvas.drawLine(Offset(r.right + inset, r.top - inset), Offset(r.right - len, r.top - inset), bracketPaint);

    // Bottom-left
    canvas.drawLine(Offset(r.left - inset, r.bottom - len), Offset(r.left - inset, r.bottom + inset), bracketPaint);
    canvas.drawLine(Offset(r.left - inset, r.bottom + inset), Offset(r.left + len, r.bottom + inset), bracketPaint);

    // Bottom-right
    canvas.drawLine(Offset(r.right + inset, r.bottom - len), Offset(r.right + inset, r.bottom + inset), bracketPaint);
    canvas.drawLine(Offset(r.right + inset, r.bottom + inset), Offset(r.right - len, r.bottom + inset), bracketPaint);
  }

  @override
  bool shouldRepaint(_CutoutPainter old) =>
      old.ovalWidth != ovalWidth ||
      old.ovalHeight != ovalHeight ||
      old.scrimColor != scrimColor ||
      old.borderColor != borderColor ||
      old.borderWidth != borderWidth;
}
