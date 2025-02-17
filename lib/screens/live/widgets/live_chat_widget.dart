import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/live/live_comment.dart';
import '../../../models/live/live_viewer.dart';
import '../../../services/live/live_comment_service.dart';
import '../../../services/live/live_viewer_service.dart';
import '../../../services/social/auth_service.dart';

class LiveChatWidget extends StatefulWidget {
  final String streamId;
  final LiveCommentService commentService;
  final LiveViewerService viewerService;

  const LiveChatWidget({
    Key? key,
    required this.streamId,
    required this.commentService,
    required this.viewerService,
  }) : super(key: key);

  @override
  State<LiveChatWidget> createState() => _LiveChatWidgetState();
}

class _LiveChatWidgetState extends State<LiveChatWidget> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToBottom = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    setState(() {
      _showScrollToBottom = currentScroll < maxScroll - 100;
    });
  }

  void _scrollToBottom() {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _sendComment() async {
    final comment = _commentController.text.trim();
    if (comment.isEmpty) return;

    final user = context.read<AuthService>().currentUser;
    if (user == null) return;

    final viewer = widget.viewerService.currentViewer;
    if (viewer == null) return;

    try {
      await widget.commentService.addComment(
        streamId: widget.streamId,
        userId: user.uid,
        userDisplayName: user.displayName ?? 'Anonymous',
        userProfileImage: user.photoURL,
        content: comment,
        type: viewer.isModerator ? CommentType.moderator : CommentType.regular,
      );

      _commentController.clear();
      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending comment: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Chat header
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: const Row(
              children: [
                Icon(Icons.chat, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Live Chat',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Chat messages
          Expanded(
            child: Stack(
              children: [
                StreamBuilder<List<LiveComment>>(
                  stream: widget.commentService.getComments(widget.streamId),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text(
                          'Error loading comments',
                          style: TextStyle(color: Colors.white),
                        ),
                      );
                    }

                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    final comments = snapshot.data!;
                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(8),
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final comment = comments[index];
                        if (comment.isHidden) return const SizedBox.shrink();
                        
                        return _ChatMessage(
                          comment: comment,
                          onLongPress: widget.viewerService.currentViewer?.isModerator == true
                              ? () => _showModeratorActions(comment)
                              : null,
                        );
                      },
                    );
                  },
                ),

                // Scroll to bottom button
                if (_showScrollToBottom)
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: FloatingActionButton.small(
                      onPressed: _scrollToBottom,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      child: const Icon(Icons.arrow_downward),
                    ),
                  ),
              ],
            ),
          ),

          // Input area
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(color: Colors.white70),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _sendComment(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: _sendComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showModeratorActions(LiveComment comment) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility_off),
              title: const Text('Hide Comment'),
              onTap: () {
                widget.commentService.toggleCommentVisibility(
                  widget.streamId,
                  comment.id,
                  true,
                );
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.push_pin),
              title: Text(
                comment.type == CommentType.pinned ? 'Unpin Comment' : 'Pin Comment'
              ),
              onTap: () {
                widget.commentService.toggleCommentPin(
                  widget.streamId,
                  comment.id,
                  comment.type != CommentType.pinned,
                );
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete Comment'),
              onTap: () {
                widget.commentService.deleteComment(
                  widget.streamId,
                  comment.id,
                );
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatMessage extends StatelessWidget {
  final LiveComment comment;
  final VoidCallback? onLongPress;

  const _ChatMessage({
    required this.comment,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (comment.userProfileImage != null)
              CircleAvatar(
                radius: 16,
                backgroundImage: NetworkImage(comment.userProfileImage!),
              )
            else
              const CircleAvatar(
                radius: 16,
                child: Icon(Icons.person, size: 20),
              ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        comment.userDisplayName,
                        style: TextStyle(
                          color: _getNameColor(comment.type),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (comment.type == CommentType.moderator)
                        Container(
                          margin: const EdgeInsets.only(left: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'MOD',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    comment.content,
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getNameColor(CommentType type) {
    switch (type) {
      case CommentType.moderator:
        return Colors.blue;
      case CommentType.system:
        return Colors.yellow;
      case CommentType.pinned:
        return Colors.green;
      case CommentType.highlighted:
        return Colors.purple;
      default:
        return Colors.white;
    }
  }
} 