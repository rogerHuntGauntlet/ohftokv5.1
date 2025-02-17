import 'package:flutter/material.dart';
import '../../../widgets/tutorial/tutorial_overlay.dart';

/// A button widget that handles movie creation through voice recording.
/// Includes tutorial overlay and gesture detection for starting/stopping recording.
class CreateMovieButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return TutorialOverlay(
      featureKey: 'create_movie',
      title: 'Create Your Movie',
      description: 'Double tap to start recording your movie idea!',
      targetPosition: getTargetPosition(),
      targetSize: const Size(48, 48),
      child: GestureDetector(
        onDoubleTap: (isProcessing || !isSpeechInitialized) ? null : onTap,
        child: IconButton(
          key: buttonKey,
          onPressed: isProcessing ? null : onInstructionsTap,
          icon: Icon(isListening ? Icons.mic : Icons.add_to_queue),
          color: isListening ? Colors.red : null,
        ),
      ),
    );
  }
} 