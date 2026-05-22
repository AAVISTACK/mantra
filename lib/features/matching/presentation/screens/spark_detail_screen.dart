import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/mantra_button.dart';
import '../../../matching/providers/sparks_provider.dart';

class SparkDetailScreen extends ConsumerWidget {
  final String userId;
  const SparkDetailScreen({super.key, required this.userId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sparksAsync = ref.watch(sparksProvider);
    return sparksAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: \$e'))),
      data: (sparks) {
        if (sparks.isEmpty) return const Scaffold(body: Center(child: Text('No sparks')));
        final spark = sparks.firstWhere((s) => s.userId == userId, orElse: () => sparks.first);
        return Scaffold(
          backgroundColor: AppColors.background,
          extendBodyBehindAppBar: true,
          appBar: AppBar(backgroundColor: Colors.transparent,
            leading: IconButton(onPressed: () => context.pop(),
              icon: Container(width: 36, height: 36,
                decoration: const BoxDecoration(color: Colors.black26, shape: BoxShape.circle),
                child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white)))),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
          floatingActionButton: Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () { ref.read(sparksProvider.notifier).pass(spark.userId); context.pop(); },
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: AppColors.border)),
                child: const Text('Pass'))),
              const SizedBox(width: 12),
              Expanded(child: MantraButton(label: 'Connect ✨',
                onPressed: () { ref.read(sparksProvider.notifier).connect(spark.userId, context: context); context.pop(); })),
            ])),
          body: CustomScrollView(slivers: [
            SliverToBoxAdapter(child: Container(height: 340, color: AppColors.surfaceVariant,
              child: Stack(fit: StackFit.expand, children: [
                Center(child: Icon(Icons.person_rounded, size: 120, color: AppColors.textMuted)),
                Positioned(bottom: 16, left: 16, right: 16,
                  child: Container(padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(AppSpacing.radiusLG)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('\${spark.displayName}, \${spark.age}',
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                      Text(spark.city, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                    ]))),
              ]))),
            SliverPadding(padding: const EdgeInsets.all(AppSpacing.screenPadding),
              sliver: SliverList(delegate: SliverChildListDelegate([
                Wrap(spacing: 8, children: [
                  _Badge('✨ \${spark.compatibilityScore}% match', AppColors.primary),
                  if (spark.isVerified) _Badge('✅ Verified', AppColors.success),
                  _Badge('🛡️ \${spark.trustScore.toInt()} trust', AppColors.trust),
                ]),
                if (spark.interests.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text('Interests', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8,
                    children: spark.interests.map((t) => _Tag(t)).toList()),
                ],
                const SizedBox(height: 80),
              ]))),
          ]),
        );
      },
    );
  }
}
class _Badge extends StatelessWidget {
  final String text; final Color color;
  const _Badge(this.text, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(AppSpacing.radiusFull), border: Border.all(color: color.withOpacity(0.3))),
    child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)));
}
class _Tag extends StatelessWidget {
  final String text; const _Tag(this.text);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.radiusFull), border: Border.all(color: AppColors.border)),
    child: Text(text, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)));
}
