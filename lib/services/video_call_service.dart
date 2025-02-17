import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import '../models/message.dart';

class VideoCallService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  
  final _iceServers = {
    'iceServers': [
      {
        'urls': [
          'stun:stun1.l.google.com:19302',
          'stun:stun2.l.google.com:19302',
        ],
      },
    ],
  };

  // Stream controllers for call state updates
  final _callStateController = StreamController<CallState>.broadcast();
  Stream<CallState> get callStateStream => _callStateController.stream;

  // Stream controllers for remote video
  final _remoteVideoController = StreamController<RTCVideoRenderer>.broadcast();
  Stream<RTCVideoRenderer> get remoteVideoStream => _remoteVideoController.stream;

  // Initialize a call
  Future<CallInfo> initializeCall({
    required String senderId,
    required String receiverId,
    required CallType callType,
    required String conversationId,
  }) async {
    final String callId = const Uuid().v4();
    final callInfo = CallInfo(
      callId: callId,
      callType: callType,
      callState: CallState.initiating,
      startTime: DateTime.now(),
      iceServers: _iceServers,
      participantStates: {
        senderId: true,
        receiverId: false,
      },
    );

    // Show incoming call UI for receiver
    await _showIncomingCallUI(
      callId: callId,
      callerId: senderId,
      callType: callType,
    );

    return callInfo;
  }

  // Start a call
  Future<void> startCall(CallInfo callInfo, RTCVideoRenderer localVideo) async {
    try {
      // Get user media
      final Map<String, dynamic> mediaConstraints = {
        'audio': true,
        'video': callInfo.callType == CallType.video
            ? {
                'mandatory': {
                  'minWidth': '640',
                  'minHeight': '480',
                  'minFrameRate': '30',
                },
                'facingMode': 'user',
                'optional': [],
              }
            : false,
      };

      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      localVideo.srcObject = _localStream;

      // Create peer connection
      _peerConnection = await createPeerConnection(
        callInfo.iceServers ?? _iceServers,
        {},
      );

      // Add local stream to peer connection
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      // Set up event handlers
      _setupPeerConnectionHandlers(callInfo);

      // Create and set local description
      RTCSessionDescription offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      // Update call info with offer
      await _updateCallInfo(
        callInfo.callId,
        callInfo.copyWith(
          callState: CallState.ringing,
          sdpOffer: offer.toMap(),
        ),
      );
    } catch (e) {
      await _handleCallError(callInfo, e.toString());
    }
  }

  // Answer a call
  Future<void> answerCall(CallInfo callInfo, RTCVideoRenderer localVideo) async {
    try {
      // Get user media
      final Map<String, dynamic> mediaConstraints = {
        'audio': true,
        'video': callInfo.callType == CallType.video
            ? {
                'mandatory': {
                  'minWidth': '640',
                  'minHeight': '480',
                  'minFrameRate': '30',
                },
                'facingMode': 'user',
                'optional': [],
              }
            : false,
      };

      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      localVideo.srcObject = _localStream;

      // Create peer connection
      _peerConnection = await createPeerConnection(
        callInfo.iceServers ?? _iceServers,
        {},
      );

      // Add local stream
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      // Set up event handlers
      _setupPeerConnectionHandlers(callInfo);

      // Set remote description from offer
      if (callInfo.sdpOffer != null) {
        await _peerConnection!.setRemoteDescription(
          RTCSessionDescription(
            callInfo.sdpOffer!['sdp'],
            callInfo.sdpOffer!['type'],
          ),
        );
      }

      // Create and set local description (answer)
      RTCSessionDescription answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      // Update call info with answer
      await _updateCallInfo(
        callInfo.callId,
        callInfo.copyWith(
          callState: CallState.accepted,
          sdpAnswer: answer.toMap(),
        ),
      );
    } catch (e) {
      await _handleCallError(callInfo, e.toString());
    }
  }

  // End a call
  Future<void> endCall(CallInfo callInfo) async {
    try {
      // Close peer connection
      await _peerConnection?.close();
      _peerConnection = null;

      // Stop local stream
      await _localStream?.dispose();
      _localStream = null;

      // Stop remote stream
      await _remoteStream?.dispose();
      _remoteStream = null;

      // Update call info
      await _updateCallInfo(
        callInfo.callId,
        callInfo.copyWith(
          callState: CallState.ended,
          endTime: DateTime.now(),
        ),
      );

      // Remove incoming call UI
      await FlutterCallkitIncoming.endCall(callInfo.callId);
    } catch (e) {
      print('Error ending call: $e');
    }
  }

  // Set up peer connection event handlers
  void _setupPeerConnectionHandlers(CallInfo callInfo) {
    // Handle ICE candidates
    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) async {
      await _addIceCandidate(callInfo.callId, candidate);
    };

    // Handle remote stream
    _peerConnection!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        final remoteVideo = RTCVideoRenderer();
        remoteVideo.initialize().then((_) {
          remoteVideo.srcObject = _remoteStream;
          _remoteVideoController.add(remoteVideo);
        });
      }
    };

    // Handle connection state changes
    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _handleCallError(callInfo, 'Connection failed');
      }
    };
  }

  // Update call info in Firestore
  Future<void> _updateCallInfo(String callId, CallInfo callInfo) async {
    await _firestore
        .collection('calls')
        .doc(callId)
        .set(callInfo.toMap(), SetOptions(merge: true));
  }

  // Add ICE candidate
  Future<void> _addIceCandidate(String callId, RTCIceCandidate candidate) async {
    await _firestore.collection('calls').doc(callId).update({
      'iceCandidates': FieldValue.arrayUnion([candidate.toMap()]),
    });
  }

  // Show incoming call UI
  Future<void> _showIncomingCallUI({
    required String callId,
    required String callerId,
    required CallType callType,
  }) async {
    final params = CallKitParams(
      id: callId,
      nameCaller: callerId,
      appName: 'OHFtok',
      type: callType == CallType.video ? 1 : 0,
      duration: 30000,
      textAccept: 'Accept',
      textDecline: 'Decline',
      extra: {'callerId': callerId},
      headers: {'apiKey': 'your-api-key'},
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: true,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#0955fa',
        backgroundUrl: 'assets/images/app_logo.png',
        actionColor: '#4CAF50',
      ),
      ios: const IOSParams(
        iconName: 'CallKitLogo',
        handleType: 'generic',
        supportsVideo: true,
        maximumCallGroups: 2,
        maximumCallsPerCallGroup: 1,
        audioSessionMode: 'default',
        audioSessionActive: true,
        audioSessionPreferredSampleRate: 44100.0,
        audioSessionPreferredIOBufferDuration: 0.005,
        supportsDTMF: true,
        supportsHolding: true,
        supportsGrouping: false,
        supportsUngrouping: false,
        ringtonePath: 'system_ringtone_default',
      ),
    );

    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }

  // Handle call errors
  Future<void> _handleCallError(CallInfo callInfo, String error) async {
    await _updateCallInfo(
      callInfo.callId,
      callInfo.copyWith(
        callState: CallState.failed,
        endTime: DateTime.now(),
        metadata: {'error': error},
      ),
    );

    // Close connections and streams
    await endCall(callInfo);
  }

  // Dispose resources
  void dispose() {
    _callStateController.close();
    _remoteVideoController.close();
    endCall(CallInfo(
      callId: '',
      callType: CallType.video,
      callState: CallState.ended,
      startTime: DateTime.now(),
    ));
  }
} 