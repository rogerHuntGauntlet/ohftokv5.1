import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/live/live_viewer.dart';

class LiveViewerService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _currentStreamId;
  LiveViewer? _currentViewer;
  bool _isInitialized = false;

  String? get currentStreamId => _currentStreamId;
  LiveViewer? get currentViewer => _currentViewer;
  bool get isInitialized => _isInitialized;

  // Initialize service with a stream and viewer
  Future<void> initialize(String streamId, String userId) async {
    _currentStreamId = streamId;
    
    // Get or create viewer document
    final viewerDoc = await _firestore
        .collection('live_streams')
        .doc(streamId)
        .collection('viewers')
        .doc(userId)
        .get();

    if (viewerDoc.exists) {
      _currentViewer = LiveViewer.fromFirestore(viewerDoc);
    }
    
    _isInitialized = true;
    notifyListeners();
  }

  // Join stream as viewer
  Future<LiveViewer> joinStream({
    required String streamId,
    required String userId,
    required String userDisplayName,
    String? userProfileImage,
    ViewerRole role = ViewerRole.viewer,
    Map<String, dynamic>? metadata,
  }) async {
    final viewerData = {
      'streamId': streamId,
      'userId': userId,
      'userDisplayName': userDisplayName,
      'userProfileImage': userProfileImage,
      'role': role.toString().split('.').last,
      'joinedAt': FieldValue.serverTimestamp(),
      'lastActive': FieldValue.serverTimestamp(),
      'isActive': true,
      'metadata': metadata,
    };

    await _firestore
        .collection('live_streams')
        .doc(streamId)
        .collection('viewers')
        .doc(userId)
        .set(viewerData);

    final doc = await _firestore
        .collection('live_streams')
        .doc(streamId)
        .collection('viewers')
        .doc(userId)
        .get();

    final viewer = LiveViewer.fromFirestore(doc);
    if (streamId == _currentStreamId) {
      _currentViewer = viewer;
      notifyListeners();
    }
    return viewer;
  }

  // Leave stream
  Future<void> leaveStream(String streamId, String userId) async {
    await _firestore
        .collection('live_streams')
        .doc(streamId)
        .collection('viewers')
        .doc(userId)
        .update({
          'isActive': false,
          'lastActive': FieldValue.serverTimestamp(),
        });

    if (streamId == _currentStreamId && userId == _currentViewer?.userId) {
      _currentViewer = _currentViewer?.copyWith(isActive: false);
      notifyListeners();
    }
  }

  // Update viewer's last active timestamp
  Future<void> updateLastActive(String streamId, String userId) async {
    await _firestore
        .collection('live_streams')
        .doc(streamId)
        .collection('viewers')
        .doc(userId)
        .update({
          'lastActive': FieldValue.serverTimestamp(),
        });
  }

  // Get active viewers
  Stream<List<LiveViewer>> getActiveViewers(String streamId) {
    return _firestore
        .collection('live_streams')
        .doc(streamId)
        .collection('viewers')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => 
            snapshot.docs.map((doc) => LiveViewer.fromFirestore(doc)).toList());
  }

  // Get viewers by role
  Stream<List<LiveViewer>> getViewersByRole(String streamId, ViewerRole role) {
    return _firestore
        .collection('live_streams')
        .doc(streamId)
        .collection('viewers')
        .where('role', isEqualTo: role.toString().split('.').last)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => 
            snapshot.docs.map((doc) => LiveViewer.fromFirestore(doc)).toList());
  }

  // Update viewer role
  Future<void> updateViewerRole(String streamId, String userId, ViewerRole newRole) async {
    await _firestore
        .collection('live_streams')
        .doc(streamId)
        .collection('viewers')
        .doc(userId)
        .update({
          'role': newRole.toString().split('.').last,
        });

    if (streamId == _currentStreamId && userId == _currentViewer?.userId) {
      _currentViewer = _currentViewer?.copyWith(role: newRole);
      notifyListeners();
    }
  }

  // Ban viewer
  Future<void> banViewer(String streamId, String userId) async {
    await updateViewerRole(streamId, userId, ViewerRole.banned);
    await leaveStream(streamId, userId);
  }

  // Unban viewer
  Future<void> unbanViewer(String streamId, String userId) async {
    await updateViewerRole(streamId, userId, ViewerRole.viewer);
  }

  // Get banned viewers
  Stream<List<LiveViewer>> getBannedViewers(String streamId) {
    return getViewersByRole(streamId, ViewerRole.banned);
  }

  // Get moderators
  Stream<List<LiveViewer>> getModerators(String streamId) {
    return getViewersByRole(streamId, ViewerRole.moderator);
  }

  // Clean up
  void dispose() {
    _currentStreamId = null;
    _currentViewer = null;
    _isInitialized = false;
    super.dispose();
  }
} 