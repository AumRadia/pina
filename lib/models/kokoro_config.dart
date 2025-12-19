// lib/models/kokoro_config.dart

class KokoroConfig {
  String voice;
  double speed;

  KokoroConfig({
    this.voice = 'af_heart', // Default
    this.speed = 1.0, // Default
  });

  Map<String, dynamic> toJson() => {'voice': voice, 'speed': speed};

  // Create a copy to avoid mutating state directly in dialogs until saved
  KokoroConfig copyWith({String? voice, double? speed}) {
    return KokoroConfig(voice: voice ?? this.voice, speed: speed ?? this.speed);
  }
}
