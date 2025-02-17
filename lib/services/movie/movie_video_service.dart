import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../video/video_creation_service.dart';
import '../../models/video_generation_progress.dart';

class MovieVideoService {
  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final VideoCreationService _videoService = VideoCreationService();

  /// Uploads a video for a scene, either from camera or gallery
  Future<Map<String, String>?> uploadVideoForScene({
    required String movieId,
    required String sceneId,
    required BuildContext context,
    required bool fromCamera,
    required Function(double) onProgress,
  }) async {
    return await _videoService.uploadVideo(
      context: context,
      movieId: movieId,
      sceneId: sceneId,
      fromCamera: fromCamera,
      onProgress: onProgress,
    );
  }

  /// Starts a video generation with Replicate
  Future<String> startReplicateGeneration(String sceneText) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw 'User not authenticated';

      final response = await http.post(
        Uri.parse('https://api.replicate.com/v1/predictions'),
        headers: {
          'Authorization': 'Bearer ${dotenv.env['REPLICATE_API_KEY']}',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'version': 'luma/ray',  // Hardcode the model version to match cloud functions
          'input': {
            'prompt': sceneText,
          },
        }),
      );

      if (response.statusCode != 201) {
        throw 'Failed to start video generation: ${response.body}';
      }

      final data = json.decode(response.body);
      return data['id']; // Return the prediction ID
    } catch (e) {
      print('Error starting Replicate generation: $e');
      throw 'Failed to start video generation';
    }
  }

  /// Checks the status of a Replicate prediction
  Future<Map<String, dynamic>> checkReplicateStatus(String predictionId) async {
    try {
      final response = await http.get(
        Uri.parse('https://api.replicate.com/v1/predictions/$predictionId'),
        headers: {
          'Authorization': 'Bearer ${dotenv.env['REPLICATE_API_KEY']}',
        },
      );

      if (response.statusCode != 200) {
        throw 'Failed to check prediction status: ${response.body}';
      }

      final data = json.decode(response.body);
      return {
        'status': data['status'],
        'output': data['output'],
        'error': data['error'],
      };
    } catch (e) {
      print('Error checking Replicate status: $e');
      throw 'Failed to check video generation status';
    }
  }

  /// Downloads a video from a URL and uploads it to Firebase Storage
  Future<Map<String, String>> processAndUploadVideo(
    String videoUrl,
    String movieId,
    String sceneId,
    String predictionId,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw 'User not authenticated';

      // Download video from URL
      final videoResponse = await http.get(Uri.parse(videoUrl));
      if (videoResponse.statusCode != 200) {
        throw 'Failed to download video';
      }

      // Generate a unique video ID
      final videoId = _firestore.collection('videos').doc().id;
      final storageRef = _storage.ref().child('$videoId.mp4');

      // Upload to Firebase Storage
      final uploadTask = storageRef.putData(
        videoResponse.bodyBytes,
        SettableMetadata(
          contentType: 'video/mp4',
          customMetadata: {
            'videoId': videoId,
            'movieId': movieId,
            'sceneId': sceneId,
            'userId': user.uid,
            'uploadedAt': DateTime.now().toIso8601String(),
            'sourceType': 'ai',
            'predictionId': predictionId,
          },
        ),
      );

      // Wait for upload to complete
      await uploadTask;
      final downloadUrl = await storageRef.getDownloadURL();

      return {
        'videoUrl': downloadUrl,
        'videoId': videoId,
      };
    } catch (e) {
      print('Error processing and uploading video: $e');
      throw 'Failed to process and upload video';
    }
  }

  Future<void> deleteVideo(String movieId, String sceneId, String videoId) async {
    await _videoService.deleteVideo(movieId, sceneId, videoId);
  }

  Future<Map<String, String>> generateVideo({
    required String sceneText,
    required String movieId,
    required String sceneId,
    required Function(VideoGenerationProgress) onProgress,
  }) async {
    return await _videoService.generateVideo(
      sceneText: sceneText,
      movieId: movieId,
      sceneId: sceneId,
      onProgress: onProgress,
    );
  }
}

class _ProgressDialog {
  final BuildContext context;
  bool _isShowing = false;
  double _progress = 0;

  _ProgressDialog({required this.context});

  void show() {
    if (!_isShowing) {
      _isShowing = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text('Uploading video... ${_progress.toStringAsFixed(1)}%'),
                  ],
                ),
              );
            },
          );
        },
      );
    }
  }

  void update(double progress) {
    _progress = progress;
    if (_isShowing && context.mounted) {
      Navigator.of(context).pop();
      show();
    }
  }

  void close() {
    if (_isShowing && context.mounted) {
      Navigator.of(context).pop();
      _isShowing = false;
    }
  }
}