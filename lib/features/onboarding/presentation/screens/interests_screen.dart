import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/mantra_button.dart';
import '../../providers/onboarding_provider.dart';

class InterestsScreen extends ConsumerWidget {
  const InterestsScreen({super.key});
  static const _tags = [
    '🎵 Music','📚 Books','🏋️ Fitness','🎬 Movies','🍕 Food','✈️ Travel',
    '🎮 Gaming','💻 Tech','🎨 Art','🌿 Nature','🏏 Cricket','🎭 Theatre',
    '📸 Photography','🧘 Yoga','💃 Dance','🎤 Stand-up','🍳 Cooking',
    '🚴 Cycling','📰 Politics','🔭 Science','🛍️ Fashion','🌙 Astrology',
    '🐾 Pets','🏡 Startups',
  ];
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(onboardingProvider).interests;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: SafeArea(child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 8),
            Text("What are you into?", style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 6),
            Text("Pick at least 3. These help us find your community.",
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          ]),
        ),
        Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(
            spacing: 10, runSpacing: 10,
            children: _tags.map((tag) {
              final sel = selected.contains(tag);
              return GestureDetector(
                onTap: () => ref.read(onboardingProvider.notifier).toggleInterest(tag),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.primaryLight.withOpacity(0.15) : AppColors.surface,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                    border: Border.all(color: sel ? AppColors.primary : AppColors.border, width: sel ? 2 : 1),
                  ),
                  child: Text(tag, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                      color: sel ? AppColors.primary : AppColors.textSecondary)),
                ),
              );
            }).toList(),
          ),
        )),
        Padding(
          padding: const EdgeInsets.all(20),
          child: MantraButton(
            label: 'Continue (\${selected.length} selected)',
            onPressed: selected.length >= 3 ? () => context.push('/onboarding/voice') : null,
            icon: Icons.arrow_forward_rounded,
          ),
        ),
      ])),
    );
  }
}
