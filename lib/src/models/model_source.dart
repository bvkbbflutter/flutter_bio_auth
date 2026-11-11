/// Origin source of a TFLite model file.
enum ModelSourceType {
  asset,
  file,
  network,
}

class ModelSource {
  const ModelSource._({
    required this.type,
    this.assetPath,
    this.filePath,
    this.url,
  });

  final ModelSourceType type;
  final String? assetPath;
  final String? filePath;
  final String? url;

  /// Loads model bundled within Flutter application assets.
  factory ModelSource.asset(String path) => ModelSource._(
        type: ModelSourceType.asset,
        assetPath: path,
      );

  /// Loads model from local on-device file storage (e.g. app support dir).
  factory ModelSource.file(String path) => ModelSource._(
        type: ModelSourceType.file,
        filePath: path,
      );

  /// Downloads model securely over network with checksum verification.
  factory ModelSource.network(String url) => ModelSource._(
        type: ModelSourceType.network,
        url: url,
      );

  @override
  String toString() {
    switch (type) {
      case ModelSourceType.asset:
        return 'Asset($assetPath)';
      case ModelSourceType.file:
        return 'File($filePath)';
      case ModelSourceType.network:
        return 'Network($url)';
    }
  }
}
