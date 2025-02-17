import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/live/live_comment.dart';
import '../../models/live/live_viewer.dart';

class LiveCommentService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _currentStreamId;
  bool _isInitialized = false;

  String? get currentStreamId => _currentStreamId;
  bool get isInitialized => _isInitialized;

  // Initialize service with a stream
  void initialize(String streamId) {
    _currentStreamId = streamId;
    _isInitialized = true;
    notifyListeners();
  }

  // Add a new comment
  Future<LiveComment> addComment({
    required String streamId,
    required String userId,
    required String userDisplayName,
    String? userProfileImage,
    required String content,
    CommentType type = CommentType.regular,
    Map<String, dynamic>? metadata,
  }) async {
    final commentData = {
      'streamId': streamId,
      'userId': userId,
      'userDisplayName': userDisplayName,
      'userProfileImage': userProfileImage,
      'content': content,
      'timestamp': FieldValue.serverTimestamp(),
      'type': type.toString().split('.').last,
      'isHidden': false,
      'metadata': metadata,
    };

    final docRef = await _firestore
        .collection('live_streams')
        .doc(streamId)
        .collection('comments')
        .add(commentData);

    final doc = await docRef.get();
    return LiveComment.fromFirestore(doc);
  }

  // Get stream of comments for a live stream
  Stream<List<LiveComment>> getComments(String streamId) {
    return _firestore
        .collection('live_streams')
        .doc(streamId)
        .collection('comments')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) => 
            snapshot.docs.map((doc) => LiveComment.fromFirestore(doc)).toList());
  }

  // Hide/Show a comment
  Future<void> toggleCommentVisibility(String streamId, String commentId, bool isHidden) async {
    await _firestore
        .collection('live_streams')
        .doc(streamId)
        .collection('comments')
        .doc(commentId)
        .update({'isHidden': isHidden});
  }

  // Pin/Unpin a comment
  Future<void> toggleCommentPin(String streamId, String commentId, bool isPinned) async {
    final type = isPinned ? CommentType.pinned : CommentType.regular;
    await _firestore
        .collection('live_streams')
        .doc(streamId)
        .collection('comments')
        .doc(commentId)
        .update({'type': type.toString().split('.').last});
  }

  // Delete a comment
  Future<void> deleteComment(String streamId, String commentId) async {
    await _firestore
        .collection('live_streams')
        .doc(streamId)
        .collection('comments')
        .doc(commentId)
        .delete();
  }

  // Get pinned comments
  Stream<List<LiveComment>> getPinnedComments(String streamId) {
    return _firestore
        .collection('live_streams')
        .doc(streamId)
        .collection('comments')
        .where('type', isEqualTo: CommentType.pinned.toString().split('.').last)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => 
            snapshot.docs.map((doc) => LiveComment.fromFirestore(doc)).toList());
  }

  // Add a system message
  Future<LiveComment> addSystemMessage({
    required String streamId,
    required String content,
    Map<String, dynamic>? metadata,
  }) async {
    return addComment(
      streamId: streamId,
      userId: 'system',
      userDisplayName: 'System',
      content: content,
      type: CommentType.system,
      metadata: metadata,
    );
  }

  // Add a moderator message
  Future<LiveComment> addModeratorMessage({
    required String streamId,
    required String userId,
    required String userDisplayName,
    String? userProfileImage,
    required String content,
    Map<String, dynamic>? metadata,
  }) async {
    return addComment(
      streamId: streamId,
      userId: userId,
      userDisplayName: userDisplayName,
      userProfileImage: userProfileImage,
      content: content,
      type: CommentType.moderator,
      metadata: metadata,
    );
  }

  // Clean up
  void dispose() {
    _currentStreamId = null;
    _isInitialized = false;
    super.dispose();
  }
} 