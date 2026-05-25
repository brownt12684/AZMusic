/// User profile entity representing a student, parent, or instructor.
class Profile {
  final String id;
  final String displayName;
  final ProfileRole role;
  final bool parentPinRequired;
  final bool isDefaultOnDevice;
  final String? localPin;
  final String? email;
  final String? avatarUrl;
  final InstrumentType instrument;
  final int? gradeLevel;
  final String? subtitle;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Profile({
    required this.id,
    required this.displayName,
    this.role = ProfileRole.student,
    this.parentPinRequired = false,
    this.isDefaultOnDevice = false,
    this.localPin,
    this.email,
    this.avatarUrl,
    this.instrument = InstrumentType.violin,
    this.gradeLevel,
    this.subtitle,
    required this.createdAt,
    required this.updatedAt,
  });

  Profile copyWith({
    String? id,
    String? displayName,
    ProfileRole? role,
    bool? parentPinRequired,
    bool? isDefaultOnDevice,
    String? localPin,
    String? email,
    String? avatarUrl,
    InstrumentType? instrument,
    int? gradeLevel,
    String? subtitle,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Profile(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      parentPinRequired: parentPinRequired ?? this.parentPinRequired,
      isDefaultOnDevice: isDefaultOnDevice ?? this.isDefaultOnDevice,
      localPin: localPin ?? this.localPin,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      instrument: instrument ?? this.instrument,
      gradeLevel: gradeLevel ?? this.gradeLevel,
      subtitle: subtitle ?? this.subtitle,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'display_name': displayName,
      'role': role.name,
      'parent_pin_required': parentPinRequired,
      'is_default_on_device': isDefaultOnDevice,
      'local_pin': localPin,
      'email': email,
      'avatar_url': avatarUrl,
      'instrument': instrument.name,
      'grade_level': gradeLevel,
      'subtitle': subtitle,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'] as String,
      displayName: map['display_name'] as String,
      role: ProfileRole.values.firstWhere(
        (e) => e.name == map['role'],
        orElse: () => ProfileRole.student,
      ),
      parentPinRequired: map['parent_pin_required'] as bool? ?? false,
      isDefaultOnDevice: map['is_default_on_device'] as bool? ?? false,
      localPin: map['local_pin'] as String?,
      email: map['email'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      instrument: InstrumentType.values.firstWhere(
        (e) => e.name == map['instrument'],
        orElse: () => InstrumentType.violin,
      ),
      gradeLevel: map['grade_level'] as int?,
      subtitle: map['subtitle'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => toMap();
  factory Profile.fromJson(Map<String, dynamic> json) => Profile.fromMap(json);

  bool get requiresPin =>
      role == ProfileRole.parent || (localPin?.isNotEmpty ?? false);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Profile && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Profile(id: $id, displayName: $displayName, role: $role)';
}

enum ProfileRole {
  student,
  parent,
}

/// Supported instrument types for student profiles.
enum InstrumentType {
  violin,
  viola,
  cello,
  doubleBass,
  guitar,
  piano,
  other,
}
