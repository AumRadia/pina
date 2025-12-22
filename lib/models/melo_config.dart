// lib/models/melo_config.dart
class MeloConfig {
  String language;
  String accent;
  double speed;
  double noiseScale; // Kept as requested

  MeloConfig({
    this.language = 'EN',
    this.accent = 'Default',
    this.speed = 1.0,
    this.noiseScale = 0.667,
  });

  Map<String, dynamic> toJson() => {
    'language': language,
    'accent': accent,
    'speed': speed,
    'noiseScale': noiseScale,
  };

  MeloConfig copyWith({
    String? language,
    String? accent,
    double? speed,
    double? noiseScale,
  }) {
    return MeloConfig(
      language: language ?? this.language,
      accent: accent ?? this.accent,
      speed: speed ?? this.speed,
      noiseScale: noiseScale ?? this.noiseScale,
    );
  }
}
