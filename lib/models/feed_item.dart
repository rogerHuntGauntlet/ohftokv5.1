import 'package:cloud_firestore/cloud_firestore.dart';

class FeedItem {
  final String id;
  final String userId;
  final String userDisplayName;
  final String userProfileImage;
  final String activityType; // e.g., 'post', 'like', 'follow', 'comment'
  final String? content;
  final String? movieId;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  FeedItem({
    required this.id,
    required this.userId,
    required this.userDisplayName,
    required this.userProfileImage,
    required this.activityType,
    this.content,
    this.movieId,
    required this.timestamp,
    this.metadata,
  });

  factory FeedItem.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return FeedItem(
      id: doc.id,
      userId: data['userId'] ?? '',
      userDisplayName: data['userDisplayName'] ?? '',
      userProfileImage: data['userProfileImage'] ?? '',
      activityType: data['activityType'] ?? '',
      content: data['content'],
      movieId: data['movieId'],
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      metadata: data['metadata'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userDisplayName': userDisplayName,
      'userProfileImage': userProfileImage,
      'activityType': activityType,
      'content': content,
      'movieId': movieId,
      'timestamp': Timestamp.fromDate(timestamp),
      'metadata': metadata,
    };
  }
} 