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
  bool _ignoreNextFirestoreUpdate = false;

  @override
  void initState() {
    super.initState();
    _currentTitle = widget.movieTitle;
    _scenes = List<Map<String, dynamic>>.from(widget.scenes);
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

  Future<void> _handleScenesUpdated(List<Map<String, dynamic>> updatedScenes) async {
    print('🔄 _handleScenesUpdated called with ${updatedScenes.length} scenes');
    
    try {
      // Set flag to ignore the next Firestore update since we're about to make one
      _ignoreNextFirestoreUpdate = true;
      
      // Update local state first
      if (mounted) {
        setState(() {
          _scenes = List<Map<String, dynamic>>.from(updatedScenes);
        });
      }

      // Then update Firestore in the background
      for (var scene in updatedScenes) {
        if (scene['documentId'] != null) {
          await _movieService.updateScene(
            movieId: widget.movieId,
            sceneId: scene['documentId'],
            sceneData: Map<String, dynamic>.from(scene),
          );
        }
      }
    } catch (e) {
      print('❌ Error in _handleScenesUpdated: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving changes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateSceneInList(Map<String, dynamic> updatedScene) async {
    print('🔄 _updateSceneInList called with scene: ${updatedScene['documentId']}');
    
    try {
      // Set flag to ignore the next Firestore update
      _ignoreNextFirestoreUpdate = true;

      // Update local state first
      if (mounted) {
        setState(() {
          final index = _scenes.indexWhere((s) => s['documentId'] == updatedScene['documentId']);
          if (index != -1) {
            _scenes[index] = Map<String, dynamic>.from(updatedScene);
          }
        });
      }

      // Then update Firestore in the background
      if (updatedScene['documentId'] != null) {
        await _movieService.updateScene(
          movieId: widget.movieId,
          sceneId: updatedScene['documentId'],
          sceneData: Map<String, dynamic>.from(updatedScene),
        );
      }
    } catch (e) {
      print('❌ Error in _updateSceneInList: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving changes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadVideo(BuildContext context, Map<String, dynamic> scene, bool fromCamera) async {
    print('🎥 Starting video upload for scene: ${scene['documentId']}');
    final progressController = StreamController<double>();
    bool hasError = false;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => VideoUploadModal(
          progressStream: progressController.stream,
          onCancel: () {
            print('❌ Upload cancelled by user');
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
            print('📈 Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
            progressController.add(progress);
          }
        },
        onComplete: (result) {
          print('✅ Video upload complete. VideoUrl: ${result['videoUrl']}');
          if (!mounted) return;
          
          final updatedScene = {
            ...scene,
            'status': 'completed',
            'videoUrl': result['videoUrl'],
            'videoId': result['videoId'],
            'videoType': 'user',
          };
          
          print('🔄 Updating scene with new video data');
          // First update the progress to 100%
          if (!progressController.isClosed) {
            progressController.add(1.0);
          }

          // Wait a moment for the progress bar to complete
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              // Dismiss the dialog
              Navigator.of(context).pop();
              
              // Then update the scene data
              _updateSceneInList(updatedScene).then((_) {
                print('✅ Scene update complete');
                
                if (mounted) {
                  print('🎉 Showing success message to user');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Video uploaded successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              });
            }
          });
        },
        onError: (error) {
          print('❌ Upload error: $error');
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
    } catch (e) {
      print('❌ Unexpected upload error: $e');
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
                          // Close the initial dialog
                          Navigator.of(context).pop();
                          
                          final progressController = StreamController<String>();
                          BuildContext? dialogContext;

                          if (!mounted) return;
                          // Show the generation modal
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) {
                              dialogContext = context;
                              return SceneGenerationModal(
                                originalIdea: widget.movieIdea,
                                continuationIdea: _continuationIdea,
                                progressStream: progressController.stream,
                                onRetry: _showAddScenesDialog,
                              );
                            },
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

                            // Close the generation modal
                            if (dialogContext != null && mounted) {
                              Navigator.of(dialogContext!).pop();
                            }

                            if (mounted) {
                              setState(() {
                                _scenes = [..._scenes, ...newScenes];
                              });

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${newScenes.length} new scenes added successfully!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            progressController.addError(e.toString());
                            await Future.delayed(const Duration(seconds: 3));
                            
                            // Close the generation modal on error
                            if (dialogContext != null && mounted) {
                              Navigator.of(dialogContext!).pop();
                            }

                            if (mounted) {
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
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
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
        title: Text(_currentTitle ?? 'Movie Scenes'),
        actions: [
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
            return Center(
              child: Text(
                'Error loading scenes: ${snapshot.error}',
                style: TextStyle(color: Colors.red[400]),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // If we just made a local update, ignore this Firestore update
          if (_ignoreNextFirestoreUpdate) {
            _ignoreNextFirestoreUpdate = false;
          } else {
            // Only update from Firestore if we haven't just made a local change
            final firestoreScenes = snapshot.data!;
            
            // Deep compare scenes to check for actual changes
            bool hasChanges = _scenes.length != firestoreScenes.length;
            if (!hasChanges) {
              for (int i = 0; i < _scenes.length; i++) {
                print('🔍 Comparing scene ${_scenes[i]['documentId']}:');
                print('   Local - videoUrl: ${_scenes[i]['videoUrl']}, status: ${_scenes[i]['status']}');
                print('   Firestore - videoUrl: ${firestoreScenes[i]['videoUrl']}, status: ${firestoreScenes[i]['status']}');
                
                if (_scenes[i]['documentId'] != firestoreScenes[i]['documentId'] ||
                    _scenes[i]['hasDirectorCut'] != firestoreScenes[i]['hasDirectorCut'] ||
                    _scenes[i]['text'] != firestoreScenes[i]['text'] ||
                    _scenes[i]['videoUrl'] != firestoreScenes[i]['videoUrl'] ||
                    _scenes[i]['status'] != firestoreScenes[i]['status'] ||
                    _scenes[i]['videoType'] != firestoreScenes[i]['videoType']) {
                  print('⚠️ Scene ${_scenes[i]['documentId']} has changes');
                  hasChanges = true;
                  break;
                }
              }
            }
            
            if (hasChanges) {
              print('🔄 Updating local scenes from Firestore');
              // Schedule the setState for the next frame
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _scenes = List<Map<String, dynamic>>.from(firestoreScenes);
                  });
                }
              });
            }
          }

          // Use the current state for rendering
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TitleSection(
                    currentTitle: _currentTitle,
                    movieId: widget.movieId,
                    isReadOnly: widget.isReadOnly,
                    onTitleChanged: _handleTitleChanged,
                  ),
                  const SizedBox(height: 16),
                  IdeaSection(
                    movieIdea: widget.movieIdea,
                  ),
                  const SizedBox(height: 24),
                  ScenesList(
                    scenes: _scenes,
                    movieId: widget.movieId,
                    movieTitle: _currentTitle,
                    isReadOnly: widget.isReadOnly,
                    onScenesUpdated: _handleScenesUpdated,
                    onVideoSelected: (scene) {
                      _showVideoOptionsMenu(context, scene);
                    },
                  ),
                  const SizedBox(height: 24),
                  // Add Watch Movie button
                  if (_scenes.any((scene) => scene['videoUrl'] != null && scene['videoUrl'].toString().isNotEmpty))
                    Center(
                      child: ElevatedButton.icon(
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
                        icon: const Icon(Icons.play_circle_filled),
                        label: const Text('Watch Full Movie'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
} 