import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/movie/movie_service.dart';
import '../movie/movie_scenes_screen.dart';

class FindMoviesScreen extends StatelessWidget {
  const FindMoviesScreen({Key? key}) : super(key: key);

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Just now';
    
    final date = timestamp is DateTime 
        ? timestamp
        : timestamp.toDate();
    
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Movies'),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Discover Movies',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: Provider.of<MovieService>(context).getPublicMovies(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
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
                    if (movies.isEmpty) {
                      return Center(
                        child: Text(
                          'No public movies available yet',
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
                        final scenes = List<Map<String, dynamic>>.from(movie['scenes'] ?? [])
                            .where((scene) => 
                              scene['videoUrl'] != null && 
                              scene['videoUrl'].toString().isNotEmpty
                            )
                            .toList();
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            onTap: () async {
                              try {
                                final fullMovie = await Provider.of<MovieService>(context, listen: false)
                                    .getMovie(movie['documentId']);
                                
                                if (context.mounted) {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => MovieScenesScreen(
                                        movieIdea: fullMovie['movieIdea'],
                                        scenes: fullMovie['scenes'],
                                        movieId: fullMovie['documentId'],
                                        movieTitle: fullMovie['title'],
                                        isReadOnly: true,
                                      ),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error loading movie: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        child: Icon(
                                          movie['forkedFrom'] != null ? Icons.fork_right : Icons.movie,
                                        ),
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
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(
                                                  movie['forkedFrom'] != null ? Icons.fork_right : Icons.movie_creation,
                                                  size: 14,
                                                  color: Colors.grey[600],
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  movie['forkedFrom'] != null ? 'mNp Movie' : 'Original Movie',
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 12,
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.play_circle_outline),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Created: ${_formatTimestamp(movie['createdAt'])}',
                                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                      ),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.visibility,
                                            size: 16,
                                            color: Colors.grey[600],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${movie['views'] ?? 0}',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Text(
                                            '${scenes.length} scenes',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
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
      ),
    );
  }
} 