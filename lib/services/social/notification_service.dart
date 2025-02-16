import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // Initialize notifications
  Future<void> initialize() async {
    // Request permission for notifications
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // Get FCM token
      String? token = await _messaging.getToken();
      if (token != null) {
        print('FCM Token: $token');
      }
    }
  }

  // Send welcome notification
  Future<void> sendWelcomeNotification(String uid, String username) async {
    await _firestore.collection('notifications').add({
      'userId': uid,
      'type': 'welcome',
      'title': 'Welcome to OHFtok!',
      'body': 'Hey $username! Welcome to the community. Start exploring and sharing your creativity!',
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Get user notifications
  Stream<QuerySnapshot> getUserNotifications(String uid) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    await _firestore
        .collection('notifications')
        .doc(notificationId)
        .update({'read': true});
  }

  // Save FCM token
  Future<void> saveFCMToken(String uid, String token) async {
    await _firestore.collection('users').doc(uid).update({
      'fcmTokens': FieldValue.arrayUnion([token]),
    });
  }

  // Remove FCM token
  Future<void> removeFCMToken(String uid, String token) async {
    await _firestore.collection('users').doc(uid).update({
      'fcmTokens': FieldValue.arrayRemove([token]),
    });
  }
} 