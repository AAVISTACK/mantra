import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

class KycScreen extends StatelessWidget {
  const KycScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: Colors.transparent,
        leading: IconButton(onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20))),
      body: SafeArea(child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 16),
          Text('Verify your identity', style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 8),
          Text('This keeps Mantra safe for everyone. Your data is never shared.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5)),
          const SizedBox(height: 40),
          _Option('🪪', 'DigiLocker (Recommended)', 'Fastest. Uses your Aadhaar via official govt system.',
              () => context.push('/auth/liveness')),
          const SizedBox(height: 12),
          _Option('📱', 'Aadhaar OTP', 'Enter last 4 digits + receive OTP on registered number.',
              () => context.push('/auth/liveness')),
          const SizedBox(height: 12),
          _Option('📄', 'Manual Upload', 'Upload govt ID. Reviewed within 24 hours.',
              () => context.push('/auth/liveness')),
          const Spacer(),
          Text('🔒 We only verify your age and gender. Your Aadhaar number is never stored.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.5),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
        ]),
      )),
    );
  }
}

class _Option extends StatelessWidget {
  final String icon, title, subtitle;
  final VoidCallback onTap;
  const _Option(this.icon, this.title, this.subtitle, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
        border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Text(icon, style: const TextStyle(fontSize: 28)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4)),
        ])),
        Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMuted),
      ]),
    ));
}
