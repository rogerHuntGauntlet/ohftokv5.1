import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user.dart';
import '../../services/user_service.dart';
import '../../services/movie/movie_firestore_service.dart';

class OtherUserProfileScreen extends StatefulWidget {
  final String userId;

  const OtherUserProfileScreen({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  _OtherUserProfileScreenState createState() => _OtherUserProfileScreenState();
}

class _OtherUserProfileScreenState extends State<OtherUserProfileScreen> {
  late Future<User?> _userFuture;
  late Future<User?> _currentUserFuture;
  late Future<List<Map<String, dynamic>>> _moviesFuture;
  final _movieService = MovieFirestoreService();
  final _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final userService = Provider.of<UserService>(context, listen: false);
    _userFuture = userService.getUserById(widget.userId);
    _currentUserFuture = userService.getCurrentUser();
    _loadMovies();
  }

  void _loadMovies() {
    _moviesFuture = _firestore
        .collection('movies')
        .where('userId', isEqualTo: widget.userId)
        .where('isPublic', isEqualTo: true)
        .get()
        .then((snapshot) async {
          final movies = <Map<String, dynamic>>[];
          
          for (final doc in snapshot.docs) {
            final movieData = doc.data();
            final scenesSnapshot = await doc.reference
                .collection('scenes')
                .orderBy('id')
                .get();
            
            final scenes = scenesSnapshot.docs
                .map((sceneDoc) => {
                      ...sceneDoc.data(),
                      'documentId': sceneDoc.id,
                    })
                .toList();

            movies.add({
              ...movieData,
              'documentId': doc.id,
              'scenes': scenes,
            });
          }
          
          return movies;
        });
  }

  Future<void> _toggleFollow(User targetUser, bool isFollowing) async {
    final userService = Provider.of<UserService>(context, listen: false);
    
    try {
      if (isFollowing) {
        await userService.unfollowUser(targetUser.id);
      } else {
        await userService.followUser(targetUser.id);
      }
      setState(() {
        _loadData();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF6B1FA6),
              const Color(0xFF2E0B8C),
              const Color(0xFFFF4081).withOpacity(0.8),
            ],
          ),
        ),
        child: FutureBuilder<List<User?>>(
          future: Future.wait([_userFuture, _currentUserFuture]),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.white),
                ),
              );
            }

            final user = snapshot.data?[0];
            final currentUser = snapshot.data?[1];

            if (user == null || currentUser == null) {
              return const Center(
                child: Text(
                  'User not found',
                  style: TextStyle(color: Colors.white),
                ),
              );
            }

            final isFollowing = currentUser.isFollowing(user.id);

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const SizedBox(height: 60),
                    _buildProfileHeader(user, isFollowing),
                    const SizedBox(height: 24),
                    _buildUserInfo(user),
                    const SizedBox(height: 24),
                    _buildMoviesList(user),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProfileHeader(User user, bool isFollowing) {
    return Column(
      children: [
        Hero(
          tag: 'profile-picture-${user.id}',
          child: CircleAvatar(
            radius: 60,
            backgroundImage: user.photoUrl != null
                ? NetworkImage(user.photoUrl!)
                : null,
            child: user.photoUrl == null
                ? const Icon(Icons.person, size: 60, color: Colors.white70)
                : null,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          user.displayName,
          style: GoogleFonts.righteous(
            fontSize: 32,
            color: Colors.white,
            shadows: [
              const Shadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(2, 2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => _toggleFollow(user, isFollowing),
          style: ElevatedButton.styleFrom(
            backgroundColor: isFollowing ? Colors.grey : Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: Text(
            isFollowing ? 'Unfollow' : 'Follow',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserInfo(User user) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatItem('Movies', user.totalMoviesCreated.toString()),
                  _buildStatDivider(),
                  InkWell(
                    onTap: () => _showFollowersList(user.id),
                    child: _buildStatItem('Followers', user.followersCount.toString()),
                  ),
                  _buildStatDivider(),
                  InkWell(
                    onTap: () => _showFollowingList(user.id),
                    child: _buildStatItem('Following', user.followingCount.toString()),
                  ),
                ],
              ),
              if (user.bio != null && user.bio!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  user.bio!,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      height: 30,
      width: 1,
      color: Colors.white.withOpacity(0.3),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildMoviesList(User user) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _moviesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading movies: ${snapshot.error}',
              style: const TextStyle(color: Colors.white70),
            ),
          );
        }

        final movies = snapshot.data ?? [];
        if (movies.isEmpty) {
          return Center(
            child: Text(
              'No public movies yet',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
          );
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Public Movies',
                    style: GoogleFonts.righteous(
                      fontSize: 24,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: movies.length,
                    itemBuilder: (context, index) {
                      final movie = movies[index];
                      return _buildMovieItem(movie);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMovieItem(Map<String, dynamic> movie) {
    final status = movie['status'] as String;
    final createdAt = (movie['createdAt'] as Timestamp).toDate();
    final scenes = List<Map<String, dynamic>>.from(movie['scenes'] ?? []);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        title: Text(
          movie['title'] ?? 'Untitled Movie',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              movie['movieIdea'] ?? '',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white70,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildStatusChip(status),
                const SizedBox(width: 8),
                Text(
                  '${scenes.length} scenes',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDate(createdAt),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: () {
          // TODO: Navigate to movie view screen
        },
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;

    switch (status) {
      case 'completed':
        color = Colors.green;
        label = 'Completed';
        break;
      case 'in_progress':
        color = Colors.orange;
        label = 'In Progress';
        break;
      default:
        color = Colors.grey;
        label = 'Draft';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}y ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}mo ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Future<void> _showFollowersList(String userId) async {
    final userService = Provider.of<UserService>(context, listen: false);
    final followers = await userService.getFollowers(userId);
    
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildUserListSheet('Followers', followers),
    );
  }

  Future<void> _showFollowingList(String userId) async {
    final userService = Provider.of<UserService>(context, listen: false);
    final following = await userService.getFollowing(userId);
    
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildUserListSheet('Following', following),
    );
  }

  Widget _buildUserListSheet(String title, List<User> users) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
            child: Text(
              title,
              style: GoogleFonts.righteous(
                fontSize: 24,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                return _buildUserListItem(user);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserListItem(User user) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
        child: user.photoUrl == null ? const Icon(Icons.person) : null,
      ),
      title: Text(
        user.displayName,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        user.bio ?? '',
        style: GoogleFonts.poppins(
          color: Colors.white70,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () {
        Navigator.pop(context);
        if (user.id != widget.userId) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OtherUserProfileScreen(userId: user.id),
            ),
          );
        }
      },
    );
  }
} 