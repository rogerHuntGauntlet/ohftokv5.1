import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MovieFirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<List<Map<String, dynamic>>> getAllMovies() async {
    try {
      final snapshot = await _firestore.collection('movies').get();
      return snapshot.docs.map((doc) => {
        ...doc.data(),
        'documentId': doc.id,
      }).toList();
    } catch (e) {
      print('Error getting all movies: $e');
      throw 'Failed to get movies';
    }
  }

  Future<String> saveMovie({
    required String movieIdea,
    required List<Map<String, dynamic>> scenes,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw 'User not authenticated';

      final movieDoc = await _firestore.collection('movies').add({
        'userId': user.uid,
        'movieIdea': movieIdea,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'status': 'in_progress',
        'isPublic': false,
        'likes': 0,
        'views': 0,
        'forks': 0,
      });

      // Add scenes as a subcollection
      final batch = _firestore.batch();
      for (final scene in scenes) {
        final sceneRef = movieDoc.collection('scenes').doc();
        batch.set(sceneRef, {
          ...scene,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Update user's movie counts
      final userRef = _firestore.collection('users').doc(user.uid);
      batch.update(userRef, {
        'totalMoviesCreated': FieldValue.increment(1),
        'movieIds': FieldValue.arrayUnion([movieDoc.id]),
      });

      await batch.commit();

      return movieDoc.id;
    } catch (e) {
      print('Error saving movie: $e');
      throw 'Failed to save movie. Please try again.';
    }
  }

  Future<Map<String, dynamic>> getMovie(String movieId) async {
    try {
      final movieDoc = await _firestore.collection('movies').doc(movieId).get();
      if (!movieDoc.exists) throw 'Movie not found';

      final scenesSnapshot = await movieDoc.reference.collection('scenes').orderBy('id').get();
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

  Future<void> updateScene({
    required String movieId,
    required String sceneId,
    required Map<String, dynamic> sceneData,
  }) async {
    try {
      final batch = _firestore.batch();
      
      // Update the scene
      final sceneRef = _firestore
          .collection('movies')
          .doc(movieId)
          .collection('scenes')
          .doc(sceneId);
          
      batch.update(sceneRef, {
        ...sceneData,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // If this scene has a video, update the movie status
      if (sceneData['videoUrl'] != null) {
        final movieRef = _firestore.collection('movies').doc(movieId);
        batch.update(movieRef, {
          'status': 'complete',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      print('Error updating scene: $e');
      throw 'Failed to update scene. Please try again.';
    }
  }

  /// Gets movies for the current user (excluding forks)
  Stream<List<Map<String, dynamic>>> getUserMovies() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw 'User not authenticated';

    return _firestore
        .collection('movies')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          final movies = <Map<String, dynamic>>[];
          
          for (final doc in snapshot.docs) {
            final movieData = doc.data();
            // Client-side filter to ensure we only get non-fork movies
            if (movieData['type'] == 'fork') continue;

            // Create a stream for the scenes collection
            final scenesStream = doc.reference
                .collection('scenes')
                .orderBy('id')
                .snapshots();

            // Wait for the first value from the stream
            final scenesSnapshot = await scenesStream.first;
            
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

  /// Gets only forked movies for the current user
  Stream<List<Map<String, dynamic>>> getUserForkedMovies() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw 'User not authenticated';

    return _firestore
        .collection('movies')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          final movies = <Map<String, dynamic>>[];
          
          for (final doc in snapshot.docs) {
            final movieData = doc.data();
            // Client-side filter to ensure we only get fork movies
            if (movieData['type'] != 'fork') continue;

            // Create a stream for the scenes collection
            final scenesStream = doc.reference
                .collection('scenes')
                .orderBy('id')
                .snapshots();

            // Wait for the first value from the stream
            final scenesSnapshot = await scenesStream.first;
            
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

  /// Gets a stream of a single movie's scenes
  Stream<List<Map<String, dynamic>>> getMovieScenes(String movieId) {
    return _firestore
        .collection('movies')
        .doc(movieId)
        .collection('scenes')
        .orderBy('id')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {
                  ...doc.data(),
                  'documentId': doc.id,
                })
            .toList());
  }

  /// Updates a movie's title
  Future<void> updateMovieTitle(String movieId, String title) async {
    try {
      await _firestore.collection('movies').doc(movieId).update({
        'title': title,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating movie title: $e');
      throw 'Failed to update movie title';
    }
  }

  /// Updates a movie's public status
  Future<void> updateMoviePublicStatus(String movieId, bool isPublic) async {
    try {
      await _firestore.collection('movies').doc(movieId).update({
        'isPublic': isPublic,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating movie public status: $e');
      throw 'Failed to update movie status';
    }
  }

  /// Deletes a movie and all its associated data
  Future<void> deleteMovie(String movieId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw 'User not authenticated';

      // Get movie reference
      final movieRef = _firestore.collection('movies').doc(movieId);
      final userRef = _firestore.collection('users').doc(user.uid);
      
      // Get all scenes to delete their videos later if needed
      final scenesSnapshot = await movieRef.collection('scenes').get();
      
      // Delete all scenes and update counts in a batch
      final batch = _firestore.batch();
      
      // Update user's movie counts
      batch.update(userRef, {
        'totalMoviesCreated': FieldValue.increment(-1),
        'movieIds': FieldValue.arrayRemove([movieId]),
      });
      
      // Delete scenes
      for (final scene in scenesSnapshot.docs) {
        batch.delete(scene.reference);
      }
      
      // Delete the movie document
      batch.delete(movieRef);
      
      // Commit the batch
      await batch.commit();
    } catch (e) {
      print('Error deleting movie: $e');
      throw 'Failed to delete movie';
    }
  }

  /// Gets all public movies with their scenes
  Stream<List<Map<String, dynamic>>> getPublicMovies() {
    return _firestore
        .collection('movies')
        .where('isPublic', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          final movies = <Map<String, dynamic>>[];
          
          for (final doc in snapshot.docs) {
            final movieData = doc.data();
            
            // Create a stream for the scenes collection
            final scenesStream = doc.reference
                .collection('scenes')
                .orderBy('id')
                .snapshots();

            // Wait for the first value from the stream
            final scenesSnapshot = await scenesStream.first;
            
            final scenes = scenesSnapshot.docs
                .map((sceneDoc) => {
                      ...sceneDoc.data(),
                      'documentId': sceneDoc.id,
                    })
                .toList();

            // Only add movies that have at least one scene
            if (scenes.isNotEmpty) {
              movies.add({
                ...movieData,
                'documentId': doc.id,
                'scenes': scenes,
              });
            }
          }
          
          return movies;
        });
  }

  Future<void> updateMovieStatus(String movieId, String status) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw 'User not authenticated';

      final batch = _firestore.batch();
      
      // Update movie status
      final movieRef = _firestore.collection('movies').doc(movieId);
      batch.update(movieRef, {
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } catch (e) {
      print('Error updating movie status: $e');
      throw 'Failed to update movie status';
    }
  }

  Future<Map<String, int>> getUserMovieCounts(String userId) async {
    try {
      final moviesQuery = await _firestore
          .collection('movies')
          .where('userId', isEqualTo: userId)
          .get();

      int total = 0;
      int completed = 0;
      int inProgress = 0;

      for (final doc in moviesQuery.docs) {
        final status = doc.data()['status'] as String?;
        total++;
        
        if (status == 'completed') {
          completed++;
        } else if (status == 'in_progress') {
          inProgress++;
        }
      }

      return {
        'total': total,
        'completed': completed,
        'inProgress': inProgress,
      };
    } catch (e) {
      print('Error getting user movie counts: $e');
      throw 'Failed to get movie counts';
    }
  }
} 