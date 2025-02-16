import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/movie/movie_service.dart';
import 'movie_scenes_screen.dart';

class SceneGenerationModal extends StatelessWidget {
  final String originalIdea;
  final String continuationIdea;
  final Stream<String> progressStream;

  const SceneGenerationModal({
    super.key,
    required this.originalIdea,
    required this.continuationIdea,
    required this.progressStream,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Generating New Scene',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
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
                        snapshot.error.toString(),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();  // Close the modal
                            },
                            child: const Text('Close'),
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
                          if (snapshot.connectionState == ConnectionState.done)
                            Column(
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 48,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Scene Generated Successfully!',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('Close'),
                                ),
                              ],
                            )
                          else
                            Column(
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

class AdditionalScenesGenerationModal extends StatelessWidget {
  final String originalIdea;
  final String continuationIdea;
  final Stream<String> progressStream;

  const AdditionalScenesGenerationModal({
    super.key,
    required this.originalIdea,
    required this.continuationIdea,
    required this.progressStream,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Generating New Scenes'),
      content: Column(
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
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ],
                );
              }
              
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    snapshot.data ?? 'Initializing...',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  const CircularProgressIndicator(),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class SceneGenerationLoadingScreen extends StatefulWidget {
  final String movieIdea;

  const SceneGenerationLoadingScreen({
    super.key,
    required this.movieIdea,
  });

  @override
  State<SceneGenerationLoadingScreen> createState() => _SceneGenerationLoadingScreenState();
}

class _SceneGenerationLoadingScreenState extends State<SceneGenerationLoadingScreen> {
  String _currentStep = 'Initializing scene generation';
  final List<String> _completedSteps = [];

  @override
  void initState() {
    super.initState();
    _startGeneration();
  }

  Future<void> _startGeneration() async {
    try {
      final movieService = Provider.of<MovieService>(context, listen: false);
      
      // Update progress through the steps
      await Future.delayed(const Duration(seconds: 2));
      setState(() {
        _completedSteps.add(_currentStep);
        _currentStep = 'Analyzing your movie idea';
      });

      await Future.delayed(const Duration(seconds: 4));
      setState(() {
        _completedSteps.add(_currentStep);
        _currentStep = 'Creating scene descriptions';
      });

      // Generate the scenes
      final scenes = await movieService.generateMovieScenes(widget.movieIdea);

      setState(() {
        _completedSteps.add(_currentStep);
        _currentStep = 'Finalizing your movie';
      });

      await Future.delayed(const Duration(milliseconds: 3000));
      
      if (!mounted) return;

      // Navigate to the scenes screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => MovieScenesScreen(
            movieIdea: widget.movieIdea,
            scenes: scenes,
            movieId: scenes[0]['movieId'],
            movieTitle: null,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 32),
              const Text(
                'Creating Your Movie',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Based on your idea:',
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.movieIdea,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 32),
              _buildProgressSteps(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressSteps() {
    const steps = [
      'Initializing scene generation',
      'Analyzing your movie idea',
      'Creating scene descriptions',
      'Finalizing your movie',
    ];

    return Column(
      children: steps.map((step) {
        final isCompleted = _completedSteps.contains(step);
        final isActive = step == _currentStep;

        return Column(
          children: [
            _buildProgressStep(
              step,
              isActive: isActive,
              isCompleted: isCompleted,
            ),
            if (step != steps.last) const SizedBox(height: 16),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildProgressStep(String title, {required bool isActive, required bool isCompleted}) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted
                ? Colors.green
                : isActive
                    ? Colors.blue
                    : Colors.grey[300],
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : isActive
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : null,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            color: isActive || isCompleted ? Colors.black : Colors.grey,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
} 