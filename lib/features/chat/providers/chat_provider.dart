import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../data/models/message_model.dart';
import '../data/models/conversation_state.dart';

final chatProvider = AsyncNotifierProviderFamily<ChatNotifier, ConversationState?, String>(
  ChatNotifier.new,
);

class ChatNotifier extends FamilyAsyncNotifier<ConversationState?, String> {
  late String _conversationId;
  final _firestore = FirebaseFirestore.instance;
  final _storage   = FirebaseStorage.instance;

  String get _myUserId {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) throw StateError('User not authenticated');
    return uid;
  }

  @override
  Future<ConversationState?> build(String arg) async {
    _conversationId = arg;
    _listenToMessages();
    return _fetchInitial();
  }

  Future<ConversationState?> _fetchInitial() async {
    try {
      final convDoc = await _firestore.collection('conversations').doc(_conversationId).get();
      final data = convDoc.data() ?? {};
      final snap = await _firestore
          .collection('conversations').doc(_conversationId)
          .collection('messages').orderBy('created_at').limitToLast(50).get();
      final uid = _myUserId;
      return ConversationState(
        conversationId: _conversationId,
        messages: snap.docs.map((d) => MessageModel.fromFirestore(d.data(), d.id, uid)).toList(),
        stage: (data['stage'] as int?) ?? 1,
        aiSuggestion: data['ai_suggestion'] as String?,
        isTyping: false,
      );
    } catch (_) {
      return ConversationState(conversationId: _conversationId, messages: [], stage: 1, isTyping: false);
    }
  }

  void _listenToMessages() {
    _firestore.collection('conversations').doc(_conversationId)
        .collection('messages').orderBy('created_at').snapshots().listen((snap) {
      try {
        final uid = _myUserId;
        final messages = snap.docs.map((d) => MessageModel.fromFirestore(d.data(), d.id, uid)).toList();
        state = AsyncData(state.value?.copyWith(messages: messages) ??
            ConversationState(conversationId: _conversationId, messages: messages, stage: 1, isTyping: false));
      } catch (_) {}
    });
    _firestore.collection('conversations').doc(_conversationId)
        .collection('typing').snapshots().listen((snap) {
      try {
        final uid = _myUserId;
        final isTyping = snap.docs.any((d) => d.id != uid && (d.data()['typing'] == true));
        final cur = state.value;
        if (cur != null) state = AsyncData(cur.copyWith(isTyping: isTyping));
      } catch (_) {}
    });
  }

  Future<void> sendText(String content) async {
    if (content.trim().isEmpty) return;
    final uid = _myUserId;
    final now = DateTime.now().toIso8601String();
    await _firestore.collection('conversations').doc(_conversationId)
        .collection('messages').add({
      'sender_id': uid, 'type': 'text', 'content': content.trim(),
      'created_at': now, 'is_deleted': false,
    });
    await _firestore.collection('conversations').doc(_conversationId).set({
      'last_message': {'text': content.trim(), 'timestamp': now, 'sender_id': uid},
      'last_message_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> sendVoice(String localPath) async {
    final uid = _myUserId;
    final ref = _storage.ref('voice/\${const Uuid().v4()}.m4a');
    try {
      await ref.putFile(File(localPath));
      final url = await ref.getDownloadURL();
      final now = DateTime.now().toIso8601String();
      await _firestore.collection('conversations').doc(_conversationId)
          .collection('messages').add({
        'sender_id': uid, 'type': 'voice', 'content': url,
        'created_at': now, 'voice_duration': 0, 'is_deleted': false,
      });
      await _firestore.collection('conversations').doc(_conversationId).set({
        'last_message': {'text': '🎤 Voice message', 'timestamp': now, 'sender_id': uid},
        'last_message_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } finally {
      try { await File(localPath).delete(); } catch (_) {}
    }
  }

  Future<void> setTyping(bool isTyping) async {
    try {
      await _firestore.collection('conversations').doc(_conversationId)
          .collection('typing').doc(_myUserId).set({'typing': isTyping});
    } catch (_) {}
  }
}
