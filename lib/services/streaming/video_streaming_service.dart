import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

enum StreamQuality {
  low(640, 360, 24, 800000),
  medium(854, 480, 30, 1500000),
  high(1280, 720, 30, 2500000),
  veryHigh(1920, 1080, 30, 4000000);

  final int width;
  final int height;
  final int frameRate;
  final int bitrate;

  const StreamQuality(this.width, this.height, this.frameRate, this.bitrate);
}

enum StreamLatency {
  ultraLow, // < 1s
  low, // 1-2s
  normal, // 2-4s
  high // > 4s
}

class VideoStreamingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  
  MediaStream? _localStream;
  RTCPeerConnection? _peerConnection;
  final Map<String, RTCPeerConnection> _viewers = {};
  bool _isMuted = false;
  bool _isCameraOff = false;
  StreamQuality _currentQuality = StreamQuality.high;
  StreamLatency _currentLatency = StreamLatency.low;
  String? _currentCameraDevice;
  List<MediaDeviceInfo>? _cameras;

  // Stream configuration based on quality
  final Map<StreamQuality, Map<String, dynamic>> _qualityConfigs = {
    StreamQuality.low: {
      'width': 640,
      'height': 360,
      'frameRate': 24,
      'bitrate': 800000, // 800 kbps
    },
    StreamQuality.medium: {
      'width': 854,
      'height': 480,
      'frameRate': 30,
      'bitrate': 1500000, // 1.5 Mbps
    },
    StreamQuality.high: {
      'width': 1280,
      'height': 720,
      'frameRate': 30,
      'bitrate': 2500000, // 2.5 Mbps
    },
    StreamQuality.veryHigh: {
      'width': 1920,
      'height': 1080,
      'frameRate': 30,
      'bitrate': 4000000, // 4 Mbps
    },
  };

  // Initialize streaming
  Future<void> initializeStream({
    required String streamId,
    required RTCVideoRenderer localRenderer,
    StreamQuality quality = StreamQuality.high,
    StreamLatency latency = StreamLatency.low,
  }) async {
    try {
      _currentQuality = quality;
      _currentLatency = latency;

      // Get available cameras
      _cameras = await navigator.mediaDevices.enumerateDevices();
      _currentCameraDevice = _cameras!
          .firstWhere((device) => device.kind == 'videoinput')
          .deviceId;

      // Get media stream with initial configuration
      await _getLocalStream(localRenderer);

      // Initialize WebRTC peer connection
      await _initializePeerConnection(streamId);

      // Log stream start
      await _analytics.logEvent(
        name: 'stream_started',
        parameters: {
          'stream_id': streamId,
          'quality': quality.toString(),
          'latency': latency.toString(),
        },
      );
    } catch (e) {
      print('Error initializing stream: $e');
      rethrow;
    }
  }

  // Get local media stream
  Future<void> _getLocalStream(RTCVideoRenderer localRenderer) async {
    final config = _qualityConfigs[_currentQuality]!;
    
    final constraints = {
      'audio': true,
      'video': {
        'mandatory': {
          'minWidth': config['width'].toString(),
          'minHeight': config['height'].toString(),
          'minFrameRate': config['frameRate'].toString(),
        },
        'facingMode': 'user',
        'optional': [
          {'sourceId': _currentCameraDevice},
        ],
      },
    };

    _localStream = await navigator.mediaDevices.getUserMedia(constraints);
    localRenderer.srcObject = _localStream;
  }

  // Initialize peer connection
  Future<void> _initializePeerConnection(String streamId) async {
    final configuration = {
      'iceServers': [
        {
          'urls': [
            'stun:stun1.l.google.com:19302',
            'stun:stun2.l.google.com:19302',
          ],
        },
      ],
      'sdpSemantics': 'unified-plan',
    };

    _peerConnection = await createPeerConnection(configuration);

    // Add local tracks to peer connection
    _localStream?.getTracks().forEach((track) {
      _peerConnection?.addTrack(track, _localStream!);
    });

    // Set up event handlers
    _setupPeerConnectionHandlers(streamId);
  }

  // Camera controls
  Future<void> flipCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;

    // Find next camera
    final currentIndex = _cameras!.indexWhere(
      (device) => device.deviceId == _currentCameraDevice,
    );
    final nextIndex = (currentIndex + 1) % _cameras!.length;
    _currentCameraDevice = _cameras![nextIndex].deviceId;

    // Stop current stream
    await _localStream?.dispose();

    // Get new stream with flipped camera
    await _getLocalStream(_peerConnection!.getLocalStreams().first as RTCVideoRenderer);
  }

  // Audio controls
  void toggleMute() {
    _isMuted = !_isMuted;
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = !_isMuted;
    });
  }

  void toggleCamera() {
    _isCameraOff = !_isCameraOff;
    _localStream?.getVideoTracks().forEach((track) {
      track.enabled = !_isCameraOff;
    });
  }

  // Quality settings
  Future<void> changeQuality(StreamQuality newQuality) async {
    if (newQuality == _currentQuality) return;

    _currentQuality = newQuality;
    final config = _qualityConfigs[newQuality]!;

    // Update video track constraints
    final localStream = _peerConnection?.getLocalStreams().firstOrNull;
    if (localStream == null) return;

    final videoTrack = localStream.getVideoTracks().firstOrNull;
    if (videoTrack == null) return;

    try {
      // Apply new constraints to the video track
      final constraints = {
        'width': config['width'],
        'height': config['height'],
        'frameRate': config['frameRate'],
        'mandatory': {
          'minWidth': config['width'].toString(),
          'minHeight': config['height'].toString(),
          'minFrameRate': config['frameRate'].toString(),
          'maxBitrate': config['bitrate'].toString(),
        },
      };

      await videoTrack.applyConstraints(constraints);
      
      // Update the current quality
      _currentQuality = newQuality;
      
      // Log quality change
      await _analytics.logEvent(
        name: 'stream_quality_changed',
        parameters: {
          'quality': newQuality.toString(),
          'width': config['width'],
          'height': config['height'],
          'frameRate': config['frameRate'],
          'bitrate': config['bitrate'],
        },
      );
    } catch (e) {
      print('Error updating video quality: $e');
    }
  }

  // Latency settings
  void changeLatency(StreamLatency newLatency) {
    _currentLatency = newLatency;
    // Implement latency adjustment logic
    // This might involve adjusting buffer sizes, encoding parameters, etc.
  }

  // Event handlers
  void _setupPeerConnectionHandlers(String streamId) {
    _peerConnection?.onIceCandidate = (candidate) {
      // Send ICE candidate to signaling server
      _firestore.collection('streams').doc(streamId).collection('candidates').add({
        'candidate': candidate.toMap(),
        'timestamp': FieldValue.serverTimestamp(),
      });
    };

    _peerConnection?.onTrack = (RTCTrackEvent event) {
      // Handle incoming tracks
      if (event.streams.isNotEmpty) {
        event.streams[0].getTracks().forEach((track) {
          // Handle track
        });
      }
    };

    _peerConnection?.onConnectionState = (state) {
      // Monitor connection state
      print('Connection state changed: $state');
    };
  }

  // Clean up
  Future<void> dispose() async {
    await _localStream?.dispose();
    await _peerConnection?.dispose();
    _viewers.forEach((_, pc) => pc.dispose());
    _viewers.clear();
  }

  // Getters
  bool get isMuted => _isMuted;
  bool get isCameraOff => _isCameraOff;
  StreamQuality get currentQuality => _currentQuality;
  StreamLatency get currentLatency => _currentLatency;

  Future<void> _updateVideoQuality(StreamQuality quality) async {
    if (_peerConnection == null) return;

    final localStream = _peerConnection?.getLocalStreams().firstOrNull;
    if (localStream == null) return;

    final videoTrack = localStream.getVideoTracks().firstOrNull;
    if (videoTrack == null) return;

    try {
      await videoTrack.applyConstraints({
        'width': quality.width,
        'height': quality.height,
        'frameRate': quality.frameRate,
        'bitrate': quality.bitrate,
      });
      _currentQuality = quality;
    } catch (e) {
      print('Error updating video quality: $e');
    }
  }
} 