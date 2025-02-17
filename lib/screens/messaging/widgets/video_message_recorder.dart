import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../../../services/video_message_service.dart';

class VideoMessageRecorder extends StatefulWidget {
  final Function(String videoUrl) onVideoRecorded;

  const VideoMessageRecorder({
    Key? key,
    required this.onVideoRecorded,
  }) : super(key: key);

  @override
  State<VideoMessageRecorder> createState() => _VideoMessageRecorderState();
}

class _VideoMessageRecorderState extends State<VideoMessageRecorder> {
  final _videoService = VideoMessageService();
  bool _isInitialized = false;
  Duration _recordingDuration = Duration.zero;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      await _videoService.initializeCamera();
      setState(() => _isInitialized = true);
    } catch (e) {
      // Show error dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to initialize camera: $e'),
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

  void _startRecording() async {
    try {
      await _videoService.startRecording();
      setState(() => _recordingDuration = Duration.zero);
      _timer = Timer.periodic(
        const Duration(seconds: 1),
        (timer) => setState(() => _recordingDuration += const Duration(seconds: 1)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start recording: $e')),
        );
      }
    }
  }

  void _stopRecording() async {
    try {
      _timer.cancel();
      final videoUrl = await _videoService.stopRecording();
      widget.onVideoRecorded(videoUrl);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to stop recording: $e')),
        );
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    if (_videoService.isRecording) {
      _timer.cancel();
    }
    _videoService.disposeCamera();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        // Camera preview
        SizedBox.expand(
          child: CameraPreview(_videoService.cameraController!),
        ),

        // Recording duration
        if (_videoService.isRecording)
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.fiber_manual_record,
                    color: Colors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDuration(_recordingDuration),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Recording controls
        Positioned(
          bottom: 32,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FloatingActionButton(
                onPressed: _videoService.isRecording ? _stopRecording : _startRecording,
                backgroundColor: _videoService.isRecording ? Colors.red : Colors.white,
                child: Icon(
                  _videoService.isRecording ? Icons.stop : Icons.fiber_manual_record,
                  color: _videoService.isRecording ? Colors.white : Colors.red,
                  size: 32,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
} 