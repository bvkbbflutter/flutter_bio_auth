import 'package:flutter/material.dart';

/// Generic success/failure summary screen, reused by enrollment,
/// authentication, and compare flows so results are always shown the
/// same way. Never shows raw biometric data (embeddings, templates).
class ResultPage extends StatelessWidget {
  const ResultPage({
    super.key,
    required this.success,
    required this.title,
    required this.details,
  });

  final bool success;
  final String title;
  final Map<String, String> details;

  @override
  Widget build(BuildContext context) {
    final Color color = success ? Colors.green : Theme.of(context).colorScheme.error;
    return Scaffold(
      appBar: AppBar(title: const Text('Result')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(success ? Icons.check_circle : Icons.cancel, color: color, size: 72),
              const SizedBox(height: 16),
              Text(title, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: details.entries
                        .map(
                          (MapEntry<String, String> e) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                                Text(e.value),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
