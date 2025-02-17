import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/feed_item.dart';

class FeedService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const int _pageSize = 20;

  // Get feed items for a user
  Stream<List<FeedItem>> getFeedItems(String userId, {DocumentSnapshot? lastDocument}) {
    Query query = _firestore.collection('feeds')
        .doc(userId)
        .collection('items')
        .orderBy('timestamp', descending: true)
        .limit(_pageSize);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => FeedItem.fromFirestore(doc)).toList();
    });
  }

  // Add a new feed item
  Future<void> addFeedItem(String userId, FeedItem item) async {
    await _firestore.collection('feeds')
        .doc(userId)
        .collection('items')
        .add(item.toMap());
  }

  // Add feed item to all followers
  Future<void> addFeedItemToFollowers(
    String userId,
    FeedItem item,
    List<String> followerIds,
  ) async {
    final batch = _firestore.batch();
    
    for (final followerId in followerIds) {
      final feedRef = _firestore.collection('feeds')
          .doc(followerId)
          .collection('items')
          .doc();
      batch.set(feedRef, item.toMap());
    }

    await batch.commit();
  }

  // Delete a feed item
  Future<void> deleteFeedItem(String userId, String itemId) async {
    await _firestore.collection('feeds')
        .doc(userId)
        .collection('items')
        .doc(itemId)
        .delete();
  }

  // Clear old feed items (older than 30 days)
  Future<void> clearOldFeedItems(String userId) async {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    final snapshot = await _firestore.collection('feeds')
        .doc(userId)
        .collection('items')
        .where('timestamp', isLessThan: Timestamp.fromDate(thirtyDaysAgo))
        .get();

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
} 