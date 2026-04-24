class SherpaTtsConfig {
  const SherpaTtsConfig({
    this.engine = 'vits',
    this.modelPath = '',
    this.tokensPath = '',
    this.dataDir = '',
    this.speed = 1.0,
    this.speakerId = 0,
  });

  final String engine;
  final String modelPath;
  final String tokensPath;
  final String dataDir;
  final double speed;
  final int speakerId;

  bool get isComplete =>
      modelPath.isNotEmpty && tokensPath.isNotEmpty && dataDir.isNotEmpty;

  SherpaTtsConfig copyWith({
    String? engine,
    String? modelPath,
    String? tokensPath,
    String? dataDir,
    double? speed,
    int? speakerId,
  }) {
    return SherpaTtsConfig(
      engine: engine ?? this.engine,
      modelPath: modelPath ?? this.modelPath,
      tokensPath: tokensPath ?? this.tokensPath,
      dataDir: dataDir ?? this.dataDir,
      speed: speed ?? this.speed,
      speakerId: speakerId ?? this.speakerId,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'engine': engine,
      'modelPath': modelPath,
      'tokensPath': tokensPath,
      'dataDir': dataDir,
      'speed': speed,
      'speakerId': speakerId,
    };
  }

  factory SherpaTtsConfig.fromJson(Map<String, Object?> json) {
    return SherpaTtsConfig(
      engine: json['engine'] as String? ?? 'vits',
      modelPath: json['modelPath'] as String? ?? '',
      tokensPath: json['tokensPath'] as String? ?? '',
      dataDir: json['dataDir'] as String? ?? '',
      speed: (json['speed'] as num?)?.toDouble() ?? 1.0,
      speakerId: (json['speakerId'] as num?)?.toInt() ?? 0,
    );
  }
}
