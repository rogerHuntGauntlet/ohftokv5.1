import 'fork_firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ForkService {
  final ForkFirestoreService _firestoreService = ForkFirestoreService();

  /// Forks a single scene from a movie
  Future<String> forkSingleScene({
    required String originalMovieId,
    required Map<String, dynamic> scene,
    required String movieIdea,
    required String originalCreatorId,
  }) async {
    try {
      return _firestoreService.createFork(
        originalMovieId: originalMovieId,
        scenesToFork: [scene],
        movieIdea: movieIdea,
        originalCreatorId: originalCreatorId,
      );
    } catch (e) {
      print('Error forking single scene: $e');
      throw 'Failed to fork scene. Please try again.';
    }
  }

  /// Forks a scene and all scenes before it
  Future<String> forkSceneAndPrevious({
    required String originalMovieId,
    required List<Map<String, dynamic>> allScenes,
    required int currentSceneIndex,
    required String movieIdea,
    required String originalCreatorId,
  }) async {
    try {
      // Get all scenes up to and including the current scene
      final scenesToFork = allScenes.sublist(0, currentSceneIndex + 1);
      
      return _firestoreService.createFork(
        originalMovieId: originalMovieId,
        scenesToFork: scenesToFork,
        movieIdea: movieIdea,
        originalCreatorId: originalCreatorId,
      );
    } catch (e) {
      print('Error forking scenes: $e');
      throw 'Failed to fork scenes. Please try again.';
    }
  }

  /// Gets all forked movies for the current user
  Stream<List<Map<String, dynamic>>> getUserForks() {
    return _firestoreService.getUserForks();
  }

  /// Gets the fork count for a specific movie
  Future<int> getMovieForkCount(String movieId) {
    return _firestoreService.getMovieForkCount(movieId);
  }

  /// Gets a movie by ID
  Future<Map<String, dynamic>> getMovie(String movieId) async {
    try {
      final doc = await _firestoreService.getMovie(movieId);
      return doc;
    } catch (e) {
      print('Error getting movie: $e');
      throw 'Failed to load movie. Please try again.';
    }
  }
} 