import 'package:cloud_firestore/cloud_firestore.dart';

enum ViewerRole {
  viewer,
  moderator,
  host,
  vip,
  banned
}

class LiveViewer {
  final String id;
  final String streamId;
  final String userId;
  final String userDisplayName;
  final String? userProfileImage;
  final ViewerRole role;
  final DateTime joinedAt;
  final DateTime? lastActive;
  final bool isActive;
  final Map<String, dynamic>? metadata;

  LiveViewer({
    required this.id,
    required this.streamId,
    required this.userId,
    required this.userDisplayName,
    this.userProfileImage,
    required this.role,
    required this.joinedAt,
    this.lastActive,
    this.isActive = true,
    this.metadata,
  });

  factory LiveViewer.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return LiveViewer(
      id: doc.id,
      streamId: data['streamId'] ?? '',
      userId: data['userId'] ?? '',
      userDisplayName: data['userDisplayName'] ?? '',
      userProfileImage: data['userProfileImage'],
      role: ViewerRole.values.firstWhere(
        (e) => e.toString() == 'ViewerRole.${data['role']}',
        orElse: () => ViewerRole.viewer
      ),
      joinedAt: (data['joinedAt'] as Timestamp).toDate(),
      lastActive: data['lastActive'] != null 
          ? (data['lastActive'] as Timestamp).toDate() 
          : null,
      isActive: data['isActive'] ?? true,
      metadata: data['metadata'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'streamId': streamId,
      'userId': userId,
      'userDisplayName': userDisplayName,
      'userProfileImage': userProfileImage,
      'role': role.toString().split('.').last,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'lastActive': lastActive != null ? Timestamp.fromDate(lastActive!) : null,
      'isActive': isActive,
      'metadata': metadata,
    };
  }

  LiveViewer copyWith({
    String? id,
    String? streamId,
    String? userId,
    String? userDisplayName,
    String? userProfileImage,
    ViewerRole? role,
    DateTime? joinedAt,
    DateTime? lastActive,
    bool? isActive,
    Map<String, dynamic>? metadata,
  }) {
    return LiveViewer(
      id: id ?? this.id,
      streamId: streamId ?? this.streamId,
      userId: userId ?? this.userId,
      userDisplayName: userDisplayName ?? this.userDisplayName,
      userProfileImage: userProfileImage ?? this.userProfileImage,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      lastActive: lastActive ?? this.lastActive,
      isActive: isActive ?? this.isActive,
      metadata: metadata ?? this.metadata,
    );
  }

  bool get isModerator => role == ViewerRole.moderator || role == ViewerRole.host;
  bool get isHost => role == ViewerRole.host;
  bool get isVIP => role == ViewerRole.vip;
  bool get isBanned => role == ViewerRole.banned;
} 