import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_storage/firebase_storage.dart';
import '../models/user.dart';

class UserService {
  final FirebaseFirestore _firestore;
  final auth.FirebaseAuth _auth;
  final FirebaseStorage _storage;

  UserService({
    FirebaseFirestore? firestore,
    auth.FirebaseAuth? authInstance,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = authInstance ?? auth.FirebaseAuth.instance,
        _storage = storage ?? FirebaseStorage.instance;

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

    final moviesQuery = await _firestore
        .collection('movies')
        .where('userId', isEqualTo: userId)
        .get();

    return {
      'totalMovies': userData.totalMoviesCreated,
      'completedMovies': moviesQuery.docs.where((doc) => doc.data()['status'] == 'completed').length,
      'inProgressMovies': moviesQuery.docs.where((doc) => doc.data()['status'] == 'in_progress').length,
      'joinDate': userData.createdAt,
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
} 