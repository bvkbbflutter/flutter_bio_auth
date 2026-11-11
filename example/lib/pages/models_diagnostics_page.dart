import 'package:flutter/material.dart';
import 'package:flutter_bio_auth/flutter_bio_auth.dart';

class ModelsDiagnosticsPage extends StatefulWidget {
  const ModelsDiagnosticsPage({super.key});

  @override
  State<ModelsDiagnosticsPage> createState() => _ModelsDiagnosticsPageState();
}

class _ModelsDiagnosticsPageState extends State<ModelsDiagnosticsPage> {
  DeviceCapabilities? _capabilities;
  List<ModelConfig> _models = <ModelConfig>[];
  BenchmarkResult? _lastBenchmark;
  bool _isBenchmarking = false;

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    final caps = await FaceAI.getDeviceCapabilities();
    final available = await FaceAI.models.getAvailableModels();
    if (mounted) {
      setState(() {
        _capabilities = caps;
        _models = available;
      });
    }
  }

  Future<void> _runBenchmark(String modelId) async {
    setState(() => _isBenchmarking = true);
    final result = await FaceAI.models.benchmark(modelId: modelId);
    if (mounted) {
      setState(() {
        _lastBenchmark = result;
        _isBenchmarking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final caps = _capabilities;
    final bench = _lastBenchmark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Models & Diagnostics'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          // Hardware AI Delegates Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[Color(0xFF00796B), Color(0xFF009688)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Row(
                  children: <Widget>[
                    Icon(Icons.memory, color: Colors.white, size: 28),
                    SizedBox(width: 10),
                    Text(
                      'Hardware Acceleration Engine',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Runtime: ${caps?.runtimeVersion ?? "Loading..."}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                Text(
                  'Platform: ${caps?.platformName.toUpperCase() ?? "Loading..."}',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                const Text('Available Delegates:', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: (caps?.supportedDelegates ?? <String>['CPU'])
                      .map((del) => Chip(
                            label: Text(del, style: const TextStyle(fontSize: 12)),
                            backgroundColor: Colors.white.withOpacity(0.2),
                            labelStyle: const TextStyle(color: Colors.white),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Registered Models List
          Text(
            'Registered Pluggable AI Models',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          ..._models.map((model) {
            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.withOpacity(0.2)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          model.displayName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Active',
                            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Type: ${model.type.name}', style: const TextStyle(color: Colors.grey)),
                    Text('Source: ${model.source}', style: const TextStyle(color: Colors.grey)),
                    Text('Input Size: ${model.inputSize.width.toInt()}x${model.inputSize.height.toInt()} RGB',
                        style: const TextStyle(color: Colors.grey)),
                    Text('Embedding Dimensions: ${model.embeddingDimensions}',
                        style: const TextStyle(color: Colors.grey)),
                    Text('Calibrated Cosine Threshold: ${model.calibratedThreshold}',
                        style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      onPressed: _isBenchmarking ? null : () => _runBenchmark(model.id),
                      icon: const Icon(Icons.speed, size: 18),
                      label: Text(_isBenchmarking ? 'Testing...' : 'Benchmark Speed'),
                    ),
                  ],
                ),
              ),
            );
          }),

          if (bench != null) ...<Widget>[
            const SizedBox(height: 16),
            Card(
              color: Colors.teal.shade50,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('Benchmark Diagnostics Report',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                    const SizedBox(height: 8),
                    Text('Model: ${bench.modelId}'),
                    Text('Average Latency: ${bench.averageInferenceTimeMs} ms / frame'),
                    Text('Backend: ${bench.executionBackend}'),
                    Text('Evaluated over: ${bench.iterations} iterations'),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
