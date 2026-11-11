/// Diagnostics performance report for an AI model.
class BenchmarkResult {
  const BenchmarkResult({
    required this.modelId,
    required this.averageInferenceTimeMs,
    required this.executionBackend,
    this.peakMemoryBytes,
    this.iterations = 10,
  });

  final String modelId;
  final double averageInferenceTimeMs;
  final String executionBackend;
  final int? peakMemoryBytes;
  final int iterations;

  @override
  String toString() =>
      'BenchmarkResult(model: $modelId, latency: ${averageInferenceTimeMs.toStringAsFixed(1)}ms, backend: $executionBackend)';
}
