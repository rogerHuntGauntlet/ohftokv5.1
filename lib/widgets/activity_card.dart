import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/activity.dart';
import '../models/user.dart';
import '../models/movie.dart';
import '../widgets/user_avatar.dart';
import '../widgets/movie_preview_card.dart';

class ActivityCard extends StatelessWidget {
  final Activity activity;
  final VoidCallback? onTap;
  final VoidCallback? onUserTap;

  const ActivityCard({
    Key? key,
    required this.activity,
    this.onTap,
    this.onUserTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with user info and timestamp
              Row(
                children: [
                  GestureDetector(
                    onTap: onUserTap,
                    child: UserAvatar(
                      imageUrl: activity.user.profileImageUrl,
                      size: 40,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity.user.username,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          timeago.format(activity.timestamp),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildActivityIcon(),
                ],
              ),
              const SizedBox(height: 12),
              // Activity description
              Text(
                _buildActivityDescription(),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (activity.relatedMovie != null) ...[
                const SizedBox(height: 12),
                MoviePreviewCard(movie: activity.relatedMovie!),
              ],
              // Interaction options
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildInteractionButton(
                    icon: Icons.favorite_border,
                    label: 'Like',
                    onTap: () {/* TODO: Implement like functionality */},
                  ),
                  _buildInteractionButton(
                    icon: Icons.comment_outlined,
                    label: 'Comment',
                    onTap: () {/* TODO: Implement comment functionality */},
                  ),
                  _buildInteractionButton(
                    icon: Icons.share_outlined,
                    label: 'Share',
                    onTap: () {/* TODO: Implement share functionality */},
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityIcon() {
    IconData icon;
    Color color;
    
    switch (activity.type) {
      case ActivityType.createMovie:
        icon = Icons.movie_creation;
        color = Colors.blue;
        break;
      case ActivityType.like:
        icon = Icons.favorite;
        color = Colors.red;
        break;
      case ActivityType.comment:
        icon = Icons.comment;
        color = Colors.green;
        break;
      case ActivityType.follow:
        icon = Icons.person_add;
        color = Colors.purple;
        break;
      default:
        icon = Icons.notifications;
        color = Colors.grey;
    }

    return Icon(icon, color: color);
  }

  String _buildActivityDescription() {
    switch (activity.type) {
      case ActivityType.createMovie:
        return 'created a new movie "${activity.relatedMovie?.title ?? ''}"';
      case ActivityType.like:
        return 'liked ${activity.targetUser?.username ?? "a"}'s movie';
      case ActivityType.comment:
        return 'commented on ${activity.targetUser?.username ?? "a"}'s movie';
      case ActivityType.follow:
        return 'started following ${activity.targetUser?.username ?? "someone"}';
      default:
        return activity.description ?? '';
    }
  }

  Widget _buildInteractionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 4),
            Text(label),
          ],
        ),
      ),
    );
  }
} 