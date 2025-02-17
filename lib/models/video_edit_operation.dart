import 'dart:io';

enum VideoEditOperationType {
  trim,
  split,
  merge,
  addTransition
}

class VideoEditOperation {
  final VideoEditOperationType type;
  final Map<String, dynamic> parameters;
  final DateTime timestamp;
  bool isCompleted;
  File? resultFile;
  String? error;

  VideoEditOperation({
    required this.type,
    required this.parameters,
    this.isCompleted = false,
    this.resultFile,
    this.error,
  }) : timestamp = DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'type': type.toString(),
      'parameters': parameters,
      'timestamp': timestamp.toIso8601String(),
      'isCompleted': isCompleted,
      'resultFilePath': resultFile?.path,
      'error': error,
    };
  }

  factory VideoEditOperation.fromJson(Map<String, dynamic> json) {
    return VideoEditOperation(
      type: VideoEditOperationType.values.firstWhere(
        (e) => e.toString() == json['type'],
      ),
      parameters: json['parameters'] as Map<String, dynamic>,
      isCompleted: json['isCompleted'] as bool,
      resultFile: json['resultFilePath'] != null 
        ? File(json['resultFilePath'] as String)
        : null,
      error: json['error'] as String?,
    );
  }

  @override
  String toString() {
    return 'VideoEditOperation(type: $type, completed: $isCompleted)';
  }
} 