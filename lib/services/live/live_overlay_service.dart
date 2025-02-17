import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/live/live_overlay.dart';

class LiveOverlayService {
  final FirebaseFirestore _firestore;
  final String _collection = 'live_overlays';

  LiveOverlayService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> createOverlay({
    required String streamId,
    required OverlayType type,
    required String content,
    Map<String, dynamic>? metadata,
    DateTime? expiresAt,
    String? style,
    Map<String, dynamic>? animation,
    int priority = 0,
  }) async {
    final overlay = {
      'streamId': streamId,
      'type': type.toString().split('.').last,
      'content': content,
      'metadata': metadata,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt) : null,
      'style': style,
      'animation': animation,
      'isActive': true,
      'priority': priority,
    };

    await _firestore.collection(_collection).add(overlay);
  }

  Future<void> updateOverlay({
    required String overlayId,
    String? content,
    Map<String, dynamic>? metadata,
    DateTime? expiresAt,
    String? style,
    Map<String, dynamic>? animation,
    bool? isActive,
    int? priority,
  }) async {
    final updates = <String, dynamic>{};
    
    if (content != null) updates['content'] = content;
    if (metadata != null) updates['metadata'] = metadata;
    if (expiresAt != null) updates['expiresAt'] = Timestamp.fromDate(expiresAt);
    if (style != null) updates['style'] = style;
    if (animation != null) updates['animation'] = animation;
    if (isActive != null) updates['isActive'] = isActive;
    if (priority != null) updates['priority'] = priority;

    if (updates.isNotEmpty) {
      await _firestore.collection(_collection).doc(overlayId).update(updates);
    }
  }

  Future<void> deactivateOverlay(String overlayId) async {
    await _firestore
        .collection(_collection)
        .doc(overlayId)
        .update({'isActive': false});
  }

  Future<void> deleteOverlay(String overlayId) async {
    await _firestore.collection(_collection).doc(overlayId).delete();
  }

  Stream<List<LiveOverlay>> getActiveOverlays(String streamId) {
    return _firestore
        .collection(_collection)
        .where('streamId', isEqualTo: streamId)
        .where('isActive', isEqualTo: true)
        .orderBy('priority', descending: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => LiveOverlay.fromFirestore(doc)).toList();
        });
  }

  Stream<List<LiveOverlay>> getOverlaysByType(String streamId, OverlayType type) {
    return _firestore
        .collection(_collection)
        .where('streamId', isEqualTo: streamId)
        .where('type', isEqualTo: type.toString().split('.').last)
        .where('isActive', isEqualTo: true)
        .orderBy('priority', descending: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => LiveOverlay.fromFirestore(doc)).toList();
        });
  }

  // Helper methods for specific overlay types
  Future<void> createAnnouncement({
    required String streamId,
    required String content,
    DateTime? expiresAt,
    String? style,
    Map<String, dynamic>? animation,
  }) async {
    await createOverlay(
      streamId: streamId,
      type: OverlayType.announcement,
      content: content,
      expiresAt: expiresAt,
      style: style,
      animation: animation,
      priority: 100, // High priority for announcements
    );
  }

  Future<void> featureComment({
    required String streamId,
    required String content,
    required Map<String, dynamic> commentData,
    String? style,
    Map<String, dynamic>? animation,
  }) async {
    await createOverlay(
      streamId: streamId,
      type: OverlayType.featuredComment,
      content: content,
      metadata: commentData,
      expiresAt: DateTime.now().add(const Duration(seconds: 30)),
      style: style,
      animation: animation,
      priority: 50,
    );
  }

  Future<void> featureResponse({
    required String streamId,
    required String content,
    required Map<String, dynamic> responseData,
    String? style,
    Map<String, dynamic>? animation,
  }) async {
    await createOverlay(
      streamId: streamId,
      type: OverlayType.featuredResponse,
      content: content,
      metadata: responseData,
      expiresAt: DateTime.now().add(const Duration(seconds: 30)),
      style: style,
      animation: animation,
      priority: 50,
    );
  }

  Future<void> showReaction({
    required String streamId,
    required String content,
    required Map<String, dynamic> reactionData,
    String? style,
    Map<String, dynamic>? animation,
  }) async {
    await createOverlay(
      streamId: streamId,
      type: OverlayType.reaction,
      content: content,
      metadata: reactionData,
      expiresAt: DateTime.now().add(const Duration(seconds: 5)),
      style: style,
      animation: animation,
      priority: 10,
    );
  }

  Future<void> captureMoment({
    required String streamId,
    required String content,
    required Map<String, dynamic> momentData,
    String? style,
    Map<String, dynamic>? animation,
  }) async {
    await createOverlay(
      streamId: streamId,
      type: OverlayType.moment,
      content: content,
      metadata: momentData,
      expiresAt: DateTime.now().add(const Duration(seconds: 15)),
      style: style,
      animation: animation,
      priority: 75,
    );
  }
} 