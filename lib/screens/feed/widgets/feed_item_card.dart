import 'package:flutter/material.dart';
import '../../../models/feed_item.dart';
import 'package:timeago/timeago.dart' as timeago;

class FeedItemCard extends StatelessWidget {
  final FeedItem item;
  final VoidCallback? onTap;

  const FeedItemCard({
    Key? key,
    required this.item,
    this.onTap,
  }) : super(key: key);

  Widget _buildActivityContent() {
    switch (item.activityType) {
      case 'post':
        return Text(item.content ?? '');
      case 'like':
        return const Text('liked your movie');
      case 'follow':
        return const Text('started following you');
      case 'comment':
        return Text('commented: ${item.content ?? ''}');
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundImage: NetworkImage(item.userProfileImage),
                    radius: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.userDisplayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          timeago.format(item.timestamp),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildActivityContent(),
              if (item.movieId != null) ...[
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      Icon(Icons.movie, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      const Text('View Movie'),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
} 