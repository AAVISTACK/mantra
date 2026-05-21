import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../features/auth/presentation/screens/splash_screen.dart';
import '../features/auth/presentation/screens/phone_auth_screen.dart';
import '../features/auth/presentation/screens/otp_screen.dart';
import '../features/auth/presentation/screens/kyc_screen.dart';
import '../features/auth/presentation/screens/liveness_screen.dart';
import '../features/onboarding/presentation/screens/intent_screen.dart';
import '../features/onboarding/presentation/screens/personality_quiz_screen.dart';
import '../features/onboarding/presentation/screens/interests_screen.dart';
import '../features/onboarding/presentation/screens/voice_intro_screen.dart';
import '../features/onboarding/presentation/screens/photo_upload_screen.dart';
import '../features/onboarding/presentation/screens/prompts_screen.dart';
import '../features/onboarding/presentation/screens/safety_tour_screen.dart';
import '../features/home/presentation/screens/main_shell_screen.dart';
import '../features/home/presentation/screens/home_screen.dart';
import '../features/matching/presentation/screens/sparks_screen.dart';
import '../features/matching/presentation/screens/spark_detail_screen.dart';
import '../features/chat/presentation/screens/conversations_screen.dart';
import '../features/chat/presentation/screens/chat_screen.dart';
import '../features/community/presentation/screens/rooms_screen.dart';
import '../features/community/presentation/screens/room_detail_screen.dart';
import '../features/community/presentation/screens/room_post_screen.dart';
import '../features/profile/presentation/screens/profile_screen.dart';
import '../features/profile/presentation/screens/edit_profile_screen.dart';
import '../features/profile/presentation/screens/trust_score_screen.dart';
import '../features/safety/presentation/screens/safety_center_screen.dart';
import '../features/safety/presentation/screens/sos_screen.dart';
import '../features/safety/presentation/screens/trusted_contacts_screen.dart';
import '../features/premium/presentation/screens/premium_screen.dart';
import '../features/auth/providers/auth_provider.dart';

part 'app_router.g.dart';

@riverpod
GoRouter appRouter(AppRouterRef ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final isAuthenticated = authState.value != null;
      final isOnboarded = authState.value?.isOnboarded ?? false;
      final path = state.uri.path;

      if (path == '/splash') return null;

      if (!isAuthenticated) {
        if (path.startsWith('/auth')) return null;
        return '/auth/phone';
      }

      if (!isOnboarded) {
        if (path.startsWith('/onboarding')) return null;
        return '/onboarding/intent';
      }

      if (path.startsWith('/auth') || path.startsWith('/onboarding')) {
        return '/home';
      }

      return null;
    },
    routes: [
      // Splash
      GoRoute(
        path: '/splash',
        builder: (_, __) => const SplashScreen(),
      ),

      // Auth flow
      GoRoute(
        path: '/auth/phone',
        builder: (_, __) => const PhoneAuthScreen(),
      ),
      GoRoute(
        path: '/auth/otp',
        builder: (context, state) => OtpScreen(
          phone: state.extra as String,
        ),
      ),
      GoRoute(
        path: '/auth/kyc',
        builder: (_, __) => const KycScreen(),
      ),
      GoRoute(
        path: '/auth/liveness',
        builder: (_, __) => const LivenessScreen(),
      ),

      // Onboarding flow
      GoRoute(
        path: '/onboarding/intent',
        builder: (_, __) => const IntentScreen(),
      ),
      GoRoute(
        path: '/onboarding/quiz',
        builder: (_, __) => const PersonalityQuizScreen(),
      ),
      GoRoute(
        path: '/onboarding/interests',
        builder: (_, __) => const InterestsScreen(),
      ),
      GoRoute(
        path: '/onboarding/voice',
        builder: (_, __) => const VoiceIntroScreen(),
      ),
      GoRoute(
        path: '/onboarding/photos',
        builder: (_, __) => const PhotoUploadScreen(),
      ),
      GoRoute(
        path: '/onboarding/prompts',
        builder: (_, __) => const PromptsScreen(),
      ),
      GoRoute(
        path: '/onboarding/safety-tour',
        builder: (_, __) => const SafetyTourScreen(),
      ),

      // Main shell with bottom nav
      ShellRoute(
        builder: (context, state, child) => MainShellScreen(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, __) => const HomeScreen(),
          ),
          GoRoute(
            path: '/sparks',
            builder: (_, __) => const SparksScreen(),
            routes: [
              GoRoute(
                path: ':userId',
                builder: (context, state) => SparkDetailScreen(
                  userId: state.pathParameters['userId']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/conversations',
            builder: (_, __) => const ConversationsScreen(),
          ),
          GoRoute(
            path: '/rooms',
            builder: (_, __) => const RoomsScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (_, __) => const ProfileScreen(),
          ),
        ],
      ),

      // Chat (full screen, outside shell)
      GoRoute(
        path: '/chat/:conversationId',
        builder: (context, state) => ChatScreen(
          conversationId: state.pathParameters['conversationId']!,
          extra: state.extra as Map<String, dynamic>?,
        ),
      ),

      // Room detail
      GoRoute(
        path: '/rooms/:roomId',
        builder: (context, state) => RoomDetailScreen(
          roomId: state.pathParameters['roomId']!,
        ),
        routes: [
          GoRoute(
            path: 'post/:postId',
            builder: (context, state) => RoomPostScreen(
              roomId: state.pathParameters['roomId']!,
              postId: state.pathParameters['postId']!,
            ),
          ),
        ],
      ),

      // Profile
      GoRoute(
        path: '/profile/edit',
        builder: (_, __) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/profile/trust-score',
        builder: (_, __) => const TrustScoreScreen(),
      ),

      // Safety
      GoRoute(
        path: '/safety',
        builder: (_, __) => const SafetyCenterScreen(),
      ),
      GoRoute(
        path: '/safety/sos',
        builder: (_, __) => const SosScreen(),
      ),
      GoRoute(
        path: '/safety/trusted-contacts',
        builder: (_, __) => const TrustedContactsScreen(),
      ),

      // Premium
      GoRoute(
        path: '/premium',
        builder: (_, __) => const PremiumScreen(),
      ),
    ],
  );
}
