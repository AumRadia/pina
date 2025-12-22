// lib/widgets/melo_config_dialog.dart
import 'package:flutter/material.dart';
import 'package:pina/models/melo_config.dart';

class MeloConfigDialog extends StatefulWidget {
  final MeloConfig initialConfig;
  const MeloConfigDialog({required this.initialConfig, super.key});

  @override
  State<MeloConfigDialog> createState() => _MeloConfigDialogState();
}

class _MeloConfigDialogState extends State<MeloConfigDialog> {
  late MeloConfig config;

  @override
  void initState() {
    super.initState();
    config = widget.initialConfig.copyWith();
    // Force defaults that aren't user-selectable anymore
    config.language = 'EN';
    if (config.accent.isEmpty || config.accent == 'Default') {
      config.accent = 'US'; // Default to US if not set
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("MeloTTS Settings"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Audio Parameters",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 20),
            _buildSlider(
              "Speed",
              config.speed,
              0.5,
              1.5, // Changed max to 1.5
              (v) => setState(() => config.speed = v),
            ),
            const SizedBox(height: 10),
            _buildSlider(
              "Noise Scale",
              config.noiseScale,
              0.5, // Changed min to 0.5
              1.5, // Changed max to 1.5
              (v) => setState(() => config.noiseScale = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, config),
          child: const Text("Apply"),
        ),
      ],
    );
  }

  Widget _buildSlider(
    String label,
    double val,
    double min,
    double max,
    Function(double) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            Text(
              val.toStringAsFixed(2),
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
        Slider(
          value: val.clamp(min, max), // Ensure value stays within new bounds
          min: min,
          max: max,
          activeColor: Colors.black,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
