import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/feed_item.dart';

class FeedService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  static const int _pageSize = 20;

  // Get feed items with pagination
  Future<List<FeedItem>> getFeedItems({
    String? lastItemId,
    String? contentType,
    String? userId,
  }) async {
    Query query = _firestore.collection('feed_items')
        .orderBy('createdAt', descending: true)
        .limit(_pageSize);

    if (contentType != null) {
      query = query.where('contentType', isEqualTo: contentType);
    }

    if (userId != null) {
      query = query.where('userId', isEqualTo: userId);
    }

    if (lastItemId != null) {
      final lastDoc = await _firestore.collection('feed_items').doc(lastItemId).get();
      query = query.startAfterDocument(lastDoc);
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => FeedItem.fromFirestore(doc)).toList();
  }

  // Create a new feed item
  Future<String> createFeedItem({
    required String contentType,
    required String contentId,
    String? contentPreviewUrl,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userData = userDoc.data() as Map<String, dynamic>;

    final feedItem = {
      'userId': user.uid,
      'userDisplayName': userData['displayName'] ?? '',
      'userProfileImage': userData['profileImage'] ?? '',
      'contentType': contentType,
      'contentId': contentId,
      'contentPreviewUrl': contentPreviewUrl,
      'description': description,
      'createdAt': FieldValue.serverTimestamp(),
      'metadata': metadata,
      'likeCount': 0,
      'commentCount': 0,
    };

    final doc = await _firestore.collection('feed_items').add(feedItem);
    return doc.id;
  }

  // Like/unlike a feed item
  Future<void> toggleLike(String feedItemId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final likeRef = _firestore
        .collection('feed_items')
        .doc(feedItemId)
        .collection('likes')
        .doc(user.uid);

    final likeDoc = await likeRef.get();

    await _firestore.runTransaction((transaction) async {
      final feedItemRef = _firestore.collection('feed_items').doc(feedItemId);
      final feedItemDoc = await transaction.get(feedItemRef);
      
      if (!feedItemDoc.exists) {
        throw Exception('Feed item not found');
      }

      if (likeDoc.exists) {
        // Unlike
        transaction.delete(likeRef);
        transaction.update(feedItemRef, {
          'likeCount': FieldValue.increment(-1),
        });
      } else {
        // Like
        transaction.set(likeRef, {
          'userId': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
        transaction.update(feedItemRef, {
          'likeCount': FieldValue.increment(1),
        });
      }
    });
  }

  // Check if user has liked a feed item
  Future<bool> hasLiked(String feedItemId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final likeDoc = await _firestore
        .collection('feed_items')
        .doc(feedItemId)
        .collection('likes')
        .doc(user.uid)
        .get();

    return likeDoc.exists;
  }

  // Delete a feed item
  Future<void> deleteFeedItem(String feedItemId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final feedItem = await _firestore.collection('feed_items').doc(feedItemId).get();
    
    if (!feedItem.exists) throw Exception('Feed item not found');
    if (feedItem.data()?['userId'] != user.uid) {
      throw Exception('Not authorized to delete this feed item');
    }

    await _firestore.collection('feed_items').doc(feedItemId).delete();
  }

  // Get feed items for following users
  Future<List<FeedItem>> getFollowingFeed({String? lastItemId}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Get list of users being followed
    final following = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('following')
        .get();

    final followingIds = following.docs.map((doc) => doc.id).toList();
    if (followingIds.isEmpty) return [];

    Query query = _firestore.collection('feed_items')
        .where('userId', whereIn: followingIds)
        .orderBy('createdAt', descending: true)
        .limit(_pageSize);

    if (lastItemId != null) {
      final lastDoc = await _firestore.collection('feed_items').doc(lastItemId).get();
      query = query.startAfterDocument(lastDoc);
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => FeedItem.fromFirestore(doc)).toList();
  }
} 