import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class MovieVideoPlayerScreen extends StatefulWidget {
  final List<Map<String, dynamic>> scenes;
  final int initialIndex;

  const MovieVideoPlayerScreen({
    super.key,
    required this.scenes,
    this.initialIndex = 0,
  });

  @override
  State<MovieVideoPlayerScreen> createState() => _MovieVideoPlayerScreenState();
}

class _MovieVideoPlayerScreenState extends State<MovieVideoPlayerScreen> {
  late PageController _pageController;
  late List<VideoPlayerController> _videoControllers;
  late List<ChewieController?> _chewieControllers;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _videoControllers = List.generate(
      widget.scenes.length,
      (index) => VideoPlayerController.network(widget.scenes[index]['videoUrl']),
    );
    _chewieControllers = List.generate(widget.scenes.length, (index) => null);
    _initializeControllers();
  }

  Future<void> _initializeControllers() async {
    // Initialize current and adjacent controllers
    final indicesToInit = [
      if (_currentIndex > 0) _currentIndex - 1,
      _currentIndex,
      if (_currentIndex < widget.scenes.length - 1) _currentIndex + 1,
    ];

    for (final index in indicesToInit) {
      await _initializeController(index);
    }
  }

  Future<void> _initializeController(int index) async {
    if (_chewieControllers[index] != null) return;

    try {
      await _videoControllers[index].initialize();
      
      if (!mounted) return;

      setState(() {
        _chewieControllers[index] = ChewieController(
          videoPlayerController: _videoControllers[index],
          autoPlay: index == _currentIndex,
          looping: true,
          aspectRatio: _videoControllers[index].value.aspectRatio,
          errorBuilder: (context, errorMessage) {
            return Center(
              child: Text(
                'Error: $errorMessage',
                style: const TextStyle(color: Colors.white),
              ),
            );
          },
        );
      });
    } catch (e) {
      print('Error initializing video controller $index: $e');
    }
  }

  Future<void> _onPageChanged(int index) async {
    // Pause current video
    _chewieControllers[_currentIndex]?.pause();
    
    setState(() => _currentIndex = index);

    // Initialize adjacent controllers if needed
    final indicesToInit = [
      if (index > 0) index - 1,
      index,
      if (index < widget.scenes.length - 1) index + 1,
    ];

    for (final i in indicesToInit) {
      await _initializeController(i);
    }

    // Play new video
    _chewieControllers[index]?.play();

    // Dispose controllers that are no longer needed
    for (var i = 0; i < _chewieControllers.length; i++) {
      if (!indicesToInit.contains(i) && _chewieControllers[i] != null) {
        _chewieControllers[i]!.dispose();
        _chewieControllers[i] = null;
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final controller in _videoControllers) {
      controller.dispose();
    }
    for (final controller in _chewieControllers) {
      controller?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        itemCount: widget.scenes.length,
        itemBuilder: (context, index) {
          if (_chewieControllers[index] == null) {
            return const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            );
          }

          return Stack(
            children: [
              Center(
                child: Chewie(
                  controller: _chewieControllers[index]!,
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 32,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Scene ${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.scenes[index]['text'],
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
} 