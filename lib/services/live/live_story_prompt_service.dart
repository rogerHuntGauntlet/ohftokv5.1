import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/live/live_story_prompt.dart';

class LiveStoryPromptService {
  final FirebaseFirestore _firestore;
  final String _collection = 'live_story_prompts';

  LiveStoryPromptService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> createPrompt({
    required String streamId,
    required String prompt,
  }) async {
    final promptData = {
      'streamId': streamId,
      'prompt': prompt,
      'selectedResponse': null,
      'selectedUserId': null,
      'selectedUserDisplayName': null,
      'createdAt': FieldValue.serverTimestamp(),
      'selectedAt': null,
      'isActive': true,
      'responses': {},
    };

    await _firestore.collection(_collection).add(promptData);
  }

  Future<void> submitResponse({
    required String promptId,
    required String userId,
    required String userDisplayName,
    required String response,
  }) async {
    final promptRef = _firestore.collection(_collection).doc(promptId);
    
    await _firestore.runTransaction((transaction) async {
      final promptDoc = await transaction.get(promptRef);
      
      if (!promptDoc.exists || !(promptDoc.data()!['isActive'] as bool)) {
        throw Exception('Prompt is no longer active');
      }

      final responses = Map<String, String>.from(
        promptDoc.data()!['responses'] as Map<String, dynamic>,
      );
      
      responses[userId] = response;

      transaction.update(promptRef, {'responses': responses});
    });
  }

  Future<void> selectResponse({
    required String promptId,
    required String userId,
    required String userDisplayName,
    required String response,
  }) async {
    await _firestore.collection(_collection).doc(promptId).update({
      'selectedResponse': response,
      'selectedUserId': userId,
      'selectedUserDisplayName': userDisplayName,
      'selectedAt': FieldValue.serverTimestamp(),
      'isActive': false,
    });
  }

  Stream<List<LiveStoryPrompt>> getActivePrompts(String streamId) {
    return _firestore
        .collection(_collection)
        .where('streamId', isEqualTo: streamId)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => LiveStoryPrompt.fromFirestore(doc)).toList();
        });
  }

  Stream<List<LiveStoryPrompt>> getCompletedPrompts(String streamId) {
    return _firestore
        .collection(_collection)
        .where('streamId', isEqualTo: streamId)
        .where('isActive', isEqualTo: false)
        .orderBy('selectedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => LiveStoryPrompt.fromFirestore(doc)).toList();
        });
  }

  Future<void> deletePrompt(String promptId) async {
    await _firestore.collection(_collection).doc(promptId).delete();
  }

  Future<void> closePrompt(String promptId) async {
    await _firestore.collection(_collection).doc(promptId).update({
      'isActive': false,
    });
  }

  Stream<LiveStoryPrompt> getPrompt(String promptId) {
    return _firestore
        .collection(_collection)
        .doc(promptId)
        .snapshots()
        .map((doc) => LiveStoryPrompt.fromFirestore(doc));
  }
} 