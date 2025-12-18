import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:read_pdf_text/read_pdf_text.dart';
import 'package:docx_to_text/docx_to_text.dart';
import 'package:pina/models/attached_file.dart';

class FileProcessingHelper {
  /// Picks files and handles strict size/count validations
  /// Returns a Map containing 'files' (List<AttachedFile>) or 'error' (String)
  static Future<Map<String, dynamic>> pickAndProcessFiles({
    required int currentFileCount,
    required int currentTotalSize,
  }) async {
    // 1. Check Max Files Limit
    if (currentFileCount >= 5) {
      return {'error': "Maximum 5 files allowed."};
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowMultiple: true,
        allowedExtensions: [
          'txt', 'md', 'json', 'pdf', 'docx', // Docs
          'jpg', 'jpeg', 'png', 'webp', // Images
          // UPDATED MEDIA LIST (Added wav, m4a, mkv, webm):
          'mp4', 'mov', 'avi', 'mp3', 'wav', 'm4a', 'mkv', 'webm',
        ],
      );

      if (result == null) return {'files': <AttachedFile>[]};

      List<AttachedFile> newFiles = [];
      int tempTotalSize = currentTotalSize;
      String? warningMessage;

      for (var platformFile in result.files) {
        // 2. CHECK: Max Files Limit
        if (currentFileCount + newFiles.length >= 5) {
          warningMessage = "Stopped adding files: Max 5 files reached.";
          break;
        }

        // 3. CHECK: Individual File Size > 100MB
        if (platformFile.size > 100 * 1024 * 1024) {
          continue;
        }

        // 4. CHECK: Total Size Limit > 100MB
        if (tempTotalSize + platformFile.size > 100 * 1024 * 1024) {
          warningMessage = "Total size cannot exceed 100 MB";
          break;
        }

        // Process Valid File
        final file = File(platformFile.path!);
        final extension = platformFile.extension?.toLowerCase() ?? "";
        String? content;

        try {
          if (extension == 'pdf') {
            content = await ReadPdfText.getPDFtext(file.path);
          } else if (extension == 'docx') {
            final bytes = await file.readAsBytes();
            content = docxToText(bytes);
          } else if (['txt', 'md', 'json'].contains(extension)) {
            content = await file.readAsString();
          } else {
            content = null; // Media files
          }
        } catch (e) {
          print("Error reading ${platformFile.name}: $e");
        }

        newFiles.add(
          AttachedFile(
            file: file,
            name: platformFile.name,
            extension: extension,
            sizeBytes: platformFile.size,
            extractedText: content,
          ),
        );

        tempTotalSize += platformFile.size;
      }

      return {'files': newFiles, 'warning': warningMessage};
    } catch (e) {
      return {'error': "Error picking files: $e"};
    }
  }
}
