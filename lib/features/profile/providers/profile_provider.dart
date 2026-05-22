import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';

class ProfileData {
  final String? displayName;
  final double? trustScore;
  final int? age;
  final String? city;
  final String? gender;
  final List<String> photoUrls;
  final List<String> personalityTags;
  final String? intent;

  const ProfileData({
    this.displayName, this.trustScore, this.age, this.city, this.gender,
    this.photoUrls = const [], this.personalityTags = const [], this.intent,
  });

  factory ProfileData.fromJson(Map<String, dynamic> json) => ProfileData(
    displayName: json['display_name'] as String?,
    trustScore: (json['trust_score'] as num?)?.toDouble(),
    age: (json['age'] as num?)?.toInt(),
    city: json['city'] as String?,
    gender: json['gender'] as String?,
    photoUrls: (json['photo_urls'] as List?)?.cast<String>() ?? [],
    personalityTags: (json['personality_tags'] as List?)?.cast<String>() ?? [],
    intent: json['intent'] as String?,
  );

  String get displayNameOrFallback => displayName ?? 'Mantra User';
  String get locationAge {
    final parts = <String>[];
    if (age != null) parts.add('\$age');
    if (city != null && city!.isNotEmpty) parts.add(city!);
    return parts.join(' · ');
  }
}

final profileNotifierProvider =
    StateNotifierProvider<ProfileNotifier, AsyncValue<ProfileData?>>((ref) => ProfileNotifier());

class ProfileNotifier extends StateNotifier<AsyncValue<ProfileData?>> {
  ProfileNotifier() : super(const AsyncValue.loading()) { _load(); }

  Future<void> _load() async {
    try {
      final res = await ApiClient.instance.get(ApiConstants.me);
      state = AsyncValue.data(ProfileData.fromJson(res.data['data'] as Map<String, dynamic>));
    } catch (e, st) { state = AsyncValue.error(e, st); }
  }

  Future<void> refresh() => _load();
}
