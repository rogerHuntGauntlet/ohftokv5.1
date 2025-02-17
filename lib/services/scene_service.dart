import 'package:flutter/material.dart';
import 'dart:async';
import '../services/movie/movie_service.dart';

class SceneService {
  final MovieService _movieService = MovieService();

  Future<List<Map<String, dynamic>>> generateAdditionalScenes({
    required String movieId,
    required List<Map<String, dynamic>> existingScenes,
    required String continuationIdea,
    required Function(String) onProgress,
  }) async {
    try {
      return await _movieService.generateAdditionalScene(
        movieId: movieId,
        existingScenes: existingScenes,
        continuationIdea: continuationIdea,
        onProgress: onProgress,
      );
    } catch (e) {
      throw Exception('Failed to generate additional scenes: $e');
    }
  }

  Future<void> updateScene({
    required String movieId,
    required String sceneId,
    required Map<String, dynamic> sceneData,
  }) async {
    try {
      await _movieService.updateScene(
        movieId: movieId,
        sceneId: sceneId,
        sceneData: sceneData,
      );
    } catch (e) {
      throw Exception('Failed to update scene: $e');
    }
  }

  Future<void> deleteScene({
    required String movieId,
    required String sceneId,
  }) async {
    try {
      await _movieService.deleteScene(movieId, sceneId);
    } catch (e) {
      throw Exception('Failed to delete scene: $e');
    }
  }

  Future<void> reorderScenes({
    required String movieId,
    required List<Map<String, dynamic>> scenes,
  }) async {
    try {
      // Update scene order in Firestore
      for (var i = 0; i < scenes.length; i++) {
        await _movieService.updateScene(
          movieId: movieId,
          sceneId: scenes[i]['documentId'],
          sceneData: {
            'order': i + 1,
          },
        );
      }
    } catch (e) {
      throw Exception('Failed to reorder scenes: $e');
    }
  }
} 