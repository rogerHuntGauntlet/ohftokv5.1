import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_to_text.dart' show ListenMode;
import 'package:permission_handler/permission_handler.dart';

/// Helper class for managing speech recognition functionality.
/// Handles speech initialization, recording, and processing of movie ideas.
class SpeechHelper {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isSpeechInitialized = false;
  
  bool get isInitialized => _isSpeechInitialized;
  stt.SpeechToText get speech => _speech;

  /// Check and request microphone permissions
  Future<bool> checkPermissions(BuildContext context) async {
    final status = await Permission.microphone.status;
    if (status.isGranted) {
      return await initializeSpeech(context);
    } else {
      final result = await Permission.microphone.request();
      if (result.isGranted) {
        return await initializeSpeech(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission is required for speech recognition'),
            duration: Duration(seconds: 3),
          ),
        );
        return false;
      }
    }
  }

  /// Initialize speech recognition
  Future<bool> initializeSpeech(BuildContext context) async {
    try {
      bool available = await _speech.initialize(
        onStatus: (status) {
          print('Speech status: $status');
        },
        onError: (error) {
          print('Speech Error: $error');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $error')),
          );
        },
      );
      _isSpeechInitialized = available;
      if (!available) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speech recognition not available on this device')),
        );
      }
      return available;
    } catch (e) {
      print('Speech initialization error: $e');
      _isSpeechInitialized = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to initialize speech recognition')),
      );
      return false;
    }
  }

  /// Start listening for speech input
  Future<void> startListening({
    required Function(String) onResult,
    required Function(dynamic) onError,
  }) async {
    try {
      await _speech.listen(
        onResult: (result) {
          final text = result.recognizedWords;
          onResult(text);
        },
        listenMode: ListenMode.dictation,
        cancelOnError: true,
        partialResults: true,
      );
    } catch (e) {
      print('Listen error: $e');
      onError(e);
    }
  }

  /// Stop listening for speech input
  Future<void> stopListening() async {
    await _speech.stop();
  }

  /// Process the recorded speech into a movie idea
  Future<void> processMovieIdea(String speech) async {
    // TODO: Implement movie idea processing
  }
} 