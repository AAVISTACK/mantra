// lib/features/chat/data/models/message_model.dart

enum MessageType { text, voice, gif, system }

class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final MessageType type;
  final String content;
  final bool isMine;
  final bool isRead;
  final bool isDelivered;
  final DateTime createdAt;
  final int? voiceDuration;

  const MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.type,
    required this.content,
    required this.isMine,
    required this.isRead,
    required this.isDelivered,
    required this.createdAt,
    this.voiceDuration,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json, String myUserId) =>
      MessageModel(
        id: json['_id'] ?? json['id'],
        conversationId: json['conversation_id'],
        senderId: json['sender_id'],
        type: MessageType.values.firstWhere(
          (t) => t.name == (json['type'] ?? 'text'),
          orElse: () => MessageType.text,
        ),
        content: json['content'] ?? '',
        isMine: json['sender_id'] == myUserId,
        isRead: json['read_at'] != null,
        isDelivered: json['delivered_at'] != null,
        createdAt: DateTime.parse(json['created_at']),
        voiceDuration: json['voice_duration'],
      );
}

// ─────────────────────────────────────────────────────────
// lib/features/chat/data/models/conversation_state.dart

class ConversationState {
  final String conversationId;
  final List<MessageModel> messages;
  final int stage;
  final String? aiSuggestion;
  final bool isTyping;

  const ConversationState({
    required this.conversationId,
    required this.messages,
    required this.stage,
    this.aiSuggestion,
    required this.isTyping,
  });

  ConversationState copyWith({
    List<MessageModel>? messages,
    int? stage,
    String? aiSuggestion,
    bool? isTyping,
  }) {
    return ConversationState(
      conversationId: conversationId,
      messages: messages ?? this.messages,
      stage: stage ?? this.stage,
      aiSuggestion: aiSuggestion ?? this.aiSuggestion,
      isTyping: isTyping ?? this.isTyping,
    );
  }
}

// ─────────────────────────────────────────────────────────
// lib/features/chat/providers/chat_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/models/message_model.dart';
import '../data/models/conversation_state.dart';

final chatProvider = AsyncNotifierProviderFamily<ChatNotifier,
    ConversationState?, String>(
  ChatNotifier.new,
);

class ChatNotifier
    extends FamilyAsyncNotifier<ConversationState?, String> {
  late String _conversationId;
  final _firestore = FirebaseFirestore.instance;

  @override
  Future<ConversationState?> build(String arg) async {
    _conversationId = arg;
    _listenToMessages();
    return _fetchInitialState();
  }

  Future<ConversationState?> _fetchInitialState() async {
    try {
      final convDoc = await _firestore
          .collection('conversations')
          .doc(_conversationId)
          .get();

      if (!convDoc.exists) return null;

      final data = convDoc.data()!;
      final messagesSnap = await _firestore
          .collection('messages')
          .where('conversation_id', isEqualTo: _conversationId)
          .orderBy('created_at', descending: false)
          .limit(50)
          .get();

      final messages = messagesSnap.docs
          .map((d) => MessageModel.fromJson(d.data(), _myUserId()))
          .toList();

      return ConversationState(
        conversationId: _conversationId,
        messages: messages,
        stage: data['stage'] ?? 1,
        aiSuggestion: data['ai_suggestion'],
        isTyping: false,
      );
    } catch (e) {
      return null;
    }
  }

  void _listenToMessages() {
    _firestore
        .collection('messages')
        .where('conversation_id', isEqualTo: _conversationId)
        .orderBy('created_at', descending: false)
        .snapshots()
        .listen((snap) {
      final current = state.value;
      if (current == null) return;

      final messages = snap.docs
          .map((d) => MessageModel.fromJson(d.data(), _myUserId()))
          .toList();

      state = AsyncData(current.copyWith(messages: messages));
    });

    // Typing indicator
    _firestore
        .collection('typing')
        .doc(_conversationId)
        .snapshots()
        .listen((snap) {
      final current = state.value;
      if (current == null) return;
      final data = snap.data();
      final isTyping = data != null &&
          data.keys.any((k) => k != _myUserId() && (data[k] == true));
      state = AsyncData(current.copyWith(isTyping: isTyping));
    });
  }

  Future<void> sendText(String content) async {
    final msg = {
      'conversation_id': _conversationId,
      'sender_id': _myUserId(),
      'type': 'text',
      'content': content,
      'created_at': DateTime.now().toIso8601String(),
      'is_deleted': false,
    };
    await _firestore.collection('messages').add(msg);
    await _firestore
        .collection('conversations')
        .doc(_conversationId)
        .update({'last_message_at': FieldValue.serverTimestamp()});
  }

  Future<void> sendVoice(String localPath) async {
    // Upload to Firebase Storage then create message
    // Simplified here — in production, upload then create doc
    final msg = {
      'conversation_id': _conversationId,
      'sender_id': _myUserId(),
      'type': 'voice',
      'content': localPath, // replace with Storage URL after upload
      'created_at': DateTime.now().toIso8601String(),
      'voice_duration': 30,
      'is_deleted': false,
    };
    await _firestore.collection('messages').add(msg);
  }

  Future<void> setTyping(bool isTyping) async {
    await _firestore.collection('typing').doc(_conversationId).set({
      _myUserId(): isTyping,
    }, SetOptions(merge: true));
  }

  String _myUserId() {
    // In production: read from auth provider
    return 'current_user_id';
  }
}
