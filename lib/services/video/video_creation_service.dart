import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/video_generation_progress.dart';
import '../../models/video_operation_exception.dart';
import '../../models/video_progress.dart';
import 'dart:io';

class VideoCreationService {
  static const String VIDEO_TYPE_AI = 'ai';
  static const String VIDEO_TYPE_USER = 'user';
  
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _picker = ImagePicker();

  Future<Map<String, String>> generateVideo({
    required String sceneText,
    required String movieId,
    required String sceneId,
    required Function(VideoGenerationProgress) onProgress,
  }) async {
    try {
      // TODO: Implement real AI video generation
      // For now, return a placeholder video
      final videoUrl = 'https://storage.googleapis.com/ohftok-videos/placeholder.mp4';
      final videoId = 'placeholder_${DateTime.now().millisecondsSinceEpoch}';
      
      // Update the scene in Firestore
      await _firestore
          .collection('movies')
          .doc(movieId)
          .collection('scenes')
          .doc(sceneId)
          .update({
        'videoUrl': videoUrl,
        'videoId': videoId,
        'videoType': VIDEO_TYPE_AI,
        'status': 'completed',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return {
        'videoUrl': videoUrl,
        'videoId': videoId,
      };
    } catch (e) {
      throw VideoOperationException('Failed to generate video: $e');
    }
  }

  Future<Map<String, String>> uploadVideo({
    required BuildContext context,
    required String movieId,
    required String sceneId,
    required bool fromCamera,
    required Function(double) onProgress,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw VideoOperationException('User not authenticated');

      // Pick video file
      final XFile? videoFile = await _picker.pickVideo(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );

      if (videoFile == null) {
        throw VideoOperationException('No video selected');
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
            SettableMetadata(contentType: 'video/mp4'),
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
            throw VideoOperationException('Failed to upload after $maxRetries attempts');
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
        'videoType': VIDEO_TYPE_USER,
        'status': 'completed',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return {
        'videoUrl': videoUrl,
        'videoId': videoId,
      };
    } catch (e) {
      print('Upload error: $e');
      throw VideoOperationException('Failed to upload video: $e');
    }
  }

  Future<void> deleteVideo(String movieId, String sceneId, String videoId) async {
    try {
      // Delete from storage
      final storageRef = _storage
          .ref()
          .child('movies')
          .child(movieId)
          .child('scenes')
          .child('$videoId.mp4');
      
      await storageRef.delete();

      // Update the scene in Firestore
      await _firestore
          .collection('movies')
          .doc(movieId)
          .collection('scenes')
          .doc(sceneId)
          .update({
        'videoUrl': null,
        'videoId': null,
        'videoType': null,
        'status': 'pending',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw VideoOperationException('Failed to delete video: $e');
    }
  }

  Stream<VideoGenerationProgress> generateAIVideo({
    required String sceneText,
    required String movieId,
    required String sceneId,
  }) async* {
    try {
      // TODO: Implement real AI video generation stream
      // For now, return mock progress
      for (var i = 0; i < 5; i++) {
        await Future.delayed(const Duration(seconds: 1));
        yield VideoGenerationProgress(
          percentage: (i + 1) / 5,
          stage: 'Generating video...',
          progress: (i + 1) / 5,
          status: 'Processing frame ${i + 1} of 5',
        );
      }
    } catch (e) {
      throw VideoOperationException('Failed to generate AI video: $e');
    }
  }
} 