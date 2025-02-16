class Video {
  final String id;
  final String url;
  final String userId;
  final String username;
  final String? caption;
  final int likes;
  final int comments;
  final int shares;
  final DateTime createdAt;
  final String? thumbnailUrl;
  final Map<String, dynamic>? metadata;

  Video({
    required this.id,
    required this.url,
    required this.userId,
    required this.username,
    this.caption,
    this.likes = 0,
    this.comments = 0,
    this.shares = 0,
    required this.createdAt,
    this.thumbnailUrl,
    this.metadata,
  });

  factory Video.fromMap(Map<String, dynamic> map) {
    return Video(
      id: map['id'] as String,
      url: map['url'] as String,
      userId: map['userId'] as String,
      username: map['username'] as String,
      caption: map['caption'] as String?,
      likes: map['likes'] as int? ?? 0,
      comments: map['comments'] as int? ?? 0,
      shares: map['shares'] as int? ?? 0,
      createdAt: (map['createdAt'] as DateTime?) ?? DateTime.now(),
      thumbnailUrl: map['thumbnailUrl'] as String?,
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'url': url,
      'userId': userId,
      'username': username,
      'caption': caption,
      'likes': likes,
      'comments': comments,
      'shares': shares,
      'createdAt': createdAt,
      'thumbnailUrl': thumbnailUrl,
      'metadata': metadata,
    };
  }

  Video copyWith({
    String? id,
    String? url,
    String? userId,
    String? username,
    String? caption,
    int? likes,
    int? comments,
    int? shares,
    DateTime? createdAt,
    String? thumbnailUrl,
    Map<String, dynamic>? metadata,
  }) {
    return Video(
      id: id ?? this.id,
      url: url ?? this.url,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      caption: caption ?? this.caption,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      shares: shares ?? this.shares,
      createdAt: createdAt ?? this.createdAt,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      metadata: metadata ?? this.metadata,
    );
  }
} 