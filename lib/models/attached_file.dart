import 'dart:io';

class AttachedFile {
  final File file;
  final String name;
  final String extension;
  final int sizeBytes;
  String? extractedText;

  AttachedFile({
    required this.file,
    required this.name,
    required this.extension,
    required this.sizeBytes,
    this.extractedText,
  });

  String get path => file.path;
}
