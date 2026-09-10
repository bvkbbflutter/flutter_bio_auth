import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Renders the platform-native camera preview view.
///
/// On Android, uses `AndroidView(viewType: 'flutter_bio_auth/camera_preview')`.
/// On iOS, uses `UiKitView(viewType: 'flutter_bio_auth/camera_preview')`.
class FaceBiometricCameraView extends StatelessWidget {
  const FaceBiometricCameraView({super.key});

  static const String viewType = 'flutter_bio_auth/camera_preview';

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Text(
            'Camera preview is not supported on web.',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }
    if (Platform.isAndroid) {
      return const AndroidView(
        viewType: viewType,
        creationParams: <String, Object?>{},
        creationParamsCodec: StandardMessageCodec(),
      );
    }
    if (Platform.isIOS) {
      return const UiKitView(
        viewType: viewType,
        creationParams: <String, Object?>{},
        creationParamsCodec: StandardMessageCodec(),
      );
    }
    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: Text(
          'Unsupported platform.',
          style: TextStyle(color: Colors.white70),
        ),
      ),
    );
  }
}
