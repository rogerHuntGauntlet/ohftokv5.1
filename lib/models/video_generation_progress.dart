class VideoGenerationProgress {
  final double percentage;
  final String stage;
  final double progress;
  final String status;
  final Map<String, String>? result;

  VideoGenerationProgress({
    required this.percentage,
    required this.stage,
    double? progress,
    String? status,
    this.result,
  }) : 
    this.progress = progress ?? percentage,
    this.status = status ?? stage;
} 