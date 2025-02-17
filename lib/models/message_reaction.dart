import 'package:cloud_firestore/cloud_firestore.dart';

class MessageReaction {
  final String id;
  final String messageId;
  final String userId;
  final String reactionType;
  final DateTime timestamp;

  MessageReaction({
    required this.id,
    required this.messageId,
    required this.userId,
    required this.reactionType,
    required this.timestamp,
  });

  factory MessageReaction.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return MessageReaction(
      id: doc.id,
      messageId: data['messageId'] ?? '',
      userId: data['userId'] ?? '',
      reactionType: data['reactionType'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'userId': userId,
      'reactionType': reactionType,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}

class ReactionType {
  static const String like = '👍';
  static const String love = '❤️';
  static const String laugh = '😂';
  static const String wow = '😮';
  static const String sad = '😢';
  static const String angry = '😠';

  static List<String> get all => [
        like,
        love,
        laugh,
        wow,
        sad,
        angry,
      ];
} 