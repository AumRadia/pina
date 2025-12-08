class ImageGenerationConfig {
  double cfgScale;
  int samples;
  int steps;
  String safetyMode; // "SAFE" or "NONE"
  String outputFormat; // "png" or "jpg"
  String? stylePreset;
  int height; // NEW
  int width; // Nullable, as it can be "None"

  ImageGenerationConfig({
    this.cfgScale = 7.0,
    this.samples = 1,
    this.steps = 30,
    this.safetyMode = 'SAFE',
    this.outputFormat = 'png',
    this.stylePreset,
    this.height = 768,
    this.width = 768,
  });

  // Convert to JSON for API request
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {
      "cfg_scale": cfgScale,
      "samples": samples,
      "steps": steps,
      // Note: Standard Stability API uses "style_preset"
      if (stylePreset != null && stylePreset != 'none')
        "style_preset": stylePreset,
    };

    // Note: 'safety_mode' and 'output_format' might need
    // to be handled via Headers or specific API versions.
    // We include them here in case your specific API proxy expects them in body.
    // Standard Stability V1 returns base64, so output format is usually implied.

    return json;
  }

  ImageGenerationConfig copyWith({
    double? cfgScale,
    int? samples,
    int? steps,
    String? safetyMode,
    String? outputFormat,
    String? stylePreset,
    int? height,
    int? width,
  }) {
    return ImageGenerationConfig(
      cfgScale: cfgScale ?? this.cfgScale,
      samples: samples ?? this.samples,
      steps: steps ?? this.steps,
      safetyMode: safetyMode ?? this.safetyMode,
      outputFormat: outputFormat ?? this.outputFormat,
      stylePreset: stylePreset ?? this.stylePreset,
      height: height ?? this.height,
      width: width ?? this.width,
    );
  }
}

class ImageStylePresets {
  static const List<String> presets = [
    '3d-model',
    'analog-film',
    'anime',
    'cinematic',
    'comic-book',
    'digital-art',
    'enhance',
    'fantasy-art',
    'isometric',
    'line-art',
    'low-poly',
    'modeling-compound',
    'neon-punk',
    'origami',
    'photographic',
    'pixel-art',
    'tile-texture',
  ];
}
