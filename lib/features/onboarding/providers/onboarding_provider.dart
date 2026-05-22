import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';

class OnboardingData {
  final String? intent;
  final Map<int, int> quizAnswers;
  final Set<String> interests;
  final String? displayName;
  final List<String> promptResponses;
  final List<String> photoUrls;
  final String? voiceIntroUrl;
  final bool isSubmitting;
  final String? error;

  const OnboardingData({
    this.intent, this.quizAnswers = const {}, this.interests = const {},
    this.displayName, this.promptResponses = const [],
    this.photoUrls = const [], this.voiceIntroUrl,
    this.isSubmitting = false, this.error,
  });

  OnboardingData copyWith({
    String? intent, Map<int, int>? quizAnswers, Set<String>? interests,
    String? displayName, List<String>? promptResponses,
    List<String>? photoUrls, String? voiceIntroUrl,
    bool? isSubmitting, String? error,
  }) => OnboardingData(
    intent: intent ?? this.intent,
    quizAnswers: quizAnswers ?? this.quizAnswers,
    interests: interests ?? this.interests,
    displayName: displayName ?? this.displayName,
    promptResponses: promptResponses ?? this.promptResponses,
    photoUrls: photoUrls ?? this.photoUrls,
    voiceIntroUrl: voiceIntroUrl ?? this.voiceIntroUrl,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    error: error,
  );
}

final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingData>((_) => OnboardingNotifier());

class OnboardingNotifier extends StateNotifier<OnboardingData> {
  OnboardingNotifier() : super(const OnboardingData());

  void setIntent(String intent) => state = state.copyWith(intent: intent);

  void setQuizAnswer(int q, int a) {
    final m = Map<int, int>.from(state.quizAnswers)..[q] = a;
    state = state.copyWith(quizAnswers: m);
  }

  void toggleInterest(String tag) {
    final s = Set<String>.from(state.interests);
    s.contains(tag) ? s.remove(tag) : s.add(tag);
    state = state.copyWith(interests: s);
  }

  void setPromptResponses(List<String> r) => state = state.copyWith(promptResponses: r);

  Future<String?> uploadVoice(String localPath) async {
    try {
      final ref = FirebaseStorage.instance.ref('voice_intros/\${const Uuid().v4()}.m4a');
      await ref.putFile(File(localPath));
      final url = await ref.getDownloadURL();
      state = state.copyWith(voiceIntroUrl: url);
      await ApiClient.instance.post(ApiConstants.uploadVoice, data: {'voice_url': url});
      return url;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  Future<String?> uploadPhoto(String localPath) async {
    try {
      final ref = FirebaseStorage.instance.ref('profile_photos/\${const Uuid().v4()}.jpg');
      await ref.putFile(File(localPath));
      final url = await ref.getDownloadURL();
      state = state.copyWith(photoUrls: [...state.photoUrls, url]);
      return url;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  Future<bool> completeOnboarding() async {
    state = state.copyWith(isSubmitting: true, error: null);
    try {
      await ApiClient.instance.post(ApiConstants.updateProfile, data: {
        'display_name': state.displayName ?? 'Mantra User',
        'intent': state.intent,
        'personality_tags': state.interests.toList(),
        'bio_prompt_responses': state.promptResponses,
        'photo_urls': state.photoUrls,
        'voice_intro_url': state.voiceIntroUrl,
        'is_onboarded': true,
      });
      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return false;
    }
  }
}
