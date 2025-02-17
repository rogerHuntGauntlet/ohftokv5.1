import 'package:cloud_firestore/cloud_firestore.dart';

class TypingStatus {
  final String userId;
  final String conversationId;
  final bool isTyping;
  final DateTime timestamp;

  TypingStatus({
    required this.userId,
    required this.conversationId,
    required this.isTyping,
    required this.timestamp,
  });

  factory TypingStatus.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return TypingStatus(
      userId: data['userId'] ?? '',
      conversationId: data['conversationId'] ?? '',
      isTyping: data['isTyping'] ?? false,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'conversationId': conversationId,
      'isTyping': isTyping,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
} 