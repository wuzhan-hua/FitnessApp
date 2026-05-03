class UserProfile {
  const UserProfile({
    required this.userId,
    required this.profileName,
    this.avatarUrl,
    this.gender,
    this.birthDate,
    this.heightCm,
    this.weightKg,
    this.trainingGoal,
    this.trainingYears,
    this.activityLevel,
  });

  final String userId;
  final String profileName;
  final String? avatarUrl;
  final String? gender;
  final DateTime? birthDate;
  final double? heightCm;
  final double? weightKg;
  final String? trainingGoal;
  final String? trainingYears;
  final String? activityLevel;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['user_id'] as String? ?? '',
      profileName: json['profile_name'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      gender: json['gender'] as String?,
      birthDate: _parseDate(json['birth_date'] as String?),
      heightCm: (json['height_cm'] as num?)?.toDouble(),
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      trainingGoal: json['training_goal'] as String?,
      trainingYears: json['training_years'] as String?,
      activityLevel: json['activity_level'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'profile_name': profileName,
      'avatar_url': avatarUrl,
      'gender': gender,
      'birth_date': birthDate == null
          ? null
          : '${birthDate!.year.toString().padLeft(4, '0')}-'
                '${birthDate!.month.toString().padLeft(2, '0')}-'
                '${birthDate!.day.toString().padLeft(2, '0')}',
      'height_cm': heightCm,
      'weight_kg': weightKg,
      'training_goal': trainingGoal,
      'training_years': trainingYears,
      'activity_level': activityLevel,
    };
  }

  static DateTime? _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw);
  }
}
