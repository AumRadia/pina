// lib/widgets/kokoro_config_dialog.dart

import 'package:flutter/material.dart';
import 'package:pina/models/kokoro_config.dart';

class KokoroConfigDialog extends StatefulWidget {
  final KokoroConfig initialConfig;

  const KokoroConfigDialog({required this.initialConfig, super.key});

  @override
  State<KokoroConfigDialog> createState() => _KokoroConfigDialogState();
}

class _KokoroConfigDialogState extends State<KokoroConfigDialog> {
  late KokoroConfig config;

  // Grouped voices for display
  final Map<String, List<Map<String, String>>> voiceGroups = {
    'American – Female': [
      {'id': 'af_bella', 'name': 'Bella'},
      {'id': 'af_heart', 'name': 'Heart'},
      {'id': 'af_nicole', 'name': 'Nicole'},
    ],
    'American – Male': [
      {'id': 'am_adam', 'name': 'Adam'},
      {'id': 'am_michael', 'name': 'Michael'},
    ],
    'British – Female': [
      {'id': 'bf_emma', 'name': 'Emma'},
      {'id': 'bf_isabella', 'name': 'Isabella'},
    ],
    'British – Male': [
      {'id': 'bm_george', 'name': 'George'},
      {'id': 'bm_lewis', 'name': 'Lewis'},
    ],
  };

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
        constraints: const BoxConstraints(maxWidth: 400),
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
                  const Icon(Icons.record_voice_over, color: Colors.white),
                  const SizedBox(width: 12),
                  const Text(
                    'TTS Settings',
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

            // Body
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Voice Selection
                  const Text(
                    "Select Voice",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: config.voice,
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: _buildDropdownItems(),
                      onChanged: (val) {
                        if (val != null) setState(() => config.voice = val);
                      },
                    ),
                  ),

                  const SizedBox(height: 25),

                  // Speed Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Speed",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        "${config.speed.toStringAsFixed(1)}x",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Slider(
                    value: config.speed,
                    min: 0.8,
                    max: 1.3,
                    divisions: 5, // 0.8, 0.9, 1.0, 1.1, 1.2, 1.3
                    activeColor: Colors.black,
                    label: config.speed.toStringAsFixed(1),
                    onChanged: (val) {
                      setState(() => config.speed = val);
                    },
                  ),
                ],
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      "Cancel",
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(context, config),
                    child: const Text("Apply"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper to build grouped dropdown items
  List<DropdownMenuItem<String>> _buildDropdownItems() {
    List<DropdownMenuItem<String>> items = [];

    voiceGroups.forEach((groupName, voices) {
      // Add Group Header (disabled)
      items.add(
        DropdownMenuItem<String>(
          enabled: false,
          value: "header_$groupName",
          child: Text(
            groupName,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ),
      );

      // Add Voices
      for (var voice in voices) {
        items.add(
          DropdownMenuItem<String>(
            value: voice['id'],
            child: Padding(
              padding: const EdgeInsets.only(left: 10.0),
              child: Text(voice['name']!),
            ),
          ),
        );
      }
    });

    return items;
  }
}
