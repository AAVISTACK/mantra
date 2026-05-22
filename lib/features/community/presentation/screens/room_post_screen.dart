import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class RoomPostScreen extends StatelessWidget {
  final String roomId, postId;
  const RoomPostScreen({super.key, required this.roomId, required this.postId});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('Post'), backgroundColor: Colors.transparent),
    body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.article_rounded, size: 64, color: AppColors.textMuted),
      const SizedBox(height: 16),
      const Text('Post Detail', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
    ])),
  );
}
