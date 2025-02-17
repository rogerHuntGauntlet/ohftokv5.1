import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_storage/firebase_storage.dart';
import '../models/user.dart';
import '../services/movie/movie_firestore_service.dart';

class UserService {
  final FirebaseFirestore _firestore;
  final auth.FirebaseAuth _auth;
  final FirebaseStorage _storage;
  final MovieFirestoreService _movieService;

  UserService({
    FirebaseFirestore? firestore,
    auth.FirebaseAuth? authInstance,
    FirebaseStorage? storage,
    MovieFirestoreService? movieService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = authInstance ?? auth.FirebaseAuth.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _movieService = movieService ?? MovieFirestoreService();

  // Get current user profile
  Future<User?> getCurrentUser() async {
    final authUser = _auth.currentUser;
    if (authUser == null) return null;

    final doc = await _firestore.collection('users').doc(authUser.uid).get();
    if (!doc.exists) return null;

    return User.fromFirestore(doc);
  }

  // Update user profile
  Future<User> updateProfile({
    String? displayName,
    String? bio,
    Map<String, dynamic>? preferences,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('No authenticated user');

    final userRef = _firestore.collection('users').doc(userId);
    final updates = {
      if (displayName != null) 'displayName': displayName,
      if (bio != null) 'bio': bio,
      if (preferences != null) 'preferences': preferences,
      'lastUpdated': FieldValue.serverTimestamp(),
    };

    await userRef.update(updates);
    final updatedDoc = await userRef.get();
    return User.fromFirestore(updatedDoc);
  }

  // Upload profile picture
  Future<String> uploadProfilePicture(File imageFile) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('No authenticated user');

    final ref = _storage.ref().child('profile_pictures/$userId.jpg');
    await ref.putFile(imageFile);
    final downloadUrl = await ref.getDownloadURL();

    await _firestore.collection('users').doc(userId).update({
      'photoUrl': downloadUrl,
      'lastUpdated': FieldValue.serverTimestamp(),
    });

    return downloadUrl;
  }

  // Get user's movie statistics
  Future<Map<String, dynamic>> getUserStats() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('No authenticated user');

    final userDoc = await _firestore.collection('users').doc(userId).get();
    final userData = User.fromFirestore(userDoc);
    final movieCounts = await _movieService.getUserMovieCounts(userId);

    return {
      'totalMovies': movieCounts['total'],
      'completedMovies': movieCounts['completed'],
      'inProgressMovies': movieCounts['inProgress'],
      'joinDate': userData.createdAt,
      'followingCount': userData.followingCount,
      'followersCount': userData.followersCount,
    };
  }

  // Delete account
  Future<void> deleteAccount() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('No authenticated user');

    // Delete profile picture if exists
    try {
      await _storage.ref().child('profile_pictures/$userId.jpg').delete();
    } catch (e) {
      // Ignore if no profile picture exists
    }

    // Delete user document
    await _firestore.collection('users').doc(userId).delete();

    // Delete Firebase Auth user
    await _auth.currentUser?.delete();
  }

  // Follow a user
  Future<void> followUser(String targetUserId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) throw Exception('No authenticated user');
    if (currentUserId == targetUserId) throw Exception('Cannot follow yourself');

    final batch = _firestore.batch();
    
    // Add to current user's following list
    final currentUserRef = _firestore.collection('users').doc(currentUserId);
    batch.update(currentUserRef, {
      'following': FieldValue.arrayUnion([targetUserId]),
      'lastUpdated': FieldValue.serverTimestamp(),
    });

    // Add to target user's followers list
    final targetUserRef = _firestore.collection('users').doc(targetUserId);
    batch.update(targetUserRef, {
      'followers': FieldValue.arrayUnion([currentUserId]),
      'lastUpdated': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // Unfollow a user
  Future<void> unfollowUser(String targetUserId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) throw Exception('No authenticated user');

    final batch = _firestore.batch();
    
    // Remove from current user's following list
    final currentUserRef = _firestore.collection('users').doc(currentUserId);
    batch.update(currentUserRef, {
      'following': FieldValue.arrayRemove([targetUserId]),
      'lastUpdated': FieldValue.serverTimestamp(),
    });

    // Remove from target user's followers list
    final targetUserRef = _firestore.collection('users').doc(targetUserId);
    batch.update(targetUserRef, {
      'followers': FieldValue.arrayRemove([currentUserId]),
      'lastUpdated': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // Get user's followers
  Future<List<User>> getFollowers(String userId) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    if (!userDoc.exists) throw Exception('User not found');

    final user = User.fromFirestore(userDoc);
    final followers = await Future.wait(
      user.followers.map((followerId) async {
        final followerDoc = await _firestore.collection('users').doc(followerId).get();
        return User.fromFirestore(followerDoc);
      }),
    );

    return followers;
  }

  // Get user's following
  Future<List<User>> getFollowing(String userId) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    if (!userDoc.exists) throw Exception('User not found');

    final user = User.fromFirestore(userDoc);
    final following = await Future.wait(
      user.following.map((followingId) async {
        final followingDoc = await _firestore.collection('users').doc(followingId).get();
        return User.fromFirestore(followingDoc);
      }),
    );

    return following;
  }

  // Get a user by ID
  Future<User?> getUserById(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) return null;
    return User.fromFirestore(doc);
  }

  // Search users
  Future<List<User>> searchUsers(String query, {int limit = 20}) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) throw Exception('No authenticated user');

    final querySnapshot = await _firestore
        .collection('users')
        .where('displayName', isGreaterThanOrEqualTo: query)
        .where('displayName', isLessThanOrEqualTo: query + '\uf8ff')
        .limit(limit)
        .get();

    return querySnapshot.docs
        .map((doc) => User.fromFirestore(doc))
        .where((user) => user.id != currentUserId)
        .toList();
  }
} 