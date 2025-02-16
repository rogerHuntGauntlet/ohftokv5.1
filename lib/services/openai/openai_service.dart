import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'dart:async';

class OpenAIService {
  final String _baseUrl = 'https://api.openai.com/v1/chat/completions';
  late final String _apiKey;

  OpenAIService() {
    _apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
  }

  Future<String> updateSceneText({
    required String originalScene,
    required String notes,
    required String movieIdea,
    required StreamController<String> progressController,
  }) async {
    try {
      // Step 1: Analyzing
      progressController.add('analyzing');
      await Future.delayed(const Duration(seconds: 1));

      // Step 2: Processing
      progressController.add('processing');
      
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: json.encode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {
              'role': 'system',
              'content': 'You are a creative movie script writer. Your task is to update a movie scene based on the provided notes while maintaining consistency with the overall movie idea.'
            },
            {
              'role': 'user',
              'content': '''Movie Idea: $movieIdea

Original Scene: $originalScene

Notes for changes: $notes

Please rewrite the scene incorporating these notes. Keep the response focused and only return the new scene text.'''
            }
          ],
          'temperature': 0.7,
          'max_tokens': 500,
        }),
      );

      if (response.statusCode != 200) {
        throw 'Failed to update scene: ${response.body}';
      }

      // Step 3: Finalizing
      progressController.add('finalizing');
      await Future.delayed(const Duration(milliseconds: 500));

      final data = json.decode(response.body);
      return data['choices'][0]['message']['content'].trim();
    } catch (e) {
      throw 'Failed to update scene: $e';
    }
  }

  Future<List<String>> generateSingleScene({
    required String movieIdea,
    required List<Map<String, dynamic>> existingScenes,
    required String continuationIdea,
    required StreamController<String> progressController,
  }) async {
    try {
      // Step 1: Analyzing
      progressController.add('Analyzing existing scenes...');
      await Future.delayed(const Duration(seconds: 1));

      // Format existing scenes for the prompt
      final scenesText = existingScenes.map((scene) => 
        'Scene ${scene['id']}: ${scene['text']}'
      ).join('\n');

      // Step 2: Processing
      progressController.add('Generating new scenes...');
      
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: json.encode({
          'model': 'gpt-4',
          'messages': [
            {
              'role': 'system',
              'content': '''You are a creative movie script writer. Your task is to generate new scenes that continue the story while maintaining consistency with the existing scenes and overall movie idea.

IMPORTANT FORMATTING INSTRUCTIONS:
1. ALWAYS start with scene number 1, regardless of existing scenes
2. Each scene must start with a number followed by a period (e.g., "1.", "2.", etc.)
3. Write ONLY the scene description - no commentary about transitions or story elements
4. Each scene must be on a new line
5. Do not include any additional text, headers, or explanations
6. Format EXACTLY like this example:
1. A man walks into the garden, his footsteps crunching on the gravel path.
2. He picks up a red rose, carefully avoiding the thorns.
3. The rose begins to glow with an otherworldly light.'''
            },
            {
              'role': 'user',
              'content': '''Movie Idea: $movieIdea

Existing Scenes:
$scenesText

Continuation Idea: $continuationIdea

Write new scenes that continue the story based on the continuation idea. Remember to start with scene 1 and follow the formatting instructions exactly.'''
            }
          ],
          'temperature': 0.7,
          'max_tokens': 1000,
        }),
      );

      if (response.statusCode != 200) {
        throw 'Failed to generate scene: ${response.body}';
      }

      // Step 3: Finalizing
      progressController.add('Finalizing new scenes...');
      await Future.delayed(const Duration(milliseconds: 500));

      final data = json.decode(response.body);
      final content = data['choices'][0]['message']['content'].trim();

      // Debug logging
      print('RAW OPENAI RESPONSE:');
      print(content);
      print('------------------------');

      // First, clean up the content to ensure proper line breaks
      final cleanContent = content
          .replaceAll(RegExp(r'\r\n|\r'), '\n')  // Normalize line endings
          .replaceAll(RegExp(r'\n\s*\n'), '\n')  // Remove multiple blank lines
          .trim();

      // Split into scenes and process each one
      final List<String> rawScenes = cleanContent.split(RegExp(r'\n(?=\d+\.)'));
      
      // Process each scene to remove the number and clean up
      final List<String> scenes = rawScenes
          .map((String scene) => scene.trim())
          .where((String scene) => scene.isNotEmpty)
          .map((String scene) {
            // Remove the scene number and any leading/trailing whitespace
            final withoutNumber = scene.replaceFirst(RegExp(r'^\d+\.\s*'), '').trim();
            return withoutNumber;
          })
          .where((String scene) => scene.isNotEmpty)
          .toList();

      // Debug logging
      print('PARSED SCENES:');
      for (var i = 0; i < scenes.length; i++) {
        print('Scene ${i + 1}: ${scenes[i]}');
      }
      print('Total scenes: ${scenes.length}');
      print('------------------------');

      if (scenes.isEmpty) {
        throw 'No valid scenes were generated';
      }

      return scenes;
    } catch (e) {
      throw 'Failed to generate scenes: $e';
    }
  }
} 