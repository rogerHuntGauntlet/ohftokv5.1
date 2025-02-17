import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/live/live_question.dart';

class LiveQuestionService {
  final FirebaseFirestore _firestore;
  final String _collection = 'live_questions';

  LiveQuestionService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> askQuestion({
    required String streamId,
    required String userId,
    required String userDisplayName,
    String? userProfileImage,
    required String question,
  }) async {
    final questionData = {
      'streamId': streamId,
      'userId': userId,
      'userDisplayName': userDisplayName,
      'userProfileImage': userProfileImage,
      'question': question,
      'answer': null,
      'createdAt': FieldValue.serverTimestamp(),
      'answeredAt': null,
      'isAnswered': false,
      'upvotes': 0,
      'upvoterIds': [],
    };

    await _firestore.collection(_collection).add(questionData);
  }

  Future<void> answerQuestion({
    required String questionId,
    required String answer,
  }) async {
    await _firestore.collection(_collection).doc(questionId).update({
      'answer': answer,
      'answeredAt': FieldValue.serverTimestamp(),
      'isAnswered': true,
    });
  }

  Future<void> upvoteQuestion({
    required String questionId,
    required String userId,
  }) async {
    final questionRef = _firestore.collection(_collection).doc(questionId);

    return _firestore.runTransaction((transaction) async {
      final questionDoc = await transaction.get(questionRef);
      
      if (!questionDoc.exists) return;

      final upvoterIds = List<String>.from(questionDoc.data()!['upvoterIds'] ?? []);
      
      if (upvoterIds.contains(userId)) {
        // Remove upvote
        upvoterIds.remove(userId);
        transaction.update(questionRef, {
          'upvotes': FieldValue.increment(-1),
          'upvoterIds': upvoterIds,
        });
      } else {
        // Add upvote
        upvoterIds.add(userId);
        transaction.update(questionRef, {
          'upvotes': FieldValue.increment(1),
          'upvoterIds': upvoterIds,
        });
      }
    });
  }

  Stream<List<LiveQuestion>> getQuestions(String streamId) {
    return _firestore
        .collection(_collection)
        .where('streamId', isEqualTo: streamId)
        .orderBy('upvotes', descending: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => LiveQuestion.fromFirestore(doc)).toList();
        });
  }

  Stream<List<LiveQuestion>> getUnansweredQuestions(String streamId) {
    return _firestore
        .collection(_collection)
        .where('streamId', isEqualTo: streamId)
        .where('isAnswered', isEqualTo: false)
        .orderBy('upvotes', descending: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => LiveQuestion.fromFirestore(doc)).toList();
        });
  }

  Stream<List<LiveQuestion>> getAnsweredQuestions(String streamId) {
    return _firestore
        .collection(_collection)
        .where('streamId', isEqualTo: streamId)
        .where('isAnswered', isEqualTo: true)
        .orderBy('answeredAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => LiveQuestion.fromFirestore(doc)).toList();
        });
  }

  Future<void> deleteQuestion(String questionId) async {
    await _firestore.collection(_collection).doc(questionId).delete();
  }
} 