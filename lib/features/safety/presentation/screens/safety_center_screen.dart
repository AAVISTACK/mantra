// lib/features/safety/presentation/screens/safety_center_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';

class SafetyCenterScreen extends ConsumerWidget {
  const SafetyCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Safety Center'),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SOS Card — always first, always prominent
            _SOSCard(onTap: () => context.push('/safety/sos'))
                .animate()
                .fadeIn(duration: 300.ms)
                .slideY(begin: 0.08, end: 0),

            const SizedBox(height: 24),

            Text(
              'Your safety controls',
              style: Theme.of(context).textTheme.titleLarge,
            ).animate(delay: 100.ms).fadeIn(),

            const SizedBox(height: 14),

            _SafetyOption(
              icon: Icons.people_alt_rounded,
              iconColor: AppColors.trust,
              title: 'Trusted Contacts',
              subtitle: 'People who get alerted if you need help',
              badge: '2 added',
              onTap: () => context.push('/safety/trusted-contacts'),
            ).animate(delay: 150.ms).fadeIn().slideX(begin: 0.04, end: 0),

            _SafetyOption(
              icon: Icons.visibility_off_rounded,
              iconColor: AppColors.secondary,
              title: 'Ghost Mode',
              subtitle: 'Go invisible — browse without being seen',
              trailing: _ToggleSwitch(),
              onTap: null,
            ).animate(delay: 200.ms).fadeIn().slideX(begin: 0.04, end: 0),

            _SafetyOption(
              icon: Icons.no_photography_rounded,
              iconColor: AppColors.warning,
              title: 'Screenshot Alerts',
              subtitle: 'Get notified if someone screenshots your chat',
              trailing: _ToggleSwitch(initialValue: true),
              onTap: null,
            ).animate(delay: 250.ms).fadeIn().slideX(begin: 0.04, end: 0),

            _SafetyOption(
              icon: Icons.nightlight_round,
              iconColor: AppColors.primary,
              title: 'Night Mode Protection',
              subtitle: 'Delay messages from new connections after 11 PM',
              trailing: _ToggleSwitch(initialValue: true),
              onTap: null,
            ).animate(delay: 300.ms).fadeIn().slideX(begin: 0.04, end: 0),

            _SafetyOption(
              icon: Icons.event_available_rounded,
              iconColor: AppColors.success,
              title: 'Meetup Check-In',
              subtitle: 'Set up a safety check-in for real dates',
              onTap: () {},
            ).animate(delay: 350.ms).fadeIn().slideX(begin: 0.04, end: 0),

            const SizedBox(height: 24),

            Text(
              'Privacy controls',
              style: Theme.of(context).textTheme.titleLarge,
            ).animate(delay: 380.ms).fadeIn(),

            const SizedBox(height: 14),

            _SafetyOption(
              icon: Icons.blur_on_rounded,
              iconColor: AppColors.primary,
              title: 'Always Blur My Photos',
              subtitle: 'Never reveal photos automatically',
              trailing: _ToggleSwitch(),
              onTap: null,
            ).animate(delay: 400.ms).fadeIn().slideX(begin: 0.04, end: 0),

            _SafetyOption(
              icon: Icons.location_off_rounded,
              iconColor: AppColors.secondary,
              title: 'Location Privacy',
              subtitle: 'Show only your city, never neighborhood',
              trailing: _ToggleSwitch(initialValue: true),
              onTap: null,
            ).animate(delay: 430.ms).fadeIn().slideX(begin: 0.04, end: 0),

            _SafetyOption(
              icon: Icons.timer_off_rounded,
              iconColor: AppColors.textSecondary,
              title: 'Hide Last Active',
              subtitle: "Don't show when you were last online",
              trailing: _ToggleSwitch(),
              onTap: null,
            ).animate(delay: 460.ms).fadeIn().slideX(begin: 0.04, end: 0),

            const SizedBox(height: 24),

            // Block list
            _SafetyOption(
              icon: Icons.block_rounded,
              iconColor: AppColors.error,
              title: 'Blocked Users',
              subtitle: 'Manage people you have blocked',
              badge: 'View',
              onTap: () {},
            ).animate(delay: 490.ms).fadeIn().slideX(begin: 0.04, end: 0),

            const SizedBox(height: 32),

            // Help section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.trust.withOpacity(0.06),
                borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
                border: Border.all(color: AppColors.trust.withOpacity(0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.support_agent_rounded,
                          color: AppColors.trust, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Need help?',
                        style: TextStyle(
                          color: AppColors.trust,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Our safety team is available 8 AM – 12 AM IST. Reports are reviewed within 4 hours.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {},
                    child: Text(
                      'Contact Safety Team →',
                      style: TextStyle(
                        color: AppColors.trust,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate(delay: 520.ms).fadeIn(),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─── SOS Card ──────────────────────────────────────────
class _SOSCard extends StatelessWidget {
  final VoidCallback onTap;
  const _SOSCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.trust,
              AppColors.trust.withBlue(200),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
          boxShadow: [
            BoxShadow(
              color: AppColors.trust.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shield_rounded,
                color: Colors.white,
                size: 28,
              ),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(
                    begin: 1.0,
                    end: 1.06,
                    duration: 1500.ms,
                    curve: Curves.easeInOut),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SOS — Emergency Alert',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'One tap sends your location to trusted contacts and archives this conversation.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white.withOpacity(0.7),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Safety Option Tile ────────────────────────────────
class _SafetyOption extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? badge;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SafetyOption({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.badge,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
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
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
            if (badge != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: Text(
                  badge!,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            if (trailing == null && badge == null && onTap != null)
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: AppColors.textMuted,
              ),
          ],
        ),
      ),
    );
  }
}

class _ToggleSwitch extends StatefulWidget {
  final bool initialValue;
  const _ToggleSwitch({this.initialValue = false});

  @override
  State<_ToggleSwitch> createState() => _ToggleSwitchState();
}

class _ToggleSwitchState extends State<_ToggleSwitch> {
  late bool _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: 0.85,
      child: Switch(
        value: _value,
        onChanged: (v) {
          HapticFeedback.selectionClick();
          setState(() => _value = v);
        },
        activeColor: AppColors.primary,
        activeTrackColor: AppColors.primaryLight.withOpacity(0.4),
      ),
    );
  }
}
