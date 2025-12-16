import 'package:flutter/material.dart';
import 'package:pina/services/lm_studio_service.dart';

class ProviderSelectorWidget extends StatelessWidget {
  final LlmProvider selectedProvider;
  final Function(LlmProvider) onProviderChanged;

  const ProviderSelectorWidget({
    required this.selectedProvider,
    required this.onProviderChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Select Provider:",
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<LlmProvider>(
              value: selectedProvider,
              isExpanded: true,
              items: LlmProvider.values.map((LlmProvider provider) {
                return DropdownMenuItem<LlmProvider>(
                  value: provider,
                  child: Text(provider.displayName),
                );
              }).toList(),
              onChanged: (LlmProvider? newValue) {
                if (newValue != null) {
                  onProviderChanged(newValue);
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}
