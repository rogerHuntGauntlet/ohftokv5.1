import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'scene_card.dart';
import '../../../services/movie/movie_service.dart';

class ScenesList extends StatelessWidget {
  final List<Map<String, dynamic>> scenes;
  final String movieId;
  final String? movieTitle;
  final bool isReadOnly;
  final Function(List<Map<String, dynamic>>) onScenesUpdated;
  final Function(Map<String, dynamic>) onVideoSelected;

  const ScenesList({
    Key? key,
    required this.scenes,
    required this.movieId,
    required this.movieTitle,
    required this.isReadOnly,
    required this.onScenesUpdated,
    required this.onVideoSelected,
  }) : super(key: key);

  void _handleSceneEdit(Map<String, dynamic> editedScene) {
    try {
      // Find the scene by documentId
      final sceneIndex = scenes.indexWhere((s) => s['documentId'] == editedScene['documentId']);
      if (sceneIndex != -1) {
        // Create a new list with the updated scene
        final updatedScenes = List<Map<String, dynamic>>.from(scenes);
        updatedScenes[sceneIndex] = editedScene;
        
        // Update the parent immediately
        onScenesUpdated(updatedScenes);
      }
    } catch (e) {
      print('❌ Error in _handleSceneEdit: $e');
    }
  }

  void _handleSceneDelete(Map<String, dynamic> scene) async {
    try {
      // Remove the scene by documentId
      final updatedScenes = scenes.where((s) => s['documentId'] != scene['documentId']).toList();
      
      // Update the parent immediately
      onScenesUpdated(updatedScenes);
    } catch (e) {
      print('❌ Error in _handleSceneDelete: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: scenes.length,
      itemBuilder: (context, index) {
        final scene = scenes[index];
        // Use a more specific key that includes all relevant update information
        final keyString = '${scene['documentId']}_${scene['updatedAt'] ?? ''}_${scene['hasDirectorCut'] ?? false}_${scene['text'] ?? ''}';
        
        return SceneCard(
          key: ValueKey(keyString),
          scene: scene,
          isReadOnly: isReadOnly,
          onEdit: _handleSceneEdit,
          onDelete: _handleSceneDelete,
          onVideoSelected: onVideoSelected,
          movieTitle: movieTitle,
          movieId: movieId,
          isNewScene: false,
        );
      },
    );
  }
}
