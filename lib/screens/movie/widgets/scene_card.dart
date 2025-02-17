import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import '../../../services/video/video_creation_service.dart';
import '../../../models/video_progress.dart';
import '../../../models/video_operation_exception.dart';
import '../../../models/video_generation_progress.dart';
import '../../../screens/video/movie_video_player_screen.dart';
import '../../../services/ai/scene_director_service.dart';
import '../../../services/movie/movie_service.dart';
import '../dialogs/director_cut_dialog.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'video_progress_tracker.dart';

class SceneCard extends StatelessWidget {
  final Map<String, dynamic> scene;
  final bool isNewScene;
  final bool isReadOnly;
  final Function(Map<String, dynamic>) onEdit;
  final Function(Map<String, dynamic>) onDelete;
  final Function(Map<String, dynamic>) onVideoSelected;
  final String? movieTitle;
  final String movieId;

  const SceneCard({
    Key? key,
    required this.scene,
    required this.isReadOnly,
    required this.onEdit,
    required this.onDelete,
    required this.onVideoSelected,
    required this.isNewScene,
    required this.movieTitle,
    required this.movieId,
  }) : super(key: key);

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

  Future<void> _handleVideoUpload(BuildContext context, bool fromCamera) async {
    final videoService = VideoCreationService();
    final progressTracker = VideoProgressTracker(context);

    try {
      progressTracker.show();
      
      final result = await videoService.uploadVideo(
        context: context,
        movieId: movieId,
        sceneId: scene['documentId'],
        fromCamera: fromCamera,
        onProgress: (progress) {
          progressTracker.update(progress);
        },
      );

      if (result != null) {
        onEdit({
          ...scene,
          'videoUrl': result['videoUrl'],
          'videoId': result['videoId'],
          'videoType': VideoCreationService.VIDEO_TYPE_USER,
        });
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading video: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      progressTracker.close();
    }
  }

  Future<void> _handleVideoDelete(BuildContext context) async {
    final videoService = VideoCreationService();
    final progressTracker = VideoProgressTracker(context);

    try {
      progressTracker.show();
      
      await videoService.deleteVideo(
        movieId,
        scene['documentId'],
        scene['videoId'],
      );

      onEdit({
        ...scene,
        'videoUrl': null,
        'videoId': null,
        'videoType': null,
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting video: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      progressTracker.close();
    }
  }

  Future<void> _handleAIVideoGeneration(BuildContext context) async {
    final videoService = VideoCreationService();
    final progressController = StreamController<VideoGenerationProgress>.broadcast();
    
    try {
      // If there's a director's cut, ask which version to use
      String sceneTextToUse = scene['text'];
      
      if (scene['directorNotes'] != null && scene['originalText'] != null) {
        final choice = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.movie_creation, color: Colors.blue),
                SizedBox(width: 8),
                Text('Choose Scene Version'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Which version of the scene would you like to use for the AI video?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Original Scene'),
                  subtitle: Text(
                    scene['originalText'],
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => Navigator.of(context).pop('original'),
                ),
                const Divider(),
                ListTile(
                  title: Text('Director\'s Cut (${scene['directorName']})'),
                  subtitle: Text(
                    scene['text'],
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => Navigator.of(context).pop('directors'),
                ),
              ],
            ),
          ),
        );

        if (choice == null) return; // User cancelled
        sceneTextToUse = choice == 'original' ? scene['originalText'] : scene['text'];
      }

      // Show progress dialog
      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => WillPopScope(
          onWillPop: () async => false,
          child: StreamBuilder<VideoGenerationProgress>(
            stream: progressController.stream,
            builder: (context, snapshot) {
              final progress = snapshot.data?.progress ?? 0.0;
              final status = snapshot.data?.status ?? 'Initializing...';
              
              return AlertDialog(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 20),
                    Text(
                      status,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${(progress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: progress),
                  ],
                ),
              );
            },
          ),
        ),
      );

      await for (final progress in videoService.generateAIVideo(
        sceneText: sceneTextToUse,
        movieId: movieId,
        sceneId: scene['documentId'],
      )) {
        if (!progressController.isClosed) {
          progressController.add(progress);
        }

        if (progress.result != null) {
          // Video generation complete
          if (context.mounted) {
            Navigator.of(context).pop(); // Close progress dialog

            final updatedScene = Map<String, dynamic>.from(scene);
            updatedScene['videoUrl'] = progress.result!['videoUrl'];
            updatedScene['videoId'] = progress.result!['videoId'];
            updatedScene['videoType'] = VideoCreationService.VIDEO_TYPE_AI;
            updatedScene['status'] = 'completed';
            onVideoSelected(updatedScene);

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('AI Video generated successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
          break;
        }
      }
    } catch (e) {
      if (!progressController.isClosed) {
        await progressController.close();
      }
      if (context.mounted) {
        Navigator.of(context).pop(); // Close progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating AI video: $e'),
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

  Future<void> _handleDirectorCut(BuildContext context) async {
    final result = await showDialog<SceneReconception>(
      context: context,
      builder: (context) => DirectorCutDialog(
        sceneText: scene['text'],
        onDirectorCutSelected: (directorCut) {
          final updatedScene = Map<String, dynamic>.from(scene);
          updatedScene['originalText'] = scene['text'];
          updatedScene['text'] = directorCut.sceneDescription;
          updatedScene['directorNotes'] = directorCut.directorNotes;
          onEdit(updatedScene);
        },
      ),
    );

    if (result != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Director\'s cut applied successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Widget _buildVideoSection(BuildContext context) {
    if (scene['videoUrl'] == null || scene['videoUrl'].toString().isEmpty) {
      return ElevatedButton.icon(
        onPressed: isReadOnly ? null : () => onVideoSelected(scene),
        icon: const Icon(Icons.video_call),
        label: const Text('Add Video'),
      );
    }

    return Row(
      children: [
        Expanded(
          child: StreamBuilder<VideoGenerationProgress>(
            stream: scene['videoType'] == VideoCreationService.VIDEO_TYPE_AI
                ? VideoCreationService().generateAIVideo(
                    sceneText: scene['text'],
                    movieId: movieId,
                    sceneId: scene['documentId'],
                  )
                : null,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final progress = snapshot.data?.progress ?? 0.0;
                final status = snapshot.data?.status ?? 'Initializing...';
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(value: progress),
                    Text(status),
                  ],
                );
              }
              
              return Row(
                children: [
                  Icon(
                    scene['videoType'] == VideoCreationService.VIDEO_TYPE_AI
                        ? Icons.auto_awesome
                        : Icons.videocam,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 8),
                  const Text('Video Ready'),
                ],
              );
            },
          ),
        ),
        if (!isReadOnly)
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _handleVideoDelete(context),
            tooltip: 'Delete Video',
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
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
              children: const [
                Icon(
                  Icons.delete,
                  color: Colors.white,
                  size: 32,
                ),
                SizedBox(height: 4),
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
                children: const [
                  Icon(Icons.warning, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete Scene'),
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
      onDismissed: (_) => onDelete(scene),
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
                  if (scene['directorNotes'] != null && scene['directorNotes'].toString().isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
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
                            scene['text'],
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
                  if (scene['videoType'] == 'ai')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome, color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          Text(
                            'AI Generated Video',
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (scene['videoUrl'] != null && scene['videoUrl'].toString().isNotEmpty)
                        TextButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => MovieVideoPlayerScreen(
                                  scenes: [scene],
                                  initialIndex: 0,
                                  movieId: movieId,
                                  userId: scene['userId'] ?? '',
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.play_circle_outline),
                          label: const Text('Watch Video'),
                        ),
                      if (!isReadOnly)
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.video_library),
                          tooltip: 'Add Video',
                          itemBuilder: (context) => [
                            if (scene['status'] != 'pending') ...[
                              const PopupMenuItem(
                                value: 'remove',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text('Remove Video', style: TextStyle(color: Colors.red)),
                                  ],
                                ),
                              ),
                              const PopupMenuDivider(),
                            ],
                            const PopupMenuItem(
                              value: 'generate_ai',
                              child: Row(
                                children: [
                                  Icon(Icons.auto_awesome),
                                  SizedBox(width: 8),
                                  Text('Generate AI Video'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'upload',
                              child: Row(
                                children: [
                                  Icon(Icons.upload_file),
                                  SizedBox(width: 8),
                                  Text('Upload Video'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'capture',
                              child: Row(
                                children: [
                                  Icon(Icons.videocam),
                                  SizedBox(width: 8),
                                  Text('Capture Video'),
                                ],
                              ),
                            ),
                          ],
                          onSelected: (action) async {
                            switch (action) {
                              case 'remove':
                                await _handleVideoDelete(context);
                                break;
                              case 'generate_ai':
                                await _handleAIVideoGeneration(context);
                                break;
                              case 'upload':
                                await _handleVideoUpload(context, false);
                                break;
                              case 'capture':
                                await _handleVideoUpload(context, true);
                                break;
                            }
                          },
                        ),
                      if (!isReadOnly)
                        TextButton.icon(
                          onPressed: () => _handleDirectorCut(context),
                          icon: const Icon(Icons.movie_creation),
                          label: const Text('Director\'s Cut'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.blue,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 