import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:gal/gal.dart';

class FileDownloadHelper {
  static Future<bool> downloadAsText(
    BuildContext context,
    String content,
    String audioFileName,
  ) async {
    try {
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')[0];
      final baseFileName = audioFileName.split('.').first;
      final fileName = '${baseFileName}_transcript_$timestamp.txt';

      if (kIsWeb) {
        return false;
      } else {
        final bytes = utf8.encode(content);

        final outputPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Transcript',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['txt'],
          bytes: Uint8List.fromList(bytes),
        );

        if (outputPath != null) {
          try {
            final file = File(outputPath);
            await file.writeAsString(content);
          } catch (e) {
            print('File already saved by file_picker: $e');
          }
          return true;
        }
      }
      return false;
    } catch (e) {
      print('Error downloading transcript as text: $e');
      return false;
    }
  }

  static Future<bool> downloadAsPdf(
    BuildContext context,
    String content,
    String audioFileName,
  ) async {
    try {
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')[0];
      final baseFileName = audioFileName.split('.').first;
      final fileName = '${baseFileName}_transcript_$timestamp.pdf';

      // Create PDF
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Text(
                  'Transcript: $baseFileName',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Generated on: ${DateTime.now().toString().split('.')[0]}',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey),
              ),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.SizedBox(height: 20),
              pw.Text(
                content,
                style: const pw.TextStyle(fontSize: 12),
                textAlign: pw.TextAlign.left,
              ),
            ];
          },
        ),
      );

      final pdfBytes = await pdf.save();

      if (kIsWeb) {
        return false;
      } else {
        final outputPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Transcript as PDF',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['pdf'],
          bytes: pdfBytes,
        );

        if (outputPath != null) {
          try {
            final file = File(outputPath);
            await file.writeAsBytes(pdfBytes);
          } catch (e) {
            print('File already saved by file_picker: $e');
          }
          return true;
        }
      }
      return false;
    } catch (e) {
      print('Error downloading transcript as PDF: $e');
      return false;
    }
  }

  // NEW: Save images to gallery using Gal
  static Future<bool> saveImagesToGallery(
    BuildContext context,
    List<Uint8List> images,
  ) async {
    try {
      if (kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gallery save not supported on web'),
            duration: Duration(seconds: 2),
          ),
        );
        return false;
      }

      // Check for permissions
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final requestGranted = await Gal.requestAccess();
        if (!requestGranted) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Gallery access denied. Please enable in settings.',
                ),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
          }
          return false;
        }
      }

      int successCount = 0;
      int failCount = 0;

      // Get temporary directory to save files first
      final tempDir = await getTemporaryDirectory();

      for (int i = 0; i < images.length; i++) {
        try {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final fileName = 'generated_image_${timestamp}_$i.png';
          final filePath = '${tempDir.path}/$fileName';

          // Write image to temporary file
          final file = File(filePath);
          await file.writeAsBytes(images[i]);

          // Save to gallery
          await Gal.putImage(filePath);

          // Delete temporary file
          await file.delete();

          successCount++;
        } catch (e) {
          print('Error saving image $i: $e');
          failCount++;
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              failCount > 0
                  ? 'Saved $successCount of ${images.length} images'
                  : 'Successfully saved ${images.length} image(s) to gallery!',
            ),
            backgroundColor: failCount > 0 ? Colors.orange : Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      return successCount > 0;
    } catch (e) {
      print('Error saving images to gallery: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save images: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return false;
    }
  }

  static Future<bool> shareToGmail(
    BuildContext context,
    String content,
    String audioFileName,
  ) async {
    // Will implement later
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Gmail sharing feature coming soon!'),
        duration: Duration(seconds: 2),
      ),
    );
    return false;
  }

  static Future<bool> shareToDrive(
    BuildContext context,
    String content,
    String audioFileName,
  ) async {
    // Will implement later
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Google Drive sharing feature coming soon!'),
        duration: Duration(seconds: 2),
      ),
    );
    return false;
  }

  static void showDownloadSnackBar(BuildContext context, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Transcript downloaded successfully!'
              : 'Failed to download transcript',
        ),
        backgroundColor: success ? Colors.green : Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
