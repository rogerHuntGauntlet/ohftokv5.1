import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  static String get openAiKey => dotenv.env['OPENAI_API_KEY'] ?? '';
  static String get replicateApiKey => dotenv.env['REPLICATE_API_KEY'] ?? '';
  static String get firebaseApiKey => dotenv.env['FIREBASE_API_KEY'] ?? '';
  static String get geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
} 