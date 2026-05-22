import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

class ConversationsScreen extends ConsumerWidget {
  const ConversationsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Conversations'), backgroundColor: Colors.transparent, elevation: 0),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('conversations')
            .where('participants', arrayContains: uid)
            .orderBy('last_message_at', descending: true).snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return Center(child: Text('Error: \${snap.error}'));
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.chat_bubble_outline_rounded, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text('No conversations yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Connect with someone on Sparks to start talking.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14), textAlign: TextAlign.center),
          ]));
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final convId = docs[i].id;
              final otherName = data['other_user_name'] as String? ?? 'Connection';
              final stage = (data['stage'] as int?) ?? 1;
              final lastMsg = data['last_message'] as Map<String, dynamic>?;
              final lastText = lastMsg?['text'] as String? ?? 'Start the conversation';
              final lastAt = data['last_message_at'];
              String timeStr = '';
              if (lastAt is Timestamp) {
                final diff = DateTime.now().difference(lastAt.toDate());
                timeStr = diff.inMinutes < 60 ? '\${diff.inMinutes}m'
                    : diff.inHours < 24 ? '\${diff.inHours}h' : '\${diff.inDays}d';
              }
              final stageLabel = {1:'Breaking the ice',2:'Getting to know each other',
                3:'Building trust',4:'Deep connection',5:'Trusted connection'}[stage] ?? '';
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                leading: CircleAvatar(radius: 26,
                  backgroundColor: AppColors.primaryLight.withOpacity(0.3),
                  child: Text(otherName.isNotEmpty ? otherName[0].toUpperCase() : '?',
                      style: TextStyle(fontSize: 20, color: AppColors.primary, fontWeight: FontWeight.w700))),
                title: Row(children: [
                  Expanded(child: Text(otherName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
                  if (timeStr.isNotEmpty) Text(timeStr, style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ]),
                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SizedBox(height: 2),
                  Text('Stage \$stage · \$stageLabel',
                      style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(lastText, style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
                onTap: () => context.push('/chat/\$convId', extra: {'name': otherName}),
              );
            },
          );
        },
      ),
    );
  }
}
