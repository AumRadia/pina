import 'package:flutter/material.dart';
import 'package:pina/models/image_generation_config.dart';

class ImageConfigDialog extends StatefulWidget {
  final ImageGenerationConfig initialConfig;

  const ImageConfigDialog({required this.initialConfig, super.key});

  @override
  State<ImageConfigDialog> createState() => _ImageConfigDialogState();
}

class _ImageConfigDialogState extends State<ImageConfigDialog> {
  late ImageGenerationConfig config;

  @override
  void initState() {
    super.initState();
    config = widget.initialConfig.copyWith();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.image, color: Colors.white),
                  const SizedBox(width: 12),
                  const Text(
                    'Image Settings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- NEW: RESOLUTION SELECTOR ---
                    _buildSectionTitle('Image Size'),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<int>(
                        value: config
                            .height, // We assume height == width for these presets
                        isExpanded: true,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(
                            value: 512,
                            child: Text("512 x 512 (Fast, Cheap)"),
                          ),
                          DropdownMenuItem(
                            value: 768,
                            child: Text("768 x 768 (Default)"),
                          ),
                          DropdownMenuItem(
                            value: 1024,
                            child: Text("1024 x 1024 (Best Quality)"),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              config.height = val;
                              config.width = val;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    // --------------------------------

                    // Style Preset
                    _buildSectionTitle('Style Preset'),

                    // CFG Scale
                    _buildSectionTitle(
                      'CFG Scale: ${config.cfgScale.toStringAsFixed(1)}',
                    ),
                    const Text(
                      "How strictly the AI follows the prompt (1-10)",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    Slider(
                      value: config.cfgScale,
                      min: 1.0,
                      max: 10.0,
                      divisions: 90, // allows decimals like 7.5
                      activeColor: Colors.black,
                      onChanged: (v) => setState(() => config.cfgScale = v),
                    ),

                    // Steps
                    _buildSectionTitle('Steps: ${config.steps}'),
                    const Text(
                      "More steps = higher quality but slower (0-30)",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    Slider(
                      value: config.steps.toDouble() < 10
                          ? 10
                          : config.steps.toDouble(),
                      min: 10,
                      max: 30,
                      divisions: 4, // 0, 5, 10, 15, 20, 25, 30
                      activeColor: Colors.black,
                      onChanged: (v) =>
                          setState(() => config.steps = v.toInt()),
                    ),

                    // Samples
                    _buildSectionTitle('Samples: ${config.samples}'),
                    const Text(
                      "Number of images to generate (1-10)",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    Slider(
                      value: config.samples.toDouble(),
                      min: 1,
                      max: 10,
                      divisions: 9,
                      activeColor: Colors.black,
                      onChanged: (v) =>
                          setState(() => config.samples = v.toInt()),
                    ),

                    const SizedBox(height: 10),
                    const Divider(),
                    const SizedBox(height: 10),

                    // Output Format
                    _buildSectionTitle('Output Format'),
                    Row(
                      children: [
                        _buildRadio("png", "PNG"),
                        const SizedBox(width: 20),
                        _buildRadio("jpg", "JPG"),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Safety Mode
                    _buildSectionTitle('Safety Mode'),
                    Row(
                      children: [
                        _buildSafetyRadio("SAFE", "Safe"),
                        const SizedBox(width: 20),
                        _buildSafetyRadio("NONE", "None"),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(context, config),
                    child: const Text('Apply'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }


  Widget _buildRadio(String val, String label) {
    return Row(
      children: [
        Radio<String>(
          value: val,
          groupValue: config.outputFormat,
          onChanged: (v) => setState(() => config.outputFormat = v!),
          activeColor: Colors.black,
        ),
        Text(label),
      ],
    );
  }

  Widget _buildSafetyRadio(String val, String label) {
    return Row(
      children: [
        Radio<String>(
          value: val,
          groupValue: config.safetyMode,
          onChanged: (v) => setState(() => config.safetyMode = v!),
          activeColor: Colors.black,
        ),
        Text(label),
      ],
    );
  }
}
