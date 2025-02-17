import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/message.dart';
import '../../models/typing_status.dart';
import '../../models/message_reaction.dart';
import '../../services/messaging/messaging_service.dart';
import '../../services/messaging/voice_message_service.dart';
import '../../services/social/auth_service.dart';
import '../../services/video_message_service.dart';
import 'widgets/voice_message_bubble.dart';
import './widgets/video_message_player.dart';
import './widgets/video_message_recorder.dart';
import 'dart:async';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String otherUserId;
  final String otherUserName;
  final bool isGroup;

  const ChatScreen({
    Key? key,
    required this.conversationId,
    required this.otherUserId,
    required this.otherUserName,
    this.isGroup = false,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final VoiceMessageService _voiceService = VoiceMessageService();
  bool _isAttachmentMenuOpen = false;
  Timer? _typingTimer;
  bool _isTyping = false;
  bool _isRecording = false;
  String? _replyToMessageId;
  Message? _replyToMessage;
  final FocusNode _focusNode = FocusNode();
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onTextChanged);
    _voiceService.initialize();
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _typingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _voiceService.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final messagingService = Provider.of<MessagingService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUserId = authService.currentUser?.uid ?? '';

    if (_messageController.text.isNotEmpty && !_isTyping) {
      _isTyping = true;
      messagingService.updateTypingStatus(
        userId: currentUserId,
        conversationId: widget.conversationId,
        isTyping: true,
      );
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(milliseconds: 1000), () {
      if (_isTyping) {
        _isTyping = false;
        messagingService.updateTypingStatus(
          userId: currentUserId,
          conversationId: widget.conversationId,
          isTyping: false,
        );
      }
    });
  }

  Future<void> _sendMessage(MessagingService messagingService, String senderId) async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    await messagingService.sendMessage(
      senderId: senderId,
      conversationId: widget.conversationId,
      content: messageText,
      messageType: MessageType.text,
      conversationType: widget.isGroup ? 'group' : 'individual',
      groupId: widget.isGroup ? widget.conversationId : null,
    );

    _messageController.clear();
    _scrollToBottom();
  }

  Future<void> _sendImage(MessagingService messagingService, String senderId) async {
    final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    // TODO: Implement image upload and sending
    await messagingService.sendMessage(
      senderId: senderId,
      conversationId: widget.conversationId,
      content: '📷 Image',
      messageType: MessageType.image,
      conversationType: widget.isGroup ? 'group' : 'individual',
      groupId: widget.isGroup ? widget.conversationId : null,
    );

    _scrollToBottom();
  }

  Future<void> _handleVoiceMessage(MessagingService messagingService, String senderId) async {
    if (_isRecording) {
      // Stop recording
      final recordingPath = await _voiceService.stopRecording();
      if (recordingPath != null) {
        final downloadUrl = await _voiceService.uploadVoiceMessage(
          recordingPath,
          widget.conversationId,
        );

        if (downloadUrl != null) {
          await messagingService.sendMessage(
            senderId: senderId,
            conversationId: widget.conversationId,
            content: 'Voice Message',
            messageType: MessageType.voice,
            mediaUrl: downloadUrl,
            conversationType: widget.isGroup ? 'group' : 'individual',
            groupId: widget.isGroup ? widget.conversationId : null,
          );
        }
      }
    } else {
      // Start recording
      await _voiceService.startRecording();
    }

    setState(() {
      _isRecording = !_isRecording;
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Widget _buildMessageContent(Message message, bool isCurrentUser) {
    switch (message.messageType) {
      case 'voice':
        return VoiceMessageBubble(
          url: message.mediaUrl!,
          isCurrentUser: isCurrentUser,
        );
      case 'video':
        return VideoMessagePlayer(
          videoUrl: message.mediaUrl!,
          width: 200,
          height: 300,
        );
      case 'image':
        // TODO: Implement image message bubble
        return Text(
          message.content,
          style: TextStyle(
            color: isCurrentUser ? Colors.white : Colors.black,
          ),
        );
      default:
        return Text(
          message.content,
          style: TextStyle(
            color: isCurrentUser ? Colors.white : Colors.black,
          ),
        );
    }
  }

  void _showReactionPicker(Message message) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        height: 100,
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: ReactionType.all.map((reaction) {
            final messagingService = Provider.of<MessagingService>(context, listen: false);
            final authService = Provider.of<AuthService>(context, listen: false);
            final currentUserId = authService.currentUser?.uid ?? '';

            return InkWell(
              onTap: () {
                messagingService.addReaction(
                  messageId: message.id,
                  userId: currentUserId,
                  reactionType: reaction,
                );
                Navigator.pop(context);
              },
              child: Text(
                reaction,
                style: const TextStyle(fontSize: 24),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildReactions(Message message) {
    if (message.reactions?.isEmpty ?? true) return const SizedBox.shrink();

    return Wrap(
      spacing: 4,
      children: message.reactions!.entries.map((entry) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(entry.value.first), // Show first reaction
              const SizedBox(width: 4),
              Text(
                entry.value.length.toString(),
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildReplyPreview() {
    if (_replyToMessage == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Replying to ${_replyToMessage!.senderId}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  _replyToMessage!.content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              setState(() {
                _replyToMessage = null;
                _replyToMessageId = null;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message message, bool isCurrentUser) {
    return GestureDetector(
      onLongPress: () => _showReactionPicker(message),
      onTap: () {
        setState(() {
          _replyToMessage = message;
          _replyToMessageId = message.id;
        });
        _focusNode.requestFocus();
      },
      child: Column(
        crossAxisAlignment:
            isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (message.replyToMessageId != null)
            FutureBuilder<Message?>(
              future: Provider.of<MessagingService>(context)
                  .getMessageById(message.replyToMessageId!),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                final replyMessage = snapshot.data!;
                return Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    replyMessage.content,
                    style: const TextStyle(fontSize: 12),
                  ),
                );
              },
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: isCurrentUser ? Colors.blue : Colors.grey[300],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMessageContent(message, isCurrentUser),
                const SizedBox(height: 4),
                _buildReactions(message),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: _isSearching ? 56 : 0,
      child: _isSearching
          ? TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search messages...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _isSearching = false;
                      _searchQuery = '';
                    });
                  },
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            )
          : null,
    );
  }

  void _showVideoRecorder() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: VideoMessageRecorder(
          onVideoRecorded: (String videoUrl) async {
            Navigator.pop(context);
            final messagingService = Provider.of<MessagingService>(context, listen: false);
            final authService = Provider.of<AuthService>(context, listen: false);
            final currentUserId = authService.currentUser?.uid ?? '';

            await messagingService.sendMessage(
              senderId: currentUserId,
              conversationId: widget.conversationId,
              content: '📹 Video Message',
              messageType: MessageType.video,
              mediaUrl: videoUrl,
              conversationType: widget.isGroup ? 'group' : 'individual',
              groupId: widget.isGroup ? widget.conversationId : null,
            );

            _scrollToBottom();
          },
        ),
      ),
    );
  }

  Widget _buildAttachmentMenu() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: _isAttachmentMenuOpen ? 120 : 0,
      child: SingleChildScrollView(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAttachmentButton(
                  icon: Icons.image,
                  label: 'Image',
                  onTap: () async {
                    final messagingService = Provider.of<MessagingService>(context, listen: false);
                    final authService = Provider.of<AuthService>(context, listen: false);
                    final currentUserId = authService.currentUser?.uid ?? '';
                    await _sendImage(messagingService, currentUserId);
                  },
                ),
                _buildAttachmentButton(
                  icon: Icons.videocam,
                  label: 'Video',
                  onTap: _showVideoRecorder,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Theme.of(context).primaryColor),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messagingService = Provider.of<MessagingService>(context);
    final authService = Provider.of<AuthService>(context);
    final currentUserId = authService.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.otherUserName),
            StreamBuilder<Map<String, DateTime>>(
              stream: messagingService.getTypingStatus(widget.conversationId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();

                final typingUsers = snapshot.data!;
                final typingUserIds = typingUsers.keys.where((id) => id != currentUserId).toList();

                if (typingUserIds.isEmpty) return const SizedBox.shrink();

                return Text(
                  '${typingUserIds.length} typing...',
                  style: const TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
              });
            },
          ),
          if (widget.isGroup)
            IconButton(
              icon: const Icon(Icons.group),
              onPressed: () {
                // TODO: Show group info/settings
              },
            ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: _isSearching && _searchQuery.isNotEmpty
                  ? Stream.fromFuture(
                      messagingService.searchMessages(widget.conversationId, _searchQuery))
                  : messagingService.getMessages(widget.conversationId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final messages = snapshot.data ?? [];

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isCurrentUser = message.senderId == currentUserId;

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 4.0,
                      ),
                      child: _buildMessageBubble(message, isCurrentUser),
                    );
                  },
                );
              },
            ),
          ),
          _buildReplyPreview(),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(_isAttachmentMenuOpen ? Icons.close : Icons.attach_file),
                  onPressed: () {
                    setState(() {
                      _isAttachmentMenuOpen = !_isAttachmentMenuOpen;
                    });
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    focusNode: _focusNode,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(messagingService, currentUserId),
                  ),
                ),
                IconButton(
                  icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                  onPressed: () => _handleVoiceMessage(messagingService, currentUserId),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () => _sendMessage(messagingService, currentUserId),
                ),
              ],
            ),
          ),
          _buildAttachmentMenu(),
        ],
      ),
    );
  }
} 