class VideoProgress {
  final double progress;
  final String status;
  final String? error;

  VideoProgress({
    required this.progress,
    required this.status,
    this.error,
  });

  factory VideoProgress.initial() {
    return VideoProgress(
      progress: 0.0,
      status: 'Initializing...',
    );
  }

  factory VideoProgress.error(String message) {
    return VideoProgress(
      progress: 0.0,
      status: 'Error',
      error: message,
    );
  }

  factory VideoProgress.complete() {
    return VideoProgress(
      progress: 1.0,
      status: 'Complete',
    );
  }
} 