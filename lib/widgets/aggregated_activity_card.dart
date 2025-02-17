import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../services/social/activity_aggregator_service.dart';
import 'activity_card.dart';
import 'user_avatar.dart';

class AggregatedActivityCard extends StatelessWidget {
  final AggregatedActivity aggregatedActivity;
  final VoidCallback? onTap;
  final Function(String)? onUserTap;

  const AggregatedActivityCard({
    Key? key,
    required this.aggregatedActivity,
    this.onTap,
    this.onUserTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!aggregatedActivity.isAggregated) {
      return ActivityCard(
        activity: aggregatedActivity.primaryActivity,
        onTap: onTap,
        onUserTap: onUserTap != null 
          ? () => onUserTap!(aggregatedActivity.primaryActivity.user.id)
          : null,
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User avatars stack
              Row(
                children: [
                  SizedBox(
                    width: 80,
                    height: 40,
                    child: Stack(
                      children: [
                        for (var i = 0; i < _getVisibleAvatarCount(); i++)
                          Positioned(
                            left: i * 20.0,
                            child: GestureDetector(
                              onTap: onUserTap != null 
                                ? () => onUserTap!(aggregatedActivity.activities[i].user.id)
                                : null,
                              child: UserAvatar(
                                imageUrl: aggregatedActivity.activities[i].user.profileImageUrl,
                                size: 40,
                                borderColor: Colors.white,
                                borderWidth: 2,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          aggregatedActivity.summary ?? '',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          timeago.format(aggregatedActivity.timestamp),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_shouldShowContent()) ...[
                const SizedBox(height: 12),
                _buildContentPreview(context),
              ],
              // Interaction options
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildInteractionButton(
                    context: context,
                    icon: Icons.favorite_border,
                    label: 'Like',
                    onTap: () {/* TODO: Implement like functionality */},
                  ),
                  _buildInteractionButton(
                    context: context,
                    icon: Icons.comment_outlined,
                    label: 'Comment',
                    onTap: () {/* TODO: Implement comment functionality */},
                  ),
                  _buildInteractionButton(
                    context: context,
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

  int _getVisibleAvatarCount() {
    return aggregatedActivity.activities.length > 3 
      ? 3 
      : aggregatedActivity.activities.length;
  }

  bool _shouldShowContent() {
    return aggregatedActivity.type == ActivityType.createMovie ||
           aggregatedActivity.type == ActivityType.like ||
           aggregatedActivity.type == ActivityType.comment;
  }

  Widget _buildContentPreview(BuildContext context) {
    final activity = aggregatedActivity.primaryActivity;
    if (activity.relatedMovie == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (activity.relatedMovie?.thumbnailUrl != null)
            Image.network(
              activity.relatedMovie!.thumbnailUrl!,
              height: 150,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.relatedMovie?.title ?? '',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (activity.relatedMovie?.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    activity.relatedMovie!.description!,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractionButton({
    required BuildContext context,
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
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
} 