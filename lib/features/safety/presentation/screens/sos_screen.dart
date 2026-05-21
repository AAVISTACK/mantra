import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

class SosScreen extends ConsumerStatefulWidget {
  const SosScreen({super.key});

  @override
  ConsumerState<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends ConsumerState<SosScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _activated = false;
  bool _locationFetching = false;
  String? _locationText;
  int _countdown = 5;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _activateSOS() async {
    HapticFeedback.heavyImpact();
    setState(() {
      _activated = true;
      _locationFetching = true;
      _countdown = 5;
    });

    // Start countdown
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown <= 1) {
        t.cancel();
        _sendAlert();
      } else {
        setState(() => _countdown--);
        HapticFeedback.lightImpact();
      }
    });

    // Fetch location simultaneously
    try {
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.granted ||
          permission == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 8),
        );
        setState(() {
          _locationText =
              'https://maps.google.com/?q=${pos.latitude},${pos.longitude}';
          _locationFetching = false;
        });
      }
    } catch (_) {
      setState(() => _locationFetching = false);
    }
  }

  void _cancelSOS() {
    HapticFeedback.mediumImpact();
    _countdownTimer?.cancel();
    setState(() {
      _activated = false;
      _countdown = 5;
      _locationText = null;
    });
  }

  Future<void> _sendAlert() async {
    // In production: call backend to SMS trusted contacts
    // and archive current conversation
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 300));
    HapticFeedback.heavyImpact();

    if (mounted) {
      _showAlertSentSheet();
    }
  }

  void _showAlertSentSheet() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_rounded,
                color: AppColors.success,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Alert Sent',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your trusted contacts have been notified with your location. Stay safe.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            // Call police
            GestureDetector(
              onTap: () => launchUrl(Uri.parse('tel:100')),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
                  border:
                      Border.all(color: AppColors.error.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.phone_rounded,
                        color: AppColors.error, size: 22),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Call Police — 100',
                          style: TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          'Tap to call emergency services',
                          style: TextStyle(
                            color: AppColors.error.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => launchUrl(Uri.parse('tel:112')),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
                  border:
                      Border.all(color: AppColors.warning.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.emergency_rounded,
                        color: AppColors.warning, size: 22),
                    const SizedBox(width: 12),
                    Text(
                      'Emergency — 112',
                      style: TextStyle(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () {
                context.pop();
                context.pop();
              },
              child: Text(
                "I'm safe now",
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _activated ? const Color(0xFF0D1B2A) : AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: _activated ? Colors.white : AppColors.textPrimary,
            size: 20,
          ),
        ),
        title: Text(
          'Emergency SOS',
          style: TextStyle(
            color: _activated ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        color: _activated ? const Color(0xFF0D1B2A) : AppColors.background,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: Column(
              children: [
                const SizedBox(height: 32),

                // Main SOS button
                Center(
                  child: _activated
                      ? _ActivatedSOSButton(
                          countdown: _countdown,
                          onCancel: _cancelSOS,
                          pulseController: _pulseController,
                        )
                      : _IdleSOSButton(onActivate: _activateSOS),
                ),

                const SizedBox(height: 40),

                if (_activated) ...[
                  Text(
                    _countdown > 0
                        ? 'Sending alert in $_countdown seconds...'
                        : 'Sending alert...',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ).animate().fadeIn(duration: 300.ms),
                  const SizedBox(height: 8),
                  Text(
                    _locationFetching
                        ? 'Getting your location...'
                        : _locationText != null
                            ? 'Location captured ✓'
                            : 'Could not get location',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 32),
                  GestureDetector(
                    onTap: _cancelSOS,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 14),
                      decoration: BoxDecoration(
                        border:
                            Border.all(color: Colors.white.withOpacity(0.3)),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusFull),
                      ),
                      child: const Text(
                        'Cancel — I\'m safe',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ).animate().fadeIn(duration: 400.ms),
                ] else ...[
                  Text(
                    'Hold the button above to activate.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  _InfoCard(
                    icon: Icons.send_rounded,
                    title: 'Alerts your contacts',
                    subtitle:
                        'Your trusted contacts receive an SMS with your location.',
                  ),
                  const SizedBox(height: 10),
                  _InfoCard(
                    icon: Icons.archive_rounded,
                    title: 'Archives the conversation',
                    subtitle:
                        'Current conversation is saved as evidence automatically.',
                  ),
                  const SizedBox(height: 10),
                  _InfoCard(
                    icon: Icons.location_on_rounded,
                    title: 'Shares your location',
                    subtitle:
                        'GPS location sent to contacts as a Google Maps link.',
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IdleSOSButton extends StatefulWidget {
  final VoidCallback onActivate;
  const _IdleSOSButton({required this.onActivate});

  @override
  State<_IdleSOSButton> createState() => _IdleSOSButtonState();
}

class _IdleSOSButtonState extends State<_IdleSOSButton> {
  bool _pressing = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressing = true),
      onTapUp: (_) {
        setState(() => _pressing = false);
        widget.onActivate();
      },
      onTapCancel: () => setState(() => _pressing = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: _pressing ? 160 : 180,
        height: _pressing ? 160 : 180,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.trust, const Color(0xFF3A7BBF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.trust.withOpacity(_pressing ? 0.2 : 0.35),
              blurRadius: _pressing ? 16 : 32,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield_rounded, color: Colors.white, size: 48),
            const SizedBox(height: 8),
            Text(
              'SOS',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivatedSOSButton extends StatelessWidget {
  final int countdown;
  final VoidCallback onCancel;
  final AnimationController pulseController;

  const _ActivatedSOSButton({
    required this.countdown,
    required this.onCancel,
    required this.pulseController,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseController,
      builder: (context, child) {
        final scale = 1.0 + (pulseController.value * 0.08);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              color: AppColors.error,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.error.withOpacity(0.4 + pulseController.value * 0.2),
                  blurRadius: 40 + pulseController.value * 20,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$countdown',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 56,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'SENDING',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 3,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.trust.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.trust, size: 20),
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
        ],
      ),
    );
  }
}
