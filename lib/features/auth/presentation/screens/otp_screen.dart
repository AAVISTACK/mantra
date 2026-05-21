import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/mantra_button.dart';
import '../../providers/auth_provider.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String phone;
  const OtpScreen({super.key, required this.phone});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _otpController = TextEditingController();
  String _otp = '';
  int _resendSeconds = 60;
  Timer? _timer;
  String? _verificationId;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _sendOtpInitial();
  }

  Future<void> _sendOtpInitial() async {
    final controller = ref.read(authControllerProvider.notifier);
    _verificationId = await controller.sendOtp(widget.phone);
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendSeconds == 0) {
        t.cancel();
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  Future<void> _resendOtp() async {
    setState(() => _resendSeconds = 60);
    _startTimer();
    final controller = ref.read(authControllerProvider.notifier);
    _verificationId = await controller.sendOtp(widget.phone);
  }

  Future<void> _verify() async {
    if (_otp.length != 6 || _verificationId == null) return;
    final controller = ref.read(authControllerProvider.notifier);
    final success = await controller.verifyOtp(_verificationId!, _otp);
    if (success && mounted) {
      context.go('/auth/kyc');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authControllerProvider).isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              Text('Enter OTP', style: AppTextStyles.heroDisplay)
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.1, end: 0),

              const SizedBox(height: 10),

              Text(
                'We sent a 6-digit code to +91 ${widget.phone}',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  height: 1.5,
                ),
              ).animate(delay: 100.ms).fadeIn(duration: 400.ms),

              const SizedBox(height: 40),

              PinCodeTextField(
                appContext: context,
                controller: _otpController,
                length: 6,
                animationType: AnimationType.fade,
                keyboardType: TextInputType.number,
                autoFocus: true,
                pinTheme: PinTheme(
                  shape: PinCodeFieldShape.box,
                  borderRadius: BorderRadius.circular(12),
                  fieldHeight: 56,
                  fieldWidth: 48,
                  activeFillColor: AppColors.surfaceVariant,
                  inactiveFillColor: AppColors.surfaceVariant,
                  selectedFillColor: AppColors.primaryLight.withOpacity(0.15),
                  activeColor: AppColors.primary,
                  inactiveColor: AppColors.border,
                  selectedColor: AppColors.primary,
                ),
                enableActiveFill: true,
                onChanged: (v) => setState(() => _otp = v),
                onCompleted: (_) => _verify(),
              ).animate(delay: 200.ms).fadeIn(duration: 400.ms),

              const SizedBox(height: 32),

              MantraButton(
                label: 'Verify',
                isLoading: isLoading,
                onPressed: _otp.length == 6 ? _verify : null,
              ).animate(delay: 300.ms).fadeIn(),

              const SizedBox(height: 24),

              Center(
                child: _resendSeconds > 0
                    ? Text(
                        'Resend OTP in ${_resendSeconds}s',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 14,
                        ),
                      )
                    : GestureDetector(
                        onTap: _resendOtp,
                        child: Text(
                          'Resend OTP',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
