import 'package:flutter/material.dart';
import 'package:flutter_bio_auth/flutter_bio_auth.dart';

import 'happy_page.dart';

/// Screen opened on click to verify a smile before entering HappyPage.
/// Uses the turnkey [FaceSmileView] provided directly by flutter_bio_auth.
class SmilePage extends StatelessWidget {
  const SmilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smile to Enter'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FaceSmileView(
            title: 'Please smile to enter Happy Page 😊',
            timeout: const Duration(seconds: 45),
            onSmiled: (double confidence) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) => HappyPage(smileConfidence: confidence),
                ),
              );
            },
            onCancel: () => Navigator.of(context).maybePop(),
          ),
        ),
      ),
    );
  }
}
