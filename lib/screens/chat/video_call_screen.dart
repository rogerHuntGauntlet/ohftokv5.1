import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../models/message.dart';
import '../../services/video_call_service.dart';

class VideoCallScreen extends StatefulWidget {
  final CallInfo callInfo;
  final String currentUserId;
  final VideoCallService callService;
  final bool isIncoming;

  const VideoCallScreen({
    Key? key,
    required this.callInfo,
    required this.currentUserId,
    required this.callService,
    this.isIncoming = false,
  }) : super(key: key);

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isSpeakerOn = true;
  bool _isMinimized = false;

  @override
  void initState() {
    super.initState();
    _initializeCall();
  }

  Future<void> _initializeCall() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();

    // Listen for remote video stream
    widget.callService.remoteVideoStream.listen((remoteVideo) {
      setState(() {
        _remoteRenderer.srcObject = remoteVideo.srcObject;
      });
    });

    if (widget.isIncoming) {
      await widget.callService.answerCall(widget.callInfo, _localRenderer);
    } else {
      await widget.callService.startCall(widget.callInfo, _localRenderer);
    }
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await widget.callService.endCall(widget.callInfo);
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              // Remote video (full screen)
              _buildRemoteVideo(),
              
              // Local video (picture in picture)
              _buildLocalVideo(),
              
              // Call controls
              _buildCallControls(),
              
              // Call status bar
              _buildStatusBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRemoteVideo() {
    return _remoteRenderer.srcObject != null
        ? RTCVideoView(
            _remoteRenderer,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
          )
        : const Center(
            child: CircularProgressIndicator(),
          );
  }

  Widget _buildLocalVideo() {
    return Positioned(
      right: 16,
      top: 16,
      child: GestureDetector(
        onPanUpdate: (details) {
          // TODO: Implement drag to move local video
        },
        child: Container(
          width: 120,
          height: 160,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: _isCameraOff
                ? const Center(
                    child: Icon(Icons.videocam_off, color: Colors.white),
                  )
                : RTCVideoView(
                    _localRenderer,
                    mirror: true,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildCallControls() {
    return Positioned(
      bottom: 32,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildControlButton(
              icon: _isMuted ? Icons.mic_off : Icons.mic,
              label: _isMuted ? 'Unmute' : 'Mute',
              onPressed: _toggleMute,
            ),
            _buildControlButton(
              icon: _isCameraOff ? Icons.videocam_off : Icons.videocam,
              label: _isCameraOff ? 'Camera On' : 'Camera Off',
              onPressed: _toggleCamera,
            ),
            _buildControlButton(
              icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
              label: _isSpeakerOn ? 'Speaker Off' : 'Speaker On',
              onPressed: _toggleSpeaker,
            ),
            _buildControlButton(
              icon: Icons.call_end,
              label: 'End',
              color: Colors.red,
              onPressed: () async {
                await widget.callService.endCall(widget.callInfo);
                if (mounted) {
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    return Positioned(
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
              Colors.black.withOpacity(0.8),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _getCallStatus(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: _handleMenuSelection,
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'quality',
                  child: Text('Video Quality'),
                ),
                const PopupMenuItem(
                  value: 'minimize',
                  child: Text('Minimize'),
                ),
                const PopupMenuItem(
                  value: 'stats',
                  child: Text('Call Stats'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color color = Colors.white,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          onPressed: onPressed,
          backgroundColor: color,
          child: Icon(icon, color: color == Colors.white ? Colors.black : Colors.white),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ],
    );
  }

  String _getCallStatus() {
    switch (widget.callInfo.callState) {
      case CallState.initiating:
        return 'Initializing call...';
      case CallState.ringing:
        return 'Ringing...';
      case CallState.accepted:
        return 'Connected';
      case CallState.declined:
        return 'Call declined';
      case CallState.missed:
        return 'Missed call';
      case CallState.ended:
        return 'Call ended';
      case CallState.busy:
        return 'User is busy';
      case CallState.failed:
        return 'Call failed';
      default:
        return '';
    }
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _localRenderer.srcObject?.getAudioTracks().forEach((track) {
        track.enabled = !_isMuted;
      });
    });
  }

  void _toggleCamera() {
    setState(() {
      _isCameraOff = !_isCameraOff;
      _localRenderer.srcObject?.getVideoTracks().forEach((track) {
        track.enabled = !_isCameraOff;
      });
    });
  }

  void _toggleSpeaker() {
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
      // TODO: Implement speaker toggle using platform-specific audio routing
    });
  }

  void _handleMenuSelection(String value) {
    switch (value) {
      case 'quality':
        _showQualitySettings();
        break;
      case 'minimize':
        setState(() {
          _isMinimized = !_isMinimized;
        });
        break;
      case 'stats':
        _showCallStats();
        break;
    }
  }

  void _showQualitySettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Video Quality'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('High (720p)'),
              onTap: () {
                // TODO: Implement quality change
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Medium (480p)'),
              onTap: () {
                // TODO: Implement quality change
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Low (360p)'),
              onTap: () {
                // TODO: Implement quality change
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCallStats() {
    // TODO: Implement call statistics display
    showDialog(
      context: context,
      builder: (context) => const AlertDialog(
        title: Text('Call Statistics'),
        content: Text('Coming soon...'),
      ),
    );
  }
} 