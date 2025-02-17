import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/feed_item.dart';
import '../../models/activity.dart';
import '../../services/social/feed_service.dart';
import '../../services/social/activity_service.dart';
import '../../services/social/auth_service.dart';
import '../../services/movie/movie_service.dart';
import 'widgets/feed_item_card.dart';
import 'widgets/activity_filter_bar.dart';
import '../movie/movie_video_player_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({Key? key}) : super(key: key);

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final FeedService _feedService = FeedService();
  final ActivityService _activityService = ActivityService();
  final ScrollController _scrollController = ScrollController();
  DocumentSnapshot? _lastDocument;
  bool _isLoading = false;
  List<Activity> _activities = [];
  List<String> _selectedTypes = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitialFeed();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialFeed() async {
    final userId = context.read<AuthService>().currentUser?.uid;
    if (userId == null) return;

    if (_selectedTypes.isEmpty) {
      // Load all activities
      _activityService.getUserActivities(userId).listen((activities) {
        if (mounted) {
          setState(() {
            _activities = activities;
          });
        }
      });
    } else {
      // Load filtered activities
      _activityService.getFilteredActivities(userId, _selectedTypes).listen((activities) {
        if (mounted) {
          setState(() {
            _activities = activities;
          });
        }
      });
    }
  }

  Future<void> _loadMoreFeed() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    final userId = context.read<AuthService>().currentUser?.uid;
    if (userId == null) return;

    try {
      final newActivities = await (_selectedTypes.isEmpty
          ? _activityService.getUserActivities(userId, lastDocument: _lastDocument)
          : _activityService.getFilteredActivities(userId, _selectedTypes, lastDocument: _lastDocument)
      ).first;

      if (mounted) {
        setState(() {
          _activities.addAll(newActivities);
          if (newActivities.isNotEmpty) {
            _lastDocument = newActivities.last as DocumentSnapshot;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreFeed();
    }
  }

  Future<void> _onRefresh() async {
    _lastDocument = null;
    await _loadInitialFeed();
  }

  void _onFilterChanged(List<String> types) {
    setState(() {
      _selectedTypes = types;
      _lastDocument = null;
    });
    _loadInitialFeed();
  }

  void _onActivityTap(Activity activity) {
    if (activity.movieId != null) {
      final movieService = Provider.of<MovieService>(context, listen: false);
      movieService.getMovie(activity.movieId!).then((movie) {
        if (mounted) {
          final scenesWithVideos = (movie['scenes'] as List<dynamic>)
              .map((scene) => Map<String, dynamic>.from(scene))
              .where((scene) => 
                scene['videoUrl'] != null && 
                scene['videoUrl'].toString().isNotEmpty
              )
              .toList();

          if (scenesWithVideos.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MovieVideoPlayerScreen(
                  scenes: scenesWithVideos,
                  initialIndex: 0,
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('This movie has no viewable scenes yet.'),
              ),
            );
          }
        }
      }).catchError((error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading movie: $error'),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feed'),
        elevation: 0,
      ),
      body: Column(
        children: [
          ActivityFilterBar(
            selectedTypes: _selectedTypes,
            onFilterChanged: _onFilterChanged,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              child: _activities.isEmpty
                  ? const Center(
                      child: Text('No activities yet'),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _activities.length + 1,
                      itemBuilder: (context, index) {
                        if (index == _activities.length) {
                          return _isLoading
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              : const SizedBox.shrink();
                        }

                        final activity = _activities[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 4.0,
                          ),
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.person),
                            ),
                            title: Text(activity.getDescription()),
                            subtitle: Text(
                              _formatTimestamp(activity.timestamp),
                            ),
                            onTap: () => _onActivityTap(activity),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final difference = DateTime.now().difference(timestamp);
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
} 