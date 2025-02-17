import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../models/feed_item.dart';

class FeedItemWidget extends StatelessWidget {
  final FeedItem feedItem;
  final VoidCallback onLikePressed;

  const FeedItemWidget({
    Key? key,
    required this.feedItem,
    required this.onLikePressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User info header
          ListTile(
            leading: CircleAvatar(
              backgroundImage: feedItem.userProfileImage.isNotEmpty
                  ? NetworkImage(feedItem.userProfileImage)
                  : null,
              child: feedItem.userProfileImage.isEmpty
                  ? const Icon(Icons.person)
                  : null,
            ),
            title: Text(
              feedItem.userDisplayName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              timeago.format(feedItem.createdAt),
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                // TODO: Implement menu actions
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'share',
                  child: Text('Share'),
                ),
                const PopupMenuItem(
                  value: 'report',
                  child: Text('Report'),
                ),
              ],
            ),
          ),

          // Content preview
          if (feedItem.contentPreviewUrl != null)
            Container(
              constraints: const BoxConstraints(
                maxHeight: 400,
              ),
              width: double.infinity,
              child: Image.network(
                feedItem.contentPreviewUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Icon(
                      Icons.error_outline,
                      size: 50,
                      color: Colors.grey,
                    ),
                  );
                },
              ),
            ),

          // Description
          if (feedItem.description != null && feedItem.description!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                feedItem.description!,
                style: const TextStyle(fontSize: 16),
              ),
            ),

          // Action buttons
          Row(
            children: [
              IconButton(
                icon: Icon(
                  feedItem.isLiked ? Icons.favorite : Icons.favorite_border,
                  color: feedItem.isLiked ? Colors.red : null,
                ),
                onPressed: onLikePressed,
              ),
              Text(
                feedItem.likeCount.toString(),
                style: const TextStyle(
                  color: Colors.grey,
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.comment_outlined),
                onPressed: () {
                  // TODO: Implement comments view
                },
              ),
              Text(
                feedItem.commentCount.toString(),
                style: const TextStyle(
                  color: Colors.grey,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.share_outlined),
                onPressed: () {
                  // TODO: Implement share functionality
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
} 