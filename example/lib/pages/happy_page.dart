import 'package:flutter/material.dart';

/// The destination page navigated to when the user smiles.
/// Celebrates the detected smile with cheerful animations and delightful UI.
class HappyPage extends StatelessWidget {
  const HappyPage({
    super.key,
    this.smileConfidence = 1.0,
  });

  final double smileConfidence;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color(0xFFFFF9C4), // Light golden yellow
              Color(0xFFFFE082), // Warm amber yellow
              Color(0xFFFFD54F), // Joyful gold
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Spacer(),

                // Bouncing smiling emoji avatar
                Center(
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.amber.withOpacity(0.4),
                          blurRadius: 28,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.sentiment_very_satisfied,
                        size: 96,
                        color: Color(0xFFFF8F00),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Celebratory Header
                Text(
                  'You Smiled! 😊',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF4E342E),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),

                Text(
                  'Welcome to your Happy Page!\nYour genuine smile was verified on-device.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF5D4037),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),

                // Confidence badge card
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(Icons.verified, color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Smile Verified: ${(smileConfidence * 100).toStringAsFixed(0)}% Confidence',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E7D32),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // Action buttons
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Return to Home'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF4E342E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
