// lib/features/matching/data/models/spark_model.dart

class SparkModel {
  final String userId;
  final String displayName;
  final int age;
  final String city;
  final String? profilePhotoUrl;
  final bool photosBlurred;
  final double trustScore;
  final int compatibilityScore;
  final bool isVerified;
  final List<String> interests;
  final String? voiceIntroUrl;
  final int voiceDurationSeconds;
  final List<String> sharedInterests;
  final int sharedRoomsCount;

  const SparkModel({
    required this.userId,
    required this.displayName,
    required this.age,
    required this.city,
    this.profilePhotoUrl,
    required this.photosBlurred,
    required this.trustScore,
    required this.compatibilityScore,
    required this.isVerified,
    required this.interests,
    this.voiceIntroUrl,
    required this.voiceDurationSeconds,
    required this.sharedInterests,
    required this.sharedRoomsCount,
  });

  factory SparkModel.fromJson(Map<String, dynamic> json) => SparkModel(
        userId: json['user_id'],
        displayName: json['display_name'],
        age: json['age'],
        city: json['city'],
        profilePhotoUrl: json['profile_photo_url'],
        photosBlurred: json['photos_blurred'] ?? true,
        trustScore: (json['trust_score'] as num).toDouble(),
        compatibilityScore: json['compatibility_score'],
        isVerified: json['is_verified'] ?? false,
        interests: List<String>.from(json['interests'] ?? []),
        voiceIntroUrl: json['voice_intro_url'],
        voiceDurationSeconds: json['voice_duration_seconds'] ?? 0,
        sharedInterests: List<String>.from(json['shared_interests'] ?? []),
        sharedRoomsCount: json['shared_rooms_count'] ?? 0,
      );
}

// ─────────────────────────────────────────
// lib/features/matching/providers/sparks_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/spark_model.dart';
import '../data/repositories/sparks_repository.dart';

final sparksRepositoryProvider = Provider<SparksRepository>((ref) {
  return SparksRepositoryImpl();
});

final sparksProvider =
    AsyncNotifierProvider<SparksNotifier, List<SparkModel>>(
  SparksNotifier.new,
);

class SparksNotifier extends AsyncNotifier<List<SparkModel>> {
  @override
  Future<List<SparkModel>> build() async {
    return ref.read(sparksRepositoryProvider).getDailySparks();
  }

  Future<void> connect(String userId) async {
    final current = state.value ?? [];
    state = AsyncData(current.where((s) => s.userId != userId).toList());
    await ref.read(sparksRepositoryProvider).connect(userId);
  }

  Future<void> pass(String userId) async {
    final current = state.value ?? [];
    state = AsyncData(current.where((s) => s.userId != userId).toList());
    await ref.read(sparksRepositoryProvider).pass(userId);
  }

  Future<void> save(String userId) async {
    await ref.read(sparksRepositoryProvider).save(userId);
  }
}
