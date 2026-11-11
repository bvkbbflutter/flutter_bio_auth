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
  ModelConfig? _activeRecognitionModel;
  BenchmarkResult? _lastBenchmark;
  bool _isBenchmarking = false;
  String? _benchmarkingModelId;

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    final caps = await FaceAI.getDeviceCapabilities();
    final available = await FaceAI.models.getAvailableModels();
    final active = FaceAI.models.getActiveModel(ModelType.faceRecognition);
    if (mounted) {
      setState(() {
        _capabilities = caps;
        _models = available;
        _activeRecognitionModel = active;
      });
    }
  }

  Future<void> _switchActiveModel(ModelConfig model) async {
    await FaceAI.models.activate(model.type, modelId: model.id);
    if (!mounted) return;
    setState(() {
      _activeRecognitionModel = FaceAI.models.getActiveModel(model.type);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Switched active model to "${model.displayName}". Persisted across restarts.'),
        backgroundColor: Colors.teal.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _runBenchmark(ModelConfig model) async {
    setState(() {
      _isBenchmarking = true;
      _benchmarkingModelId = model.id;
    });
    final result = await FaceAI.models.benchmark(modelId: model.id);
    if (mounted) {
      setState(() {
        _lastBenchmark = result;
        _isBenchmarking = false;
        _benchmarkingModelId = null;
      });
    }
  }

  void _showModelSelectionSheet() {
    final recognitionModels =
        _models.where((m) => m.type == ModelType.faceRecognition).toList();

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  const Text(
                    'Select Active AI Model',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose the face recognition neural network. The selected model is saved and used for all enrollment, authentication, and comparison tasks.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ...recognitionModels.map((model) {
                return RadioListTile<String>(
                  title: Text(model.displayName,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    '${model.embeddingDimensions}-d embeddings · Threshold ${model.calibratedThreshold}',
                  ),
                  value: model.id,
                  groupValue: _activeRecognitionModel?.id,
                  activeColor: Colors.teal,
                  onChanged: (val) async {
                    Navigator.of(ctx).pop();
                    await _switchActiveModel(model);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final caps = _capabilities;
    final bench = _lastBenchmark;
    final activeModel = _activeRecognitionModel ??
        FaceAI.models.getActiveModel(ModelType.faceRecognition);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Models & Diagnostics'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Switch Active Model',
            onPressed: _showModelSelectionSheet,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          // Currently Active Model Highlight Banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[Color(0xFF004D40), Color(0xFF00796B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: const Color(0xFF004D40).withOpacity(0.4),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    const Row(
                      children: <Widget>[
                        Icon(Icons.verified,
                            color: Color(0xFF00E676), size: 22),
                        SizedBox(width: 8),
                        Text(
                          'ACTIVE RECOGNITION MODEL',
                          style: TextStyle(
                            color: Color(0xFF00E676),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: _showModelSelectionSheet,
                      child:
                          const Text('Switch', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  activeModel?.displayName ?? 'MobileFaceNet Bundled',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Dimensions: ${activeModel?.embeddingDimensions ?? 192}-d vector  ·  Threshold: ${activeModel?.calibratedThreshold ?? 0.68}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: <Widget>[
                    _buildBadge('Input: 112x112 RGB'),
                    _buildBadge('Format: Float32 Normalized'),
                    _buildBadge('Persisted: SharedPreferences'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Hardware AI Delegates Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(Icons.memory,
                        color: theme.colorScheme.primary, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Hardware Acceleration Engine',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Runtime: ${caps?.runtimeVersion ?? "TFLite Edge 2.14"}  ·  Platform: ${caps?.platformName.toUpperCase() ?? "ANDROID"}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: (caps?.supportedDelegates ??
                          <String>['CPU', 'NNAPI', 'GPU'])
                      .map((del) => Chip(
                            label:
                                Text(del, style: const TextStyle(fontSize: 11)),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Registered Models List Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Available AI Model Catalog',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                '${_models.length} Models',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),

          ..._models.map((model) {
            final bool isActive = activeModel?.id == model.id;
            final bool isTestingThis =
                _isBenchmarking && _benchmarkingModelId == model.id;

            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isActive
                      ? const Color(0xFF00E676)
                      : Colors.grey.withOpacity(0.2),
                  width: isActive ? 2 : 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Card Header with Name & Active Indicator
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                model.displayName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Role: ${model.type.name} · v${model.version}',
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        if (isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00E676).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: const Color(0xFF00E676)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(Icons.check,
                                    size: 14, color: Color(0xFF00C853)),
                                SizedBox(width: 4),
                                Text(
                                  'ACTIVE',
                                  style: TextStyle(
                                    color: Color(0xFF00C853),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Model Metadata Grid
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: <Widget>[
                        Text('Dimensions: ${model.embeddingDimensions}-d',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12)),
                        Text(
                            'Calibrated Threshold: ${model.calibratedThreshold}',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12)),
                        Text(
                            'Input: ${model.inputSize.width.toInt()}x${model.inputSize.height.toInt()}',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Responsive Action Buttons
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        if (!isActive &&
                            model.type == ModelType.faceRecognition)
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.teal,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                            ),
                            onPressed: () => _switchActiveModel(model),
                            icon: const Icon(Icons.check_circle_outline,
                                size: 16),
                            label: const Text('Set as Active',
                                style: TextStyle(fontSize: 12)),
                          ),
                        FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                          onPressed: _isBenchmarking
                              ? null
                              : () => _runBenchmark(model),
                          icon: isTestingThis
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.speed, size: 16),
                          label: Text(
                            isTestingThis ? 'Benchmarking…' : 'Benchmark Speed',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),

          // Benchmark Report Box
          if (bench != null) ...<Widget>[
            const SizedBox(height: 16),
            Card(
              color: Colors.teal.shade50,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.teal.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Row(
                      children: <Widget>[
                        Icon(Icons.assessment, color: Colors.teal, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Benchmark Diagnostics Report',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                              fontSize: 15),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text('Evaluated Model: ${bench.modelId}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                        'Average Inference Latency: ${bench.averageInferenceTimeMs} ms / frame'),
                    Text(
                        'Hardware Execution Backend: ${bench.executionBackend}'),
                    Text(
                        'Measurement Iterations: ${bench.iterations} consecutive runs'),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
            color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
      ),
    );
  }
}
