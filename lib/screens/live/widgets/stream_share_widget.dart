import 'package:flutter/material.dart';
import 'package:ohftok/services/sharing/stream_sharing_service.dart';

class StreamShareWidget extends StatefulWidget {
  final String streamId;
  final String streamTitle;
  final String? thumbnailUrl;

  const StreamShareWidget({
    Key? key,
    required this.streamId,
    required this.streamTitle,
    this.thumbnailUrl,
  }) : super(key: key);

  @override
  State<StreamShareWidget> createState() => _StreamShareWidgetState();
}

class _StreamShareWidgetState extends State<StreamShareWidget> {
  final StreamSharingService _sharingService = StreamSharingService();
  String? _streamUrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _generateLink();
  }

  Future<void> _generateLink() async {
    setState(() => _isLoading = true);
    try {
      final url = await _sharingService.generateStreamLink(
        streamId: widget.streamId,
        streamTitle: widget.streamTitle,
        thumbnailUrl: widget.thumbnailUrl,
      );
      setState(() => _streamUrl = url);
    } catch (e) {
      // TODO: Handle error
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isLoading)
          const CircularProgressIndicator()
        else if (_streamUrl != null) ...[
          // QR Code
          Container(
            padding: const EdgeInsets.all(16.0),
            child: _sharingService.generateQRCode(_streamUrl!),
          ),
          
          // Stream URL
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _streamUrl!,
                    style: Theme.of(context).textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    // TODO: Implement copy to clipboard
                  },
                ),
              ],
            ),
          ),

          // Share Button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.share),
              label: const Text('Share Stream'),
              onPressed: () => _sharingService.shareStream(
                streamUrl: _streamUrl!,
                streamTitle: widget.streamTitle,
              ),
            ),
          ),
        ],
      ],
    );
  }
} 