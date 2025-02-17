import 'package:flutter/material.dart';
import '../../../models/live/live_stream.dart';
import '../../../services/live/live_stream_service.dart';

class LiveStreamControls extends StatelessWidget {
  final String streamId;
  final bool isHost;
  final LiveStreamService streamService;

  const LiveStreamControls({
    Key? key,
    required this.streamId,
    required this.isHost,
    required this.streamService,
  }) : super(key: key);

  Future<void> _endStream(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Stream'),
        content: const Text('Are you sure you want to end the stream?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'End Stream',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await streamService.endStream(streamId);
        if (context.mounted) {
          Navigator.pop(context); // Return to previous screen
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error ending stream: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withOpacity(0.8),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Camera flip button (host only)
            if (isHost)
              _ControlButton(
                icon: Icons.flip_camera_ios,
                label: 'Flip',
                onPressed: () {
                  // TODO: Implement camera flip
                },
              ),

            // Microphone toggle (host only)
            if (isHost)
              _ControlButton(
                icon: Icons.mic,
                label: 'Mic',
                onPressed: () {
                  // TODO: Implement microphone toggle
                },
              ),

            // Settings button
            _ControlButton(
              icon: Icons.settings,
              label: 'Settings',
              onPressed: () => _showSettingsDialog(context),
            ),

            // Share button
            _ControlButton(
              icon: Icons.share,
              label: 'Share',
              onPressed: () => _showShareDialog(context),
            ),

            // End stream button (host only) or leave stream (viewer)
            _ControlButton(
              icon: Icons.close,
              label: isHost ? 'End' : 'Leave',
              color: Colors.red,
              onPressed: () {
                if (isHost) {
                  _endStream(context);
                } else {
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.9),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Stream Settings',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (isHost) ...[
              ListTile(
                leading: const Icon(Icons.video_quality, color: Colors.white),
                title: const Text(
                  'Video Quality',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  // TODO: Implement video quality settings
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.speed, color: Colors.white),
                title: const Text(
                  'Stream Latency',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  // TODO: Implement latency settings
                  Navigator.pop(context);
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.white),
              title: const Text(
                'Stream Info',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => _showStreamInfo(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showShareDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.9),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Share Stream',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ShareButton(
                  icon: Icons.copy,
                  label: 'Copy Link',
                  onTap: () {
                    // TODO: Implement copy link
                    Navigator.pop(context);
                  },
                ),
                _ShareButton(
                  icon: Icons.message,
                  label: 'Message',
                  onTap: () {
                    // TODO: Implement share via message
                    Navigator.pop(context);
                  },
                ),
                _ShareButton(
                  icon: Icons.share,
                  label: 'More',
                  onTap: () {
                    // TODO: Implement system share
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showStreamInfo(BuildContext context) {
    Navigator.pop(context); // Close settings dialog
    showDialog(
      context: context,
      builder: (context) => StreamBuilder<LiveStream>(
        stream: streamService.getStream(streamId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final stream = snapshot.data!;
          return AlertDialog(
            backgroundColor: Colors.black.withOpacity(0.9),
            title: const Text(
              'Stream Info',
              style: TextStyle(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(
                  label: 'Title',
                  value: stream.title,
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  label: 'Started',
                  value: stream.startedAt?.toString() ?? 'Not started',
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  label: 'Viewers',
                  value: stream.viewerCount.toString(),
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  label: 'Status',
                  value: stream.status.toString().split('.').last,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Close',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? color;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onPressed,
          icon: Icon(icon),
          color: color ?? Colors.white,
          iconSize: 32,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: color ?? Colors.white,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _ShareButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ShareButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.bold,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
} 