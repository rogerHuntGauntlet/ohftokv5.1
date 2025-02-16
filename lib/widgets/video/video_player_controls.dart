import 'package:flutter/material.dart';
import '../../services/video/video_service.dart';

class VideoPlayerControls extends StatelessWidget {
  final VideoService videoService;
  final bool showControls;

  const VideoPlayerControls({
    super.key,
    required this.videoService,
    this.showControls = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!showControls) return const SizedBox.shrink();

    return Stack(
      children: [
        // Play/Pause Button
        if (videoService.isInitialized)
          Center(
            child: AnimatedOpacity(
              opacity: videoService.isPlaying ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ),

        // Bottom Controls
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.7),
                ],
              ),
            ),
            child: Row(
              children: [
                // Mute Button
                IconButton(
                  icon: Icon(
                    videoService.isMuted ? Icons.volume_off : Icons.volume_up,
                    color: Colors.white,
                  ),
                  onPressed: videoService.toggleMute,
                ),
                
                // Progress Bar (if needed)
                if (videoService.duration != null)
                  Expanded(
                    child: VideoProgressBar(videoService: videoService),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class VideoProgressBar extends StatelessWidget {
  final VideoService videoService;

  const VideoProgressBar({
    super.key,
    required this.videoService,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: videoService,
      builder: (context, _) {
        final duration = videoService.duration;
        if (duration == null) return const SizedBox.shrink();

        final position = videoService.position;
        final progress = position.inMilliseconds / duration.inMilliseconds;

        return SliderTheme(
          data: SliderThemeData(
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white.withOpacity(0.3),
            thumbColor: Colors.white,
            overlayColor: Colors.white.withOpacity(0.3),
          ),
          child: Slider(
            value: progress.clamp(0.0, 1.0),
            onChanged: (value) {
              final newPosition = Duration(
                milliseconds: (value * duration.inMilliseconds).round(),
              );
              videoService.seekTo(newPosition);
            },
          ),
        );
      },
    );
  }
} 