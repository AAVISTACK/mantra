// lib/core/constants/api_constants.dart

class ApiConstants {
  ApiConstants._();

  static const String baseUrl = 'https://api.mantraapp.in/api/v1';
  static const String wsUrl = 'wss://ws.mantraapp.in';

  // Auth
  static const String sendOtp = '/auth/send-otp';
  static const String verifyOtp = '/auth/verify-otp';
  static const String register = '/auth/register';
  static const String me = '/auth/me';
  static const String refresh = '/auth/refresh';

  // Profile
  static const String profile = '/profile';
  static const String updateProfile = '/profile/update';
  static const String uploadVoice = '/profile/voice';
  static const String uploadPhoto = '/profile/photo';

  // Matching
  static const String dailySparks = '/match/sparks';
  static const String connect = '/match/connect';
  static const String pass = '/match/pass';
  static const String save = '/match/save';

  // Chat
  static const String conversations = '/conversations';
  static const String messages = '/messages';

  // Community
  static const String rooms = '/rooms';
  static const String joinRoom = '/rooms/join';
  static const String roomPosts = '/rooms/posts';

  // Safety
  static const String reportUser = '/safety/report';
  static const String blockUser = '/safety/block';
  static const String trustedContacts = '/safety/trusted-contacts';
  static const String sosAlert = '/safety/sos';

  // Premium
  static const String createOrder = '/payment/order';
  static const String verifyPayment = '/payment/verify';

  // Timeouts
  static const int connectTimeout = 15000;
  static const int receiveTimeout = 30000;
}

// ─────────────────────────────────────────────────────────────────────
// lib/core/network/api_client.dart

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/api_constants.dart';

class ApiClient {
  static Dio? _instance;
  static const _storage = FlutterSecureStorage();

  static Dio get instance {
    _instance ??= _createDio();
    return _instance!;
  }

  static Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(milliseconds: ApiConstants.connectTimeout),
        receiveTimeout: const Duration(milliseconds: ApiConstants.receiveTimeout),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(_AuthInterceptor());
    dio.interceptors.add(_LoggingInterceptor());

    return dio;
  }
}

class _AuthInterceptor extends Interceptor {
  static const _storage = FlutterSecureStorage();

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      // Token expired — attempt refresh
      try {
        final refreshToken = await _storage.read(key: 'refresh_token');
        if (refreshToken != null) {
          final dio = Dio();
          final response = await dio.post(
            '${ApiConstants.baseUrl}${ApiConstants.refresh}',
            data: {'refresh_token': refreshToken},
          );
          final newToken = response.data['data']['access_token'];
          await _storage.write(key: 'jwt_token', value: newToken);

          // Retry original request
          err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
          final retryResponse = await dio.fetch(err.requestOptions);
          return handler.resolve(retryResponse);
        }
      } catch (_) {
        await _storage.deleteAll();
      }
    }
    handler.next(err);
  }
}

class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    assert(() {
      debugPrint('[API] ${options.method} ${options.uri}');
      return true;
    }());
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    assert(() {
      debugPrint('[API ERROR] ${err.response?.statusCode} ${err.message}');
      return true;
    }());
    handler.next(err);
  }
}

// ─────────────────────────────────────────────────────────────────────
// Stub screens (to satisfy router imports)

// lib/features/auth/presentation/screens/kyc_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/mantra_button.dart';

class KycScreen extends StatelessWidget {
  const KycScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
              Text('Verify your identity',
                  style: Theme.of(context).textTheme.displaySmall),
              const SizedBox(height: 8),
              Text(
                'This keeps Mantra safe for everyone. Your data is never shared.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 40),
              _KycOption(
                icon: '🪪',
                title: 'DigiLocker (Recommended)',
                subtitle: 'Fastest. Uses your Aadhaar via official govt system.',
                onTap: () => context.push('/auth/liveness'),
              ),
              const SizedBox(height: 12),
              _KycOption(
                icon: '📱',
                title: 'Aadhaar OTP',
                subtitle: 'Enter last 4 digits + receive OTP on registered number.',
                onTap: () => context.push('/auth/liveness'),
              ),
              const SizedBox(height: 12),
              _KycOption(
                icon: '📄',
                title: 'Manual Upload',
                subtitle: 'Upload govt ID. Reviewed within 24 hours.',
                onTap: () => context.push('/auth/liveness'),
              ),
              const Spacer(),
              Text(
                '🔒 We only verify your age and gender. Your Aadhaar number is never stored.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _KycOption extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _KycOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Text(icon, style: TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// lib/features/auth/presentation/screens/liveness_screen.dart

class LivenessScreen extends StatelessWidget {
  const LivenessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            children: [
              const SizedBox(height: 32),
              Text('Face Verification',
                  style: Theme.of(context).textTheme.displaySmall),
              const SizedBox(height: 12),
              Text(
                'Look at the camera and follow the prompts. This confirms you\'re a real person.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              // Camera preview placeholder
              Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 3),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.face_rounded, size: 80, color: AppColors.textMuted),
                    const SizedBox(height: 8),
                    Text('Camera Preview',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  ],
                ),
              ),
              const Spacer(),
              MantraButton(
                label: 'Start Verification',
                onPressed: () => context.go('/onboarding/intent'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
