import 'package:flutter/material.dart';
import 'package:pina/models/local_whisper_config.dart';

class LocalWhisperConfigDialog extends StatefulWidget {
  final LocalWhisperConfig initialConfig;

  const LocalWhisperConfigDialog({required this.initialConfig, super.key});

  @override
  State<LocalWhisperConfigDialog> createState() =>
      _LocalWhisperConfigDialogState();
}

class _LocalWhisperConfigDialogState extends State<LocalWhisperConfigDialog> {
  late LocalWhisperConfig config;

  final Map<String, String> modelOptions = {
    'tiny': 'Tiny (Fastest, Low Accuracy)',
    'base': 'Base (Fast, Good Accuracy)',
    'small': 'Small (Balanced)',
    'medium': 'Medium (Slow, High Accuracy)',
    'large': 'Large (Slowest, Best Accuracy)',
  };

  final Map<String, String> languages = {
    'en': 'English',
    'es': 'Spanish',
    'fr': 'French',
    'de': 'German',
    'it': 'Italian',
    'ja': 'Japanese',
    'zh': 'Chinese',
    'hi': 'Hindi',
    'auto': 'Auto Detect',
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
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
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
                  const Icon(Icons.tune, color: Colors.white),
                  const SizedBox(width: 12),
                  const Text(
                    'Whisper Settings',
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
                    _buildSectionTitle('Model Size'),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        value: config.modelSize,
                        isExpanded: true,
                        underline: const SizedBox(),
                        items: modelOptions.entries.map((e) {
                          return DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          );
                        }).toList(),
                        onChanged: (v) =>
                            setState(() => config.modelSize = v ?? 'small'),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildSectionTitle('Language'),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        value: languages.containsKey(config.language)
                            ? config.language
                            : 'en',
                        isExpanded: true,
                        underline: const SizedBox(),
                        items: languages.entries.map((e) {
                          return DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          );
                        }).toList(),
                        onChanged: (v) =>
                            setState(() => config.language = v ?? 'en'),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildSectionTitle('Features'),
                    SwitchListTile(
                      title: const Text('Translate to English'),
                      subtitle: const Text(
                        'If audio is non-English, output English text',
                      ),
                      value: config.translateToEnglish,
                      onChanged: (v) =>
                          setState(() => config.translateToEnglish = v),
                      activeColor: Colors.black,
                    ),
                    SwitchListTile(
                      title: const Text('Use GPU (FP16)'),
                      subtitle: const Text(
                        'Enable only if your server has a GPU',
                      ),
                      value: config.useGpu,
                      onChanged: (v) => setState(() => config.useGpu = v),
                      activeColor: Colors.black,
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
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(context, config),
                    child: const Text('Apply Settings'),
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}
