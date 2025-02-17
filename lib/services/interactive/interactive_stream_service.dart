import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

// Poll models
class Poll {
  final String id;
  final String question;
  final List<String> options;
  final Map<String, int> votes;
  final DateTime createdAt;
  final DateTime? endedAt;
  final bool isActive;

  Poll({
    required this.id,
    required this.question,
    required this.options,
    required this.votes,
    required this.createdAt,
    this.endedAt,
    this.isActive = true,
  });

  factory Poll.fromMap(Map<String, dynamic> map) {
    return Poll(
      id: map['id'],
      question: map['question'],
      options: List<String>.from(map['options']),
      votes: Map<String, int>.from(map['votes']),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      endedAt: map['endedAt'] != null ? (map['endedAt'] as Timestamp).toDate() : null,
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'question': question,
      'options': options,
      'votes': votes,
      'createdAt': Timestamp.fromDate(createdAt),
      'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
      'isActive': isActive,
    };
  }
}

// Q&A models
class Question {
  final String id;
  final String userId;
  final String userName;
  final String text;
  final int upvotes;
  final bool isAnswered;
  final DateTime createdAt;
  final String? answer;
  final DateTime? answeredAt;

  Question({
    required this.id,
    required this.userId,
    required this.userName,
    required this.text,
    this.upvotes = 0,
    this.isAnswered = false,
    required this.createdAt,
    this.answer,
    this.answeredAt,
  });

  factory Question.fromMap(Map<String, dynamic> map) {
    return Question(
      id: map['id'],
      userId: map['userId'],
      userName: map['userName'],
      text: map['text'],
      upvotes: map['upvotes'] ?? 0,
      isAnswered: map['isAnswered'] ?? false,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      answer: map['answer'],
      answeredAt: map['answeredAt'] != null ? (map['answeredAt'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'text': text,
      'upvotes': upvotes,
      'isAnswered': isAnswered,
      'createdAt': Timestamp.fromDate(createdAt),
      'answer': answer,
      'answeredAt': answeredAt != null ? Timestamp.fromDate(answeredAt!) : null,
    };
  }
}

// Story prompt models
class StoryPrompt {
  final String id;
  final String prompt;
  final List<String> responses;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? endedAt;
  final String? selectedResponseId;

  StoryPrompt({
    required this.id,
    required this.prompt,
    required this.responses,
    required this.isActive,
    required this.createdAt,
    this.endedAt,
    this.selectedResponseId,
  });

  factory StoryPrompt.fromMap(Map<String, dynamic> map) {
    return StoryPrompt(
      id: map['id'],
      prompt: map['prompt'],
      responses: List<String>.from(map['responses']),
      isActive: map['isActive'] ?? true,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      endedAt: map['endedAt'] != null ? (map['endedAt'] as Timestamp).toDate() : null,
      selectedResponseId: map['selectedResponseId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'prompt': prompt,
      'responses': responses,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
      'selectedResponseId': selectedResponseId,
    };
  }
}

class InteractiveStreamService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  // Polls
  Future<void> createPoll(String streamId, String question, List<String> options) async {
    final pollId = _firestore.collection('streams').doc(streamId).collection('polls').doc().id;
    final poll = Poll(
      id: pollId,
      question: question,
      options: options,
      votes: {},
      createdAt: DateTime.now(),
      isActive: true,
    );

    await _firestore
        .collection('streams')
        .doc(streamId)
        .collection('polls')
        .doc(pollId)
        .set(poll.toMap());

    await _analytics.logEvent(
      name: 'poll_created',
      parameters: {
        'stream_id': streamId,
        'poll_id': pollId,
      },
    );
  }

  Future<void> votePoll(String streamId, String pollId, String option, String userId) async {
    await _firestore
        .collection('streams')
        .doc(streamId)
        .collection('polls')
        .doc(pollId)
        .update({
      'votes.$option': FieldValue.increment(1),
    });

    await _analytics.logEvent(
      name: 'poll_vote',
      parameters: {
        'stream_id': streamId,
        'poll_id': pollId,
        'option': option,
      },
    );
  }

  Future<void> endPoll(String streamId, String pollId) async {
    await _firestore
        .collection('streams')
        .doc(streamId)
        .collection('polls')
        .doc(pollId)
        .update({
      'isActive': false,
      'endedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Poll>> getPolls(String streamId) {
    return _firestore
        .collection('streams')
        .doc(streamId)
        .collection('polls')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Poll.fromMap(doc.data())).toList());
  }

  // Q&A
  Future<void> askQuestion(String streamId, String userId, String userName, String text) async {
    final questionId = _firestore.collection('streams').doc(streamId).collection('questions').doc().id;
    final question = Question(
      id: questionId,
      userId: userId,
      userName: userName,
      text: text,
      createdAt: DateTime.now(),
    );

    await _firestore
        .collection('streams')
        .doc(streamId)
        .collection('questions')
        .doc(questionId)
        .set(question.toMap());

    await _analytics.logEvent(
      name: 'question_asked',
      parameters: {
        'stream_id': streamId,
        'question_id': questionId,
      },
    );
  }

  Future<void> upvoteQuestion(String streamId, String questionId) async {
    await _firestore
        .collection('streams')
        .doc(streamId)
        .collection('questions')
        .doc(questionId)
        .update({
      'upvotes': FieldValue.increment(1),
    });
  }

  Future<void> answerQuestion(String streamId, String questionId, String answer) async {
    await _firestore
        .collection('streams')
        .doc(streamId)
        .collection('questions')
        .doc(questionId)
        .update({
      'answer': answer,
      'isAnswered': true,
      'answeredAt': FieldValue.serverTimestamp(),
    });

    await _analytics.logEvent(
      name: 'question_answered',
      parameters: {
        'stream_id': streamId,
        'question_id': questionId,
      },
    );
  }

  Stream<List<Question>> getQuestions(String streamId) {
    return _firestore
        .collection('streams')
        .doc(streamId)
        .collection('questions')
        .orderBy('upvotes', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Question.fromMap(doc.data())).toList());
  }

  // Story Prompts
  Future<void> createStoryPrompt(String streamId, String prompt) async {
    final promptId = _firestore.collection('streams').doc(streamId).collection('prompts').doc().id;
    final storyPrompt = StoryPrompt(
      id: promptId,
      prompt: prompt,
      responses: [],
      isActive: true,
      createdAt: DateTime.now(),
    );

    await _firestore
        .collection('streams')
        .doc(streamId)
        .collection('prompts')
        .doc(promptId)
        .set(storyPrompt.toMap());

    await _analytics.logEvent(
      name: 'story_prompt_created',
      parameters: {
        'stream_id': streamId,
        'prompt_id': promptId,
      },
    );
  }

  Future<void> submitResponse(String streamId, String promptId, String response) async {
    await _firestore
        .collection('streams')
        .doc(streamId)
        .collection('prompts')
        .doc(promptId)
        .update({
      'responses': FieldValue.arrayUnion([response]),
    });

    await _analytics.logEvent(
      name: 'story_response_submitted',
      parameters: {
        'stream_id': streamId,
        'prompt_id': promptId,
      },
    );
  }

  Future<void> selectResponse(String streamId, String promptId, String responseId) async {
    await _firestore
        .collection('streams')
        .doc(streamId)
        .collection('prompts')
        .doc(promptId)
        .update({
      'selectedResponseId': responseId,
      'isActive': false,
      'endedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<StoryPrompt>> getStoryPrompts(String streamId) {
    return _firestore
        .collection('streams')
        .doc(streamId)
        .collection('prompts')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => StoryPrompt.fromMap(doc.data())).toList());
  }
} 