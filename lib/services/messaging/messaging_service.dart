import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../models/message.dart';
import '../../models/typing_status.dart';
import '../../models/message_reaction.dart';
import 'package:rxdart/rxdart.dart';

class MessagingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  
  // Stream controllers for real-time updates
  final _messageController = StreamController<Message>.broadcast();
  final _conversationController = StreamController<List<Conversation>>.broadcast();
  final _typingController = StreamController<TypingStatus>.broadcast();

  Stream<Message> get messageStream => _messageController.stream;
  Stream<List<Conversation>> get conversationStream => _conversationController.stream;
  Stream<TypingStatus> get typingStream => _typingController.stream;

  final BehaviorSubject<Map<String, bool>> _typingStatusController = BehaviorSubject.seeded({});

  // Messages Collection References
  CollectionReference get _messagesRef => _firestore.collection('messages');
  CollectionReference get _conversationsRef => _firestore.collection('conversations');
  CollectionReference get _reactionsRef => _firestore.collection('message_reactions');

  // Initialize messaging service
  Future<void> initialize(String userId) async {
    // Request notification permissions
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Listen for incoming messages when app is in background
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Listen for incoming messages when app is in foreground
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Get FCM token and save it
    final token = await _fcm.getToken();
    if (token != null) {
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': token,
      });
    }
  }

  // Send a new message
  Future<void> sendMessage({
    required String senderId,
    required String conversationId,
    required String content,
    MessageType messageType = MessageType.text,
    String? mediaUrl,
    String? replyToMessageId,
    String conversationType = 'individual',
    String? groupId,
  }) async {
    try {
      final message = Message(
        id: _messagesRef.doc().id,
        senderId: senderId,
        receiverId: '', // Will be set based on conversation type
        content: content,
        timestamp: DateTime.now(),
        messageType: messageType,
        mediaUrl: mediaUrl,
        replyToMessageId: replyToMessageId,
        conversationType: conversationType,
        groupId: groupId,
      );

      final batch = _firestore.batch();
      
      // Add message
      batch.set(_messagesRef.doc(message.id), message.toMap());
      
      // Update conversation
      batch.update(_conversationsRef.doc(conversationId), {
        'lastMessageTime': message.timestamp,
        'lastMessageContent': content,
        'hasUnreadMessages': true,
      });

      await batch.commit();

      // Send push notification
      await _sendPushNotification(conversationId, content);
    } catch (e) {
      print('Error sending message: $e');
      rethrow;
    }
  }

  // Get conversation messages
  Stream<List<Message>> getMessages(String conversationId) {
    return _messagesRef
        .where('conversationId', isEqualTo: conversationId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Message.fromFirestore(doc)).toList();
    });
  }

  // Get user conversations
  Stream<List<Conversation>> getUserConversations(String userId) {
    return _conversationsRef
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Conversation.fromFirestore(doc))
          .toList();
    });
  }

  // Mark message as read
  Future<void> markMessageAsRead(String conversationId, String messageId) async {
    await _messagesRef
        .doc(messageId)
        .update({'isRead': true});
  }

  // Helper methods
  String _encryptMessage(String content) {
    // Simple base64 encoding for now
    // TODO: Implement proper encryption
    return base64Encode(utf8.encode(content));
  }

  String _decryptMessage(String encryptedContent) {
    // Simple base64 decoding for now
    // TODO: Implement proper decryption
    try {
      return utf8.decode(base64Decode(encryptedContent));
    } catch (e) {
      print('Error decrypting message: $e');
      return encryptedContent; // Return as-is if decryption fails
    }
  }

  Future<String> _getOrCreateConversation(
      String userId1, String userId2) async {
    // Sort user IDs to ensure consistent conversation ID
    final sortedUsers = [userId1, userId2]..sort();
    final conversationId = sortedUsers.join('_');

    final conversationDoc = await _conversationsRef.doc(conversationId).get();

    if (!conversationDoc.exists) {
      await _conversationsRef.doc(conversationId).set({
        'participants': sortedUsers,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessageTime': FieldValue.serverTimestamp(),
        'hasUnreadMessages': false,
      });
    }

    return conversationId;
  }

  Future<void> _updateConversationMetadata(
      String conversationId, String lastMessage, DateTime timestamp) async {
    await _conversationsRef.doc(conversationId).update({
      'lastMessageContent': lastMessage,
      'lastMessageTime': Timestamp.fromDate(timestamp),
      'hasUnreadMessages': true,
    });
  }

  Future<void> _sendPushNotification(String conversationId, String messageContent) async {
    try {
      // Get the conversation's participants
      final conversationDoc = await _conversationsRef.doc(conversationId).get();
      final data = conversationDoc.data() as Map<String, dynamic>?;
      final participants = data?['participants'] as List<dynamic>?;
      
      if (participants != null) {
        for (var userId in participants) {
          // Get the user's FCM token
          final userDoc = await _firestore.collection('users').doc(userId).get();
          final userData = userDoc.data() as Map<String, dynamic>?;
          final fcmToken = userData?['fcmToken'];
          
          if (fcmToken != null) {
            // Send to Cloud Functions to handle FCM sending
            await _firestore.collection('notifications').add({
              'to': fcmToken,
              'notification': {
                'title': 'New Message',
                'body': messageContent,
              },
              'data': {
                'type': 'message',
                'senderId': userId,
              },
              'timestamp': FieldValue.serverTimestamp(),
            });
          }
        }
      }
    } catch (e) {
      print('Error sending push notification: $e');
    }
  }

  static Future<void> _firebaseMessagingBackgroundHandler(
      RemoteMessage message) async {
    // Handle background messages
    print('Handling background message: ${message.messageId}');
  }

  void _handleForegroundMessage(RemoteMessage message) {
    // Handle foreground messages
    print('Received foreground message: ${message.messageId}');
  }

  // Typing status methods
  Future<void> updateTypingStatus({
    required String userId,
    required String conversationId,
    required bool isTyping,
  }) async {
    try {
      if (isTyping) {
        await _conversationsRef.doc(conversationId).update({
          'typingUsers.$userId': Timestamp.fromDate(DateTime.now()),
        });
      } else {
        await _conversationsRef.doc(conversationId).update({
          'typingUsers.$userId': FieldValue.delete(),
        });
      }

      _typingController.add(TypingStatus(
        userId: userId,
        conversationId: conversationId,
        isTyping: isTyping,
        timestamp: DateTime.now(),
      ));
    } catch (e) {
      print('Error updating typing status: $e');
    }
  }

  // Stream of typing status for a conversation
  Stream<Map<String, DateTime>> getTypingStatus(String conversationId) {
    return _conversationsRef
        .doc(conversationId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return {};
      final data = snapshot.data() as Map<String, dynamic>;
      final typingUsers = data['typingUsers'] as Map<String, dynamic>? ?? {};
      return typingUsers.map((key, value) => 
        MapEntry(key, (value as Timestamp).toDate())
      );
    });
  }

  // Add reaction to a message
  Future<void> addReaction({
    required String messageId,
    required String userId,
    required String reactionType,
  }) async {
    final reaction = MessageReaction(
      id: _reactionsRef.doc().id,
      messageId: messageId,
      userId: userId,
      reactionType: reactionType,
      timestamp: DateTime.now(),
    );

    await _reactionsRef.doc(reaction.id).set(reaction.toMap());

    // Update message reactions
    await _messagesRef.doc(messageId).update({
      'reactions.$userId': FieldValue.arrayUnion([reactionType]),
    });
  }

  // Remove reaction from a message
  Future<void> removeReaction({
    required String messageId,
    required String userId,
    required String reactionType,
  }) async {
    // Remove from reactions collection
    await _reactionsRef
        .where('messageId', isEqualTo: messageId)
        .where('userId', isEqualTo: userId)
        .where('reactionType', isEqualTo: reactionType)
        .get()
        .then((snapshot) {
      for (var doc in snapshot.docs) {
        doc.reference.delete();
      }
    });

    // Update message reactions
    await _messagesRef.doc(messageId).update({
      'reactions.$userId': FieldValue.arrayRemove([reactionType]),
    });
  }

  // Create a group conversation
  Future<String> createGroupConversation({
    required List<String> participants,
    required String groupName,
    String? groupAvatar,
    required String creatorId,
  }) async {
    final conversationId = _conversationsRef.doc().id;
    
    final conversation = Conversation(
      id: conversationId,
      participants: participants,
      lastMessageTime: DateTime.now(),
      conversationType: 'group',
      groupName: groupName,
      groupAvatar: groupAvatar,
      participantRoles: {creatorId: 'admin'},
    );

    await _conversationsRef.doc(conversationId).set(conversation.toMap());
    return conversationId;
  }

  // Search messages
  Future<List<Message>> searchMessages(String conversationId, String query) async {
    final snapshot = await _messagesRef
        .where('conversationId', isEqualTo: conversationId)
        .where('content', isGreaterThanOrEqualTo: query)
        .where('content', isLessThanOrEqualTo: query + '\uf8ff')
        .get();

    return snapshot.docs.map((doc) => Message.fromFirestore(doc)).toList();
  }

  // Add user to group
  Future<void> addUserToGroup(String conversationId, String userId) async {
    await _conversationsRef.doc(conversationId).update({
      'participants': FieldValue.arrayUnion([userId]),
      'participantRoles.$userId': 'member',
    });
  }

  // Remove user from group
  Future<void> removeUserFromGroup(String conversationId, String userId) async {
    await _conversationsRef.doc(conversationId).update({
      'participants': FieldValue.arrayRemove([userId]),
      'participantRoles.$userId': FieldValue.delete(),
    });
  }

  // Update user role in group
  Future<void> updateUserRole(String conversationId, String userId, String role) async {
    await _conversationsRef.doc(conversationId).update({
      'participantRoles.$userId': role,
    });
  }

  // Get a message by ID
  Future<Message?> getMessageById(String messageId) async {
    try {
      final doc = await _messagesRef.doc(messageId).get();
      if (!doc.exists) return null;
      return Message.fromFirestore(doc);
    } catch (e) {
      print('Error getting message: $e');
      return null;
    }
  }

  // Cleanup
  void dispose() {
    _messageController.close();
    _conversationController.close();
    _typingController.close();
    _typingStatusController.close();
  }
} 