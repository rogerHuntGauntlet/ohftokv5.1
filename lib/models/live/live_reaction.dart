import 'package:cloud_firestore/cloud_firestore.dart';

enum ReactionType {
  like,
  love,
  laugh,
  wow,
  support,
  custom
}

class LiveReaction {
  final String id;
  final String streamId;
  final String userId;
  final String userDisplayName;
  final ReactionType type;
  final String? customEmoji;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  LiveReaction({
    required this.id,
    required this.streamId,
    required this.userId,
    required this.userDisplayName,
    required this.type,
    this.customEmoji,
    required this.timestamp,
    this.metadata,
  });

  factory LiveReaction.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return LiveReaction(
      id: doc.id,
      streamId: data['streamId'] ?? '',
      userId: data['userId'] ?? '',
      userDisplayName: data['userDisplayName'] ?? '',
      type: ReactionType.values.firstWhere(
        (e) => e.toString() == 'ReactionType.${data['type']}',
        orElse: () => ReactionType.like
      ),
      customEmoji: data['customEmoji'],
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      metadata: data['metadata'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'streamId': streamId,
      'userId': userId,
      'userDisplayName': userDisplayName,
      'type': type.toString().split('.').last,
      'customEmoji': customEmoji,
      'timestamp': Timestamp.fromDate(timestamp),
      'metadata': metadata,
    };
  }

  LiveReaction copyWith({
    String? id,
    String? streamId,
    String? userId,
    String? userDisplayName,
    ReactionType? type,
    String? customEmoji,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) {
    return LiveReaction(
      id: id ?? this.id,
      streamId: streamId ?? this.streamId,
      userId: userId ?? this.userId,
      userDisplayName: userDisplayName ?? this.userDisplayName,
      type: type ?? this.type,
      customEmoji: customEmoji ?? this.customEmoji,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
    );
  }
} 