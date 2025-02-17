import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/activity.dart';

class ActivityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const int _pageSize = 20;

  // Track a new activity
  Future<void> trackActivity({
    required String userId,
    required String type,
    String? targetUserId,
    String? movieId,
    String? sceneId,
    String? comment,
    Map<String, dynamic>? metadata,
  }) async {
    final activity = Activity(
      id: '', // Will be set by Firestore
      userId: userId,
      type: type,
      timestamp: DateTime.now(),
      targetUserId: targetUserId,
      movieId: movieId,
      sceneId: sceneId,
      comment: comment,
      metadata: metadata,
    );

    // Add to user's activity collection
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('activities')
        .add(activity.toMap());

    // If there's a target user, add to their notifications
    if (targetUserId != null) {
      await _firestore
          .collection('users')
          .doc(targetUserId)
          .collection('notifications')
          .add({
        ...activity.toMap(),
        'read': false,
      });
    }
  }

  // Get activities for a specific user
  Stream<List<Activity>> getUserActivities(String userId, {DocumentSnapshot? lastDocument}) {
    Query query = _firestore
        .collection('users')
        .doc(userId)
        .collection('activities')
        .orderBy('timestamp', descending: true)
        .limit(_pageSize);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Activity.fromFirestore(doc)).toList();
    });
  }

  // Get activities from followed users
  Stream<List<Activity>> getFollowedUsersActivities(
    String userId,
    List<String> followedUserIds, {
    DocumentSnapshot? lastDocument,
  }) {
    if (followedUserIds.isEmpty) {
      return Stream.value([]);
    }

    Query query = _firestore
        .collectionGroup('activities')
        .where('userId', whereIn: followedUserIds)
        .orderBy('timestamp', descending: true)
        .limit(_pageSize);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Activity.fromFirestore(doc)).toList();
    });
  }

  // Get filtered activities
  Stream<List<Activity>> getFilteredActivities(
    String userId,
    List<String> types, {
    DocumentSnapshot? lastDocument,
  }) {
    Query query = _firestore
        .collection('users')
        .doc(userId)
        .collection('activities')
        .where('type', whereIn: types)
        .orderBy('timestamp', descending: true)
        .limit(_pageSize);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Activity.fromFirestore(doc)).toList();
    });
  }

  // Delete old activities (older than 30 days)
  Future<void> deleteOldActivities(String userId) async {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('activities')
        .where('timestamp', isLessThan: Timestamp.fromDate(thirtyDaysAgo))
        .get();

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
} 