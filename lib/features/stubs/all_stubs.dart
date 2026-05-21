// ── STUB SCREENS ── paste each into their respective file paths ──

// ─────────────────────────────────────────────────────────────────────
// lib/features/onboarding/presentation/screens/personality_quiz_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/mantra_button.dart';

class PersonalityQuizScreen extends StatefulWidget {
  const PersonalityQuizScreen({super.key});
  @override
  State<PersonalityQuizScreen> createState() => _PersonalityQuizScreenState();
}

class _PersonalityQuizScreenState extends State<PersonalityQuizScreen> {
  int _step = 0;
  final Map<int, int> _answers = {};

  final _questions = [
    {
      'q': 'Your ideal Saturday?',
      'options': ['🏔️ Hiking / outdoors', '☕ Cozy café', '🛋️ Home, recharging', '🎶 Live event / concert'],
    },
    {
      'q': 'Meeting someone new, you feel...',
      'options': ['😃 Excited', '😅 Nervous but curious', '😌 Calm observer', '🤐 Quiet until comfortable'],
    },
    {
      'q': 'Conversations you love are...',
      'options': ['🌊 Deep & meaningful', '😂 Fun & playful', '🧠 Intellectual', '🎲 Totally random'],
    },
    {
      'q': 'Your emotional style?',
      'options': ['❤️ Openly expressive', '🤔 Thoughtful & reserved', '😄 Humor is my armor', '🌱 Still figuring out'],
    },
    {
      'q': 'You value most:',
      'options': ['🤝 Loyalty', '💡 Intelligence', '💛 Kindness', '🚀 Ambition'],
    },
  ];

  void _selectAnswer(int optionIdx) {
    setState(() => _answers[_step] = optionIdx);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_step < _questions.length - 1) {
        setState(() => _step++);
      } else {
        context.push('/onboarding/interests');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = _questions[_step];
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StepBar(current: _step + 1, total: _questions.length),
              const SizedBox(height: 32),
              Text(
                q['q'] as String,
                style: Theme.of(context).textTheme.headlineMedium,
                key: ValueKey(_step),
              ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0),
              const SizedBox(height: 28),
              ...((q['options'] as List<String>).asMap().entries.map((e) {
                final selected = _answers[_step] == e.key;
                return GestureDetector(
                  onTap: () => _selectAnswer(e.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primaryLight.withOpacity(0.15) : AppColors.surface,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
                      border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 2 : 1),
                    ),
                    child: Text(e.value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: selected ? AppColors.primary : AppColors.textPrimary)),
                  ),
                ).animate(delay: Duration(milliseconds: e.key * 60)).fadeIn(duration: 250.ms).slideX(begin: 0.04, end: 0);
              })),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepBar extends StatelessWidget {
  final int current;
  final int total;
  const _StepBar({required this.current, required this.total});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) => Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: 6),
          height: 4,
          decoration: BoxDecoration(
            color: i < current ? AppColors.primary : AppColors.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      )),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// lib/features/onboarding/presentation/screens/interests_screen.dart

class InterestsScreen extends StatefulWidget {
  const InterestsScreen({super.key});
  @override
  State<InterestsScreen> createState() => _InterestsScreenState();
}

class _InterestsScreenState extends State<InterestsScreen> {
  final Set<String> _selected = {};
  final _interests = ['🎵 Music', '📚 Books', '🏋️ Fitness', '🎬 Movies', '🍕 Food', '✈️ Travel', '🎮 Gaming', '💻 Tech', '🎨 Art', '🌿 Nature', '🏏 Cricket', '🎭 Theatre', '📸 Photography', '🧘 Yoga', '💃 Dance', '🎤 Stand-up', '🍳 Cooking', '🚴 Cycling', '📰 Politics', '🔭 Science', '🛍️ Fashion', '🌙 Astrology', '🐾 Pets', '🏡 Startups'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StepBar(current: 3, total: 6),
                  const SizedBox(height: 24),
                  Text('What are you into?', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 6),
                  Text('Pick at least 3. These help us find your community.', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _interests.map((tag) {
                    final sel = _selected.contains(tag);
                    return GestureDetector(
                      onTap: () => setState(() => sel ? _selected.remove(tag) : _selected.add(tag)),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: sel ? AppColors.primaryLight.withOpacity(0.15) : AppColors.surface,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                          border: Border.all(color: sel ? AppColors.primary : AppColors.border, width: sel ? 2 : 1),
                        ),
                        child: Text(tag, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: sel ? AppColors.primary : AppColors.textSecondary)),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: MantraButton(
                label: 'Continue (${_selected.length} selected)',
                onPressed: _selected.length >= 3 ? () => context.push('/onboarding/voice') : null,
                icon: Icons.arrow_forward_rounded,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// lib/features/onboarding/presentation/screens/photo_upload_screen.dart

class PhotoUploadScreen extends StatelessWidget {
  const PhotoUploadScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: Colors.transparent, actions: [
        TextButton(onPressed: () => context.push('/onboarding/prompts'), child: Text('Skip', style: TextStyle(color: AppColors.textMuted))),
      ]),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StepBar(current: 5, total: 6),
              const SizedBox(height: 24),
              Text('Add your photos', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text('Photos are blurred until you reveal them. You\'re in control.', style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5)),
              const SizedBox(height: 32),
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: List.generate(6, (i) => Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border, style: BorderStyle.solid),
                  ),
                  child: i == 0
                    ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.add_photo_alternate_outlined, color: AppColors.primary, size: 28),
                        const SizedBox(height: 4),
                        Text('Add', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                      ])
                    : Icon(Icons.add_rounded, color: AppColors.border, size: 24),
                )),
              ),
              const Spacer(),
              MantraButton(label: 'Continue', onPressed: () => context.push('/onboarding/prompts'), icon: Icons.arrow_forward_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// lib/features/onboarding/presentation/screens/prompts_screen.dart

class PromptsScreen extends StatelessWidget {
  const PromptsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StepBar(current: 6, total: 6),
              const SizedBox(height: 24),
              Text('Tell your story', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text('Choose 3 prompts. These show the real you.', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              const SizedBox(height: 24),
              ...[
                "The most spontaneous thing I've done...",
                "I'll never shut up about...",
                "My love language is...",
              ].asMap().entries.map((e) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppSpacing.radiusLG), border: Border.all(color: AppColors.border)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.value, style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(
                      style: const TextStyle(fontSize: 14),
                      maxLines: 2,
                      decoration: InputDecoration(hintText: 'Your answer...', hintStyle: TextStyle(color: AppColors.textMuted), border: InputBorder.none, contentPadding: EdgeInsets.zero),
                    ),
                  ],
                ),
              )),
              const Spacer(),
              MantraButton(label: "Let's go! 🌱", onPressed: () => context.push('/onboarding/safety-tour'), icon: Icons.arrow_forward_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// lib/features/onboarding/presentation/screens/safety_tour_screen.dart

class SafetyTourScreen extends StatelessWidget {
  const SafetyTourScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 72, height: 72, decoration: BoxDecoration(color: AppColors.trust.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.shield_rounded, color: AppColors.trust, size: 36)),
              const SizedBox(height: 24),
              Text('You\'re in control.\nAlways.', style: Theme.of(context).textTheme.displaySmall, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text('Mantra is built safety-first. Here\'s what protects you:', style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5), textAlign: TextAlign.center),
              const SizedBox(height: 32),
              ...[
                ('🔒', 'Photos are blurred by default'),
                ('🛡️', 'One-tap SOS alerts your contacts'),
                ('👁️', 'Ghost mode hides you instantly'),
                ('🤖', 'AI monitors for creep behavior'),
                ('🚫', 'No DMs until you\'re ready'),
              ].map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(children: [
                  Text(item.$1, style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 14),
                  Text(item.$2, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                ]),
              )),
              const Spacer(),
              MantraButton(label: "I feel safe. Let's go!", onPressed: () => context.go('/home')),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── More stub screens (minimal) ─────────────────────────────────────

class SparkDetailScreen extends StatelessWidget {
  final String userId;
  const SparkDetailScreen({super.key, required this.userId});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(), body: Center(child: Text('Spark Detail: $userId')));
}

class ConversationsScreen extends ConsumerWidget {
  const ConversationsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('Conversations'), backgroundColor: Colors.transparent),
    body: ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (_, i) => ListTile(
        leading: CircleAvatar(backgroundColor: AppColors.primaryLight.withOpacity(0.3), child: Text(['P','R','S','A','M'][i])),
        title: Text(['Priya', 'Rahul', 'Simran', 'Arjun', 'Meera'][i], style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(['Stage 2 · Getting to know each other', 'Stage 1 · Breaking the ice', 'Stage 3 · Building trust', 'Stage 1 · Breaking the ice', 'Stage 4 · Deep connection'][i], style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
        trailing: Text(['2m', '1h', '3h', '1d', '2d'][i], style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
        onTap: () => context.push('/chat/${i + 1}', extra: {'name': ['Priya','Rahul','Simran','Arjun','Meera'][i], 'trust_score': 82}),
      ),
    ),
  );
}

class RoomDetailScreen extends StatelessWidget {
  final String roomId;
  const RoomDetailScreen({super.key, required this.roomId});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text('Room $roomId')), body: const Center(child: Text('Room posts here')));
}

class RoomPostScreen extends StatelessWidget {
  final String roomId, postId;
  const RoomPostScreen({super.key, required this.roomId, required this.postId});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(), body: Center(child: Text('Post $postId in Room $roomId')));
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('Profile'), backgroundColor: Colors.transparent, actions: [
      TextButton(onPressed: () => context.push('/premium'), child: Text('⭐ Upgrade', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w600))),
    ]),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      Center(child: CircleAvatar(radius: 48, backgroundColor: AppColors.primaryLight.withOpacity(0.3), child: Text('A', style: TextStyle(fontSize: 36, color: AppColors.primary, fontWeight: FontWeight.w700)))),
      const SizedBox(height: 12),
      Center(child: Text('Ankush', style: Theme.of(context).textTheme.headlineMedium)),
      Center(child: Text('25 · Chandigarh', style: TextStyle(color: AppColors.textSecondary, fontSize: 14))),
      const SizedBox(height: 24),
      ListTile(leading: Icon(Icons.edit_rounded, color: AppColors.primary), title: const Text('Edit Profile'), onTap: () => context.push('/profile/edit'), contentPadding: EdgeInsets.zero),
      ListTile(leading: Icon(Icons.shield_rounded, color: AppColors.trust), title: const Text('Trust Score'), trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: Text('87', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w700))), onTap: () => context.push('/profile/trust-score'), contentPadding: EdgeInsets.zero),
      ListTile(leading: Icon(Icons.security_rounded, color: AppColors.secondary), title: const Text('Safety Center'), onTap: () => context.push('/safety'), contentPadding: EdgeInsets.zero),
      ListTile(leading: const Icon(Icons.logout_rounded, color: Colors.red), title: const Text('Log Out', style: TextStyle(color: Colors.red)), onTap: () {}, contentPadding: EdgeInsets.zero),
    ]),
  );
}

class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Edit Profile')), body: const Center(child: Text('Edit profile form')));
}

class TrustScoreScreen extends StatelessWidget {
  const TrustScoreScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Trust Score')), body: const Center(child: Text('Trust score breakdown')));
}

class TrustedContactsScreen extends StatelessWidget {
  const TrustedContactsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Trusted Contacts')), body: const Center(child: Text('Manage trusted contacts')));
}

class SparksRepository {
  Future<List<dynamic>> getDailySparks() async => [];
  Future<void> connect(String userId) async {}
  Future<void> pass(String userId) async {}
  Future<void> save(String userId) async {}
}

class SparksRepositoryImpl extends SparksRepository {}
