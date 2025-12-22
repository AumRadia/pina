// lib/utils/submission_handler.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:pina/models/melo_config.dart'; // <--- NEW IMPORT
import 'package:pina/services/lm_studio_service.dart';
import 'package:pina/services/audio_transcription_service.dart';
import 'package:pina/services/image_generation_service.dart';
import 'package:pina/models/assembly_config.dart';
import 'package:pina/models/local_whisper_config.dart';
import 'package:pina/models/image_generation_config.dart';
import 'package:pina/models/attached_file.dart';
import 'package:pina/models/kokoro_config.dart';
import 'package:pina/utils/transcript_formatter.dart';

// Simple class to hold the result
class SubmissionResult {
  final String content;
  final String modelName;
  final Map<String, dynamic> metaData;
  final List<Uint8List>? images;
  final bool isImage;
  final Uint8List? audioBytes;
  final bool isAudio;
  final List<dynamic>? errorLogs;

  SubmissionResult({
    required this.content,
    required this.modelName,
    required this.metaData,
    this.images,
    this.isImage = false,
    this.audioBytes,
    this.isAudio = false,
    this.errorLogs,
  });

  factory SubmissionResult.error(String error) {
    return SubmissionResult(
      content: "Error: $error",
      modelName: "error",
      metaData: {"error": error},
      errorLogs: [],
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
    required KokoroConfig kokoroConfig,
    required MeloConfig meloConfig, // <--- NEW PARAMETER
    required AudioTranscriptionService audioService,
    required ImageGenerationService imageService,
    required LmStudioService aiService,
    required double temperature,
  }) async {
    try {
      String finalPrompt = promptText;
      List<String> selectedFeatures = [];

      // Logic to prevent metadata pollution in text intended for TTS models
      if (provider != LlmProvider.kokoro &&
          provider != LlmProvider.cosyVoice &&
          provider != LlmProvider.meloTts) {
        activeOptions.forEach((key, isChecked) {
          if (isChecked) selectedFeatures.add(key);
        });

        if (selectedFeatures.isNotEmpty) {
          finalPrompt += "\n\n[Active Options: ${selectedFeatures.join(', ')}]";
        }
      }

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
        );
      }
      // === CASE E: STANDARD LLMs & TTS (Kokoro, CosyVoice, Melo) ===
      else {
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
          audioFile: audioFile,
          assemblyConfig: assemblyConfig,
          whisperConfig: whisperConfig,
          kokoroConfig: kokoroConfig,
          meloConfig: meloConfig, // <--- PASS MELO CONFIG TO SERVICE
          temperature: temperature,
        );

        bool isAudioOutput = aiResponse['isAudio'] == true;
        Uint8List? audioBytes = aiResponse['audioBytes'];

        return SubmissionResult(
          content: aiResponse['content'] ?? aiResponse.toString(),
          modelName: aiResponse['model'] ?? provider.name,
          metaData: aiResponse, // This Mixed map will be saved as outputParams
          errorLogs: aiResponse['errorLogs'] ?? [],
          isAudio: isAudioOutput,
          audioBytes: audioBytes,
        );
      }
    } catch (e) {
      return SubmissionResult.error(e.toString());
    }
  }
}
