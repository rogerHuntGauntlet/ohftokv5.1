class TrainingScene {
  final String id;
  final String title;
  final String? description;
  final String? difficulty;
  final String? videoPath;  // Path to the recorded/uploaded video
  final DateTime? submittedAt;  // When the scene was submitted for feedback
  final String? feedback;  // Director's feedback on the scene
  final Map<String, dynamic>? metadata;

  TrainingScene({
    required this.id,
    required this.title,
    this.description,
    this.difficulty,
    this.videoPath,
    this.submittedAt,
    this.feedback,
    this.metadata,
  });

  // Create a new training scene attempt
  factory TrainingScene.newAttempt({
    required String videoPath,
    String? description,
  }) {
    return TrainingScene(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Training Scene Attempt',
      description: description ?? 'Scene submitted for director analysis',
      videoPath: videoPath,
      submittedAt: DateTime.now(),
    );
  }
} 