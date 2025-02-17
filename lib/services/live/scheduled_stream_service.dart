import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../models/live/scheduled_stream.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class ScheduledStreamService {
  final FirebaseFirestore _firestore;
  final String _collection = 'scheduled_streams';
  final DeviceCalendarPlugin _calendarPlugin;
  final FlutterLocalNotificationsPlugin _notificationsPlugin;

  ScheduledStreamService({
    FirebaseFirestore? firestore,
    DeviceCalendarPlugin? calendarPlugin,
    FlutterLocalNotificationsPlugin? notificationsPlugin,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _calendarPlugin = calendarPlugin ?? DeviceCalendarPlugin(),
        _notificationsPlugin = notificationsPlugin ?? FlutterLocalNotificationsPlugin() {
    tz.initializeTimeZones();
  }

  Future<void> initialize() async {
    // Initialize notifications
    const initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettingsIOS = DarwinInitializationSettings();
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    await _notificationsPlugin.initialize(initializationSettings);
  }

  // CRUD operations
  Future<String> createScheduledStream({
    required String hostId,
    required String hostDisplayName,
    String? hostProfileImage,
    required String title,
    String? description,
    required DateTime scheduledStart,
    required Duration duration,
    required StreamRecurrence recurrence,
    Map<String, dynamic>? recurrenceMetadata,
    Map<String, dynamic>? settings,
    String? thumbnailUrl,
    List<String> tags = const [],
    bool isPublic = true,
  }) async {
    final stream = {
      'hostId': hostId,
      'hostDisplayName': hostDisplayName,
      'hostProfileImage': hostProfileImage,
      'title': title,
      'description': description,
      'scheduledStart': Timestamp.fromDate(scheduledStart),
      'durationMinutes': duration.inMinutes,
      'recurrence': recurrence.toString().split('.').last,
      'recurrenceMetadata': recurrenceMetadata,
      'subscriberIds': [],
      'settings': settings,
      'thumbnailUrl': thumbnailUrl,
      'tags': tags,
      'isPublic': isPublic,
      'createdAt': FieldValue.serverTimestamp(),
      'isCancelled': false,
    };

    final doc = await _firestore.collection(_collection).add(stream);
    await _scheduleNotifications(doc.id, title, scheduledStart);
    await _createCalendarEvent(title, description ?? '', scheduledStart, duration);
    return doc.id;
  }

  Future<void> updateScheduledStream({
    required String streamId,
    String? title,
    String? description,
    DateTime? scheduledStart,
    Duration? duration,
    StreamRecurrence? recurrence,
    Map<String, dynamic>? recurrenceMetadata,
    Map<String, dynamic>? settings,
    String? thumbnailUrl,
    List<String>? tags,
    bool? isPublic,
  }) async {
    final updates = <String, dynamic>{
      'lastModifiedAt': FieldValue.serverTimestamp(),
    };

    if (title != null) updates['title'] = title;
    if (description != null) updates['description'] = description;
    if (scheduledStart != null) {
      updates['scheduledStart'] = Timestamp.fromDate(scheduledStart);
    }
    if (duration != null) updates['durationMinutes'] = duration.inMinutes;
    if (recurrence != null) {
      updates['recurrence'] = recurrence.toString().split('.').last;
    }
    if (recurrenceMetadata != null) {
      updates['recurrenceMetadata'] = recurrenceMetadata;
    }
    if (settings != null) updates['settings'] = settings;
    if (thumbnailUrl != null) updates['thumbnailUrl'] = thumbnailUrl;
    if (tags != null) updates['tags'] = tags;
    if (isPublic != null) updates['isPublic'] = isPublic;

    await _firestore.collection(_collection).doc(streamId).update(updates);

    // Update notifications and calendar if schedule changed
    if (scheduledStart != null || title != null) {
      final stream = await getScheduledStream(streamId);
      if (stream != null) {
        await _updateNotifications(
          streamId,
          stream.title,
          stream.scheduledStart,
        );
        await _updateCalendarEvent(
          stream.title,
          stream.description ?? '',
          stream.scheduledStart,
          stream.duration,
        );
      }
    }
  }

  Future<void> cancelScheduledStream({
    required String streamId,
    required String reason,
  }) async {
    await _firestore.collection(_collection).doc(streamId).update({
      'isCancelled': true,
      'cancellationReason': reason,
      'lastModifiedAt': FieldValue.serverTimestamp(),
    });

    // Cancel notifications
    await _cancelNotifications(streamId);
    
    // Update calendar event
    final stream = await getScheduledStream(streamId);
    if (stream != null) {
      await _updateCalendarEvent(
        '(CANCELLED) ${stream.title}',
        '${stream.description ?? ''}\n\nCANCELLED: $reason',
        stream.scheduledStart,
        stream.duration,
      );
    }
  }

  Future<void> deleteScheduledStream(String streamId) async {
    await _firestore.collection(_collection).doc(streamId).delete();
    await _cancelNotifications(streamId);
    // Remove calendar event
    final stream = await getScheduledStream(streamId);
    if (stream != null) {
      await _removeFromCalendar(stream.title);
    }
  }

  // Query methods
  Future<ScheduledStream?> getScheduledStream(String streamId) async {
    final doc = await _firestore.collection(_collection).doc(streamId).get();
    if (!doc.exists) return null;
    return ScheduledStream.fromFirestore(doc);
  }

  Stream<List<ScheduledStream>> getUpcomingStreams() {
    final now = DateTime.now();
    return _firestore
        .collection(_collection)
        .where('scheduledStart', isGreaterThan: Timestamp.fromDate(now))
        .where('isCancelled', isEqualTo: false)
        .orderBy('scheduledStart')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => ScheduledStream.fromFirestore(doc)).toList();
        });
  }

  Stream<List<ScheduledStream>> getUserScheduledStreams(String userId) {
    return _firestore
        .collection(_collection)
        .where('hostId', isEqualTo: userId)
        .orderBy('scheduledStart', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => ScheduledStream.fromFirestore(doc)).toList();
        });
  }

  Stream<List<ScheduledStream>> getSubscribedStreams(String userId) {
    return _firestore
        .collection(_collection)
        .where('subscriberIds', arrayContains: userId)
        .orderBy('scheduledStart')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => ScheduledStream.fromFirestore(doc)).toList();
        });
  }

  // Subscription methods
  Future<void> subscribeToStream({
    required String streamId,
    required String userId,
  }) async {
    await _firestore.collection(_collection).doc(streamId).update({
      'subscriberIds': FieldValue.arrayUnion([userId]),
    });

    final stream = await getScheduledStream(streamId);
    if (stream != null) {
      await _scheduleNotifications(streamId, stream.title, stream.scheduledStart);
      await _createCalendarEvent(
        stream.title,
        stream.description ?? '',
        stream.scheduledStart,
        stream.duration,
      );
    }
  }

  Future<void> unsubscribeFromStream({
    required String streamId,
    required String userId,
  }) async {
    await _firestore.collection(_collection).doc(streamId).update({
      'subscriberIds': FieldValue.arrayRemove([userId]),
    });

    await _cancelNotifications(streamId);
    final stream = await getScheduledStream(streamId);
    if (stream != null) {
      await _removeFromCalendar(stream.title);
    }
  }

  // Notification methods
  Future<void> _scheduleNotifications(
    String streamId,
    String title,
    DateTime scheduledStart,
  ) async {
    final notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'scheduled_streams',
        'Scheduled Streams',
        channelDescription: 'Notifications for scheduled live streams',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );

    // Schedule notification 15 minutes before
    final fifteenMinBefore = tz.TZDateTime.from(
      scheduledStart.subtract(const Duration(minutes: 15)),
      tz.local,
    );

    if (fifteenMinBefore.isAfter(DateTime.now())) {
      await _notificationsPlugin.zonedSchedule(
        int.parse('${streamId.hashCode}1'),
        'Stream Starting Soon',
        'The stream "$title" will begin in 15 minutes',
        fifteenMinBefore,
        notificationDetails,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }

    // Schedule notification at start time
    final startTime = tz.TZDateTime.from(scheduledStart, tz.local);
    if (startTime.isAfter(DateTime.now())) {
      await _notificationsPlugin.zonedSchedule(
        int.parse('${streamId.hashCode}2'),
        'Stream Starting Now',
        'The stream "$title" is starting now',
        startTime,
        notificationDetails,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> _updateNotifications(
    String streamId,
    String title,
    DateTime scheduledStart,
  ) async {
    await _cancelNotifications(streamId);
    await _scheduleNotifications(streamId, title, scheduledStart);
  }

  Future<void> _cancelNotifications(String streamId) async {
    // Cancel all notifications related to this stream
    final notifications = [
      const Duration(days: 1),
      const Duration(hours: 1),
      const Duration(minutes: 5),
    ];

    for (final notification in notifications) {
      await _notificationsPlugin.cancel(
        int.parse('${streamId.hashCode}${notification.inMinutes}'),
      );
    }
  }

  // Calendar methods
  Future<void> _createCalendarEvent(
    String title,
    String description,
    DateTime start,
    Duration duration,
  ) async {
    final calendarsResult = await _calendarPlugin.retrieveCalendars();
    final calendars = calendarsResult.data;
    
    if (calendars == null || calendars.isEmpty) return;
    
    final calendar = calendars.firstWhere(
      (cal) => cal.isReadOnly == false,
      orElse: () => calendars.first,
    );

    final location = tz.local;
    final tzStart = tz.TZDateTime.from(start, location);
    final tzEnd = tz.TZDateTime.from(start.add(duration), location);

    final event = Event(
      calendar.id,
      title: title,
      description: description,
      start: tzStart,
      end: tzEnd,
    );

    await _calendarPlugin.createOrUpdateEvent(event);
  }

  Future<void> _updateCalendarEvent(
    String title,
    String description,
    DateTime start,
    Duration duration,
  ) async {
    final calendarsResult = await _calendarPlugin.retrieveCalendars();
    final calendars = calendarsResult.data;
    
    if (calendars == null || calendars.isEmpty) return;

    final calendar = calendars.firstWhere(
      (cal) => cal.isReadOnly == false,
      orElse: () => calendars.first,
    );

    final eventsResult = await _calendarPlugin.retrieveEvents(
      calendar.id,
      RetrieveEventsParams(
        startDate: DateTime.now().subtract(const Duration(days: 30)),
        endDate: DateTime.now().add(const Duration(days: 365)),
      ),
    );

    final events = eventsResult.data;
    if (events == null || events.isEmpty) return;

    final existingEvent = events.firstWhere(
      (e) => e.title?.contains(title.replaceAll('(CANCELLED) ', '')) ?? false,
      orElse: () => Event(
        calendar.id,
        title: title,
        description: description,
        start: tz.TZDateTime.from(start, tz.local),
        end: tz.TZDateTime.from(start.add(duration), tz.local),
      ),
    );

    existingEvent.title = title;
    existingEvent.description = description;
    existingEvent.start = tz.TZDateTime.from(start, tz.local);
    existingEvent.end = tz.TZDateTime.from(start.add(duration), tz.local);

    await _calendarPlugin.createOrUpdateEvent(existingEvent);
  }

  Future<void> _removeFromCalendar(String title) async {
    final calendarsResult = await _calendarPlugin.retrieveCalendars();
    final calendars = calendarsResult.data;
    
    if (calendars == null || calendars.isEmpty) return;

    final calendar = calendars.firstWhere(
      (cal) => cal.isReadOnly == false,
      orElse: () => calendars.first,
    );

    final eventsResult = await _calendarPlugin.retrieveEvents(
      calendar.id,
      RetrieveEventsParams(
        startDate: DateTime.now().subtract(const Duration(days: 30)),
        endDate: DateTime.now().add(const Duration(days: 365)),
      ),
    );

    final events = eventsResult.data;
    if (events == null) return;

    final event = events.firstWhere(
      (e) => e.title?.contains(title.replaceAll('(CANCELLED) ', '')) ?? false,
      orElse: () => Event(
        calendar.id,
        title: title,
        description: '',
        start: tz.TZDateTime.now(tz.local),
        end: tz.TZDateTime.now(tz.local).add(const Duration(hours: 1)),
      ),
    );

    if (event.eventId != null) {
      await _calendarPlugin.deleteEvent(calendar.id, event.eventId!);
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) return '${duration.inDays} day(s)';
    if (duration.inHours > 0) return '${duration.inHours} hour(s)';
    if (duration.inMinutes > 0) return '${duration.inMinutes} minute(s)';
    return 'less than a minute';
  }
} 