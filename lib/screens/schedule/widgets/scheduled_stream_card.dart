import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/live/scheduled_stream.dart';
import '../../../services/live/scheduled_stream_service.dart';
import 'edit_stream_dialog.dart';

class ScheduledStreamCard extends StatelessWidget {
  final ScheduledStream stream;
  final ScheduledStreamService streamService;
  final bool isHost;
  final bool isSubscribed;

  const ScheduledStreamCard({
    Key? key,
    required this.stream,
    required this.streamService,
    required this.isHost,
    required this.isSubscribed,
  }) : super(key: key);

  Future<void> _showEditDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => EditStreamDialog(
        stream: stream,
        streamService: streamService,
      ),
    );
  }

  Future<void> _showCancelDialog(BuildContext context) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Stream'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Are you sure you want to cancel this stream?'),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Reason for cancellation',
                hintText: 'Enter a reason for cancelling the stream',
              ),
              maxLines: 3,
              onSubmitted: (value) => Navigator.pop(context, value),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(
              context,
              'Stream cancelled by host',
            ),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (reason != null) {
      await streamService.cancelScheduledStream(
        streamId: stream.id,
        reason: reason,
      );
    }
  }

  Future<void> _toggleSubscription(BuildContext context) async {
    try {
      if (isSubscribed) {
        await streamService.unsubscribeFromStream(
          streamId: stream.id,
          userId: stream.hostId,
        );
      } else {
        await streamService.subscribeToStream(
          streamId: stream.id,
          userId: stream.hostId,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM d, y \'at\' h:mm a');
    final durationText = stream.duration.inHours > 0
        ? '${stream.duration.inHours}h ${stream.duration.inMinutes % 60}m'
        : '${stream.duration.inMinutes}m';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stream thumbnail or placeholder
          if (stream.thumbnailUrl != null)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                stream.thumbnailUrl!,
                fit: BoxFit.cover,
              ),
            )
          else
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                color: theme.colorScheme.primary.withOpacity(0.1),
                child: Center(
                  child: Icon(
                    Icons.live_tv,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and status
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        stream.title,
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    if (stream.isCancelled)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Cancelled',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 8),

                // Host info
                Row(
                  children: [
                    CircleAvatar(
                      backgroundImage: stream.hostProfileImage != null
                          ? NetworkImage(stream.hostProfileImage!)
                          : null,
                      child: stream.hostProfileImage == null
                          ? Text(stream.hostDisplayName[0])
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      stream.hostDisplayName,
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Schedule info
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 16),
                    const SizedBox(width: 4),
                    Text(dateFormat.format(stream.scheduledStart)),
                    const SizedBox(width: 16),
                    const Icon(Icons.timer, size: 16),
                    const SizedBox(width: 4),
                    Text(durationText),
                  ],
                ),

                if (stream.description != null) ...[
                  const SizedBox(height: 8),
                  Text(stream.description!),
                ],

                if (stream.tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: stream.tags.map((tag) {
                      return Chip(
                        label: Text(tag),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      );
                    }).toList(),
                  ),
                ],

                const SizedBox(height: 16),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isHost && !stream.isCancelled) ...[
                      TextButton(
                        onPressed: () => _showEditDialog(context),
                        child: const Text('Edit'),
                      ),
                      TextButton(
                        onPressed: () => _showCancelDialog(context),
                        child: const Text('Cancel'),
                      ),
                    ],
                    if (!isHost && !stream.isCancelled)
                      TextButton.icon(
                        onPressed: () => _toggleSubscription(context),
                        icon: Icon(
                          isSubscribed ? Icons.notifications_off : Icons.notifications,
                        ),
                        label: Text(isSubscribed ? 'Unsubscribe' : 'Subscribe'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 