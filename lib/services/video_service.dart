import 'package:flutter/material.dart';
import 'dart:async';
import '../models/video_generation_progress.dart';
import '../models/video_operation_exception.dart';
import '../services/movie/movie_video_service.dart';
import '../services/movie/movie_service.dart';

class VideoService {
  final MovieVideoService _videoService = MovieVideoService();

  Future<void> generateVideo({
    required BuildContext context,
    required Map<String, dynamic> scene,
    required Function(VideoGenerationProgress) onProgress,
    required Function(String videoUrl, String videoId) onComplete,
    required Function(String error) onError,
  }) async {
    try {
      final movieService = MovieService();
      final result = await _videoService.generateVideo(
        sceneText: scene['text'],
        movieId: scene['movieId'],
        sceneId: scene['documentId'],
        onProgress: onProgress,
      );

      if (result != null) {
        await movieService.updateSceneVideo(
          scene['movieId'],
          scene['documentId'],
          result['videoUrl']!,
          result['videoId']!,
        );

        onComplete(result['videoUrl']!, result['videoId']!);
      }
    } catch (e) {
      onError(e.toString());
    }
  }

  Future<void> uploadVideo({
    required BuildContext context,
    required Map<String, dynamic> scene,
    required bool fromCamera,
    required Function(double progress) onProgress,
    required Function(Map<String, String> result) onComplete,
    required Function(String error) onError,
  }) async {
    try {
      final result = await _videoService.uploadVideoForScene(
        movieId: scene['movieId'],
        sceneId: scene['documentId'],
        context: context,
        fromCamera: fromCamera,
        onProgress: onProgress,
      );

      if (result != null) {
        final movieService = MovieService();
        await movieService.updateSceneVideo(
          scene['movieId'],
          scene['documentId'],
          result['videoUrl']!,
          result['videoId']!,
          isUserVideo: true,
        );

        onComplete(result);
      }
    } catch (e) {
      onError(e.toString());
    }
  }

  Future<void> deleteVideo({
    required String movieId,
    required String sceneId,
    required String videoId,
  }) async {
    try {
      await _videoService.deleteVideo(movieId, sceneId, videoId);
    } catch (e) {
      throw VideoOperationException('Failed to delete video: $e');
    }
  }
} 