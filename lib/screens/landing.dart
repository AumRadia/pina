import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart'; // Required for Audio Playback
import 'package:path_provider/path_provider.dart'; // Required for temp file creation

import 'package:pina/models/image_generation_config.dart';
import 'package:pina/models/local_whisper_config.dart';
import 'package:pina/models/attached_file.dart';
import 'package:pina/models/kokoro_config.dart'; // New Import
import 'package:pina/models/melo_config.dart';
import 'package:pina/services/lm_studio_service.dart';
import 'package:pina/screens/loginscreen.dart';
import 'package:pina/services/submission_service.dart';
import 'package:pina/models/assembly_config.dart';
import 'package:pina/utils/melo_config_dialog.dart';
import 'package:pina/widgets/audio_config_dialog.dart';
import 'package:pina/services/audio_transcription_service.dart';
import 'package:pina/services/image_generation_service.dart';
import 'package:pina/widgets/generation_output_view.dart';
import 'package:pina/utils/file_download_helper.dart';
import 'package:pina/utils/file_processing_helper.dart';
import 'package:pina/utils/submission_handler.dart';
import 'package:pina/widgets/download_options_dialog.dart';
import 'package:pina/widgets/image_config_dialog.dart';
import 'package:pina/widgets/image_download_dialog.dart';
import 'package:pina/widgets/local_whisper_config_dialog.dart';
import 'package:pina/widgets/kokoro_config_dialog.dart'; // New Import
import 'package:pina/widgets/provider_selector_widget.dart';

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
  // MASTER SOURCE OF TRUTH FOR TEMPERATURE
  MeloConfig meloConfig = MeloConfig();
  double _temperature = 0.7;
  String _lastSubmittedPrompt = "";

  final TextEditingController controller = TextEditingController();

  // Attachments
  List<AttachedFile> attachedFiles = [];

  // Services
  final LmStudioService _aiService = LmStudioService();
  final SubmissionService _submissionService = SubmissionService();
  final AudioTranscriptionService _audioService = AudioTranscriptionService();
  final ImageGenerationService _imageService = ImageGenerationService();

  // Configs
  ImageGenerationConfig imageConfig = ImageGenerationConfig();
  LlmProvider selectedProvider = LlmProvider.openRouter;
  LocalWhisperConfig localWhisperConfig = LocalWhisperConfig();
  AssemblyConfig audioConfig = AssemblyConfig(
    languageCode: 'en',
    punctuate: true,
    formatText: true,
  );
  KokoroConfig kokoroConfig =
      KokoroConfig(); // New Config (Used for Kokoro, CosyVoice & Melo)

  // Outputs & State
  String? output;
  List<Uint8List>? imageOutput;

  // --- Audio Output State ---
  Uint8List? audioOutputBytes;
  final AudioPlayer _audioPlayer = AudioPlayer();
  // -------------------------------

  OutputType currentOutputType = OutputType.text;
  bool isLoading = false;
  int tokenCount = 0;
  int? currentPromptId;

  // Selections
  final List<String> dataTypes = [
    "Text",
    "Image",
    "Audio",
    "Video",
    "Multiple",
  ];
  Map<String, bool> fromSelection = {};
  Map<String, bool> toSelection = {};

  // Audio-specific
  // This is now derived from attachedFiles
  File? selectedAudioFile;
  bool isAudioToTextMode = false;

  final List<String> _audioExtensions = [
    'mp3',
    'wav',
    'm4a',
    'mp4',
    'mov',
    'mkv',
    'avi',
    'webm',
  ];

  @override
  void initState() {
    super.initState();
    _initializeSelections();
    _autoSelectFromTitle();
  }

  @override
  void dispose() {
    _audioPlayer.dispose(); // Clean up audio player
    controller.dispose();
    super.dispose();
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

  int get currentTotalSize =>
      attachedFiles.fold(0, (sum, f) => sum + f.sizeBytes);

  // --- FILE PICKER (Unified) ---
  Future<void> _pickFiles() async {
    setState(() => isLoading = true);

    final result = await FileProcessingHelper.pickAndProcessFiles(
      currentFileCount: attachedFiles.length,
      currentTotalSize: currentTotalSize,
    );

    setState(() => isLoading = false);

    if (result.containsKey('error')) {
      _showSnack(result['error'], isError: true);
      return;
    }

    if (result.containsKey('files')) {
      List<AttachedFile> newFiles = result['files'];
      setState(() {
        attachedFiles.addAll(newFiles);
      });
      _checkForAudioFiles(); // Check if user uploaded an audio file
      _updateAiContext();
    }

    if (result.containsKey('warning') && result['warning'] != null) {
      _showSnack(result['warning'], isError: true);
    }
  }

  void _removeFile(int index) {
    setState(() => attachedFiles.removeAt(index));
    _checkForAudioFiles(); // Re-check audio state
    _updateAiContext();
  }

  // Detects if any attached file is audio and sets selectedAudioFile
  void _checkForAudioFiles() {
    File? foundAudio;
    for (var file in attachedFiles) {
      if (_audioExtensions.contains(file.extension.toLowerCase())) {
        foundAudio = File(file.path);
        break; // Use the first found audio file
      }
    }

    setState(() {
      selectedAudioFile = foundAudio;
      // Auto-update UI mode if audio is detected
      if (selectedAudioFile != null) {
        if (!fromSelection['Audio']!) fromSelection['Audio'] = true;
      }
    });
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

  // --- DIALOGS ---
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

  Future<void> _showKokoroConfig() async {
    final result = await showDialog<KokoroConfig>(
      context: context,
      builder: (context) => KokoroConfigDialog(initialConfig: kokoroConfig),
    );
    if (result != null) {
      setState(() => kokoroConfig = result);
      _showSnack(
        "TTS Settings updated: ${kokoroConfig.voice} @ ${kokoroConfig.speed}x",
      );
    }
  }

  Future<void> _showTtsSettings() async {
    if (selectedProvider == LlmProvider.meloTts) {
      // Show Melo Dialog
      final result = await showDialog<MeloConfig>(
        context: context,
        builder: (context) => MeloConfigDialog(initialConfig: meloConfig),
      );
      if (result != null) {
        setState(() => meloConfig = result);
        _showSnack(
          "Melo Updated: Speed ${meloConfig.speed}x | Noise ${meloConfig.noiseScale}",
        );
      }
    } else {
      // Existing Kokoro/CosyVoice Logic
      final result = await showDialog<KokoroConfig>(
        context: context,
        builder: (context) => KokoroConfigDialog(initialConfig: kokoroConfig),
      );
      if (result != null) {
        setState(() => kokoroConfig = result);
        _showSnack("Kokoro Settings updated");
      }
    }
  }

  Future<void> _showAudioConfig() async {
    if (selectedProvider == LlmProvider.assemblyAi) {
      final result = await showDialog<AssemblyConfig>(
        context: context,
        builder: (context) => AudioConfigDialog(initialConfig: audioConfig),
      );
      if (result != null) {
        setState(() => audioConfig = result);
        _showSnack("AssemblyAI settings updated");
      }
    } else if (selectedProvider == LlmProvider.localWhisper) {
      final result = await showDialog<LocalWhisperConfig>(
        context: context,
        builder: (context) =>
            LocalWhisperConfigDialog(initialConfig: localWhisperConfig),
      );
      if (result != null) {
        setState(() => localWhisperConfig = result);
        _showSnack("Local Whisper settings updated");
      }
    } else {
      _showSnack("Select an Audio Provider to configure settings.");
    }
  }

  // --- SUBMISSION LOGIC (UPDATED) ---
  Future<void> _submitData({
    String? manualPrompt,
    bool isRegeneration = false,
  }) async {
    final promptText = manualPrompt ?? controller.text.trim();

    if (manualPrompt == null) {
      _lastSubmittedPrompt = controller.text.trim();
    }

    final fromList = _getSelectedList(fromSelection);
    final toList = _getSelectedList(toSelection);

    // 1. VALIDATION
    if (fromList.isEmpty || toList.isEmpty) {
      _showSnack("Please select Input and Output types.", isError: true);
      return;
    }

    if ((selectedProvider == LlmProvider.assemblyAi ||
            selectedProvider == LlmProvider.localWhisper) &&
        selectedAudioFile == null) {
      _showSnack("Audio provider requires an audio file.", isError: true);
      return;
    }
    if (selectedProvider == LlmProvider.stableDiffusion && promptText.isEmpty) {
      _showSnack(
        "Please enter a text prompt for image generation.",
        isError: true,
      );
      return;
    }
    // Validation for TTS Models (Kokoro OR CosyVoice OR Melo)
    if ((selectedProvider == LlmProvider.kokoro ||
            selectedProvider == LlmProvider.cosyVoice ||
            selectedProvider == LlmProvider.meloTts) &&
        promptText.isEmpty) {
      _showSnack("Please enter text to generate audio.", isError: true);
      return;
    }

    // 2. UI PREP
    _prepareUIForSubmission();
    setState(() {
      isLoading = true;
      output = null;
      imageOutput = null;
      audioOutputBytes = null; // Reset audio
      if (!isRegeneration) {
        currentPromptId = null;
      }
    });

    // --- 3. GATHER CHECKBOX OPTIONS ---
    Map<String, bool> effectiveOptions = {};
    fromSelection.forEach((key, value) {
      if (value) effectiveOptions["Input Type: $key"] = true;
    });
    toSelection.forEach((key, value) {
      if (value) effectiveOptions["Output Type: $key"] = true;
    });

    double effectiveTemperature = _temperature;

    // 4. SAVE INPUT (Database) - SKIP IF REGENERATING
    if (!isRegeneration) {
      final inputParams = _getInputParams();

      // Do NOT save temperature for TTS models
      if (selectedProvider != LlmProvider.kokoro &&
          selectedProvider != LlmProvider.cosyVoice &&
          selectedProvider != LlmProvider.meloTts) {
        inputParams['temperature'] = effectiveTemperature;
      }

      final submissionPrompt =
          _isAudioProvider(selectedProvider) && selectedAudioFile != null
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
    }

    // 5. CHECK FOR IMAGES
    bool hasImages = attachedFiles.any((f) {
      final ext = f.extension.toLowerCase();
      return ['jpg', 'png', 'jpeg', 'webp', 'bmp'].contains(ext);
    });

    // 6. EXECUTE LOGIC
    final executionResult = await SubmissionHandler.processRequest(
      provider: selectedProvider,
      promptText: promptText,
      audioFile: selectedAudioFile,
      hasImages: hasImages,
      attachedFiles: attachedFiles,
      activeOptions: effectiveOptions,
      assemblyConfig: audioConfig,
      whisperConfig: localWhisperConfig,
      imageConfig: imageConfig,
      kokoroConfig: kokoroConfig,
      meloConfig: meloConfig, // <--- ADD THIS LINE HERE
      audioService: _audioService,
      imageService: _imageService,
      aiService: _aiService,
      temperature: effectiveTemperature,
    );

    // 7. UPDATE UI WITH RESULTS
    if (executionResult.isImage) {
      imageOutput = executionResult.images;
      // Ensure UI knows we have images
      currentOutputType = OutputType.image;
    } else if (executionResult.isAudio) {
      // HANDLE AUDIO OUTPUT
      audioOutputBytes = executionResult.audioBytes;
      output = executionResult.content;
      // We don't have OutputType.audio in the existing enum usually,
      // so we rely on audioOutputBytes not being null in build()
    } else {
      output = executionResult.content;
      currentOutputType = OutputType.text;
    }

    // 8. SAVE OUTPUT (Database)
    if (currentPromptId != null) {
      await _submissionService.saveOutput(
        promptId: currentPromptId!,
        userId: widget.userId,
        content: executionResult.content,
        modelName: executionResult.modelName,
        outputParams: executionResult.metaData,
        errorLogs: executionResult.errorLogs,
      );
    }

    setState(() => isLoading = false);
  }

  // --- REGENERATION LOGIC ---
  void _regenerateResponse() {
    if (output == null || output!.isEmpty) return;

    final originalPrompt = _lastSubmittedPrompt.isNotEmpty
        ? _lastSubmittedPrompt
        : controller.text;
    final previousOutput = output!;

    final regenerationPrompt =
        """
$originalPrompt

[PREVIOUS OUTPUT]:
$previousOutput

[INSTRUCTION]:
Rewrite the previous answer to be clearer, more accurate, and more concise.
Fix mistakes, remove fluff, and keep the same meaning.
""";

    _submitData(manualPrompt: regenerationPrompt, isRegeneration: true);
  }

  // Helper getters
  bool _isAudioProvider(LlmProvider p) =>
      p == LlmProvider.assemblyAi || p == LlmProvider.localWhisper;

  void _prepareUIForSubmission() {
    if (_isAudioProvider(selectedProvider) || selectedAudioFile != null) {
      setState(() {
        isAudioToTextMode = true;
        currentOutputType = OutputType.text;
      });
    } else if (selectedProvider == LlmProvider.stableDiffusion) {
      setState(() {
        isAudioToTextMode = false;
        currentOutputType = OutputType.image;
      });
    } else {
      setState(() {
        isAudioToTextMode = false;
        currentOutputType = OutputType.text;
      });
    }
  }

  Map<String, dynamic> _getInputParams() {
    if (selectedProvider == LlmProvider.assemblyAi) return audioConfig.toJson();
    if (selectedProvider == LlmProvider.stableDiffusion)
      return imageConfig.toJson();
    if (selectedProvider == LlmProvider.localWhisper)
      return localWhisperConfig.toJson();

    // FIX: Separate Melo from Kokoro/CosyVoice
    if (selectedProvider == LlmProvider.meloTts) {
      return meloConfig
          .toJson(); // Now includes accent, language, speed, noiseScale
    }

    if (selectedProvider == LlmProvider.kokoro ||
        selectedProvider == LlmProvider.cosyVoice) {
      return kokoroConfig.toJson();
    }

    return {};
  }

  // --- DOWNLOAD HELPERS ---
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
    String fileName = selectedAudioFile!.path.split('/').last;

    switch (result) {
      case DownloadOption.text:
        if (await FileDownloadHelper.downloadAsText(context, output!, fileName))
          _showSnack("Downloaded!");
        break;
      case DownloadOption.pdf:
        if (await FileDownloadHelper.downloadAsPdf(context, output!, fileName))
          _showSnack("Downloaded!");
        break;
      case DownloadOption.gmail:
        await FileDownloadHelper.shareToGmail(context, output!, fileName);
        break;
      case DownloadOption.drive:
        await FileDownloadHelper.shareToDrive(context, output!, fileName);
        break;
    }
  }

  // --- SAVE AUDIO BYTES ---
  Future<void> _saveGeneratedAudio() async {
    if (audioOutputBytes == null) return;

    try {
      String fileName =
          "generated_audio_${DateTime.now().millisecondsSinceEpoch}.wav";

      String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Audio',
        fileName: fileName,
        type: FileType.audio,
        bytes: audioOutputBytes,
      );

      if (outputPath != null) {
        File savedFile = File(outputPath);
        if (!savedFile.existsSync()) {
          await savedFile.writeAsBytes(audioOutputBytes!);
        }
        _showSnack("Audio saved to $outputPath");
      } else {
        _showSnack("Save cancelled");
      }
    } catch (e) {
      _showSnack("Error saving file: $e", isError: true);
    }
  }

  List<String> _getSelectedList(Map<String, bool> map) {
    return map.entries.where((e) => e.value).map((e) => e.key).toList();
  }

  int estimateTokens(String text) {
    if (text.trim().isEmpty) return 0;
    return (text.trim().split(RegExp(r"\s+")).length * 1.3).round();
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  // --- UI BUILD ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      bottomSheet: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 55,
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: isLoading ? null : () => _submitData(),
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

            // Updated Audio Section: Only shows settings if audio is detected
            if (selectedAudioFile != null) ...[
              _buildAudioSection(),
              const SizedBox(height: 15),
            ],

            _buildDataTypeSelections(),
            const SizedBox(height: 15),

            _buildTemperatureSlider(),
            const SizedBox(height: 15),

            // Provider + Settings Row
            Row(
              children: [
                Expanded(
                  child: ProviderSelectorWidget(
                    selectedProvider: selectedProvider,
                    onProviderChanged: (p) =>
                        setState(() => selectedProvider = p),
                  ),
                ),
                // Show Settings button if Kokoro OR CosyVoice OR Melo is selected
                if (selectedProvider == LlmProvider.kokoro ||
                    selectedProvider == LlmProvider.cosyVoice ||
                    selectedProvider == LlmProvider.meloTts) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _showTtsSettings, // Reuse Config Dialog
                    icon: const Icon(Icons.tune),
                    tooltip: "TTS Settings",
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 30),
            if (output != null ||
                imageOutput != null ||
                audioOutputBytes != null)
              _buildOutputSection(),
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
        suffixIcon: IconButton(
          icon: const Icon(Icons.add_circle_outline, color: Colors.blue),
          onPressed: _pickFiles, // Unified picker
          tooltip: "Add Files (Max 5)",
        ),
      ),
    );
  }

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
                  Icon(
                    ['jpg', 'png', 'jpeg'].contains(file.extension)
                        ? Icons.image
                        : _audioExtensions.contains(file.extension)
                        ? Icons.audiotrack
                        : Icons.description,
                    size: 16,
                    color: Colors.black54,
                  ),
                  const SizedBox(width: 5),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 150),
                    child: Text(
                      file.name,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                "Audio: ${selectedAudioFile!.path.split('/').last}",
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
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

  Widget _buildTemperatureSlider() {
    // 1. Determine if slider should be enabled
    // Disable for TTS models (Kokoro, CosyVoice, Melo) or when loading
    bool isEnabled =
        selectedProvider != LlmProvider.kokoro &&
        selectedProvider != LlmProvider.cosyVoice &&
        selectedProvider != LlmProvider.meloTts &&
        !isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  "Creativity",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    // Dim text if disabled
                    color: isEnabled ? Colors.black : Colors.grey,
                  ),
                ),
                const SizedBox(width: 5),
                Tooltip(
                  message:
                      "Controls how 'random' or 'creative' the AI is.\n"
                      "Low = Focused, factual, and consistent.\n"
                      "High = Creative, diverse, and unpredictable.",
                  triggerMode: TooltipTriggerMode.tap,
                  showDuration: const Duration(seconds: 4),
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  textStyle: const TextStyle(color: Colors.white),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.help_outline,
                    size: 18,
                    // Dim icon if disabled
                    color: isEnabled
                        ? Colors.grey
                        : Colors.grey.withOpacity(0.3),
                  ),
                ),
              ],
            ),
            Text(
              isEnabled ? _temperature.toStringAsFixed(1) : "N/A",
              style: TextStyle(color: isEnabled ? Colors.black : Colors.grey),
            ),
          ],
        ),
        // 2. Wrap Slider in AbsorbPointer/Opacity or just use onChanged: null
        Slider(
          value: _temperature,
          min: 0.1,
          max: 1.5,
          divisions: 14,
          label: _temperature.toStringAsFixed(1),
          activeColor: Colors.black,
          // Disable slider interaction by setting onChanged to null if disabled
          onChanged: isEnabled
              ? (val) => setState(() => _temperature = val)
              : null,
        ),
      ],
    );
  }

  Widget _buildOutputSection() {
    // === 1. IMAGE OUTPUT ===
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

    // === 2. AUDIO OUTPUT (Kokoro & CosyVoice & Melo) ===
    if (audioOutputBytes != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Audio Output:",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.download),
                tooltip: "Save Audio",
                onPressed: _saveGeneratedAudio,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.black,
                  radius: 25,
                  child: IconButton(
                    icon: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 30,
                    ),
                    onPressed: () async {
                      try {
                        // Write bytes to temp file to play
                        final tempDir = await getTemporaryDirectory();
                        final file = File(
                          '${tempDir.path}/temp_generated_audio.wav',
                        );
                        await file.writeAsBytes(audioOutputBytes!);

                        await _audioPlayer.stop(); // Stop previous
                        await _audioPlayer.play(DeviceFileSource(file.path));
                      } catch (e) {
                        _showSnack("Error playing audio: $e", isError: true);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        output ?? "Audio Generated Successfully",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${(audioOutputBytes!.length / 1024).toStringAsFixed(1)} KB • WAV",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.stop_circle_outlined, size: 30),
                  onPressed: () async => await _audioPlayer.stop(),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // === 3. TEXT OUTPUT (Default) ===
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
            Row(
              children: [
                if (!isLoading)
                  TextButton.icon(
                    onPressed: _regenerateResponse,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.orange[800],
                    ),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text("Regenerate"),
                  ),

                const SizedBox(width: 8),

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
}
