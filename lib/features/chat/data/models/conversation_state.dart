import 'message_model.dart';

class ConversationState {
  final String conversationId;
  final List<MessageModel> messages;
  final int stage;
  final String? aiSuggestion;
  final bool isTyping;
  final String? otherUserName;

  const ConversationState({
    required this.conversationId,
    required this.messages,
    required this.stage,
    this.aiSuggestion,
    required this.isTyping,
    this.otherUserName,
  });

  ConversationState copyWith({
    List<MessageModel>? messages,
    int? stage,
    String? aiSuggestion,
    bool? isTyping,
    String? otherUserName,
  }) => ConversationState(
    conversationId: conversationId,
    messages: messages ?? this.messages,
    stage: stage ?? this.stage,
    aiSuggestion: aiSuggestion ?? this.aiSuggestion,
    isTyping: isTyping ?? this.isTyping,
    otherUserName: otherUserName ?? this.otherUserName,
  );
}
