import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/live/live_stream.dart';
import '../../models/live/live_comment.dart';
import '../../models/live/live_reaction.dart';
import '../../models/live/live_viewer.dart';
import '../../services/live/live_stream_service.dart';
import '../../services/live/live_comment_service.dart';
import '../../services/live/live_reaction_service.dart';
import '../../services/live/live_viewer_service.dart';
import '../../services/live/live_poll_service.dart';
import '../../services/live/live_question_service.dart';
import '../../services/live/live_story_prompt_service.dart';
import '../../services/live/live_overlay_service.dart';
import '../../services/social/auth_service.dart';
import 'widgets/live_chat_widget.dart';
import 'widgets/live_reactions_widget.dart';
import 'widgets/live_viewer_list.dart';
import 'widgets/live_stream_controls.dart';
import 'widgets/live_poll_widget.dart';
import 'widgets/live_question_widget.dart';
import 'widgets/live_story_prompt_widget.dart';
import 'widgets/live_overlay_widget.dart';

class LiveStreamScreen extends StatefulWidget {
  final String streamId;
  final bool isHost;

  const LiveStreamScreen({
    Key? key,
    required this.streamId,
    this.isHost = false,
  }) : super(key: key);

  @override
  State<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends State<LiveStreamScreen> {
  late final LiveStreamService _streamService;
  late final LiveCommentService _commentService;
  late final LiveReactionService _reactionService;
  late final LiveViewerService _viewerService;
  late final LivePollService _pollService;
  late final LiveQuestionService _questionService;
  late final LiveStoryPromptService _storyPromptService;
  late final LiveOverlayService _overlayService;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    final userId = context.read<AuthService>().currentUser?.uid;
    if (userId == null) return;

    // Initialize all services
    _streamService = LiveStreamService();
    _commentService = LiveCommentService();
    _reactionService = LiveReactionService();
    _viewerService = LiveViewerService();
    _pollService = LivePollService();
    _questionService = LiveQuestionService();
    _storyPromptService = LiveStoryPromptService();
    _overlayService = LiveOverlayService();

    await _streamService.initialize(widget.streamId);
    _commentService.initialize(widget.streamId);
    _reactionService.initialize(widget.streamId);
    await _viewerService.initialize(widget.streamId, userId);

    // Join as viewer if not host
    if (!widget.isHost) {
      final user = context.read<AuthService>().currentUser!;
      await _viewerService.joinStream(
        streamId: widget.streamId,
        userId: user.uid,
        userDisplayName: user.displayName ?? 'Anonymous',
        userProfileImage: user.photoURL,
      );
    }
  }

  @override
  void dispose() {
    // Clean up services
    _streamService.dispose();
    _commentService.dispose();
    _reactionService.dispose();
    _viewerService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _streamService),
        ChangeNotifierProvider.value(value: _commentService),
        ChangeNotifierProvider.value(value: _reactionService),
        ChangeNotifierProvider.value(value: _viewerService),
      ],
      child: Scaffold(
        body: SafeArea(
          child: StreamBuilder<LiveStream>(
            stream: _streamService.getStream(widget.streamId),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: Text('Error loading stream'),
                );
              }

              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              final stream = snapshot.data!;
              return Stack(
                children: [
                  // Main content area (video stream)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black,
                      // TODO: Implement video player
                      child: const Center(
                        child: Text(
                          'Video Stream',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),

                  // Interactive overlays
                  Positioned.fill(
                    child: LiveOverlayWidget(
                      streamId: widget.streamId,
                      overlayService: _overlayService,
                      isHost: widget.isHost,
                    ),
                  ),

                  // Stream info overlay (top)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(16),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stream.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          StreamBuilder<List<LiveViewer>>(
                            stream: _viewerService.getActiveViewers(widget.streamId),
                            builder: (context, snapshot) {
                              final viewerCount = snapshot.data?.length ?? 0;
                              return Text(
                                '$viewerCount viewers',
                                style: const TextStyle(
                                  color: Colors.white70,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Chat overlay (right)
                  Positioned(
                    top: 80,
                    bottom: 80,
                    right: 0,
                    width: 300,
                    child: LiveChatWidget(
                      streamId: widget.streamId,
                      commentService: _commentService,
                      viewerService: _viewerService,
                    ),
                  ),

                  // Reactions overlay (bottom left)
                  Positioned(
                    bottom: 80,
                    left: 16,
                    child: LiveReactionsWidget(
                      streamId: widget.streamId,
                      reactionService: _reactionService,
                    ),
                  ),

                  // Poll overlay (center left)
                  Positioned(
                    top: 80,
                    left: 16,
                    width: 300,
                    height: 200,
                    child: LivePollWidget(
                      streamId: widget.streamId,
                      pollService: _pollService,
                      isHost: widget.isHost,
                    ),
                  ),

                  // Q&A overlay (center left, below polls)
                  Positioned(
                    top: 300,
                    left: 16,
                    width: 300,
                    height: 200,
                    child: LiveQuestionWidget(
                      streamId: widget.streamId,
                      questionService: _questionService,
                      isHost: widget.isHost,
                    ),
                  ),

                  // Story Prompts overlay (center left, below Q&A)
                  Positioned(
                    top: 520,
                    bottom: 160,
                    left: 16,
                    width: 300,
                    child: LiveStoryPromptWidget(
                      streamId: widget.streamId,
                      promptService: _storyPromptService,
                      isHost: widget.isHost,
                    ),
                  ),

                  // Stream controls (bottom)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: LiveStreamControls(
                      streamId: widget.streamId,
                      isHost: widget.isHost,
                      streamService: _streamService,
                    ),
                  ),

                  // Viewer list (top right)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: LiveViewerList(
                      streamId: widget.streamId,
                      viewerService: _viewerService,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
} 