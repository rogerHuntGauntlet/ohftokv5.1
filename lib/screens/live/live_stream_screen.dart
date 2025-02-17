import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
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
import '../../services/streaming/video_streaming_service.dart';
import 'widgets/live_chat_widget.dart';
import 'widgets/live_reactions_widget.dart';
import 'widgets/live_viewer_list.dart';
import 'widgets/live_stream_controls.dart';
import 'widgets/live_poll_widget.dart';
import 'widgets/live_qa_widget.dart';
import 'widgets/live_story_prompt_widget.dart';
import 'widgets/live_overlay_widget.dart';

class LiveStreamScreen extends StatefulWidget {
  final String streamId;
  final bool isHost;

  const LiveStreamScreen({
    Key? key,
    required this.streamId,
    required this.isHost,
  }) : super(key: key);

  @override
  State<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends State<LiveStreamScreen> {
  final VideoStreamingService _streamingService = VideoStreamingService();
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  bool _isInitialized = false;
  String? _error;
  bool _showInteractiveFeatures = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _localRenderer.initialize();
      
      if (widget.isHost) {
        await _streamingService.initializeStream(
          streamId: widget.streamId,
          localRenderer: _localRenderer,
          quality: StreamQuality.high,
          latency: StreamLatency.low,
        );
      }

      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
      print('Error initializing stream: $e');
    }
  }

  @override
  void dispose() {
    _streamingService.dispose();
    _localRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video view
          if (_isInitialized && _error == null)
            Positioned.fill(
              child: RTCVideoView(
                _localRenderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                mirror: true,
                filterQuality: FilterQuality.low,
              ),
            )
          else if (_error != null)
            Center(
              child: Text(
                'Error: $_error',
                style: const TextStyle(color: Colors.white),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(),
            ),

          // Interactive features
          if (_isInitialized && _showInteractiveFeatures)
            Positioned(
              top: 80,
              bottom: 80,
              right: 16,
              width: 300,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    LivePollWidget(
                      streamId: widget.streamId,
                      isHost: widget.isHost,
                    ),
                    const SizedBox(height: 16),
                    LiveQAWidget(
                      streamId: widget.streamId,
                      isHost: widget.isHost,
                    ),
                    const SizedBox(height: 16),
                    LiveStoryPromptWidget(
                      streamId: widget.streamId,
                      isHost: widget.isHost,
                    ),
                  ],
                ),
              ),
            ),

          // Interactive features toggle button
          if (_isInitialized)
            Positioned(
              top: 16,
              right: 16,
              child: SafeArea(
                child: IconButton(
                  icon: Icon(
                    _showInteractiveFeatures
                        ? Icons.close
                        : Icons.chat_bubble_outline,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    setState(() {
                      _showInteractiveFeatures = !_showInteractiveFeatures;
                    });
                  },
                ),
              ),
            ),

          // Stream controls
          if (_isInitialized)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: LiveStreamControls(
                streamId: widget.streamId,
                isHost: widget.isHost,
                onEndStream: () {
                  Navigator.pop(context);
                },
              ),
            ),

          // Status bar (viewers count, duration, etc.)
          if (_isInitialized)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _StreamStatusBar(
                streamId: widget.streamId,
              ),
            ),
        ],
      ),
    );
  }
}

class _StreamStatusBar extends StatelessWidget {
  final String streamId;

  const _StreamStatusBar({
    Key? key,
    required this.streamId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.8),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Live indicator
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'LIVE',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Stream duration
            StreamBuilder<Duration>(
              stream: Stream.periodic(
                const Duration(seconds: 1),
                (count) => Duration(seconds: count),
              ),
              builder: (context, snapshot) {
                final duration = snapshot.data ?? Duration.zero;
                final hours = duration.inHours;
                final minutes = duration.inMinutes.remainder(60);
                final seconds = duration.inSeconds.remainder(60);
                return Text(
                  '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: Colors.white),
                );
              },
            ),
            const Spacer(),
            // Viewers count
            Row(
              children: [
                const Icon(
                  Icons.remove_red_eye,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 4),
                const Text(
                  '0', // TODO: Implement real viewer count
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 