import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../services/video/video_editor_service.dart';
import 'package:path_provider/path_provider.dart';

class VideoEditorScreen extends StatefulWidget {
  final File videoFile;

  const VideoEditorScreen({
    super.key,
    required this.videoFile,
  });

  @override
  State<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends State<VideoEditorScreen> {
  late VideoPlayerController _controller;
  final VideoEditorService _editorService = VideoEditorService();
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _startTrim = Duration.zero;
  Duration _endTrim = Duration.zero;
  List<File> _splitClips = [];
  bool _isTrimming = false;
  bool _isSplitting = false;
  bool _isProcessing = false;
  double _speedFactor = 1.0;
  String? _selectedFilter;
  double _filterIntensity = 1.0;
  TextEditingController _textController = TextEditingController();
  Map<String, dynamic> _textStyle = {
    'fontSize': 24.0,
    'color': 'white',
    'shadowColor': 'black@0.5',
    'shadowOffset': const Offset(2, 2),
  };
  Offset _textPosition = const Offset(10, 10);

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    _controller = VideoPlayerController.file(widget.videoFile);
    await _controller.initialize();
    _endTrim = _controller.value.duration;
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _trimVideo() async {
    setState(() => _isTrimming = true);
    try {
      final trimmedVideo = await _editorService.trimVideo(
        videoFile: widget.videoFile,
        startTime: _startTrim,
        endTime: _endTrim,
      );

      if (trimmedVideo != null) {
        // Reinitialize player with trimmed video
        await _controller.dispose();
        _controller = VideoPlayerController.file(trimmedVideo);
        await _controller.initialize();
        setState(() {
          _startTrim = Duration.zero;
          _endTrim = _controller.value.duration;
        });
      }
    } finally {
      setState(() => _isTrimming = false);
    }
  }

  Future<void> _splitVideo() async {
    setState(() => _isSplitting = true);
    try {
      final splits = await _editorService.splitVideo(
        videoFile: widget.videoFile,
        splitPoint: _currentPosition,
      );

      if (splits != null) {
        setState(() => _splitClips = splits);
      }
    } finally {
      setState(() => _isSplitting = false);
    }
  }

  Future<void> _mergeClips() async {
    if (_splitClips.length < 2) return;

    final merged = await _editorService.mergeClips(
      videoFiles: _splitClips,
      transitionEffect: 'fade', // Default transition
    );

    if (merged != null) {
      // Reinitialize player with merged video
      await _controller.dispose();
      _controller = VideoPlayerController.file(merged);
      await _controller.initialize();
      setState(() {
        _splitClips = [];
        _startTrim = Duration.zero;
        _endTrim = _controller.value.duration;
      });
    }
  }

  Future<void> _applyFilter() async {
    if (_selectedFilter == null) return;

    setState(() => _isProcessing = true);
    try {
      final filteredVideo = await _editorService.applyFilter(
        videoFile: widget.videoFile,
        filterType: _selectedFilter!,
        intensity: _filterIntensity,
      );

      if (filteredVideo != null) {
        await _controller.dispose();
        _controller = VideoPlayerController.file(filteredVideo);
        await _controller.initialize();
        setState(() {});
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _addText() async {
    if (_textController.text.isEmpty) return;

    setState(() => _isProcessing = true);
    try {
      final videoWithText = await _editorService.addTextOverlay(
        videoFile: widget.videoFile,
        text: _textController.text,
        textStyle: _textStyle,
        position: _textPosition,
      );

      if (videoWithText != null) {
        await _controller.dispose();
        _controller = VideoPlayerController.file(videoWithText);
        await _controller.initialize();
        setState(() {});
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _adjustSpeed() async {
    if (_speedFactor == 1.0) return;

    setState(() => _isProcessing = true);
    try {
      final adjustedVideo = await _editorService.adjustSpeed(
        videoFile: widget.videoFile,
        speedFactor: _speedFactor,
      );

      if (adjustedVideo != null) {
        await _controller.dispose();
        _controller = VideoPlayerController.file(adjustedVideo);
        await _controller.initialize();
        setState(() {});
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Widget _buildVideoPlayer() {
    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: VideoPlayer(_controller),
    );
  }

  Widget _buildTimelineSlider() {
    return Slider(
      value: _currentPosition.inMilliseconds.toDouble(),
      min: 0,
      max: _controller.value.duration.inMilliseconds.toDouble(),
      onChanged: (value) {
        setState(() {
          _currentPosition = Duration(milliseconds: value.toInt());
        });
        _controller.seekTo(_currentPosition);
      },
    );
  }

  Widget _buildTrimControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton(
          onPressed: _isTrimming ? null : _trimVideo,
          child: _isTrimming 
            ? const CircularProgressIndicator()
            : const Text('Trim Video'),
        ),
        ElevatedButton(
          onPressed: _isSplitting ? null : _splitVideo,
          child: _isSplitting 
            ? const CircularProgressIndicator()
            : const Text('Split at Current Position'),
        ),
        if (_splitClips.isNotEmpty)
          ElevatedButton(
            onPressed: _mergeClips,
            child: const Text('Merge Clips'),
          ),
      ],
    );
  }

  Widget _buildPlaybackControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
          onPressed: () {
            setState(() {
              _isPlaying = !_isPlaying;
              _isPlaying ? _controller.play() : _controller.pause();
            });
          },
        ),
        Text(
          '${_currentPosition.toString().split('.').first} / '
          '${_controller.value.duration.toString().split('.').first}',
        ),
      ],
    );
  }

  Widget _buildAdvancedControls() {
    return Column(
      children: [
        // Filter controls
        ExpansionTile(
          title: const Text('Filters'),
          children: [
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Normal'),
                  selected: _selectedFilter == null,
                  onSelected: (selected) {
                    setState(() => _selectedFilter = null);
                  },
                ),
                ChoiceChip(
                  label: const Text('Brightness'),
                  selected: _selectedFilter == 'brightness',
                  onSelected: (selected) {
                    setState(() => _selectedFilter = selected ? 'brightness' : null);
                  },
                ),
                ChoiceChip(
                  label: const Text('Contrast'),
                  selected: _selectedFilter == 'contrast',
                  onSelected: (selected) {
                    setState(() => _selectedFilter = selected ? 'contrast' : null);
                  },
                ),
                ChoiceChip(
                  label: const Text('Saturation'),
                  selected: _selectedFilter == 'saturation',
                  onSelected: (selected) {
                    setState(() => _selectedFilter = selected ? 'saturation' : null);
                  },
                ),
                ChoiceChip(
                  label: const Text('Sepia'),
                  selected: _selectedFilter == 'sepia',
                  onSelected: (selected) {
                    setState(() => _selectedFilter = selected ? 'sepia' : null);
                  },
                ),
                ChoiceChip(
                  label: const Text('Grayscale'),
                  selected: _selectedFilter == 'grayscale',
                  onSelected: (selected) {
                    setState(() => _selectedFilter = selected ? 'grayscale' : null);
                  },
                ),
              ],
            ),
            if (_selectedFilter != null && _selectedFilter != 'sepia' && _selectedFilter != 'grayscale')
              Slider(
                value: _filterIntensity,
                min: 0.0,
                max: 2.0,
                divisions: 20,
                label: _filterIntensity.toStringAsFixed(1),
                onChanged: (value) {
                  setState(() => _filterIntensity = value);
                },
              ),
            ElevatedButton(
              onPressed: _selectedFilter != null && !_isProcessing ? _applyFilter : null,
              child: _isProcessing 
                ? const CircularProgressIndicator()
                : const Text('Apply Filter'),
            ),
          ],
        ),

        // Text overlay controls
        ExpansionTile(
          title: const Text('Text Overlay'),
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _textController,
                decoration: const InputDecoration(
                  labelText: 'Enter text',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.format_size),
                  onPressed: () {
                    // Show font size picker
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Font Size'),
                        content: Slider(
                          value: _textStyle['fontSize'],
                          min: 12,
                          max: 72,
                          divisions: 60,
                          label: _textStyle['fontSize'].toString(),
                          onChanged: (value) {
                            setState(() {
                              _textStyle['fontSize'] = value;
                            });
                          },
                        ),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.color_lens),
                  onPressed: () {
                    // Show color picker
                    // Implement color picker dialog
                  },
                ),
              ],
            ),
            ElevatedButton(
              onPressed: !_isProcessing ? _addText : null,
              child: _isProcessing 
                ? const CircularProgressIndicator()
                : const Text('Add Text'),
            ),
          ],
        ),

        // Speed control
        ExpansionTile(
          title: const Text('Speed'),
          children: [
            Slider(
              value: _speedFactor,
              min: 0.5,
              max: 2.0,
              divisions: 15,
              label: '${_speedFactor}x',
              onChanged: (value) {
                setState(() => _speedFactor = value);
              },
            ),
            ElevatedButton(
              onPressed: _speedFactor != 1.0 && !_isProcessing ? _adjustSpeed : null,
              child: _isProcessing 
                ? const CircularProgressIndicator()
                : const Text('Adjust Speed'),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Editor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {
              // TODO: Implement save functionality
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            ),
            _buildTimelineSlider(),
            _buildPlaybackControls(),
            _buildTrimControls(),
            _buildAdvancedControls(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
} 