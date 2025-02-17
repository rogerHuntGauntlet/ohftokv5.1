import 'package:flutter/material.dart';
import '../../../models/video_generation_progress.dart';

class VideoGenerationModal extends StatelessWidget {
  final String sceneText;
  final String movieId;
  final String sceneId;
  final Stream<VideoGenerationProgress> progressStream;
  final Function(String, String) onVideoReady;

  const VideoGenerationModal({
    super.key,
    required this.sceneText,
    required this.movieId,
    required this.sceneId,
    required this.progressStream,
    required this.onVideoReady,
  });

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: AlertDialog(
        title: const Text('Generating Video'),
        content: StreamBuilder<VideoGenerationProgress>(
          stream: progressStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Video Generation Failed',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Error Details:',
                          style: TextStyle(
                            color: Colors.red[900],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          snapshot.error.toString(),
                          style: TextStyle(color: Colors.red[900]),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              );
            }

            final progress = snapshot.data;
            final percentage = progress?.percentage ?? 0.0;
            final stage = progress?.stage ?? 'Initializing...';

            return SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(value: percentage),
                  const SizedBox(height: 24),
                  Text(
                    'Scene Text:',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    sceneText,
                    style: const TextStyle(fontStyle: FontStyle.italic),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    stage,
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  if (percentage < 1.0)
                    const CircularProgressIndicator()
                  else
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 48,
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
