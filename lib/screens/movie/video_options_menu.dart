import 'package:flutter/material.dart';

class VideoOptionsMenu extends StatelessWidget {
  final Function(bool fromCamera) onUploadVideo;
  final VoidCallback onGenerateAI;

  const VideoOptionsMenu({
    super.key,
    required this.onUploadVideo,
    required this.onGenerateAI,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(Icons.auto_awesome),
          title: const Text('Generate AI Video'),
          onTap: () {
            Navigator.pop(context);
            onGenerateAI();
          },
        ),
        ListTile(
          leading: const Icon(Icons.camera_alt),
          title: const Text('Record Video'),
          onTap: () {
            Navigator.pop(context);
            onUploadVideo(true);
          },
        ),
        ListTile(
          leading: const Icon(Icons.photo_library),
          title: const Text('Upload from Gallery'),
          onTap: () {
            Navigator.pop(context);
            onUploadVideo(false);
          },
        ),
      ],
    );
  }
}
