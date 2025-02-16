import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../../services/movie/movie_service.dart';
import 'movie_scenes_screen.dart';

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
      setState(() {
        _currentStep = 'Initializing scene generation';
      });

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

      if (scenes.isEmpty) {
        throw 'No scenes were generated. Please try again.';
      }

      setState(() {
        _completedSteps.add(_currentStep);
        _currentStep = 'Finalizing your movie';
      });

      await Future.delayed(const Duration(seconds: 2));
      
      if (!mounted) return;

      // Navigate to the scenes screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => MovieScenesScreen(
            movieIdea: widget.movieIdea,
            scenes: scenes,
            movieId: scenes.first['movieId'],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      // Show error dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                e.toString(),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Go back to previous screen
              },
              child: const Text('Go Back'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                _startGeneration(); // Retry generation
              },
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '🎬 Creating Your Movie',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your Movie Idea:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.movieIdea,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const Center(
                child: CircularProgressIndicator(),
              ),
              const SizedBox(height: 32),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'What\'s Happening:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _StepIndicator(
                        icon: Icons.psychology,
                        text: 'Analyzing your idea',
                        isCompleted: _completedSteps.contains('Analyzing your movie idea'),
                        isActive: _currentStep == 'Analyzing your movie idea',
                      ),
                      const _StepDivider(),
                      _StepIndicator(
                        icon: Icons.auto_awesome,
                        text: 'Gathering creative inspiration',
                        isCompleted: _completedSteps.contains('Creating scene descriptions'),
                        isActive: _currentStep == 'Creating scene descriptions',
                      ),
                      const _StepDivider(),
                      _StepIndicator(
                        icon: Icons.movie_creation,
                        text: 'Crafting your scenes',
                        isCompleted: _completedSteps.contains('Finalizing your movie'),
                        isActive: _currentStep == 'Finalizing your movie',
                      ),
                      const _StepDivider(),
                      _StepIndicator(
                        icon: Icons.check_circle,
                        text: 'Finalizing your movie',
                        isCompleted: _completedSteps.contains('Finalizing your movie'),
                        isActive: _currentStep == 'Finalizing your movie',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'This usually takes about 30 seconds...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isCompleted;
  final bool isActive;

  const _StepIndicator({
    required this.icon,
    required this.text,
    this.isCompleted = false,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isCompleted
        ? Colors.green
        : isActive
            ? Theme.of(context).primaryColor
            : Colors.grey;

    return Row(
      children: [
        Icon(
          isCompleted ? Icons.check_circle : icon,
          color: color,
          size: 24,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 16,
              color: color,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        if (isActive)
          Container(
            width: 24,
            height: 24,
            padding: const EdgeInsets.all(4),
            child: const CircularProgressIndicator(
              strokeWidth: 2,
            ),
          ),
      ],
    );
  }
}

class _StepDivider extends StatelessWidget {
  const _StepDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      child: Container(
        width: 1,
        height: 24,
        color: Colors.grey.withOpacity(0.3),
      ),
    );
  }
} 