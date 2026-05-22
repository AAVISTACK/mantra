import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/mantra_button.dart';

class LivenessScreen extends StatelessWidget {
  const LivenessScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: SafeArea(child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(children: [
          const SizedBox(height: 32),
          Text('Face Verification', style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 12),
          Text("Look at the camera and follow the prompts.",
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
              textAlign: TextAlign.center),
          const SizedBox(height: 40),
          Container(width: 240, height: 240,
            decoration: BoxDecoration(color: AppColors.surfaceVariant, shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 3)),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.face_rounded, size: 80, color: AppColors.textMuted),
              const SizedBox(height: 8),
              Text('Camera Preview', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            ])),
          const SizedBox(height: 16),
          Text('⚠️ Live face detection integration required before launch.',
              style: TextStyle(color: AppColors.warning, fontSize: 12),
              textAlign: TextAlign.center),
          const Spacer(),
          MantraButton(label: 'Continue to Onboarding', onPressed: () => context.go('/onboarding/intent')),
          const SizedBox(height: 16),
        ]),
      )),
    );
  }
}
