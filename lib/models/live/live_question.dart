import 'package:cloud_firestore/cloud_firestore.dart';

class LiveQuestion {
  final String id;
  final String streamId;
  final String userId;
  final String userDisplayName;
  final String? userProfileImage;
  final String question;
  final String? answer;
  final DateTime createdAt;
  final DateTime? answeredAt;
  final bool isAnswered;
  final int upvotes;
  final List<String> upvoterIds;

  LiveQuestion({
    required this.id,
    required this.streamId,
    required this.userId,
    required this.userDisplayName,
    this.userProfileImage,
    required this.question,
    this.answer,
    required this.createdAt,
    this.answeredAt,
    required this.isAnswered,
    required this.upvotes,
    required this.upvoterIds,
  });

  factory LiveQuestion.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LiveQuestion(
      id: doc.id,
      streamId: data['streamId'] as String,
      userId: data['userId'] as String,
      userDisplayName: data['userDisplayName'] as String,
      userProfileImage: data['userProfileImage'] as String?,
      question: data['question'] as String,
      answer: data['answer'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      answeredAt: data['answeredAt'] != null
          ? (data['answeredAt'] as Timestamp).toDate()
          : null,
      isAnswered: data['isAnswered'] as bool,
      upvotes: data['upvotes'] as int,
      upvoterIds: List<String>.from(data['upvoterIds'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'streamId': streamId,
      'userId': userId,
      'userDisplayName': userDisplayName,
      'userProfileImage': userProfileImage,
      'question': question,
      'answer': answer,
      'createdAt': Timestamp.fromDate(createdAt),
      'answeredAt': answeredAt != null ? Timestamp.fromDate(answeredAt!) : null,
      'isAnswered': isAnswered,
      'upvotes': upvotes,
      'upvoterIds': upvoterIds,
    };
  }

  LiveQuestion copyWith({
    String? id,
    String? streamId,
    String? userId,
    String? userDisplayName,
    String? userProfileImage,
    String? question,
    String? answer,
    DateTime? createdAt,
    DateTime? answeredAt,
    bool? isAnswered,
    int? upvotes,
    List<String>? upvoterIds,
  }) {
    return LiveQuestion(
      id: id ?? this.id,
      streamId: streamId ?? this.streamId,
      userId: userId ?? this.userId,
      userDisplayName: userDisplayName ?? this.userDisplayName,
      userProfileImage: userProfileImage ?? this.userProfileImage,
      question: question ?? this.question,
      answer: answer ?? this.answer,
      createdAt: createdAt ?? this.createdAt,
      answeredAt: answeredAt ?? this.answeredAt,
      isAnswered: isAnswered ?? this.isAnswered,
      upvotes: upvotes ?? this.upvotes,
      upvoterIds: upvoterIds ?? this.upvoterIds,
    );
  }
} 