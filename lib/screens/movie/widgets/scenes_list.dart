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
    final sceneIndex = scenes.indexWhere((s) => s['id'] == editedScene['id']);
    if (sceneIndex != -1) {
      final updatedScenes = List<Map<String, dynamic>>.from(scenes);
      updatedScenes[sceneIndex] = editedScene;
      onScenesUpdated(updatedScenes);
    }
  }

  void _handleSceneDelete(Map<String, dynamic> scene) {
    final updatedScenes = scenes.where((s) => s['id'] != scene['id']).toList();
    onScenesUpdated(updatedScenes);
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: scenes.length,
      itemBuilder: (context, index) {
        final scene = scenes[index];
        return SceneCard(
          scene: scene,
          isReadOnly: isReadOnly,
          onEdit: (updatedScene) {
            final updatedScenes = List<Map<String, dynamic>>.from(scenes);
            updatedScenes[index] = updatedScene;
            onScenesUpdated(updatedScenes);
          },
          onDelete: (scene) {
            final updatedScenes = scenes.where((s) => s['id'] != scene['id']).toList();
            onScenesUpdated(updatedScenes);
          },
          onVideoSelected: onVideoSelected,
          movieTitle: movieTitle,
          movieId: movieId,
          isNewScene: false,
        );
      },
    );
  }
}
