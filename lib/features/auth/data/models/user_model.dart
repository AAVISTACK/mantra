class UserModel {
  final String id;
  final int verificationLevel;
  final String accountStatus;
  final String? gender;
  final int? age;
  final String? city;
  final String? displayName;
  final double? trustScore;
  final List<String> photoUrls;
  final bool isPremium;
  final String? premiumTier;
  final bool isOnboarded;
  final String? kycLevel;
  final DateTime createdAt;
  final DateTime lastActive;

  const UserModel({
    required this.id,
    required this.verificationLevel,
    required this.accountStatus,
    this.gender,
    this.age,
    this.city,
    this.displayName,
    this.trustScore,
    this.photoUrls = const [],
    required this.isPremium,
    this.premiumTier,
    required this.isOnboarded,
    this.kycLevel,
    required this.createdAt,
    required this.lastActive,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'] as String,
    verificationLevel: (json['verification_level'] as num?)?.toInt() ?? 1,
    accountStatus: json['account_status'] as String? ?? 'active',
    gender: json['gender'] as String?,
    age: (json['age'] as num?)?.toInt(),
    city: json['city'] as String?,
    displayName: json['display_name'] as String?,
    trustScore: (json['trust_score'] as num?)?.toDouble(),
    photoUrls: (json['photo_urls'] as List?)?.cast<String>() ?? [],
    isPremium: json['is_premium'] as bool? ?? false,
    premiumTier: json['premium_tier'] as String?,
    isOnboarded: json['is_onboarded'] as bool? ?? false,
    kycLevel: json['kyc_level'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
    lastActive: DateTime.parse(json['last_active'] as String),
  );

  UserModel copyWith({
    String? id, int? verificationLevel, String? accountStatus,
    String? gender, int? age, String? city, String? displayName,
    double? trustScore, List<String>? photoUrls, bool? isPremium,
    String? premiumTier, bool? isOnboarded, String? kycLevel,
    DateTime? createdAt, DateTime? lastActive,
  }) => UserModel(
    id: id ?? this.id,
    verificationLevel: verificationLevel ?? this.verificationLevel,
    accountStatus: accountStatus ?? this.accountStatus,
    gender: gender ?? this.gender,
    age: age ?? this.age,
    city: city ?? this.city,
    displayName: displayName ?? this.displayName,
    trustScore: trustScore ?? this.trustScore,
    photoUrls: photoUrls ?? this.photoUrls,
    isPremium: isPremium ?? this.isPremium,
    premiumTier: premiumTier ?? this.premiumTier,
    isOnboarded: isOnboarded ?? this.isOnboarded,
    kycLevel: kycLevel ?? this.kycLevel,
    createdAt: createdAt ?? this.createdAt,
    lastActive: lastActive ?? this.lastActive,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModel && id == other.id &&
      isOnboarded == other.isOnboarded && accountStatus == other.accountStatus;

  @override
  int get hashCode => id.hashCode ^ isOnboarded.hashCode ^ accountStatus.hashCode;
}
