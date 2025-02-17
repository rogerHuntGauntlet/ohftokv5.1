import 'package:cloud_firestore/cloud_firestore.dart';

enum CommentType {
  regular,
  moderator,
  pinned,
  system,
  highlighted
}

class LiveComment {
  final String id;
  final String streamId;
  final String userId;
  final String userDisplayName;
  final String? userProfileImage;
  final String content;
  final DateTime timestamp;
  final CommentType type;
  final bool isHidden;
  final Map<String, dynamic>? metadata;

  LiveComment({
    required this.id,
    required this.streamId,
    required this.userId,
    required this.userDisplayName,
    this.userProfileImage,
    required this.content,
    required this.timestamp,
    this.type = CommentType.regular,
    this.isHidden = false,
    this.metadata,
  });

  factory LiveComment.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return LiveComment(
      id: doc.id,
      streamId: data['streamId'] ?? '',
      userId: data['userId'] ?? '',
      userDisplayName: data['userDisplayName'] ?? '',
      userProfileImage: data['userProfileImage'],
      content: data['content'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      type: CommentType.values.firstWhere(
        (e) => e.toString() == 'CommentType.${data['type']}',
        orElse: () => CommentType.regular
      ),
      isHidden: data['isHidden'] ?? false,
      metadata: data['metadata'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'streamId': streamId,
      'userId': userId,
      'userDisplayName': userDisplayName,
      'userProfileImage': userProfileImage,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'type': type.toString().split('.').last,
      'isHidden': isHidden,
      'metadata': metadata,
    };
  }

  LiveComment copyWith({
    String? id,
    String? streamId,
    String? userId,
    String? userDisplayName,
    String? userProfileImage,
    String? content,
    DateTime? timestamp,
    CommentType? type,
    bool? isHidden,
    Map<String, dynamic>? metadata,
  }) {
    return LiveComment(
      id: id ?? this.id,
      streamId: streamId ?? this.streamId,
      userId: userId ?? this.userId,
      userDisplayName: userDisplayName ?? this.userDisplayName,
      userProfileImage: userProfileImage ?? this.userProfileImage,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      isHidden: isHidden ?? this.isHidden,
      metadata: metadata ?? this.metadata,
    );
  }
} 