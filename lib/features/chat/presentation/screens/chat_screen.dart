import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../chat/data/models/message_model.dart';
import '../../../chat/providers/chat_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final Map<String, dynamic>? extra;

  const ChatScreen({
    super.key,
    required this.conversationId,
    this.extra,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _audioRecorder = AudioRecorder();
  bool _isRecordingVoice = false;
  bool _showSuggestion = true;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  void _sendText() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    ref.read(chatProvider(widget.conversationId).notifier).sendText(text);
    _textController.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _startVoiceRecord() async {
    final permission = await Permission.microphone.request();
    if (!permission.isGranted) return;

    HapticFeedback.mediumImpact();
    final dir = await getApplicationDocumentsDirectory();
    final path =
        '${dir.path}/voice_msg_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _audioRecorder.start(const RecordConfig(), path: path);
    setState(() => _isRecordingVoice = true);
  }

  Future<void> _stopVoiceRecord() async {
    final path = await _audioRecorder.stop();
    setState(() => _isRecordingVoice = false);
    if (path != null) {
      HapticFeedback.lightImpact();
      ref
          .read(chatProvider(widget.conversationId).notifier)
          .sendVoice(path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider(widget.conversationId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _ChatAppBar(
        name: extra?['name'] ?? 'Connection',
        trustScore: (extra?['trust_score'] as num?)?.toDouble() ?? 75.0,
        stage: chatState.value?.stage ?? 1,
        onBack: () => context.pop(),
        onMore: () => _showMoreOptions(context),
      ),
      body: Column(
        children: [
          // Stage indicator
          _StageIndicator(stage: chatState.value?.stage ?? 1),

          // AI suggestion banner
          if (_showSuggestion && chatState.value?.aiSuggestion != null)
            _AISuggestionBanner(
              suggestion: chatState.value!.aiSuggestion!,
              onDismiss: () => setState(() => _showSuggestion = false),
              onUse: () {
                _textController.text = chatState.value!.aiSuggestion!;
                setState(() => _showSuggestion = false);
              },
            ),

          // Messages
          Expanded(
            child: chatState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (state) {
                if (state == null) return const SizedBox();
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  itemCount: state.messages.length,
                  itemBuilder: (context, i) {
                    final msg = state.messages[i];
                    final showDate = i == 0 ||
                        !_isSameDay(
                          state.messages[i - 1].createdAt,
                          msg.createdAt,
                        );
                    return Column(
                      children: [
                        if (showDate) _DateDivider(date: msg.createdAt),
                        MessageBubble(message: msg),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // Voice recording indicator
          if (_isRecordingVoice) _RecordingIndicator(),

          // Input bar
          _ChatInputBar(
            controller: _textController,
            isRecording: _isRecordingVoice,
            onSend: _sendText,
            onVoiceStart: _startVoiceRecord,
            onVoiceStop: _stopVoiceRecord,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic>? get extra => widget.extra;

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => _ChatMoreOptions(
        onReport: () {},
        onBlock: () {},
        onSafety: () => context.push('/safety'),
      ),
    );
  }
}

// ─── App Bar ───────────────────────────────────────────
class _ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String name;
  final double trustScore;
  final int stage;
  final VoidCallback onBack;
  final VoidCallback onMore;

  const _ChatAppBar({
    required this.name,
    required this.trustScore,
    required this.stage,
    required this.onBack,
    required this.onMore,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.surface,
      leading: IconButton(
        onPressed: onBack,
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          Row(
            children: [
              Icon(Icons.shield_rounded, size: 11, color: AppColors.trust),
              const SizedBox(width: 3),
              Text(
                '${trustScore.toInt()} Trust · Stage $stage',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        // SOS always visible
        IconButton(
          onPressed: () {},
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.trust.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.shield_rounded,
              color: AppColors.trust,
              size: 18,
            ),
          ),
        ),
        IconButton(
          onPressed: onMore,
          icon: const Icon(Icons.more_vert_rounded),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, color: AppColors.border),
      ),
    );
  }
}

// ─── Stage Indicator ───────────────────────────────────
class _StageIndicator extends StatelessWidget {
  final int stage;
  const _StageIndicator({required this.stage});

  String get _label {
    switch (stage) {
      case 1:
        return 'Stage 1 — Breaking the ice 🌱';
      case 2:
        return 'Stage 2 — Getting to know each other 🌿';
      case 3:
        return 'Stage 3 — Building trust 🌸';
      case 4:
        return 'Stage 4 — Deep connection 🌳';
      case 5:
        return 'Stage 5 — Trusted ✨';
      default:
        return 'Stage $stage';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.secondary.withOpacity(0.08),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _label,
              style: TextStyle(
                color: AppColors.secondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // Stage progress dots
          Row(
            children: List.generate(5, (i) {
              return Container(
                margin: const EdgeInsets.only(left: 4),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < stage
                      ? AppColors.secondary
                      : AppColors.border,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ─── AI Suggestion Banner ──────────────────────────────
class _AISuggestionBanner extends StatelessWidget {
  final String suggestion;
  final VoidCallback onDismiss;
  final VoidCallback onUse;

  const _AISuggestionBanner({
    required this.suggestion,
    required this.onDismiss,
    required this.onUse,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.15),
        ),
      ),
      child: Row(
        children: [
          Text('💡', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              suggestion,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onUse,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Use',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: Icon(
              Icons.close_rounded,
              size: 16,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1, end: 0);
  }
}

// ─── Message Bubble ────────────────────────────────────
class MessageBubble extends StatelessWidget {
  final MessageModel message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isMine = message.isMine;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) const SizedBox(width: 8),
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              padding: message.type == MessageType.voice
                  ? const EdgeInsets.all(10)
                  : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMine ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMine ? 18 : 4),
                  bottomRight: Radius.circular(isMine ? 4 : 18),
                ),
                border:
                    isMine ? null : Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadow.withOpacity(0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: message.type == MessageType.voice
                  ? _VoiceMessageContent(
                      message: message,
                      isMine: isMine,
                    )
                  : _TextMessageContent(
                      message: message,
                      isMine: isMine,
                    ),
            ),
          ),
          if (isMine) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _TextMessageContent extends StatelessWidget {
  final MessageModel message;
  final bool isMine;

  const _TextMessageContent({
    required this.message,
    required this.isMine,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          message.content,
          style: TextStyle(
            color: isMine ? Colors.white : AppColors.textPrimary,
            fontSize: 15,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatTime(message.createdAt),
              style: TextStyle(
                color: isMine
                    ? Colors.white.withOpacity(0.6)
                    : AppColors.textMuted,
                fontSize: 10,
              ),
            ),
            if (isMine) ...[
              const SizedBox(width: 4),
              Icon(
                message.isRead
                    ? Icons.done_all_rounded
                    : Icons.done_rounded,
                size: 12,
                color: message.isRead
                    ? AppColors.primaryLight
                    : Colors.white.withOpacity(0.6),
              ),
            ],
          ],
        ),
      ],
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _VoiceMessageContent extends StatelessWidget {
  final MessageModel message;
  final bool isMine;

  const _VoiceMessageContent({
    required this.message,
    required this.isMine,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isMine
                ? Colors.white.withOpacity(0.2)
                : AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.play_arrow_rounded,
            color: isMine ? Colors.white : AppColors.primary,
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Waveform bars (static visual)
            Row(
              children: List.generate(20, (i) {
                final heights = [4.0, 8.0, 12.0, 6.0, 10.0, 14.0, 8.0,
                    12.0, 6.0, 10.0, 14.0, 8.0, 6.0, 12.0, 8.0, 10.0,
                    6.0, 14.0, 8.0, 4.0];
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  width: 3,
                  height: heights[i],
                  decoration: BoxDecoration(
                    color: isMine
                        ? Colors.white.withOpacity(0.7)
                        : AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
            const SizedBox(height: 4),
            Text(
              '0:${message.voiceDuration?.toString().padLeft(2, '0') ?? '00'}',
              style: TextStyle(
                color: isMine
                    ? Colors.white.withOpacity(0.7)
                    : AppColors.textMuted,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Input Bar ─────────────────────────────────────────
class _ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isRecording;
  final VoidCallback onSend;
  final VoidCallback onVoiceStart;
  final VoidCallback onVoiceStop;
  final ValueChanged<String> onChanged;

  const _ChatInputBar({
    required this.controller,
    required this.isRecording,
    required this.onSend,
    required this.onVoiceStart,
    required this.onVoiceStop,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasText = controller.text.isNotEmpty;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          // Input field
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                maxLines: null,
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Say something genuine...',
                  hintStyle: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 15,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // Send or Voice button
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: hasText
                ? GestureDetector(
                    onTap: onSend,
                    key: const ValueKey('send'),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  )
                : GestureDetector(
                    onLongPressStart: (_) => onVoiceStart(),
                    onLongPressEnd: (_) => onVoiceStop(),
                    key: const ValueKey('voice'),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isRecording
                            ? AppColors.error
                            : AppColors.surfaceVariant,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Icon(
                        isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                        color: isRecording
                            ? Colors.white
                            : AppColors.textSecondary,
                        size: 22,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _RecordingIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.error.withOpacity(0.08),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.error,
              shape: BoxShape.circle,
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .fadeOut(duration: 600.ms),
          const SizedBox(width: 8),
          Text(
            'Recording... release to send',
            style: TextStyle(
              color: AppColors.error,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _DateDivider extends StatelessWidget {
  final DateTime date;
  const _DateDivider({required this.date});

  String get _label {
    final now = DateTime.now();
    final diff = now.difference(date).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          ),
          child: Text(
            _label,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatMoreOptions extends StatelessWidget {
  final VoidCallback onReport;
  final VoidCallback onBlock;
  final VoidCallback onSafety;

  const _ChatMoreOptions({
    required this.onReport,
    required this.onBlock,
    required this.onSafety,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Option(
            icon: Icons.flag_outlined,
            label: 'Report',
            onTap: onReport,
          ),
          _Option(
            icon: Icons.block_rounded,
            label: 'Block',
            color: AppColors.error,
            onTap: onBlock,
          ),
          _Option(
            icon: Icons.shield_rounded,
            label: 'Safety Center',
            color: AppColors.trust,
            onTap: onSafety,
          ),
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _Option({
    required this.icon,
    required this.label,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: color ?? AppColors.textPrimary, size: 22),
      title: Text(
        label,
        style: TextStyle(
          color: color ?? AppColors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      contentPadding: EdgeInsets.zero,
    );
  }
}
