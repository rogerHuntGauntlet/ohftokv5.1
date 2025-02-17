import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:developer' as developer;
import '../../../services/movie/movie_service.dart';
import '../utils/date_formatter.dart';
import '../../movie/movie_scenes_screen.dart';
import '../../movie/movie_video_player_screen.dart';

/// Tab view that displays the mNp(s) movies.
/// This includes all forked movies and related content.
class ForksTab extends StatelessWidget {
  const ForksTab({Key? key}) : super(key: key);

  void _navigateToMovie(BuildContext context, Map<String, dynamic> movie) {
    try {
      developer.log('Navigating to forked movie:', error: {
        'movieId': movie['id'],
        'title': movie['title'],
        'status': movie['status'],
        'hasScenes': movie['scenes'] != null,
        'scenesLength': (movie['scenes'] as List?)?.length ?? 0,
        'fullMovie': movie.toString(),
      });

      if (_isMovieComplete(movie)) {
        developer.log('Forked movie is complete, navigating to video player');
        final scenes = movie['scenes'] as List<dynamic>? ?? [];
        final userId = movie['userId'] as String?;
        final movieId = movie['documentId'] as String?;

        if (userId == null || movieId == null) {
          developer.log('Error: Missing required movie data for video player', error: {
            'userId': userId,
            'movieId': movieId,
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: Invalid movie data'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        developer.log('Processing scenes for video player:', error: {
          'scenesCount': scenes.length,
          'scenesSample': scenes.take(1).toString(),
          'userId': userId,
          'movieId': movieId,
        });

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MovieVideoPlayerScreen(
              scenes: scenes.map((s) {
                developer.log('Processing scene:', error: s);
                return Map<String, dynamic>.from(s);
              }).toList(),
              userId: userId,
              movieId: movieId,
            ),
          ),
        );
      } else {
        developer.log('Forked movie is incomplete, navigating to scenes screen');
        final movieIdea = movie['movieIdea'] as String?;
        final movieId = movie['documentId'] as String?;
        final scenes = movie['scenes'] as List<dynamic>? ?? [];

        developer.log('Movie details for scenes screen:', error: {
          'movieIdea': movieIdea,
          'movieId': movieId,
          'scenesCount': scenes.length,
        });

        if (movieIdea == null || movieId == null) {
          developer.log('Error: Missing required movie data', error: {
            'movieIdea': movieIdea,
            'movieId': movieId,
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: Invalid movie data'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        try {
          final processedScenes = scenes.map((s) {
            developer.log('Processing scene for scenes screen:', error: s);
            return Map<String, dynamic>.from(s);
          }).toList();

          developer.log('Navigating to MovieScenesScreen with:', error: {
            'movieIdea': movieIdea,
            'movieId': movieId,
            'scenesCount': processedScenes.length,
            'title': movie['title'],
          });

          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => MovieScenesScreen(
                movieIdea: movieIdea,
                scenes: processedScenes,
                movieId: movieId,
                movieTitle: movie['title'] as String?,
              ),
            ),
          );
        } catch (e, stackTrace) {
          developer.log(
            'Error processing scenes',
            error: e,
            stackTrace: stackTrace,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error processing movie data: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error in _navigateToMovie',
        error: e,
        stackTrace: stackTrace,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error navigating to movie: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  bool _isMovieComplete(Map<String, dynamic> movie) {
    return movie['status'] == 'complete';
  }

  int _getIncompleteScenesCount(Map<String, dynamic> movie) {
    final scenes = movie['scenes'] as List<dynamic>? ?? [];
    return scenes.where((scene) => scene['status'] != 'complete').length;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'mNp(s)',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: Provider.of<MovieService>(context).getUserForkedMovies(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error loading mNp(s): ${snapshot.error}',
                        style: TextStyle(color: Colors.red[400]),
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final movies = snapshot.data!;
                  if (movies.isEmpty) {
                    return Center(
                      child: Text(
                        'Your mNp(s) will appear here',
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: movies.length,
                    itemBuilder: (context, index) {
                      final movie = movies[index];
                      final isComplete = _isMovieComplete(movie);
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: () => _navigateToMovie(context, movie),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const CircleAvatar(
                                      child: Icon(Icons.fork_right),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            movie['title'] ?? 'Untitled',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          if (movie['originalTitle'] != null)
                                            Text(
                                              'Forked from: ${movie['originalTitle']}',
                                              style: TextStyle(color: Colors.grey[600]),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Created: ${DateFormatter.formatTimestamp(movie['createdAt'].toDate())}',
                                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                        ),
                                        Text(
                                          'Last Updated: ${DateFormatter.formatTimestamp((movie['updatedAt'] ?? movie['createdAt']).toDate())}',
                                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                        ),
                                      ],
                                    ),
                                    if (_getIncompleteScenesCount(movie) > 0)
                                      Chip(
                                        label: Text(
                                          '${_getIncompleteScenesCount(movie)} scenes pending',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        backgroundColor: Colors.orange[100],
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
} 