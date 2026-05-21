// lib/features/auth/data/models/user_model.dart

class UserModel {
  final String id;
  final String phoneHash;
  final int verificationLevel; // 1-5
  final String accountStatus;
  final String gender;
  final int age;
  final String city;
  final DateTime createdAt;
  final DateTime lastActive;
  final bool isPremium;
  final String? premiumTier;
  final bool isOnboarded;

  const UserModel({
    required this.id,
    required this.phoneHash,
    required this.verificationLevel,
    required this.accountStatus,
    required this.gender,
    required this.age,
    required this.city,
    required this.createdAt,
    required this.lastActive,
    required this.isPremium,
    this.premiumTier,
    required this.isOnboarded,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'],
        phoneHash: json['phone_hash'],
        verificationLevel: json['verification_level'],
        accountStatus: json['account_status'],
        gender: json['gender'],
        age: json['age'],
        city: json['city'],
        createdAt: DateTime.parse(json['created_at']),
        lastActive: DateTime.parse(json['last_active']),
        isPremium: json['is_premium'],
        premiumTier: json['premium_tier'],
        isOnboarded: json['is_onboarded'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone_hash': phoneHash,
        'verification_level': verificationLevel,
        'account_status': accountStatus,
        'gender': gender,
        'age': age,
        'city': city,
        'created_at': createdAt.toIso8601String(),
        'last_active': lastActive.toIso8601String(),
        'is_premium': isPremium,
        'premium_tier': premiumTier,
        'is_onboarded': isOnboarded,
      };

  UserModel copyWith({
    String? id,
    String? phoneHash,
    int? verificationLevel,
    String? accountStatus,
    String? gender,
    int? age,
    String? city,
    DateTime? createdAt,
    DateTime? lastActive,
    bool? isPremium,
    String? premiumTier,
    bool? isOnboarded,
  }) {
    return UserModel(
      id: id ?? this.id,
      phoneHash: phoneHash ?? this.phoneHash,
      verificationLevel: verificationLevel ?? this.verificationLevel,
      accountStatus: accountStatus ?? this.accountStatus,
      gender: gender ?? this.gender,
      age: age ?? this.age,
      city: city ?? this.city,
      createdAt: createdAt ?? this.createdAt,
      lastActive: lastActive ?? this.lastActive,
      isPremium: isPremium ?? this.isPremium,
      premiumTier: premiumTier ?? this.premiumTier,
      isOnboarded: isOnboarded ?? this.isOnboarded,
    );
  }
}
