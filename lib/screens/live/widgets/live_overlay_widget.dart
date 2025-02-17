import 'package:flutter/material.dart';
import '../../../models/live/live_overlay.dart';
import '../../../services/live/live_overlay_service.dart';

class LiveOverlayWidget extends StatelessWidget {
  final String streamId;
  final LiveOverlayService overlayService;
  final bool isHost;

  const LiveOverlayWidget({
    Key? key,
    required this.streamId,
    required this.overlayService,
    required this.isHost,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<LiveOverlay>>(
      stream: overlayService.getActiveOverlays(streamId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final overlays = snapshot.data!;
        if (overlays.isEmpty) return const SizedBox.shrink();

        return Stack(
          children: overlays.map((overlay) {
            // Skip expired overlays
            if (overlay.isExpired()) return const SizedBox.shrink();

            switch (overlay.type) {
              case OverlayType.announcement:
                return _AnnouncementOverlay(overlay: overlay);
              case OverlayType.featuredComment:
                return _FeaturedCommentOverlay(overlay: overlay);
              case OverlayType.featuredResponse:
                return _FeaturedResponseOverlay(overlay: overlay);
              case OverlayType.reaction:
                return _ReactionOverlay(overlay: overlay);
              case OverlayType.moment:
                return _MomentOverlay(overlay: overlay);
            }
          }).toList(),
        );
      },
    );
  }
}

class _AnnouncementOverlay extends StatelessWidget {
  final LiveOverlay overlay;

  const _AnnouncementOverlay({required this.overlay});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 100,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.campaign, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  overlay.content,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeaturedCommentOverlay extends StatelessWidget {
  final LiveOverlay overlay;

  const _FeaturedCommentOverlay({required this.overlay});

  @override
  Widget build(BuildContext context) {
    final metadata = overlay.metadata;
    if (metadata == null) return const SizedBox.shrink();

    return Positioned(
      bottom: 160,
      left: 32,
      right: 32,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: metadata['userProfileImage'] != null
                      ? NetworkImage(metadata['userProfileImage'] as String)
                      : null,
                  child: metadata['userProfileImage'] == null
                      ? Text((metadata['userDisplayName'] as String)[0])
                      : null,
                ),
                const SizedBox(width: 8),
                Text(
                  metadata['userDisplayName'] as String,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              overlay.content,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturedResponseOverlay extends StatelessWidget {
  final LiveOverlay overlay;

  const _FeaturedResponseOverlay({required this.overlay});

  @override
  Widget build(BuildContext context) {
    final metadata = overlay.metadata;
    if (metadata == null) return const SizedBox.shrink();

    return Positioned(
      bottom: 160,
      left: 32,
      right: 32,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.purple.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
              children: [
                Icon(Icons.star, color: Colors.yellow),
                SizedBox(width: 8),
                Text(
                  'Featured Response',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              metadata['prompt'] as String,
              style: const TextStyle(
                color: Colors.white70,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              overlay.content,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '- ${metadata['userDisplayName']}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReactionOverlay extends StatelessWidget {
  final LiveOverlay overlay;

  const _ReactionOverlay({required this.overlay});

  @override
  Widget build(BuildContext context) {
    final metadata = overlay.metadata;
    if (metadata == null) return const SizedBox.shrink();

    return Positioned(
      bottom: 120,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              overlay.content,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              metadata['userDisplayName'] as String,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MomentOverlay extends StatelessWidget {
  final LiveOverlay overlay;

  const _MomentOverlay({required this.overlay});

  @override
  Widget build(BuildContext context) {
    final metadata = overlay.metadata;
    if (metadata == null) return const SizedBox.shrink();

    return Positioned(
      top: 120,
      left: 32,
      right: 32,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
              children: [
                Icon(Icons.movie, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Moment Captured',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              overlay.content,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 