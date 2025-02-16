import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ForkFirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Creates a fork of a movie with specified scenes
  Future<String> createFork({
    required String originalMovieId,
    required List<Map<String, dynamic>> scenesToFork,
    required String movieIdea,
    required String originalCreatorId,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw 'User not authenticated';

      // Create the forked movie document
      final movieDoc = await _firestore.collection('movies').add({
        'userId': user.uid,
        'movieIdea': movieIdea,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'status': 'forked',
        'isPublic': false,
        'likes': 0,
        'views': 0,
        'forks': 0,
        'forkedFrom': originalMovieId,
        'originalCreatorId': originalCreatorId,
        'type': 'fork', // This will help distinguish it from regular movies and show in mNp(s) tab
      });

      // Add scenes as a subcollection
      final batch = _firestore.batch();
      for (int i = 0; i < scenesToFork.length; i++) {
        final scene = scenesToFork[i];
        final sceneRef = movieDoc.collection('scenes').doc();
        batch.set(sceneRef, {
          ...scene,
          'id': i + 1, // Renumber starting from 1
          'title': 'Scene ${i + 1}', // Update title to match new number
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'originalSceneId': scene['documentId'], // Keep track of original scene ID
        });
      }
      await batch.commit();

      // Increment the original movie's fork count
      await _firestore.collection('movies').doc(originalMovieId).update({
        'forks': FieldValue.increment(1),
      });

      // Update user's fork count
      await _firestore.collection('users').doc(user.uid).update({
        'forksCount': FieldValue.increment(1),
      });

      return movieDoc.id;
    } catch (e) {
      print('Error creating fork: $e');
      throw 'Failed to create fork. Please try again.';
    }
  }

  /// Gets all forked movies for the current user
  Stream<List<Map<String, dynamic>>> getUserForks() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw 'User not authenticated';

    return _firestore
        .collection('movies')
        .where('userId', isEqualTo: userId)
        .where('type', isEqualTo: 'fork')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          final movies = <Map<String, dynamic>>[];
          
          for (final doc in snapshot.docs) {
            final movieData = doc.data();
            final scenesSnapshot = await doc.reference
                .collection('scenes')
                .orderBy('createdAt')
                .get();
            
            final scenes = scenesSnapshot.docs
                .map((sceneDoc) => {
                      ...sceneDoc.data(),
                      'documentId': sceneDoc.id,
                    })
                .toList();

            movies.add({
              ...movieData,
              'documentId': doc.id,
              'scenes': scenes,
            });
          }
          
          return movies;
        });
  }

  /// Gets the fork count for a specific movie
  Future<int> getMovieForkCount(String movieId) async {
    try {
      final doc = await _firestore.collection('movies').doc(movieId).get();
      return (doc.data()?['forks'] as num?)?.toInt() ?? 0;
    } catch (e) {
      print('Error getting fork count: $e');
      return 0;
    }
  }

  /// Gets a movie by ID with its scenes
  Future<Map<String, dynamic>> getMovie(String movieId) async {
    try {
      final movieDoc = await _firestore.collection('movies').doc(movieId).get();
      if (!movieDoc.exists) throw 'Movie not found';

      final scenesSnapshot = await movieDoc.reference.collection('scenes')
          .orderBy('createdAt')
          .get();
      final scenes = scenesSnapshot.docs.map((doc) => {
        ...doc.data(),
        'documentId': doc.id,
      }).toList();

      return {
        ...movieDoc.data()!,
        'documentId': movieDoc.id,
        'scenes': scenes,
      };
    } catch (e) {
      print('Error getting movie: $e');
      throw 'Failed to load movie. Please try again.';
    }
  }
} 