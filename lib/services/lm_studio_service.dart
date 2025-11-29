import 'package:langchain/langchain.dart';
import 'package:langchain_openai/langchain_openai.dart';
import 'package:pina/screens/constants.dart';

class LmStudioService {
  late ChatOpenAI _model;

  // --- MEMORY STORE ---
  final List<ChatMessage> _history = [];

  LmStudioService() {
    _model = ChatOpenAI(
      apiKey: 'not-needed',
      baseUrl: '${ApiConstants.lmStudioUrl}/v1',
      defaultOptions: const ChatOpenAIOptions(
        model: 'google/gemma-3-4b',
        temperature: 0.7,
      ),
    );

    // System messages still accept simple Strings
    _history.add(ChatMessage.system('You are a helpful AI assistant.'));
  }

  Future<Map<String, dynamic>> generateResponse(String userPrompt) async {
    try {
      // FIX 1: Use .humanText() instead of .human()
      // This handles the conversion from String to ChatMessageContent automatically
      _history.add(ChatMessage.humanText(userPrompt));

      // 2. Send the ENTIRE history to the model
      final response = await _model.invoke(PromptValue.chat(_history));

      // 3. Extract the text from the AI's response
      final aiText = response.output.content;

      // 4. Add the AI's response to our history list
      // Note: .ai() still accepts a simple String in most versions,
      // but if you get an error here too, change it to .ai(aiText)
      _history.add(ChatMessage.ai(aiText));

      return {
        "content": aiText,
        "model": "google/gemma-3-4b",
        "status": "success",
      };
    } catch (e) {
      return {"content": "Error: $e", "model": "error", "status": "error"};
    }
  }

  void clearMemory() {
    _history.clear();
    _history.add(ChatMessage.system('You are a helpful AI assistant.'));
  }
}
