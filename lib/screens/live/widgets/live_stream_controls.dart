import 'package:flutter/material.dart';
import '../../../services/streaming/video_streaming_service.dart';
import '../../../services/sharing/stream_sharing_service.dart';

class LiveStreamControls extends StatefulWidget {
  final String streamId;
  final bool isHost;
  final VoidCallback? onEndStream;

  const LiveStreamControls({
    Key? key,
    required this.streamId,
    required this.isHost,
    this.onEndStream,
  }) : super(key: key);

  @override
  State<LiveStreamControls> createState() => _LiveStreamControlsState();
}

class _LiveStreamControlsState extends State<LiveStreamControls> {
  final VideoStreamingService _streamingService = VideoStreamingService();
  final StreamSharingService _sharingService = StreamSharingService();
  bool _isMuted = false;
  bool _isCameraOff = false;

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
            if (widget.isHost)
              _ControlButton(
                icon: Icons.flip_camera_ios,
                label: 'Flip',
                onPressed: () async {
                  try {
                    await _streamingService.flipCamera();
                  } catch (e) {
                    print('Error flipping camera: $e');
                  }
                },
              ),

            // Camera toggle (host only)
            if (widget.isHost)
              _ControlButton(
                icon: _isCameraOff ? Icons.videocam_off : Icons.videocam,
                label: _isCameraOff ? 'Camera Off' : 'Camera On',
                onPressed: () {
                  setState(() {
                    _isCameraOff = !_isCameraOff;
                    _streamingService.toggleCamera();
                  });
                },
              ),

            // Microphone toggle (host only)
            if (widget.isHost)
              _ControlButton(
                icon: _isMuted ? Icons.mic_off : Icons.mic,
                label: _isMuted ? 'Muted' : 'Mic On',
                onPressed: () {
                  setState(() {
                    _isMuted = !_isMuted;
                    _streamingService.toggleMute();
                  });
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
              label: widget.isHost ? 'End' : 'Leave',
              color: Colors.red,
              onPressed: () {
                if (widget.isHost) {
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
            if (widget.isHost) ...[
              ListTile(
                leading: const Icon(Icons.high_quality, color: Colors.white),
                title: const Text(
                  'Video Quality',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () => _showQualitySettings(context),
              ),
              ListTile(
                leading: const Icon(Icons.speed, color: Colors.white),
                title: const Text(
                  'Stream Latency',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () => _showLatencySettings(context),
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

  void _showQualitySettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Video Quality'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: StreamQuality.values.map((quality) {
            final qualityName = quality.toString().split('.').last;
            String resolution;
            String description;
            
            switch (quality) {
              case StreamQuality.veryHigh:
                resolution = '1080p';
                description = 'Very High Quality';
                break;
              case StreamQuality.high:
                resolution = '720p';
                description = 'High Quality';
                break;
              case StreamQuality.medium:
                resolution = '480p';
                description = 'Medium Quality';
                break;
              case StreamQuality.low:
                resolution = '360p';
                description = 'Low Quality';
                break;
            }

            return ListTile(
              title: Text(resolution),
              subtitle: Text(description),
              onTap: () {
                _streamingService.changeQuality(quality);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showLatencySettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stream Latency'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: StreamLatency.values.map((latency) {
            final latencyName = latency.toString().split('.').last;
            String description;
            
            switch (latency) {
              case StreamLatency.ultraLow:
                description = '< 1 second';
                break;
              case StreamLatency.low:
                description = '1-2 seconds';
                break;
              case StreamLatency.normal:
                description = '2-4 seconds';
                break;
              case StreamLatency.high:
                description = '> 4 seconds';
                break;
            }

            return ListTile(
              title: Text(latencyName.replaceAll('_', ' ')),
              subtitle: Text(description),
              onTap: () {
                _streamingService.changeLatency(latency);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showStreamInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stream Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quality: ${_streamingService.currentQuality.toString().split('.').last}'),
            const SizedBox(height: 8),
            Text('Latency: ${_streamingService.currentLatency.toString().split('.').last}'),
            const SizedBox(height: 8),
            Text('Camera: ${_streamingService.isCameraOff ? 'Off' : 'On'}'),
            const SizedBox(height: 8),
            Text('Microphone: ${_streamingService.isMuted ? 'Muted' : 'On'}'),
          ],
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
                  onTap: () async {
                    final url = await _sharingService.generateDynamicLink(
                      path: '/stream',
                      title: 'Live Stream',
                    );
                    await _sharingService.copyToClipboard(url);
                    Navigator.pop(context);
                  },
                ),
                _ShareButton(
                  icon: Icons.qr_code,
                  label: 'QR Code',
                  onTap: () async {
                    final url = await _sharingService.generateDynamicLink(
                      path: '/stream',
                      title: 'Live Stream',
                    );
                    _showQRCode(context, url);
                  },
                ),
                _ShareButton(
                  icon: Icons.share,
                  label: 'Share',
                  onTap: () async {
                    final url = await _sharingService.generateDynamicLink(
                      path: '/stream',
                      title: 'Live Stream',
                    );
                    await _sharingService.shareStream(
                      streamUrl: url,
                      streamTitle: 'Live Stream',
                    );
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

  void _showQRCode(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scan QR Code'),
        content: Container(
          width: 250,
          height: 250,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: _sharingService.generateQRCode(url),
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

  void _endStream(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Stream'),
        content: const Text('Are you sure you want to end the stream?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onEndStream?.call();
            },
            child: const Text('End Stream'),
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color color;

  const _ControlButton({
    Key? key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color = Colors.white,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(icon),
          color: color,
          onPressed: onPressed,
        ),
        Text(
          label,
          style: TextStyle(
            color: color,
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
    Key? key,
    required this.icon,
    required this.label,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
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