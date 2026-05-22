import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/mantra_button.dart';
import '../../providers/onboarding_provider.dart';

class PromptsScreen extends ConsumerStatefulWidget {
  const PromptsScreen({super.key});
  @override
  ConsumerState<PromptsScreen> createState() => _State();
}

class _State extends ConsumerState<PromptsScreen> {
  final _prompts = [
    "The most spontaneous thing I've done...",
    "I'll never shut up about...",
    "My love language is...",
  ];
  late final List<TextEditingController> _ctrls;

  @override
  void initState() {
    super.initState();
    _ctrls = List.generate(_prompts.length, (_) => TextEditingController());
  }
  @override
  void dispose() { for (final c in _ctrls) c.dispose(); super.dispose(); }

  bool get _hasOne => _ctrls.any((c) => c.text.trim().isNotEmpty);

  void _continue() {
    ref.read(onboardingProvider.notifier).setPromptResponses(_ctrls.map((c) => c.text.trim()).toList());
    context.push('/onboarding/safety-tour');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: SafeArea(child: Column(children: [
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Tell your story', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text('Answer at least 1 prompt. These show the real you.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 24),
            ...List.generate(_prompts.length, (i) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface, borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_prompts[i], style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(controller: _ctrls[i], onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontSize: 14), maxLines: 3, maxLength: 200,
                  decoration: InputDecoration(
                    hintText: 'Your answer...', hintStyle: TextStyle(color: AppColors.textMuted),
                    border: InputBorder.none, contentPadding: EdgeInsets.zero,
                    counterStyle: TextStyle(color: AppColors.textMuted, fontSize: 11),
                  )),
              ]),
            )),
          ]),
        )),
        Padding(padding: const EdgeInsets.all(20), child: MantraButton(
          label: "Let's go! 🌱", onPressed: _hasOne ? _continue : null,
          icon: Icons.arrow_forward_rounded,
        )),
      ])),
    );
  }
}
