import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/movie/movie_service.dart';
import '../../services/movie/movie_video_service.dart';
import '../video/movie_video_player_screen.dart';
import '../training/director_training_screen.dart';
import 'scene_generation_modal.dart';
import 'video_generation_modal.dart';
import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../services/ai/scene_director_service.dart';
import 'dialogs/director_cut_dialog.dart';

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
  final MovieVideoService _videoService = MovieVideoService();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _continuationIdea = '';
  final TextEditingController _numScenesController = TextEditingController(text: '3');
  final TextEditingController _confirmDeleteController = TextEditingController();
  late List<Map<String, dynamic>> _scenes;

  @override
  void initState() {
    super.initState();
    _currentTitle = widget.movieTitle;
    _initializeSpeech();
    _scenes = List<Map<String, dynamic>>.from(widget.scenes);
  }

  Future<void> _initializeSpeech() async {
    try {
      bool available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done') {
            setState(() => _isListening = false);
          }
        },
        onError: (error) {
          print('Speech Error: $error');
          setState(() => _isListening = false);
        },
      );
      if (!available) {
        print('Speech recognition not available');
      }
    } catch (e) {
      print('Speech initialization error: $e');
    }
  }

  Future<void> _showTitleDialog(BuildContext context, {String? currentTitle}) async {
    final textController = TextEditingController(text: currentTitle);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(currentTitle == null ? 'Create Movie Title' : 'Edit Movie Title'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: textController,
              decoration: const InputDecoration(
                hintText: 'Enter a title for your movie...',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final title = textController.text.trim();
              if (title.isEmpty) return;

              try {
                final movieService = Provider.of<MovieService>(context, listen: false);
                await movieService.updateMovieTitle(widget.movieId, title);
                setState(() => _currentTitle = title);
                Navigator.of(context).pop();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: Text(currentTitle == null ? 'Create' : 'Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDirectorCutDialog(BuildContext context, Map<String, dynamic> scene) async {
    final result = await showDialog<SceneReconception>(
      context: context,
      builder: (context) => DirectorCutDialog(
        sceneText: scene['text'],
        onDirectorCutSelected: (directorCut) async {
          try {
            final movieService = Provider.of<MovieService>(context, listen: false);
            await movieService.updateScene(
              movieId: widget.movieId,
              sceneId: scene['documentId'],
              sceneData: {
                'hasDirectorCut': true,
                'directorCutScene': directorCut.sceneDescription,
                'directorNotes': directorCut.directorNotes,
                'directorName': directorCut.directorName,
                'updatedAt': FieldValue.serverTimestamp(),
              },
            );

            // Update the scene in the UI
            setState(() {
              final index = _scenes.indexWhere((s) => s['documentId'] == scene['documentId']);
              if (index != -1) {
                _scenes[index] = {
                  ..._scenes[index],
                  'hasDirectorCut': true,
                  'directorCutScene': directorCut.sceneDescription,
                  'directorNotes': directorCut.directorNotes,
                  'directorName': directorCut.directorName,
                };
              }
            });

            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Director\'s cut added successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error adding director\'s cut: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _generateVideo(BuildContext context, Map<String, dynamic> scene) async {
    final progressController = StreamController<VideoGenerationProgress>();
    
    try {
      // Show the generation modal
      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => VideoGenerationModal(
          sceneText: scene['text'],
          movieId: scene['movieId'],
          sceneId: scene['documentId'],
          progressStream: progressController.stream,
          onVideoReady: (videoUrl, videoId) async {
            // Update the scene with the new video URL
            final movieService = Provider.of<MovieService>(context, listen: false);
            await movieService.updateSceneVideo(
              scene['movieId'],
              scene['documentId'],
              videoUrl,
              videoId,
            );

            // Update the scene status in the UI
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
              Navigator.of(context).pop(); // Close the modal
            }

            // Show success message
            if (context.mounted) {
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
    } catch (e) {
      // Show error message
      if (context.mounted) {
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
  }

  Future<void> _uploadVideo(BuildContext context, Map<String, dynamic> scene, bool fromCamera) async {
    final progressController = StreamController<double>();

    try {
      if (!context.mounted) {
        await progressController.close();
        return;
      }

      // Show upload progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => WillPopScope(
          onWillPop: () async => false,
          child: StreamBuilder<double>(
            stream: progressController.stream,
            builder: (context, snapshot) {
              return AlertDialog(
                title: Text(snapshot.data == 1.0 ? 'Complete!' : 'Uploading Video'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 16),
                    if (snapshot.data != 1.0) LinearProgressIndicator(
                      value: snapshot.data,
                    ),
                    if (snapshot.data == 1.0) const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      snapshot.data == 1.0
                        ? 'Video upload successful!'
                        : snapshot.data != null 
                          ? '${(snapshot.data! * 100).toStringAsFixed(0)}%'
                          : 'Starting upload...',
                    ),
                  ],
                ),
                actions: snapshot.data == 1.0 ? [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('Close'),
                  ),
                ] : null,
              );
            },
          ),
        ),
      );

      final movieService = Provider.of<MovieService>(context, listen: false);
      final result = await _videoService.uploadVideoForScene(
        movieId: widget.movieId,
        sceneId: scene['documentId'],
        context: context,
        fromCamera: fromCamera,
        onProgress: (progress) {
          if (!progressController.isClosed) {
            progressController.add(progress);
          }
        },
      );

      if (result != null) {
        await movieService.updateSceneVideo(
          widget.movieId,
          scene['documentId'],
          result['videoUrl']!,
          result['videoId']!,
          isUserVideo: true,
        );

        // Update the scene status in the UI
        setState(() {
          final index = _scenes.indexWhere((s) => s['documentId'] == scene['documentId']);
          if (index != -1) {
            _scenes[index] = {
              ..._scenes[index],
              'status': 'completed',
              'videoUrl': result['videoUrl'],
              'videoId': result['videoId'],
              'videoType': 'user',
            };
          }
        });

        // Send final progress to show completion state
        if (!progressController.isClosed) {
          progressController.add(1.0);
        }
        await Future.delayed(const Duration(seconds: 1));

        // Show success message
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Video uploaded successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      // Close progress dialog on error
      if (context.mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading video: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // Always close the progress controller
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
                            _speech.stop();
                            setState(() => _isListening = false);
                          } else {
                            _startListening(
                              onResult: (text) => setState(() => _continuationIdea = text),
                              onListening: (isListening) => setState(() => _isListening = isListening),
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
                          // Close the dialog
                          Navigator.of(context).pop();

                          // Create progress stream
                          final progressController = StreamController<String>();

                          // Show generation modal
                          if (!context.mounted) return;
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => SceneGenerationModal(
                              originalIdea: widget.movieIdea,
                              continuationIdea: _continuationIdea,
                              progressStream: progressController.stream,
                            ),
                          );

                          try {
                            // Generate new scene
                            final movieService = Provider.of<MovieService>(context, listen: false);
                            final newScenes = await movieService.generateAdditionalScene(
                              movieId: widget.movieId,
                              existingScenes: _scenes,
                              continuationIdea: _continuationIdea,
                              onProgress: (message) {
                                progressController.add(message);
                              },
                            );

                            // Close progress modal
                            if (!context.mounted) return;
                            Navigator.of(context).pop();

                            // Update the scenes list with the new data
                            setState(() {
                              _scenes = [..._scenes, ...newScenes];
                            });

                            // Refresh the parent widget if needed
                            if (mounted) {
                              setState(() {});
                            }

                            // Show success message
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${newScenes.length} new scenes added successfully!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            // Send error to progress stream
                            progressController.addError(e.toString());
                            
                            // Wait a moment to show the error
                            await Future.delayed(const Duration(seconds: 3));
                            
                            // Close progress modal if it's open
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                            
                            // Show error message
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          } finally {
                            await progressController.close();
                          }
                        } catch (e) {
                          // Show error message
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

  Future<void> _startListening({
    required Function(String) onResult,
    required Function(bool) onListening,
  }) async {
    bool available = await _speech.initialize();
    if (available) {
      onListening(true);
      await _speech.listen(
        onResult: (result) {
          onResult(result.recognizedWords);
        },
      );
    }
  }

  Future<void> _showDeleteConfirmationDialog() async {
    _confirmDeleteController.clear();
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Movie'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This action cannot be undone. All scenes and videos will be permanently deleted.',
                style: TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              const Text(
                'Type "confirm" to delete:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _confirmDeleteController,
                decoration: const InputDecoration(
                  hintText: 'Type confirm here',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_confirmDeleteController.text.trim().toLowerCase() == 'confirm') {
                  try {
                    Navigator.of(context).pop(); // Close dialog
                    final movieService = Provider.of<MovieService>(context, listen: false);
                    await movieService.deleteMovie(widget.movieId);
                    
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
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please type "confirm" exactly to delete'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Your Movie Scenes'),
        actions: [
          if (!widget.isReadOnly) // Only show delete for owned movies
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _showDeleteConfirmationDialog,
              tooltip: 'Delete Movie',
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Movie Title:',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            if (_currentTitle != null)
                              TextButton.icon(
                                onPressed: () => _showTitleDialog(context, currentTitle: _currentTitle),
                                icon: const Icon(Icons.edit),
                                label: const Text('Edit'),
                              )
                            else
                              TextButton.icon(
                                onPressed: () => _showTitleDialog(context),
                                icon: const Icon(Icons.add),
                                label: const Text('Create Title'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_currentTitle != null)
                          Text(
                            _currentTitle!,
                            style: const TextStyle(fontSize: 20),
                          )
                        else
                          const Text(
                            'No title yet',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Movie Idea:',
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
                const SizedBox(height: 24),
                const Text(
                  'Suggested Scenes:',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _scenes.length,
                  itemBuilder: (context, index) {
                    final scene = _scenes[index];
                    final isNewScene = scene['id'] > widget.scenes.length;
                    final isFirstNewScene = scene['id'] == widget.scenes.length + 1;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isFirstNewScene) ...[
                          Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Continuation Prompt:',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _continuationIdea,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              'New Scenes:',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        Dismissible(
                          key: Key(scene['documentId']),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 24.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.delete,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Delete',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 16),
                              ],
                            ),
                          ),
                          confirmDismiss: (direction) async {
                            return await showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: Row(
                                    children: [
                                      const Icon(Icons.warning, color: Colors.red),
                                      const SizedBox(width: 8),
                                      const Text('Delete Scene'),
                                    ],
                                  ),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Are you sure you want to delete this scene?',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Scene ${scene['id']}: ${scene['text']}',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'This action cannot be undone.',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(false),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () => Navigator.of(context).pop(true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                      ),
                                      icon: const Icon(Icons.delete),
                                      label: const Text('Delete'),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                          onDismissed: (direction) async {
                            try {
                              // Remove the scene from Firestore
                              final movieService = Provider.of<MovieService>(context, listen: false);
                              await movieService.deleteScene(widget.movieId, scene['documentId']);

                              // Update the local state
                              setState(() {
                                _scenes.removeAt(index);
                                // Update the IDs of subsequent scenes
                                for (var i = index; i < _scenes.length; i++) {
                                  _scenes[i] = {
                                    ..._scenes[i],
                                    'id': i + 1,
                                    'title': 'Scene ${i + 1}',
                                  };
                                }
                              });

                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Scene deleted successfully'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error deleting scene: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          child: Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ExpansionTile(
                              leading: CircleAvatar(
                                child: Text('${scene['id']}'),
                                backgroundColor: isNewScene ? Colors.blue : null,
                              ),
                              title: Text(
                                scene['title'] ?? 'Scene ${scene['id']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                scene['text'],
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (scene['videoType'] == 'ai')
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.blue[100],
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.blue),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.auto_awesome, size: 16, color: Colors.blue[700]),
                                          const SizedBox(width: 4),
                                          Text(
                                            'AI',
                                            style: TextStyle(
                                              color: Colors.blue[700],
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  Icon(
                                    Icons.circle,
                                    size: 12,
                                    color: _getStatusColor(scene['status']),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    scene['status'],
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        scene['text'],
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                      const SizedBox(height: 16),
                                      if (scene['hasDirectorCut'] == true) ...[
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.blue.withOpacity(0.3)),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  const Icon(Icons.movie_filter, color: Colors.blue, size: 20),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'Director\'s Vision (${scene['directorName']})',
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.blue,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 12),
                                              const Text(
                                                'Reimagined Scene:',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.blue,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                scene['directorCutScene'],
                                                style: TextStyle(
                                                  color: Colors.grey[800],
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              const Text(
                                                'Director\'s Notes:',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.blue,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                scene['directorNotes'],
                                                style: TextStyle(
                                                  color: Colors.grey[800],
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                      ],
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (scene['videoUrl'] != null && scene['videoUrl'].toString().isNotEmpty) ...[
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              margin: const EdgeInsets.only(right: 8),
                                              decoration: BoxDecoration(
                                                color: scene['videoType'] == 'ai' ? Colors.blue[100] : Colors.green[100],
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: scene['videoType'] == 'ai' ? Colors.blue : Colors.green,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    scene['videoType'] == 'ai' 
                                                      ? Icons.auto_awesome 
                                                      : Icons.videocam,
                                                    size: 16,
                                                    color: scene['videoType'] == 'ai' 
                                                      ? Colors.blue[700]
                                                      : Colors.green[700],
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    scene['videoType'] == 'ai' ? 'AI' : 'User',
                                                    style: TextStyle(
                                                      color: scene['videoType'] == 'ai' 
                                                        ? Colors.blue[700]
                                                        : Colors.green[700],
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                          if (!widget.isReadOnly)
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.video_library),
                                                  tooltip: 'Add Video',
                                                  onPressed: () => _showVideoOptionsMenu(context, scene),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.movie_creation),
                                                  tooltip: 'Director\'s Cut',
                                                  onPressed: () => _showDirectorCutDialog(context, scene),
                                                ),
                                              ],
                                            ),
                                          if (scene['videoUrl'] != null && scene['videoUrl'].toString().isNotEmpty) ...[
                                            IconButton(
                                              icon: const Icon(Icons.play_circle_outline),
                                              tooltip: 'Watch Video',
                                              onPressed: () {
                                                final scenesWithVideos = _scenes.where((scene) => 
                                                  scene['videoUrl'] != null && scene['videoUrl'].toString().isNotEmpty
                                                ).toList();
                                                
                                                Navigator.of(context).push(
                                                  MaterialPageRoute(
                                                    builder: (context) => MovieVideoPlayerScreen(
                                                      scenes: scenesWithVideos,
                                                      initialIndex: scenesWithVideos.indexWhere(
                                                        (s) => s['documentId'] == scene['documentId']
                                                      ),
                                                      movieId: widget.movieId,
                                                      userId: scene['userId'] ?? '',
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.school),
                                              tooltip: 'Practice with Director',
                                              onPressed: () {
                                                Navigator.of(context).push(
                                                  MaterialPageRoute(
                                                    builder: (context) => DirectorTrainingScreen(
                                                      initialVideoPath: scene['videoUrl'],
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),

                // Add New Scenes button - show for all movies except read-only
                if (!widget.isReadOnly) ...[
                  const SizedBox(height: 24),
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: _showAddScenesDialog,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        backgroundColor: Colors.blue, // Make it stand out
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text(
                        'Add New Scene',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16), // Add some space before the bottom bar
                ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton.icon(
          onPressed: () {
            final scenesWithVideos = _scenes.where((scene) => 
              scene['videoUrl'] != null && scene['videoUrl'].toString().isNotEmpty
            ).toList();
            
            if (scenesWithVideos.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('No videos available yet. Add some videos to your scenes first.'),
                ),
              );
              return;
            }
            
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => MovieVideoPlayerScreen(
                  scenes: scenesWithVideos,
                  movieId: widget.movieId,
                  userId: scenesWithVideos.first['userId'] ?? '',
                ),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          icon: const Icon(Icons.movie),
          label: const Text('Watch Full Movie'),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.grey;
      case 'recording':
        return Colors.red;
      case 'completed':
        return Colors.green;
      case 'failed':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Future<void> _showVideoOptionsMenu(BuildContext context, Map<String, dynamic> scene) async {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.auto_awesome),
            title: const Text('Generate AI Video'),
            onTap: () {
              Navigator.pop(context);
              _generateVideo(context, scene);
            },
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Record Video'),
            onTap: () {
              Navigator.pop(context);
              _uploadVideo(context, scene, true);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Upload from Gallery'),
            onTap: () {
              Navigator.pop(context);
              _uploadVideo(context, scene, false);
            },
          ),
        ],
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
                              // Show the add scenes dialog again
                              Future.microtask(() => 
                                (context as Element).findAncestorStateOfType<_MovieScenesScreenState>()
                                ?._showAddScenesDialog()
                              );
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