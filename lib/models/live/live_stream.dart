import 'package:cloud_firestore/cloud_firestore.dart';

enum LiveStreamStatus {
  scheduled,
  live,
  ended,
  cancelled
}

class LiveStream {
  final String id;
  final String hostId;
  final String title;
  final String? description;
  final DateTime createdAt;
  final DateTime? scheduledFor;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final LiveStreamStatus status;
  final String? thumbnailUrl;
  final int viewerCount;
  final Map<String, dynamic>? settings;
  final Map<String, dynamic>? metadata;

  LiveStream({
    required this.id,
    required this.hostId,
    required this.title,
    this.description,
    required this.createdAt,
    this.scheduledFor,
    this.startedAt,
    this.endedAt,
    required this.status,
    this.thumbnailUrl,
    this.viewerCount = 0,
    this.settings,
    this.metadata,
  });

  factory LiveStream.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return LiveStream(
      id: doc.id,
      hostId: data['hostId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      scheduledFor: data['scheduledFor'] != null 
          ? (data['scheduledFor'] as Timestamp).toDate() 
          : null,
      startedAt: data['startedAt'] != null 
          ? (data['startedAt'] as Timestamp).toDate() 
          : null,
      endedAt: data['endedAt'] != null 
          ? (data['endedAt'] as Timestamp).toDate() 
          : null,
      status: LiveStreamStatus.values.firstWhere(
        (e) => e.toString() == 'LiveStreamStatus.${data['status']}',
        orElse: () => LiveStreamStatus.ended
      ),
      thumbnailUrl: data['thumbnailUrl'],
      viewerCount: data['viewerCount'] ?? 0,
      settings: data['settings'],
      metadata: data['metadata'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'hostId': hostId,
      'title': title,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      'scheduledFor': scheduledFor != null ? Timestamp.fromDate(scheduledFor!) : null,
      'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
      'status': status.toString().split('.').last,
      'thumbnailUrl': thumbnailUrl,
      'viewerCount': viewerCount,
      'settings': settings,
      'metadata': metadata,
    };
  }

  LiveStream copyWith({
    String? id,
    String? hostId,
    String? title,
    String? description,
    DateTime? createdAt,
    DateTime? scheduledFor,
    DateTime? startedAt,
    DateTime? endedAt,
    LiveStreamStatus? status,
    String? thumbnailUrl,
    int? viewerCount,
    Map<String, dynamic>? settings,
    Map<String, dynamic>? metadata,
  }) {
    return LiveStream(
      id: id ?? this.id,
      hostId: hostId ?? this.hostId,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      scheduledFor: scheduledFor ?? this.scheduledFor,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      status: status ?? this.status,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      viewerCount: viewerCount ?? this.viewerCount,
      settings: settings ?? this.settings,
      metadata: metadata ?? this.metadata,
    );
  }
} 