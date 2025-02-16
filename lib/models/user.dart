import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  final String id;
  final String email;
  final String displayName;
  String? photoUrl;
  String? bio;
  DateTime createdAt;
  DateTime lastUpdated;
  Map<String, dynamic>? preferences;
  List<String> movieIds;
  int totalMoviesCreated;
  
  User({
    required this.id,
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.bio,
    DateTime? createdAt,
    DateTime? lastUpdated,
    this.preferences,
    List<String>? movieIds,
    this.totalMoviesCreated = 0,
  }) : 
    this.createdAt = createdAt ?? DateTime.now(),
    this.lastUpdated = lastUpdated ?? DateTime.now(),
    this.movieIds = movieIds ?? [];

  factory User.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return User(
      id: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? '',
      photoUrl: data['photoUrl'],
      bio: data['bio'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastUpdated: (data['lastUpdated'] as Timestamp).toDate(),
      preferences: data['preferences'],
      movieIds: List<String>.from(data['movieIds'] ?? []),
      totalMoviesCreated: data['totalMoviesCreated'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'bio': bio,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastUpdated': Timestamp.fromDate(DateTime.now()),
      'preferences': preferences,
      'movieIds': movieIds,
      'totalMoviesCreated': totalMoviesCreated,
    };
  }

  User copyWith({
    String? displayName,
    String? photoUrl,
    String? bio,
    Map<String, dynamic>? preferences,
  }) {
    return User(
      id: this.id,
      email: this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      bio: bio ?? this.bio,
      createdAt: this.createdAt,
      lastUpdated: DateTime.now(),
      preferences: preferences ?? this.preferences,
      movieIds: this.movieIds,
      totalMoviesCreated: this.totalMoviesCreated,
    );
  }
} 