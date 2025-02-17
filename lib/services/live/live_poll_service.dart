import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/live/live_poll.dart';

class LivePollService {
  final FirebaseFirestore _firestore;
  final String _collection = 'live_polls';

  LivePollService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> createPoll({
    required String streamId,
    required String question,
    required List<String> options,
  }) async {
    final poll = {
      'streamId': streamId,
      'question': question,
      'options': options,
      'votes': <String, int>{},
      'createdAt': FieldValue.serverTimestamp(),
      'isActive': true,
    };

    await _firestore.collection(_collection).add(poll);
  }

  Future<void> vote({
    required String pollId,
    required String userId,
    required int optionIndex,
  }) async {
    final userVoteDoc = await _firestore
        .collection('${_collection}_votes')
        .where('pollId', isEqualTo: pollId)
        .where('userId', isEqualTo: userId)
        .get();

    if (userVoteDoc.docs.isNotEmpty) {
      // User has already voted, update their vote
      final oldVote = userVoteDoc.docs.first;
      final oldOptionIndex = oldVote.data()['optionIndex'] as int;

      await _firestore.runTransaction((transaction) async {
        final pollRef = _firestore.collection(_collection).doc(pollId);
        final pollDoc = await transaction.get(pollRef);

        if (!pollDoc.exists) return;

        final votes = Map<String, int>.from(pollDoc.data()!['votes'] as Map<String, dynamic>);
        
        // Remove old vote
        votes[oldOptionIndex.toString()] = (votes[oldOptionIndex.toString()] ?? 1) - 1;
        
        // Add new vote
        votes[optionIndex.toString()] = (votes[optionIndex.toString()] ?? 0) + 1;

        transaction.update(pollRef, {'votes': votes});
        transaction.update(oldVote.reference, {'optionIndex': optionIndex});
      });
    } else {
      // First time voting
      await _firestore.runTransaction((transaction) async {
        final pollRef = _firestore.collection(_collection).doc(pollId);
        final pollDoc = await transaction.get(pollRef);

        if (!pollDoc.exists) return;

        final votes = Map<String, int>.from(pollDoc.data()!['votes'] as Map<String, dynamic>);
        votes[optionIndex.toString()] = (votes[optionIndex.toString()] ?? 0) + 1;

        transaction.update(pollRef, {'votes': votes});
        transaction.set(
          _firestore.collection('${_collection}_votes').doc(),
          {
            'pollId': pollId,
            'userId': userId,
            'optionIndex': optionIndex,
            'timestamp': FieldValue.serverTimestamp(),
          },
        );
      });
    }
  }

  Stream<List<LivePoll>> getActivePolls(String streamId) {
    return _firestore
        .collection(_collection)
        .where('streamId', isEqualTo: streamId)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => LivePoll.fromFirestore(doc)).toList();
        });
  }

  Future<void> closePoll(String pollId) async {
    await _firestore
        .collection(_collection)
        .doc(pollId)
        .update({'isActive': false});
  }

  Future<void> deletePoll(String pollId) async {
    final batch = _firestore.batch();

    // Delete the poll
    batch.delete(_firestore.collection(_collection).doc(pollId));

    // Delete associated votes
    final votes = await _firestore
        .collection('${_collection}_votes')
        .where('pollId', isEqualTo: pollId)
        .get();

    for (var vote in votes.docs) {
      batch.delete(vote.reference);
    }

    await batch.commit();
  }
} 