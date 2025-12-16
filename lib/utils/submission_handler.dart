import 'dart:io';
import 'dart:typed_data';
import 'package:pina/services/lm_studio_service.dart';
import 'package:pina/services/audio_transcription_service.dart';
import 'package:pina/services/image_generation_service.dart';
import 'package:pina/models/assembly_config.dart';
import 'package:pina/models/local_whisper_config.dart';
import 'package:pina/models/image_generation_config.dart';
import 'package:pina/utils/transcript_formatter.dart';

// Simple class to hold the result so we don't return messy Maps
class SubmissionResult {
  final String content;
  final String modelName;
  final Map<String, dynamic> metaData;
  final List<Uint8List>? images;
  final bool isImage;

  SubmissionResult({
    required this.content,
    required this.modelName,
    required this.metaData,
    this.images,
    this.isImage = false,
  });

  factory SubmissionResult.error(String error) {
    return SubmissionResult(
      content: "Error: $error",
      modelName: "error",
      metaData: {"error": error},
    );
  }
}

class SubmissionHandler {
  static Future<SubmissionResult> processRequest({
    required LlmProvider provider,
    required String promptText,
    required File? audioFile,
    required bool hasImages,
    required Map<String, bool> activeOptions, // <--- 1. NEW PARAMETER
    required AssemblyConfig assemblyConfig,
    required LocalWhisperConfig whisperConfig,
    required ImageGenerationConfig imageConfig,
    // Inject services to keep them stateless
    required AudioTranscriptionService audioService,
    required ImageGenerationService imageService,
    required LmStudioService aiService,
  }) async {
    try {
      // --- 2. BUILD THE MODIFIED PROMPT ---
      // We process the checkbox map and append 'true' values to the prompt
      String finalPrompt = promptText;
      List<String> selectedFeatures = [];

      activeOptions.forEach((key, isChecked) {
        if (isChecked) {
          selectedFeatures.add(key);
        }
      });

      if (selectedFeatures.isNotEmpty) {
        // Appends options like: "\n\n[Active Options: Simple Mode, Deep Search]"
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
          );
        } else {
          return SubmissionResult.error(
            resultData?['error'] ?? "Unknown Error",
          );
        }
      }
      // === CASE B: LOCAL WHISPER ===
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
            modelName: "Whisper-Local",
            metaData: {"status": "completed"},
          );
        } else {
          return SubmissionResult.error(
            "${result['error']} ${result['details'] ?? ''}",
          );
        }
      }
      // === CASE C: STABLE DIFFUSION (IMAGE) ===
      else if (provider == LlmProvider.stableDiffusion) {
        // Use finalPrompt here so image gen respects options too
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
        );
      }
      // === CASE D: STANDARD LLMs ===
      else {
        // Use finalPrompt here for the LLM
        final aiResponse = await aiService.generateResponse(
          finalPrompt,
          provider,
          hasImages: hasImages,
        );
        return SubmissionResult(
          content: aiResponse['content'] ?? aiResponse.toString(),
          modelName: aiResponse['model'] ?? provider.name,
          metaData: aiResponse,
        );
      }
    } catch (e) {
      return SubmissionResult.error(e.toString());
    }
  }
}
