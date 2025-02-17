import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../../services/feed/feed_service.dart';
import '../../services/storage/storage_service.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({Key? key}) : super(key: key);

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  final FeedService _feedService = FeedService();
  final StorageService _storageService = StorageService();
  final ImagePicker _imagePicker = ImagePicker();
  final int _maxCharacters = 500;
  
  List<File> _selectedMedia = [];
  List<VideoPlayerController?> _videoControllers = [];
  bool _isLoading = false;
  bool _showEmojiPicker = false;
  List<String> _mentionedUsers = [];
  List<String> _hashtags = [];
  bool _isPublic = true;
  String _visibility = 'Everyone';
  bool _allowComments = true;
  bool _allowReposts = true;

  @override
  void initState() {
    super.initState();
    _descriptionController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final text = _descriptionController.text;
    // Extract mentions
    _mentionedUsers = RegExp(r'@(\w+)').allMatches(text).map((m) => m.group(1)!).toList();
    // Extract hashtags
    _hashtags = RegExp(r'#(\w+)').allMatches(text).map((m) => m.group(1)!).toList();
    setState(() {});
  }

  Future<void> _pickMedia({bool isVideo = false}) async {
    try {
      final XFile? media = isVideo 
          ? await _imagePicker.pickVideo(source: ImageSource.gallery)
          : await _imagePicker.pickImage(
              source: ImageSource.gallery,
              imageQuality: 70,
            );

      if (media != null) {
        if (_selectedMedia.length >= 4) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Maximum 4 media items allowed')),
          );
          return;
        }

        setState(() {
          _selectedMedia.add(File(media.path));
          if (isVideo) {
            _videoControllers.add(VideoPlayerController.file(File(media.path))
              ..initialize().then((_) {
                setState(() {});
              }));
          } else {
            _videoControllers.add(null);
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking media: $e')),
      );
    }
  }

  Future<void> _createPost() async {
    if (_descriptionController.text.trim().isEmpty && _selectedMedia.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add some content to your post')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      List<String> mediaUrls = [];
      
      // Upload all media files
      for (var media in _selectedMedia) {
        final url = await _storageService.uploadFile(
          media,
          'feed_media',
        );
        mediaUrls.add(url);
      }

      await _feedService.createFeedItem(
        contentType: 'post',
        contentId: DateTime.now().millisecondsSinceEpoch.toString(),
        contentPreviewUrl: mediaUrls.isNotEmpty ? mediaUrls[0] : null,
        description: _descriptionController.text.trim(),
        metadata: {
          'mediaUrls': mediaUrls,
          'mentions': _mentionedUsers,
          'hashtags': _hashtags,
          'isPublic': _isPublic,
          'allowComments': _allowComments,
          'allowReposts': _allowReposts,
        },
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating post: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _removeMedia(int index) {
    setState(() {
      _selectedMedia.removeAt(index);
      final controller = _videoControllers[index];
      if (controller != null) {
        controller.dispose();
      }
      _videoControllers.removeAt(index);
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    for (var controller in _videoControllers) {
      controller?.dispose();
    }
    super.dispose();
  }

  Widget _buildMediaPreview() {
    if (_selectedMedia.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 200,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _selectedMedia.length,
        itemBuilder: (context, index) {
          final media = _selectedMedia[index];
          final controller = _videoControllers[index];

          return Stack(
            children: [
              Container(
                width: 200,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: controller != null
                      ? AspectRatio(
                          aspectRatio: controller.value.aspectRatio,
                          child: VideoPlayer(controller),
                        )
                      : Image.file(
                          media,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
              Positioned(
                top: 4,
                right: 12,
                child: GestureDetector(
                  onTap: () => _removeMedia(index),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
              if (controller != null)
                Positioned(
                  bottom: 8,
                  right: 16,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        controller.value.isPlaying
                            ? controller.pause()
                            : controller.play();
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        controller.value.isPlaying
                            ? Icons.pause
                            : Icons.play_arrow,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.shade300,
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
                const Expanded(
                  child: Text(
                    'New Post',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                TextButton(
                  onPressed: _isLoading ? null : _createPost,
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).primaryColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).primaryColor,
                            ),
                          ),
                        )
                      : const Text(
                          'Post',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.grey[200],
                      child: const Icon(Icons.person),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _descriptionController,
                        maxLines: null,
                        maxLength: _maxCharacters,
                        decoration: const InputDecoration(
                          hintText: "What's happening?",
                          border: InputBorder.none,
                          counterText: '',
                        ),
                        style: const TextStyle(fontSize: 16),
                        autofocus: true,
                      ),
                    ),
                  ],
                ),
                _buildMediaPreview(),
                if (_mentionedUsers.isNotEmpty || _hashtags.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        ..._mentionedUsers.map((user) => Chip(
                              label: Text('@$user'),
                              backgroundColor: Colors.blue.withOpacity(0.1),
                            )),
                        ..._hashtags.map((tag) => Chip(
                              label: Text('#$tag'),
                              backgroundColor: Colors.green.withOpacity(0.1),
                            )),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Bottom bar with post options
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border(
                top: BorderSide(
                  color: Colors.grey.shade300,
                  width: 0.5,
                ),
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.photo_library),
                        onPressed: () => _pickMedia(isVideo: false),
                        tooltip: 'Add Photo',
                      ),
                      IconButton(
                        icon: const Icon(Icons.videocam),
                        onPressed: () => _pickMedia(isVideo: true),
                        tooltip: 'Add Video',
                      ),
                      IconButton(
                        icon: const Icon(Icons.emoji_emotions),
                        onPressed: () {
                          setState(() {
                            _showEmojiPicker = !_showEmojiPicker;
                          });
                        },
                        tooltip: 'Add Emoji',
                      ),
                      IconButton(
                        icon: const Icon(Icons.tag),
                        onPressed: () {
                          // TODO: Implement mention suggestions
                        },
                        tooltip: 'Mention',
                      ),
                      const Spacer(),
                      PopupMenuButton<String>(
                        icon: Icon(
                          _isPublic ? Icons.public : Icons.lock_outline,
                          size: 20,
                        ),
                        tooltip: 'Post settings',
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'visibility',
                            child: Row(
                              children: [
                                Icon(
                                  _isPublic ? Icons.public : Icons.lock_outline,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text('Visible to $_visibility'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'comments',
                            child: Row(
                              children: [
                                Icon(
                                  _allowComments ? Icons.chat_bubble_outline : Icons.chat_bubble_outline_outlined,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(_allowComments ? 'Comments on' : 'Comments off'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'reposts',
                            child: Row(
                              children: [
                                Icon(
                                  _allowReposts ? Icons.repeat : Icons.block_outlined,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(_allowReposts ? 'Allow reposts' : 'No reposts'),
                              ],
                            ),
                          ),
                        ],
                        onSelected: (value) {
                          setState(() {
                            switch (value) {
                              case 'visibility':
                                _isPublic = !_isPublic;
                                _visibility = _isPublic ? 'Everyone' : 'Followers';
                                break;
                              case 'comments':
                                _allowComments = !_allowComments;
                                break;
                              case 'reposts':
                                _allowReposts = !_allowReposts;
                                break;
                            }
                          });
                        },
                      ),
                      if (_descriptionController.text.length > _maxCharacters * 0.8)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          child: Text(
                            '${_maxCharacters - _descriptionController.text.length}',
                            style: TextStyle(
                              color: _descriptionController.text.length > _maxCharacters
                                  ? Colors.red
                                  : Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (_showEmojiPicker) ...[
                    const SizedBox(height: 8),
                    Container(
                      height: 250,
                      // TODO: Implement emoji picker
                      child: const Center(
                        child: Text('Emoji Picker Coming Soon'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
} 