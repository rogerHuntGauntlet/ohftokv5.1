import 'package:cloud_firestore/cloud_firestore.dart';

class LivePoll {
  final String id;
  final String streamId;
  final String question;
  final List<String> options;
  final Map<int, int> votes;
  final DateTime createdAt;
  final bool isActive;

  LivePoll({
    required this.id,
    required this.streamId,
    required this.question,
    required this.options,
    required this.votes,
    required this.createdAt,
    required this.isActive,
  });

  factory LivePoll.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LivePoll(
      id: doc.id,
      streamId: data['streamId'] as String,
      question: data['question'] as String,
      options: List<String>.from(data['options']),
      votes: Map<int, int>.from(
        (data['votes'] as Map<String, dynamic>).map(
          (key, value) => MapEntry(int.parse(key), value as int),
        ),
      ),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      isActive: data['isActive'] as bool,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'streamId': streamId,
      'question': question,
      'options': options,
      'votes': votes.map((key, value) => MapEntry(key.toString(), value)),
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
    };
  }

  LivePoll copyWith({
    String? id,
    String? streamId,
    String? question,
    List<String>? options,
    Map<int, int>? votes,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return LivePoll(
      id: id ?? this.id,
      streamId: streamId ?? this.streamId,
      question: question ?? this.question,
      options: options ?? this.options,
      votes: votes ?? this.votes,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }
} 