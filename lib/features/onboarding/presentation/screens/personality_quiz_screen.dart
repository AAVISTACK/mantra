import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../providers/onboarding_provider.dart';

class PersonalityQuizScreen extends ConsumerStatefulWidget {
  const PersonalityQuizScreen({super.key});
  @override
  ConsumerState<PersonalityQuizScreen> createState() => _State();
}

class _State extends ConsumerState<PersonalityQuizScreen> {
  int _step = 0;
  final _questions = [
    {'q': 'Your ideal Saturday?', 'options': ['🏔️ Hiking / outdoors','☕ Cozy café','🛋️ Home, recharging','🎶 Live event']},
    {'q': 'Meeting someone new, you feel...', 'options': ['😃 Excited','😅 Nervous but curious','😌 Calm observer','🤐 Quiet until comfortable']},
    {'q': 'Conversations you love are...', 'options': ['🌊 Deep & meaningful','😂 Fun & playful','🧠 Intellectual','🎲 Totally random']},
    {'q': 'Your emotional style?', 'options': ['❤️ Openly expressive','🤔 Thoughtful & reserved','😄 Humor is my armor','🌱 Still figuring out']},
    {'q': 'You value most:', 'options': ['🤝 Loyalty','💡 Intelligence','💛 Kindness','🚀 Ambition']},
  ];

  void _select(int idx) {
    ref.read(onboardingProvider.notifier).setQuizAnswer(_step, idx);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      if (_step < _questions.length - 1) setState(() => _step++);
      else context.push('/onboarding/interests');
    });
  }

  @override
  Widget build(BuildContext context) {
    final answers = ref.watch(onboardingProvider).quizAnswers;
    final q = _questions[_step];
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: SafeArea(child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _StepBar(current: _step + 1, total: _questions.length),
          const SizedBox(height: 32),
          Text(q['q'] as String, style: Theme.of(context).textTheme.headlineMedium, key: ValueKey(_step))
              .animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0),
          const SizedBox(height: 28),
          ...(q['options'] as List<String>).asMap().entries.map((e) {
            final sel = answers[_step] == e.key;
            return GestureDetector(
              onTap: () => _select(e.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: sel ? AppColors.primaryLight.withOpacity(0.15) : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
                  border: Border.all(color: sel ? AppColors.primary : AppColors.border, width: sel ? 2 : 1),
                ),
                child: Text(e.value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500,
                    color: sel ? AppColors.primary : AppColors.textPrimary)),
              ),
            ).animate(delay: Duration(milliseconds: e.key * 60)).fadeIn(duration: 250.ms);
          }),
        ]),
      )),
    );
  }
}

class _StepBar extends StatelessWidget {
  final int current, total;
  const _StepBar({required this.current, required this.total});
  @override
  Widget build(BuildContext context) => Row(children: List.generate(total, (i) => Expanded(child: Container(
    margin: const EdgeInsets.only(right: 6), height: 4,
    decoration: BoxDecoration(
      color: i < current ? AppColors.primary : AppColors.border,
      borderRadius: BorderRadius.circular(2),
    ),
  ))));
}
