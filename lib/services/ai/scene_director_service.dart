import 'package:dart_openai/dart_openai.dart';
import '../../config/env_config.dart';
import 'dart:convert';

class SceneReconception {
  final String sceneDescription;
  final String directorNotes;
  final String directorName;

  SceneReconception({
    required this.sceneDescription,
    required this.directorNotes,
    required this.directorName,
  });
}

class SceneDirectorService {
  SceneDirectorService() {
    OpenAI.apiKey = EnvConfig.openAiKey;
  }

  Future<SceneReconception> reconceiveScene({
    required String sceneText,
    required String directorName,
    required String directorStyle,
  }) async {
    final prompt = '''As ${directorName}, known for ${directorStyle}, reimagine and enhance the following scene.
    Return your response in the following JSON format:
    {
      "reimaginedScene": "Your reimagined scene description here",
      "directorNotes": "Your detailed directorial notes here"
    }
    
    Original Scene:
    ${sceneText}
    
    Guidelines:
    1. The reimaginedScene should maintain core story elements while incorporating your signature style
    2. The directorNotes should include specific details about camera work, lighting, blocking, and your signature techniques
    3. Keep the scene description concise but vivid
    4. Make the directorial notes practical and specific
    5. Ensure your response is valid JSON
    
    Remember to maintain proper JSON escaping for quotes and special characters.''';

    try {
      final chatCompletion = await OpenAI.instance.chat.create(
        model: 'gpt-4',
        messages: [
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.system,
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(
                'You are an expert in formatting responses as valid JSON. Always ensure your responses can be parsed as JSON.',
              ),
            ],
          ),
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.user,
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(
                prompt,
              ),
            ],
          ),
        ],
        temperature: 0.7,
      );

      if (chatCompletion.choices.isEmpty) {
        throw Exception('No response from OpenAI');
      }

      final response = chatCompletion.choices.first.message;
      if (response.content == null || response.content!.isEmpty) {
        throw Exception('Empty response from OpenAI');
      }

      final messageContent = response.content!.first;
      if (messageContent.text == null) {
        throw Exception('No text content in OpenAI response');
      }

      try {
        // Try to parse as JSON first
        final jsonResponse = json.decode(messageContent.text!) as Map<String, dynamic>;
        return SceneReconception(
          sceneDescription: jsonResponse['reimaginedScene'] as String? ?? '',
          directorNotes: jsonResponse['directorNotes'] as String? ?? '',
          directorName: directorName,
        );
      } catch (e) {
        // Fallback to text parsing if JSON fails
        return _parseResponse(messageContent.text!, directorName);
      }
    } catch (e) {
      throw Exception('Failed to get director\'s vision: $e');
    }
  }

  SceneReconception _parseResponse(String content, String directorName) {
    String sceneDescription = '';
    String directorNotes = '';
    
    final sections = content.split(RegExp(r'\n\s*\n'));
    
    for (final section in sections) {
      if (section.toLowerCase().contains('scene description') || 
          section.toLowerCase().contains('reimagined scene')) {
        sceneDescription = section.replaceFirst(
          RegExp(r'(Scene Description:|Reimagined Scene:)', caseSensitive: false),
          '',
        ).trim();
      } else if (section.toLowerCase().contains('director') || 
                 section.toLowerCase().contains('notes') ||
                 section.toLowerCase().contains('how to shoot')) {
        directorNotes = section.replaceFirst(
          RegExp(r'(Directors Notes:|Directorial Notes:|Notes:)', caseSensitive: false),
          '',
        ).trim();
      }
    }

    // If we couldn't find clear sections, make a best effort split
    if (sceneDescription.isEmpty || directorNotes.isEmpty) {
      final midPoint = content.length ~/ 2;
      sceneDescription = content.substring(0, midPoint).trim();
      directorNotes = content.substring(midPoint).trim();
    }

    return SceneReconception(
      sceneDescription: sceneDescription,
      directorNotes: directorNotes,
      directorName: directorName,
    );
  }
} 