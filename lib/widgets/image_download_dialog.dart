import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:pina/screens/constants.dart';

// Enum to tell the parent screen what action to take
enum ImageAction { save, gmail, drive }

// Class to pass back data (Action + Which images were selected)
class ImageDialogResult {
  final ImageAction action;
  final List<Uint8List> selectedImages;

  ImageDialogResult(this.action, this.selectedImages);
}

class ImageDownloadDialog extends StatefulWidget {
  final List<Uint8List> images;
  final int promptId;

  const ImageDownloadDialog({
    required this.images,
    required this.promptId,
    super.key,
  });

  @override
  State<ImageDownloadDialog> createState() => _ImageDownloadDialogState();
}

class _ImageDownloadDialogState extends State<ImageDownloadDialog> {
  // Track which images are selected. Default to true (all selected).
  late List<bool> _selections;

  @override
  void initState() {
    super.initState();
    _selections = List.generate(widget.images.length, (index) => true);
  }

  // Same "Regular Tool" logic as your other dialog
  Future<void> _markAsRegularTool(BuildContext context) async {
    final String baseUrl = ApiConstants.authUrl;
    final Uri url = Uri.parse('$baseUrl/api/mark-regular-tool');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'promptId': widget.promptId}),
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

  // Helper to get actual image data of selected items
  List<Uint8List> _getSelectedImages() {
    List<Uint8List> selected = [];
    for (int i = 0; i < widget.images.length; i++) {
      if (_selections[i]) {
        selected.add(widget.images[i]);
      }
    }
    return selected;
  }

  void _handleAction(ImageAction action) {
    final selectedImgs = _getSelectedImages();
    if (selectedImgs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one image.")),
      );
      return;
    }
    // Return result to parent
    Navigator.pop(context, ImageDialogResult(action, selectedImgs));
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
              // Header
              Stack(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(right: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Image Options',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Select images to save or share',
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
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // --- IMAGE SELECTION GRID ---
              Container(
                constraints: const BoxConstraints(maxHeight: 250),
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: widget.images.length,
                  itemBuilder: (context, index) {
                    final isSelected = _selections[index];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selections[index] = !isSelected;
                        });
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // The Image
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              widget.images[index],
                              fit: BoxFit.cover,
                              color: isSelected
                                  ? null
                                  : Colors.white.withOpacity(0.6),
                              colorBlendMode: isSelected
                                  ? null
                                  : BlendMode.lighten,
                            ),
                          ),
                          // Selection Border & Icon
                          if (isSelected)
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.blue,
                                  width: 3,
                                ),
                              ),
                              child: const Align(
                                alignment: Alignment.topRight,
                                child: Padding(
                                  padding: EdgeInsets.all(4),
                                  child: CircleAvatar(
                                    radius: 10,
                                    backgroundColor: Colors.blue,
                                    child: Icon(
                                      Icons.check,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // --- ACTIONS ---

              // Save to Gallery
              _buildOptionButton(
                icon: Icons.save_alt,
                label: 'Save to Gallery',
                subtitle: 'Save selected images',
                color: Colors.blue,
                onTap: () => _handleAction(ImageAction.save),
              ),
              const SizedBox(height: 12),

              // Gmail
              _buildOptionButton(
                icon: Icons.email,
                label: 'Share to Gmail',
                subtitle: 'Send via email',
                color: Colors.orange,
                onTap: () => _handleAction(ImageAction.gmail),
              ),
              const SizedBox(height: 12),

              // Drive
              _buildOptionButton(
                icon: Icons.cloud_upload,
                label: 'Share to Drive',
                subtitle: 'Upload to Google Drive',
                color: Colors.green,
                onTap: () => _handleAction(ImageAction.drive),
              ),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),

              // Regular Tool Feedback
              TextButton(
                onPressed: () => _markAsRegularTool(context),
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

  Widget _buildOptionButton({
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
