import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType {
  text,
  image,
  video,
  voice,
  file,
  location,
  videoCall,
}

enum CallState {
  initiating,
  ringing,
  accepted,
  declined,
  missed,
  ended,
  busy,
  failed,
}

enum CallType {
  audio,
  video,
}

class FileAttachment {
  final String url;
  final String fileName;
  final String fileType;
  final int fileSize;
  final String? thumbnailUrl;

  FileAttachment({
    required this.url,
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    this.thumbnailUrl,
  });

  factory FileAttachment.fromMap(Map<String, dynamic> map) {
    return FileAttachment(
      url: map['url'] ?? '',
      fileName: map['fileName'] ?? '',
      fileType: map['fileType'] ?? '',
      fileSize: map['fileSize'] ?? 0,
      thumbnailUrl: map['thumbnailUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'fileName': fileName,
      'fileType': fileType,
      'fileSize': fileSize,
      'thumbnailUrl': thumbnailUrl,
    };
  }
}

class LocationInfo {
  final double latitude;
  final double longitude;
  final String? address;
  final String? placeName;
  final Map<String, dynamic>? additionalInfo;

  LocationInfo({
    required this.latitude,
    required this.longitude,
    this.address,
    this.placeName,
    this.additionalInfo,
  });

  factory LocationInfo.fromMap(Map<String, dynamic> map) {
    return LocationInfo(
      latitude: map['latitude'] ?? 0.0,
      longitude: map['longitude'] ?? 0.0,
      address: map['address'],
      placeName: map['placeName'],
      additionalInfo: map['additionalInfo'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'placeName': placeName,
      'additionalInfo': additionalInfo,
    };
  }
}

class CallInfo {
  final String callId;
  final CallType callType;
  final CallState callState;
  final DateTime startTime;
  final DateTime? endTime;
  final Map<String, dynamic>? iceServers;
  final Map<String, dynamic>? sdpOffer;
  final Map<String, dynamic>? sdpAnswer;
  final List<Map<String, dynamic>>? iceCandidates;
  final Map<String, bool> participantStates; // userId: hasJoined

  CallInfo({
    required this.callId,
    required this.callType,
    required this.callState,
    required this.startTime,
    this.endTime,
    this.iceServers,
    this.sdpOffer,
    this.sdpAnswer,
    this.iceCandidates,
    this.participantStates = const {},
  });

  factory CallInfo.fromMap(Map<String, dynamic> map) {
    return CallInfo(
      callId: map['callId'] ?? '',
      callType: CallType.values.firstWhere(
        (e) => e.toString() == 'CallType.${map['callType'] ?? 'audio'}',
        orElse: () => CallType.audio,
      ),
      callState: CallState.values.firstWhere(
        (e) => e.toString() == 'CallState.${map['callState'] ?? 'ended'}',
        orElse: () => CallState.ended,
      ),
      startTime: (map['startTime'] as Timestamp).toDate(),
      endTime: map['endTime'] != null ? (map['endTime'] as Timestamp).toDate() : null,
      iceServers: map['iceServers'],
      sdpOffer: map['sdpOffer'],
      sdpAnswer: map['sdpAnswer'],
      iceCandidates: List<Map<String, dynamic>>.from(map['iceCandidates'] ?? []),
      participantStates: Map<String, bool>.from(map['participantStates'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'callId': callId,
      'callType': callType.toString().split('.').last,
      'callState': callState.toString().split('.').last,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'iceServers': iceServers,
      'sdpOffer': sdpOffer,
      'sdpAnswer': sdpAnswer,
      'iceCandidates': iceCandidates,
      'participantStates': participantStates,
    };
  }

  CallInfo copyWith({
    String? callId,
    CallType? callType,
    CallState? callState,
    DateTime? startTime,
    DateTime? endTime,
    Map<String, dynamic>? iceServers,
    Map<String, dynamic>? sdpOffer,
    Map<String, dynamic>? sdpAnswer,
    List<Map<String, dynamic>>? iceCandidates,
    Map<String, bool>? participantStates,
  }) {
    return CallInfo(
      callId: callId ?? this.callId,
      callType: callType ?? this.callType,
      callState: callState ?? this.callState,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      iceServers: iceServers ?? this.iceServers,
      sdpOffer: sdpOffer ?? this.sdpOffer,
      sdpAnswer: sdpAnswer ?? this.sdpAnswer,
      iceCandidates: iceCandidates ?? this.iceCandidates,
      participantStates: participantStates ?? this.participantStates,
    );
  }
}

class Message {
  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final DateTime timestamp;
  final bool isRead;
  final String? mediaUrl;
  final MessageType messageType;
  final Map<String, dynamic>? metadata;
  final Map<String, List<String>>? reactions;
  final String? replyToMessageId;
  final String conversationType;
  final String? groupId;
  final FileAttachment? fileAttachment;
  final LocationInfo? locationInfo;
  final CallInfo? callInfo;

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.timestamp,
    this.isRead = false,
    this.mediaUrl,
    this.messageType = MessageType.text,
    this.metadata,
    this.reactions = const {},
    this.replyToMessageId,
    this.conversationType = 'individual',
    this.groupId,
    this.fileAttachment,
    this.locationInfo,
    this.callInfo,
  });

  factory Message.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Message(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      content: data['content'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      isRead: data['isRead'] ?? false,
      mediaUrl: data['mediaUrl'],
      messageType: MessageType.values.firstWhere(
        (e) => e.toString() == 'MessageType.${data['messageType'] ?? 'text'}',
        orElse: () => MessageType.text,
      ),
      metadata: data['metadata'],
      reactions: Map<String, List<String>>.from(data['reactions'] ?? {}),
      replyToMessageId: data['replyToMessageId'],
      conversationType: data['conversationType'] ?? 'individual',
      groupId: data['groupId'],
      fileAttachment: data['fileAttachment'] != null
          ? FileAttachment.fromMap(data['fileAttachment'])
          : null,
      locationInfo: data['locationInfo'] != null
          ? LocationInfo.fromMap(data['locationInfo'])
          : null,
      callInfo: data['callInfo'] != null
          ? CallInfo.fromMap(data['callInfo'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
      'mediaUrl': mediaUrl,
      'messageType': messageType.toString().split('.').last,
      'metadata': metadata,
      'reactions': reactions,
      'replyToMessageId': replyToMessageId,
      'conversationType': conversationType,
      'groupId': groupId,
      'fileAttachment': fileAttachment?.toMap(),
      'locationInfo': locationInfo?.toMap(),
      'callInfo': callInfo?.toMap(),
    };
  }
}

class Conversation {
  final String id;
  final List<String> participants;
  final DateTime lastMessageTime;
  final String? lastMessageContent;
  final bool hasUnreadMessages;
  final Map<String, dynamic>? metadata;
  final String conversationType; // 'individual' or 'group'
  final String? groupName; // Only for group conversations
  final String? groupAvatar; // Only for group conversations
  final Map<String, String> participantRoles; // userId: role ('admin', 'member')
  final Map<String, DateTime> typingUsers; // Track multiple typing users

  Conversation({
    required this.id,
    required this.participants,
    required this.lastMessageTime,
    this.lastMessageContent,
    this.hasUnreadMessages = false,
    this.metadata,
    this.conversationType = 'individual',
    this.groupName,
    this.groupAvatar,
    this.participantRoles = const {},
    this.typingUsers = const {},
  });

  factory Conversation.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Conversation(
      id: doc.id,
      participants: List<String>.from(data['participants'] ?? []),
      lastMessageTime: (data['lastMessageTime'] as Timestamp).toDate(),
      lastMessageContent: data['lastMessageContent'],
      hasUnreadMessages: data['hasUnreadMessages'] ?? false,
      metadata: data['metadata'],
      conversationType: data['conversationType'] ?? 'individual',
      groupName: data['groupName'],
      groupAvatar: data['groupAvatar'],
      participantRoles: Map<String, String>.from(data['participantRoles'] ?? {}),
      typingUsers: (data['typingUsers'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, (value as Timestamp).toDate()),
          ) ?? {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'participants': participants,
      'lastMessageTime': Timestamp.fromDate(lastMessageTime),
      'lastMessageContent': lastMessageContent,
      'hasUnreadMessages': hasUnreadMessages,
      'metadata': metadata,
      'conversationType': conversationType,
      'groupName': groupName,
      'groupAvatar': groupAvatar,
      'participantRoles': participantRoles,
      'typingUsers': typingUsers.map((key, value) => MapEntry(key, Timestamp.fromDate(value))),
    };
  }
} 