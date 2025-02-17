import '../../models/director.dart';
import '../../models/training_scene.dart';
import 'gemini_service.dart';

class TrainingFeedbackService {
  Future<String> getFeedback(String videoPath, Director director, TrainingScene scene) async {
    final prompt = _constructPrompt(director, scene);
    return await GeminiService.analyzeVideo(prompt, videoPath);
  }

  String _constructPrompt(Director director, TrainingScene scene) {
    return '''
You are an expert film critic and director, analyzing a scene attempt based on ${director.name}'s directorial style.

Scene Context:
${scene.description}

Key Elements to Consider:
1. Visual Style:
   - Camera angles and movements
   - Lighting and color palette
   - Composition and framing

2. Technical Elements:
   - Pacing and timing
   - Scene transitions
   - Sound design and music (if present)

3. Directorial Choices:
   - How well does it match ${director.name}'s signature style?
   - Scene blocking and actor positioning
   - Emotional tone and atmosphere

4. Areas for Improvement:
   - Specific technical suggestions
   - Creative enhancements
   - Style alignment with ${director.name}

Please provide detailed, constructive feedback on how well the scene attempt captures ${director.name}'s directorial style and specific suggestions for improvement.
''';
  }

  Map<String, dynamic> _analyzeVideoElements(String videoPath) {
    // TODO: Implement actual video analysis
    return {
      'visualElements': {
        'cameraMovements': ['pan', 'tilt'],
        'lighting': 'natural',
        'composition': 'rule of thirds'
      },
      'technicalElements': {
        'pacing': 'moderate',
        'transitions': ['cut', 'fade'],
        'audioQuality': 'clear'
      }
    };
  }
} 