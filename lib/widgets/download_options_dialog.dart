import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:pina/screens/constants.dart';

enum DownloadOption { text, pdf, gmail, drive }

class DownloadOptionsDialog extends StatelessWidget {
  final String content;
  final String audioFileName;
  final int promptId; // Added to identify which record to update

  const DownloadOptionsDialog({
    required this.content,
    required this.audioFileName,
    required this.promptId, // Required now
    super.key,
  });

  Future<void> _markAsRegularTool(BuildContext context) async {
    // REPLACE WITH YOUR ACTUAL IP/URL
    // Android Emulator uses 10.0.2.2, Physical device uses your PC's IP (e.g., 192.168.1.X)
    // Production uses your vercel/hosted URL
    final String baseUrl = ApiConstants.authUrl;

    final Uri url = Uri.parse('$baseUrl/api/mark-regular-tool');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'promptId': promptId}),
      );

      if (context.mounted) {
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Thanks for your feedback!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          print('Failed to update: ${response.body}');
        }
      }
    } catch (e) {
      print('Error updating regular tool: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title with Close Button
              Stack(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(right: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Download Options',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Choose how you want to save or share your transcript',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      iconSize: 24,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Download as Text
              _buildOptionButton(
                context,
                icon: Icons.text_snippet,
                label: 'Download as Text',
                subtitle: 'Save as .txt file',
                color: Colors.blue,
                onTap: () {
                  Navigator.pop(context, DownloadOption.text);
                },
              ),
              const SizedBox(height: 12),

              // Download as PDF
              _buildOptionButton(
                context,
                icon: Icons.picture_as_pdf,
                label: 'Download as PDF',
                subtitle: 'Save as .pdf file',
                color: Colors.red,
                onTap: () {
                  Navigator.pop(context, DownloadOption.pdf);
                },
              ),
              const SizedBox(height: 12),

              // Share to Gmail
              _buildOptionButton(
                context,
                icon: Icons.email,
                label: 'Share to Gmail',
                subtitle: 'Send via email',
                color: Colors.orange,
                onTap: () {
                  Navigator.pop(context, DownloadOption.gmail);
                },
              ),
              const SizedBox(height: 12),

              // Share to Drive
              _buildOptionButton(
                context,
                icon: Icons.cloud_upload,
                label: 'Share to Drive',
                subtitle: 'Upload to Google Drive',
                color: Colors.green,
                onTap: () {
                  Navigator.pop(context, DownloadOption.drive);
                },
              ),
              const SizedBox(height: 24),

              // Divider
              const Divider(),
              const SizedBox(height: 12),

              // Regular Tool Button
              TextButton(
                onPressed: () {
                  _markAsRegularTool(context);
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'Is this your regular tool?',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}
