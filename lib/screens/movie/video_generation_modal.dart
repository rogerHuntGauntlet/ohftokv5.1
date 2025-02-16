import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/movie/movie_video_service.dart';

class VideoGenerationProgress {
  final String stage;
  final double percentage;

  VideoGenerationProgress({
    required this.stage,
    required this.percentage,
  });
}

class VideoGenerationModal extends StatefulWidget {
  final String sceneText;
  final String movieId;
  final String sceneId;
  final Function(String videoUrl, String videoId) onVideoReady;
  final Stream<VideoGenerationProgress>? progressStream;

  const VideoGenerationModal({
    super.key,
    required this.sceneText,
    required this.movieId,
    required this.sceneId,
    required this.onVideoReady,
    this.progressStream,
  });

  @override
  State<VideoGenerationModal> createState() => _VideoGenerationModalState();
}

class _VideoGenerationModalState extends State<VideoGenerationModal> {
  late Timer _statusCheckTimer;
  String _currentStage = 'starting';
  double _progress = 0.0;
  bool _hasError = false;
  String _errorMessage = '';
  String? _videoUrl;
  String? _predictionId;
  final MovieVideoService _videoService = MovieVideoService();
  final StreamController<VideoGenerationProgress>? progressController = StreamController<VideoGenerationProgress>();

  final List<String> _stages = [
    'starting',
    'analyzing',
    'processing',
    'downloading',
    'uploading',
    'completed'
  ];

  @override
  void initState() {
    super.initState();
    _startVideoGeneration();
  }

  @override
  void dispose() {
    _statusCheckTimer.cancel();
    progressController?.close();
    super.dispose();
  }

  Future<void> _startVideoGeneration() async {
    try {
      // Start Replicate generation
      setState(() {
        _currentStage = 'starting';
        _progress = 0.1;
      });

      _predictionId = await _videoService.startReplicateGeneration(widget.sceneText);
      
      // Start polling for status
      _startStatusPolling();

    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  void _startStatusPolling() {
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      try {
        if (_predictionId == null) {
          timer.cancel();
          return;
        }

        final status = await _videoService.checkReplicateStatus(_predictionId!);
        
        switch (status['status']) {
          case 'starting':
            setState(() {
              _currentStage = 'starting';
              _progress = 0.2;
            });
            progressController?.add(VideoGenerationProgress(
              stage: 'starting',
              percentage: 0.2,
            ));
            break;
          case 'processing':
            setState(() {
              _currentStage = 'processing';
              _progress = 0.4;
            });
            progressController?.add(VideoGenerationProgress(
              stage: 'processing',
              percentage: 0.4,
            ));
            break;
          case 'succeeded':
            timer.cancel();
            final videoUrl = status['output'];
            if (videoUrl != null) {
              setState(() {
                _currentStage = 'downloading';
                _progress = 0.6;
              });
              progressController?.add(VideoGenerationProgress(
                stage: 'downloading',
                percentage: 0.6,
              ));
              await _processCompletedVideo(videoUrl);
            } else {
              throw 'No video URL in completed status';
            }
            break;
          case 'failed':
            timer.cancel();
            throw status['error'] ?? 'Video generation failed';
          default:
            setState(() {
              _currentStage = 'processing';
              _progress = 0.3;
            });
            progressController?.add(VideoGenerationProgress(
              stage: 'processing',
              percentage: 0.3,
            ));
        }
      } catch (e) {
        timer.cancel();
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    });
  }

  Future<void> _processCompletedVideo(String replicateUrl) async {
    try {
      setState(() {
        _currentStage = 'downloading';
        _progress = 0.6;
      });
      progressController?.add(VideoGenerationProgress(
        stage: 'downloading',
        percentage: 0.6,
      ));

      // Process and upload the video
      final result = await _videoService.processAndUploadVideo(
        replicateUrl,
        widget.movieId,
        widget.sceneId,
        _predictionId!,
      );

      setState(() {
        _currentStage = 'completed';
        _progress = 1.0;
        _videoUrl = result['videoUrl'];
      });
      progressController?.add(VideoGenerationProgress(
        stage: 'completed',
        percentage: 1.0,
      ));

      // Update Firestore
      await FirebaseFirestore.instance
          .collection('movies')
          .doc(widget.movieId)
          .collection('scenes')
          .doc(widget.sceneId)
          .update({
        'videoUrl': result['videoUrl'],
        'videoId': result['videoId'],
        'status': 'completed',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      widget.onVideoReady(result['videoUrl']!, result['videoId']!);

    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  String _getStageTitle(String stage) {
    switch (stage) {
      case 'starting':
        return 'Initializing';
      case 'analyzing':
        return 'Analyzing Scene';
      case 'processing':
        return 'AI Model Processing';
      case 'downloading':
        return 'Downloading Video';
      case 'uploading':
        return 'Saving Video';
      case 'completed':
        return 'Video Ready!';
      default:
        return 'Processing...';
    }
  }

  bool _isStageCompleted(String stage) {
    final currentIndex = _stages.indexOf(_currentStage);
    final stageIndex = _stages.indexOf(stage);
    return currentIndex > stageIndex && stageIndex != -1;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Generating Video',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              ..._stages.map((stage) {
                final isActive = _currentStage == stage;
                final isCompleted = _isStageCompleted(stage);
                
                return Column(
                  children: [
                    _buildProgressStep(
                      _getStageTitle(stage),
                      isActive: isActive,
                      isCompleted: !_hasError && isCompleted,
                      percentage: isActive ? _progress : null,
                      hasError: _hasError && _currentStage == stage,
                    ),
                    if (_stages.indexOf(stage) < _stages.length - 1) 
                      const SizedBox(height: 16),
                  ],
                );
              }).toList(),
              
              if (_hasError) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red[700]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Video Processing Failed',
                              style: TextStyle(
                                color: Colors.red[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage,
                        style: TextStyle(color: Colors.red[700]),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Close'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              if (_currentStage == 'completed') ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle_outline, color: Colors.green[700]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Video Generation Complete',
                              style: TextStyle(
                                color: Colors.green[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Close'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Scene:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.sceneText,
                      style: const TextStyle(
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressStep(
    String title, {
    required bool isActive,
    required bool isCompleted,
    double? percentage,
    bool hasError = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hasError
                    ? Colors.red
                    : isCompleted
                        ? Colors.green
                        : isActive
                            ? Colors.blue
                            : Colors.grey[300],
              ),
              child: Center(
                child: hasError
                    ? const Icon(Icons.close, color: Colors.white, size: 16)
                    : isCompleted
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
                color: hasError
                    ? Colors.red
                    : isActive || isCompleted
                        ? Colors.black
                        : Colors.grey,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (isActive && percentage != null) ...[
              const Spacer(),
              Text(
                '${(percentage * 100).round()}%',
                style: const TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
        if (isActive && percentage != null) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: percentage,
            backgroundColor: Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
        ],
      ],
    );
  }
} 