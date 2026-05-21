import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/mantra_button.dart';

enum PremiumPlan { gold, platinum }

class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  PremiumPlan _selected = PremiumPlan.gold;
  bool _isAnnual = false;
  late Razorpay _razorpay;

  // Prices (Men pricing; women get 50% off — applied server-side)
  static const _goldMonthly = 299;
  static const _goldAnnual = 1999;
  static const _platinumMonthly = 599;
  static const _platinumAnnual = 3999;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  int get _currentPrice {
    if (_selected == PremiumPlan.gold) {
      return _isAnnual ? _goldAnnual : _goldMonthly;
    }
    return _isAnnual ? _platinumAnnual : _platinumMonthly;
  }

  String get _savingsText {
    if (!_isAnnual) return '';
    if (_selected == PremiumPlan.gold) {
      final saved = (_goldMonthly * 12) - _goldAnnual;
      return 'Save ₹$saved/year';
    }
    final saved = (_platinumMonthly * 12) - _platinumAnnual;
    return 'Save ₹$saved/year';
  }

  void _startPayment() {
    HapticFeedback.mediumImpact();
    final options = {
      'key': 'rzp_live_YOUR_KEY', // Replace with actual key
      'amount': _currentPrice * 100, // paise
      'name': 'Mantra',
      'description':
          '${_selected == PremiumPlan.gold ? 'Gold' : 'Platinum'} ${_isAnnual ? '(Annual)' : '(Monthly)'}',
      'prefill': {'contact': '', 'email': ''},
      'theme': {'color': '#C4654A'},
      'method': {
        'upi': true,
        'card': true,
        'netbanking': true,
        'wallet': true,
      },
    };
    _razorpay.open(options);
  }

  void _onPaymentSuccess(PaymentSuccessResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Welcome to Mantra ${_selected == PremiumPlan.gold ? 'Gold' : 'Platinum'} ✨'),
        backgroundColor: AppColors.success,
      ),
    );
    context.pop();
  }

  void _onPaymentError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment failed. Please try again.'),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppColors.background,
            leading: IconButton(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1A1512), Color(0xFF2C2420)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      Text(
                        '✨',
                        style: TextStyle(fontSize: 40),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Mantra Premium',
                        style: GoogleFonts_loraStyle(),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'More connections. More depth. More you.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Annual / Monthly toggle
                  _BillingToggle(
                    isAnnual: _isAnnual,
                    onChanged: (v) => setState(() => _isAnnual = v),
                  ).animate().fadeIn(duration: 300.ms),

                  const SizedBox(height: 20),

                  // Plan cards
                  _PlanCard(
                    plan: PremiumPlan.gold,
                    isSelected: _selected == PremiumPlan.gold,
                    isAnnual: _isAnnual,
                    monthlyPrice: _goldMonthly,
                    annualPrice: _goldAnnual,
                    onTap: () =>
                        setState(() => _selected = PremiumPlan.gold),
                    features: const [
                      '10 daily Sparks (3 extra)',
                      'See who connected with you',
                      'Read receipts always on',
                      'Priority in match algorithm',
                      '2 premium rooms per month',
                      'Conversation archive',
                    ],
                  ).animate(delay: 80.ms).fadeIn().slideY(begin: 0.04, end: 0),

                  const SizedBox(height: 14),

                  _PlanCard(
                    plan: PremiumPlan.platinum,
                    isSelected: _selected == PremiumPlan.platinum,
                    isAnnual: _isAnnual,
                    monthlyPrice: _platinumMonthly,
                    annualPrice: _platinumAnnual,
                    onTap: () =>
                        setState(() => _selected = PremiumPlan.platinum),
                    badge: 'Most Popular',
                    features: const [
                      'Everything in Gold',
                      '14 daily Sparks',
                      '1 weekly Super Connect',
                      'Voice call at Stage 2',
                      'AI Conversation Coach',
                      'Weekly 24h profile boost',
                      'Exclusive Platinum room',
                      'Profile preview mode',
                    ],
                  ).animate(delay: 160.ms).fadeIn().slideY(begin: 0.04, end: 0),

                  const SizedBox(height: 24),

                  // Women's discount note
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.08),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusLG),
                      border: Border.all(
                        color: AppColors.secondary.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text('💚', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Women get 50% off all plans, always. No code needed.',
                            style: TextStyle(
                              color: AppColors.secondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate(delay: 220.ms).fadeIn(),

                  const SizedBox(height: 24),

                  // CTA
                  Column(
                    children: [
                      MantraButton(
                        label: _isAnnual
                            ? 'Start for ₹$_currentPrice/year'
                            : 'Start for ₹$_currentPrice/month',
                        onPressed: _startPayment,
                        icon: Icons.star_rounded,
                      ),
                      if (_savingsText.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          _savingsText,
                          style: TextStyle(
                            color: AppColors.success,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        'Cancel anytime. No hidden fees.',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ).animate(delay: 280.ms).fadeIn().slideY(begin: 0.06, end: 0),

                  const SizedBox(height: 32),

                  // Safety features always free note
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.trust.withOpacity(0.06),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusLG),
                      border: Border.all(
                        color: AppColors.trust.withOpacity(0.15),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.shield_rounded,
                            color: AppColors.trust, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'All safety features are FREE forever for everyone. Premium is only for extra connections.',
                            style: TextStyle(
                              color: AppColors.trust,
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate(delay: 320.ms).fadeIn(),

                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  TextStyle GoogleFonts_loraStyle() {
    return const TextStyle(
      color: Colors.white,
      fontSize: 26,
      fontWeight: FontWeight.w600,
      fontFamily: 'Lora',
      letterSpacing: -0.5,
    );
  }
}

class _BillingToggle extends StatelessWidget {
  final bool isAnnual;
  final ValueChanged<bool> onChanged;

  const _BillingToggle({required this.isAnnual, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Row(
        children: [
          _Tab(
            label: 'Monthly',
            isActive: !isAnnual,
            onTap: () => onChanged(false),
          ),
          _Tab(
            label: 'Annual  🎉 4 months free',
            isActive: isAnnual,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _Tab({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppColors.shadow.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              color:
                  isActive ? AppColors.textPrimary : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final PremiumPlan plan;
  final bool isSelected;
  final bool isAnnual;
  final int monthlyPrice;
  final int annualPrice;
  final VoidCallback onTap;
  final List<String> features;
  final String? badge;

  const _PlanCard({
    required this.plan,
    required this.isSelected,
    required this.isAnnual,
    required this.monthlyPrice,
    required this.annualPrice,
    required this.onTap,
    required this.features,
    this.badge,
  });

  String get _planName =>
      plan == PremiumPlan.gold ? '🥇 Gold' : '💎 Platinum';

  Color get _accentColor =>
      plan == PremiumPlan.gold ? AppColors.gold : AppColors.platinum;

  int get _displayPrice => isAnnual ? annualPrice : monthlyPrice;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
          border: Border.all(
            color: isSelected ? _accentColor : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _accentColor.withOpacity(0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _planName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? _accentColor : AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _accentColor.withOpacity(0.1),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusFull),
                    ),
                    child: Text(
                      badge!,
                      style: TextStyle(
                        color: _accentColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹$_displayPrice',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    isAnnual ? '/year' : '/month',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...features.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: isSelected
                            ? _accentColor
                            : AppColors.success,
                        size: 16,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          f,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
