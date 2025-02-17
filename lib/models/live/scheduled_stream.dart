import 'package:cloud_firestore/cloud_firestore.dart';

enum StreamRecurrence {
  none,
  daily,
  weekly,
  biweekly,
  monthly,
}

class ScheduledStream {
  final String id;
  final String hostId;
  final String hostDisplayName;
  final String? hostProfileImage;
  final String title;
  final String? description;
  final DateTime scheduledStart;
  final Duration duration;
  final StreamRecurrence recurrence;
  final Map<String, dynamic>? recurrenceMetadata;
  final List<String> subscriberIds;
  final Map<String, dynamic>? settings;
  final String? thumbnailUrl;
  final List<String> tags;
  final bool isPublic;
  final DateTime createdAt;
  final DateTime? lastModifiedAt;
  final bool isCancelled;
  final String? cancellationReason;

  ScheduledStream({
    required this.id,
    required this.hostId,
    required this.hostDisplayName,
    this.hostProfileImage,
    required this.title,
    this.description,
    required this.scheduledStart,
    required this.duration,
    required this.recurrence,
    this.recurrenceMetadata,
    required this.subscriberIds,
    this.settings,
    this.thumbnailUrl,
    required this.tags,
    required this.isPublic,
    required this.createdAt,
    this.lastModifiedAt,
    required this.isCancelled,
    this.cancellationReason,
  });

  factory ScheduledStream.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ScheduledStream(
      id: doc.id,
      hostId: data['hostId'] as String,
      hostDisplayName: data['hostDisplayName'] as String,
      hostProfileImage: data['hostProfileImage'] as String?,
      title: data['title'] as String,
      description: data['description'] as String?,
      scheduledStart: (data['scheduledStart'] as Timestamp).toDate(),
      duration: Duration(minutes: data['durationMinutes'] as int),
      recurrence: StreamRecurrence.values.firstWhere(
        (e) => e.toString() == 'StreamRecurrence.${data['recurrence']}',
      ),
      recurrenceMetadata: data['recurrenceMetadata'] as Map<String, dynamic>?,
      subscriberIds: List<String>.from(data['subscriberIds'] ?? []),
      settings: data['settings'] as Map<String, dynamic>?,
      thumbnailUrl: data['thumbnailUrl'] as String?,
      tags: List<String>.from(data['tags'] ?? []),
      isPublic: data['isPublic'] as bool,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastModifiedAt: data['lastModifiedAt'] != null
          ? (data['lastModifiedAt'] as Timestamp).toDate()
          : null,
      isCancelled: data['isCancelled'] as bool,
      cancellationReason: data['cancellationReason'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'hostId': hostId,
      'hostDisplayName': hostDisplayName,
      'hostProfileImage': hostProfileImage,
      'title': title,
      'description': description,
      'scheduledStart': Timestamp.fromDate(scheduledStart),
      'durationMinutes': duration.inMinutes,
      'recurrence': recurrence.toString().split('.').last,
      'recurrenceMetadata': recurrenceMetadata,
      'subscriberIds': subscriberIds,
      'settings': settings,
      'thumbnailUrl': thumbnailUrl,
      'tags': tags,
      'isPublic': isPublic,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastModifiedAt':
          lastModifiedAt != null ? Timestamp.fromDate(lastModifiedAt!) : null,
      'isCancelled': isCancelled,
      'cancellationReason': cancellationReason,
    };
  }

  ScheduledStream copyWith({
    String? id,
    String? hostId,
    String? hostDisplayName,
    String? hostProfileImage,
    String? title,
    String? description,
    DateTime? scheduledStart,
    Duration? duration,
    StreamRecurrence? recurrence,
    Map<String, dynamic>? recurrenceMetadata,
    List<String>? subscriberIds,
    Map<String, dynamic>? settings,
    String? thumbnailUrl,
    List<String>? tags,
    bool? isPublic,
    DateTime? createdAt,
    DateTime? lastModifiedAt,
    bool? isCancelled,
    String? cancellationReason,
  }) {
    return ScheduledStream(
      id: id ?? this.id,
      hostId: hostId ?? this.hostId,
      hostDisplayName: hostDisplayName ?? this.hostDisplayName,
      hostProfileImage: hostProfileImage ?? this.hostProfileImage,
      title: title ?? this.title,
      description: description ?? this.description,
      scheduledStart: scheduledStart ?? this.scheduledStart,
      duration: duration ?? this.duration,
      recurrence: recurrence ?? this.recurrence,
      recurrenceMetadata: recurrenceMetadata ?? this.recurrenceMetadata,
      subscriberIds: subscriberIds ?? this.subscriberIds,
      settings: settings ?? this.settings,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      tags: tags ?? this.tags,
      isPublic: isPublic ?? this.isPublic,
      createdAt: createdAt ?? this.createdAt,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      isCancelled: isCancelled ?? this.isCancelled,
      cancellationReason: cancellationReason ?? this.cancellationReason,
    );
  }

  // Helper methods
  bool get isRecurring => recurrence != StreamRecurrence.none;
  
  bool get isUpcoming => scheduledStart.isAfter(DateTime.now());
  
  bool get isLive => !isCancelled &&
      scheduledStart.isBefore(DateTime.now()) &&
      scheduledStart.add(duration).isAfter(DateTime.now());
  
  bool get isCompleted => !isCancelled &&
      scheduledStart.add(duration).isBefore(DateTime.now());

  DateTime getNextOccurrence() {
    if (!isRecurring || isCancelled) return scheduledStart;

    final now = DateTime.now();
    var nextDate = scheduledStart;

    while (nextDate.isBefore(now)) {
      switch (recurrence) {
        case StreamRecurrence.daily:
          nextDate = nextDate.add(const Duration(days: 1));
          break;
        case StreamRecurrence.weekly:
          nextDate = nextDate.add(const Duration(days: 7));
          break;
        case StreamRecurrence.biweekly:
          nextDate = nextDate.add(const Duration(days: 14));
          break;
        case StreamRecurrence.monthly:
          nextDate = DateTime(
            nextDate.year,
            nextDate.month + 1,
            nextDate.day,
            nextDate.hour,
            nextDate.minute,
          );
          break;
        case StreamRecurrence.none:
          return scheduledStart;
      }
    }

    return nextDate;
  }

  List<DateTime> getNextOccurrences(int count) {
    if (!isRecurring || isCancelled) return [scheduledStart];

    final occurrences = <DateTime>[];
    var nextDate = getNextOccurrence();

    for (var i = 0; i < count; i++) {
      occurrences.add(nextDate);

      switch (recurrence) {
        case StreamRecurrence.daily:
          nextDate = nextDate.add(const Duration(days: 1));
          break;
        case StreamRecurrence.weekly:
          nextDate = nextDate.add(const Duration(days: 7));
          break;
        case StreamRecurrence.biweekly:
          nextDate = nextDate.add(const Duration(days: 14));
          break;
        case StreamRecurrence.monthly:
          nextDate = DateTime(
            nextDate.year,
            nextDate.month + 1,
            nextDate.day,
            nextDate.hour,
            nextDate.minute,
          );
          break;
        case StreamRecurrence.none:
          return occurrences;
      }
    }

    return occurrences;
  }
} 