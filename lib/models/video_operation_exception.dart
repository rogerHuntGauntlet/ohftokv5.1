class VideoOperationException implements Exception {
  final String message;

  VideoOperationException(this.message);

  @override
  String toString() => message;
} 