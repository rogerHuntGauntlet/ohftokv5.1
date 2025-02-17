import 'package:cloud_firestore/cloud_firestore.dart';

class FeedItem {
  final String id;
  final String userId;
  final String userDisplayName;
  final String userProfileImage;
  final String contentType; // 'movie', 'scene', 'activity'
  final String contentId;
  final String? contentPreviewUrl;
  final String? description;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;
  final int likeCount;
  final int commentCount;
  final bool isLiked;

  FeedItem({
    required this.id,
    required this.userId,
    required this.userDisplayName,
    required this.userProfileImage,
    required this.contentType,
    required this.contentId,
    this.contentPreviewUrl,
    this.description,
    required this.createdAt,
    this.metadata,
    this.likeCount = 0,
    this.commentCount = 0,
    this.isLiked = false,
  });

  factory FeedItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FeedItem(
      id: doc.id,
      userId: data['userId'] ?? '',
      userDisplayName: data['userDisplayName'] ?? '',
      userProfileImage: data['userProfileImage'] ?? '',
      contentType: data['contentType'] ?? '',
      contentId: data['contentId'] ?? '',
      contentPreviewUrl: data['contentPreviewUrl'],
      description: data['description'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      metadata: data['metadata'],
      likeCount: data['likeCount'] ?? 0,
      commentCount: data['commentCount'] ?? 0,
      isLiked: data['isLiked'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userDisplayName': userDisplayName,
      'userProfileImage': userProfileImage,
      'contentType': contentType,
      'contentId': contentId,
      'contentPreviewUrl': contentPreviewUrl,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      'metadata': metadata,
      'likeCount': likeCount,
      'commentCount': commentCount,
      'isLiked': isLiked,
    };
  }

  FeedItem copyWith({
    String? id,
    String? userId,
    String? userDisplayName,
    String? userProfileImage,
    String? contentType,
    String? contentId,
    String? contentPreviewUrl,
    String? description,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
    int? likeCount,
    int? commentCount,
    bool? isLiked,
  }) {
    return FeedItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userDisplayName: userDisplayName ?? this.userDisplayName,
      userProfileImage: userProfileImage ?? this.userProfileImage,
      contentType: contentType ?? this.contentType,
      contentId: contentId ?? this.contentId,
      contentPreviewUrl: contentPreviewUrl ?? this.contentPreviewUrl,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      metadata: metadata ?? this.metadata,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      isLiked: isLiked ?? this.isLiked,
    );
  }
} 