import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/live/live_reaction.dart';

class LiveReactionService extends ChangeNotifier {
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

  // Add a new reaction
  Future<LiveReaction> addReaction({
    required String streamId,
    required String userId,
    required String userDisplayName,
    required ReactionType type,
    String? customEmoji,
    Map<String, dynamic>? metadata,
  }) async {
    final reactionData = {
      'streamId': streamId,
      'userId': userId,
      'userDisplayName': userDisplayName,
      'type': type.toString().split('.').last,
      'customEmoji': customEmoji,
      'timestamp': FieldValue.serverTimestamp(),
      'metadata': metadata,
    };

    final docRef = await _firestore
        .collection('live_streams')
        .doc(streamId)
        .collection('reactions')
        .add(reactionData);

    final doc = await docRef.get();
    return LiveReaction.fromFirestore(doc);
  }

  // Get stream of recent reactions
  Stream<List<LiveReaction>> getRecentReactions(String streamId) {
    return _firestore
        .collection('live_streams')
        .doc(streamId)
        .collection('reactions')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => 
            snapshot.docs.map((doc) => LiveReaction.fromFirestore(doc)).toList());
  }

  // Get reaction counts by type
  Stream<Map<ReactionType, int>> getReactionCounts(String streamId) {
    return _firestore
        .collection('live_streams')
        .doc(streamId)
        .collection('reactions')
        .snapshots()
        .map((snapshot) {
          final counts = <ReactionType, int>{};
          for (final type in ReactionType.values) {
            counts[type] = 0;
          }
          
          for (final doc in snapshot.docs) {
            final reaction = LiveReaction.fromFirestore(doc);
            counts[reaction.type] = (counts[reaction.type] ?? 0) + 1;
          }
          
          return counts;
        });
  }

  // Get user reactions
  Stream<List<LiveReaction>> getUserReactions(String streamId, String userId) {
    return _firestore
        .collection('live_streams')
        .doc(streamId)
        .collection('reactions')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => 
            snapshot.docs.map((doc) => LiveReaction.fromFirestore(doc)).toList());
  }

  // Delete a reaction
  Future<void> deleteReaction(String streamId, String reactionId) async {
    await _firestore
        .collection('live_streams')
        .doc(streamId)
        .collection('reactions')
        .doc(reactionId)
        .delete();
  }

  // Add a custom reaction
  Future<LiveReaction> addCustomReaction({
    required String streamId,
    required String userId,
    required String userDisplayName,
    required String customEmoji,
    Map<String, dynamic>? metadata,
  }) async {
    return addReaction(
      streamId: streamId,
      userId: userId,
      userDisplayName: userDisplayName,
      type: ReactionType.custom,
      customEmoji: customEmoji,
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