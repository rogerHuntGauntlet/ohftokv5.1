import 'package:flutter/material.dart';
import '../../services/sharing/base_sharing_service.dart';
import '../../services/sharing/social_media_service.dart';

class ShareContentWidget extends StatefulWidget {
  final String contentId;
  final String title;
  final String? description;
  final String? thumbnailUrl;
  final String? videoPath;
  final bool showQRCode;
  final bool showSocialMedia;

  const ShareContentWidget({
    Key? key,
    required this.contentId,
    required this.title,
    this.description,
    this.thumbnailUrl,
    this.videoPath,
    this.showQRCode = true,
    this.showSocialMedia = true,
  }) : super(key: key);

  @override
  State<ShareContentWidget> createState() => _ShareContentWidgetState();
}

class _ShareContentWidgetState extends State<ShareContentWidget> {
  final BaseSharingService _sharingService = BaseSharingService();
  final SocialMediaService _socialMediaService = SocialMediaService();
  String? _generatedUrl;
  bool _isLoading = false;
  List<String>? _suggestedHashtags;

  @override
  void initState() {
    super.initState();
    _generateLink();
    if (widget.showSocialMedia) {
      _generateHashtags();
    }
  }

  Future<void> _generateLink() async {
    setState(() => _isLoading = true);
    try {
      final url = await _sharingService.generateDynamicLink(
        path: '/content/${widget.contentId}',
        title: widget.title,
        description: widget.description,
        thumbnailUrl: widget.thumbnailUrl,
      );
      setState(() => _generatedUrl = url);
    } catch (e) {
      print('Error generating link: $e');
      // TODO: Show error message
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generateHashtags() async {
    try {
      final hashtags = await _socialMediaService.generateHashtagSuggestions(widget.title);
      setState(() => _suggestedHashtags = hashtags);
    } catch (e) {
      print('Error generating hashtags: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Share',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const CircularProgressIndicator()
          else if (_generatedUrl != null) ...[
            if (widget.showQRCode) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _sharingService.generateQRCode(_generatedUrl!),
              ),
              const SizedBox(height: 16),
            ],
            // URL display and copy button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _generatedUrl!,
                      style: Theme.of(context).textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () => _sharingService.copyToClipboard(_generatedUrl!),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Share buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildShareButton(
                  icon: Icons.share,
                  label: 'Share',
                  onTap: () => _sharingService.shareContent(
                    url: _generatedUrl!,
                    title: widget.title,
                  ),
                ),
                if (widget.showSocialMedia && widget.videoPath != null) ...[
                  _buildShareButton(
                    icon: Icons.camera_alt,
                    label: 'Instagram',
                    onTap: () => _shareToInstagram(),
                  ),
                  _buildShareButton(
                    icon: Icons.music_note,
                    label: 'TikTok',
                    onTap: () => _shareToTikTok(),
                  ),
                  _buildShareButton(
                    icon: Icons.play_arrow,
                    label: 'YouTube',
                    onTap: () => _shareToYouTube(),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildShareButton({
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
            child: Icon(
              icon,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Future<void> _shareToInstagram() async {
    if (widget.videoPath == null) return;
    try {
      await _socialMediaService.shareToInstagram(
        videoPath: widget.videoPath!,
        caption: widget.title,
        hashtags: _suggestedHashtags,
      );
    } catch (e) {
      print('Error sharing to Instagram: $e');
      // TODO: Show error message
    }
  }

  Future<void> _shareToTikTok() async {
    if (widget.videoPath == null) return;
    try {
      await _socialMediaService.shareToTikTok(
        videoPath: widget.videoPath!,
        caption: widget.title,
        hashtags: _suggestedHashtags,
      );
    } catch (e) {
      print('Error sharing to TikTok: $e');
      // TODO: Show error message
    }
  }

  Future<void> _shareToYouTube() async {
    if (widget.videoPath == null) return;
    try {
      await _socialMediaService.shareToYouTube(
        videoPath: widget.videoPath!,
        title: widget.title,
        description: widget.description ?? '',
        hashtags: _suggestedHashtags,
      );
    } catch (e) {
      print('Error sharing to YouTube: $e');
      // TODO: Show error message
    }
  }
} 