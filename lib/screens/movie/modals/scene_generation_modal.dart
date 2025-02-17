import 'package:flutter/material.dart';

class SceneGenerationModal extends StatelessWidget {
  final String originalIdea;
  final String continuationIdea;
  final Stream<String> progressStream;
  final VoidCallback onRetry;

  const SceneGenerationModal({
    super.key,
    required this.originalIdea,
    required this.continuationIdea,
    required this.progressStream,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Generating New Scenes'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StreamBuilder<String>(
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
                        'Scene Generation Failed',
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                              onRetry();
                            },
                            icon: const Icon(Icons.refresh),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                            ),
                            label: const Text('Try Again'),
                          ),
                        ],
                      ),
                    ],
                  );
                }
                
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const LinearProgressIndicator(),
                    const SizedBox(height: 24),
                    Text(
                      'Original Movie Idea:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      originalIdea,
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Continuation:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      continuationIdea,
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Column(
                        children: [
                          Text(
                            snapshot.data ?? 'Initializing...',
                            style: Theme.of(context).textTheme.bodyLarge,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          const CircularProgressIndicator(),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
