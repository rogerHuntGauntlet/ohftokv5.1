import 'package:cloud_firestore/cloud_firestore.dart';

enum OverlayType {
  announcement,
  featuredComment,
  featuredResponse,
  reaction,
  moment,
}

class LiveOverlay {
  final String id;
  final String streamId;
  final OverlayType type;
  final String content;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final String? style;
  final Map<String, dynamic>? animation;
  final bool isActive;
  final int priority;

  LiveOverlay({
    required this.id,
    required this.streamId,
    required this.type,
    required this.content,
    this.metadata,
    required this.createdAt,
    this.expiresAt,
    this.style,
    this.animation,
    required this.isActive,
    required this.priority,
  });

  factory LiveOverlay.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LiveOverlay(
      id: doc.id,
      streamId: data['streamId'] as String,
      type: OverlayType.values.firstWhere(
        (e) => e.toString() == 'OverlayType.${data['type']}',
      ),
      content: data['content'] as String,
      metadata: data['metadata'] as Map<String, dynamic>?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      expiresAt: data['expiresAt'] != null
          ? (data['expiresAt'] as Timestamp).toDate()
          : null,
      style: data['style'] as String?,
      animation: data['animation'] as Map<String, dynamic>?,
      isActive: data['isActive'] as bool,
      priority: data['priority'] as int,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'streamId': streamId,
      'type': type.toString().split('.').last,
      'content': content,
      'metadata': metadata,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'style': style,
      'animation': animation,
      'isActive': isActive,
      'priority': priority,
    };
  }

  LiveOverlay copyWith({
    String? id,
    String? streamId,
    OverlayType? type,
    String? content,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? expiresAt,
    String? style,
    Map<String, dynamic>? animation,
    bool? isActive,
    int? priority,
  }) {
    return LiveOverlay(
      id: id ?? this.id,
      streamId: streamId ?? this.streamId,
      type: type ?? this.type,
      content: content ?? this.content,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      style: style ?? this.style,
      animation: animation ?? this.animation,
      isActive: isActive ?? this.isActive,
      priority: priority ?? this.priority,
    );
  }

  // Helper methods for specific overlay types
  bool get isAnnouncement => type == OverlayType.announcement;
  bool get isFeaturedComment => type == OverlayType.featuredComment;
  bool get isFeaturedResponse => type == OverlayType.featuredResponse;
  bool get isReaction => type == OverlayType.reaction;
  bool get isMoment => type == OverlayType.moment;

  // Helper method to check if overlay is expired
  bool isExpired() {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  // Helper method to get duration until expiry
  Duration? timeUntilExpiry() {
    if (expiresAt == null) return null;
    return expiresAt!.difference(DateTime.now());
  }
} 