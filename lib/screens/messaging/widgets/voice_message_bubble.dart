import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../services/messaging/voice_message_service.dart';

class VoiceMessageBubble extends StatefulWidget {
  final String url;
  final bool isCurrentUser;

  const VoiceMessageBubble({
    Key? key,
    required this.url,
    required this.isCurrentUser,
  }) : super(key: key);

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  final VoiceMessageService _voiceService = VoiceMessageService();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  
  @override
  void initState() {
    super.initState();
    _voiceService.initialize();
    _listenToPlaybackState();
  }
  
  @override
  void dispose() {
    _voiceService.dispose();
    super.dispose();
  }

  void _listenToPlaybackState() {
    _voiceService.playbackStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    _voiceService.positionStream.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    });

    _voiceService.durationStream.listen((duration) {
      if (mounted) {
        setState(() {
          _duration = duration;
        });
      }
    });
  }

  Future<void> _togglePlayback() async {
    if (_isPlaying) {
      await _voiceService.stopPlaying();
    } else {
      await _voiceService.playVoiceMessage(widget.url);
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: widget.isCurrentUser
            ? theme.primaryColor
            : Colors.grey[300],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              _isPlaying ? Icons.stop : Icons.play_arrow,
              color: widget.isCurrentUser ? Colors.white : Colors.black,
            ),
            onPressed: _togglePlayback,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.mic,
                    size: 16,
                    color: widget.isCurrentUser ? Colors.white70 : Colors.black54,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Voice Message',
                    style: TextStyle(
                      color: widget.isCurrentUser ? Colors.white : Colors.black,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 150,
                child: Column(
                  children: [
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: widget.isCurrentUser
                          ? Colors.white24
                          : Colors.grey[400],
                      valueColor: AlwaysStoppedAnimation(
                        widget.isCurrentUser ? Colors.white : theme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(_position),
                          style: TextStyle(
                            color: widget.isCurrentUser
                                ? Colors.white70
                                : Colors.black54,
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          _formatDuration(_duration),
                          style: TextStyle(
                            color: widget.isCurrentUser
                                ? Colors.white70
                                : Colors.black54,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
} 