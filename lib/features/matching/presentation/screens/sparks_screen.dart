import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../matching/data/models/spark_model.dart';
import '../../../matching/providers/sparks_provider.dart';

class SparksScreen extends ConsumerWidget {
  const SparksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sparksAsync = ref.watch(sparksProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SparksHeader(),
            Expanded(
              child: sparksAsync.when(
                loading: () => const _SparksShimmer(),
                error: (e, _) => _ErrorState(message: e.toString()),
                data: (sparks) {
                  if (sparks.isEmpty) return const _EmptyState();
                  return _SparksList(sparks: sparks);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SparksHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Today's Sparks ✨",
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 2),
              Text(
                '7 connections chosen for you',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withOpacity(0.15),
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              border: Border.all(
                color: AppColors.primaryLight.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.primary,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  '5 left',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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

class _SparksList extends StatelessWidget {
  final List<SparkModel> sparks;

  const _SparksList({required this.sparks});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      itemCount: sparks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, i) {
        return SparkCard(spark: sparks[i])
            .animate(delay: Duration(milliseconds: i * 80))
            .fadeIn(duration: 300.ms)
            .slideY(begin: 0.08, end: 0);
      },
    );
  }
}

class SparkCard extends ConsumerStatefulWidget {
  final SparkModel spark;

  const SparkCard({super.key, required this.spark});

  @override
  ConsumerState<SparkCard> createState() => _SparkCardState();
}

class _SparkCardState extends ConsumerState<SparkCard>
    with SingleTickerProviderStateMixin {
  bool _isPlayingVoice = false;
  bool _actionTaken = false;

  void _onConnect() {
    HapticFeedback.mediumImpact();
    setState(() => _actionTaken = true);
    ref.read(sparksProvider.notifier).connect(widget.spark.userId);
  }

  void _onPass() {
    HapticFeedback.lightImpact();
    setState(() => _actionTaken = true);
    ref.read(sparksProvider.notifier).pass(widget.spark.userId);
  }

  void _onSave() {
    HapticFeedback.selectionClick();
    ref.read(sparksProvider.notifier).save(widget.spark.userId);
  }

  @override
  Widget build(BuildContext context) {
    final spark = widget.spark;

    return GestureDetector(
      onTap: () => context.push('/sparks/${spark.userId}', extra: spark),
      child: AnimatedOpacity(
        opacity: _actionTaken ? 0.4 : 1.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top section: blurred photo + info
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Blurred photo avatar
                    _BlurredAvatar(
                      imageUrl: spark.profilePhotoUrl,
                      isBlurred: spark.photosBlurred,
                    ),
                    const SizedBox(width: 14),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                spark.displayName,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 6),
                              if (spark.isVerified)
                                Icon(
                                  Icons.verified_rounded,
                                  color: AppColors.trust,
                                  size: 16,
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${spark.age} · ${spark.city}',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Trust score pill
                          _TrustPill(score: spark.trustScore),
                        ],
                      ),
                    ),

                    // Compatibility score
                    _CompatibilityBadge(score: spark.compatibilityScore),
                  ],
                ),
              ),

              // Voice intro button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _VoiceIntroButton(
                  isPlaying: _isPlayingVoice,
                  onTap: () => setState(() => _isPlayingVoice = !_isPlayingVoice),
                ),
              ),

              const SizedBox(height: 12),

              // Interest tags
              if (spark.interests.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: spark.interests.take(4).map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusFull),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

              const SizedBox(height: 16),

              // Action buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    // Pass button
                    Expanded(
                      child: _ActionButton(
                        label: 'Pass',
                        icon: Icons.close_rounded,
                        color: AppColors.textMuted,
                        backgroundColor: AppColors.surfaceVariant,
                        onTap: _actionTaken ? null : _onPass,
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Save button
                    _ActionButton(
                      label: '',
                      icon: Icons.bookmark_outline_rounded,
                      color: AppColors.warning,
                      backgroundColor: AppColors.warningLight.withOpacity(0.3),
                      onTap: _onSave,
                      isIconOnly: true,
                    ),
                    const SizedBox(width: 10),

                    // Connect button
                    Expanded(
                      child: _ActionButton(
                        label: 'Connect',
                        icon: Icons.favorite_rounded,
                        color: Colors.white,
                        backgroundColor: AppColors.primary,
                        onTap: _actionTaken ? null : _onConnect,
                        isPrimary: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlurredAvatar extends StatelessWidget {
  final String? imageUrl;
  final bool isBlurred;

  const _BlurredAvatar({this.imageUrl, required this.isBlurred});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 72,
        height: 72,
        child: Stack(
          fit: StackFit.expand,
          children: [
            imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: AppColors.surfaceVariant),
                    errorWidget: (_, __, ___) => Container(
                      color: AppColors.surfaceVariant,
                      child: Icon(
                        Icons.person_rounded,
                        color: AppColors.textMuted,
                        size: 36,
                      ),
                    ),
                  )
                : Container(
                    color: AppColors.surfaceVariant,
                    child: Icon(
                      Icons.person_rounded,
                      color: AppColors.textMuted,
                      size: 36,
                    ),
                  ),
            if (isBlurred)
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  color: AppColors.primary.withOpacity(0.05),
                  child: Center(
                    child: Icon(
                      Icons.lock_rounded,
                      color: Colors.white.withOpacity(0.9),
                      size: 20,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TrustPill extends StatelessWidget {
  final double score;
  const _TrustPill({required this.score});

  Color get _color {
    if (score >= 80) return AppColors.success;
    if (score >= 60) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_rounded, color: _color, size: 11),
          const SizedBox(width: 3),
          Text(
            '${score.toInt()} Trust',
            style: TextStyle(
              color: _color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompatibilityBadge extends StatelessWidget {
  final int score;
  const _CompatibilityBadge({required this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: score >= 80
            ? AppColors.primaryGradient
            : LinearGradient(
                colors: [AppColors.secondary, AppColors.secondaryLight],
              ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$score%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'match',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoiceIntroButton extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onTap;

  const _VoiceIntroButton({required this.isPlaying, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isPlaying
              ? AppColors.primary.withOpacity(0.1)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
          border: Border.all(
            color: isPlaying ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isPlaying ? AppColors.primary : AppColors.primaryLight.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: isPlaying ? Colors.white : AppColors.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Voice Introduction',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  // Fake waveform visualization
                  const SizedBox(height: 4),
                  Row(
                    children: List.generate(20, (i) {
                      final heights = [6.0, 10.0, 14.0, 8.0, 12.0, 16.0, 6.0,
                          10.0, 14.0, 8.0, 12.0, 10.0, 6.0, 14.0, 8.0, 12.0,
                          16.0, 6.0, 10.0, 8.0];
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          height: heights[i % heights.length],
                          decoration: BoxDecoration(
                            color: isPlaying
                                ? AppColors.primary
                                : AppColors.border,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '0:32',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final VoidCallback? onTap;
  final bool isPrimary;
  final bool isIconOnly;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.backgroundColor,
    this.onTap,
    this.isPrimary = false,
    this.isIconOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (onTap != null) {
          HapticFeedback.lightImpact();
          onTap!();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 44,
        width: isIconOnly ? 44 : null,
        padding: isIconOnly
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: onTap == null
              ? backgroundColor.withOpacity(0.4)
              : backgroundColor,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          boxShadow: isPrimary && onTap != null
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 18),
              if (!isIconOnly && label.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SparksShimmer extends StatelessWidget {
  const _SparksShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (_, __) => Container(
        height: 200,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
        ),
      ).animate(onPlay: (c) => c.repeat(reverse: true))
          .shimmer(duration: 1200.ms, color: AppColors.surface),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('🌙', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          Text(
            "You've seen everyone for today",
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'New Sparks arrive tomorrow.\nMeanwhile, explore your communities.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Something went wrong.\nPull to refresh.',
        style: TextStyle(color: AppColors.textSecondary),
        textAlign: TextAlign.center,
      ),
    );
  }
}
