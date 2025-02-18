import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/movie/movie_video_service.dart';
import '../widgets/video_thumbnail.dart';
import '../widgets/video_player_modal.dart';

class SceneCard extends StatelessWidget {
  final Map<String, dynamic> scene;
  final String movieId;
  final VoidCallback? onVideoUploaded;
  final bool isReadOnly;

  const SceneCard({
    Key? key,
    required this.scene,
    required this.movieId,
    this.onVideoUploaded,
    this.isReadOnly = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool needsVideo = scene['needsVideo'] == true;
    final String videoStatus = scene['status'] ?? 'pending';
    final bool hasVideo = !needsVideo;
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            title: Text(
              scene['title'] ?? 'Scene ${scene['id']}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(scene['text'] ?? ''),
            trailing: _buildVideoStatusIndicator(videoStatus),
          ),
          if (!isReadOnly) _buildVideoSection(context, hasVideo, videoStatus),
        ],
      ),
    );
  }

  Widget _buildVideoStatusIndicator(String status) {
    IconData icon;
    Color color;
    String tooltip;

    switch (status) {
      case 'generating':
        icon = Icons.movie_creation;
        color = Colors.orange;
        tooltip = 'Generating video...';
        break;
      case 'uploading':
        icon = Icons.cloud_upload;
        color = Colors.blue;
        tooltip = 'Uploading video...';
        break;
      case 'complete':
        icon = Icons.check_circle;
        color = Colors.green;
        tooltip = 'Video ready';
        break;
      case 'error':
        icon = Icons.error;
        color = Colors.red;
        tooltip = 'Error with video';
        break;
      default:
        icon = Icons.movie_filter;
        color = Colors.grey;
        tooltip = 'No video';
    }

    return Tooltip(
      message: tooltip,
      child: Icon(icon, color: color),
    );
  }

  Widget _buildVideoSection(BuildContext context, bool hasVideo, String status) {
    if (status == 'generating' || status == 'uploading') {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Text(
              status == 'generating' ? 'Generating video...' : 'Uploading video...',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    if (hasVideo) {
      return Stack(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
                image: scene['thumbnailUrl'] != null ? DecorationImage(
                  image: NetworkImage(scene['thumbnailUrl']),
                  fit: BoxFit.cover,
                ) : null,
              ),
              child: VideoThumbnail(
                videoUrl: scene['videoUrl']!,
                onTap: () => _showVideoPlayer(context),
              ),
            ),
          ),
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showVideoPlayer(context),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: const Icon(
                      Icons.play_circle_fill,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    scene['videoType'] == 'ai' ? Icons.auto_awesome : Icons.videocam,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    scene['videoType'] == 'ai' ? 'AI Generated' : 'Recorded',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton.icon(
            onPressed: () => _showVideoSourcePicker(context),
            icon: const Icon(Icons.videocam),
            label: const Text('Record Video'),
          ),
          ElevatedButton.icon(
            onPressed: () => _generateAIVideo(context),
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Generate AI Video'),
          ),
        ],
      ),
    );
  }

  void _showVideoPlayer(BuildContext context) {
    // Show video player modal
    showDialog(
      context: context,
      builder: (context) => VideoPlayerModal(
        videoUrl: scene['videoUrl'],
        title: scene['title'] ?? 'Scene ${scene['id']}',
      ),
    );
  }

  void _showVideoSourcePicker(BuildContext context) async {
    final movieVideoService = Provider.of<MovieVideoService>(context, listen: false);
    
    try {
      await movieVideoService.uploadVideoForScene(
        movieId: movieId,
        sceneId: scene['documentId'],
        onProgress: (progress) {
          // Progress is handled by the status field in Firestore
        },
      );
      
      onVideoUploaded?.call();
    } catch (e) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to upload video: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _generateAIVideo(BuildContext context) async {
    final movieVideoService = Provider.of<MovieVideoService>(context, listen: false);
    
    try {
      await movieVideoService.generateVideo(
        movieId: movieId,
        sceneId: scene['documentId'],
        sceneText: scene['text'],
      );
    } catch (e) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to generate video: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }
} 