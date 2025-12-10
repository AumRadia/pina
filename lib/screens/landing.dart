import 'package:docx_to_text/docx_to_text.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:pina/models/image_generation_config.dart';
import 'package:pina/services/lm_studio_service.dart';
import 'package:pina/screens/loginscreen.dart';
import 'package:pina/services/submission_service.dart';
import 'package:pina/models/assembly_config.dart';
import 'package:pina/widgets/audio_config_dialog.dart';
import 'package:pina/services/audio_transcription_service.dart';
import 'package:pina/services/image_generation_service.dart';
import 'package:pina/widgets/generation_output_view.dart';
import 'package:pina/utils/transcript_formatter.dart';
import 'package:pina/utils/file_download_helper.dart';
import 'package:pina/widgets/download_options_dialog.dart';
import 'package:pina/widgets/image_config_dialog.dart';
import 'package:pina/widgets/image_download_dialog.dart';
import 'package:read_pdf_text/read_pdf_text.dart';

// Helper class for attachments
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
}

class LandingScreen extends StatefulWidget {
  final String title;
  final String userName;
  final String userId;
  final String userEmail;

  const LandingScreen({
    required this.title,
    required this.userName,
    required this.userId,
    required this.userEmail,
    super.key,
  });

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final TextEditingController controller = TextEditingController();

  // List to hold multiple files
  List<AttachedFile> attachedFiles = [];

  // Services
  final LmStudioService _aiService = LmStudioService();
  final SubmissionService _submissionService = SubmissionService();
  final AudioTranscriptionService _audioService = AudioTranscriptionService();
  final ImageGenerationService _imageService = ImageGenerationService();
  ImageGenerationConfig imageConfig = ImageGenerationConfig();
  LlmProvider selectedProvider = LlmProvider.openRouter;

  // Outputs
  String? output;
  List<Uint8List>? imageOutput;
  OutputType currentOutputType = OutputType.text;

  final List<String> dataTypes = [
    "Text",
    "Image",
    "Audio",
    "Video",
    "Multiple",
  ];
  Map<String, bool> fromSelection = {};
  Map<String, bool> toSelection = {};
  bool isLoading = false;
  int tokenCount = 0;
  int? currentPromptId;

  // Audio-related state
  File? selectedAudioFile;
  bool isAudioToTextMode = false;

  AssemblyConfig audioConfig = AssemblyConfig(
    languageCode: 'en',
    punctuate: true,
    formatText: true,
  );

  @override
  void initState() {
    super.initState();
    _initializeSelections();
    _autoSelectFromTitle();
  }

  void _initializeSelections() {
    for (var t in dataTypes) {
      fromSelection[t] = false;
      toSelection[t] = false;
    }
  }

  Widget _buildProviderSelector() {
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
                  // Use the helper extension to show A1, A2, L1, etc.
                  child: Text(provider.displayName),
                );
              }).toList(),
              onChanged: (LlmProvider? newValue) {
                if (newValue != null) {
                  setState(() => selectedProvider = newValue);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  void _autoSelectFromTitle() {
    List<String> parts = widget.title.split(" to ");
    if (parts.length >= 2) {
      String source = parts[0];
      String target = parts[1];
      setState(() {
        if (fromSelection.containsKey(source)) fromSelection[source] = true;
        if (toSelection.containsKey(target)) toSelection[target] = true;
      });
    }
  }

  // Calculate current total size of all attachments
  int get currentTotalSize =>
      attachedFiles.fold(0, (sum, f) => sum + f.sizeBytes);

  // --- UPDATED FILE PICKER LOGIC ---
  Future<void> _pickFiles() async {
    // 1. Check Max Files Limit
    if (attachedFiles.length >= 5) {
      _showSnack("Maximum 5 files allowed.", isError: true);
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowMultiple: true,
        allowedExtensions: [
          'txt', 'md', 'json', 'pdf', 'docx', // Docs
          'jpg', 'jpeg', 'png', 'webp', // Images
          'mp4', 'mov', 'avi', 'mp3', // Media
        ],
      );

      if (result != null) {
        setState(() => isLoading = true);

        List<AttachedFile> newFiles = [];
        int tempTotalSize = currentTotalSize;
        bool countExceeded = false;

        for (var platformFile in result.files) {
          // 2. CHECK: Max Files Limit
          if (attachedFiles.length + newFiles.length >= 5) {
            countExceeded = true;
            break;
          }

          // 3. CHECK: Individual File Size > 100MB
          if (platformFile.size > 100 * 1024 * 1024) {
            _showSnack("File size should be less than 100 MB", isError: true);
            continue; // Skip this specific file, continue loop
          }

          // 4. CHECK: Total Size Limit > 100MB
          if (tempTotalSize + platformFile.size > 100 * 1024 * 1024) {
            _showSnack("Total size cannot exceed 100 MB", isError: true);
            break; // Stop adding more files
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

        // Update State
        setState(() {
          attachedFiles.addAll(newFiles);
          isLoading = false;
        });

        if (countExceeded) {
          _showSnack(
            "Stopped adding files: Max 5 files reached.",
            isError: true,
          );
        }

        // Update AI Context
        _updateAiContext();
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showSnack("Error picking files: $e", isError: true);
    }
  }

  void _removeFile(int index) {
    setState(() {
      attachedFiles.removeAt(index);
    });
    _updateAiContext();
  }

  Future<void> _updateAiContext() async {
    if (attachedFiles.isEmpty) {
      _aiService.removeDocument();
      return;
    }

    StringBuffer combinedContext = StringBuffer();
    combinedContext.writeln("USER UPLOADED FILES SUMMARY:");

    for (var doc in attachedFiles) {
      combinedContext.writeln("\n--- File Name: ${doc.name} ---");
      if (doc.extractedText != null && doc.extractedText!.isNotEmpty) {
        combinedContext.writeln(doc.extractedText);
      } else {
        combinedContext.writeln(
          "[Media file: ${doc.name} - No text extracted]",
        );
      }
    }

    await _aiService.addDocumentToRAG(combinedContext.toString());
  }

  List<String> _getSelectedList(Map<String, bool> map) {
    return map.entries.where((e) => e.value).map((e) => e.key).toList();
  }

  int estimateTokens(String text) {
    if (text.trim().isEmpty) return 0;
    final words = text.trim().split(RegExp(r"\s+")).length;
    return (words * 1.3).round();
  }

  Future<void> pickAudioFile() async {
    final file = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        "mp3",
        "wav",
        "m4a",
        "mp4",
        "mov",
        "mkv",
        "avi",
        "webm",
      ],
    );
    if (file != null) {
      setState(() {
        selectedAudioFile = File(file.files.single.path!);
      });
    }
  }

  Future<void> _showImageConfig() async {
    final result = await showDialog<ImageGenerationConfig>(
      context: context,
      builder: (context) => ImageConfigDialog(initialConfig: imageConfig),
    );
    if (result != null) {
      setState(() => imageConfig = result);
      _showSnack("Image settings updated successfully");
    }
  }

  Future<void> _showAudioConfig() async {
    final result = await showDialog<AssemblyConfig>(
      context: context,
      builder: (context) => AudioConfigDialog(initialConfig: audioConfig),
    );
    if (result != null) {
      setState(() => audioConfig = result);
      _showSnack("Audio settings updated successfully");
    }
  }

  Future<void> _downloadTranscript() async {
    if (output == null || selectedAudioFile == null) return;

    final result = await showDialog<DownloadOption>(
      context: context,
      builder: (context) => DownloadOptionsDialog(
        content: output!,
        audioFileName: selectedAudioFile!.path.split('/').last,
        promptId: currentPromptId ?? 0,
      ),
    );

    if (result == null) return;

    bool success = false;
    switch (result) {
      case DownloadOption.text:
        success = await FileDownloadHelper.downloadAsText(
          context,
          output!,
          selectedAudioFile!.path.split('/').last,
        );
        break;
      case DownloadOption.pdf:
        success = await FileDownloadHelper.downloadAsPdf(
          context,
          output!,
          selectedAudioFile!.path.split('/').last,
        );
        break;
      case DownloadOption.gmail:
        await FileDownloadHelper.shareToGmail(
          context,
          output!,
          selectedAudioFile!.path.split('/').last,
        );
        return;
      case DownloadOption.drive:
        await FileDownloadHelper.shareToDrive(
          context,
          output!,
          selectedAudioFile!.path.split('/').last,
        );
        return;
    }

    if (success) _showSnack("Downloaded successfully!");
  }

  Future<void> _submitData() async {
    final promptText = controller.text.trim();
    final fromList = _getSelectedList(fromSelection);
    final toList = _getSelectedList(toSelection);

    final isAudioToText = fromList.contains("Audio") && toList.contains("Text");
    final isTextToImage = fromList.contains("Text") && toList.contains("Image");

    if (isAudioToText && selectedAudioFile == null) {
      _showSnack("Please upload an audio file first");
      return;
    }
    if (!isAudioToText && promptText.isEmpty) {
      _showSnack("Please enter a prompt");
      return;
    }

    setState(() {
      isLoading = true;
      output = null;
      imageOutput = null;
      isAudioToTextMode = isAudioToText;
      currentPromptId = null;
    });

    // 1. PREPARE INPUT PARAMS
    Map<String, dynamic> inputParams = {};
    if (isAudioToText) {
      inputParams = audioConfig.toJson(); // Capture AssemblyAI settings
    } else if (isTextToImage) {
      inputParams = imageConfig.toJson(); // Capture Image settings
    }

    // 2. SAVE INPUT (Pass the params)
    final result = await _submissionService.validateAndSaveInput(
      userId: widget.userId,
      userEmail: widget.userEmail,
      prompt: isAudioToText ? "Audio Upload" : promptText,
      fromList: fromList,
      toList: toList,
      inputParams: inputParams, // <--- NEW: Send config to backend
    );

    if (!result.success) {
      setState(() => isLoading = false);
      if (result.statusCode == 401) {
        _showSnack(result.errorMessage!);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      } else {
        _showSnack(result.errorMessage!, isError: true);
      }
      return;
    }

    setState(() => currentPromptId = result.promptId);

    String finalText = "";
    String modelUsed = "";
    Map<String, dynamic> outputParams = {}; // <--- NEW: To store raw result

    try {
      if (isAudioToText) {
        // --- AUDIO MODE ---
        final Map<String, dynamic>? resultData = await _audioService
            .transcribeAudio(selectedAudioFile!, audioConfig);

        if (resultData != null) {
          finalText = TranscriptFormatter.formatTranscriptOutput(resultData);
          outputParams =
              resultData; // <--- Store full JSON (confidence, timestamps, etc)
        } else {
          finalText = "An unknown error occurred during transcription.";
        }
        currentOutputType = OutputType.text;
        modelUsed = "AssemblyAI-STT";
      } else if (isTextToImage) {
        // --- IMAGE MODE ---
        imageOutput = await _imageService.generateImage(
          promptText,
          imageConfig,
        );
        currentOutputType = OutputType.image;
        modelUsed = "Stable-Diffusion-XL";
        finalText = "Generated ${imageOutput?.length} Images";

        // For images, we might just store metadata since we can't store binary data easily in MongoDB JSON
        outputParams = {
          "count": imageOutput?.length ?? 0,
          "config_used": imageConfig.toJson(),
        };
      } else {
        // --- TEXT MODE ---
        final aiResponse = await _aiService.generateResponse(
          promptText,
          selectedProvider,
        );

        if (aiResponse is Map<String, dynamic>) {
          finalText = aiResponse['content'] ?? aiResponse.toString();
          modelUsed = aiResponse['model'] ?? selectedProvider.name;
          outputParams = aiResponse; // <--- Store full raw AI response
        } else {
          finalText = aiResponse.toString();
          modelUsed = selectedProvider.name;
          outputParams = {"raw_response": finalText};
        }
        currentOutputType = OutputType.text;
      }
    } catch (e) {
      finalText = "Error: $e";
      modelUsed = "error";
      currentOutputType = OutputType.text;
      outputParams = {"error": e.toString()};
    }

    // 3. SAVE OUTPUT (Pass the params)
    if (currentPromptId != null) {
      await _submissionService.saveOutput(
        promptId: currentPromptId!,
        userId: widget.userId, // <--- Pass userId
        content: finalText,
        modelName: modelUsed,
        outputParams: outputParams,
      );
    }

    setState(() {
      output = finalText;
      isLoading = false;
    });
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : null,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      bottomSheet: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          width: double.infinity,
          child: SizedBox(
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: isLoading ? null : _submitData,
              child: isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Submit", style: TextStyle(fontSize: 18)),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPromptInput(),
            const SizedBox(height: 8),
            _buildTokenCounter(),
            const SizedBox(height: 15),

            // --- ATTACHMENTS SECTION ---
            if (attachedFiles.isNotEmpty) _buildAttachmentsList(),

            const SizedBox(height: 15),
            if (toSelection["Image"] == true) ...[
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _showImageConfig,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.tune),
                  label: const Text("Image Settings"),
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (fromSelection["Audio"] == true) ...[
              _buildAudioSection(),
              const SizedBox(height: 15),
            ],

            _buildDataTypeSelections(),
            const SizedBox(height: 15),
            _buildProviderSelector(),
            const SizedBox(height: 30),
            if (output != null || imageOutput != null) _buildOutputSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildPromptInput() {
    return TextField(
      controller: controller,
      maxLines: null,
      onChanged: (value) => setState(() => tokenCount = estimateTokens(value)),
      decoration: InputDecoration(
        hintText: "type here something",
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.search),
        // --- Plus Button / Attach Icon ---
        suffixIcon: IconButton(
          icon: const Icon(Icons.add_circle_outline, color: Colors.blue),
          onPressed: _pickFiles,
          tooltip: "Add Files (Max 5)",
        ),
      ),
    );
  }

  // --- WIDGET: Display Attached Files ---
  Widget _buildAttachmentsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Attached Files:",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(attachedFiles.length, (index) {
            final file = attachedFiles[index];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey[400]!),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon
                  Icon(
                    ['jpg', 'png', 'jpeg'].contains(file.extension)
                        ? Icons.image
                        : ['mp4', 'mov', 'avi'].contains(file.extension)
                        ? Icons.videocam
                        : Icons.description,
                    size: 16,
                    color: Colors.black54,
                  ),
                  const SizedBox(width: 5),
                  // Name
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 150),
                    child: Text(
                      file.name,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Cross Mark to Remove
                  InkWell(
                    onTap: () => _removeFile(index),
                    child: const Icon(Icons.close, size: 16, color: Colors.red),
                  ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildTokenCounter() {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        "Tokens: $tokenCount | Files: ${attachedFiles.length}/5",
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
    );
  }

  Widget _buildAudioSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: pickAudioFile,
                child: const Text("Upload Audio File"),
              ),
            ),
            if (selectedAudioFile != null) ...[
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _showAudioConfig,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.settings),
                label: const Text("Settings"),
              ),
            ],
          ],
        ),
        if (selectedAudioFile != null) _buildAudioFileInfo(),
      ],
    );
  }

  Widget _buildAudioFileInfo() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Selected: ${selectedAudioFile!.path.split('/').last}",
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            "Language: ${SupportedLanguages.getName(audioConfig.languageCode)}",
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildOutputSection() {
    if (currentOutputType == OutputType.image) {
      return GenerationOutputView(
        type: OutputType.image,
        imageData: imageOutput,
        onDownload: () async {
          if (imageOutput == null || imageOutput!.isEmpty) return;
          final ImageDialogResult? result = await showDialog<ImageDialogResult>(
            context: context,
            builder: (context) => ImageDownloadDialog(
              images: imageOutput!,
              promptId: currentPromptId ?? 0,
            ),
          );
          if (result != null && result.action == ImageAction.save) {
            await FileDownloadHelper.saveImagesToGallery(
              context,
              result.selectedImages,
            );
          }
        },
      );
    }

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
            if (isAudioToTextMode && selectedAudioFile != null)
              ElevatedButton.icon(
                onPressed: _downloadTranscript,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
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
          child: SelectableText(
            output ?? "",
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildDataTypeSelections() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "From:",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        _buildCheckboxGroup(fromSelection),
        const SizedBox(height: 20),
        const Text(
          "To:",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        _buildCheckboxGroup(toSelection),
      ],
    );
  }

  Widget _buildCheckboxGroup(Map<String, bool> selection) {
    return Wrap(
      spacing: 8,
      children: dataTypes.map((type) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: selection[type],
              onChanged: (v) => setState(() => selection[type] = v ?? false),
              activeColor: Colors.black,
            ),
            Text(type),
          ],
        );
      }).toList(),
    );
  }
}
