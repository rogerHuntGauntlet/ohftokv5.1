import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'achievement_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AchievementService _achievementService;

  AuthService({AchievementService? achievementService}) 
      : _achievementService = achievementService ?? AchievementService();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign up with email and password
  Future<UserCredential> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      print('[AuthService] Starting sign up process for email: $email');
      
      // Configure action code settings
      final actionCodeSettings = ActionCodeSettings(
        url: 'https://ohftok5.page.link/verify',
        handleCodeInApp: true,
        androidPackageName: 'ohftok5.flutter.app',
        androidInstallApp: true,
        androidMinimumVersion: '12',
      );

      // Create user with email and password
      print('[AuthService] Creating user account');
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      print('[AuthService] User created successfully with ID: ${credential.user?.uid}');

      // Send email verification
      try {
        await credential.user?.sendEmailVerification(actionCodeSettings);
        print('[AuthService] Verification email sent');
      } catch (e) {
        print('[AuthService] Error sending verification email: $e');
      }

      // Create user profile in Firestore
      try {
        print('[AuthService] Creating user profile in Firestore');
        await _firestore.collection('users').doc(credential.user!.uid).set({
          'username': username,
          'email': email,
          'role': 'user',
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
          'hasCompletedOnboarding': false,
          'profileCompletion': 0,
          'tokens': 0,
          'emailVerified': false,
        });
        print('[AuthService] User profile created successfully');
      } catch (e) {
        print('[AuthService] Error creating user profile: $e');
        // If Firestore fails, delete the auth user to maintain consistency
        await credential.user?.delete();
        throw 'Failed to create user profile. Please try again.';
      }

      // Initialize achievements
      try {
        print('[AuthService] Initializing achievements');
        await _achievementService.initializeAchievements(credential.user!.uid);
        await _achievementService.unlockAchievement(credential.user!.uid, 'welcome');
        print('[AuthService] Achievements initialized successfully');
      } catch (e) {
        print('[AuthService] Error initializing achievements: $e');
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      print('[AuthService] FirebaseAuthException during sign up: ${e.code} - ${e.message}');
      if (e.code == 'weak-password') {
        throw 'The password provided is too weak.';
      } else if (e.code == 'email-already-in-use') {
        throw 'The account already exists for that email.';
      } else {
        throw e.message ?? 'An error occurred during sign up.';
      }
    } catch (e) {
      print('[AuthService] Unexpected error during sign up: $e');
      throw 'An unexpected error occurred.';
    }
  }

  // Sign in with email and password
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    try {
      print('[AuthService] Attempting sign in for email: $email');
      
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      print('[AuthService] Sign in successful, user ID: ${credential.user?.uid}');

      // Update last login timestamp
      try {
        print('[AuthService] Updating last login timestamp');
        await _firestore.collection('users').doc(credential.user!.uid).update({
          'lastLogin': FieldValue.serverTimestamp(),
        });
        print('[AuthService] Last login timestamp updated');
      } catch (e) {
        print('[AuthService] Error updating last login: $e');
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      print('[AuthService] FirebaseAuthException during sign in: ${e.code} - ${e.message}');
      if (e.code == 'user-not-found') {
        throw 'No user found for that email.';
      } else if (e.code == 'wrong-password') {
        throw 'Wrong password provided.';
      } else {
        throw e.message ?? 'An error occurred during sign in.';
      }
    } catch (e) {
      print('[AuthService] Sign in error: $e');
      print('[AuthService] Error stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Password reset
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // Get user role
  Future<String> getUserRole(String uid) async {
    DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
    return doc.get('role') as String;
  }

  // Check if user has completed onboarding
  Future<bool> hasCompletedOnboarding(String uid) async {
    DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
    return doc.get('hasCompletedOnboarding') as bool? ?? false;
  }

  // Update user profile
  Future<void> updateProfile({
    required String uid,
    String? username,
    String? email,
    bool? hasCompletedOnboarding,
    List<String>? interests,
  }) async {
    final updates = <String, dynamic>{};
    
    if (username != null) updates['username'] = username;
    if (email != null) {
      updates['email'] = email;
      await currentUser?.updateEmail(email);
    }
    if (hasCompletedOnboarding != null) {
      updates['hasCompletedOnboarding'] = hasCompletedOnboarding;
    }
    if (interests != null) {
      updates['interests'] = interests;
    }

    // Calculate profile completion percentage
    if (updates.isNotEmpty) {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      Map<String, dynamic> userData = doc.data() as Map<String, dynamic>;
      
      int completedFields = 0;
      int totalFields = 5; // username, email, avatar, bio, interests
      
      if (userData['username'] != null) completedFields++;
      if (userData['email'] != null) completedFields++;
      if (userData['avatar'] != null) completedFields++;
      if (userData['bio'] != null) completedFields++;
      if (userData['interests'] != null && 
          (userData['interests'] as List).isNotEmpty) completedFields++;
      
      updates['profileCompletion'] = (completedFields / totalFields * 100).round();
      
      await _firestore.collection('users').doc(uid).update(updates);
    }
  }

  // Get user profile completion
  Future<int> getProfileCompletion(String uid) async {
    DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
    return (doc.get('profileCompletion') as num?)?.round() ?? 0;
  }

  // Get user interests
  Future<List<String>> getUserInterests(String uid) async {
    DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
    List<dynamic>? interests = doc.get('interests') as List<dynamic>?;
    return interests?.map((e) => e.toString()).toList() ?? [];
  }

  // Update user interests
  Future<void> updateInterests(String uid, List<String> interests) async {
    await updateProfile(
      uid: uid,
      interests: interests,
    );
  }
} 