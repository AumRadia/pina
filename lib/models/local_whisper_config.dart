class LocalWhisperConfig {
  String modelSize; // tiny, base, small, medium, large
  String language; // en, auto, es, fr, etc.
  bool translateToEnglish; // if true, sets task="translate"
  bool useGpu; // fp16

  LocalWhisperConfig({
    this.modelSize = 'small',
    this.language = 'en',
    this.translateToEnglish = false,
    this.useGpu = false,
  });

  // Convert to JSON for MongoDB storage
  Map<String, dynamic> toJson() => {
    'model': modelSize,
    'language': language,
    'task': translateToEnglish ? 'translate' : 'transcribe',
    'fp16': useGpu,
  };

  LocalWhisperConfig copyWith({
    String? modelSize,
    String? language,
    bool? translateToEnglish,
    bool? useGpu,
  }) {
    return LocalWhisperConfig(
      modelSize: modelSize ?? this.modelSize,
      language: language ?? this.language,
      translateToEnglish: translateToEnglish ?? this.translateToEnglish,
      useGpu: useGpu ?? this.useGpu,
    );
  }
}
