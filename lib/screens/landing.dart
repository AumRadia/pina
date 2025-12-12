import 'package:docx_to_text/docx_to_text.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:pina/models/image_generation_config.dart';
import 'package:pina/models/local_whisper_config.dart';
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
import 'package:pina/widgets/local_whisper_config_dialog.dart';
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
  LocalWhisperConfig localWhisperConfig = LocalWhisperConfig();

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
    if (selectedProvider == LlmProvider.assemblyAi) {
      // Show Existing Assembly Dialog
      final result = await showDialog<AssemblyConfig>(
        context: context,
        builder: (context) => AudioConfigDialog(initialConfig: audioConfig),
      );
      if (result != null) {
        setState(() => audioConfig = result);
        _showSnack("AssemblyAI settings updated");
      }
    } else if (selectedProvider == LlmProvider.localWhisper) {
      // Show NEW Local Whisper Dialog
      final result = await showDialog<LocalWhisperConfig>(
        context: context,
        builder: (context) =>
            LocalWhisperConfigDialog(initialConfig: localWhisperConfig),
      );
      if (result != null) {
        setState(() => localWhisperConfig = result);
        _showSnack("Local Whisper settings updated");
      }
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

  //onsubmit please select at one input or output
  //server side validation of the input is pending
  //User uplaoded file will be saved, checked with some external vendor, output from the external vendor will also be saved.So depending upon the utput message will be shown to the user :- please upload an appropriate file.  Submit button will remain disabled
  //check for the balance of the user before going ahead

  //go to the user table and using userid as primary key get the values for paid or free, balance, category

  //if the user is user free and the category is NGO than only use small language models.
  //if not paid this is only for paid user:- upgrade now
  //input apikey, input para, prompt, weather structred or input

  //apikeys will be saved in the table with encryption and decryption. we have to save it inside conversioninput table

  //user's password and payment details will be kept private

  //we will validate the output of the api than only show it to the user

  //Translation show charcters in japanese or whatever laguage selected
  //if it doesnt have have characters than show in english
  //if the user is paid or not it comes under this
  //small icons to......
  //share to social media
  //email it should to to themselves

  //special, Big llm, Aggregators
  //small llm
  //if user is free only use small llm
  //include all the small language models
  //special :- canva
  //special:- midjourney image generation
  //speical:- runway
  //special:- superintelligent
  //special:- AMD, Nvdia
  //if the user is paid
  // {
  //  we will use the special models
  // }

  // token/credit counting is pending
  // we have to calculate input token
  // we have to calculate total token calculation

  //we have tp crate inout token field in converison input|
  //we have to add 3 fields in conversion output table output toekn, total token, and one more
  //total token/credit will be deducted from the  user balance column from the user-table

  //we have to insert a new record in the transaction table
  //tran_Id,group_id, user_id, from, to, vendor:-mistral, model name:-mitral, modelnumber, version number, input token, processing_token , output token, total_token, cost
  //in next transaction trans_id will be increase group_id will be same

  //if the user will be able to process further converison after the first transaction
  //a more processing button which will allow, we will take last  output as input for next conversion task
  //one more transaction will be stored for it in transaction id

  //globalexception

  //add to my AI

  Future<void> _submitData() async {
    final promptText = controller.text.trim();
    final fromList = _getSelectedList(fromSelection);
    final toList = _getSelectedList(toSelection);

    // Basic Validation
    if (fromList.isEmpty) {
      _showSnack("Please select at least one input type (From)", isError: true);
      return;
    }
    if (toList.isEmpty) {
      _showSnack("Please select at least one output type (To)", isError: true);
      return;
    }

    // --- LOGIC SWITCH BASED ON PROVIDER ---

    // Check 1: Audio Providers (Assembly AI OR Local Whisper)
    if (selectedProvider == LlmProvider.assemblyAi ||
        selectedProvider == LlmProvider.localWhisper) {
      if (selectedAudioFile == null) {
        _showSnack(
          "${selectedProvider.displayName} requires an audio file. Please upload one.",
          isError: true,
        );
        return;
      }
      // Force internal mode flag
      setState(() {
        isAudioToTextMode = true;
        currentOutputType = OutputType.text;
      });
    }
    // Check 2: Stable Diffusion (Image Generation)
    else if (selectedProvider == LlmProvider.stableDiffusion) {
      if (promptText.isEmpty) {
        _showSnack("Stable Diffusion requires a text prompt.", isError: true);
        return;
      }
      // Force internal mode flag
      setState(() {
        isAudioToTextMode = false;
        currentOutputType = OutputType.image;
      });
    }
    // Check 3: Standard LLMs (Text/Chat)
    else {
      if (promptText.isEmpty && attachedFiles.isEmpty) {
        _showSnack("Please enter a prompt or attach a file.", isError: true);
        return;
      }
      setState(() {
        isAudioToTextMode = false;
        currentOutputType = OutputType.text;
      });
    }

    setState(() {
      isLoading = true;
      output = null;
      imageOutput = null;
      currentPromptId = null;
    });

    // 1. PREPARE INPUT PARAMS
    Map<String, dynamic> inputParams = {};
    if (selectedProvider == LlmProvider.assemblyAi) {
      inputParams = audioConfig.toJson();
    } else if (selectedProvider == LlmProvider.stableDiffusion) {
      inputParams = imageConfig.toJson();
    } else if (selectedProvider == LlmProvider.localWhisper) {
      inputParams = localWhisperConfig.toJson();
    }

    // 2. SAVE INPUT
    // Adjust 'prompt' for Audio if it's empty
    final submissionPrompt =
        (selectedProvider == LlmProvider.assemblyAi ||
            selectedProvider == LlmProvider.localWhisper)
        ? "Audio Upload: ${selectedAudioFile!.path.split('/').last}"
        : promptText;

    final result = await _submissionService.validateAndSaveInput(
      userId: widget.userId,
      userEmail: widget.userEmail,
      prompt: submissionPrompt,
      fromList: fromList,
      toList: toList,
      inputParams: inputParams,
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
    Map<String, dynamic> outputParams = {};

    try {
      // --- ROUTING LOGIC ---

      if (selectedProvider == LlmProvider.assemblyAi) {
        // === CASE A: ASSEMBLY AI (CLOUD) ===
        final Map<String, dynamic>? resultData = await _audioService
            .transcribeAudio(selectedAudioFile!, audioConfig);

        if (resultData != null) {
          finalText = TranscriptFormatter.formatTranscriptOutput(resultData);
          outputParams = resultData;
        } else {
          finalText = "An unknown error occurred during transcription.";
        }
        modelUsed = "AssemblyAI-STT";
      } else if (selectedProvider == LlmProvider.localWhisper) {
        // === CASE B: LOCAL WHISPER (PYTHON) ===
        // This calls the new method we added to AudioTranscriptionService
        final result = await _audioService.transcribeWithLocalWhisper(
          selectedAudioFile!,
          localWhisperConfig,
        );

        if (result.containsKey('text')) {
          finalText = result['text']; // Success
          modelUsed = "Whisper-Local-Small";
          outputParams = {
            "method": "local_python_child_process",
            "status": "completed",
          };
        } else {
          finalText =
              "Error: ${result['error']}\nDetails: ${result['details']}";
          modelUsed = "error";
          outputParams = result;
        }
      } else if (selectedProvider == LlmProvider.stableDiffusion) {
        // === CASE C: STABLE DIFFUSION ===
        imageOutput = await _imageService.generateImage(
          promptText,
          imageConfig,
        );
        modelUsed = "Stable-Diffusion-XL";
        finalText = "Generated ${imageOutput?.length} Images";
        outputParams = {
          "count": imageOutput?.length ?? 0,
          "config_used": imageConfig.toJson(),
        };
      } else {
        // === CASE D: STANDARD LLMs (OpenRouter, OpenAI, etc) ===
        final aiResponse = await _aiService.generateResponse(
          promptText,
          selectedProvider,
        );

        finalText = aiResponse['content'] ?? aiResponse.toString();
        modelUsed = aiResponse['model'] ?? selectedProvider.name;
        outputParams = aiResponse;
      }
    } catch (e) {
      finalText = "Error: $e";
      modelUsed = "error";
      outputParams = {"error": e.toString()};
    }

    // 3. SAVE OUTPUT
    if (currentPromptId != null) {
      await _submissionService.saveOutput(
        promptId: currentPromptId!,
        userId: widget.userId,
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
