import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/activity.dart';
import '../models/user.dart';

class ActivityAggregatorService {
  final FirebaseFirestore _firestore;
  
  ActivityAggregatorService({FirebaseFirestore? firestore}) 
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Groups similar activities together and creates a summary
  Future<List<AggregatedActivity>> aggregateActivities(List<Activity> activities) async {
    if (activities.isEmpty) return [];

    // Sort activities by timestamp in descending order
    activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    final List<AggregatedActivity> aggregatedActivities = [];
    Map<String, List<Activity>> groupedActivities = {};

    // Group activities by type and target
    for (final activity in activities) {
      final String key = _createGroupKey(activity);
      groupedActivities.putIfAbsent(key, () => []).add(activity);
    }

    // Create aggregated activities from groups
    for (final entry in groupedActivities.entries) {
      final activities = entry.value;
      if (activities.length > 1) {
        // Create an aggregated activity for multiple similar activities
        aggregatedActivities.add(
          AggregatedActivity(
            activities: activities,
            type: activities.first.type,
            timestamp: activities.first.timestamp,
            summary: _createSummary(activities),
          ),
        );
      } else {
        // Single activities don't need aggregation
        aggregatedActivities.add(
          AggregatedActivity(
            activities: activities,
            type: activities.first.type,
            timestamp: activities.first.timestamp,
            summary: null,
          ),
        );
      }
    }

    // Sort aggregated activities by most recent timestamp
    aggregatedActivities.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    return aggregatedActivities;
  }

  String _createGroupKey(Activity activity) {
    switch (activity.type) {
      case ActivityType.like:
      case ActivityType.comment:
        // Group by target movie and type
        return '${activity.type}_${activity.relatedMovie?.id ?? ''}_${DateTime.now().difference(activity.timestamp).inHours}';
      case ActivityType.follow:
        // Group follow activities by target user within a time window
        return '${activity.type}_${activity.targetUser?.id ?? ''}_${DateTime.now().difference(activity.timestamp).inHours}';
      case ActivityType.createMovie:
        // Don't group movie creation activities
        return '${activity.type}_${activity.id}';
      default:
        return activity.id;
    }
  }

  String _createSummary(List<Activity> activities) {
    if (activities.isEmpty) return '';

    final activity = activities.first;
    final count = activities.length;
    final usernames = activities
        .map((a) => a.user.username)
        .take(2)
        .join(', ');
    final remainingCount = count - 2;

    switch (activity.type) {
      case ActivityType.like:
        final movieTitle = activity.relatedMovie?.title ?? 'a movie';
        if (count > 2) {
          return '$usernames and $remainingCount others liked $movieTitle';
        } else {
          return '$usernames liked $movieTitle';
        }
      case ActivityType.comment:
        final movieTitle = activity.relatedMovie?.title ?? 'a movie';
        if (count > 2) {
          return '$usernames and $remainingCount others commented on $movieTitle';
        } else {
          return '$usernames commented on $movieTitle';
        }
      case ActivityType.follow:
        final targetUsername = activity.targetUser?.username ?? 'someone';
        if (count > 2) {
          return '$usernames and $remainingCount others started following $targetUsername';
        } else {
          return '$usernames started following $targetUsername';
        }
      default:
        return '';
    }
  }
}

class AggregatedActivity {
  final List<Activity> activities;
  final ActivityType type;
  final DateTime timestamp;
  final String? summary;

  const AggregatedActivity({
    required this.activities,
    required this.type,
    required this.timestamp,
    this.summary,
  });

  Activity get primaryActivity => activities.first;
  
  bool get isAggregated => activities.length > 1;
  
  int get count => activities.length;
} 