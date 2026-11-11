/// Hardware and platform AI capabilities report.
class DeviceCapabilities {
  const DeviceCapabilities({
    required this.supportsBiometrics,
    required this.supportedDelegates,
    required this.availableCameras,
    required this.runtimeVersion,
    required this.platformName,
  });

  /// Whether device biometrics hardware is detected and enrolled.
  final bool supportsBiometrics;

  /// Hardware acceleration backends available (CPU, GPU, NNAPI, CoreML).
  final List<String> supportedDelegates;

  /// List of camera positions available.
  final List<String> availableCameras;

  /// On-device AI runtime version string.
  final String runtimeVersion;

  /// Current OS platform.
  final String platformName;

  @override
  String toString() =>
      'DeviceCapabilities(biometrics: $supportsBiometrics, delegates: $supportedDelegates, runtime: $runtimeVersion)';
}
