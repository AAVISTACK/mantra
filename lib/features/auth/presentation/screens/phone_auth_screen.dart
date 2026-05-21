import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/mantra_button.dart';
import '../../providers/auth_provider.dart';

class PhoneAuthScreen extends ConsumerStatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  ConsumerState<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends ConsumerState<PhoneAuthScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _agreed = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept the terms to continue')),
      );
      return;
    }

    final controller = ref.read(authControllerProvider.notifier);
    final verificationId = await controller.sendOtp(_phoneController.text.trim());

    if (verificationId != null && mounted) {
      context.push('/auth/otp', extra: _phoneController.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 48),

                // Logo
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Text(
                      'M',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Lora',
                      ),
                    ),
                  ),
                ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.9, 0.9)),

                const SizedBox(height: 32),

                Text(
                  'Your story\nbegins here.',
                  style: AppTextStyles.heroDisplay,
                )
                    .animate(delay: 150.ms)
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.15, end: 0),

                const SizedBox(height: 10),

                Text(
                  'Enter your phone number to get started.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ).animate(delay: 250.ms).fadeIn(duration: 400.ms),

                const SizedBox(height: 40),

                // Phone field
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    prefixText: '+91  ',
                    prefixStyle: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    hintText: '98765 43210',
                    hintStyle: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 18,
                      letterSpacing: 2,
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter your phone number';
                    if (v.length != 10) return 'Enter a valid 10-digit number';
                    return null;
                  },
                ).animate(delay: 350.ms).fadeIn(duration: 400.ms),

                const SizedBox(height: 24),

                // Terms checkbox
                GestureDetector(
                  onTap: () => setState(() => _agreed = !_agreed),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: _agreed ? AppColors.primary : Colors.transparent,
                          border: Border.all(
                            color: _agreed ? AppColors.primary : AppColors.border,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: _agreed
                            ? const Icon(Icons.check, color: Colors.white, size: 14)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            text: 'I agree to Mantra\'s ',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                            children: [
                              TextSpan(
                                text: 'Terms of Service',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                              const TextSpan(text: ' and '),
                              TextSpan(
                                text: 'Privacy Policy',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate(delay: 450.ms).fadeIn(duration: 400.ms),

                const SizedBox(height: 32),

                MantraButton(
                  label: 'Continue',
                  isLoading: isLoading,
                  onPressed: _sendOtp,
                  icon: Icons.arrow_forward_rounded,
                ).animate(delay: 500.ms).fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),

                const SizedBox(height: 24),

                // Safety note
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.trust.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
                    border: Border.all(
                      color: AppColors.trust.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.verified_user_rounded,
                        color: AppColors.trust,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Your number is never shared. We use it only for verification.',
                          style: TextStyle(
                            color: AppColors.trust,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate(delay: 600.ms).fadeIn(duration: 400.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
