import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/user.dart';
import '../../services/user_service.dart';
import 'other_user_profile_screen.dart';

class SocialListScreen extends StatefulWidget {
  final String userId;
  final bool isFollowers; // true for followers, false for following

  const SocialListScreen({
    Key? key,
    required this.userId,
    required this.isFollowers,
  }) : super(key: key);

  @override
  _SocialListScreenState createState() => _SocialListScreenState();
}

class _SocialListScreenState extends State<SocialListScreen> {
  late Future<List<User>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  void _loadUsers() {
    final userService = Provider.of<UserService>(context, listen: false);
    _usersFuture = widget.isFollowers
        ? userService.getFollowers(widget.userId)
        : userService.getFollowing(widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isFollowers ? 'Followers' : 'Following',
          style: GoogleFonts.righteous(fontSize: 24),
        ),
        backgroundColor: Theme.of(context).primaryColor,
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
        child: FutureBuilder<List<User>>(
          future: _usersFuture,
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

            final users = snapshot.data ?? [];
            if (users.isEmpty) {
              return Center(
                child: Text(
                  widget.isFollowers ? 'No followers yet' : 'Not following anyone',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              );
            }

            return ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                return _buildUserListItem(user);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildUserListItem(User user) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OtherUserProfileScreen(userId: user.id),
            ),
          );
        },
        leading: Hero(
          tag: 'profile-${user.id}',
          child: CircleAvatar(
            radius: 25,
            backgroundImage: user.photoUrl != null
                ? NetworkImage(user.photoUrl!)
                : null,
            child: user.photoUrl == null
                ? const Icon(Icons.person, color: Colors.white70)
                : null,
          ),
        ),
        title: Text(
          user.displayName,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: user.bio != null && user.bio!.isNotEmpty
            ? Text(
                user.bio!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              )
            : null,
        trailing: _buildFollowButton(user),
      ),
    );
  }

  Widget _buildFollowButton(User user) {
    return FutureBuilder<User?>(
      future: Provider.of<UserService>(context, listen: false).getCurrentUser(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        
        final currentUser = snapshot.data!;
        if (currentUser.id == user.id) return const SizedBox.shrink();

        final isFollowing = currentUser.isFollowing(user.id);
        
        return TextButton(
          onPressed: () async {
            final userService = Provider.of<UserService>(context, listen: false);
            try {
              if (isFollowing) {
                await userService.unfollowUser(user.id);
              } else {
                await userService.followUser(user.id);
              }
              setState(() => _loadUsers());
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e')),
              );
            }
          },
          style: TextButton.styleFrom(
            backgroundColor: isFollowing
                ? Colors.grey[300]
                : Theme.of(context).primaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          child: Text(
            isFollowing ? 'Unfollow' : 'Follow',
            style: TextStyle(
              color: isFollowing ? Colors.black87 : Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      },
    );
  }
} 