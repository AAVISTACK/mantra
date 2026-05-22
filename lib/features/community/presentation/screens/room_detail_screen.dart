import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../providers/rooms_provider.dart';

class RoomDetailScreen extends ConsumerWidget {
  final String roomId;
  const RoomDetailScreen({super.key, required this.roomId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsAsync = ref.watch(roomsProvider);
    return roomsAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: \$e'))),
      data: (rooms) {
        if (rooms.isEmpty) return const Scaffold(body: Center(child: Text('Room not found')));
        final room = rooms.firstWhere((r) => r.id == roomId, orElse: () => rooms.first);
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(title: Text(room.name), backgroundColor: Colors.transparent,
            actions: [if (!room.isMember) TextButton(
              onPressed: () => ref.read(roomsProvider.notifier).joinRoom(roomId),
              child: Text('Join', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)))]),
          body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(room.emoji, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 12),
            Text(room.name, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(room.description, style: TextStyle(color: AppColors.textSecondary, fontSize: 14), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('\${room.memberCount} members', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ])),
        );
      },
    );
  }
}
