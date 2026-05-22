import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../profile/providers/profile_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileNotifierProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Profile'), backgroundColor: Colors.transparent, elevation: 0,
        actions: [TextButton(onPressed: () => context.push('/premium'),
          child: Text('⭐ Upgrade', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w600)))]),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: \$e')),
        data: (profile) {
          final name  = profile?.displayNameOrFallback ?? 'You';
          final loc   = profile?.locationAge ?? '';
          final trust = profile?.trustScore?.toInt() ?? 50;
          return ListView(padding: const EdgeInsets.all(AppSpacing.screenPadding), children: [
            Center(child: CircleAvatar(radius: 48,
              backgroundColor: AppColors.primaryLight.withOpacity(0.3),
              child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(fontSize: 36, color: AppColors.primary, fontWeight: FontWeight.w700)))),
            const SizedBox(height: 12),
            Center(child: Text(name, style: Theme.of(context).textTheme.headlineMedium)),
            if (loc.isNotEmpty) ...[const SizedBox(height: 4),
              Center(child: Text(loc, style: TextStyle(color: AppColors.textSecondary, fontSize: 14)))],
            const SizedBox(height: 24),
            _Item(Icons.edit_rounded, 'Edit Profile', onTap: () => context.push('/profile/edit')),
            _Item(Icons.shield_rounded, 'Trust Score', iconColor: AppColors.trust,
              trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: Text('\$trust', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w700))),
              onTap: () => context.push('/profile/trust-score')),
            _Item(Icons.security_rounded, 'Safety Center', iconColor: AppColors.secondary,
              onTap: () => context.push('/safety')),
            _Item(Icons.people_outline_rounded, 'Trusted Contacts', iconColor: AppColors.trust,
              onTap: () => context.push('/safety/trusted-contacts')),
            const Divider(height: 32),
            _Item(Icons.logout_rounded, 'Log Out', iconColor: Colors.red, labelColor: Colors.red,
              onTap: () async {
                final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
                  title: const Text('Log out?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Log out')),
                  ]));
                if (ok == true) await ref.read(authControllerProvider.notifier).logout();
              }),
          ]);
        },
      ),
    );
  }
}

class _Item extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? iconColor, labelColor;
  final Widget? trailing;
  final VoidCallback onTap;
  const _Item(this.icon, this.label, {this.iconColor, this.labelColor, this.trailing, required this.onTap});
  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap, contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: iconColor ?? AppColors.primary),
    title: Text(label, style: TextStyle(color: labelColor ?? AppColors.textPrimary, fontWeight: FontWeight.w500)),
    trailing: trailing ?? Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
  );
}
