import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../openai/openai_service.dart';
import 'movie_firestore_service.dart';
import 'package:flutter/material.dart';
import '../../screens/movie/video_generation_modal.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MovieService {
  final FirebaseFunctions _functions;
  final MovieFirestoreService _firestoreService = MovieFirestoreService();
  final OpenAIService _openAIService = OpenAIService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  MovieService() : _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  /// Gets the current user's ID
  String getCurrentUserId() {
    final user = _auth.currentUser;
    if (user == null) throw 'User not authenticated';
    return user.uid;
  }

  /// Gets a stream of scenes for a specific movie
  Stream<List<Map<String, dynamic>>> getMovieScenes(String movieId) {
    return FirebaseFirestore.instance
        .collection('movies')
        .doc(movieId)
        .collection('scenes')
        .orderBy('id')
        .snapshots()
        .map((snapshot) {
          final scenes = snapshot.docs.map((doc) {
            final data = doc.data();
            // Ensure video fields are properly included
            return {
              ...data,
              'documentId': doc.id,
              'videoUrl': data['videoUrl'],
              'videoId': data['videoId'],
              'videoType': data['videoType'],
              'status': data['status'] ?? 'pending',
            };
          }).toList();
          
          print('Loaded ${scenes.length} scenes with video data: ${scenes.map((s) => '${s['id']}: ${s['videoUrl'] != null}')}');
          return scenes;
        });
  }

  /// Generates movie scenes using AI
  Future<List<Map<String, dynamic>>> generateMovieScenes(String movieIdea) async {
    try {
      print('Starting generateMovieScenes with idea: $movieIdea');
      
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw 'User not authenticated';
      
      print('User authenticated: ${user.uid}');
      print('Initializing scene generation process...');

      // First save the movie to get a movieId
      final movieId = await _firestoreService.saveMovie(
        movieIdea: movieIdea,
        scenes: [], // We'll add scenes after processing them
      );

      print('Movie created with ID: $movieId');
      print('Making HTTP POST request to generateMovieScenes...');
      final response = await http.post(
        Uri.parse('https://us-central1-${dotenv.env['FIREBASE_PROJECT_ID']}.cloudfunctions.net/generateMovieScenes'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'movieIdea': movieIdea,
          'userId': user.uid,
          'movieId': movieId, // Pass the movieId to the cloud function
        }),
      );

      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode != 200) {
        print('Error from cloud function: ${response.body}');
        // Delete the movie if scene generation failed
        await _firestoreService.deleteMovie(movieId);
        throw 'Failed to generate scenes. Server returned ${response.statusCode}';
      }

      final data = json.decode(response.body);
      print('Decoded response data: $data');
      
      if (data == null || !data.containsKey('scenes')) {
        print('No data received from function or missing scenes key');
        print('Received data structure: $data');
        // Delete the movie if no scenes were generated
        await _firestoreService.deleteMovie(movieId);
        throw 'No scenes generated';
      }

      print('Processing scenes from result...');
      final rawScenes = List<dynamic>.from(data['scenes']);
      print('Raw scenes data: $rawScenes');
      
      final scenes = rawScenes.map((scene) {
        print('Processing scene: $scene');
        // Ensure all required fields have non-null values and include movieId
        final processedScene = {
          'id': scene['id'] ?? 0,
          'title': scene['title']?.toString() ?? 'Scene ${scene['id'] ?? 0}',
          'text': scene['text']?.toString() ?? '',
          'duration': scene['duration'] ?? 15,
          'type': scene['type']?.toString() ?? 'scene',
          'status': scene['status']?.toString() ?? 'pending',
          'movieId': movieId, // Add movieId to each scene
        };
        print('Processed scene: $processedScene');
        return processedScene;
      }).toList();
      
      // Now update the movie with the processed scenes
      final batch = FirebaseFirestore.instance.batch();
      final movieRef = FirebaseFirestore.instance.collection('movies').doc(movieId);
      
      // Create a list to store scenes with their document IDs
      final scenesWithIds = <Map<String, dynamic>>[];
      
      for (final scene in scenes) {
        final sceneRef = movieRef.collection('scenes').doc();
        batch.set(sceneRef, {
          ...scene,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        // Add the scene with its document ID to our list
        scenesWithIds.add({
          ...scene,
          'documentId': sceneRef.id,
        });
      }
      
      await batch.commit();
      
      print('Successfully processed ${scenes.length} scenes');
      print('Final scenes data: $scenesWithIds');
      
      return scenesWithIds;
    } catch (e, stackTrace) {
      print('Error generating movie scenes: $e');
      print('Stack trace: $stackTrace');
      throw 'Failed to generate movie scenes. Please try again.';
    }
  }

  /// Generates additional scenes for an existing movie
  Future<List<Map<String, dynamic>>> generateAdditionalScenes({
    required String movieId,
    required List<Map<String, dynamic>> existingScenes,
    required String continuationIdea,
    required int numNewScenes,
    void Function(String)? onProgress,
  }) async {
    try {
      print('Starting generateAdditionalScenes');
      onProgress?.call('Initializing scene generation...');
      await Future.delayed(const Duration(milliseconds: 500));
      
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw 'User not authenticated';
      
      print('User authenticated: ${user.uid}');
      onProgress?.call('Preparing scene analysis...');
      await Future.delayed(const Duration(milliseconds: 500));

      // Convert Timestamp objects to ISO strings in existingScenes
      onProgress?.call('Processing existing scenes...');
      final processedScenes = existingScenes.map((scene) {
        final processed = Map<String, dynamic>.from(scene);
        if (processed['createdAt'] is Timestamp) {
          processed['createdAt'] = (processed['createdAt'] as Timestamp).toDate().toIso8601String();
        }
        if (processed['updatedAt'] is Timestamp) {
          processed['updatedAt'] = (processed['updatedAt'] as Timestamp).toDate().toIso8601String();
        }
        return processed;
      }).toList();
      await Future.delayed(const Duration(milliseconds: 500));

      final payload = {
        'movieId': movieId,
        'existingScenes': processedScenes,
        'continuationIdea': continuationIdea,
        'numNewScenes': numNewScenes,
        'userId': user.uid,
      };
      print('Payload prepared: ${json.encode(payload)}');

      onProgress?.call('Analyzing existing scenes and style...');
      await Future.delayed(const Duration(milliseconds: 800));
      
      onProgress?.call('Generating creative continuation...');
      print('Making HTTP POST request...');
      final response = await http.post(
        Uri.parse('https://us-central1-${dotenv.env['FIREBASE_PROJECT_ID']}.cloudfunctions.net/generateAdditionalScenes'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      if (response.statusCode != 200) {
        print('Error from cloud function: ${response.body}');
        try {
          final errorData = json.decode(response.body);
          if (errorData is Map<String, dynamic>) {
            // Try to extract the most specific error message
            final errorMessage = errorData['details'] ?? 
                               errorData['message'] ?? 
                               errorData['error'] ??
                               'Failed to generate scenes';
            throw errorMessage;
          }
        } catch (parseError) {
          print('Error parsing error response: $parseError');
        }
        throw 'Failed to generate scenes. Server returned ${response.statusCode}';
      }

      final data = json.decode(response.body);
      if (data == null || !data.containsKey('scenes')) {
        print('No data received from function');
        throw 'No scenes were generated. Please try again.';
      }

      onProgress?.call('Processing new scenes...');
      print('Processing scenes from result...');
      await Future.delayed(const Duration(milliseconds: 500));
      
      final rawScenes = List<dynamic>.from(data['scenes']);
      print('Raw scenes data: $rawScenes');
      
      final newScenes = rawScenes.map((scene) {
        // Ensure all required fields have non-null values
        final processedScene = {
          'id': scene['id'] ?? 0,
          'title': scene['title']?.toString() ?? 'Scene ${scene['id'] ?? 0}',
          'text': scene['text']?.toString().trim() ?? '',
          'duration': scene['duration'] ?? 15,
          'type': scene['type']?.toString() ?? 'scene',
          'status': scene['status']?.toString() ?? 'pending',
          'movieId': movieId,
        };
        print('Processed scene: $processedScene');
        return processedScene;
      }).toList();

      // Validate the number of scenes
      if (newScenes.length != numNewScenes) {
        throw 'Expected $numNewScenes new scenes but got ${newScenes.length} scenes. Please try again.';
      }
      
      print('Successfully processed ${newScenes.length} scenes');
      onProgress?.call('Finalizing new scenes...');
      await Future.delayed(const Duration(milliseconds: 500));
      
      onProgress?.call('Adding scenes to your movie...');
      
      // Add new scenes to the movie in Firestore
      final batch = FirebaseFirestore.instance.batch();
      final movieRef = FirebaseFirestore.instance.collection('movies').doc(movieId);
      final newScenesWithIds = <Map<String, dynamic>>[];
      
      for (final scene in newScenes) {
        final sceneRef = movieRef.collection('scenes').doc();
        batch.set(sceneRef, {
          ...scene,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        // Add the scene with its document ID to our list
        newScenesWithIds.add({
          ...scene,
          'documentId': sceneRef.id,
        });
      }
      
      await batch.commit();
      
      // Return the new scenes with their document IDs
      print('Final new scenes count: ${newScenesWithIds.length}');
      return newScenesWithIds;
      
    } catch (e, stackTrace) {
      print('Error generating additional scenes: $e');
      print('Stack trace: $stackTrace');
      
      // If this is already a string error message, throw it directly
      if (e is String) {
        throw e;
      }
      
      // Otherwise, provide a more user-friendly error message
      throw 'Failed to generate additional scenes: ${e.toString()}';
    }
  }

  /// Generates a single additional scene for an existing movie
  Future<List<Map<String, dynamic>>> generateAdditionalScene({
    required String movieId,
    required List<Map<String, dynamic>> existingScenes,
    required String continuationIdea,
    void Function(String)? onProgress,
  }) async {
    try {
      print('Starting generateAdditionalScene');
      onProgress?.call('Initializing scene generation...');
      await Future.delayed(const Duration(milliseconds: 500));
      
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw 'User not authenticated';
      
      print('User authenticated: ${user.uid}');
      onProgress?.call('Preparing scene analysis...');
      await Future.delayed(const Duration(milliseconds: 500));

      // Convert Timestamp objects to ISO strings in existingScenes
      onProgress?.call('Processing existing scenes...');
      final processedScenes = existingScenes.map((scene) {
        final processed = Map<String, dynamic>.from(scene);
        if (processed['createdAt'] is Timestamp) {
          processed['createdAt'] = (processed['createdAt'] as Timestamp).toDate().toIso8601String();
        }
        if (processed['updatedAt'] is Timestamp) {
          processed['updatedAt'] = (processed['updatedAt'] as Timestamp).toDate().toIso8601String();
        }
        return processed;
      }).toList();

      // Create a progress stream controller for the OpenAI service
      final progressController = StreamController<String>();
      progressController.stream.listen((message) {
        onProgress?.call(message);
      });

      // Generate the scene text using OpenAI
      final sceneTexts = await _openAIService.generateSingleScene(
        movieIdea: movieId,
        existingScenes: processedScenes,
        continuationIdea: continuationIdea,
        progressController: progressController,
      );

      // Process each scene
      final newScenes = <Map<String, dynamic>>[];
      final batch = FirebaseFirestore.instance.batch();
      final movieRef = FirebaseFirestore.instance.collection('movies').doc(movieId);

      for (var i = 0; i < sceneTexts.length; i++) {
        final sceneText = sceneTexts[i];
        final sceneNumber = existingScenes.length + i + 1;

        // Process the scene data
        final processedScene = {
          'id': sceneNumber,
          'title': 'Scene $sceneNumber',
          'text': sceneText.trim(),
          'duration': 15,
          'type': 'scene',
          'status': 'pending',
          'movieId': movieId,
        };

        // Create a new document reference for the scene
        final sceneRef = movieRef.collection('scenes').doc();
        
        // Add the scene to the batch
        batch.set(sceneRef, {
          ...processedScene,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Add the scene with its document ID to our list
        newScenes.add({
          ...processedScene,
          'documentId': sceneRef.id,
        });
      }
      
      print('Successfully processed ${newScenes.length} new scenes');
      onProgress?.call('Finalizing new scenes...');
      await Future.delayed(const Duration(milliseconds: 500));
      
      onProgress?.call('Adding scenes to your movie...');
      
      // Commit all the new scenes in one batch
      await batch.commit();
      
      print('Scenes added successfully');
      onProgress?.call('Scenes generated successfully!');
      await Future.delayed(const Duration(seconds: 1));

      // Close the progress controller
      await progressController.close();
      
      // Return all the new scenes
      return newScenes;
      
    } catch (e, stackTrace) {
      print('Error generating additional scene: $e');
      print('Stack trace: $stackTrace');
      
      // If this is already a string error message, throw it directly
      if (e is String) {
        throw e;
      }
      
      // Otherwise, provide a more user-friendly error message
      throw 'Failed to generate additional scene: ${e.toString()}';
    }
  }

  /// Gets all movies (admin function)
  Future<List<Map<String, dynamic>>> getAllMovies() async {
    return _firestoreService.getAllMovies();
  }

  /// Gets movies for the current user (excluding forks)
  Stream<List<Map<String, dynamic>>> getUserMovies() {
    return _firestoreService.getUserMovies();
  }

  /// Gets forked movies for the current user
  Stream<List<Map<String, dynamic>>> getUserForkedMovies() {
    return _firestoreService.getUserForkedMovies();
  }

  /// Gets all public movies
  Stream<List<Map<String, dynamic>>> getPublicMovies() {
    return _firestoreService.getPublicMovies();
  }

  /// Gets a single movie by ID
  Future<Map<String, dynamic>> getMovie(String documentId) async {
    return _firestoreService.getMovie(documentId);
  }

  /// Updates a movie's title
  Future<void> updateMovieTitle(String movieId, String title) async {
    return _firestoreService.updateMovieTitle(movieId, title);
  }

  /// Updates a movie's public status
  Future<void> updateMoviePublicStatus(String movieId, bool isPublic) async {
    return _firestoreService.updateMoviePublicStatus(movieId, isPublic);
  }

  /// Deletes a movie and all its associated data
  Future<void> deleteMovie(String movieId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw 'User not authenticated';

      // Get the movie to verify ownership
      final movie = await _firestoreService.getMovie(movieId);
      if (movie['userId'] != user.uid) {
        throw 'You do not have permission to delete this movie';
      }

      // Delete from Firestore
      await _firestoreService.deleteMovie(movieId);
    } catch (e) {
      print('Error deleting movie: $e');
      throw 'Failed to delete movie. Please try again.';
    }
  }

  /// Updates a scene with a video URL and metadata
  Future<void> updateSceneVideo(
    String movieId,
    String sceneId,
    String videoUrl,
    String videoId,
    {bool isUserVideo = false}
  ) async {
    try {
      await _firestoreService.updateScene(
        movieId: movieId,
        sceneId: sceneId,
        sceneData: {
          'videoUrl': videoUrl,
          'videoId': videoId,
          'videoType': isUserVideo ? 'user' : 'ai',
          'status': 'completed',
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    } catch (e) {
      print('Error updating scene video: $e');
      throw 'Failed to update scene with video URL. Please try again.';
    }
  }

  /// Updates a scene with user notes and regenerates the scene text
  Future<Map<String, dynamic>?> updateSceneWithNote(
    Map<String, dynamic> scene,
    String note,
    String movieIdea,
    StreamController<String> progressController,
  ) async {
    try {
      // Get updated scene text from OpenAI
      final updatedText = await _openAIService.updateSceneText(
        originalScene: scene['text'],
        notes: note,
        movieIdea: movieIdea,
        progressController: progressController,
      );

      // Create updated scene data
      final updatedScene = {
        ...scene,
        'text': updatedText,
        'notes': [
          ...(scene['notes'] ?? []),
          {
            'text': note,
            'timestamp': DateTime.now().toIso8601String(),
          }
        ],
      };

      // Update in Firestore if scene has a documentId
      if (scene['documentId'] != null) {
        await _firestoreService.updateScene(
          movieId: scene['movieId'],
          sceneId: scene['documentId'],
          sceneData: updatedScene,
        );
      }

      return updatedScene;
    } catch (e) {
      print('Error updating scene: $e');
      throw 'Failed to update scene. Please try again.';
    }
  }

  /// Deletes a scene from a movie
  Future<void> deleteScene(String movieId, String sceneId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw 'User not authenticated';

      // Get the movie to verify ownership
      final movie = await _firestoreService.getMovie(movieId);
      if (movie['userId'] != user.uid) {
        throw 'You do not have permission to delete this scene';
      }

      // Delete the scene document
      await FirebaseFirestore.instance
        .collection('movies')
        .doc(movieId)
        .collection('scenes')
        .doc(sceneId)
        .delete();

    } catch (e) {
      print('Error deleting scene: $e');
      throw 'Failed to delete scene. Please try again.';
    }
  }

  Future<void> updateScene({
    required String movieId,
    required String sceneId,
    required Map<String, dynamic> sceneData,
  }) async {
    try {
      await FirebaseFirestore.instance
        .collection('movies')
        .doc(movieId)
        .collection('scenes')
        .doc(sceneId)
        .update(sceneData);
    } catch (e) {
      throw Exception('Failed to update scene: $e');
    }
  }

  // Helper method to get stage index for progress tracking
  int _getStageIndex(String status) {
    switch (status) {
      case 'analyzing':
        return 0;
      case 'generating':
        return 1;
      case 'processing':
        return 2;
      case 'downloading':
        return 3;
      case 'uploading':
        return 4;
      case 'completed':
        return 5;
      default:
        return 0;
    }
  }
}