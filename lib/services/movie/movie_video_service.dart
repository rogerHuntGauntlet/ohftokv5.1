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

class MovieVideoService {
  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Uploads a video for a scene, either from camera or gallery
  Future<Map<String, String>?> uploadVideoForScene({
    required String movieId,
    required String sceneId,
    required BuildContext context,
    required bool fromCamera,
    void Function(double progress)? onProgress,
  }) async {
    try {
      print('Starting video upload process');

      // Check authentication
      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        print('User not authenticated');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please sign in to upload videos'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return null;
      }

      print('User authenticated: ${currentUser.uid}');

      // Pick video from camera or gallery
      final XFile? videoFile = await _picker.pickVideo(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );

      if (videoFile == null) {
        print('No video file selected or permission denied');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No video selected or permission denied'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return null;
      }

      print('Video file selected: ${videoFile.path}');

      // Verify file exists and is readable
      final file = File(videoFile.path);
      if (!await file.exists()) {
        print('Video file does not exist at path: ${videoFile.path}');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Selected video file not found'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return null;
      }

      // Get file size for progress calculation
      final fileSize = await videoFile.length();
      if (fileSize == 0) {
        print('Video file is empty');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Selected video file is empty'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return null;
      }
      
      // Create the storage reference with a unique timestamp
      final storageRef = _storage.ref();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final videoRef = storageRef.child('${timestamp}.mp4');

      print('Created storage reference: ${videoRef.fullPath}');

      // Show upload progress
      final progressDialog = _showUploadProgress(context);

      // Start upload with progress tracking
      final uploadTask = videoRef.putFile(
        File(videoFile.path),
        SettableMetadata(
          contentType: 'video/mp4',
          customMetadata: {
            'videoId': videoRef.name,
            'movieId': movieId,
            'sceneId': sceneId,
            'userId': currentUser.uid,
            'uploadedAt': DateTime.now().toIso8601String(),
            'sourceType': 'user',
          },
        ),
      );

      print('Upload task started');

      // Track upload progress
      uploadTask.snapshotEvents.listen(
        (TaskSnapshot snapshot) {
          if (onProgress != null) {
            final progress = snapshot.bytesTransferred / fileSize;
            onProgress(progress);
          }
          final progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
          print('Upload progress: ${progress.toStringAsFixed(1)}%');
          progressDialog.update(progress);
        },
        onError: (error) {
          print('Upload error: $error');
          progressDialog.close();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Upload error: $error'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      );

      // Wait for upload to complete
      print('Waiting for upload to complete...');
      final snapshot = await uploadTask;
      print('Upload completed. Total bytes: ${snapshot.totalBytes}');

      // Get download URL
      final videoUrl = await videoRef.getDownloadURL();
      final videoId = videoRef.name;
      print('Download URL obtained: $videoUrl');

      // Close progress dialog
      progressDialog.close();

      return {
        'videoUrl': videoUrl,
        'videoId': videoId,
      };
    } catch (e, stackTrace) {
      print('Error in uploadVideoForScene: $e');
      print('Stack trace: $stackTrace');
      
      // Close progress dialog if it's open
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading video: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  _ProgressDialog _showUploadProgress(BuildContext context) {
    final dialog = _ProgressDialog(context: context);
    dialog.show();
    return dialog;
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