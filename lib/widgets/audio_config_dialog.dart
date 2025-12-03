// lib/widgets/audio_config_dialog.dart

import 'package:flutter/material.dart';
import 'package:pina/models/assembly_config.dart';

class AudioConfigDialog extends StatefulWidget {
  final AssemblyConfig initialConfig;

  const AudioConfigDialog({required this.initialConfig, super.key});

  @override
  State<AudioConfigDialog> createState() => _AudioConfigDialogState();
}

class _AudioConfigDialogState extends State<AudioConfigDialog> {
  late AssemblyConfig config;

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
                  const Icon(Icons.settings, color: Colors.white),
                  const SizedBox(width: 12),
                  const Text(
                    'Audio Settings',
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
                    // Language Selection
                    _buildSectionTitle('Language'),
                    _buildLanguageDropdown(),
                    const SizedBox(height: 20),

                    // Basic Settings
                    _buildSectionTitle('Basic Settings'),
                    _buildSwitch(
                      'Punctuate',
                      'Add punctuation to transcript',
                      config.punctuate,
                      (v) => setState(() => config.punctuate = v),
                      tooltip:
                          "Adds commas, periods, and question marks to the text.",
                    ),
                    _buildSwitch(
                      'Format Text',
                      'Apply text formatting',
                      config.formatText,
                      (v) => setState(() => config.formatText = v),
                      tooltip:
                          "Capitalizes sentences and formats proper nouns.",
                    ),
                    const SizedBox(height: 20),

                    // Advanced Features
                    _buildSectionTitle('Advanced Features'),
                    _buildSwitch(
                      'Speaker Labels',
                      'Identify different speakers',
                      config.speakerLabels,
                      (v) => setState(() => config.speakerLabels = v),
                      tooltip:
                          "Detects who is speaking and labels them (Speaker A, Speaker B).",
                    ),
                    _buildSwitch(
                      'Senti. Analysis',
                      'Analyze sentiment of speech (English only)',
                      config.sentimentAnalysis,
                      (v) => setState(() => config.sentimentAnalysis = v),
                      enabled: _isEnglish(),
                      tooltip:
                          "Detects if the speech is Positive, Negative, or Neutral.",
                    ),
                    _buildSwitch(
                      'Summarization',
                      'Generate summary of transcript (English only)',
                      config.summarization,
                      (v) => setState(() {
                        config.summarization = v;
                        if (v) config.autoChapters = false;
                      }),
                      enabled: _isEnglish(),
                      tooltip:
                          "Generates a concise summary of the entire audio file.",
                    ),
                    _buildSwitch(
                      'Auto Chapters',
                      'Automatically detect chapters (English only)',
                      config.autoChapters,
                      (v) => setState(() {
                        config.autoChapters = v;
                        if (v) config.summarization = false;
                      }),
                      enabled: _isEnglish(),
                      tooltip:
                          "Breaks long audio into titled sections with their own summaries.",
                    ),
                    _buildSwitch(
                      'Auto Highlights',
                      'Extract key highlights (English only)',
                      config.autoHighlights,
                      (v) => setState(() => config.autoHighlights = v),
                      enabled: _isEnglish(),
                      tooltip:
                          "Automatically picks out the most important phrases and keywords.",
                    ),
                    const SizedBox(height: 20),

                    // Content Moderation
                    _buildSectionTitle('Content Moderation'),
                    _buildSwitch(
                      'Filter Profanity',
                      'Replace profane words',
                      config.filterProfanity,
                      (v) => setState(() => config.filterProfanity = v),
                      tooltip:
                          "Replaces bad words with asterisks (e.g., s***).",
                    ),
                    _buildSwitch(
                      'Content Safety',
                      'Flag sensitive content',
                      config.contentSafety,
                      (v) => setState(() => config.contentSafety = v),
                      tooltip:
                          "Flags topics like hate speech, violence, or drugs.",
                    ),
                  ],
                ),
              ),
            ),

            // Footer Buttons
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
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

  bool _isEnglish() {
    return config.languageCode.toLowerCase().startsWith('en');
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildLanguageDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<String>(
        value: config.languageCode,
        isExpanded: true,
        underline: const SizedBox(),
        items: SupportedLanguages.languages.entries.map((entry) {
          return DropdownMenuItem(value: entry.key, child: Text(entry.value));
        }).toList(),
        onChanged: (value) {
          if (value != null) {
            setState(() => config.languageCode = value);
          }
        },
      ),
    );
  }

  Widget _buildPiiSubstitutionDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Substitution Method',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<String>(
            value: config.redactPiiSub,
            isExpanded: true,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 'hash', child: Text('Hash (####)')),
              DropdownMenuItem(
                value: 'entity_name',
                child: Text('Entity Name ([PERSON_NAME])'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => config.redactPiiSub = value);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPiiPoliciesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'PII Categories to Redact',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            TextButton(
              onPressed: () {
                setState(() {
                  if (config.redactPiiPolicies.isEmpty) {
                    config.redactPiiPolicies = List.from(
                      PIIRedactionPolicies.allPolicies,
                    );
                  } else {
                    config.redactPiiPolicies = [];
                  }
                });
              },
              child: Text(
                config.redactPiiPolicies.isEmpty ? 'Select All' : 'Clear All',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              // Common policies first
              ...[
                'person_name',
                'phone_number',
                'email_address',
                'credit_card_number',
              ].map((policy) => _buildPolicyCheckbox(policy)),
              ExpansionTile(
                title: const Text(
                  'More Categories',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
                children: PIIRedactionPolicies.allPolicies
                    .where(
                      (p) => ![
                        'person_name',
                        'phone_number',
                        'email_address',
                        'credit_card_number',
                      ].contains(p),
                    )
                    .map((policy) => _buildPolicyCheckbox(policy))
                    .toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPolicyCheckbox(String policy) {
    final isSelected = config.redactPiiPolicies.contains(policy);
    return CheckboxListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(
        PIIRedactionPolicies.getPolicyName(policy),
        style: const TextStyle(fontSize: 12),
      ),
      value: isSelected,
      onChanged: (value) {
        setState(() {
          if (value == true) {
            config.redactPiiPolicies = [...config.redactPiiPolicies, policy];
          } else {
            config.redactPiiPolicies = config.redactPiiPolicies
                .where((p) => p != policy)
                .toList();
          }
        });
      },
      activeColor: Colors.black,
    );
  }

  Widget _buildSwitch(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged, {
    bool enabled = true,
    String? tooltip, // <--- New parameter for the info text
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Opacity(
        opacity: enabled ? 1.0 : 0.5,
        child: SwitchListTile(
          // Change title to a Row to include the icon
          title: Row(
            children: [
              Text(title),
              if (tooltip != null) ...[
                const SizedBox(width: 8),
                Tooltip(
                  message: tooltip,
                  triggerMode: TooltipTriggerMode.tap, // Shows on tap
                  preferBelow: false, // Shows above the finger
                  showDuration: const Duration(seconds: 3),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  textStyle: const TextStyle(color: Colors.white, fontSize: 12),
                  child: const Icon(
                    Icons.info_outline,
                    size: 18,
                    color: Colors.grey,
                  ),
                ),
              ],
            ],
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          value: value,
          onChanged: enabled ? onChanged : null,
          activeColor: Colors.black,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}
