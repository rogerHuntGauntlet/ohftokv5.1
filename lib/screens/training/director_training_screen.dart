import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/famous_directors.dart';
import '../../services/ai/training_feedback_service.dart';
import '../../models/training_scene.dart';
import '../../models/director.dart';
import 'package:camera/camera.dart';
import 'dart:io';

class DirectorTrainingScreen extends StatefulWidget {
  final String? initialVideoPath;

  const DirectorTrainingScreen({
    super.key,
    this.initialVideoPath,
  });

  @override
  State<DirectorTrainingScreen> createState() => _DirectorTrainingScreenState();
}

class _DirectorTrainingScreenState extends State<DirectorTrainingScreen> {
  Director? _selectedDirector;
  String? _videoPath;
  bool _isLoading = false;
  String? _feedback;
  bool _isRecording = false;
  final TrainingFeedbackService _feedbackService = TrainingFeedbackService();
  CameraController? _cameraController;
  bool _showCamera = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialVideoPath != null) {
      _videoPath = widget.initialVideoPath;
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _cameraController = CameraController(
      cameras.first,
      ResolutionPreset.high,
      enableAudio: true,
    );

    try {
      await _cameraController!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing camera: $e')),
        );
      }
    }
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final video = await picker.pickVideo(source: ImageSource.gallery);
    
    if (video != null) {
      setState(() {
        _videoPath = video.path;
        _showCamera = false;
        _feedback = null;
      });
    }
  }

  Future<void> _showVideoOptions() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('Upload Video'),
            subtitle: const Text('Choose an existing video'),
            onTap: () {
              Navigator.pop(context);
              _pickVideo();
            },
          ),
          ListTile(
            leading: const Icon(Icons.videocam),
            title: const Text('Record New Video'),
            subtitle: const Text('Use camera to record scene'),
            onTap: () async {
              Navigator.pop(context);
              await _initializeCamera();
              setState(() {
                _showCamera = true;
                _videoPath = null;
                _feedback = null;
              });
            },
          ),
        ],
      ),
    );
  }

  Future<void> _startRecording() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    try {
      await _cameraController!.startVideoRecording();
      setState(() => _isRecording = true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting recording: $e')),
      );
    }
  }

  Future<void> _stopRecording() async {
    if (_cameraController == null || !_cameraController!.value.isRecordingVideo) return;

    try {
      final video = await _cameraController!.stopVideoRecording();
      setState(() {
        _isRecording = false;
        _videoPath = video.path;
        _showCamera = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error stopping recording: $e')),
      );
    }
  }

  Future<void> _getFeedback() async {
    if (_videoPath == null || _selectedDirector == null) return;

    setState(() {
      _isLoading = true;
      _feedback = null;
    });

    try {
      final feedback = await _feedbackService.getFeedback(
        _videoPath!,
        _selectedDirector!,
        TrainingScene.newAttempt(videoPath: _videoPath!),
      );

      setState(() {
        _feedback = feedback;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting feedback: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Director Analysis'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showHelp,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Step 1: Upload or Record Video
            const Text(
              '1. Your Scene',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Upload a video or record a new scene for analysis',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            if (_showCamera && _cameraController != null && _cameraController!.value.isInitialized)
              Card(
                elevation: 4,
                child: Column(
                  children: [
                    AspectRatio(
                      aspectRatio: _cameraController!.value.aspectRatio,
                      child: CameraPreview(_cameraController!),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            icon: Icon(_isRecording ? Icons.stop : Icons.videocam),
                            label: Text(_isRecording ? 'Stop' : 'Record'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isRecording ? Colors.red : null,
                            ),
                            onPressed: _isRecording ? _stopRecording : _startRecording,
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.close),
                            label: const Text('Cancel'),
                            onPressed: () {
                              setState(() => _showCamera = false);
                              _cameraController?.dispose();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else if (_videoPath != null)
              Card(
                elevation: 4,
                child: Column(
                  children: [
                    AspectRatio(
                      aspectRatio: 16/9,
                      child: Container(
                        color: Colors.black,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              color: Colors.grey[900],
                              child: const Center(
                                child: Icon(
                                  Icons.video_library,
                                  size: 64,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: const Text('Change Video'),
                            onPressed: _showVideoOptions,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              Card(
                elevation: 4,
                child: InkWell(
                  onTap: _showVideoOptions,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Icon(Icons.add_a_photo, size: 48),
                        const SizedBox(height: 16),
                        const Text(
                          'Tap to Upload or Record Video',
                          style: TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Select an existing video or record a new one',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 32),

            // Step 2: Select Director
            const Text(
              '2. Choose Director',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select a director to analyze your scene',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            _buildDirectorSelector(),

            if (_videoPath != null && _selectedDirector != null) ...[
              const SizedBox(height: 32),
              // Step 3: Get Feedback
              const Text(
                '3. Director\'s Analysis',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              if (_feedback == null)
                Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.analytics),
                    label: const Text('Get Director\'s Analysis'),
                    onPressed: _isLoading ? null : _getFeedback,
                  ),
                )
              else
                _buildFeedbackSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDirectorSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 5,
              ),
            ],
          ),
          child: DropdownButtonFormField<Director>(
            value: _selectedDirector,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Select a Director',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            items: famousDirectors.map((director) {
              return DropdownMenuItem(
                value: director,
                child: Text(
                  director.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              );
            }).toList(),
            onChanged: (director) {
              setState(() {
                _selectedDirector = director;
                _feedback = null;
              });
            },
          ),
        ),
        if (_selectedDirector != null) ...[
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.blue[100],
                        child: const Icon(Icons.movie_filter, color: Colors.blue),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedDirector!.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Directing Style Analysis',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Text(
                    _selectedDirector!.description,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Grading Criteria',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedDirector!.style,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFeedbackSection() {
    return Card(
      elevation: 4,
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue[700],
                  child: const Icon(Icons.movie_creation, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Feedback from ${_selectedDirector!.name}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              Text(
                _feedback!,
                style: const TextStyle(
                  height: 1.5,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.help_outline, color: Colors.blue),
            const SizedBox(width: 8),
            const Flexible(
              child: Text('How Director Analysis Works'),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '1. Submit Your Scene',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('Upload an existing video or record a new scene.'),
            SizedBox(height: 12),
            Text(
              '2. Choose a Director',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('Select a famous director to analyze your scene.'),
            SizedBox(height: 12),
            Text(
              '3. Get Analysis',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('Receive detailed feedback on your scene from the director\'s perspective.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }
} 