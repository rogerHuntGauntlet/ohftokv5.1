import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/live/live_reaction.dart';
import '../../../services/live/live_reaction_service.dart';
import '../../../services/social/auth_service.dart';

class LiveReactionsWidget extends StatelessWidget {
  final String streamId;
  final LiveReactionService reactionService;

  const LiveReactionsWidget({
    Key? key,
    required this.streamId,
    required this.reactionService,
  }) : super(key: key);

  Future<void> _sendReaction(BuildContext context, ReactionType type) async {
    final user = context.read<AuthService>().currentUser;
    if (user == null) return;

    try {
      await reactionService.addReaction(
        streamId: streamId,
        userId: user.uid,
        userDisplayName: user.displayName ?? 'Anonymous',
        type: type,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending reaction: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Reaction counts
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: StreamBuilder<Map<ReactionType, int>>(
            stream: reactionService.getReactionCounts(streamId),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                );
              }

              final counts = snapshot.data!;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ReactionCount(
                    emoji: '❤️',
                    count: counts[ReactionType.love] ?? 0,
                  ),
                  const SizedBox(width: 8),
                  _ReactionCount(
                    emoji: '👍',
                    count: counts[ReactionType.like] ?? 0,
                  ),
                  const SizedBox(width: 8),
                  _ReactionCount(
                    emoji: '😂',
                    count: counts[ReactionType.laugh] ?? 0,
                  ),
                  const SizedBox(width: 8),
                  _ReactionCount(
                    emoji: '😮',
                    count: counts[ReactionType.wow] ?? 0,
                  ),
                  const SizedBox(width: 8),
                  _ReactionCount(
                    emoji: '🎉',
                    count: counts[ReactionType.support] ?? 0,
                  ),
                ],
              );
            },
          ),
        ),

        const SizedBox(height: 8),

        // Reaction buttons
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ReactionButton(
                emoji: '❤️',
                onTap: () => _sendReaction(context, ReactionType.love),
              ),
              const SizedBox(width: 8),
              _ReactionButton(
                emoji: '👍',
                onTap: () => _sendReaction(context, ReactionType.like),
              ),
              const SizedBox(width: 8),
              _ReactionButton(
                emoji: '😂',
                onTap: () => _sendReaction(context, ReactionType.laugh),
              ),
              const SizedBox(width: 8),
              _ReactionButton(
                emoji: '😮',
                onTap: () => _sendReaction(context, ReactionType.wow),
              ),
              const SizedBox(width: 8),
              _ReactionButton(
                emoji: '🎉',
                onTap: () => _sendReaction(context, ReactionType.support),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Recent reactions
        SizedBox(
          height: 40,
          child: StreamBuilder<List<LiveReaction>>(
            stream: reactionService.getRecentReactions(streamId),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();

              final reactions = snapshot.data!;
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: reactions.length,
                itemBuilder: (context, index) {
                  final reaction = reactions[index];
                  return _FloatingReaction(
                    emoji: _getEmojiForType(reaction.type),
                    username: reaction.userDisplayName,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  String _getEmojiForType(ReactionType type) {
    switch (type) {
      case ReactionType.love:
        return '❤️';
      case ReactionType.like:
        return '👍';
      case ReactionType.laugh:
        return '😂';
      case ReactionType.wow:
        return '😮';
      case ReactionType.support:
        return '🎉';
      case ReactionType.custom:
        return '🌟';
    }
  }
}

class _ReactionCount extends StatelessWidget {
  final String emoji;
  final int count;

  const _ReactionCount({
    required this.emoji,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 4),
        Text(
          _formatCount(count),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }
}

class _ReactionButton extends StatelessWidget {
  final String emoji;
  final VoidCallback onTap;

  const _ReactionButton({
    required this.emoji,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 20)),
      ),
    );
  }
}

class _FloatingReaction extends StatelessWidget {
  final String emoji;
  final String username;

  const _FloatingReaction({
    required this.emoji,
    required this.username,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 4),
          Text(
            username,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
} 