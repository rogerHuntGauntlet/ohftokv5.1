import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:developer' as developer;
import '../../../services/movie/movie_service.dart';
import '../utils/date_formatter.dart';
import '../../movie/movie_scenes_screen.dart';
import '../../movie/movie_video_player_screen.dart';

/// Tab view that displays the user's movies.
/// This includes all movies created by the user.
class MoviesTab extends StatelessWidget {
  const MoviesTab({Key? key}) : super(key: key);

  void _navigateToMovie(BuildContext context, Map<String, dynamic> movie) {
    try {
      developer.log('Navigating to movie:', error: {
        'movieId': movie['documentId'],
        'title': movie['title'],
        'status': movie['status'],
        'hasScenes': movie['scenes'] != null,
        'scenesLength': (movie['scenes'] as List?)?.length ?? 0,
        'fullMovie': movie.toString(),
      });

      if (_isMovieComplete(movie)) {
        developer.log('Movie is complete, navigating to video player');
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
        developer.log('Movie is incomplete, navigating to scenes screen');
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
    final status = movie['status'];
    developer.log('Checking movie completion status:', error: {
      'movieId': movie['documentId'],
      'status': status,
    });
    return status == 'complete';
  }

  int _getIncompleteScenesCount(Map<String, dynamic> movie) {
    try {
      final scenes = movie['scenes'] as List<dynamic>? ?? [];
      final incompleteCount = scenes.where((scene) => scene['status'] != 'completed').length;
      developer.log('Counting incomplete scenes:', error: {
        'movieId': movie['documentId'],
        'totalScenes': scenes.length,
        'incompleteCount': incompleteCount,
      });
      return incompleteCount;
    } catch (e, stackTrace) {
      developer.log(
        'Error counting incomplete scenes',
        error: e,
        stackTrace: stackTrace,
      );
      return 0;
    }
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
                'Your Movies',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: Provider.of<MovieService>(context).getUserMovies(),
                builder: (context, snapshot) {
                  developer.log('StreamBuilder state:', error: {
                    'hasData': snapshot.hasData,
                    'hasError': snapshot.hasError,
                    'error': snapshot.error?.toString(),
                    'connectionState': snapshot.connectionState.toString(),
                  });

                  if (snapshot.hasError) {
                    developer.log('StreamBuilder error:', error: snapshot.error);
                    return Center(
                      child: Text(
                        'Error loading movies: ${snapshot.error}',
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
                  developer.log('Movies loaded:', error: {
                    'count': movies.length,
                    'movieIds': movies.map((m) => m['documentId']).toList(),
                  });

                  if (movies.isEmpty) {
                    return Center(
                      child: Text(
                        'Your created movies will appear here',
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
                      developer.log('Raw movie data:', error: {
                        'fullData': movie,
                        'keys': movie.keys.toList(),
                        'id': movie['documentId'],
                        'userId': movie['userId'],
                        'title': movie['title'],
                        'movieIdea': movie['movieIdea'],
                        'status': movie['status'],
                        'hasScenes': movie['scenes'] != null,
                        'scenesCount': (movie['scenes'] as List?)?.length ?? 0,
                      });

                      if (movie['scenes'] != null) {
                        final scenes = movie['scenes'] as List;
                        developer.log('First scene data:', error: scenes.isNotEmpty ? scenes.first : 'No scenes');
                      }

                      final isComplete = _isMovieComplete(movie);
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: () {
                            developer.log('Movie card tapped:', error: {
                              'movieId': movie['documentId'],
                              'userId': movie['userId'],
                              'isComplete': isComplete,
                              'status': movie['status'],
                              'hasScenes': movie['scenes'] != null,
                              'scenesCount': (movie['scenes'] as List?)?.length ?? 0,
                            });

                            // Validate required fields before navigation
                            final hasRequiredFields = movie['documentId'] != null && 
                                                    movie['userId'] != null && 
                                                    movie['movieIdea'] != null;
                            
                            if (!hasRequiredFields) {
                              developer.log('Missing required fields:', error: {
                                'hasId': movie['documentId'] != null,
                                'hasUserId': movie['userId'] != null,
                                'hasMovieIdea': movie['movieIdea'] != null,
                                'availableFields': movie.keys.toList(),
                              });
                            }

                            _navigateToMovie(context, movie);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const CircleAvatar(
                                      child: Icon(Icons.movie),
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
                                          Text(
                                            movie['movieIdea'],
                                            style: TextStyle(color: Colors.grey[600]),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
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