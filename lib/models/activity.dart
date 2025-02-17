import 'package:cloud_firestore/cloud_firestore.dart';

class Activity {
  final String id;
  final String userId;
  final String type; // like, comment, follow, post, etc.
  final DateTime timestamp;
  final String? targetUserId; // User being followed, or whose content is being interacted with
  final String? movieId; // Related movie if applicable
  final String? sceneId; // Related scene if applicable
  final String? comment; // Comment content if applicable
  final Map<String, dynamic>? metadata; // Additional activity-specific data

  Activity({
    required this.id,
    required this.userId,
    required this.type,
    required this.timestamp,
    this.targetUserId,
    this.movieId,
    this.sceneId,
    this.comment,
    this.metadata,
  });

  factory Activity.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Activity(
      id: doc.id,
      userId: data['userId'] ?? '',
      type: data['type'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      targetUserId: data['targetUserId'],
      movieId: data['movieId'],
      sceneId: data['sceneId'],
      comment: data['comment'],
      metadata: data['metadata'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'type': type,
      'timestamp': Timestamp.fromDate(timestamp),
      'targetUserId': targetUserId,
      'movieId': movieId,
      'sceneId': sceneId,
      'comment': comment,
      'metadata': metadata,
    };
  }

  // Helper method to get activity description
  String getDescription() {
    switch (type) {
      case 'like':
        return 'liked a movie';
      case 'comment':
        return 'commented on a movie';
      case 'follow':
        return 'started following';
      case 'post':
        return 'posted a new movie';
      case 'fork':
        return 'created an mNp';
      case 'scene_complete':
        return 'completed a scene';
      case 'movie_complete':
        return 'completed a movie';
      default:
        return 'performed an action';
    }
  }
} 