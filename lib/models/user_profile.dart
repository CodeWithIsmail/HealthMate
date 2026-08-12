enum Gender {
  male('MALE', 'Male'),
  female('FEMALE', 'Female'),
  other('OTHER', 'Other'),
  undisclosed('UNDISCLOSED', 'Prefer not to say');

  const Gender(this.apiValue, this.label);
  final String apiValue;
  final String label;

  static Gender fromApi(String value) => Gender.values.firstWhere((g) => g.apiValue == value, orElse: () => Gender.undisclosed);
}

enum BloodGroup {
  aPositive('A_POSITIVE', 'A+'),
  aNegative('A_NEGATIVE', 'A-'),
  bPositive('B_POSITIVE', 'B+'),
  bNegative('B_NEGATIVE', 'B-'),
  abPositive('AB_POSITIVE', 'AB+'),
  abNegative('AB_NEGATIVE', 'AB-'),
  oPositive('O_POSITIVE', 'O+'),
  oNegative('O_NEGATIVE', 'O-'),
  unknown('UNKNOWN', 'Unknown');

  const BloodGroup(this.apiValue, this.label);
  final String apiValue;
  final String label;

  static BloodGroup fromApi(String value) =>
      BloodGroup.values.firstWhere((b) => b.apiValue == value, orElse: () => BloodGroup.unknown);
}

class ProfileStats {
  const ProfileStats({required this.reportCount, required this.valueCount, this.lastReportDate});

  final int reportCount;
  final int valueCount;
  final DateTime? lastReportDate;

  factory ProfileStats.fromJson(Map<String, dynamic> json) => ProfileStats(
    reportCount: json['reportCount'] as int,
    valueCount: json['valueCount'] as int,
    lastReportDate: json['lastReportDate'] == null ? null : DateTime.parse(json['lastReportDate'] as String),
  );
}

/// Full profile — `GET /users/me`, `GET /users/:username`, and the response
/// of `PATCH /users/me` (minus `isSelf`/`age`/`bmi`/`stats`, which that
/// endpoint omits; callers refetch `/users/me` after an edit).
class UserProfile {
  const UserProfile({
    required this.id,
    required this.username,
    required this.email,
    this.firstName,
    this.lastName,
    required this.gender,
    required this.bloodGroup,
    this.dateOfBirth,
    this.phone,
    this.city,
    this.country,
    this.heightCm,
    this.weightKg,
    this.imageUrl,
    required this.createdAt,
    required this.isSelf,
    this.age,
    this.bmi,
    required this.stats,
  });

  final String id;
  final String username;
  final String email;
  final String? firstName;
  final String? lastName;
  final Gender gender;
  final BloodGroup bloodGroup;
  final DateTime? dateOfBirth;
  final String? phone;
  final String? city;
  final String? country;
  final double? heightCm;
  final double? weightKg;
  final String? imageUrl;
  final DateTime createdAt;
  // Server-decided — never infer by comparing usernames.
  final bool isSelf;
  final int? age;
  final double? bmi;
  final ProfileStats stats;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'] as String,
    username: json['username'] as String,
    email: json['email'] as String,
    firstName: json['firstName'] as String?,
    lastName: json['lastName'] as String?,
    gender: Gender.fromApi(json['gender'] as String? ?? 'UNDISCLOSED'),
    bloodGroup: BloodGroup.fromApi(json['bloodGroup'] as String? ?? 'UNKNOWN'),
    dateOfBirth: json['dateOfBirth'] == null ? null : DateTime.parse(json['dateOfBirth'] as String),
    phone: json['phone'] as String?,
    city: json['city'] as String?,
    country: json['country'] as String?,
    heightCm: (json['heightCm'] as num?)?.toDouble(),
    weightKg: (json['weightKg'] as num?)?.toDouble(),
    imageUrl: json['imageUrl'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    isSelf: json['isSelf'] as bool? ?? false,
    age: json['age'] as int?,
    bmi: (json['bmi'] as num?)?.toDouble(),
    stats: ProfileStats.fromJson(json['stats'] as Map<String, dynamic>? ?? const {}),
  );
}

/// Small card used in search results, viewers/access lists.
class PersonCard {
  const PersonCard({
    required this.id,
    required this.username,
    this.firstName,
    this.lastName,
    this.imageUrl,
    this.grantedAt,
    this.iCanViewThem,
    this.theyCanViewMe,
  });

  final String id;
  final String username;
  final String? firstName;
  final String? lastName;
  final String? imageUrl;
  final DateTime? grantedAt;
  final bool? iCanViewThem;
  final bool? theyCanViewMe;

  factory PersonCard.fromJson(Map<String, dynamic> json) => PersonCard(
    id: json['id'] as String,
    username: json['username'] as String,
    firstName: json['firstName'] as String?,
    lastName: json['lastName'] as String?,
    imageUrl: json['imageUrl'] as String?,
    grantedAt: json['grantedAt'] == null ? null : DateTime.parse(json['grantedAt'] as String),
    iCanViewThem: json['iCanViewThem'] as bool?,
    theyCanViewMe: json['theyCanViewMe'] as bool?,
  );
}
