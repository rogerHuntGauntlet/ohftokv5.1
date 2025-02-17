import 'package:google_generative_ai/google_generative_ai.dart';
import '../../../config/env_config.dart';

class GeminiService {
  static final GenerativeModel _model = GenerativeModel(
    model: 'gemini-pro',
    apiKey: EnvConfig.geminiApiKey,
  );

  static Future<String> generateResponse(String prompt) async {
    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      return response.text ?? 'No response generated';
    } catch (e) {
      print('Error generating Gemini response: $e');
      return 'Error: Failed to generate response';
    }
  }

  static Future<String> analyzeVideo(String prompt, String videoPath) async {
    try {
      // Note: Currently using text-only model as video analysis requires gemini-pro-vision
      // which is not yet available in the Flutter SDK
      final content = [
        Content.text(
          'Analyzing video at path: $videoPath\n\n$prompt'
        )
      ];
      final response = await _model.generateContent(content);
      return response.text ?? 'No analysis generated';
    } catch (e) {
      print('Error analyzing video with Gemini: $e');
      return 'Error: Failed to analyze video';
    }
  }
} 