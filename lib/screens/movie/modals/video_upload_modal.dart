import 'package:flutter/material.dart';

class VideoUploadModal extends StatelessWidget {
  final Stream<double> progressStream;

  const VideoUploadModal({
    super.key,
    required this.progressStream,
  });

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: StreamBuilder<double>(
        stream: progressStream,
        builder: (context, snapshot) {
          return AlertDialog(
            title: Text(snapshot.data == 1.0 ? 'Complete!' : 'Uploading Video'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                if (snapshot.data != 1.0) LinearProgressIndicator(
                  value: snapshot.data,
                ),
                if (snapshot.data == 1.0) const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  snapshot.data == 1.0
                    ? 'Video upload successful!'
                    : snapshot.data != null 
                      ? '${(snapshot.data! * 100).toStringAsFixed(0)}%'
                      : 'Starting upload...',
                ),
              ],
            ),
            actions: snapshot.data == 1.0 ? [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ] : null,
          );
        },
      ),
    );
  }
} 