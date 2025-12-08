import 'package:docx_to_text/docx_to_text.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data'; // Needed for Image data
import 'package:file_picker/file_picker.dart';
import 'package:pina/models/image_generation_config.dart';
import 'package:pina/screens/constants.dart';
import 'package:pina/services/lm_studio_service.dart';
import 'package:pina/screens/loginscreen.dart';
import 'package:pina/services/submission_service.dart';
import 'package:pina/models/assembly_config.dart';
import 'package:pina/widgets/audio_config_dialog.dart';
import 'package:pina/services/audio_transcription_service.dart';
import 'package:pina/services/image_generation_service.dart'; // NEW IMPORT
import 'package:pina/widgets/generation_output_view.dart'; // NEW IMPORT
import 'package:pina/utils/transcript_formatter.dart';
import 'package:pina/utils/file_download_helper.dart';
import 'package:pina/widgets/download_options_dialog.dart';
import 'package:pina/widgets/image_config_dialog.dart';
import 'package:pina/widgets/image_download_dialog.dart';
import 'package:read_pdf_text/read_pdf_text.dart';

class LandingScreen extends StatefulWidget {
  final String title;
  final String userName;
  final String userEmail;

  const LandingScreen({
    required this.title,
    required this.userName,
    required this.userEmail,
    super.key,
  });

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final TextEditingController controller = TextEditingController();
  File? selectedDocument; // <--- Add this
  String? documentContent; // <--- Add this to hold the text inside the file

  // Services
  final LmStudioService _aiService = LmStudioService();
  final SubmissionService _submissionService = SubmissionService();
  final AudioTranscriptionService _audioService = AudioTranscriptionService();
  final ImageGenerationService _imageService = ImageGenerationService();
  ImageGenerationConfig imageConfig = ImageGenerationConfig(); // NEW SERVICE

  // Outputs
  String? output;
  List<Uint8List>? imageOutput; // NEW: Holds image data
  OutputType currentOutputType =
      OutputType.text; // NEW: Tracks what we are showing

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

  // Track the current prompt ID for the database update
  int? currentPromptId;

  // Audio-related state
  File? selectedAudioFile;
  bool isAudioToTextMode = false;

  // Audio configuration with default settings
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

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'txt',
        'md',
        'json',
        'pdf',
        'docx',
      ], // Added pdf & docx
    );

    if (result != null) {
      final file = File(result.files.single.path!);
      final extension = result.files.single.extension?.toLowerCase();
      String content = "";

      try {
        setState(() => isLoading = true); // Show loading while parsing

        if (extension == 'pdf') {
          // Parse PDF
          content = await ReadPdfText.getPDFtext(file.path);
        } else if (extension == 'docx') {
          // Parse Word (Read as bytes first, then convert)
          final bytes = await file.readAsBytes();
          content = docxToText(bytes);
        } else {
          // Parse Text/MD/JSON (Simple read)
          content = await file.readAsString();
        }

        // Save to State & RAG
        setState(() {
          selectedDocument = file;
          documentContent = content;
          isLoading = false;
        });

        // Send to your AI Memory
        if (content.isNotEmpty) {
          await _aiService.addDocumentToRAG(content);
          _showSnack("Document added to AI Memory!");
        } else {
          _showSnack("Document was empty.");
        }
      } catch (e) {
        setState(() => isLoading = false);
        _showSnack("Error reading file: $e", isError: true);
      }
    }
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
      setState(() {
        imageConfig = result;
      });
      _showSnack("Image settings updated successfully");
    }
  }

  Future<void> _showAudioConfig() async {
    final result = await showDialog<AssemblyConfig>(
      context: context,
      builder: (context) => AudioConfigDialog(initialConfig: audioConfig),
    );

    if (result != null) {
      setState(() {
        audioConfig = result;
      });
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
    String message = '';

    switch (result) {
      case DownloadOption.text:
        success = await FileDownloadHelper.downloadAsText(
          context,
          output!,
          selectedAudioFile!.path.split('/').last,
        );
        message = success
            ? 'Transcript downloaded as text successfully!'
            : 'Failed to download transcript';
        break;

      case DownloadOption.pdf:
        success = await FileDownloadHelper.downloadAsPdf(
          context,
          output!,
          selectedAudioFile!.path.split('/').last,
        );
        message = success
            ? 'Transcript downloaded as PDF successfully!'
            : 'Failed to download PDF';
        break;

      case DownloadOption.gmail:
        success = await FileDownloadHelper.shareToGmail(
          context,
          output!,
          selectedAudioFile!.path.split('/').last,
        );
        return;

      case DownloadOption.drive:
        success = await FileDownloadHelper.shareToDrive(
          context,
          output!,
          selectedAudioFile!.path.split('/').last,
        );
        return;
    }

    if (message.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: success ? Colors.green : Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _submitData() async {
    final promptText = controller.text.trim();
    final fromList = _getSelectedList(fromSelection);
    final toList = _getSelectedList(toSelection);

    // Determine Logic Flow
    final isAudioToText = fromList.contains("Audio") && toList.contains("Text");
    final isTextToImage =
        fromList.contains("Text") && toList.contains("Image"); // NEW CHECK

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
      imageOutput = null; // Clear previous image
      isAudioToTextMode = isAudioToText;
      currentPromptId = null;
    });

    // 1. Save Input to Database (Validates tokens/active status)
    final result = await _submissionService.validateAndSaveInput(
      userName: widget.userName,
      userEmail: widget.userEmail,
      prompt: isAudioToText ? "Audio Upload" : promptText,
      fromList: fromList,
      toList: toList,
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

    // 2. Capture the Prompt ID
    setState(() {
      currentPromptId = result.promptId;
    });

    String finalText = "";
    String modelUsed = "";

    try {
      if (isAudioToText) {
        // --- EXISTING AUDIO LOGIC ---
        final Map<String, dynamic>? resultData = await _audioService
            .transcribeAudio(selectedAudioFile!, audioConfig);

        if (resultData != null) {
          finalText = TranscriptFormatter.formatTranscriptOutput(resultData);
        } else {
          finalText = "An unknown error occurred during transcription.";
        }
        currentOutputType = OutputType.text;
        modelUsed = "AssemblyAI-STT";
      } else if (isTextToImage) {
        print("DEBUG: Prompt -> $promptText");
        print("DEBUG: Config Params -> ${imageConfig.toJson()}");
        // UPDATE THIS LINE TO PASS CONFIG
        imageOutput = await _imageService.generateImage(
          promptText,
          imageConfig,
        );

        currentOutputType = OutputType.image;
        modelUsed = "Stable-Diffusion-XL";
        finalText = "Generated ${imageOutput?.length} Images";
      } else {
        // --- EXISTING TEXT LOGIC ---
        final aiResponse = await _aiService.generateResponse(promptText);
        if (aiResponse is Map<String, dynamic>) {
          finalText =
              aiResponse['content'] ??
              aiResponse['response'] ??
              aiResponse.toString();
          modelUsed = aiResponse['model'] ?? "LM-Studio";
        } else {
          finalText = aiResponse.toString();
          modelUsed = "LM-Studio";
        }
        currentOutputType = OutputType.text;
      }
    } catch (e) {
      finalText = "Error: $e";
      modelUsed = "error";
      currentOutputType = OutputType.text;
    }

    // 3. Save Output to Database using the same ID
    if (currentPromptId != null) {
      await _submissionService.saveOutput(
        promptId: currentPromptId!,
        content: finalText,
        modelName: modelUsed,
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
            if (toSelection["Image"] == true) ...[
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _showImageConfig,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.tune), // Settings slider icon
                  label: const Text("Image Settings"),
                ),
              ),
              const SizedBox(height: 10),
            ],
            // Only show Audio upload if "Audio" is selected in "From"
            if (fromSelection["Audio"] == true) ...[
              _buildAudioSection(),
              const SizedBox(height: 15),
            ],

            _buildDataTypeSelections(),
            const SizedBox(height: 30),

            // Updated Output Section to handle Images
            if (output != null || imageOutput != null) _buildOutputSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildPromptInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          maxLines: null,
          onChanged: (value) {
            setState(() {
              tokenCount = estimateTokens(value);
            });
          },
          decoration: InputDecoration(
            hintText: "type here something",
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.search),
            // --- NEW ATTACHMENT BUTTON ---
            suffixIcon: IconButton(
              icon: Icon(
                Icons.attach_file,
                color: selectedDocument != null ? Colors.green : Colors.grey,
              ),
              onPressed: _pickDocument, // Calls the function above
              tooltip: "Attach Document (TXT/MD)",
            ),
          ),
        ),
        // --- VISUAL INDICATOR ---
        if (selectedDocument != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              children: [
                const Icon(Icons.description, size: 16, color: Colors.blue),
                const SizedBox(width: 5),
                Text(
                  "Analyzing: ${selectedDocument!.path.split('/').last}",
                  style: const TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () {
                    setState(() {
                      selectedDocument = null;
                      documentContent = null;
                    });
                    // Optional: You might want a clearRAG() function in your service too
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTokenCounter() {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        "Tokens: $tokenCount",
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
          if (audioConfig.redactPii)
            Text(
              "PII Redaction: Enabled (${audioConfig.redactPiiPolicies.length} categories)",
              style: const TextStyle(fontSize: 12, color: Colors.blue),
            ),
          if (audioConfig.speakerLabels)
            const Text(
              "Speaker Labels: Enabled",
              style: TextStyle(fontSize: 12, color: Colors.blue),
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
          // --- FIXED: Call the Image Dialog ---
          if (imageOutput == null || imageOutput!.isEmpty) return;

          final ImageDialogResult? result = await showDialog<ImageDialogResult>(
            context: context,
            builder: (context) => ImageDownloadDialog(
              images: imageOutput!, // Pass the list of images
              promptId: currentPromptId ?? 0, // Pass the prompt ID for tracking
            ),
          );

          if (result == null) return; // User closed dialog without action

          // Handle the action with actual implementation
          switch (result.action) {
            case ImageAction.save:
              // Call the actual save function
              await FileDownloadHelper.saveImagesToGallery(
                context,
                result.selectedImages,
              );
              break;
            case ImageAction.gmail:
              _showSnack("Gmail sharing coming soon!");
              // TODO: Implement Gmail sharing
              break;
            case ImageAction.drive:
              _showSnack("Google Drive upload coming soon!");
              // TODO: Implement Drive upload
              break;
          }
        },
      );
    }

    // Otherwise, use your existing Text/Audio layout
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
