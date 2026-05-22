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
    required this.id, required this.conversationId, required this.senderId,
    required this.type, required this.content, required this.isMine,
    required this.isRead, required this.isDelivered, required this.createdAt,
    this.voiceDuration,
  });

  factory MessageModel.fromFirestore(Map<String, dynamic> data, String docId, String myUserId) {
    return MessageModel(
      id: docId,
      conversationId: data['conversation_id'] as String? ?? '',
      senderId: data['sender_id'] as String? ?? '',
      type: MessageType.values.firstWhere(
        (t) => t.name == (data['type'] as String? ?? 'text'),
        orElse: () => MessageType.text,
      ),
      content: data['content'] as String? ?? '',
      isMine: (data['sender_id'] as String?) == myUserId,
      isRead: data['read_at'] != null,
      isDelivered: data['delivered_at'] != null,
      createdAt: data['created_at'] != null
          ? DateTime.parse(data['created_at'] as String)
          : DateTime.now(),
      voiceDuration: data['voice_duration'] as int?,
    );
  }
}
