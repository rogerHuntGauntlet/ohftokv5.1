import 'package:speech_to_text/speech_to_text.dart' as stt;

class SpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;

  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _isInitialized = await _speech.initialize(
        onError: (error) => print('Speech Error: $error'),
        onStatus: (status) => print('Speech Status: $status'),
      );
      return _isInitialized;
    } catch (e) {
      print('Speech initialization error: $e');
      return false;
    }
  }

  Future<void> startListening({
    required Function(String) onResult,
    required Function(bool) onListeningChanged,
  }) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return;
    }

    try {
      onListeningChanged(true);
      await _speech.listen(
        onResult: (result) {
          onResult(result.recognizedWords);
        },
        cancelOnError: true,
      );
    } catch (e) {
      print('Error starting speech recognition: $e');
      onListeningChanged(false);
    }
  }

  Future<void> stopListening() async {
    try {
      await _speech.stop();
    } catch (e) {
      print('Error stopping speech recognition: $e');
    }
  }

  bool get isListening => _speech.isListening;

  void dispose() {
    _speech.cancel();
  }
} 