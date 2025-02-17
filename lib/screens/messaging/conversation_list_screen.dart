import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/message.dart';
import '../../services/messaging/messaging_service.dart';
import '../../services/social/auth_service.dart';
import 'chat_screen.dart';

class ConversationListScreen extends StatelessWidget {
  const ConversationListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final messagingService = Provider.of<MessagingService>(context);
    final currentUserId = authService.currentUser?.uid;

    if (currentUserId == null) {
      return const Center(child: Text('Please log in to view messages'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Implement search functionality
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Conversation>>(
        stream: messagingService.getUserConversations(currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final conversations = snapshot.data ?? [];

          if (conversations.isEmpty) {
            return const Center(
              child: Text('No conversations yet. Start chatting!'),
            );
          }

          return ListView.builder(
            itemCount: conversations.length,
            itemBuilder: (context, index) {
              final conversation = conversations[index];
              // Get the other participant's ID (not the current user)
              final otherUserId = conversation.participants
                  .firstWhere((id) => id != currentUserId);

              return FutureBuilder<Map<String, dynamic>>(
                future: authService.getUserDetails(otherUserId),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return const SizedBox.shrink();
                  }

                  final userData = userSnapshot.data!;
                  final username = userData['username'] ?? 'Unknown User';
                  final avatarUrl = userData['photoUrl'];

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: avatarUrl != null
                          ? NetworkImage(avatarUrl)
                          : null,
                      child: avatarUrl == null
                          ? Text(username[0].toUpperCase())
                          : null,
                    ),
                    title: Text(username),
                    subtitle: Text(
                      conversation.lastMessageContent ?? 'No messages yet',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatTimestamp(conversation.lastMessageTime),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (conversation.hasUnreadMessages)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Text(
                              '',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            conversationId: conversation.id,
                            otherUserId: otherUserId,
                            otherUserName: username,
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Implement new conversation
        },
        child: const Icon(Icons.message),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 7) {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }
} 