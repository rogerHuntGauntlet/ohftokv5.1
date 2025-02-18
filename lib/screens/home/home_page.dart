import 'package:flutter/material.dart';
import '../movie/scene_generation_loading_screen.dart';
import '../profile/profile_screen.dart';
import '../feed/feed_screen.dart';
import '../find_movies/find_movies_screen.dart';
import '../messaging/conversation_list_screen.dart';
import '../training/director_training_screen.dart';
import 'dialogs/recording_dialog.dart';
import 'tabs/movies_tab.dart';
import 'tabs/forks_tab.dart';
import 'utils/speech_helper.dart';
import 'widgets/create_movie_button.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey _createVideoButtonKey = GlobalKey();
  final SpeechHelper _speechHelper = SpeechHelper();
  bool _isListening = false;
  String _movieIdea = '';
  bool _isProcessing = false;
  StateSetter? _dialogSetState;
  int _tapCount = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initializeSpeech();
  }

  Future<void> _initializeSpeech() async {
    await _speechHelper.checkPermissions(context);
  }

  Future<void> _startListening() async {
    if (!_speechHelper.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech recognition is not initialized. Please try again.')),
      );
      return;
    }

    setState(() {
      _movieIdea = 'Listening...';
      _isListening = true;
    });

    // Show the recording dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          _dialogSetState = setDialogState;
          return RecordingDialog(
            speech: _speechHelper.speech,
            isListening: _isListening,
            movieIdea: _movieIdea,
            onCancel: () {
              _speechHelper.stopListening();
              Navigator.pop(context);
              setState(() {
                _isListening = false;
                _movieIdea = '';
              });
            },
            onStopRecording: () {
              _stopListening();
              setDialogState(() {});
            },
            onCreateMovie: () {
              Navigator.pop(context);
              _processMovieIdea();
            },
          );
        },
      ),
    );

    try {
      await _speechHelper.startListening(
        onResult: (text) {
          setState(() {
            _movieIdea = text.isEmpty ? 'Listening...' : text;
          });
          _dialogSetState?.call(() {}); // Update dialog state
        },
        onError: (e) {
          setState(() {
            _isListening = false;
            _movieIdea = '';
          });
          _dialogSetState?.call(() {}); // Update dialog state
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to start listening. Please try again.')),
          );
        },
      );
    } catch (e) {
      print('Listen error: $e');
      setState(() {
        _isListening = false;
        _movieIdea = '';
      });
      _dialogSetState?.call(() {}); // Update dialog state
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to start listening. Please try again.')),
      );
    }
  }

  Future<void> _stopListening() async {
    await _speechHelper.stopListening();
    setState(() => _isListening = false);
    _dialogSetState?.call(() {}); // Update dialog state
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

  Offset _getCreateButtonPosition() {
    final RenderBox? renderBox = _createVideoButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return Offset.zero;
    return renderBox.localToGlobal(Offset.zero);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('OHFtok'),
          leading: GestureDetector(
            onTapDown: (_) {
              print('Tap detected');
              _tapCount++;
              
              _timer?.cancel();
              _timer = Timer(const Duration(milliseconds: 500), () {
                if (_tapCount == 1) {
                  _showInstructions();
                }
                _tapCount = 0;
              });

              if (_tapCount == 2) {
                _timer?.cancel();
                _tapCount = 0;
                if (!_isProcessing && _speechHelper.isInitialized) {
                  _startListening();
                }
              }
            },
            child: Container(
              alignment: Alignment.center,
              child: Icon(
                _isListening ? Icons.mic : Icons.add_to_queue,
                color: _isListening ? Colors.red : null,
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.school),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const DirectorTrainingScreen(),
                  ),
                );
              },
              tooltip: 'Training',
            ),
            IconButton(
              icon: const Icon(Icons.message),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ConversationListScreen(),
                  ),
                );
              },
              tooltip: 'Messages',
            ),
            IconButton(
              icon: const Icon(Icons.rss_feed),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const FeedScreen(),
                  ),
                );
              },
              tooltip: 'Social Feed',
            ),
            IconButton(
              icon: const Icon(Icons.explore),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const FindMoviesScreen(),
                  ),
                );
              },
              tooltip: 'Find Movies',
            ),
            IconButton(
              icon: const Icon(Icons.person),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                );
              },
              tooltip: 'Profile',
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.movie),
                text: 'Original Movies',
              ),
              Tab(
                icon: Icon(Icons.fork_right),
                text: 'mNp(s)',
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            MoviesTab(),
            ForksTab(),
          ],
        ),
      ),
    );
  }
} 