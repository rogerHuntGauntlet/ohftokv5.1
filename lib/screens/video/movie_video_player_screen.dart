import 'package:flutter/material.dart';
import '../video/components/video_player.dart';
import '../../services/fork_services/fork_service.dart';
import '../../services/user_service.dart';
import '../../models/user.dart' as app_models;
import 'package:provider/provider.dart';
import '../movie/movie_scenes_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MovieVideoPlayerScreen extends StatefulWidget {
  final List<Map<String, dynamic>> scenes;
  final int initialIndex;
  final String movieId;
  final String userId;

  const MovieVideoPlayerScreen({
    super.key,
    required this.scenes,
    required this.movieId,
    required this.userId,
    this.initialIndex = 0,
  });

  @override
  State<MovieVideoPlayerScreen> createState() => _MovieVideoPlayerScreenState();
}

class _MovieVideoPlayerScreenState extends State<MovieVideoPlayerScreen> {
  late PageController _pageController;
  int _currentIndex = 0;
  final UserService _userService = UserService();
  Map<String, String> _directorPhotos = {};

  // Helper function to navigate to forked movie
  Future<void> _navigateToForkedMovie(BuildContext context, String newMovieId) async {
    try {
      final forkService = ForkService();
      final movie = await forkService.getMovie(newMovieId);
      
      if (context.mounted) {
        // Pop until we reach the main navigation stack
        Navigator.of(context).popUntil((route) => route.isFirst);
        
        // Navigate to the new movie's scenes screen
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MovieScenesScreen(
              movieIdea: movie['movieIdea'],
              scenes: List<Map<String, dynamic>>.from(movie['scenes']),
              movieId: newMovieId,
              movieTitle: movie['title'],
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error navigating to forked movie: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  Future<void> _loadDirectorPhoto(String userId) async {
    if (_directorPhotos.containsKey(userId)) return;
    
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (doc.exists && mounted) {
        final user = app_models.User.fromFirestore(doc);
        setState(() {
          _directorPhotos[userId] = user.photoUrl ?? 'https://via.placeholder.com/48';
        });
      }
    } catch (e) {
      print('Error loading director photo: $e');
      _directorPhotos[userId] = 'https://via.placeholder.com/48';
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Filter scenes that have videos
    final scenesWithVideos = widget.scenes.where((scene) => 
      scene['videoUrl'] != null && scene['videoUrl'].toString().isNotEmpty
    ).toList();

    if (scenesWithVideos.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Text('No videos available'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity! < 0 && _currentIndex > 0) {
            // Swipe up to previous video
            _pageController.previousPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          } else if (details.primaryVelocity! > 0 && _currentIndex < scenesWithVideos.length - 1) {
            // Swipe down to next video
            _pageController.nextPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        },
        child: Stack(
          children: [
            // Video PageView
            PageView.builder(
              physics: const NeverScrollableScrollPhysics(), // Disable PageView scrolling
              controller: _pageController,
              scrollDirection: Axis.vertical,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
              },
              itemCount: scenesWithVideos.length,
              itemBuilder: (context, index) {
                final scene = scenesWithVideos[index];
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // Video Player
                    VideoPlayer(
                      videoUrl: scene['videoUrl']!,
                      autoPlay: index == _currentIndex,
                      showControls: true,
                      fit: BoxFit.cover,
                    ),
                    
                    // Scene Info Overlay
                    Positioned(
                      left: 16,
                      right: MediaQuery.of(context).size.width * 0.25, // Make it 75% width
                      bottom: 85,
                      child: GestureDetector(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.black.withOpacity(0.8),
                            isScrollControlled: true,
                            builder: (context) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                              decoration: const BoxDecoration(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Scene ${scene['id']}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        icon: const Icon(Icons.close, color: Colors.white),
                                        onPressed: () => Navigator.pop(context),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    scene['text'],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 40),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      // Close the current bottom sheet
                                      Navigator.pop(context);
                                      // Show fork options dialog
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          backgroundColor: Colors.grey[900],
                                          title: const Text(
                                            'Fork Options',
                                            style: TextStyle(color: Colors.white),
                                          ),
                                          content: const Text(
                                            'Do you want to fork just this scene, or this scene and all scenes before it?',
                                            style: TextStyle(color: Colors.white70),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () async {
                                                Navigator.pop(context);
                                                // Show loading dialog with 4-second timer
                                                showDialog(
                                                  context: context,
                                                  barrierDismissible: false,
                                                  builder: (context) => FutureBuilder(
                                                    future: Future.delayed(const Duration(seconds: 4)),
                                                    builder: (context, snapshot) {
                                                      if (snapshot.connectionState == ConnectionState.done) {
                                                        return Center(
                                                          child: Card(
                                                            color: Colors.black87,
                                                            child: Padding(
                                                              padding: const EdgeInsets.all(32.0),
                                                              child: Column(
                                                                mainAxisSize: MainAxisSize.min,
                                                                children: [
                                                                  const Icon(
                                                                    Icons.check_circle,
                                                                    color: Colors.green,
                                                                    size: 48,
                                                                  ),
                                                                  const SizedBox(height: 16),
                                                                  const Text(
                                                                    'Fork created successfully!',
                                                                    style: TextStyle(color: Colors.white),
                                                                  ),
                                                                  const SizedBox(height: 24),
                                                                  ElevatedButton.icon(
                                                                    onPressed: () {
                                                                      Navigator.of(context).popUntil((route) => route.isFirst);
                                                                      // Wait for next frame to ensure DefaultTabController is ready
                                                                      Future.microtask(() {
                                                                        final tabController = DefaultTabController.of(context);
                                                                        if (tabController != null) {
                                                                          tabController.animateTo(1);
                                                                        }
                                                                      });
                                                                    },
                                                                    icon: const Icon(Icons.fork_right),
                                                                    label: const Text('View in mNp(s)'),
                                                                    style: ElevatedButton.styleFrom(
                                                                      backgroundColor: Colors.blue,
                                                                      foregroundColor: Colors.white,
                                                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        );
                                                      }
                                                      return const Center(
                                                        child: Card(
                                                          color: Colors.black87,
                                                          child: Padding(
                                                            padding: EdgeInsets.all(32.0),
                                                            child: Column(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                CircularProgressIndicator(),
                                                                SizedBox(height: 16),
                                                                Text(
                                                                  'Creating your fork...',
                                                                  style: TextStyle(color: Colors.white),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                );

                                                try {
                                                  final forkService = ForkService();
                                                  await forkService.forkSingleScene(
                                                    originalMovieId: widget.movieId,
                                                    scene: {
                                                      ...scene,
                                                      'movieId': widget.movieId,
                                                      'userId': widget.userId,
                                                    },
                                                    movieIdea: scene['text'] ?? 'Forked Scene',
                                                    originalCreatorId: widget.userId,
                                                  );
                                                } catch (e) {
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        content: Text('Error: $e'),
                                                        backgroundColor: Colors.red,
                                                      ),
                                                    );
                                                  }
                                                }
                                              },
                                              child: const Text(
                                                'Just This Scene',
                                                style: TextStyle(color: Colors.blue),
                                              ),
                                            ),
                                            ElevatedButton(
                                              onPressed: () async {
                                                Navigator.pop(context);
                                                // Show loading dialog with 4-second timer
                                                showDialog(
                                                  context: context,
                                                  barrierDismissible: false,
                                                  builder: (context) => FutureBuilder(
                                                    future: Future.delayed(const Duration(seconds: 4)),
                                                    builder: (context, snapshot) {
                                                      if (snapshot.connectionState == ConnectionState.done) {
                                                        return Center(
                                                          child: Card(
                                                            color: Colors.black87,
                                                            child: Padding(
                                                              padding: const EdgeInsets.all(32.0),
                                                              child: Column(
                                                                mainAxisSize: MainAxisSize.min,
                                                                children: [
                                                                  const Icon(
                                                                    Icons.check_circle,
                                                                    color: Colors.green,
                                                                    size: 48,
                                                                  ),
                                                                  const SizedBox(height: 16),
                                                                  const Text(
                                                                    'Fork created successfully!',
                                                                    style: TextStyle(color: Colors.white),
                                                                  ),
                                                                  const SizedBox(height: 24),
                                                                  ElevatedButton.icon(
                                                                    onPressed: () {
                                                                      Navigator.of(context).popUntil((route) => route.isFirst);
                                                                      // Wait for next frame to ensure DefaultTabController is ready
                                                                      Future.microtask(() {
                                                                        final tabController = DefaultTabController.of(context);
                                                                        if (tabController != null) {
                                                                          tabController.animateTo(1);
                                                                        }
                                                                      });
                                                                    },
                                                                    icon: const Icon(Icons.fork_right),
                                                                    label: const Text('View in mNp(s)'),
                                                                    style: ElevatedButton.styleFrom(
                                                                      backgroundColor: Colors.blue,
                                                                      foregroundColor: Colors.white,
                                                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        );
                                                      }
                                                      return const Center(
                                                        child: Card(
                                                          color: Colors.black87,
                                                          child: Padding(
                                                            padding: EdgeInsets.all(32.0),
                                                            child: Column(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                CircularProgressIndicator(),
                                                                SizedBox(height: 16),
                                                                Text(
                                                                  'Creating your fork...',
                                                                  style: TextStyle(color: Colors.white),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                );

                                                try {
                                                  final forkService = ForkService();
                                                  final scenesWithIds = widget.scenes.map((s) => {
                                                    ...s,
                                                    'movieId': widget.movieId,
                                                    'userId': widget.userId,
                                                  }).toList();
                                                  
                                                  await forkService.forkSceneAndPrevious(
                                                    originalMovieId: widget.movieId,
                                                    allScenes: scenesWithIds,
                                                    currentSceneIndex: _currentIndex,
                                                    movieIdea: scene['text'] ?? 'Forked Scenes',
                                                    originalCreatorId: widget.userId,
                                                  );
                                                } catch (e) {
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        content: Text('Error: $e'),
                                                        backgroundColor: Colors.red,
                                                      ),
                                                    );
                                                  }
                                                }
                                              },
                                              child: const Text('This Scene & Previous'),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    ),
                                    icon: const Icon(Icons.fork_right),
                                    label: const Text('Fork This Scene'),
                                  ),
                                  const SizedBox(height: 20),
                                ],
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Scene ${scene['id']}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      shadows: [
                                        Shadow(
                                          blurRadius: 8,
                                          color: Colors.black54,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.touch_app,
                                    color: Colors.white70,
                                    size: 16,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                scene['text'],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 8,
                                      color: Colors.black54,
                                    ),
                                  ],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Navigation Indicator
                    Positioned(
                      right: 16,
                      bottom: 85,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Up arrow
                            const Icon(
                              Icons.keyboard_arrow_up,
                              color: Colors.white,
                              size: 32,
                            ),
                            
                            const SizedBox(height: 8),
                            
                            // Director's profile photo
                            FutureBuilder(
                              future: _loadDirectorPhoto(scene['userId'] ?? widget.userId),
                              builder: (context, snapshot) {
                                return GestureDetector(
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => Dialog(
                                        backgroundColor: Colors.transparent,
                                        child: Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.9),
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              ListTile(
                                                leading: const Icon(Icons.message, color: Colors.white),
                                                title: const Text(
                                                  'DM Director',
                                                  style: TextStyle(color: Colors.white),
                                                ),
                                                onTap: () {
                                                  Navigator.pop(context);
                                                  // TODO: Implement DM functionality
                                                },
                                              ),
                                              ListTile(
                                                leading: const Icon(Icons.chat, color: Colors.white),
                                                title: const Text(
                                                  'Movie Chat',
                                                  style: TextStyle(color: Colors.white),
                                                ),
                                                onTap: () {
                                                  Navigator.pop(context);
                                                  // TODO: Implement Movie Chat functionality
                                                },
                                              ),
                                              ListTile(
                                                leading: const Icon(Icons.person, color: Colors.white),
                                                title: const Text(
                                                  'View Profile',
                                                  style: TextStyle(color: Colors.white),
                                                ),
                                                onTap: () {
                                                  Navigator.pop(context);
                                                  // TODO: Navigate to profile
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                      image: DecorationImage(
                                        image: NetworkImage(
                                          _directorPhotos[scene['userId'] ?? widget.userId] ?? 
                                          'https://via.placeholder.com/48'
                                        ),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            
                            const SizedBox(height: 8),
                            
                            // Down arrow
                            const Icon(
                              Icons.keyboard_arrow_down,
                              color: Colors.white,
                              size: 32,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            
            // Back Button with Gradient Background
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                        ),
                        const Spacer(),
                        // Scene counter
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black38,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            'Scene ${_currentIndex + 1}/${scenesWithVideos.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 