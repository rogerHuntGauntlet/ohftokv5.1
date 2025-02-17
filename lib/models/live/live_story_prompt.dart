import 'package:cloud_firestore/cloud_firestore.dart';

class LiveStoryPrompt {
  final String id;
  final String streamId;
  final String prompt;
  final String? selectedResponse;
  final String? selectedUserId;
  final String? selectedUserDisplayName;
  final DateTime createdAt;
  final DateTime? selectedAt;
  final bool isActive;
  final Map<String, String> responses; // userId -> response

  LiveStoryPrompt({
    required this.id,
    required this.streamId,
    required this.prompt,
    this.selectedResponse,
    this.selectedUserId,
    this.selectedUserDisplayName,
    required this.createdAt,
    this.selectedAt,
    required this.isActive,
    required this.responses,
  });

  factory LiveStoryPrompt.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LiveStoryPrompt(
      id: doc.id,
      streamId: data['streamId'] as String,
      prompt: data['prompt'] as String,
      selectedResponse: data['selectedResponse'] as String?,
      selectedUserId: data['selectedUserId'] as String?,
      selectedUserDisplayName: data['selectedUserDisplayName'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      selectedAt: data['selectedAt'] != null
          ? (data['selectedAt'] as Timestamp).toDate()
          : null,
      isActive: data['isActive'] as bool,
      responses: Map<String, String>.from(data['responses'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'streamId': streamId,
      'prompt': prompt,
      'selectedResponse': selectedResponse,
      'selectedUserId': selectedUserId,
      'selectedUserDisplayName': selectedUserDisplayName,
      'createdAt': Timestamp.fromDate(createdAt),
      'selectedAt': selectedAt != null ? Timestamp.fromDate(selectedAt!) : null,
      'isActive': isActive,
      'responses': responses,
    };
  }

  LiveStoryPrompt copyWith({
    String? id,
    String? streamId,
    String? prompt,
    String? selectedResponse,
    String? selectedUserId,
    String? selectedUserDisplayName,
    DateTime? createdAt,
    DateTime? selectedAt,
    bool? isActive,
    Map<String, String>? responses,
  }) {
    return LiveStoryPrompt(
      id: id ?? this.id,
      streamId: streamId ?? this.streamId,
      prompt: prompt ?? this.prompt,
      selectedResponse: selectedResponse ?? this.selectedResponse,
      selectedUserId: selectedUserId ?? this.selectedUserId,
      selectedUserDisplayName: selectedUserDisplayName ?? this.selectedUserDisplayName,
      createdAt: createdAt ?? this.createdAt,
      selectedAt: selectedAt ?? this.selectedAt,
      isActive: isActive ?? this.isActive,
      responses: responses ?? this.responses,
    );
  }
} 