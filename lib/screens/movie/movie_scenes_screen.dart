import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/movie/movie_service.dart';
import '../../services/video_service.dart';
import '../../services/speech_service.dart';
import '../../models/video_generation_progress.dart';
import '../video/movie_video_player_screen.dart';
import '../training/director_training_screen.dart';
import 'modals/scene_generation_modal.dart';
import 'modals/video_generation_modal.dart';
import 'modals/video_upload_modal.dart';
import 'modals/delete_confirmation_modal.dart';
import 'widgets/title_section.dart';
import 'widgets/idea_section.dart';
import 'widgets/scenes_list.dart';
import 'dialogs/director_cut_dialog.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'video_options_menu.dart';
import '../../widgets/scene_card.dart';

class MovieScenesScreen extends StatefulWidget {
  final String movieIdea;
  final List<Map<String, dynamic>> scenes;
  final String? movieTitle;
  final String movieId;
  final bool isReadOnly;

  const MovieScenesScreen({
    super.key,
    required this.movieIdea,
    required this.scenes,
    required this.movieId,
    this.movieTitle,
    this.isReadOnly = false,
  });

  @override
  State<MovieScenesScreen> createState() => _MovieScenesScreenState();
}

class _MovieScenesScreenState extends State<MovieScenesScreen> {
  String? _currentTitle;
  late List<Map<String, dynamic>> _scenes;
  final VideoService _videoService = VideoService();
  final SpeechService _speechService = SpeechService();
  bool _isListening = false;
  String _continuationIdea = '';
  final TextEditingController _confirmDeleteController = TextEditingController();
  late final MovieService _movieService;

  @override
  void initState() {
    super.initState();
    _currentTitle = widget.movieTitle;
    _scenes = [];
    _speechService.initialize();
    _movieService = Provider.of<MovieService>(context, listen: false);
  }

  @override
  void dispose() {
    _speechService.dispose();
    super.dispose();
  }

  void _handleTitleChanged(String newTitle) {
    setState(() => _currentTitle = newTitle);
  }

  void _handleScenesUpdated(List<Map<String, dynamic>> updatedScenes) {
    setState(() => _scenes = updatedScenes);
  }

  void _updateSceneInList(Map<String, dynamic> updatedScene) {
    setState(() {
      final index = _scenes.indexWhere((s) => s['documentId'] == updatedScene['documentId']);
      if (index != -1) {
        _scenes[index] = updatedScene;
      }
    });
  }

  Future<void> _uploadVideo(BuildContext context, Map<String, dynamic> scene, bool fromCamera) async {
    final progressController = StreamController<double>();
    bool hasError = false;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => VideoUploadModal(
          progressStream: progressController.stream,
          onCancel: () {
            progressController.close();
            Navigator.of(context).pop();
          },
        ),
      );

      await _videoService.uploadVideo(
        context: context,
        scene: scene,
        fromCamera: fromCamera,
        onProgress: (progress) {
          if (!progressController.isClosed) {
            progressController.add(progress);
          }
        },
        onComplete: (result) {
          if (!mounted) return;
          
          final updatedScene = {
            ...scene,
            'status': 'completed',
            'videoUrl': result['videoUrl'],
            'videoId': result['videoId'],
            'videoType': 'user',
          };
          
          _updateSceneInList(updatedScene);

          if (!progressController.isClosed) {
            progressController.add(1.0);
          }
        },
        onError: (error) {
          hasError = true;
          if (mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error uploading video: $error'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      );

      if (!hasError) {
        await Future.delayed(const Duration(seconds: 1));

        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Video uploaded successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      print('Upload error: $e');
      if (mounted && !hasError) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading video: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (!progressController.isClosed) {
        await progressController.close();
      }
    }
  }

  Future<void> _generateVideo(BuildContext context, Map<String, dynamic> scene) async {
    final progressController = StreamController<VideoGenerationProgress>();
    
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => VideoGenerationModal(
          sceneText: scene['text'],
          movieId: scene['movieId'],
          sceneId: scene['documentId'],
          progressStream: progressController.stream,
          onVideoReady: (videoUrl, videoId) async {
            setState(() {
              final index = _scenes.indexWhere((s) => s['documentId'] == scene['documentId']);
              if (index != -1) {
                _scenes[index] = {
                  ..._scenes[index],
                  'status': 'completed',
                  'videoUrl': videoUrl,
                  'videoId': videoId,
                  'videoType': 'ai',
                };
              }
            });

            if (context.mounted) {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Video generated successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          },
        ),
      );

      await _videoService.generateVideo(
        context: context,
        scene: scene,
        onProgress: (progress) {
          if (!progressController.isClosed) {
            progressController.sink.add(progress);
          }
        },
        onComplete: (videoUrl, videoId) async {
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        },
        onError: (error) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: $error'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      );
    } finally {
      await progressController.close();
    }
  }

  Future<void> _showAddScenesDialog() async {
    _continuationIdea = '';
    
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Add New Scene'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Describe how the movie should continue:'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _continuationIdea.isEmpty ? 'Tap microphone to record' : _continuationIdea,
                          style: TextStyle(
                            color: _continuationIdea.isEmpty ? Colors.grey : Colors.black,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(_isListening ? Icons.stop : Icons.mic),
                        onPressed: () {
                          if (_isListening) {
                            _speechService.stopListening();
                            setState(() => _isListening = false);
                          } else {
                            _speechService.startListening(
                              onResult: (text) => setState(() => _continuationIdea = text),
                              onListeningChanged: (isListening) => setState(() => _isListening = isListening),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: _continuationIdea.isEmpty
                    ? null
                    : () async {
                        try {
                          Navigator.of(context).pop();
                          final progressController = StreamController<String>();

                          if (!context.mounted) return;
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => SceneGenerationModal(
                              originalIdea: widget.movieIdea,
                              continuationIdea: _continuationIdea,
                              progressStream: progressController.stream,
                              onRetry: _showAddScenesDialog,
                            ),
                          );

                          try {
                            final newScenes = await _movieService.generateAdditionalScene(
                              movieId: widget.movieId,
                              existingScenes: _scenes,
                              continuationIdea: _continuationIdea,
                              onProgress: (message) {
                                progressController.add(message);
                              },
                            );

                            if (!context.mounted) return;
                            Navigator.of(context).pop();

                            setState(() {
                              _scenes = [..._scenes, ...newScenes];
                            });

                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${newScenes.length} new scenes added successfully!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            progressController.addError(e.toString());
                            await Future.delayed(const Duration(seconds: 3));
                            
                            if (context.mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } finally {
                            await progressController.close();
                          }
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                child: const Text('Generate Scene'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showVideoOptionsMenu(BuildContext context, Map<String, dynamic> scene) async {
    showModalBottomSheet(
      context: context,
      builder: (context) => VideoOptionsMenu(
        onUploadVideo: (fromCamera) => _uploadVideo(context, scene, fromCamera),
        onGenerateAI: () => _generateVideo(context, scene),
      ),
    );
  }

  Future<void> _showDeleteConfirmationDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => DeleteConfirmationModal(
        onConfirm: () async {
          try {
            await _movieService.deleteMovie(widget.movieId);
            
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Movie deleted successfully'),
                backgroundColor: Colors.green,
              ),
            );
            // Navigate back to home page and clear the stack
            Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error deleting movie: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.movieTitle ?? 'Movie Scenes'),
        actions: [
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _movieService.getMovieScenes(widget.movieId),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              
              final scenes = snapshot.data!;
              final needsVideoCount = scenes.where((s) => s['needsVideo'] == true).length;
              
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Center(
                  child: Text(
                    'Needs Video: $needsVideoCount/${scenes.length}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          ),
          if (!widget.isReadOnly) ...[
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _showAddScenesDialog,
              tooltip: 'Add Scene',
            ),
            IconButton(
              icon: const Icon(Icons.play_arrow),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => MovieVideoPlayerScreen(
                      scenes: _scenes,
                      movieId: widget.movieId,
                      userId: _movieService.getCurrentUserId(),
                    ),
                  ),
                );
              },
              tooltip: 'Preview Movie',
            ),
          ],
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _movieService.getMovieScenes(widget.movieId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final scenes = snapshot.data!;
          print('Displaying ${scenes.length} scenes. Scenes with videos: ${scenes.where((s) => !s['needsVideo']).length}');

          return ReorderableListView.builder(
            itemCount: scenes.length,
            onReorder: (oldIndex, newIndex) {
              // ... existing reorder code ...
            },
            itemBuilder: (context, index) {
              final scene = scenes[index];
              return SceneCard(
                key: ValueKey(scene['documentId']),
                scene: scene,
                movieId: widget.movieId,
                onVideoUploaded: () {
                  // Scene will be automatically updated through the stream
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Video uploaded successfully')),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // ... existing add scene code ...
        },
        child: const Icon(Icons.add),
      ),
    );
  }
} 