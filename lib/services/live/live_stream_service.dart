import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/live/live_stream.dart';
import '../../models/live/live_viewer.dart';

class LiveStreamService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  LiveStream? _currentStream;
  bool _isInitialized = false;

  LiveStream? get currentStream => _currentStream;
  bool get isInitialized => _isInitialized;

  // Create a new live stream
  Future<LiveStream> createStream({
    required String hostId,
    required String title,
    String? description,
    DateTime? scheduledFor,
    Map<String, dynamic>? settings,
  }) async {
    final streamData = {
      'hostId': hostId,
      'title': title,
      'description': description,
      'createdAt': FieldValue.serverTimestamp(),
      'scheduledFor': scheduledFor != null ? Timestamp.fromDate(scheduledFor) : null,
      'status': LiveStreamStatus.scheduled.toString().split('.').last,
      'viewerCount': 0,
      'settings': settings,
    };

    final docRef = await _firestore.collection('live_streams').add(streamData);
    final doc = await docRef.get();
    final stream = LiveStream.fromFirestore(doc);
    _currentStream = stream;
    notifyListeners();
    return stream;
  }

  // Start a live stream
  Future<void> startStream(String streamId) async {
    await _firestore.collection('live_streams').doc(streamId).update({
      'status': LiveStreamStatus.live.toString().split('.').last,
      'startedAt': FieldValue.serverTimestamp(),
    });
    
    if (_currentStream?.id == streamId) {
      _currentStream = _currentStream?.copyWith(
        status: LiveStreamStatus.live,
        startedAt: DateTime.now(),
      );
      notifyListeners();
    }
  }

  // End a live stream
  Future<void> endStream(String streamId) async {
    await _firestore.collection('live_streams').doc(streamId).update({
      'status': LiveStreamStatus.ended.toString().split('.').last,
      'endedAt': FieldValue.serverTimestamp(),
    });
    
    if (_currentStream?.id == streamId) {
      _currentStream = _currentStream?.copyWith(
        status: LiveStreamStatus.ended,
        endedAt: DateTime.now(),
      );
      notifyListeners();
    }
  }

  // Get a specific live stream
  Stream<LiveStream> getStream(String streamId) {
    return _firestore
        .collection('live_streams')
        .doc(streamId)
        .snapshots()
        .map((doc) => LiveStream.fromFirestore(doc));
  }

  // Get active live streams
  Stream<List<LiveStream>> getActiveStreams() {
    return _firestore
        .collection('live_streams')
        .where('status', isEqualTo: LiveStreamStatus.live.toString().split('.').last)
        .orderBy('startedAt', descending: true)
        .snapshots()
        .map((snapshot) => 
            snapshot.docs.map((doc) => LiveStream.fromFirestore(doc)).toList());
  }

  // Get scheduled streams
  Stream<List<LiveStream>> getScheduledStreams() {
    return _firestore
        .collection('live_streams')
        .where('status', isEqualTo: LiveStreamStatus.scheduled.toString().split('.').last)
        .orderBy('scheduledFor', descending: false)
        .snapshots()
        .map((snapshot) => 
            snapshot.docs.map((doc) => LiveStream.fromFirestore(doc)).toList());
  }

  // Update stream details
  Future<void> updateStream(String streamId, {
    String? title,
    String? description,
    DateTime? scheduledFor,
    Map<String, dynamic>? settings,
  }) async {
    final updates = <String, dynamic>{};
    if (title != null) updates['title'] = title;
    if (description != null) updates['description'] = description;
    if (scheduledFor != null) updates['scheduledFor'] = Timestamp.fromDate(scheduledFor);
    if (settings != null) updates['settings'] = settings;

    await _firestore.collection('live_streams').doc(streamId).update(updates);
    
    if (_currentStream?.id == streamId) {
      _currentStream = _currentStream?.copyWith(
        title: title,
        description: description,
        scheduledFor: scheduledFor,
        settings: settings,
      );
      notifyListeners();
    }
  }

  // Update viewer count
  Future<void> updateViewerCount(String streamId, int count) async {
    await _firestore.collection('live_streams').doc(streamId).update({
      'viewerCount': count,
    });
    
    if (_currentStream?.id == streamId) {
      _currentStream = _currentStream?.copyWith(viewerCount: count);
      notifyListeners();
    }
  }

  // Initialize service with a stream
  Future<void> initialize(String streamId) async {
    final doc = await _firestore.collection('live_streams').doc(streamId).get();
    if (doc.exists) {
      _currentStream = LiveStream.fromFirestore(doc);
      _isInitialized = true;
      notifyListeners();
    }
  }

  // Clean up
  void dispose() {
    _currentStream = null;
    _isInitialized = false;
    super.dispose();
  }
} 