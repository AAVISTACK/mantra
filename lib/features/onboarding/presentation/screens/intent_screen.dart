import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/mantra_button.dart';

class IntentScreen extends ConsumerStatefulWidget {
  const IntentScreen({super.key});

  @override
  ConsumerState<IntentScreen> createState() => _IntentScreenState();
}

class _IntentScreenState extends ConsumerState<IntentScreen> {
  String? _selectedIntent;

  final _intents = [
    {
      'id': 'meaningful',
      'emoji': '🌱',
      'title': 'Something meaningful',
      'subtitle': 'I want to find someone special, slowly.',
    },
    {
      'id': 'friendship',
      'emoji': '🤝',
      'title': 'Genuine friendship',
      'subtitle': 'Deep, meaningful friendships matter to me.',
    },
    {
      'id': 'conversations',
      'emoji': '💬',
      'title': 'Interesting conversations',
      'subtitle': 'I love talking to interesting people.',
    },
    {
      'id': 'exploring',
      'emoji': '✨',
      'title': 'Just exploring',
      'subtitle': "I'm not sure yet — I'm open to anything.",
    },
    {
      'id': 'partner',
      'emoji': '🏡',
      'title': 'A life partner',
      'subtitle': 'I want to find someone to build a life with.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              // Step indicator
              _StepIndicator(current: 1, total: 6),

              const SizedBox(height: 32),

              Text(
                'What brings\nyou to Mantra?',
                style: AppTextStyles.heroDisplay,
              ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),

              const SizedBox(height: 8),

              Text(
                'All answers are equally welcome here.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 14),
              ).animate(delay: 100.ms).fadeIn(),

              const SizedBox(height: 28),

              Expanded(
                child: ListView.separated(
                  itemCount: _intents.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final intent = _intents[i];
                    final isSelected = _selectedIntent == intent['id'];
                    return _IntentCard(
                      emoji: intent['emoji']!,
                      title: intent['title']!,
                      subtitle: intent['subtitle']!,
                      isSelected: isSelected,
                      onTap: () => setState(() => _selectedIntent = intent['id']),
                    )
                        .animate(delay: Duration(milliseconds: 150 + i * 80))
                        .fadeIn(duration: 300.ms)
                        .slideX(begin: 0.05, end: 0);
                  },
                ),
              ),

              const SizedBox(height: 16),

              MantraButton(
                label: 'Continue',
                onPressed: _selectedIntent != null
                    ? () => context.push('/onboarding/quiz')
                    : null,
                icon: Icons.arrow_forward_rounded,
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntentCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _IntentCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryLight.withOpacity(0.15)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.primary : Colors.transparent,
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int current;
  final int total;

  const _StepIndicator({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final active = i < current;
        return Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: 6),
            height: 4,
            decoration: BoxDecoration(
              color: active ? AppColors.primary : AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}
