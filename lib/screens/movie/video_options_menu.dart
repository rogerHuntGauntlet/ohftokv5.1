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
            // Show confirmation dialog first
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Generate AI Video'),
                content: const Text('Are you sure you want to generate an AI video for this scene? This action cannot be undone.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Close dialog
                      Navigator.pop(context); // Close bottom sheet
                      onGenerateAI();
                    },
                    child: const Text('Generate'),
                  ),
                ],
              ),
            );
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
