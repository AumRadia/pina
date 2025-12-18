//
//
import 'dart:io';
import 'dart:typed_data';
import 'package:pina/services/lm_studio_service.dart';
import 'package:pina/services/audio_transcription_service.dart';
import 'package:pina/services/image_generation_service.dart';
import 'package:pina/models/assembly_config.dart';
import 'package:pina/models/local_whisper_config.dart';
import 'package:pina/models/image_generation_config.dart';
import 'package:pina/models/attached_file.dart';
import 'package:pina/utils/transcript_formatter.dart';

// Simple class to hold the result so we don't return messy Maps
class SubmissionResult {
  final String content;
  final String modelName;
  final Map<String, dynamic> metaData;
  final List<Uint8List>? images;
  final bool isImage;
  // --- NEW FIELD ---
  final List<dynamic>? errorLogs;

  SubmissionResult({
    required this.content,
    required this.modelName,
    required this.metaData,
    this.images,
    this.isImage = false,
    this.errorLogs, // Add to constructor
  });

  factory SubmissionResult.error(String error) {
    return SubmissionResult(
      content: "Error: $error",
      modelName: "error",
      metaData: {"error": error},
      errorLogs: [], // Default empty logs on critical error
    );
  }
}

class SubmissionHandler {
  static Future<SubmissionResult> processRequest({
    required LlmProvider provider,
    required String promptText,
    required File? audioFile,
    required bool hasImages,
    required List<AttachedFile> attachedFiles,
    required Map<String, bool> activeOptions,
    required AssemblyConfig assemblyConfig,
    required LocalWhisperConfig whisperConfig,
    required ImageGenerationConfig imageConfig,
    required AudioTranscriptionService audioService,
    required ImageGenerationService imageService,
    required LmStudioService aiService,
    required double temperature,
  }) async {
    try {
      // --- 2. BUILD THE MODIFIED PROMPT ---
      // Process checkbox map and append 'true' values to the prompt
      String finalPrompt = promptText;
      List<String> selectedFeatures = [];

      activeOptions.forEach((key, isChecked) {
        if (isChecked) {
          selectedFeatures.add(key);
        }
      });

      if (selectedFeatures.isNotEmpty) {
        // Appends options like: "\n\n[Active Options: Input Type: Text, Output Type: Audio]"
        finalPrompt += "\n\n[Active Options: ${selectedFeatures.join(', ')}]";
      }
      // ------------------------------------

      // === CASE A: ASSEMBLY AI (CLOUD) ===
      if (provider == LlmProvider.assemblyAi) {
        if (audioFile == null)
          return SubmissionResult.error("No audio file provided");

        final resultData = await audioService.transcribeAudio(
          audioFile,
          assemblyConfig,
        );

        if (resultData != null && !resultData.containsKey('error')) {
          return SubmissionResult(
            content: TranscriptFormatter.formatTranscriptOutput(resultData),
            modelName: "AssemblyAI-STT",
            metaData: resultData,
            errorLogs: [], // No errors on success
          );
        } else {
          // Return the specific error log
          return SubmissionResult(
            content: "Error",
            modelName: "AssemblyAI",
            metaData: {},
            errorLogs: [
              {
                'provider': 'AssemblyAI',
                'error': resultData?['error'] ?? "Unknown Error",
              },
            ],
          );
        }
      }
      // === CASE B: LOCAL WHISPER (CLI) ===
      else if (provider == LlmProvider.localWhisper) {
        if (audioFile == null)
          return SubmissionResult.error("No audio file provided");

        final result = await audioService.transcribeWithLocalWhisper(
          audioFile,
          whisperConfig,
        );

        if (result.containsKey('text')) {
          return SubmissionResult(
            content: result['text'],
            modelName: "Whisper-Local-CLI",
            metaData: {"status": "completed"},
            errorLogs: [],
          );
        } else {
          return SubmissionResult(
            content: "Error",
            modelName: "Whisper-Local-CLI",
            metaData: {},
            errorLogs: [
              {
                'provider': 'LocalWhisper',
                'error': "${result['error']} ${result['details'] ?? ''}",
              },
            ],
          );
        }
      }
      // === CASE C: DISTIL WHISPER (LM Studio API) ===
      else if (provider == LlmProvider.distilWhisper) {
        if (audioFile == null)
          return SubmissionResult.error("No audio file provided");

        // We use aiService here because logic is encapsulated in LmStudioService
        final aiResponse = await aiService.generateResponse(
          finalPrompt,
          provider,
          audioFile: audioFile,
          whisperConfig: whisperConfig,
          assemblyConfig: assemblyConfig,
        );

        return SubmissionResult(
          content: aiResponse['content'] ?? "No transcription returned",
          modelName: aiResponse['model'] ?? "Distil-Whisper",
          metaData: aiResponse,
          errorLogs: aiResponse['errorLogs'] ?? [],
        );
      }
      // === CASE D: STABLE DIFFUSION (IMAGE) ===
      else if (provider == LlmProvider.stableDiffusion) {
        final images = await imageService.generateImage(
          finalPrompt,
          imageConfig,
        );
        return SubmissionResult(
          content: "Generated ${images.length} Images",
          modelName: "Stable-Diffusion-XL",
          metaData: {"count": images.length},
          images: images,
          isImage: true,
          errorLogs: [], // Image service handling could be expanded later
        );
      }
      // === CASE E: STANDARD LLMs (Including Qwen/Gemma & Fallbacks) ===
      else {
        // Prepare image files list for Vision models (like Gemma 4B)
        List<File> imageFiles = [];
        if (hasImages) {
          imageFiles = attachedFiles
              .where(
                (f) => [
                  'jpg',
                  'png',
                  'jpeg',
                  'webp',
                  'bmp',
                ].contains(f.extension.toLowerCase()),
              )
              .map((f) => File(f.path))
              .toList();
        }

        final aiResponse = await aiService.generateResponse(
          finalPrompt,
          provider,
          hasImages: hasImages,
          imageFiles: imageFiles,
          // PASS AUDIO DATA TO SUPPORT AUTO-SWITCHING
          audioFile: audioFile,
          assemblyConfig: assemblyConfig,
          whisperConfig: whisperConfig,

          temperature: temperature,
        );

        return SubmissionResult(
          content: aiResponse['content'] ?? aiResponse.toString(),
          modelName: aiResponse['model'] ?? provider.name,
          metaData: aiResponse,
          // --- EXTRACT LOGS FROM SERVICE ---
          errorLogs: aiResponse['errorLogs'] ?? [],
        );
      }
    } catch (e) {
      return SubmissionResult.error(e.toString());
    }
  }
}
