import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../profile/providers/profile_provider.dart';

class TrustScoreScreen extends ConsumerWidget {
  const TrustScoreScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final score = ref.watch(profileNotifierProvider).value?.trustScore?.toInt() ?? 50;
    final buckets = [('📸 Verified Photos', true),('🪪 ID Verified', true),('🎤 Voice Intro Recorded', true),
      ('📝 Prompts Answered', false),('⭐ Premium Member', false),('🚫 No Reports', true)];
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Trust Score'), backgroundColor: Colors.transparent),
      body: ListView(padding: const EdgeInsets.all(AppSpacing.screenPadding), children: [
        Center(child: Stack(alignment: Alignment.center, children: [
          SizedBox(width: 120, height: 120, child: CircularProgressIndicator(
            value: score / 100, strokeWidth: 10, backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation(score >= 80 ? AppColors.success : score >= 60 ? AppColors.warning : Colors.red))),
          Column(children: [
            Text('\$score', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
            Text('/100', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ]),
        ])),
        const SizedBox(height: 8),
        Center(child: Text(score >= 80 ? '🌟 Highly Trusted' : score >= 60 ? '✅ Trusted' : '⚠️ Build Your Score',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500))),
        const SizedBox(height: 32),
        Text('Score Breakdown', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        ...buckets.map((b) => ListTile(contentPadding: EdgeInsets.zero,
          leading: Icon(b.\$2 ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              color: b.\$2 ? AppColors.success : AppColors.border),
          title: Text(b.\$1, style: TextStyle(fontSize: 14, color: b.\$2 ? AppColors.textPrimary : AppColors.textMuted)),
          trailing: b.\$2 ? null : Text('+10 pts', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)))),
      ]),
    );
  }
}
