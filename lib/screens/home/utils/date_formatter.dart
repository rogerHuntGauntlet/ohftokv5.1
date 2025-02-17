import 'package:intl/intl.dart';

/// Utility class for formatting dates and timestamps consistently across the app.
class DateFormatter {
  /// Format a timestamp into a human-readable string
  static String formatTimestamp(DateTime timestamp) {
    // TODO: Implement timestamp formatting
    return DateFormat.yMMMd().add_jm().format(timestamp);
  }

  /// Format a duration into a human-readable string
  static String formatDuration(Duration duration) {
    // TODO: Implement duration formatting
    return '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
  }
} 