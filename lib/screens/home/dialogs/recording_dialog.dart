import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_to_text.dart' show ListenMode;

/// A dialog that manages voice recording and movie idea display.
/// This dialog is shown when a user starts recording a new movie idea.
class RecordingDialog extends StatefulWidget {
  final stt.SpeechToText speech;
  final bool isListening;
  final String movieIdea;
  final VoidCallback onCancel;
  final VoidCallback onStopRecording;
  final VoidCallback onCreateMovie;

  const RecordingDialog({
    Key? key,
    required this.speech,
    required this.isListening,
    required this.movieIdea,
    required this.onCancel,
    required this.onStopRecording,
    required this.onCreateMovie,
  }) : super(key: key);

  @override
  State<RecordingDialog> createState() => _RecordingDialogState();
}

class _RecordingDialogState extends State<RecordingDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            widget.isListening ? Icons.mic : Icons.mic_off,
            color: widget.isListening ? Colors.red : Colors.grey,
          ),
          const SizedBox(width: 8),
          const Text('Recording Movie Idea'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Describe your movie idea:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Text(
              widget.movieIdea == 'Listening...' ? 'Speak now...' : widget.movieIdea,
              style: TextStyle(
                color: widget.movieIdea == 'Listening...' ? Colors.grey : Colors.black,
                fontStyle: widget.movieIdea == 'Listening...' ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
          if (widget.movieIdea != 'Listening...' && widget.movieIdea.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                'Tap Stop Recording when you\'re done speaking.',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: widget.onCancel,
          child: const Text('Cancel'),
        ),
        if (widget.isListening)
          ElevatedButton(
            onPressed: widget.onStopRecording,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Stop Recording'),
          ),
        if (!widget.isListening && widget.movieIdea.isNotEmpty)
          ElevatedButton(
            onPressed: widget.onCreateMovie,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
            child: const Text('Create Movie'),
          ),
      ],
    );
  }
} 