class AppConstants {
  // API Endpoints
  static const String baseUrl = 'https://api.ohftok.com';
  static const String apiVersion = 'v1';

  // Firebase Collections
  static const String usersCollection = 'users';
  static const String videosCollection = 'videos';
  static const String achievementsCollection = 'achievements';
  static const String notificationsCollection = 'notifications';

  // Storage Paths
  static const String videoStoragePath = 'videos';
  static const String thumbnailStoragePath = 'thumbnails';
  static const String profileImagePath = 'profile_images';

  // Cache Configuration
  static const int maxCachedVideos = 10;
  static const Duration videoCacheDuration = Duration(days: 1);
  static const Duration profileCacheDuration = Duration(hours: 1);

  // UI Constants
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const double borderRadius = 12.0;
  static const double buttonHeight = 48.0;

  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 350);
  static const Duration longAnimation = Duration(milliseconds: 500);

  // Video Configuration
  static const Duration maxVideoDuration = Duration(minutes: 3);
  static const int maxVideoSize = 100 * 1024 * 1024; // 100MB
  static const List<String> supportedVideoFormats = ['mp4', 'mov', 'avi'];

  // Achievement Thresholds
  static const int followersForBronze = 100;
  static const int followersForSilver = 1000;
  static const int followersForGold = 10000;
  static const int viewsForTrending = 1000;
  static const int likesForPopular = 500;

  // Error Messages
  static const String networkError = 'Network connection error. Please try again.';
  static const String unknownError = 'An unknown error occurred. Please try again.';
  static const String authError = 'Authentication failed. Please try again.';
  static const String uploadError = 'Failed to upload video. Please try again.';

  // Success Messages
  static const String profileUpdateSuccess = 'Profile updated successfully!';
  static const String videoUploadSuccess = 'Video uploaded successfully!';
  static const String achievementUnlocked = 'New achievement unlocked!';
} 