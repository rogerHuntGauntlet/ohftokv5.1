import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/social/auth_service.dart';
import '../../widgets/tutorial/tutorial_overlay.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_to_text.dart' show ListenMode;
import '../../services/movie/movie_service.dart';
import 'package:permission_handler/permission_handler.dart';
import '../movie/scene_generation_loading_screen.dart';
import '../movie/movie_scenes_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../movie/movie_video_player_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey _createVideoButtonKey = GlobalKey();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _movieIdea = '';
  bool _isProcessing = false;
  bool _isSpeechInitialized = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) {
      _initializeSpeech();
    } else {
      final result = await Permission.microphone.request();
      if (result.isGranted) {
        _initializeSpeech();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission is required for speech recognition'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _initializeSpeech() async {
    try {
      bool available = await _speech.initialize(
        onStatus: (status) {
          print('Speech status: $status');
          // Only update listening state, don't auto-process
          if (status == 'done') {
            setState(() => _isListening = false);
          }
        },
        onError: (error) {
          print('Speech Error: $error');
          setState(() => _isListening = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $error')),
          );
        },
      );
      setState(() => _isSpeechInitialized = available);
      if (!available) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speech recognition not available on this device')),
        );
      }
    } catch (e) {
      print('Speech initialization error: $e');
      setState(() => _isSpeechInitialized = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to initialize speech recognition')),
      );
    }
  }

  Future<void> _startListening() async {
    if (!_isSpeechInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech recognition is not initialized. Please try again.')),
      );
      return;
    }

    setState(() {
      _movieIdea = 'Listening...';
      _isListening = true;
    });

    late StateSetter dialogSetState;
    // Show the recording dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          dialogSetState = setDialogState;
          return AlertDialog(
            title: Row(
              children: [
                Icon(
                  _isListening ? Icons.mic : Icons.mic_off,
                  color: _isListening ? Colors.red : Colors.grey,
                ),
                const SizedBox(width: 8),
                const Text('Recording Movie Idea'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Describe your movie idea:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Text(
                    _movieIdea == 'Listening...' ? 'Speak now...' : _movieIdea,
                    style: TextStyle(
                      color: _movieIdea == 'Listening...' ? Colors.grey : Colors.black,
                      fontStyle: _movieIdea == 'Listening...' ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                ),
                if (_movieIdea != 'Listening...' && _movieIdea.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      'Tap Stop Recording when you\'re done speaking.',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _speech.stop();
                  Navigator.pop(context);
                  setState(() {
                    _isListening = false;
                    _movieIdea = '';
                  });
                },
                child: const Text('Cancel'),
              ),
              if (_isListening)
                ElevatedButton(
                  onPressed: () {
                    _stopListening();
                    dialogSetState(() {});
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  child: const Text('Stop Recording'),
                ),
              if (!_isListening && _movieIdea.isNotEmpty)
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _processMovieIdea();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                  ),
                  child: const Text('Create Movie'),
                ),
            ],
          );
        },
      ),
    );

    try {
      await _speech.listen(
        onResult: (result) {
          final text = result.recognizedWords;
          setState(() {
            _movieIdea = text.isEmpty ? 'Listening...' : text;
          });
          dialogSetState(() {}); // Update the dialog with new text
        },
        listenMode: ListenMode.dictation,
        cancelOnError: true,
        partialResults: true,
      );
    } catch (e) {
      print('Listen error: $e');
      setState(() {
        _isListening = false;
        _movieIdea = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to start listening. Please try again.')),
      );
    }
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);
  }

  Future<void> _processMovieIdea() async {
    if (_movieIdea.isEmpty) return;

    final movieIdeaCopy = _movieIdea;  // Create a copy before resetting

    // Stop listening if still active
    if (_isListening) {
      await _stopListening();
    }

    // Reset the state first
    setState(() {
      _movieIdea = '';
      _isListening = false;
      _isProcessing = false;
    });

    // Use a slight delay to ensure the dialog is closed properly
    await Future.delayed(const Duration(milliseconds: 100));

    // Navigate to loading screen if still mounted
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => SceneGenerationLoadingScreen(
            movieIdea: movieIdeaCopy,
          ),
        ),
      );
    }
  }

  Future<void> _showInstructions() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How to Create a Movie'),
        content: const Text('Double tap the movie icon to start recording your movie idea. Tap it again to stop recording.\n\nYour idea will be processed and turned into movie scenes!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('OHFtok'),
          leading: TutorialOverlay(
            featureKey: 'create_movie',
            title: 'Create Your Movie',
            description: 'Double tap to start recording your movie idea!',
            targetPosition: _getCreateButtonPosition(),
            targetSize: const Size(48, 48),
            child: GestureDetector(
              onDoubleTap: (_isProcessing || !_isSpeechInitialized) 
                ? null 
                : () {
                    if (_isListening) {
                      _stopListening();
                    } else {
                      _startListening();
                    }
                  },
              child: IconButton(
                key: _createVideoButtonKey,
                onPressed: _isProcessing ? null : _showInstructions,
                icon: Icon(_isListening ? Icons.mic : Icons.movie_creation),
                color: _isListening ? Colors.red : null,
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.bug_report),
              onPressed: () async {
                try {
                  final service = Provider.of<MovieService>(context, listen: false);
                  final movies = await service.getAllMovies();
                  if (mounted) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Database Contents'),
                        content: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Found ${movies.length} movies:'),
                              const SizedBox(height: 8),
                              ...movies.map((movie) => Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Movie ID: ${movie['documentId']}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text('Idea: ${movie['movieIdea']}'),
                                      Text('User: ${movie['userId']}'),
                                      Text('Status: ${movie['status']}'),
                                      Text('Created: ${_formatTimestamp(movie['createdAt'])}'),
                                    ],
                                  ),
                                ),
                              )),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error checking database: $e')),
                    );
                  }
                }
              },
            ),
            IconButton(
              onPressed: () async {
                await Provider.of<AuthService>(context, listen: false).signOut();
                if (mounted) {
                  Navigator.of(context).pushReplacementNamed('/login');
                }
              },
              icon: const Icon(Icons.logout),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.movie),
                text: 'My Movies',
              ),
              Tab(
                icon: Icon(Icons.fork_right),
                text: 'mNp(s)',
              ),
              Tab(
                icon: Icon(Icons.search),
                text: 'Find Movies',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildMyMoviesTab(),
            _buildMyForksTab(),
            _buildFindMoviesTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildMyMoviesTab() {
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your Movies',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: Provider.of<MovieService>(context).getUserMovies(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error loading movies: ${snapshot.error}',
                        style: TextStyle(color: Colors.red[400]),
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final movies = snapshot.data!;
                  if (movies.isEmpty) {
                    return Center(
                      child: Text(
                        'Your created movies will appear here',
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: movies.length,
                    itemBuilder: (context, index) {
                      final movie = movies[index];
                      final isComplete = _isMovieComplete(movie);
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: () => _navigateToMovie(movie),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const CircleAvatar(
                                      child: Icon(Icons.movie),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            movie['title'] ?? 'Untitled',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            movie['movieIdea'],
                                            style: TextStyle(color: Colors.grey[600]),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Created: ${_formatTimestamp(movie['createdAt'])}',
                                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                        ),
                                        Text(
                                          'Last Updated: ${_formatTimestamp(movie['updatedAt'] ?? movie['createdAt'])}',
                                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                        ),
                                      ],
                                    ),
                                    if (_getIncompleteScenesCount(movie) > 0)
                                      Chip(
                                        label: Text('${_getIncompleteScenesCount(movie)} scenes need videos'),
                                        backgroundColor: Colors.orange[100],
                                        labelStyle: TextStyle(color: Colors.orange[900]),
                                      )
                                    else
                                      TextButton.icon(
                                        onPressed: () => _toggleMoviePublicStatus(movie),
                                        icon: Icon(
                                          movie['isPublic'] ? Icons.unpublished : Icons.publish,
                                          size: 18,
                                        ),
                                        label: Text(movie['isPublic'] ? 'Unpublish' : 'Publish'),
                                        style: TextButton.styleFrom(
                                          foregroundColor: movie['isPublic'] ? Colors.red : Colors.green,
                                        ),
                                      ),
                                  ],
                                ),
                                if (movie['isPublic'])
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.visibility,
                                          size: 16,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${movie['views'] ?? 0} views',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Just now';
    
    final date = timestamp is Timestamp 
        ? timestamp.toDate() 
        : DateTime.now();
    
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildMyForksTab() {
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your Forked Movies',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: Provider.of<MovieService>(context).getUserForkedMovies(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error loading movies: ${snapshot.error}',
                        style: TextStyle(color: Colors.red[400]),
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final movies = snapshot.data!;
                  if (movies.isEmpty) {
                    return Center(
                      child: Text(
                        'Movies you\'ve forked will appear here',
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: movies.length,
                    itemBuilder: (context, index) {
                      final movie = movies[index];
                      
                      return Dismissible(
                        key: Key(movie['documentId']),
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
                                    const Text('Delete Forked Movie'),
                                  ],
                                ),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Are you sure you want to delete this forked movie?',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      movie['title'] ?? 'Untitled Movie',
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
                            final movieService = Provider.of<MovieService>(context, listen: false);
                            await movieService.deleteMovie(movie['documentId']);

                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Forked movie deleted successfully'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error deleting forked movie: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            onTap: () => _navigateToMovie(movie),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const CircleAvatar(
                                        child: Icon(Icons.fork_right),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              movie['title'] ?? 'Untitled',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              movie['movieIdea'],
                                              style: TextStyle(color: Colors.grey[600]),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.chevron_right),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Created: ${_formatTimestamp(movie['createdAt'])}',
                                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                          ),
                                          Text(
                                            'Last Updated: ${_formatTimestamp(movie['updatedAt'] ?? movie['createdAt'])}',
                                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                          ),
                                        ],
                                      ),
                                      if (_getIncompleteScenesCount(movie) > 0)
                                        Chip(
                                          label: Text('${_getIncompleteScenesCount(movie)} scenes need videos'),
                                          backgroundColor: Colors.orange[100],
                                          labelStyle: TextStyle(color: Colors.orange[900]),
                                        )
                                      else
                                        TextButton.icon(
                                          onPressed: () => _toggleMoviePublicStatus(movie),
                                          icon: Icon(
                                            movie['isPublic'] ? Icons.unpublished : Icons.publish,
                                            size: 18,
                                          ),
                                          label: Text(movie['isPublic'] ? 'Unpublish' : 'Publish'),
                                          style: TextButton.styleFrom(
                                            foregroundColor: movie['isPublic'] ? Colors.red : Colors.green,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFindMoviesTab() {
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Discover Movies',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: Provider.of<MovieService>(context).getPublicMovies(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error loading movies: ${snapshot.error}',
                        style: TextStyle(color: Colors.red[400]),
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final movies = snapshot.data!;
                  if (movies.isEmpty) {
                    return Center(
                      child: Text(
                        'No public movies available yet',
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: movies.length,
                    itemBuilder: (context, index) {
                      final movie = movies[index];
                      final scenes = List<Map<String, dynamic>>.from(movie['scenes'] ?? [])
                          .where((scene) => 
                            scene['videoUrl'] != null && 
                            scene['videoUrl'].toString().isNotEmpty
                          )
                          .toList();
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: () async {
                            try {
                              // Get full movie data with all scenes
                              final fullMovie = await Provider.of<MovieService>(context, listen: false)
                                  .getMovie(movie['documentId']);
                              
                              if (mounted) {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => MovieScenesScreen(
                                      movieIdea: fullMovie['movieIdea'],
                                      scenes: fullMovie['scenes'],
                                      movieId: fullMovie['documentId'],
                                      movieTitle: fullMovie['title'],
                                      isReadOnly: true,  // Set to read-only mode
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error loading movie: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      child: Icon(
                                        movie['forkedFrom'] != null ? Icons.fork_right : Icons.movie,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            movie['title'] ?? 'Untitled',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            movie['movieIdea'],
                                            style: TextStyle(color: Colors.grey[600]),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(
                                                movie['forkedFrom'] != null ? Icons.fork_right : Icons.movie_creation,
                                                size: 14,
                                                color: Colors.grey[600],
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                movie['forkedFrom'] != null ? 'Forked Movie' : 'Original Movie',
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 12,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.play_circle_outline),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Created: ${_formatTimestamp(movie['createdAt'])}',
                                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                    ),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.visibility,
                                          size: 16,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${movie['views'] ?? 0}',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Text(
                                          '${scenes.length} scenes',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateMovieDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Movie'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.mic),
              title: const Text('Voice Recording'),
              onTap: () {
                Navigator.pop(context);
                if (_isListening) {
                  _stopListening();
                } else {
                  _startListening();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.keyboard),
              title: const Text('Type Idea'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Show text input dialog
              },
            ),
          ],
        ),
      ),
    );
  }

  Offset _getCreateButtonPosition() {
    final RenderBox? renderBox = _createVideoButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return Offset.zero;
    return renderBox.localToGlobal(Offset.zero);
  }

  /// Navigate to movie details screen
  Future<void> _navigateToMovie(Map<String, dynamic> movie) async {
    try {
      final fullMovie = await Provider.of<MovieService>(context, listen: false)
          .getMovie(movie['documentId']);
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MovieScenesScreen(
              movieIdea: fullMovie['movieIdea'],
              scenes: fullMovie['scenes'],
              movieId: fullMovie['documentId'],
              movieTitle: fullMovie['title'],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading movie: $e')),
        );
      }
    }
  }

  bool _isMovieComplete(Map<String, dynamic> movie) {
    final scenes = movie['scenes'] as List<dynamic>?;
    if (scenes == null || scenes.isEmpty) return false;
    return scenes.every((scene) => 
      scene['status'] == 'completed' && 
      scene['videoUrl'] != null && 
      scene['videoUrl'].toString().isNotEmpty
    );
  }

  int _getIncompleteScenesCount(Map<String, dynamic> movie) {
    final scenes = movie['scenes'] as List<dynamic>?;
    if (scenes == null) return 0;
    
    return scenes.where((scene) => 
      scene['videoUrl'] == null || 
      scene['videoUrl'].toString().isEmpty
    ).length;
  }

  Future<void> _toggleMoviePublicStatus(Map<String, dynamic> movie) async {
    try {
      final movieService = Provider.of<MovieService>(context, listen: false);
      await movieService.updateMoviePublicStatus(
        movie['documentId'],
        !movie['isPublic'],
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              movie['isPublic'] 
                ? 'Movie unpublished successfully' 
                : 'Movie published successfully'
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating movie status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
} 