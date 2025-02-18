import 'package:flutter/material.dart';
import '../../../widgets/tutorial/tutorial_overlay.dart';
import 'dart:async';
import 'dart:developer' as developer;

/// A button widget that handles movie creation through voice recording.
/// Includes tutorial overlay and gesture detection for starting/stopping recording.
class CreateMovieButton extends StatefulWidget {
  final VoidCallback onTap;
  final VoidCallback onInstructionsTap;
  final bool isListening;
  final bool isProcessing;
  final bool isSpeechInitialized;
  final GlobalKey buttonKey;
  final Offset Function() getTargetPosition;

  const CreateMovieButton({
    Key? key,
    required this.onTap,
    required this.onInstructionsTap,
    required this.isListening,
    required this.isProcessing,
    required this.isSpeechInitialized,
    required this.buttonKey,
    required this.getTargetPosition,
  }) : super(key: key);

  @override
  State<CreateMovieButton> createState() => _CreateMovieButtonState();
}

class _CreateMovieButtonState extends State<CreateMovieButton> {
  Timer? _timer;
  int _tapCount = 0;

  void _handleTap() {
    developer.log('Tap detected');
    _tapCount++;
    
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 500), () {
      if (_tapCount == 1) {
        widget.onInstructionsTap();
      }
      _tapCount = 0;
    });

    if (_tapCount == 2) {
      _timer?.cancel();
      _tapCount = 0;
      if (!widget.isProcessing && widget.isSpeechInitialized) {
        widget.onTap();
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TutorialOverlay(
      featureKey: 'create_movie',
      title: 'Create Your Movie',
      description: 'Double tap to start recording your movie idea!',
      targetPosition: widget.getTargetPosition(),
      targetSize: const Size(48, 48),
      child: IconButton(
        key: widget.buttonKey,
        onPressed: _handleTap,
        icon: Icon(
          widget.isListening ? Icons.mic : Icons.add_to_queue,
          color: widget.isListening ? Colors.red : null,
        ),
      ),
    );
  }
} 