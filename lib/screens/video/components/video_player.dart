import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/video/video_service.dart';
import '../../../widgets/video/video_player_controls.dart';

class VideoPlayer extends StatelessWidget {
  final String videoUrl;
  final BoxFit fit;
  final bool autoPlay;
  final bool showControls;
  final VoidCallback? onTap;

  const VideoPlayer({
    super.key,
    required this.videoUrl,
    this.fit = BoxFit.cover,
    this.autoPlay = false,
    this.showControls = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final service = VideoService();
        service.initialize(videoUrl).then((_) {
          if (autoPlay) {
            service.play();
          }
        });
        return service;
      },
      child: Consumer<VideoService>(
        builder: (context, service, child) {
          return GestureDetector(
            onTap: () {
              if (onTap != null) {
                onTap!();
              } else {
                service.togglePlayPause();
              }
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Video Player
                service.buildPlayer(fit: fit),

                // Loading Indicator
                if (!service.isInitialized)
                  const Center(child: CircularProgressIndicator()),

                // Controls Overlay
                VideoPlayerControls(
                  videoService: service,
                  showControls: showControls,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
} 