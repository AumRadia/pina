import 'dart:typed_data';
import 'package:flutter/material.dart';

enum OutputType { text, image, audio }

class GenerationOutputView extends StatelessWidget {
  final OutputType type;
  final String? textContent;
  final List<Uint8List>? imageData; // CHANGE: Now accepts a List
  final VoidCallback? onDownload;

  const GenerationOutputView({
    super.key,
    required this.type,
    this.textContent,
    this.imageData,
    this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Output:",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (onDownload != null)
              ElevatedButton.icon(
                onPressed: onDownload,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                icon: const Icon(Icons.download, size: 18),
                label: const Text("Download"),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black12,
            borderRadius: BorderRadius.circular(12),
          ),
          // Change this to handle scrolling
          child: type == OutputType.image
              ? _buildImageGallery()
              : _buildContent(),
        ),
      ],
    );
  }

  // NEW: Helper to show one or multiple images
  Widget _buildImageGallery() {
    if (imageData == null || imageData!.isEmpty)
      return const Text("Error displaying image");
      

    // If just 1 image, show normally
    if (imageData!.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(imageData!.first, fit: BoxFit.contain),
      );
    }

    // If multiple images, show a scrollable list
    return SizedBox(
      height: 300, // Fixed height for carousel
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: imageData!.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(imageData![index], fit: BoxFit.contain),
          );
        },
      ),
    );
  }

  Widget _buildContent() {
    return Text(textContent ?? "", style: const TextStyle(fontSize: 16));
  }
}
