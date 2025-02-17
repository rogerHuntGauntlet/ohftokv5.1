import 'package:flutter/material.dart';

class VideoProgressTracker {
  final BuildContext context;
  bool _isShowing = false;
  double _progress = 0;

  VideoProgressTracker(this.context);

  void show() {
    if (!_isShowing) {
      _isShowing = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text('Processing video... ${(_progress * 100).toStringAsFixed(1)}%'),
                  ],
                ),
              );
            },
          );
        },
      );
    }
  }

  void update(double progress) {
    _progress = progress;
    if (_isShowing && context.mounted) {
      Navigator.of(context).pop();
      show();
    }
  }

  void close() {
    if (_isShowing && context.mounted) {
      Navigator.of(context).pop();
      _isShowing = false;
    }
  }
} 