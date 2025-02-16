import 'package:cloud_firestore/cloud_firestore.dart';

class Achievement {
  final String id;
  final String title;
  final String description;
  final String icon;
  final int tokenReward;
  final bool isUnlocked;
  final DateTime? unlockedAt;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.tokenReward,
    this.isUnlocked = false,
    this.unlockedAt,
  });

  factory Achievement.fromMap(Map<String, dynamic> map) {
    return Achievement(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      icon: map['icon'],
      tokenReward: map['tokenReward'],
      isUnlocked: map['isUnlocked'] ?? false,
      unlockedAt: map['unlockedAt']?.toDate(),
    );
  }
}

class AchievementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Available achievements
  static const Map<String, Map<String, dynamic>> _achievements = {
    'welcome': {
      'title': 'Welcome Aboard!',
      'description': 'Complete the onboarding process',
      'icon': '🎉',
      'tokenReward': 50,
    },
    'profile_complete': {
      'title': 'Profile Master',
      'description': 'Complete your profile 100%',
      'icon': '👤',
      'tokenReward': 100,
    },
    'first_video': {
      'title': 'Content Creator',
      'description': 'Upload your first video',
      'icon': '🎥',
      'tokenReward': 150,
    },
    'social_butterfly': {
      'title': 'Social Butterfly',
      'description': 'Follow 10 creators',
      'icon': '🦋',
      'tokenReward': 200,
    },
    'trending': {
      'title': 'Trending Star',
      'description': 'Get a video in trending',
      'icon': '⭐',
      'tokenReward': 500,
    },
  };

  // Initialize achievements for new user
  Future<void> initializeAchievements(String uid) async {
    final batch = _firestore.batch();
    final achievementsRef = _firestore.collection('users').doc(uid).collection('achievements');

    _achievements.forEach((id, data) {
      batch.set(achievementsRef.doc(id), {
        'id': id,
        ...data,
        'isUnlocked': false,
        'unlockedAt': null,
      });
    });

    await batch.commit();
  }

  // Get user achievements
  Stream<List<Achievement>> getUserAchievements(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('achievements')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Achievement.fromMap(doc.data()))
            .toList());
  }

  // Unlock achievement
  Future<void> unlockAchievement(String uid, String achievementId) async {
    final userRef = _firestore.collection('users').doc(uid);
    final achievementRef = userRef.collection('achievements').doc(achievementId);

    await _firestore.runTransaction((transaction) async {
      final achievementDoc = await transaction.get(achievementRef);
      
      if (!achievementDoc.get('isUnlocked')) {
        // Update achievement
        transaction.update(achievementRef, {
          'isUnlocked': true,
          'unlockedAt': FieldValue.serverTimestamp(),
        });

        // Add tokens to user
        final tokenReward = achievementDoc.get('tokenReward') as int;
        transaction.update(userRef, {
          'tokens': FieldValue.increment(tokenReward),
        });

        // Create notification
        final notificationRef = _firestore.collection('notifications').doc();
        transaction.set(notificationRef, {
          'userId': uid,
          'type': 'achievement',
          'title': 'Achievement Unlocked!',
          'body': 'You\'ve earned the "${achievementDoc.get('title')}" achievement and ${tokenReward} tokens!',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  // Check and update achievements based on user actions
  Future<void> checkAchievements(String uid) async {
    final userDoc = await _firestore.collection('users').doc(uid).get();
    final userData = userDoc.data() as Map<String, dynamic>;

    // Check profile completion
    if (userData['profileCompletion'] == 100) {
      await unlockAchievement(uid, 'profile_complete');
    }

    // Check following count
    if ((userData['following'] as List?)?.length == 10) {
      await unlockAchievement(uid, 'social_butterfly');
    }

    // Add more achievement checks based on user actions
  }
} 