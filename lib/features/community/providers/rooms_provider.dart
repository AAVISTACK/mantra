// lib/features/community/providers/rooms_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/room_model.dart';

final roomsProvider =
    AsyncNotifierProvider<RoomsNotifier, List<RoomModel>>(RoomsNotifier.new);

class RoomsNotifier extends AsyncNotifier<List<RoomModel>> {
  @override
  Future<List<RoomModel>> build() async {
    await Future.delayed(const Duration(milliseconds: 600)); // simulate network
    return RoomModel.mockRooms();
  }

  Future<void> joinRoom(String roomId) async {
    final rooms = state.value ?? [];
    state = AsyncData(rooms
        .map((r) => r.id == roomId
            ? RoomModel(
                id: r.id,
                name: r.name,
                description: r.description,
                emoji: r.emoji,
                type: r.type,
                memberCount: r.memberCount + 1,
                isMember: true,
                isFeatured: r.isFeatured,
                isWomenOnly: r.isWomenOnly,
                latestPost: r.latestPost,
                color: r.color,
              )
            : r)
        .toList());
  }
}

// ─────────────────────────────────────────────────────────────────────
// lib/features/home/presentation/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../community/data/models/room_model.dart';
import '../../../community/providers/rooms_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsAsync = ref.watch(roomsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Good evening 🌙',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Welcome back, Ankush',
                            style:
                                Theme.of(context).textTheme.headlineMedium,
                          ),
                        ],
                      ),
                    ),
                    // Safety always accessible
                    GestureDetector(
                      onTap: () => context.push('/safety'),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.trust.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.shield_rounded,
                          color: AppColors.trust,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () {},
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Icon(
                          Icons.notifications_none_rounded,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // Mood check-in
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _MoodCheckIn(),
              ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.06, end: 0),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // Today's Sparks preview
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _SparksBanner(onTap: () => context.go('/sparks')),
              ).animate(delay: 180.ms).fadeIn().slideY(begin: 0.06, end: 0),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // Communities header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Your Communities',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    TextButton(
                      onPressed: () => context.go('/rooms'),
                      child: Text(
                        'See all',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate(delay: 240.ms).fadeIn(),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 10)),

            // Community rooms list
            roomsAsync.when(
              loading: () => const SliverToBoxAdapter(child: SizedBox(height: 100)),
              error: (_, __) => const SliverToBoxAdapter(child: SizedBox()),
              data: (rooms) {
                final myRooms = rooms.where((r) => r.isMember).take(3).toList();
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                      child: _HomeRoomTile(room: myRooms[i])
                          .animate(
                              delay: Duration(milliseconds: 280 + i * 60))
                          .fadeIn(duration: 250.ms)
                          .slideX(begin: 0.04, end: 0),
                    ),
                    childCount: myRooms.length,
                  ),
                );
              },
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

class _MoodCheckIn extends StatefulWidget {
  @override
  State<_MoodCheckIn> createState() => _MoodCheckInState();
}

class _MoodCheckInState extends State<_MoodCheckIn> {
  final _moods = ['😴', '😊', '🔥', '🥺', '💭', '🎉'];
  int? _selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How are you feeling today?',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _moods.asMap().entries.map((e) {
              final selected = _selected == e.key;
              return GestureDetector(
                onTap: () => setState(() => _selected = e.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primaryLight.withOpacity(0.2)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? AppColors.primary
                          : Colors.transparent,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      e.value,
                      style: TextStyle(
                        fontSize: selected ? 26 : 22,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _SparksBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _SparksBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.25),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Today's Sparks are ready ✨",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '7 connections chosen just for you',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeRoomTile extends StatelessWidget {
  final RoomModel room;
  const _HomeRoomTile({required this.room});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: room.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text(room.emoji, style: TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  room.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (room.latestPost != null)
                  Text(
                    room.latestPost!,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textMuted,
            size: 18,
          ),
        ],
      ),
    );
  }
}
