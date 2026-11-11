import 'package:flutter/material.dart';
import 'package:flutter_bio_auth/flutter_bio_auth.dart';
import 'package:permission_handler/permission_handler.dart';

import 'pages/home_page.dart';

void main() {
  runApp(const FaceBiometricExampleApp());
}

class FaceBiometricExampleApp extends StatefulWidget {
  const FaceBiometricExampleApp({super.key});

  @override
  State<FaceBiometricExampleApp> createState() =>
      _FaceBiometricExampleAppState();
}

class _FaceBiometricExampleAppState extends State<FaceBiometricExampleApp> {
  late final Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Request camera permission upfront when loading the app
    try {
      final PermissionStatus status = await Permission.camera.status;
      if (!status.isGranted) {
        await Permission.camera.request();
      }
    } catch (_) {
      // Graceful fallback in test or headless environments
    }

    await FaceBiometric.initialize(
      config: const FaceBiometricConfig(
        recognitionThreshold: 0.65,
        livenessThreshold: 0.80,
        antiSpoofThreshold: 0.80,
        enableLiveness: true,
        // Anti-spoofing is off by default in the example so it runs
        // out of the box without a bundled model. Turn this on (and
        // set antiSpoofModelAssetPath) once you've added a real
        // model -- see the root README.
        enableAntiSpoofing: false,
        authenticationMode: FaceAuthenticationMode.faceWithLiveness,
        randomizeChallenges: true,
        challenges: <LivenessChallenge>[
          LivenessChallenge.blink,
          LivenessChallenge.turnLeft,
          LivenessChallenge.turnRight,
        ],
        // Bundled MobileFaceNet model (112x112 RGB, 192-d output)
        // enables real face recognition, enrollment, and comparison!
        embeddingModelAssetPath: 'assets/models/mobilefacenet.tflite',
        antiSpoofModelAssetPath: null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Face Biometric Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3F5AA6)),
        useMaterial3: true,
      ),
      home: FutureBuilder<void>(
        future: _initFuture,
        builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Failed to initialize flutter_bio_auth:\n${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }
          return const HomePage();
        },
      ),
    );
  }
}
