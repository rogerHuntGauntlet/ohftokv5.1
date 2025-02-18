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
    try {
      final user = _auth.currentUser;
      if (user == null) throw 'User not authenticated';

      // Pick video file
      final XFile? videoFile = await _picker.pickVideo(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );

      if (videoFile == null) {
        return null; // User cancelled selection
      }

      // Create storage reference
      final storageRef = _storage
          .ref()
          .child('movies')
          .child(movieId)
          .child('scenes')
          .child('$sceneId.mp4');

      // Upload video file with retry logic
      UploadTask? uploadTask;
      int retryCount = 0;
      const maxRetries = 3;

      while (retryCount < maxRetries) {
        try {
          uploadTask = storageRef.putFile(
            File(videoFile.path),
            SettableMetadata(
              contentType: 'video/mp4',
              customMetadata: {
                'movieId': movieId,
                'sceneId': sceneId,
                'userId': user.uid,
                'uploadedAt': DateTime.now().toIso8601String(),
                'sourceType': 'user',
              },
            ),
          );

          // Monitor upload progress
          uploadTask.snapshotEvents.listen(
            (TaskSnapshot snapshot) {
              final progress = snapshot.bytesTransferred / snapshot.totalBytes;
              onProgress(progress);
            },
            onError: (error) {
              print('Upload error: $error');
              if (retryCount < maxRetries - 1) {
                retryCount++;
              } else {
                throw error;
              }
            },
          );

          // Wait for upload to complete
          await uploadTask.whenComplete(() => null);
          
          // If we get here, upload was successful
          break;
        } catch (e) {
          print('Upload attempt $retryCount failed: $e');
          if (retryCount >= maxRetries - 1) {
            throw 'Failed to upload after $maxRetries attempts';
          }
          retryCount++;
          await Future.delayed(Duration(seconds: retryCount * 2)); // Exponential backoff
        } finally {
          uploadTask = null;
        }
      }

      // Get download URL
      final videoUrl = await storageRef.getDownloadURL();
      final videoId = storageRef.name;

      // Update the scene in Firestore
      await _firestore
          .collection('movies')
          .doc(movieId)
          .collection('scenes')
          .doc(sceneId)
          .update({
        'videoUrl': videoUrl,
        'videoId': videoId,
        'videoType': 'user',
        'status': 'completed',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return {
        'videoUrl': videoUrl,
        'videoId': videoId,
      };
    } catch (e) {
      print('Error in uploadVideoForScene: $e');
      throw 'Failed to upload video: $e';
    }
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
    try {
      final user = _auth.currentUser;
      if (user == null) throw 'User not authenticated';

      // Start generation
      onProgress(VideoGenerationProgress(
        percentage: 0.1,
        stage: 'Starting video generation...',
        progress: 0.1,
        status: 'Initializing',
      ));

      // Start Replicate generation
      final predictionId = await startReplicateGeneration(sceneText);
      
      onProgress(VideoGenerationProgress(
        percentage: 0.2,
        stage: 'Processing your scene...',
        progress: 0.2,
        status: 'Generating frames',
      ));

      // Poll for completion
      bool isComplete = false;
      String? videoUrl;
      String? error;
      int attempts = 0;
      const maxAttempts = 60; // 1 minute with 1-second delays

      while (!isComplete && attempts < maxAttempts) {
        attempts++;
        final status = await checkReplicateStatus(predictionId);
        
        switch (status['status']) {
          case 'succeeded':
            isComplete = true;
            videoUrl = status['output'];
            break;
          case 'failed':
            isComplete = true;
            error = status['error'] ?? 'Generation failed';
            break;
          case 'processing':
            // Update progress based on attempt count
            final progress = 0.2 + (attempts / maxAttempts * 0.6); // 20% to 80%
            onProgress(VideoGenerationProgress(
              percentage: progress,
              stage: 'Generating your video...',
              progress: progress,
              status: 'Frame ${attempts} of $maxAttempts',
            ));
            await Future.delayed(const Duration(seconds: 1));
            break;
          default:
            await Future.delayed(const Duration(seconds: 1));
        }
      }

      if (error != null) {
        throw error;
      }

      if (videoUrl == null) {
        throw 'Video generation timed out';
      }

      onProgress(VideoGenerationProgress(
        percentage: 0.8,
        stage: 'Processing generated video...',
        progress: 0.8,
        status: 'Downloading and uploading',
      ));

      // Process and upload the video
      final result = await processAndUploadVideo(
        videoUrl,
        movieId,
        sceneId,
        predictionId,
      );

      onProgress(VideoGenerationProgress(
        percentage: 0.9,
        stage: 'Finalizing...',
        progress: 0.9,
        status: 'Updating scene',
      ));

      // Update the scene in Firestore
      await _firestore
          .collection('movies')
          .doc(movieId)
          .collection('scenes')
          .doc(sceneId)
          .update({
        'videoUrl': result['videoUrl'],
        'videoId': result['videoId'],
        'videoType': 'ai',
        'status': 'completed',
        'updatedAt': FieldValue.serverTimestamp(),
        'generationId': predictionId,
      });

      onProgress(VideoGenerationProgress(
        percentage: 1.0,
        stage: 'Complete!',
        progress: 1.0,
        status: 'Video ready',
      ));

      return result;
    } catch (e) {
      print('Error generating video: $e');
      throw 'Failed to generate video: $e';
    }
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