import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../community/providers/rooms_provider.dart';
import '../../../community/data/models/room_model.dart';
import '../../../profile/providers/profile_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning ☀️';
    if (h < 17) return 'Good afternoon 🌤️';
    return 'Good evening 🌙';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsAsync   = ref.watch(roomsProvider);
    final profileAsync = ref.watch(profileNotifierProvider);
    final firstName = profileAsync.value?.displayName?.split(' ').first ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_greeting(), style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              const SizedBox(height: 2),
              Text(firstName.isEmpty ? 'Welcome back' : 'Welcome back, \$firstName',
                  style: Theme.of(context).textTheme.headlineMedium),
            ])),
            GestureDetector(onTap: () => context.push('/safety'),
              child: Container(width: 40, height: 40,
                decoration: BoxDecoration(color: AppColors.trust.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(Icons.shield_rounded, color: AppColors.trust, size: 20))),
          ]),
        ).animate().fadeIn(duration: 400.ms)),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GestureDetector(
            onTap: () => context.go('/sparks'),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
                boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 6))],
              ),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text("Today's Sparks are ready ✨",
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('7 connections chosen just for you',
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                ])),
                Container(width: 44, height: 44,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 22)),
              ]),
            ),
          ),
        ).animate(delay: 150.ms).fadeIn()),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Your Communities', style: Theme.of(context).textTheme.titleLarge),
            TextButton(onPressed: () => context.go('/rooms'),
              child: Text('See all', style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600))),
          ]),
        ).animate(delay: 220.ms).fadeIn()),
        const SliverToBoxAdapter(child: SizedBox(height: 10)),
        roomsAsync.when(
          loading: () => const SliverToBoxAdapter(child: SizedBox(height: 80, child: Center(child: CircularProgressIndicator()))),
          error: (_, __) => const SliverToBoxAdapter(child: SizedBox()),
          data: (rooms) {
            final myRooms = rooms.where((r) => r.isMember).take(3).toList();
            if (myRooms.isEmpty) return SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('Join communities that interest you →',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 14))));
            return SliverList(delegate: SliverChildBuilderDelegate(
              (ctx, i) => Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: _RoomTile(room: myRooms[i])
                    .animate(delay: Duration(milliseconds: 260 + i * 60)).fadeIn(),
              ), childCount: myRooms.length));
          },
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ])),
    );
  }
}

class _RoomTile extends StatelessWidget {
  final RoomModel room;
  const _RoomTile({required this.room});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
      border: Border.all(color: AppColors.border)),
    child: Row(children: [
      Container(width: 42, height: 42,
        decoration: BoxDecoration(color: room.color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Center(child: Text(room.emoji, style: const TextStyle(fontSize: 20)))),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(room.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        if (room.latestPost != null)
          Text(room.latestPost!, style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              maxLines: 1, overflow: TextOverflow.ellipsis),
      ])),
      Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 18),
    ]),
  );
}
