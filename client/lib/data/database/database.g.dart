// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $ProfilesTable extends Profiles
    with TableInfo<$ProfilesTable, ProfileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _displayNameMeta =
      const VerificationMeta('displayName');
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
      'display_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
      'role', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _parentPinRequiredMeta =
      const VerificationMeta('parentPinRequired');
  @override
  late final GeneratedColumn<bool> parentPinRequired = GeneratedColumn<bool>(
      'parent_pin_required', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("parent_pin_required" IN (0, 1))'));
  static const VerificationMeta _isDefaultOnDeviceMeta =
      const VerificationMeta('isDefaultOnDevice');
  @override
  late final GeneratedColumn<bool> isDefaultOnDevice = GeneratedColumn<bool>(
      'is_default_on_device', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_default_on_device" IN (0, 1))'));
  static const VerificationMeta _localPinMeta =
      const VerificationMeta('localPin');
  @override
  late final GeneratedColumn<String> localPin = GeneratedColumn<String>(
      'local_pin', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
      'email', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _avatarUrlMeta =
      const VerificationMeta('avatarUrl');
  @override
  late final GeneratedColumn<String> avatarUrl = GeneratedColumn<String>(
      'avatar_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _instrumentMeta =
      const VerificationMeta('instrument');
  @override
  late final GeneratedColumn<String> instrument = GeneratedColumn<String>(
      'instrument', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _gradeLevelMeta =
      const VerificationMeta('gradeLevel');
  @override
  late final GeneratedColumn<int> gradeLevel = GeneratedColumn<int>(
      'grade_level', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _subtitleMeta =
      const VerificationMeta('subtitle');
  @override
  late final GeneratedColumn<String> subtitle = GeneratedColumn<String>(
      'subtitle', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        displayName,
        role,
        parentPinRequired,
        isDefaultOnDevice,
        localPin,
        email,
        avatarUrl,
        instrument,
        gradeLevel,
        subtitle,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'profiles';
  @override
  VerificationContext validateIntegrity(Insertable<ProfileRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
          _displayNameMeta,
          displayName.isAcceptableOrUnknown(
              data['display_name']!, _displayNameMeta));
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
          _roleMeta, role.isAcceptableOrUnknown(data['role']!, _roleMeta));
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('parent_pin_required')) {
      context.handle(
          _parentPinRequiredMeta,
          parentPinRequired.isAcceptableOrUnknown(
              data['parent_pin_required']!, _parentPinRequiredMeta));
    } else if (isInserting) {
      context.missing(_parentPinRequiredMeta);
    }
    if (data.containsKey('is_default_on_device')) {
      context.handle(
          _isDefaultOnDeviceMeta,
          isDefaultOnDevice.isAcceptableOrUnknown(
              data['is_default_on_device']!, _isDefaultOnDeviceMeta));
    } else if (isInserting) {
      context.missing(_isDefaultOnDeviceMeta);
    }
    if (data.containsKey('local_pin')) {
      context.handle(_localPinMeta,
          localPin.isAcceptableOrUnknown(data['local_pin']!, _localPinMeta));
    }
    if (data.containsKey('email')) {
      context.handle(
          _emailMeta, email.isAcceptableOrUnknown(data['email']!, _emailMeta));
    }
    if (data.containsKey('avatar_url')) {
      context.handle(_avatarUrlMeta,
          avatarUrl.isAcceptableOrUnknown(data['avatar_url']!, _avatarUrlMeta));
    }
    if (data.containsKey('instrument')) {
      context.handle(
          _instrumentMeta,
          instrument.isAcceptableOrUnknown(
              data['instrument']!, _instrumentMeta));
    } else if (isInserting) {
      context.missing(_instrumentMeta);
    }
    if (data.containsKey('grade_level')) {
      context.handle(
          _gradeLevelMeta,
          gradeLevel.isAcceptableOrUnknown(
              data['grade_level']!, _gradeLevelMeta));
    }
    if (data.containsKey('subtitle')) {
      context.handle(_subtitleMeta,
          subtitle.isAcceptableOrUnknown(data['subtitle']!, _subtitleMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProfileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProfileRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      displayName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}display_name'])!,
      role: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}role'])!,
      parentPinRequired: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}parent_pin_required'])!,
      isDefaultOnDevice: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}is_default_on_device'])!,
      localPin: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}local_pin']),
      email: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}email']),
      avatarUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}avatar_url']),
      instrument: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}instrument'])!,
      gradeLevel: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}grade_level']),
      subtitle: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}subtitle']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $ProfilesTable createAlias(String alias) {
    return $ProfilesTable(attachedDatabase, alias);
  }
}

class ProfileRow extends DataClass implements Insertable<ProfileRow> {
  final String id;
  final String displayName;
  final String role;
  final bool parentPinRequired;
  final bool isDefaultOnDevice;
  final String? localPin;
  final String? email;
  final String? avatarUrl;
  final String instrument;
  final int? gradeLevel;
  final String? subtitle;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ProfileRow(
      {required this.id,
      required this.displayName,
      required this.role,
      required this.parentPinRequired,
      required this.isDefaultOnDevice,
      this.localPin,
      this.email,
      this.avatarUrl,
      required this.instrument,
      this.gradeLevel,
      this.subtitle,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['display_name'] = Variable<String>(displayName);
    map['role'] = Variable<String>(role);
    map['parent_pin_required'] = Variable<bool>(parentPinRequired);
    map['is_default_on_device'] = Variable<bool>(isDefaultOnDevice);
    if (!nullToAbsent || localPin != null) {
      map['local_pin'] = Variable<String>(localPin);
    }
    if (!nullToAbsent || email != null) {
      map['email'] = Variable<String>(email);
    }
    if (!nullToAbsent || avatarUrl != null) {
      map['avatar_url'] = Variable<String>(avatarUrl);
    }
    map['instrument'] = Variable<String>(instrument);
    if (!nullToAbsent || gradeLevel != null) {
      map['grade_level'] = Variable<int>(gradeLevel);
    }
    if (!nullToAbsent || subtitle != null) {
      map['subtitle'] = Variable<String>(subtitle);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ProfilesCompanion toCompanion(bool nullToAbsent) {
    return ProfilesCompanion(
      id: Value(id),
      displayName: Value(displayName),
      role: Value(role),
      parentPinRequired: Value(parentPinRequired),
      isDefaultOnDevice: Value(isDefaultOnDevice),
      localPin: localPin == null && nullToAbsent
          ? const Value.absent()
          : Value(localPin),
      email:
          email == null && nullToAbsent ? const Value.absent() : Value(email),
      avatarUrl: avatarUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(avatarUrl),
      instrument: Value(instrument),
      gradeLevel: gradeLevel == null && nullToAbsent
          ? const Value.absent()
          : Value(gradeLevel),
      subtitle: subtitle == null && nullToAbsent
          ? const Value.absent()
          : Value(subtitle),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ProfileRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProfileRow(
      id: serializer.fromJson<String>(json['id']),
      displayName: serializer.fromJson<String>(json['displayName']),
      role: serializer.fromJson<String>(json['role']),
      parentPinRequired: serializer.fromJson<bool>(json['parentPinRequired']),
      isDefaultOnDevice: serializer.fromJson<bool>(json['isDefaultOnDevice']),
      localPin: serializer.fromJson<String?>(json['localPin']),
      email: serializer.fromJson<String?>(json['email']),
      avatarUrl: serializer.fromJson<String?>(json['avatarUrl']),
      instrument: serializer.fromJson<String>(json['instrument']),
      gradeLevel: serializer.fromJson<int?>(json['gradeLevel']),
      subtitle: serializer.fromJson<String?>(json['subtitle']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'displayName': serializer.toJson<String>(displayName),
      'role': serializer.toJson<String>(role),
      'parentPinRequired': serializer.toJson<bool>(parentPinRequired),
      'isDefaultOnDevice': serializer.toJson<bool>(isDefaultOnDevice),
      'localPin': serializer.toJson<String?>(localPin),
      'email': serializer.toJson<String?>(email),
      'avatarUrl': serializer.toJson<String?>(avatarUrl),
      'instrument': serializer.toJson<String>(instrument),
      'gradeLevel': serializer.toJson<int?>(gradeLevel),
      'subtitle': serializer.toJson<String?>(subtitle),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ProfileRow copyWith(
          {String? id,
          String? displayName,
          String? role,
          bool? parentPinRequired,
          bool? isDefaultOnDevice,
          Value<String?> localPin = const Value.absent(),
          Value<String?> email = const Value.absent(),
          Value<String?> avatarUrl = const Value.absent(),
          String? instrument,
          Value<int?> gradeLevel = const Value.absent(),
          Value<String?> subtitle = const Value.absent(),
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      ProfileRow(
        id: id ?? this.id,
        displayName: displayName ?? this.displayName,
        role: role ?? this.role,
        parentPinRequired: parentPinRequired ?? this.parentPinRequired,
        isDefaultOnDevice: isDefaultOnDevice ?? this.isDefaultOnDevice,
        localPin: localPin.present ? localPin.value : this.localPin,
        email: email.present ? email.value : this.email,
        avatarUrl: avatarUrl.present ? avatarUrl.value : this.avatarUrl,
        instrument: instrument ?? this.instrument,
        gradeLevel: gradeLevel.present ? gradeLevel.value : this.gradeLevel,
        subtitle: subtitle.present ? subtitle.value : this.subtitle,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  ProfileRow copyWithCompanion(ProfilesCompanion data) {
    return ProfileRow(
      id: data.id.present ? data.id.value : this.id,
      displayName:
          data.displayName.present ? data.displayName.value : this.displayName,
      role: data.role.present ? data.role.value : this.role,
      parentPinRequired: data.parentPinRequired.present
          ? data.parentPinRequired.value
          : this.parentPinRequired,
      isDefaultOnDevice: data.isDefaultOnDevice.present
          ? data.isDefaultOnDevice.value
          : this.isDefaultOnDevice,
      localPin: data.localPin.present ? data.localPin.value : this.localPin,
      email: data.email.present ? data.email.value : this.email,
      avatarUrl: data.avatarUrl.present ? data.avatarUrl.value : this.avatarUrl,
      instrument:
          data.instrument.present ? data.instrument.value : this.instrument,
      gradeLevel:
          data.gradeLevel.present ? data.gradeLevel.value : this.gradeLevel,
      subtitle: data.subtitle.present ? data.subtitle.value : this.subtitle,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProfileRow(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('role: $role, ')
          ..write('parentPinRequired: $parentPinRequired, ')
          ..write('isDefaultOnDevice: $isDefaultOnDevice, ')
          ..write('localPin: $localPin, ')
          ..write('email: $email, ')
          ..write('avatarUrl: $avatarUrl, ')
          ..write('instrument: $instrument, ')
          ..write('gradeLevel: $gradeLevel, ')
          ..write('subtitle: $subtitle, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      displayName,
      role,
      parentPinRequired,
      isDefaultOnDevice,
      localPin,
      email,
      avatarUrl,
      instrument,
      gradeLevel,
      subtitle,
      createdAt,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProfileRow &&
          other.id == this.id &&
          other.displayName == this.displayName &&
          other.role == this.role &&
          other.parentPinRequired == this.parentPinRequired &&
          other.isDefaultOnDevice == this.isDefaultOnDevice &&
          other.localPin == this.localPin &&
          other.email == this.email &&
          other.avatarUrl == this.avatarUrl &&
          other.instrument == this.instrument &&
          other.gradeLevel == this.gradeLevel &&
          other.subtitle == this.subtitle &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ProfilesCompanion extends UpdateCompanion<ProfileRow> {
  final Value<String> id;
  final Value<String> displayName;
  final Value<String> role;
  final Value<bool> parentPinRequired;
  final Value<bool> isDefaultOnDevice;
  final Value<String?> localPin;
  final Value<String?> email;
  final Value<String?> avatarUrl;
  final Value<String> instrument;
  final Value<int?> gradeLevel;
  final Value<String?> subtitle;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ProfilesCompanion({
    this.id = const Value.absent(),
    this.displayName = const Value.absent(),
    this.role = const Value.absent(),
    this.parentPinRequired = const Value.absent(),
    this.isDefaultOnDevice = const Value.absent(),
    this.localPin = const Value.absent(),
    this.email = const Value.absent(),
    this.avatarUrl = const Value.absent(),
    this.instrument = const Value.absent(),
    this.gradeLevel = const Value.absent(),
    this.subtitle = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProfilesCompanion.insert({
    required String id,
    required String displayName,
    required String role,
    required bool parentPinRequired,
    required bool isDefaultOnDevice,
    this.localPin = const Value.absent(),
    this.email = const Value.absent(),
    this.avatarUrl = const Value.absent(),
    required String instrument,
    this.gradeLevel = const Value.absent(),
    this.subtitle = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        displayName = Value(displayName),
        role = Value(role),
        parentPinRequired = Value(parentPinRequired),
        isDefaultOnDevice = Value(isDefaultOnDevice),
        instrument = Value(instrument),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<ProfileRow> custom({
    Expression<String>? id,
    Expression<String>? displayName,
    Expression<String>? role,
    Expression<bool>? parentPinRequired,
    Expression<bool>? isDefaultOnDevice,
    Expression<String>? localPin,
    Expression<String>? email,
    Expression<String>? avatarUrl,
    Expression<String>? instrument,
    Expression<int>? gradeLevel,
    Expression<String>? subtitle,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (displayName != null) 'display_name': displayName,
      if (role != null) 'role': role,
      if (parentPinRequired != null) 'parent_pin_required': parentPinRequired,
      if (isDefaultOnDevice != null) 'is_default_on_device': isDefaultOnDevice,
      if (localPin != null) 'local_pin': localPin,
      if (email != null) 'email': email,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (instrument != null) 'instrument': instrument,
      if (gradeLevel != null) 'grade_level': gradeLevel,
      if (subtitle != null) 'subtitle': subtitle,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProfilesCompanion copyWith(
      {Value<String>? id,
      Value<String>? displayName,
      Value<String>? role,
      Value<bool>? parentPinRequired,
      Value<bool>? isDefaultOnDevice,
      Value<String?>? localPin,
      Value<String?>? email,
      Value<String?>? avatarUrl,
      Value<String>? instrument,
      Value<int?>? gradeLevel,
      Value<String?>? subtitle,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return ProfilesCompanion(
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
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (parentPinRequired.present) {
      map['parent_pin_required'] = Variable<bool>(parentPinRequired.value);
    }
    if (isDefaultOnDevice.present) {
      map['is_default_on_device'] = Variable<bool>(isDefaultOnDevice.value);
    }
    if (localPin.present) {
      map['local_pin'] = Variable<String>(localPin.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (avatarUrl.present) {
      map['avatar_url'] = Variable<String>(avatarUrl.value);
    }
    if (instrument.present) {
      map['instrument'] = Variable<String>(instrument.value);
    }
    if (gradeLevel.present) {
      map['grade_level'] = Variable<int>(gradeLevel.value);
    }
    if (subtitle.present) {
      map['subtitle'] = Variable<String>(subtitle.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProfilesCompanion(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('role: $role, ')
          ..write('parentPinRequired: $parentPinRequired, ')
          ..write('isDefaultOnDevice: $isDefaultOnDevice, ')
          ..write('localPin: $localPin, ')
          ..write('email: $email, ')
          ..write('avatarUrl: $avatarUrl, ')
          ..write('instrument: $instrument, ')
          ..write('gradeLevel: $gradeLevel, ')
          ..write('subtitle: $subtitle, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PiecesTable extends Pieces with TableInfo<$PiecesTable, PieceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PiecesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _composerMeta =
      const VerificationMeta('composer');
  @override
  late final GeneratedColumn<String> composer = GeneratedColumn<String>(
      'composer', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _serverPieceIdMeta =
      const VerificationMeta('serverPieceId');
  @override
  late final GeneratedColumn<String> serverPieceId = GeneratedColumn<String>(
      'server_piece_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _assignedProfileIdMeta =
      const VerificationMeta('assignedProfileId');
  @override
  late final GeneratedColumn<String> assignedProfileId =
      GeneratedColumn<String>('assigned_profile_id', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _visibleToProfileIdsMeta =
      const VerificationMeta('visibleToProfileIds');
  @override
  late final GeneratedColumn<String> visibleToProfileIds =
      GeneratedColumn<String>('visible_to_profile_ids', aliasedName, false,
          type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _previousVisibleToProfileIdsMeta =
      const VerificationMeta('previousVisibleToProfileIds');
  @override
  late final GeneratedColumn<String> previousVisibleToProfileIds =
      GeneratedColumn<String>(
          'previous_visible_to_profile_ids', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _primaryInstrumentMeta =
      const VerificationMeta('primaryInstrument');
  @override
  late final GeneratedColumn<String> primaryInstrument =
      GeneratedColumn<String>('primary_instrument', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _bookOrCollectionMeta =
      const VerificationMeta('bookOrCollection');
  @override
  late final GeneratedColumn<String> bookOrCollection = GeneratedColumn<String>(
      'book_or_collection', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _libraryStatusMeta =
      const VerificationMeta('libraryStatus');
  @override
  late final GeneratedColumn<String> libraryStatus = GeneratedColumn<String>(
      'library_status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _normalizedTitleMeta =
      const VerificationMeta('normalizedTitle');
  @override
  late final GeneratedColumn<String> normalizedTitle = GeneratedColumn<String>(
      'normalized_title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _normalizedComposerMeta =
      const VerificationMeta('normalizedComposer');
  @override
  late final GeneratedColumn<String> normalizedComposer =
      GeneratedColumn<String>('normalized_composer', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sortTitleMeta =
      const VerificationMeta('sortTitle');
  @override
  late final GeneratedColumn<String> sortTitle = GeneratedColumn<String>(
      'sort_title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sortComposerMeta =
      const VerificationMeta('sortComposer');
  @override
  late final GeneratedColumn<String> sortComposer = GeneratedColumn<String>(
      'sort_composer', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _opusMeta = const VerificationMeta('opus');
  @override
  late final GeneratedColumn<String> opus = GeneratedColumn<String>(
      'opus', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _movementMeta =
      const VerificationMeta('movement');
  @override
  late final GeneratedColumn<String> movement = GeneratedColumn<String>(
      'movement', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _keySignatureMeta =
      const VerificationMeta('keySignature');
  @override
  late final GeneratedColumn<String> keySignature = GeneratedColumn<String>(
      'key_signature', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _tempoMeta = const VerificationMeta('tempo');
  @override
  late final GeneratedColumn<String> tempo = GeneratedColumn<String>(
      'tempo', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _difficultyMeta =
      const VerificationMeta('difficulty');
  @override
  late final GeneratedColumn<String> difficulty = GeneratedColumn<String>(
      'difficulty', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _genreMeta = const VerificationMeta('genre');
  @override
  late final GeneratedColumn<String> genre = GeneratedColumn<String>(
      'genre', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _processedMetadataMeta =
      const VerificationMeta('processedMetadata');
  @override
  late final GeneratedColumn<String> processedMetadata =
      GeneratedColumn<String>('processed_metadata', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _pieceKindMeta =
      const VerificationMeta('pieceKind');
  @override
  late final GeneratedColumn<String> pieceKind = GeneratedColumn<String>(
      'piece_kind', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('piece'));
  static const VerificationMeta _sourceBookIdMeta =
      const VerificationMeta('sourceBookId');
  @override
  late final GeneratedColumn<String> sourceBookId = GeneratedColumn<String>(
      'source_book_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sourcePageStartMeta =
      const VerificationMeta('sourcePageStart');
  @override
  late final GeneratedColumn<int> sourcePageStart = GeneratedColumn<int>(
      'source_page_start', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _sourcePageEndMeta =
      const VerificationMeta('sourcePageEnd');
  @override
  late final GeneratedColumn<int> sourcePageEnd = GeneratedColumn<int>(
      'source_page_end', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _catalogMetadataMeta =
      const VerificationMeta('catalogMetadata');
  @override
  late final GeneratedColumn<String> catalogMetadata = GeneratedColumn<String>(
      'catalog_metadata', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _catalogSuggestionsMeta =
      const VerificationMeta('catalogSuggestions');
  @override
  late final GeneratedColumn<String> catalogSuggestions =
      GeneratedColumn<String>('catalog_suggestions', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _validationWarningsMeta =
      const VerificationMeta('validationWarnings');
  @override
  late final GeneratedColumn<String> validationWarnings =
      GeneratedColumn<String>('validation_warnings', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _splitConfidenceMeta =
      const VerificationMeta('splitConfidence');
  @override
  late final GeneratedColumn<double> splitConfidence = GeneratedColumn<double>(
      'split_confidence', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _sourceContentSha256Meta =
      const VerificationMeta('sourceContentSha256');
  @override
  late final GeneratedColumn<String> sourceContentSha256 =
      GeneratedColumn<String>('source_content_sha256', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _workflowClosedMeta =
      const VerificationMeta('workflowClosed');
  @override
  late final GeneratedColumn<bool> workflowClosed = GeneratedColumn<bool>(
      'workflow_closed', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("workflow_closed" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        title,
        composer,
        serverPieceId,
        assignedProfileId,
        visibleToProfileIds,
        previousVisibleToProfileIds,
        primaryInstrument,
        bookOrCollection,
        libraryStatus,
        normalizedTitle,
        normalizedComposer,
        sortTitle,
        sortComposer,
        opus,
        movement,
        keySignature,
        tempo,
        difficulty,
        genre,
        notes,
        processedMetadata,
        pieceKind,
        sourceBookId,
        sourcePageStart,
        sourcePageEnd,
        catalogMetadata,
        catalogSuggestions,
        validationWarnings,
        splitConfidence,
        sourceContentSha256,
        workflowClosed,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pieces';
  @override
  VerificationContext validateIntegrity(Insertable<PieceRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('composer')) {
      context.handle(_composerMeta,
          composer.isAcceptableOrUnknown(data['composer']!, _composerMeta));
    }
    if (data.containsKey('server_piece_id')) {
      context.handle(
          _serverPieceIdMeta,
          serverPieceId.isAcceptableOrUnknown(
              data['server_piece_id']!, _serverPieceIdMeta));
    }
    if (data.containsKey('assigned_profile_id')) {
      context.handle(
          _assignedProfileIdMeta,
          assignedProfileId.isAcceptableOrUnknown(
              data['assigned_profile_id']!, _assignedProfileIdMeta));
    }
    if (data.containsKey('visible_to_profile_ids')) {
      context.handle(
          _visibleToProfileIdsMeta,
          visibleToProfileIds.isAcceptableOrUnknown(
              data['visible_to_profile_ids']!, _visibleToProfileIdsMeta));
    } else if (isInserting) {
      context.missing(_visibleToProfileIdsMeta);
    }
    if (data.containsKey('previous_visible_to_profile_ids')) {
      context.handle(
          _previousVisibleToProfileIdsMeta,
          previousVisibleToProfileIds.isAcceptableOrUnknown(
              data['previous_visible_to_profile_ids']!,
              _previousVisibleToProfileIdsMeta));
    }
    if (data.containsKey('primary_instrument')) {
      context.handle(
          _primaryInstrumentMeta,
          primaryInstrument.isAcceptableOrUnknown(
              data['primary_instrument']!, _primaryInstrumentMeta));
    }
    if (data.containsKey('book_or_collection')) {
      context.handle(
          _bookOrCollectionMeta,
          bookOrCollection.isAcceptableOrUnknown(
              data['book_or_collection']!, _bookOrCollectionMeta));
    }
    if (data.containsKey('library_status')) {
      context.handle(
          _libraryStatusMeta,
          libraryStatus.isAcceptableOrUnknown(
              data['library_status']!, _libraryStatusMeta));
    } else if (isInserting) {
      context.missing(_libraryStatusMeta);
    }
    if (data.containsKey('normalized_title')) {
      context.handle(
          _normalizedTitleMeta,
          normalizedTitle.isAcceptableOrUnknown(
              data['normalized_title']!, _normalizedTitleMeta));
    } else if (isInserting) {
      context.missing(_normalizedTitleMeta);
    }
    if (data.containsKey('normalized_composer')) {
      context.handle(
          _normalizedComposerMeta,
          normalizedComposer.isAcceptableOrUnknown(
              data['normalized_composer']!, _normalizedComposerMeta));
    }
    if (data.containsKey('sort_title')) {
      context.handle(_sortTitleMeta,
          sortTitle.isAcceptableOrUnknown(data['sort_title']!, _sortTitleMeta));
    } else if (isInserting) {
      context.missing(_sortTitleMeta);
    }
    if (data.containsKey('sort_composer')) {
      context.handle(
          _sortComposerMeta,
          sortComposer.isAcceptableOrUnknown(
              data['sort_composer']!, _sortComposerMeta));
    }
    if (data.containsKey('opus')) {
      context.handle(
          _opusMeta, opus.isAcceptableOrUnknown(data['opus']!, _opusMeta));
    }
    if (data.containsKey('movement')) {
      context.handle(_movementMeta,
          movement.isAcceptableOrUnknown(data['movement']!, _movementMeta));
    }
    if (data.containsKey('key_signature')) {
      context.handle(
          _keySignatureMeta,
          keySignature.isAcceptableOrUnknown(
              data['key_signature']!, _keySignatureMeta));
    }
    if (data.containsKey('tempo')) {
      context.handle(
          _tempoMeta, tempo.isAcceptableOrUnknown(data['tempo']!, _tempoMeta));
    }
    if (data.containsKey('difficulty')) {
      context.handle(
          _difficultyMeta,
          difficulty.isAcceptableOrUnknown(
              data['difficulty']!, _difficultyMeta));
    }
    if (data.containsKey('genre')) {
      context.handle(
          _genreMeta, genre.isAcceptableOrUnknown(data['genre']!, _genreMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('processed_metadata')) {
      context.handle(
          _processedMetadataMeta,
          processedMetadata.isAcceptableOrUnknown(
              data['processed_metadata']!, _processedMetadataMeta));
    }
    if (data.containsKey('piece_kind')) {
      context.handle(_pieceKindMeta,
          pieceKind.isAcceptableOrUnknown(data['piece_kind']!, _pieceKindMeta));
    }
    if (data.containsKey('source_book_id')) {
      context.handle(
          _sourceBookIdMeta,
          sourceBookId.isAcceptableOrUnknown(
              data['source_book_id']!, _sourceBookIdMeta));
    }
    if (data.containsKey('source_page_start')) {
      context.handle(
          _sourcePageStartMeta,
          sourcePageStart.isAcceptableOrUnknown(
              data['source_page_start']!, _sourcePageStartMeta));
    }
    if (data.containsKey('source_page_end')) {
      context.handle(
          _sourcePageEndMeta,
          sourcePageEnd.isAcceptableOrUnknown(
              data['source_page_end']!, _sourcePageEndMeta));
    }
    if (data.containsKey('catalog_metadata')) {
      context.handle(
          _catalogMetadataMeta,
          catalogMetadata.isAcceptableOrUnknown(
              data['catalog_metadata']!, _catalogMetadataMeta));
    }
    if (data.containsKey('catalog_suggestions')) {
      context.handle(
          _catalogSuggestionsMeta,
          catalogSuggestions.isAcceptableOrUnknown(
              data['catalog_suggestions']!, _catalogSuggestionsMeta));
    }
    if (data.containsKey('validation_warnings')) {
      context.handle(
          _validationWarningsMeta,
          validationWarnings.isAcceptableOrUnknown(
              data['validation_warnings']!, _validationWarningsMeta));
    }
    if (data.containsKey('split_confidence')) {
      context.handle(
          _splitConfidenceMeta,
          splitConfidence.isAcceptableOrUnknown(
              data['split_confidence']!, _splitConfidenceMeta));
    }
    if (data.containsKey('source_content_sha256')) {
      context.handle(
          _sourceContentSha256Meta,
          sourceContentSha256.isAcceptableOrUnknown(
              data['source_content_sha256']!, _sourceContentSha256Meta));
    }
    if (data.containsKey('workflow_closed')) {
      context.handle(
          _workflowClosedMeta,
          workflowClosed.isAcceptableOrUnknown(
              data['workflow_closed']!, _workflowClosedMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PieceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PieceRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      composer: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}composer']),
      serverPieceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}server_piece_id']),
      assignedProfileId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}assigned_profile_id']),
      visibleToProfileIds: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}visible_to_profile_ids'])!,
      previousVisibleToProfileIds: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}previous_visible_to_profile_ids']),
      primaryInstrument: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}primary_instrument']),
      bookOrCollection: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}book_or_collection']),
      libraryStatus: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}library_status'])!,
      normalizedTitle: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}normalized_title'])!,
      normalizedComposer: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}normalized_composer']),
      sortTitle: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sort_title'])!,
      sortComposer: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sort_composer']),
      opus: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}opus']),
      movement: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}movement']),
      keySignature: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key_signature']),
      tempo: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tempo']),
      difficulty: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}difficulty']),
      genre: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}genre']),
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
      processedMetadata: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}processed_metadata']),
      pieceKind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}piece_kind'])!,
      sourceBookId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source_book_id']),
      sourcePageStart: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}source_page_start']),
      sourcePageEnd: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}source_page_end']),
      catalogMetadata: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}catalog_metadata']),
      catalogSuggestions: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}catalog_suggestions']),
      validationWarnings: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}validation_warnings']),
      splitConfidence: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}split_confidence']),
      sourceContentSha256: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}source_content_sha256']),
      workflowClosed: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}workflow_closed'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $PiecesTable createAlias(String alias) {
    return $PiecesTable(attachedDatabase, alias);
  }
}

class PieceRow extends DataClass implements Insertable<PieceRow> {
  final String id;
  final String title;
  final String? composer;
  final String? serverPieceId;
  final String? assignedProfileId;
  final String visibleToProfileIds;
  final String? previousVisibleToProfileIds;
  final String? primaryInstrument;
  final String? bookOrCollection;
  final String libraryStatus;
  final String normalizedTitle;
  final String? normalizedComposer;
  final String sortTitle;
  final String? sortComposer;
  final String? opus;
  final String? movement;
  final String? keySignature;
  final String? tempo;
  final String? difficulty;
  final String? genre;
  final String? notes;
  final String? processedMetadata;
  final String pieceKind;
  final String? sourceBookId;
  final int? sourcePageStart;
  final int? sourcePageEnd;
  final String? catalogMetadata;
  final String? catalogSuggestions;
  final String? validationWarnings;
  final double? splitConfidence;
  final String? sourceContentSha256;
  final bool workflowClosed;
  final DateTime createdAt;
  final DateTime updatedAt;
  const PieceRow(
      {required this.id,
      required this.title,
      this.composer,
      this.serverPieceId,
      this.assignedProfileId,
      required this.visibleToProfileIds,
      this.previousVisibleToProfileIds,
      this.primaryInstrument,
      this.bookOrCollection,
      required this.libraryStatus,
      required this.normalizedTitle,
      this.normalizedComposer,
      required this.sortTitle,
      this.sortComposer,
      this.opus,
      this.movement,
      this.keySignature,
      this.tempo,
      this.difficulty,
      this.genre,
      this.notes,
      this.processedMetadata,
      required this.pieceKind,
      this.sourceBookId,
      this.sourcePageStart,
      this.sourcePageEnd,
      this.catalogMetadata,
      this.catalogSuggestions,
      this.validationWarnings,
      this.splitConfidence,
      this.sourceContentSha256,
      required this.workflowClosed,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || composer != null) {
      map['composer'] = Variable<String>(composer);
    }
    if (!nullToAbsent || serverPieceId != null) {
      map['server_piece_id'] = Variable<String>(serverPieceId);
    }
    if (!nullToAbsent || assignedProfileId != null) {
      map['assigned_profile_id'] = Variable<String>(assignedProfileId);
    }
    map['visible_to_profile_ids'] = Variable<String>(visibleToProfileIds);
    if (!nullToAbsent || previousVisibleToProfileIds != null) {
      map['previous_visible_to_profile_ids'] =
          Variable<String>(previousVisibleToProfileIds);
    }
    if (!nullToAbsent || primaryInstrument != null) {
      map['primary_instrument'] = Variable<String>(primaryInstrument);
    }
    if (!nullToAbsent || bookOrCollection != null) {
      map['book_or_collection'] = Variable<String>(bookOrCollection);
    }
    map['library_status'] = Variable<String>(libraryStatus);
    map['normalized_title'] = Variable<String>(normalizedTitle);
    if (!nullToAbsent || normalizedComposer != null) {
      map['normalized_composer'] = Variable<String>(normalizedComposer);
    }
    map['sort_title'] = Variable<String>(sortTitle);
    if (!nullToAbsent || sortComposer != null) {
      map['sort_composer'] = Variable<String>(sortComposer);
    }
    if (!nullToAbsent || opus != null) {
      map['opus'] = Variable<String>(opus);
    }
    if (!nullToAbsent || movement != null) {
      map['movement'] = Variable<String>(movement);
    }
    if (!nullToAbsent || keySignature != null) {
      map['key_signature'] = Variable<String>(keySignature);
    }
    if (!nullToAbsent || tempo != null) {
      map['tempo'] = Variable<String>(tempo);
    }
    if (!nullToAbsent || difficulty != null) {
      map['difficulty'] = Variable<String>(difficulty);
    }
    if (!nullToAbsent || genre != null) {
      map['genre'] = Variable<String>(genre);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || processedMetadata != null) {
      map['processed_metadata'] = Variable<String>(processedMetadata);
    }
    map['piece_kind'] = Variable<String>(pieceKind);
    if (!nullToAbsent || sourceBookId != null) {
      map['source_book_id'] = Variable<String>(sourceBookId);
    }
    if (!nullToAbsent || sourcePageStart != null) {
      map['source_page_start'] = Variable<int>(sourcePageStart);
    }
    if (!nullToAbsent || sourcePageEnd != null) {
      map['source_page_end'] = Variable<int>(sourcePageEnd);
    }
    if (!nullToAbsent || catalogMetadata != null) {
      map['catalog_metadata'] = Variable<String>(catalogMetadata);
    }
    if (!nullToAbsent || catalogSuggestions != null) {
      map['catalog_suggestions'] = Variable<String>(catalogSuggestions);
    }
    if (!nullToAbsent || validationWarnings != null) {
      map['validation_warnings'] = Variable<String>(validationWarnings);
    }
    if (!nullToAbsent || splitConfidence != null) {
      map['split_confidence'] = Variable<double>(splitConfidence);
    }
    if (!nullToAbsent || sourceContentSha256 != null) {
      map['source_content_sha256'] = Variable<String>(sourceContentSha256);
    }
    map['workflow_closed'] = Variable<bool>(workflowClosed);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PiecesCompanion toCompanion(bool nullToAbsent) {
    return PiecesCompanion(
      id: Value(id),
      title: Value(title),
      composer: composer == null && nullToAbsent
          ? const Value.absent()
          : Value(composer),
      serverPieceId: serverPieceId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverPieceId),
      assignedProfileId: assignedProfileId == null && nullToAbsent
          ? const Value.absent()
          : Value(assignedProfileId),
      visibleToProfileIds: Value(visibleToProfileIds),
      previousVisibleToProfileIds:
          previousVisibleToProfileIds == null && nullToAbsent
              ? const Value.absent()
              : Value(previousVisibleToProfileIds),
      primaryInstrument: primaryInstrument == null && nullToAbsent
          ? const Value.absent()
          : Value(primaryInstrument),
      bookOrCollection: bookOrCollection == null && nullToAbsent
          ? const Value.absent()
          : Value(bookOrCollection),
      libraryStatus: Value(libraryStatus),
      normalizedTitle: Value(normalizedTitle),
      normalizedComposer: normalizedComposer == null && nullToAbsent
          ? const Value.absent()
          : Value(normalizedComposer),
      sortTitle: Value(sortTitle),
      sortComposer: sortComposer == null && nullToAbsent
          ? const Value.absent()
          : Value(sortComposer),
      opus: opus == null && nullToAbsent ? const Value.absent() : Value(opus),
      movement: movement == null && nullToAbsent
          ? const Value.absent()
          : Value(movement),
      keySignature: keySignature == null && nullToAbsent
          ? const Value.absent()
          : Value(keySignature),
      tempo:
          tempo == null && nullToAbsent ? const Value.absent() : Value(tempo),
      difficulty: difficulty == null && nullToAbsent
          ? const Value.absent()
          : Value(difficulty),
      genre:
          genre == null && nullToAbsent ? const Value.absent() : Value(genre),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
      processedMetadata: processedMetadata == null && nullToAbsent
          ? const Value.absent()
          : Value(processedMetadata),
      pieceKind: Value(pieceKind),
      sourceBookId: sourceBookId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceBookId),
      sourcePageStart: sourcePageStart == null && nullToAbsent
          ? const Value.absent()
          : Value(sourcePageStart),
      sourcePageEnd: sourcePageEnd == null && nullToAbsent
          ? const Value.absent()
          : Value(sourcePageEnd),
      catalogMetadata: catalogMetadata == null && nullToAbsent
          ? const Value.absent()
          : Value(catalogMetadata),
      catalogSuggestions: catalogSuggestions == null && nullToAbsent
          ? const Value.absent()
          : Value(catalogSuggestions),
      validationWarnings: validationWarnings == null && nullToAbsent
          ? const Value.absent()
          : Value(validationWarnings),
      splitConfidence: splitConfidence == null && nullToAbsent
          ? const Value.absent()
          : Value(splitConfidence),
      sourceContentSha256: sourceContentSha256 == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceContentSha256),
      workflowClosed: Value(workflowClosed),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory PieceRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PieceRow(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      composer: serializer.fromJson<String?>(json['composer']),
      serverPieceId: serializer.fromJson<String?>(json['serverPieceId']),
      assignedProfileId:
          serializer.fromJson<String?>(json['assignedProfileId']),
      visibleToProfileIds:
          serializer.fromJson<String>(json['visibleToProfileIds']),
      previousVisibleToProfileIds:
          serializer.fromJson<String?>(json['previousVisibleToProfileIds']),
      primaryInstrument:
          serializer.fromJson<String?>(json['primaryInstrument']),
      bookOrCollection: serializer.fromJson<String?>(json['bookOrCollection']),
      libraryStatus: serializer.fromJson<String>(json['libraryStatus']),
      normalizedTitle: serializer.fromJson<String>(json['normalizedTitle']),
      normalizedComposer:
          serializer.fromJson<String?>(json['normalizedComposer']),
      sortTitle: serializer.fromJson<String>(json['sortTitle']),
      sortComposer: serializer.fromJson<String?>(json['sortComposer']),
      opus: serializer.fromJson<String?>(json['opus']),
      movement: serializer.fromJson<String?>(json['movement']),
      keySignature: serializer.fromJson<String?>(json['keySignature']),
      tempo: serializer.fromJson<String?>(json['tempo']),
      difficulty: serializer.fromJson<String?>(json['difficulty']),
      genre: serializer.fromJson<String?>(json['genre']),
      notes: serializer.fromJson<String?>(json['notes']),
      processedMetadata:
          serializer.fromJson<String?>(json['processedMetadata']),
      pieceKind: serializer.fromJson<String>(json['pieceKind']),
      sourceBookId: serializer.fromJson<String?>(json['sourceBookId']),
      sourcePageStart: serializer.fromJson<int?>(json['sourcePageStart']),
      sourcePageEnd: serializer.fromJson<int?>(json['sourcePageEnd']),
      catalogMetadata: serializer.fromJson<String?>(json['catalogMetadata']),
      catalogSuggestions:
          serializer.fromJson<String?>(json['catalogSuggestions']),
      validationWarnings:
          serializer.fromJson<String?>(json['validationWarnings']),
      splitConfidence: serializer.fromJson<double?>(json['splitConfidence']),
      sourceContentSha256:
          serializer.fromJson<String?>(json['sourceContentSha256']),
      workflowClosed: serializer.fromJson<bool>(json['workflowClosed']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'composer': serializer.toJson<String?>(composer),
      'serverPieceId': serializer.toJson<String?>(serverPieceId),
      'assignedProfileId': serializer.toJson<String?>(assignedProfileId),
      'visibleToProfileIds': serializer.toJson<String>(visibleToProfileIds),
      'previousVisibleToProfileIds':
          serializer.toJson<String?>(previousVisibleToProfileIds),
      'primaryInstrument': serializer.toJson<String?>(primaryInstrument),
      'bookOrCollection': serializer.toJson<String?>(bookOrCollection),
      'libraryStatus': serializer.toJson<String>(libraryStatus),
      'normalizedTitle': serializer.toJson<String>(normalizedTitle),
      'normalizedComposer': serializer.toJson<String?>(normalizedComposer),
      'sortTitle': serializer.toJson<String>(sortTitle),
      'sortComposer': serializer.toJson<String?>(sortComposer),
      'opus': serializer.toJson<String?>(opus),
      'movement': serializer.toJson<String?>(movement),
      'keySignature': serializer.toJson<String?>(keySignature),
      'tempo': serializer.toJson<String?>(tempo),
      'difficulty': serializer.toJson<String?>(difficulty),
      'genre': serializer.toJson<String?>(genre),
      'notes': serializer.toJson<String?>(notes),
      'processedMetadata': serializer.toJson<String?>(processedMetadata),
      'pieceKind': serializer.toJson<String>(pieceKind),
      'sourceBookId': serializer.toJson<String?>(sourceBookId),
      'sourcePageStart': serializer.toJson<int?>(sourcePageStart),
      'sourcePageEnd': serializer.toJson<int?>(sourcePageEnd),
      'catalogMetadata': serializer.toJson<String?>(catalogMetadata),
      'catalogSuggestions': serializer.toJson<String?>(catalogSuggestions),
      'validationWarnings': serializer.toJson<String?>(validationWarnings),
      'splitConfidence': serializer.toJson<double?>(splitConfidence),
      'sourceContentSha256': serializer.toJson<String?>(sourceContentSha256),
      'workflowClosed': serializer.toJson<bool>(workflowClosed),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  PieceRow copyWith(
          {String? id,
          String? title,
          Value<String?> composer = const Value.absent(),
          Value<String?> serverPieceId = const Value.absent(),
          Value<String?> assignedProfileId = const Value.absent(),
          String? visibleToProfileIds,
          Value<String?> previousVisibleToProfileIds = const Value.absent(),
          Value<String?> primaryInstrument = const Value.absent(),
          Value<String?> bookOrCollection = const Value.absent(),
          String? libraryStatus,
          String? normalizedTitle,
          Value<String?> normalizedComposer = const Value.absent(),
          String? sortTitle,
          Value<String?> sortComposer = const Value.absent(),
          Value<String?> opus = const Value.absent(),
          Value<String?> movement = const Value.absent(),
          Value<String?> keySignature = const Value.absent(),
          Value<String?> tempo = const Value.absent(),
          Value<String?> difficulty = const Value.absent(),
          Value<String?> genre = const Value.absent(),
          Value<String?> notes = const Value.absent(),
          Value<String?> processedMetadata = const Value.absent(),
          String? pieceKind,
          Value<String?> sourceBookId = const Value.absent(),
          Value<int?> sourcePageStart = const Value.absent(),
          Value<int?> sourcePageEnd = const Value.absent(),
          Value<String?> catalogMetadata = const Value.absent(),
          Value<String?> catalogSuggestions = const Value.absent(),
          Value<String?> validationWarnings = const Value.absent(),
          Value<double?> splitConfidence = const Value.absent(),
          Value<String?> sourceContentSha256 = const Value.absent(),
          bool? workflowClosed,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      PieceRow(
        id: id ?? this.id,
        title: title ?? this.title,
        composer: composer.present ? composer.value : this.composer,
        serverPieceId:
            serverPieceId.present ? serverPieceId.value : this.serverPieceId,
        assignedProfileId: assignedProfileId.present
            ? assignedProfileId.value
            : this.assignedProfileId,
        visibleToProfileIds: visibleToProfileIds ?? this.visibleToProfileIds,
        previousVisibleToProfileIds: previousVisibleToProfileIds.present
            ? previousVisibleToProfileIds.value
            : this.previousVisibleToProfileIds,
        primaryInstrument: primaryInstrument.present
            ? primaryInstrument.value
            : this.primaryInstrument,
        bookOrCollection: bookOrCollection.present
            ? bookOrCollection.value
            : this.bookOrCollection,
        libraryStatus: libraryStatus ?? this.libraryStatus,
        normalizedTitle: normalizedTitle ?? this.normalizedTitle,
        normalizedComposer: normalizedComposer.present
            ? normalizedComposer.value
            : this.normalizedComposer,
        sortTitle: sortTitle ?? this.sortTitle,
        sortComposer:
            sortComposer.present ? sortComposer.value : this.sortComposer,
        opus: opus.present ? opus.value : this.opus,
        movement: movement.present ? movement.value : this.movement,
        keySignature:
            keySignature.present ? keySignature.value : this.keySignature,
        tempo: tempo.present ? tempo.value : this.tempo,
        difficulty: difficulty.present ? difficulty.value : this.difficulty,
        genre: genre.present ? genre.value : this.genre,
        notes: notes.present ? notes.value : this.notes,
        processedMetadata: processedMetadata.present
            ? processedMetadata.value
            : this.processedMetadata,
        pieceKind: pieceKind ?? this.pieceKind,
        sourceBookId:
            sourceBookId.present ? sourceBookId.value : this.sourceBookId,
        sourcePageStart: sourcePageStart.present
            ? sourcePageStart.value
            : this.sourcePageStart,
        sourcePageEnd:
            sourcePageEnd.present ? sourcePageEnd.value : this.sourcePageEnd,
        catalogMetadata: catalogMetadata.present
            ? catalogMetadata.value
            : this.catalogMetadata,
        catalogSuggestions: catalogSuggestions.present
            ? catalogSuggestions.value
            : this.catalogSuggestions,
        validationWarnings: validationWarnings.present
            ? validationWarnings.value
            : this.validationWarnings,
        splitConfidence: splitConfidence.present
            ? splitConfidence.value
            : this.splitConfidence,
        sourceContentSha256: sourceContentSha256.present
            ? sourceContentSha256.value
            : this.sourceContentSha256,
        workflowClosed: workflowClosed ?? this.workflowClosed,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  PieceRow copyWithCompanion(PiecesCompanion data) {
    return PieceRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      composer: data.composer.present ? data.composer.value : this.composer,
      serverPieceId: data.serverPieceId.present
          ? data.serverPieceId.value
          : this.serverPieceId,
      assignedProfileId: data.assignedProfileId.present
          ? data.assignedProfileId.value
          : this.assignedProfileId,
      visibleToProfileIds: data.visibleToProfileIds.present
          ? data.visibleToProfileIds.value
          : this.visibleToProfileIds,
      previousVisibleToProfileIds: data.previousVisibleToProfileIds.present
          ? data.previousVisibleToProfileIds.value
          : this.previousVisibleToProfileIds,
      primaryInstrument: data.primaryInstrument.present
          ? data.primaryInstrument.value
          : this.primaryInstrument,
      bookOrCollection: data.bookOrCollection.present
          ? data.bookOrCollection.value
          : this.bookOrCollection,
      libraryStatus: data.libraryStatus.present
          ? data.libraryStatus.value
          : this.libraryStatus,
      normalizedTitle: data.normalizedTitle.present
          ? data.normalizedTitle.value
          : this.normalizedTitle,
      normalizedComposer: data.normalizedComposer.present
          ? data.normalizedComposer.value
          : this.normalizedComposer,
      sortTitle: data.sortTitle.present ? data.sortTitle.value : this.sortTitle,
      sortComposer: data.sortComposer.present
          ? data.sortComposer.value
          : this.sortComposer,
      opus: data.opus.present ? data.opus.value : this.opus,
      movement: data.movement.present ? data.movement.value : this.movement,
      keySignature: data.keySignature.present
          ? data.keySignature.value
          : this.keySignature,
      tempo: data.tempo.present ? data.tempo.value : this.tempo,
      difficulty:
          data.difficulty.present ? data.difficulty.value : this.difficulty,
      genre: data.genre.present ? data.genre.value : this.genre,
      notes: data.notes.present ? data.notes.value : this.notes,
      processedMetadata: data.processedMetadata.present
          ? data.processedMetadata.value
          : this.processedMetadata,
      pieceKind: data.pieceKind.present ? data.pieceKind.value : this.pieceKind,
      sourceBookId: data.sourceBookId.present
          ? data.sourceBookId.value
          : this.sourceBookId,
      sourcePageStart: data.sourcePageStart.present
          ? data.sourcePageStart.value
          : this.sourcePageStart,
      sourcePageEnd: data.sourcePageEnd.present
          ? data.sourcePageEnd.value
          : this.sourcePageEnd,
      catalogMetadata: data.catalogMetadata.present
          ? data.catalogMetadata.value
          : this.catalogMetadata,
      catalogSuggestions: data.catalogSuggestions.present
          ? data.catalogSuggestions.value
          : this.catalogSuggestions,
      validationWarnings: data.validationWarnings.present
          ? data.validationWarnings.value
          : this.validationWarnings,
      splitConfidence: data.splitConfidence.present
          ? data.splitConfidence.value
          : this.splitConfidence,
      sourceContentSha256: data.sourceContentSha256.present
          ? data.sourceContentSha256.value
          : this.sourceContentSha256,
      workflowClosed: data.workflowClosed.present
          ? data.workflowClosed.value
          : this.workflowClosed,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PieceRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('composer: $composer, ')
          ..write('serverPieceId: $serverPieceId, ')
          ..write('assignedProfileId: $assignedProfileId, ')
          ..write('visibleToProfileIds: $visibleToProfileIds, ')
          ..write('previousVisibleToProfileIds: $previousVisibleToProfileIds, ')
          ..write('primaryInstrument: $primaryInstrument, ')
          ..write('bookOrCollection: $bookOrCollection, ')
          ..write('libraryStatus: $libraryStatus, ')
          ..write('normalizedTitle: $normalizedTitle, ')
          ..write('normalizedComposer: $normalizedComposer, ')
          ..write('sortTitle: $sortTitle, ')
          ..write('sortComposer: $sortComposer, ')
          ..write('opus: $opus, ')
          ..write('movement: $movement, ')
          ..write('keySignature: $keySignature, ')
          ..write('tempo: $tempo, ')
          ..write('difficulty: $difficulty, ')
          ..write('genre: $genre, ')
          ..write('notes: $notes, ')
          ..write('processedMetadata: $processedMetadata, ')
          ..write('pieceKind: $pieceKind, ')
          ..write('sourceBookId: $sourceBookId, ')
          ..write('sourcePageStart: $sourcePageStart, ')
          ..write('sourcePageEnd: $sourcePageEnd, ')
          ..write('catalogMetadata: $catalogMetadata, ')
          ..write('catalogSuggestions: $catalogSuggestions, ')
          ..write('validationWarnings: $validationWarnings, ')
          ..write('splitConfidence: $splitConfidence, ')
          ..write('sourceContentSha256: $sourceContentSha256, ')
          ..write('workflowClosed: $workflowClosed, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
        id,
        title,
        composer,
        serverPieceId,
        assignedProfileId,
        visibleToProfileIds,
        previousVisibleToProfileIds,
        primaryInstrument,
        bookOrCollection,
        libraryStatus,
        normalizedTitle,
        normalizedComposer,
        sortTitle,
        sortComposer,
        opus,
        movement,
        keySignature,
        tempo,
        difficulty,
        genre,
        notes,
        processedMetadata,
        pieceKind,
        sourceBookId,
        sourcePageStart,
        sourcePageEnd,
        catalogMetadata,
        catalogSuggestions,
        validationWarnings,
        splitConfidence,
        sourceContentSha256,
        workflowClosed,
        createdAt,
        updatedAt
      ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PieceRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.composer == this.composer &&
          other.serverPieceId == this.serverPieceId &&
          other.assignedProfileId == this.assignedProfileId &&
          other.visibleToProfileIds == this.visibleToProfileIds &&
          other.previousVisibleToProfileIds ==
              this.previousVisibleToProfileIds &&
          other.primaryInstrument == this.primaryInstrument &&
          other.bookOrCollection == this.bookOrCollection &&
          other.libraryStatus == this.libraryStatus &&
          other.normalizedTitle == this.normalizedTitle &&
          other.normalizedComposer == this.normalizedComposer &&
          other.sortTitle == this.sortTitle &&
          other.sortComposer == this.sortComposer &&
          other.opus == this.opus &&
          other.movement == this.movement &&
          other.keySignature == this.keySignature &&
          other.tempo == this.tempo &&
          other.difficulty == this.difficulty &&
          other.genre == this.genre &&
          other.notes == this.notes &&
          other.processedMetadata == this.processedMetadata &&
          other.pieceKind == this.pieceKind &&
          other.sourceBookId == this.sourceBookId &&
          other.sourcePageStart == this.sourcePageStart &&
          other.sourcePageEnd == this.sourcePageEnd &&
          other.catalogMetadata == this.catalogMetadata &&
          other.catalogSuggestions == this.catalogSuggestions &&
          other.validationWarnings == this.validationWarnings &&
          other.splitConfidence == this.splitConfidence &&
          other.sourceContentSha256 == this.sourceContentSha256 &&
          other.workflowClosed == this.workflowClosed &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class PiecesCompanion extends UpdateCompanion<PieceRow> {
  final Value<String> id;
  final Value<String> title;
  final Value<String?> composer;
  final Value<String?> serverPieceId;
  final Value<String?> assignedProfileId;
  final Value<String> visibleToProfileIds;
  final Value<String?> previousVisibleToProfileIds;
  final Value<String?> primaryInstrument;
  final Value<String?> bookOrCollection;
  final Value<String> libraryStatus;
  final Value<String> normalizedTitle;
  final Value<String?> normalizedComposer;
  final Value<String> sortTitle;
  final Value<String?> sortComposer;
  final Value<String?> opus;
  final Value<String?> movement;
  final Value<String?> keySignature;
  final Value<String?> tempo;
  final Value<String?> difficulty;
  final Value<String?> genre;
  final Value<String?> notes;
  final Value<String?> processedMetadata;
  final Value<String> pieceKind;
  final Value<String?> sourceBookId;
  final Value<int?> sourcePageStart;
  final Value<int?> sourcePageEnd;
  final Value<String?> catalogMetadata;
  final Value<String?> catalogSuggestions;
  final Value<String?> validationWarnings;
  final Value<double?> splitConfidence;
  final Value<String?> sourceContentSha256;
  final Value<bool> workflowClosed;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const PiecesCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.composer = const Value.absent(),
    this.serverPieceId = const Value.absent(),
    this.assignedProfileId = const Value.absent(),
    this.visibleToProfileIds = const Value.absent(),
    this.previousVisibleToProfileIds = const Value.absent(),
    this.primaryInstrument = const Value.absent(),
    this.bookOrCollection = const Value.absent(),
    this.libraryStatus = const Value.absent(),
    this.normalizedTitle = const Value.absent(),
    this.normalizedComposer = const Value.absent(),
    this.sortTitle = const Value.absent(),
    this.sortComposer = const Value.absent(),
    this.opus = const Value.absent(),
    this.movement = const Value.absent(),
    this.keySignature = const Value.absent(),
    this.tempo = const Value.absent(),
    this.difficulty = const Value.absent(),
    this.genre = const Value.absent(),
    this.notes = const Value.absent(),
    this.processedMetadata = const Value.absent(),
    this.pieceKind = const Value.absent(),
    this.sourceBookId = const Value.absent(),
    this.sourcePageStart = const Value.absent(),
    this.sourcePageEnd = const Value.absent(),
    this.catalogMetadata = const Value.absent(),
    this.catalogSuggestions = const Value.absent(),
    this.validationWarnings = const Value.absent(),
    this.splitConfidence = const Value.absent(),
    this.sourceContentSha256 = const Value.absent(),
    this.workflowClosed = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PiecesCompanion.insert({
    required String id,
    required String title,
    this.composer = const Value.absent(),
    this.serverPieceId = const Value.absent(),
    this.assignedProfileId = const Value.absent(),
    required String visibleToProfileIds,
    this.previousVisibleToProfileIds = const Value.absent(),
    this.primaryInstrument = const Value.absent(),
    this.bookOrCollection = const Value.absent(),
    required String libraryStatus,
    required String normalizedTitle,
    this.normalizedComposer = const Value.absent(),
    required String sortTitle,
    this.sortComposer = const Value.absent(),
    this.opus = const Value.absent(),
    this.movement = const Value.absent(),
    this.keySignature = const Value.absent(),
    this.tempo = const Value.absent(),
    this.difficulty = const Value.absent(),
    this.genre = const Value.absent(),
    this.notes = const Value.absent(),
    this.processedMetadata = const Value.absent(),
    this.pieceKind = const Value.absent(),
    this.sourceBookId = const Value.absent(),
    this.sourcePageStart = const Value.absent(),
    this.sourcePageEnd = const Value.absent(),
    this.catalogMetadata = const Value.absent(),
    this.catalogSuggestions = const Value.absent(),
    this.validationWarnings = const Value.absent(),
    this.splitConfidence = const Value.absent(),
    this.sourceContentSha256 = const Value.absent(),
    this.workflowClosed = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        title = Value(title),
        visibleToProfileIds = Value(visibleToProfileIds),
        libraryStatus = Value(libraryStatus),
        normalizedTitle = Value(normalizedTitle),
        sortTitle = Value(sortTitle),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<PieceRow> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? composer,
    Expression<String>? serverPieceId,
    Expression<String>? assignedProfileId,
    Expression<String>? visibleToProfileIds,
    Expression<String>? previousVisibleToProfileIds,
    Expression<String>? primaryInstrument,
    Expression<String>? bookOrCollection,
    Expression<String>? libraryStatus,
    Expression<String>? normalizedTitle,
    Expression<String>? normalizedComposer,
    Expression<String>? sortTitle,
    Expression<String>? sortComposer,
    Expression<String>? opus,
    Expression<String>? movement,
    Expression<String>? keySignature,
    Expression<String>? tempo,
    Expression<String>? difficulty,
    Expression<String>? genre,
    Expression<String>? notes,
    Expression<String>? processedMetadata,
    Expression<String>? pieceKind,
    Expression<String>? sourceBookId,
    Expression<int>? sourcePageStart,
    Expression<int>? sourcePageEnd,
    Expression<String>? catalogMetadata,
    Expression<String>? catalogSuggestions,
    Expression<String>? validationWarnings,
    Expression<double>? splitConfidence,
    Expression<String>? sourceContentSha256,
    Expression<bool>? workflowClosed,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (composer != null) 'composer': composer,
      if (serverPieceId != null) 'server_piece_id': serverPieceId,
      if (assignedProfileId != null) 'assigned_profile_id': assignedProfileId,
      if (visibleToProfileIds != null)
        'visible_to_profile_ids': visibleToProfileIds,
      if (previousVisibleToProfileIds != null)
        'previous_visible_to_profile_ids': previousVisibleToProfileIds,
      if (primaryInstrument != null) 'primary_instrument': primaryInstrument,
      if (bookOrCollection != null) 'book_or_collection': bookOrCollection,
      if (libraryStatus != null) 'library_status': libraryStatus,
      if (normalizedTitle != null) 'normalized_title': normalizedTitle,
      if (normalizedComposer != null) 'normalized_composer': normalizedComposer,
      if (sortTitle != null) 'sort_title': sortTitle,
      if (sortComposer != null) 'sort_composer': sortComposer,
      if (opus != null) 'opus': opus,
      if (movement != null) 'movement': movement,
      if (keySignature != null) 'key_signature': keySignature,
      if (tempo != null) 'tempo': tempo,
      if (difficulty != null) 'difficulty': difficulty,
      if (genre != null) 'genre': genre,
      if (notes != null) 'notes': notes,
      if (processedMetadata != null) 'processed_metadata': processedMetadata,
      if (pieceKind != null) 'piece_kind': pieceKind,
      if (sourceBookId != null) 'source_book_id': sourceBookId,
      if (sourcePageStart != null) 'source_page_start': sourcePageStart,
      if (sourcePageEnd != null) 'source_page_end': sourcePageEnd,
      if (catalogMetadata != null) 'catalog_metadata': catalogMetadata,
      if (catalogSuggestions != null) 'catalog_suggestions': catalogSuggestions,
      if (validationWarnings != null) 'validation_warnings': validationWarnings,
      if (splitConfidence != null) 'split_confidence': splitConfidence,
      if (sourceContentSha256 != null)
        'source_content_sha256': sourceContentSha256,
      if (workflowClosed != null) 'workflow_closed': workflowClosed,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PiecesCompanion copyWith(
      {Value<String>? id,
      Value<String>? title,
      Value<String?>? composer,
      Value<String?>? serverPieceId,
      Value<String?>? assignedProfileId,
      Value<String>? visibleToProfileIds,
      Value<String?>? previousVisibleToProfileIds,
      Value<String?>? primaryInstrument,
      Value<String?>? bookOrCollection,
      Value<String>? libraryStatus,
      Value<String>? normalizedTitle,
      Value<String?>? normalizedComposer,
      Value<String>? sortTitle,
      Value<String?>? sortComposer,
      Value<String?>? opus,
      Value<String?>? movement,
      Value<String?>? keySignature,
      Value<String?>? tempo,
      Value<String?>? difficulty,
      Value<String?>? genre,
      Value<String?>? notes,
      Value<String?>? processedMetadata,
      Value<String>? pieceKind,
      Value<String?>? sourceBookId,
      Value<int?>? sourcePageStart,
      Value<int?>? sourcePageEnd,
      Value<String?>? catalogMetadata,
      Value<String?>? catalogSuggestions,
      Value<String?>? validationWarnings,
      Value<double?>? splitConfidence,
      Value<String?>? sourceContentSha256,
      Value<bool>? workflowClosed,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return PiecesCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      composer: composer ?? this.composer,
      serverPieceId: serverPieceId ?? this.serverPieceId,
      assignedProfileId: assignedProfileId ?? this.assignedProfileId,
      visibleToProfileIds: visibleToProfileIds ?? this.visibleToProfileIds,
      previousVisibleToProfileIds:
          previousVisibleToProfileIds ?? this.previousVisibleToProfileIds,
      primaryInstrument: primaryInstrument ?? this.primaryInstrument,
      bookOrCollection: bookOrCollection ?? this.bookOrCollection,
      libraryStatus: libraryStatus ?? this.libraryStatus,
      normalizedTitle: normalizedTitle ?? this.normalizedTitle,
      normalizedComposer: normalizedComposer ?? this.normalizedComposer,
      sortTitle: sortTitle ?? this.sortTitle,
      sortComposer: sortComposer ?? this.sortComposer,
      opus: opus ?? this.opus,
      movement: movement ?? this.movement,
      keySignature: keySignature ?? this.keySignature,
      tempo: tempo ?? this.tempo,
      difficulty: difficulty ?? this.difficulty,
      genre: genre ?? this.genre,
      notes: notes ?? this.notes,
      processedMetadata: processedMetadata ?? this.processedMetadata,
      pieceKind: pieceKind ?? this.pieceKind,
      sourceBookId: sourceBookId ?? this.sourceBookId,
      sourcePageStart: sourcePageStart ?? this.sourcePageStart,
      sourcePageEnd: sourcePageEnd ?? this.sourcePageEnd,
      catalogMetadata: catalogMetadata ?? this.catalogMetadata,
      catalogSuggestions: catalogSuggestions ?? this.catalogSuggestions,
      validationWarnings: validationWarnings ?? this.validationWarnings,
      splitConfidence: splitConfidence ?? this.splitConfidence,
      sourceContentSha256: sourceContentSha256 ?? this.sourceContentSha256,
      workflowClosed: workflowClosed ?? this.workflowClosed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (composer.present) {
      map['composer'] = Variable<String>(composer.value);
    }
    if (serverPieceId.present) {
      map['server_piece_id'] = Variable<String>(serverPieceId.value);
    }
    if (assignedProfileId.present) {
      map['assigned_profile_id'] = Variable<String>(assignedProfileId.value);
    }
    if (visibleToProfileIds.present) {
      map['visible_to_profile_ids'] =
          Variable<String>(visibleToProfileIds.value);
    }
    if (previousVisibleToProfileIds.present) {
      map['previous_visible_to_profile_ids'] =
          Variable<String>(previousVisibleToProfileIds.value);
    }
    if (primaryInstrument.present) {
      map['primary_instrument'] = Variable<String>(primaryInstrument.value);
    }
    if (bookOrCollection.present) {
      map['book_or_collection'] = Variable<String>(bookOrCollection.value);
    }
    if (libraryStatus.present) {
      map['library_status'] = Variable<String>(libraryStatus.value);
    }
    if (normalizedTitle.present) {
      map['normalized_title'] = Variable<String>(normalizedTitle.value);
    }
    if (normalizedComposer.present) {
      map['normalized_composer'] = Variable<String>(normalizedComposer.value);
    }
    if (sortTitle.present) {
      map['sort_title'] = Variable<String>(sortTitle.value);
    }
    if (sortComposer.present) {
      map['sort_composer'] = Variable<String>(sortComposer.value);
    }
    if (opus.present) {
      map['opus'] = Variable<String>(opus.value);
    }
    if (movement.present) {
      map['movement'] = Variable<String>(movement.value);
    }
    if (keySignature.present) {
      map['key_signature'] = Variable<String>(keySignature.value);
    }
    if (tempo.present) {
      map['tempo'] = Variable<String>(tempo.value);
    }
    if (difficulty.present) {
      map['difficulty'] = Variable<String>(difficulty.value);
    }
    if (genre.present) {
      map['genre'] = Variable<String>(genre.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (processedMetadata.present) {
      map['processed_metadata'] = Variable<String>(processedMetadata.value);
    }
    if (pieceKind.present) {
      map['piece_kind'] = Variable<String>(pieceKind.value);
    }
    if (sourceBookId.present) {
      map['source_book_id'] = Variable<String>(sourceBookId.value);
    }
    if (sourcePageStart.present) {
      map['source_page_start'] = Variable<int>(sourcePageStart.value);
    }
    if (sourcePageEnd.present) {
      map['source_page_end'] = Variable<int>(sourcePageEnd.value);
    }
    if (catalogMetadata.present) {
      map['catalog_metadata'] = Variable<String>(catalogMetadata.value);
    }
    if (catalogSuggestions.present) {
      map['catalog_suggestions'] = Variable<String>(catalogSuggestions.value);
    }
    if (validationWarnings.present) {
      map['validation_warnings'] = Variable<String>(validationWarnings.value);
    }
    if (splitConfidence.present) {
      map['split_confidence'] = Variable<double>(splitConfidence.value);
    }
    if (sourceContentSha256.present) {
      map['source_content_sha256'] =
          Variable<String>(sourceContentSha256.value);
    }
    if (workflowClosed.present) {
      map['workflow_closed'] = Variable<bool>(workflowClosed.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PiecesCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('composer: $composer, ')
          ..write('serverPieceId: $serverPieceId, ')
          ..write('assignedProfileId: $assignedProfileId, ')
          ..write('visibleToProfileIds: $visibleToProfileIds, ')
          ..write('previousVisibleToProfileIds: $previousVisibleToProfileIds, ')
          ..write('primaryInstrument: $primaryInstrument, ')
          ..write('bookOrCollection: $bookOrCollection, ')
          ..write('libraryStatus: $libraryStatus, ')
          ..write('normalizedTitle: $normalizedTitle, ')
          ..write('normalizedComposer: $normalizedComposer, ')
          ..write('sortTitle: $sortTitle, ')
          ..write('sortComposer: $sortComposer, ')
          ..write('opus: $opus, ')
          ..write('movement: $movement, ')
          ..write('keySignature: $keySignature, ')
          ..write('tempo: $tempo, ')
          ..write('difficulty: $difficulty, ')
          ..write('genre: $genre, ')
          ..write('notes: $notes, ')
          ..write('processedMetadata: $processedMetadata, ')
          ..write('pieceKind: $pieceKind, ')
          ..write('sourceBookId: $sourceBookId, ')
          ..write('sourcePageStart: $sourcePageStart, ')
          ..write('sourcePageEnd: $sourcePageEnd, ')
          ..write('catalogMetadata: $catalogMetadata, ')
          ..write('catalogSuggestions: $catalogSuggestions, ')
          ..write('validationWarnings: $validationWarnings, ')
          ..write('splitConfidence: $splitConfidence, ')
          ..write('sourceContentSha256: $sourceContentSha256, ')
          ..write('workflowClosed: $workflowClosed, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ScoreVersionsTable extends ScoreVersions
    with TableInfo<$ScoreVersionsTable, ScoreVersionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScoreVersionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _pieceIdMeta =
      const VerificationMeta('pieceId');
  @override
  late final GeneratedColumn<String> pieceId = GeneratedColumn<String>(
      'piece_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES pieces (id)'));
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _filePathMeta =
      const VerificationMeta('filePath');
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
      'file_path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _remoteUrlMeta =
      const VerificationMeta('remoteUrl');
  @override
  late final GeneratedColumn<String> remoteUrl = GeneratedColumn<String>(
      'remote_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _versionTypeMeta =
      const VerificationMeta('versionType');
  @override
  late final GeneratedColumn<String> versionType = GeneratedColumn<String>(
      'version_type', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _formatMeta = const VerificationMeta('format');
  @override
  late final GeneratedColumn<String> format = GeneratedColumn<String>(
      'format', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _pageCountMeta =
      const VerificationMeta('pageCount');
  @override
  late final GeneratedColumn<int> pageCount = GeneratedColumn<int>(
      'page_count', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _checksumMeta =
      const VerificationMeta('checksum');
  @override
  late final GeneratedColumn<String> checksum = GeneratedColumn<String>(
      'checksum', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isPrimaryMeta =
      const VerificationMeta('isPrimary');
  @override
  late final GeneratedColumn<bool> isPrimary = GeneratedColumn<bool>(
      'is_primary', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_primary" IN (0, 1))'));
  static const VerificationMeta _isStudentVisibleMeta =
      const VerificationMeta('isStudentVisible');
  @override
  late final GeneratedColumn<bool> isStudentVisible = GeneratedColumn<bool>(
      'is_student_visible', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_student_visible" IN (0, 1))'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        pieceId,
        title,
        filePath,
        remoteUrl,
        versionType,
        format,
        pageCount,
        checksum,
        isPrimary,
        isStudentVisible,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'score_versions';
  @override
  VerificationContext validateIntegrity(Insertable<ScoreVersionRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('piece_id')) {
      context.handle(_pieceIdMeta,
          pieceId.isAcceptableOrUnknown(data['piece_id']!, _pieceIdMeta));
    } else if (isInserting) {
      context.missing(_pieceIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(_filePathMeta,
          filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta));
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('remote_url')) {
      context.handle(_remoteUrlMeta,
          remoteUrl.isAcceptableOrUnknown(data['remote_url']!, _remoteUrlMeta));
    }
    if (data.containsKey('version_type')) {
      context.handle(
          _versionTypeMeta,
          versionType.isAcceptableOrUnknown(
              data['version_type']!, _versionTypeMeta));
    }
    if (data.containsKey('format')) {
      context.handle(_formatMeta,
          format.isAcceptableOrUnknown(data['format']!, _formatMeta));
    } else if (isInserting) {
      context.missing(_formatMeta);
    }
    if (data.containsKey('page_count')) {
      context.handle(_pageCountMeta,
          pageCount.isAcceptableOrUnknown(data['page_count']!, _pageCountMeta));
    }
    if (data.containsKey('checksum')) {
      context.handle(_checksumMeta,
          checksum.isAcceptableOrUnknown(data['checksum']!, _checksumMeta));
    }
    if (data.containsKey('is_primary')) {
      context.handle(_isPrimaryMeta,
          isPrimary.isAcceptableOrUnknown(data['is_primary']!, _isPrimaryMeta));
    } else if (isInserting) {
      context.missing(_isPrimaryMeta);
    }
    if (data.containsKey('is_student_visible')) {
      context.handle(
          _isStudentVisibleMeta,
          isStudentVisible.isAcceptableOrUnknown(
              data['is_student_visible']!, _isStudentVisibleMeta));
    } else if (isInserting) {
      context.missing(_isStudentVisibleMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ScoreVersionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScoreVersionRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      pieceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}piece_id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      filePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}file_path'])!,
      remoteUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}remote_url']),
      versionType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}version_type']),
      format: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}format'])!,
      pageCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}page_count']),
      checksum: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}checksum']),
      isPrimary: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_primary'])!,
      isStudentVisible: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}is_student_visible'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $ScoreVersionsTable createAlias(String alias) {
    return $ScoreVersionsTable(attachedDatabase, alias);
  }
}

class ScoreVersionRow extends DataClass implements Insertable<ScoreVersionRow> {
  final String id;
  final String pieceId;
  final String title;
  final String filePath;
  final String? remoteUrl;
  final String? versionType;
  final String format;
  final int? pageCount;
  final String? checksum;
  final bool isPrimary;
  final bool isStudentVisible;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ScoreVersionRow(
      {required this.id,
      required this.pieceId,
      required this.title,
      required this.filePath,
      this.remoteUrl,
      this.versionType,
      required this.format,
      this.pageCount,
      this.checksum,
      required this.isPrimary,
      required this.isStudentVisible,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['piece_id'] = Variable<String>(pieceId);
    map['title'] = Variable<String>(title);
    map['file_path'] = Variable<String>(filePath);
    if (!nullToAbsent || remoteUrl != null) {
      map['remote_url'] = Variable<String>(remoteUrl);
    }
    if (!nullToAbsent || versionType != null) {
      map['version_type'] = Variable<String>(versionType);
    }
    map['format'] = Variable<String>(format);
    if (!nullToAbsent || pageCount != null) {
      map['page_count'] = Variable<int>(pageCount);
    }
    if (!nullToAbsent || checksum != null) {
      map['checksum'] = Variable<String>(checksum);
    }
    map['is_primary'] = Variable<bool>(isPrimary);
    map['is_student_visible'] = Variable<bool>(isStudentVisible);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ScoreVersionsCompanion toCompanion(bool nullToAbsent) {
    return ScoreVersionsCompanion(
      id: Value(id),
      pieceId: Value(pieceId),
      title: Value(title),
      filePath: Value(filePath),
      remoteUrl: remoteUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteUrl),
      versionType: versionType == null && nullToAbsent
          ? const Value.absent()
          : Value(versionType),
      format: Value(format),
      pageCount: pageCount == null && nullToAbsent
          ? const Value.absent()
          : Value(pageCount),
      checksum: checksum == null && nullToAbsent
          ? const Value.absent()
          : Value(checksum),
      isPrimary: Value(isPrimary),
      isStudentVisible: Value(isStudentVisible),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ScoreVersionRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScoreVersionRow(
      id: serializer.fromJson<String>(json['id']),
      pieceId: serializer.fromJson<String>(json['pieceId']),
      title: serializer.fromJson<String>(json['title']),
      filePath: serializer.fromJson<String>(json['filePath']),
      remoteUrl: serializer.fromJson<String?>(json['remoteUrl']),
      versionType: serializer.fromJson<String?>(json['versionType']),
      format: serializer.fromJson<String>(json['format']),
      pageCount: serializer.fromJson<int?>(json['pageCount']),
      checksum: serializer.fromJson<String?>(json['checksum']),
      isPrimary: serializer.fromJson<bool>(json['isPrimary']),
      isStudentVisible: serializer.fromJson<bool>(json['isStudentVisible']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'pieceId': serializer.toJson<String>(pieceId),
      'title': serializer.toJson<String>(title),
      'filePath': serializer.toJson<String>(filePath),
      'remoteUrl': serializer.toJson<String?>(remoteUrl),
      'versionType': serializer.toJson<String?>(versionType),
      'format': serializer.toJson<String>(format),
      'pageCount': serializer.toJson<int?>(pageCount),
      'checksum': serializer.toJson<String?>(checksum),
      'isPrimary': serializer.toJson<bool>(isPrimary),
      'isStudentVisible': serializer.toJson<bool>(isStudentVisible),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ScoreVersionRow copyWith(
          {String? id,
          String? pieceId,
          String? title,
          String? filePath,
          Value<String?> remoteUrl = const Value.absent(),
          Value<String?> versionType = const Value.absent(),
          String? format,
          Value<int?> pageCount = const Value.absent(),
          Value<String?> checksum = const Value.absent(),
          bool? isPrimary,
          bool? isStudentVisible,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      ScoreVersionRow(
        id: id ?? this.id,
        pieceId: pieceId ?? this.pieceId,
        title: title ?? this.title,
        filePath: filePath ?? this.filePath,
        remoteUrl: remoteUrl.present ? remoteUrl.value : this.remoteUrl,
        versionType: versionType.present ? versionType.value : this.versionType,
        format: format ?? this.format,
        pageCount: pageCount.present ? pageCount.value : this.pageCount,
        checksum: checksum.present ? checksum.value : this.checksum,
        isPrimary: isPrimary ?? this.isPrimary,
        isStudentVisible: isStudentVisible ?? this.isStudentVisible,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  ScoreVersionRow copyWithCompanion(ScoreVersionsCompanion data) {
    return ScoreVersionRow(
      id: data.id.present ? data.id.value : this.id,
      pieceId: data.pieceId.present ? data.pieceId.value : this.pieceId,
      title: data.title.present ? data.title.value : this.title,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      remoteUrl: data.remoteUrl.present ? data.remoteUrl.value : this.remoteUrl,
      versionType:
          data.versionType.present ? data.versionType.value : this.versionType,
      format: data.format.present ? data.format.value : this.format,
      pageCount: data.pageCount.present ? data.pageCount.value : this.pageCount,
      checksum: data.checksum.present ? data.checksum.value : this.checksum,
      isPrimary: data.isPrimary.present ? data.isPrimary.value : this.isPrimary,
      isStudentVisible: data.isStudentVisible.present
          ? data.isStudentVisible.value
          : this.isStudentVisible,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScoreVersionRow(')
          ..write('id: $id, ')
          ..write('pieceId: $pieceId, ')
          ..write('title: $title, ')
          ..write('filePath: $filePath, ')
          ..write('remoteUrl: $remoteUrl, ')
          ..write('versionType: $versionType, ')
          ..write('format: $format, ')
          ..write('pageCount: $pageCount, ')
          ..write('checksum: $checksum, ')
          ..write('isPrimary: $isPrimary, ')
          ..write('isStudentVisible: $isStudentVisible, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      pieceId,
      title,
      filePath,
      remoteUrl,
      versionType,
      format,
      pageCount,
      checksum,
      isPrimary,
      isStudentVisible,
      createdAt,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScoreVersionRow &&
          other.id == this.id &&
          other.pieceId == this.pieceId &&
          other.title == this.title &&
          other.filePath == this.filePath &&
          other.remoteUrl == this.remoteUrl &&
          other.versionType == this.versionType &&
          other.format == this.format &&
          other.pageCount == this.pageCount &&
          other.checksum == this.checksum &&
          other.isPrimary == this.isPrimary &&
          other.isStudentVisible == this.isStudentVisible &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ScoreVersionsCompanion extends UpdateCompanion<ScoreVersionRow> {
  final Value<String> id;
  final Value<String> pieceId;
  final Value<String> title;
  final Value<String> filePath;
  final Value<String?> remoteUrl;
  final Value<String?> versionType;
  final Value<String> format;
  final Value<int?> pageCount;
  final Value<String?> checksum;
  final Value<bool> isPrimary;
  final Value<bool> isStudentVisible;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ScoreVersionsCompanion({
    this.id = const Value.absent(),
    this.pieceId = const Value.absent(),
    this.title = const Value.absent(),
    this.filePath = const Value.absent(),
    this.remoteUrl = const Value.absent(),
    this.versionType = const Value.absent(),
    this.format = const Value.absent(),
    this.pageCount = const Value.absent(),
    this.checksum = const Value.absent(),
    this.isPrimary = const Value.absent(),
    this.isStudentVisible = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ScoreVersionsCompanion.insert({
    required String id,
    required String pieceId,
    required String title,
    required String filePath,
    this.remoteUrl = const Value.absent(),
    this.versionType = const Value.absent(),
    required String format,
    this.pageCount = const Value.absent(),
    this.checksum = const Value.absent(),
    required bool isPrimary,
    required bool isStudentVisible,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        pieceId = Value(pieceId),
        title = Value(title),
        filePath = Value(filePath),
        format = Value(format),
        isPrimary = Value(isPrimary),
        isStudentVisible = Value(isStudentVisible),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<ScoreVersionRow> custom({
    Expression<String>? id,
    Expression<String>? pieceId,
    Expression<String>? title,
    Expression<String>? filePath,
    Expression<String>? remoteUrl,
    Expression<String>? versionType,
    Expression<String>? format,
    Expression<int>? pageCount,
    Expression<String>? checksum,
    Expression<bool>? isPrimary,
    Expression<bool>? isStudentVisible,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (pieceId != null) 'piece_id': pieceId,
      if (title != null) 'title': title,
      if (filePath != null) 'file_path': filePath,
      if (remoteUrl != null) 'remote_url': remoteUrl,
      if (versionType != null) 'version_type': versionType,
      if (format != null) 'format': format,
      if (pageCount != null) 'page_count': pageCount,
      if (checksum != null) 'checksum': checksum,
      if (isPrimary != null) 'is_primary': isPrimary,
      if (isStudentVisible != null) 'is_student_visible': isStudentVisible,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ScoreVersionsCompanion copyWith(
      {Value<String>? id,
      Value<String>? pieceId,
      Value<String>? title,
      Value<String>? filePath,
      Value<String?>? remoteUrl,
      Value<String?>? versionType,
      Value<String>? format,
      Value<int?>? pageCount,
      Value<String?>? checksum,
      Value<bool>? isPrimary,
      Value<bool>? isStudentVisible,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return ScoreVersionsCompanion(
      id: id ?? this.id,
      pieceId: pieceId ?? this.pieceId,
      title: title ?? this.title,
      filePath: filePath ?? this.filePath,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      versionType: versionType ?? this.versionType,
      format: format ?? this.format,
      pageCount: pageCount ?? this.pageCount,
      checksum: checksum ?? this.checksum,
      isPrimary: isPrimary ?? this.isPrimary,
      isStudentVisible: isStudentVisible ?? this.isStudentVisible,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (pieceId.present) {
      map['piece_id'] = Variable<String>(pieceId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (remoteUrl.present) {
      map['remote_url'] = Variable<String>(remoteUrl.value);
    }
    if (versionType.present) {
      map['version_type'] = Variable<String>(versionType.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    if (pageCount.present) {
      map['page_count'] = Variable<int>(pageCount.value);
    }
    if (checksum.present) {
      map['checksum'] = Variable<String>(checksum.value);
    }
    if (isPrimary.present) {
      map['is_primary'] = Variable<bool>(isPrimary.value);
    }
    if (isStudentVisible.present) {
      map['is_student_visible'] = Variable<bool>(isStudentVisible.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScoreVersionsCompanion(')
          ..write('id: $id, ')
          ..write('pieceId: $pieceId, ')
          ..write('title: $title, ')
          ..write('filePath: $filePath, ')
          ..write('remoteUrl: $remoteUrl, ')
          ..write('versionType: $versionType, ')
          ..write('format: $format, ')
          ..write('pageCount: $pageCount, ')
          ..write('checksum: $checksum, ')
          ..write('isPrimary: $isPrimary, ')
          ..write('isStudentVisible: $isStudentVisible, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AnnotationLayersTable extends AnnotationLayers
    with TableInfo<$AnnotationLayersTable, AnnotationLayerRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AnnotationLayersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _profileIdMeta =
      const VerificationMeta('profileId');
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
      'profile_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _scoreVersionIdMeta =
      const VerificationMeta('scoreVersionId');
  @override
  late final GeneratedColumn<String> scoreVersionId = GeneratedColumn<String>(
      'score_version_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _pageNumberMeta =
      const VerificationMeta('pageNumber');
  @override
  late final GeneratedColumn<int> pageNumber = GeneratedColumn<int>(
      'page_number', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _strokesMeta =
      const VerificationMeta('strokes');
  @override
  late final GeneratedColumn<String> strokes = GeneratedColumn<String>(
      'strokes', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        profileId,
        scoreVersionId,
        pageNumber,
        strokes,
        notes,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'annotation_layers';
  @override
  VerificationContext validateIntegrity(Insertable<AnnotationLayerRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(_profileIdMeta,
          profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta));
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('score_version_id')) {
      context.handle(
          _scoreVersionIdMeta,
          scoreVersionId.isAcceptableOrUnknown(
              data['score_version_id']!, _scoreVersionIdMeta));
    } else if (isInserting) {
      context.missing(_scoreVersionIdMeta);
    }
    if (data.containsKey('page_number')) {
      context.handle(
          _pageNumberMeta,
          pageNumber.isAcceptableOrUnknown(
              data['page_number']!, _pageNumberMeta));
    } else if (isInserting) {
      context.missing(_pageNumberMeta);
    }
    if (data.containsKey('strokes')) {
      context.handle(_strokesMeta,
          strokes.isAcceptableOrUnknown(data['strokes']!, _strokesMeta));
    } else if (isInserting) {
      context.missing(_strokesMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    } else if (isInserting) {
      context.missing(_notesMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AnnotationLayerRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AnnotationLayerRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      profileId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}profile_id'])!,
      scoreVersionId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}score_version_id'])!,
      pageNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}page_number'])!,
      strokes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}strokes'])!,
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $AnnotationLayersTable createAlias(String alias) {
    return $AnnotationLayersTable(attachedDatabase, alias);
  }
}

class AnnotationLayerRow extends DataClass
    implements Insertable<AnnotationLayerRow> {
  final String id;
  final String profileId;
  final String scoreVersionId;
  final int pageNumber;
  final String strokes;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  const AnnotationLayerRow(
      {required this.id,
      required this.profileId,
      required this.scoreVersionId,
      required this.pageNumber,
      required this.strokes,
      required this.notes,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['profile_id'] = Variable<String>(profileId);
    map['score_version_id'] = Variable<String>(scoreVersionId);
    map['page_number'] = Variable<int>(pageNumber);
    map['strokes'] = Variable<String>(strokes);
    map['notes'] = Variable<String>(notes);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AnnotationLayersCompanion toCompanion(bool nullToAbsent) {
    return AnnotationLayersCompanion(
      id: Value(id),
      profileId: Value(profileId),
      scoreVersionId: Value(scoreVersionId),
      pageNumber: Value(pageNumber),
      strokes: Value(strokes),
      notes: Value(notes),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory AnnotationLayerRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AnnotationLayerRow(
      id: serializer.fromJson<String>(json['id']),
      profileId: serializer.fromJson<String>(json['profileId']),
      scoreVersionId: serializer.fromJson<String>(json['scoreVersionId']),
      pageNumber: serializer.fromJson<int>(json['pageNumber']),
      strokes: serializer.fromJson<String>(json['strokes']),
      notes: serializer.fromJson<String>(json['notes']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'profileId': serializer.toJson<String>(profileId),
      'scoreVersionId': serializer.toJson<String>(scoreVersionId),
      'pageNumber': serializer.toJson<int>(pageNumber),
      'strokes': serializer.toJson<String>(strokes),
      'notes': serializer.toJson<String>(notes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AnnotationLayerRow copyWith(
          {String? id,
          String? profileId,
          String? scoreVersionId,
          int? pageNumber,
          String? strokes,
          String? notes,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      AnnotationLayerRow(
        id: id ?? this.id,
        profileId: profileId ?? this.profileId,
        scoreVersionId: scoreVersionId ?? this.scoreVersionId,
        pageNumber: pageNumber ?? this.pageNumber,
        strokes: strokes ?? this.strokes,
        notes: notes ?? this.notes,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  AnnotationLayerRow copyWithCompanion(AnnotationLayersCompanion data) {
    return AnnotationLayerRow(
      id: data.id.present ? data.id.value : this.id,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      scoreVersionId: data.scoreVersionId.present
          ? data.scoreVersionId.value
          : this.scoreVersionId,
      pageNumber:
          data.pageNumber.present ? data.pageNumber.value : this.pageNumber,
      strokes: data.strokes.present ? data.strokes.value : this.strokes,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AnnotationLayerRow(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('scoreVersionId: $scoreVersionId, ')
          ..write('pageNumber: $pageNumber, ')
          ..write('strokes: $strokes, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, profileId, scoreVersionId, pageNumber,
      strokes, notes, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AnnotationLayerRow &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.scoreVersionId == this.scoreVersionId &&
          other.pageNumber == this.pageNumber &&
          other.strokes == this.strokes &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class AnnotationLayersCompanion extends UpdateCompanion<AnnotationLayerRow> {
  final Value<String> id;
  final Value<String> profileId;
  final Value<String> scoreVersionId;
  final Value<int> pageNumber;
  final Value<String> strokes;
  final Value<String> notes;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const AnnotationLayersCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.scoreVersionId = const Value.absent(),
    this.pageNumber = const Value.absent(),
    this.strokes = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AnnotationLayersCompanion.insert({
    required String id,
    required String profileId,
    required String scoreVersionId,
    required int pageNumber,
    required String strokes,
    required String notes,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        profileId = Value(profileId),
        scoreVersionId = Value(scoreVersionId),
        pageNumber = Value(pageNumber),
        strokes = Value(strokes),
        notes = Value(notes),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<AnnotationLayerRow> custom({
    Expression<String>? id,
    Expression<String>? profileId,
    Expression<String>? scoreVersionId,
    Expression<int>? pageNumber,
    Expression<String>? strokes,
    Expression<String>? notes,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (scoreVersionId != null) 'score_version_id': scoreVersionId,
      if (pageNumber != null) 'page_number': pageNumber,
      if (strokes != null) 'strokes': strokes,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AnnotationLayersCompanion copyWith(
      {Value<String>? id,
      Value<String>? profileId,
      Value<String>? scoreVersionId,
      Value<int>? pageNumber,
      Value<String>? strokes,
      Value<String>? notes,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return AnnotationLayersCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      scoreVersionId: scoreVersionId ?? this.scoreVersionId,
      pageNumber: pageNumber ?? this.pageNumber,
      strokes: strokes ?? this.strokes,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (scoreVersionId.present) {
      map['score_version_id'] = Variable<String>(scoreVersionId.value);
    }
    if (pageNumber.present) {
      map['page_number'] = Variable<int>(pageNumber.value);
    }
    if (strokes.present) {
      map['strokes'] = Variable<String>(strokes.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AnnotationLayersCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('scoreVersionId: $scoreVersionId, ')
          ..write('pageNumber: $pageNumber, ')
          ..write('strokes: $strokes, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AnnotationStrokesTable extends AnnotationStrokes
    with TableInfo<$AnnotationStrokesTable, AnnotationStrokeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AnnotationStrokesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _layerIdMeta =
      const VerificationMeta('layerId');
  @override
  late final GeneratedColumn<String> layerId = GeneratedColumn<String>(
      'layer_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES annotation_layers (id)'));
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
      'color', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _strokeWidthMeta =
      const VerificationMeta('strokeWidth');
  @override
  late final GeneratedColumn<double> strokeWidth = GeneratedColumn<double>(
      'stroke_width', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _pointsMeta = const VerificationMeta('points');
  @override
  late final GeneratedColumn<String> points = GeneratedColumn<String>(
      'points', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _toolMeta = const VerificationMeta('tool');
  @override
  late final GeneratedColumn<String> tool = GeneratedColumn<String>(
      'tool', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, layerId, color, strokeWidth, points, tool];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'annotation_strokes';
  @override
  VerificationContext validateIntegrity(
      Insertable<AnnotationStrokeRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('layer_id')) {
      context.handle(_layerIdMeta,
          layerId.isAcceptableOrUnknown(data['layer_id']!, _layerIdMeta));
    } else if (isInserting) {
      context.missing(_layerIdMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
          _colorMeta, color.isAcceptableOrUnknown(data['color']!, _colorMeta));
    } else if (isInserting) {
      context.missing(_colorMeta);
    }
    if (data.containsKey('stroke_width')) {
      context.handle(
          _strokeWidthMeta,
          strokeWidth.isAcceptableOrUnknown(
              data['stroke_width']!, _strokeWidthMeta));
    } else if (isInserting) {
      context.missing(_strokeWidthMeta);
    }
    if (data.containsKey('points')) {
      context.handle(_pointsMeta,
          points.isAcceptableOrUnknown(data['points']!, _pointsMeta));
    } else if (isInserting) {
      context.missing(_pointsMeta);
    }
    if (data.containsKey('tool')) {
      context.handle(
          _toolMeta, tool.isAcceptableOrUnknown(data['tool']!, _toolMeta));
    } else if (isInserting) {
      context.missing(_toolMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AnnotationStrokeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AnnotationStrokeRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      layerId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}layer_id'])!,
      color: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}color'])!,
      strokeWidth: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}stroke_width'])!,
      points: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}points'])!,
      tool: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tool'])!,
    );
  }

  @override
  $AnnotationStrokesTable createAlias(String alias) {
    return $AnnotationStrokesTable(attachedDatabase, alias);
  }
}

class AnnotationStrokeRow extends DataClass
    implements Insertable<AnnotationStrokeRow> {
  final String id;
  final String layerId;
  final String color;
  final double strokeWidth;
  final String points;
  final String tool;
  const AnnotationStrokeRow(
      {required this.id,
      required this.layerId,
      required this.color,
      required this.strokeWidth,
      required this.points,
      required this.tool});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['layer_id'] = Variable<String>(layerId);
    map['color'] = Variable<String>(color);
    map['stroke_width'] = Variable<double>(strokeWidth);
    map['points'] = Variable<String>(points);
    map['tool'] = Variable<String>(tool);
    return map;
  }

  AnnotationStrokesCompanion toCompanion(bool nullToAbsent) {
    return AnnotationStrokesCompanion(
      id: Value(id),
      layerId: Value(layerId),
      color: Value(color),
      strokeWidth: Value(strokeWidth),
      points: Value(points),
      tool: Value(tool),
    );
  }

  factory AnnotationStrokeRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AnnotationStrokeRow(
      id: serializer.fromJson<String>(json['id']),
      layerId: serializer.fromJson<String>(json['layerId']),
      color: serializer.fromJson<String>(json['color']),
      strokeWidth: serializer.fromJson<double>(json['strokeWidth']),
      points: serializer.fromJson<String>(json['points']),
      tool: serializer.fromJson<String>(json['tool']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'layerId': serializer.toJson<String>(layerId),
      'color': serializer.toJson<String>(color),
      'strokeWidth': serializer.toJson<double>(strokeWidth),
      'points': serializer.toJson<String>(points),
      'tool': serializer.toJson<String>(tool),
    };
  }

  AnnotationStrokeRow copyWith(
          {String? id,
          String? layerId,
          String? color,
          double? strokeWidth,
          String? points,
          String? tool}) =>
      AnnotationStrokeRow(
        id: id ?? this.id,
        layerId: layerId ?? this.layerId,
        color: color ?? this.color,
        strokeWidth: strokeWidth ?? this.strokeWidth,
        points: points ?? this.points,
        tool: tool ?? this.tool,
      );
  AnnotationStrokeRow copyWithCompanion(AnnotationStrokesCompanion data) {
    return AnnotationStrokeRow(
      id: data.id.present ? data.id.value : this.id,
      layerId: data.layerId.present ? data.layerId.value : this.layerId,
      color: data.color.present ? data.color.value : this.color,
      strokeWidth:
          data.strokeWidth.present ? data.strokeWidth.value : this.strokeWidth,
      points: data.points.present ? data.points.value : this.points,
      tool: data.tool.present ? data.tool.value : this.tool,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AnnotationStrokeRow(')
          ..write('id: $id, ')
          ..write('layerId: $layerId, ')
          ..write('color: $color, ')
          ..write('strokeWidth: $strokeWidth, ')
          ..write('points: $points, ')
          ..write('tool: $tool')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, layerId, color, strokeWidth, points, tool);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AnnotationStrokeRow &&
          other.id == this.id &&
          other.layerId == this.layerId &&
          other.color == this.color &&
          other.strokeWidth == this.strokeWidth &&
          other.points == this.points &&
          other.tool == this.tool);
}

class AnnotationStrokesCompanion extends UpdateCompanion<AnnotationStrokeRow> {
  final Value<String> id;
  final Value<String> layerId;
  final Value<String> color;
  final Value<double> strokeWidth;
  final Value<String> points;
  final Value<String> tool;
  final Value<int> rowid;
  const AnnotationStrokesCompanion({
    this.id = const Value.absent(),
    this.layerId = const Value.absent(),
    this.color = const Value.absent(),
    this.strokeWidth = const Value.absent(),
    this.points = const Value.absent(),
    this.tool = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AnnotationStrokesCompanion.insert({
    required String id,
    required String layerId,
    required String color,
    required double strokeWidth,
    required String points,
    required String tool,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        layerId = Value(layerId),
        color = Value(color),
        strokeWidth = Value(strokeWidth),
        points = Value(points),
        tool = Value(tool);
  static Insertable<AnnotationStrokeRow> custom({
    Expression<String>? id,
    Expression<String>? layerId,
    Expression<String>? color,
    Expression<double>? strokeWidth,
    Expression<String>? points,
    Expression<String>? tool,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (layerId != null) 'layer_id': layerId,
      if (color != null) 'color': color,
      if (strokeWidth != null) 'stroke_width': strokeWidth,
      if (points != null) 'points': points,
      if (tool != null) 'tool': tool,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AnnotationStrokesCompanion copyWith(
      {Value<String>? id,
      Value<String>? layerId,
      Value<String>? color,
      Value<double>? strokeWidth,
      Value<String>? points,
      Value<String>? tool,
      Value<int>? rowid}) {
    return AnnotationStrokesCompanion(
      id: id ?? this.id,
      layerId: layerId ?? this.layerId,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      points: points ?? this.points,
      tool: tool ?? this.tool,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (layerId.present) {
      map['layer_id'] = Variable<String>(layerId.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (strokeWidth.present) {
      map['stroke_width'] = Variable<double>(strokeWidth.value);
    }
    if (points.present) {
      map['points'] = Variable<String>(points.value);
    }
    if (tool.present) {
      map['tool'] = Variable<String>(tool.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AnnotationStrokesCompanion(')
          ..write('id: $id, ')
          ..write('layerId: $layerId, ')
          ..write('color: $color, ')
          ..write('strokeWidth: $strokeWidth, ')
          ..write('points: $points, ')
          ..write('tool: $tool, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AnnotationNotesTable extends AnnotationNotes
    with TableInfo<$AnnotationNotesTable, AnnotationNoteRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AnnotationNotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _layerIdMeta =
      const VerificationMeta('layerId');
  @override
  late final GeneratedColumn<String> layerId = GeneratedColumn<String>(
      'layer_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES annotation_layers (id)'));
  static const VerificationMeta _xMeta = const VerificationMeta('x');
  @override
  late final GeneratedColumn<double> x = GeneratedColumn<double>(
      'x', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _yMeta = const VerificationMeta('y');
  @override
  late final GeneratedColumn<double> y = GeneratedColumn<double>(
      'y', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _noteTextMeta =
      const VerificationMeta('noteText');
  @override
  late final GeneratedColumn<String> noteText = GeneratedColumn<String>(
      'note_text', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, layerId, x, y, noteText, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'annotation_notes';
  @override
  VerificationContext validateIntegrity(Insertable<AnnotationNoteRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('layer_id')) {
      context.handle(_layerIdMeta,
          layerId.isAcceptableOrUnknown(data['layer_id']!, _layerIdMeta));
    } else if (isInserting) {
      context.missing(_layerIdMeta);
    }
    if (data.containsKey('x')) {
      context.handle(_xMeta, x.isAcceptableOrUnknown(data['x']!, _xMeta));
    } else if (isInserting) {
      context.missing(_xMeta);
    }
    if (data.containsKey('y')) {
      context.handle(_yMeta, y.isAcceptableOrUnknown(data['y']!, _yMeta));
    } else if (isInserting) {
      context.missing(_yMeta);
    }
    if (data.containsKey('note_text')) {
      context.handle(_noteTextMeta,
          noteText.isAcceptableOrUnknown(data['note_text']!, _noteTextMeta));
    } else if (isInserting) {
      context.missing(_noteTextMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AnnotationNoteRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AnnotationNoteRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      layerId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}layer_id'])!,
      x: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}x'])!,
      y: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}y'])!,
      noteText: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note_text'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $AnnotationNotesTable createAlias(String alias) {
    return $AnnotationNotesTable(attachedDatabase, alias);
  }
}

class AnnotationNoteRow extends DataClass
    implements Insertable<AnnotationNoteRow> {
  final String id;
  final String layerId;
  final double x;
  final double y;
  final String noteText;
  final DateTime createdAt;
  const AnnotationNoteRow(
      {required this.id,
      required this.layerId,
      required this.x,
      required this.y,
      required this.noteText,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['layer_id'] = Variable<String>(layerId);
    map['x'] = Variable<double>(x);
    map['y'] = Variable<double>(y);
    map['note_text'] = Variable<String>(noteText);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  AnnotationNotesCompanion toCompanion(bool nullToAbsent) {
    return AnnotationNotesCompanion(
      id: Value(id),
      layerId: Value(layerId),
      x: Value(x),
      y: Value(y),
      noteText: Value(noteText),
      createdAt: Value(createdAt),
    );
  }

  factory AnnotationNoteRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AnnotationNoteRow(
      id: serializer.fromJson<String>(json['id']),
      layerId: serializer.fromJson<String>(json['layerId']),
      x: serializer.fromJson<double>(json['x']),
      y: serializer.fromJson<double>(json['y']),
      noteText: serializer.fromJson<String>(json['noteText']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'layerId': serializer.toJson<String>(layerId),
      'x': serializer.toJson<double>(x),
      'y': serializer.toJson<double>(y),
      'noteText': serializer.toJson<String>(noteText),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  AnnotationNoteRow copyWith(
          {String? id,
          String? layerId,
          double? x,
          double? y,
          String? noteText,
          DateTime? createdAt}) =>
      AnnotationNoteRow(
        id: id ?? this.id,
        layerId: layerId ?? this.layerId,
        x: x ?? this.x,
        y: y ?? this.y,
        noteText: noteText ?? this.noteText,
        createdAt: createdAt ?? this.createdAt,
      );
  AnnotationNoteRow copyWithCompanion(AnnotationNotesCompanion data) {
    return AnnotationNoteRow(
      id: data.id.present ? data.id.value : this.id,
      layerId: data.layerId.present ? data.layerId.value : this.layerId,
      x: data.x.present ? data.x.value : this.x,
      y: data.y.present ? data.y.value : this.y,
      noteText: data.noteText.present ? data.noteText.value : this.noteText,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AnnotationNoteRow(')
          ..write('id: $id, ')
          ..write('layerId: $layerId, ')
          ..write('x: $x, ')
          ..write('y: $y, ')
          ..write('noteText: $noteText, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, layerId, x, y, noteText, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AnnotationNoteRow &&
          other.id == this.id &&
          other.layerId == this.layerId &&
          other.x == this.x &&
          other.y == this.y &&
          other.noteText == this.noteText &&
          other.createdAt == this.createdAt);
}

class AnnotationNotesCompanion extends UpdateCompanion<AnnotationNoteRow> {
  final Value<String> id;
  final Value<String> layerId;
  final Value<double> x;
  final Value<double> y;
  final Value<String> noteText;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const AnnotationNotesCompanion({
    this.id = const Value.absent(),
    this.layerId = const Value.absent(),
    this.x = const Value.absent(),
    this.y = const Value.absent(),
    this.noteText = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AnnotationNotesCompanion.insert({
    required String id,
    required String layerId,
    required double x,
    required double y,
    required String noteText,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        layerId = Value(layerId),
        x = Value(x),
        y = Value(y),
        noteText = Value(noteText),
        createdAt = Value(createdAt);
  static Insertable<AnnotationNoteRow> custom({
    Expression<String>? id,
    Expression<String>? layerId,
    Expression<double>? x,
    Expression<double>? y,
    Expression<String>? noteText,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (layerId != null) 'layer_id': layerId,
      if (x != null) 'x': x,
      if (y != null) 'y': y,
      if (noteText != null) 'note_text': noteText,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AnnotationNotesCompanion copyWith(
      {Value<String>? id,
      Value<String>? layerId,
      Value<double>? x,
      Value<double>? y,
      Value<String>? noteText,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return AnnotationNotesCompanion(
      id: id ?? this.id,
      layerId: layerId ?? this.layerId,
      x: x ?? this.x,
      y: y ?? this.y,
      noteText: noteText ?? this.noteText,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (layerId.present) {
      map['layer_id'] = Variable<String>(layerId.value);
    }
    if (x.present) {
      map['x'] = Variable<double>(x.value);
    }
    if (y.present) {
      map['y'] = Variable<double>(y.value);
    }
    if (noteText.present) {
      map['note_text'] = Variable<String>(noteText.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AnnotationNotesCompanion(')
          ..write('id: $id, ')
          ..write('layerId: $layerId, ')
          ..write('x: $x, ')
          ..write('y: $y, ')
          ..write('noteText: $noteText, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MediaAssetsTable extends MediaAssets
    with TableInfo<$MediaAssetsTable, MediaAsset> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MediaAssetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _pieceIdMeta =
      const VerificationMeta('pieceId');
  @override
  late final GeneratedColumn<String> pieceId = GeneratedColumn<String>(
      'piece_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES pieces (id)'));
  static const VerificationMeta _filePathMeta =
      const VerificationMeta('filePath');
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
      'file_path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _remoteUrlMeta =
      const VerificationMeta('remoteUrl');
  @override
  late final GeneratedColumn<String> remoteUrl = GeneratedColumn<String>(
      'remote_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _formatMeta = const VerificationMeta('format');
  @override
  late final GeneratedColumn<String> format = GeneratedColumn<String>(
      'format', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _durationMsMeta =
      const VerificationMeta('durationMs');
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
      'duration_ms', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _fileSizeBytesMeta =
      const VerificationMeta('fileSizeBytes');
  @override
  late final GeneratedColumn<int> fileSizeBytes = GeneratedColumn<int>(
      'file_size_bytes', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _thumbnailPathMeta =
      const VerificationMeta('thumbnailPath');
  @override
  late final GeneratedColumn<String> thumbnailPath = GeneratedColumn<String>(
      'thumbnail_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        pieceId,
        filePath,
        remoteUrl,
        format,
        durationMs,
        fileSizeBytes,
        thumbnailPath,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'media_assets';
  @override
  VerificationContext validateIntegrity(Insertable<MediaAsset> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('piece_id')) {
      context.handle(_pieceIdMeta,
          pieceId.isAcceptableOrUnknown(data['piece_id']!, _pieceIdMeta));
    } else if (isInserting) {
      context.missing(_pieceIdMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(_filePathMeta,
          filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta));
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('remote_url')) {
      context.handle(_remoteUrlMeta,
          remoteUrl.isAcceptableOrUnknown(data['remote_url']!, _remoteUrlMeta));
    }
    if (data.containsKey('format')) {
      context.handle(_formatMeta,
          format.isAcceptableOrUnknown(data['format']!, _formatMeta));
    } else if (isInserting) {
      context.missing(_formatMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
          _durationMsMeta,
          durationMs.isAcceptableOrUnknown(
              data['duration_ms']!, _durationMsMeta));
    }
    if (data.containsKey('file_size_bytes')) {
      context.handle(
          _fileSizeBytesMeta,
          fileSizeBytes.isAcceptableOrUnknown(
              data['file_size_bytes']!, _fileSizeBytesMeta));
    }
    if (data.containsKey('thumbnail_path')) {
      context.handle(
          _thumbnailPathMeta,
          thumbnailPath.isAcceptableOrUnknown(
              data['thumbnail_path']!, _thumbnailPathMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MediaAsset map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MediaAsset(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      pieceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}piece_id'])!,
      filePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}file_path'])!,
      remoteUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}remote_url']),
      format: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}format'])!,
      durationMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}duration_ms']),
      fileSizeBytes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}file_size_bytes']),
      thumbnailPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}thumbnail_path']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $MediaAssetsTable createAlias(String alias) {
    return $MediaAssetsTable(attachedDatabase, alias);
  }
}

class MediaAsset extends DataClass implements Insertable<MediaAsset> {
  final String id;
  final String pieceId;
  final String filePath;
  final String? remoteUrl;
  final String format;
  final int? durationMs;
  final int? fileSizeBytes;
  final String? thumbnailPath;
  final DateTime createdAt;
  final DateTime updatedAt;
  const MediaAsset(
      {required this.id,
      required this.pieceId,
      required this.filePath,
      this.remoteUrl,
      required this.format,
      this.durationMs,
      this.fileSizeBytes,
      this.thumbnailPath,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['piece_id'] = Variable<String>(pieceId);
    map['file_path'] = Variable<String>(filePath);
    if (!nullToAbsent || remoteUrl != null) {
      map['remote_url'] = Variable<String>(remoteUrl);
    }
    map['format'] = Variable<String>(format);
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    if (!nullToAbsent || fileSizeBytes != null) {
      map['file_size_bytes'] = Variable<int>(fileSizeBytes);
    }
    if (!nullToAbsent || thumbnailPath != null) {
      map['thumbnail_path'] = Variable<String>(thumbnailPath);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  MediaAssetsCompanion toCompanion(bool nullToAbsent) {
    return MediaAssetsCompanion(
      id: Value(id),
      pieceId: Value(pieceId),
      filePath: Value(filePath),
      remoteUrl: remoteUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteUrl),
      format: Value(format),
      durationMs: durationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMs),
      fileSizeBytes: fileSizeBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(fileSizeBytes),
      thumbnailPath: thumbnailPath == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnailPath),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory MediaAsset.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MediaAsset(
      id: serializer.fromJson<String>(json['id']),
      pieceId: serializer.fromJson<String>(json['pieceId']),
      filePath: serializer.fromJson<String>(json['filePath']),
      remoteUrl: serializer.fromJson<String?>(json['remoteUrl']),
      format: serializer.fromJson<String>(json['format']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
      fileSizeBytes: serializer.fromJson<int?>(json['fileSizeBytes']),
      thumbnailPath: serializer.fromJson<String?>(json['thumbnailPath']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'pieceId': serializer.toJson<String>(pieceId),
      'filePath': serializer.toJson<String>(filePath),
      'remoteUrl': serializer.toJson<String?>(remoteUrl),
      'format': serializer.toJson<String>(format),
      'durationMs': serializer.toJson<int?>(durationMs),
      'fileSizeBytes': serializer.toJson<int?>(fileSizeBytes),
      'thumbnailPath': serializer.toJson<String?>(thumbnailPath),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  MediaAsset copyWith(
          {String? id,
          String? pieceId,
          String? filePath,
          Value<String?> remoteUrl = const Value.absent(),
          String? format,
          Value<int?> durationMs = const Value.absent(),
          Value<int?> fileSizeBytes = const Value.absent(),
          Value<String?> thumbnailPath = const Value.absent(),
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      MediaAsset(
        id: id ?? this.id,
        pieceId: pieceId ?? this.pieceId,
        filePath: filePath ?? this.filePath,
        remoteUrl: remoteUrl.present ? remoteUrl.value : this.remoteUrl,
        format: format ?? this.format,
        durationMs: durationMs.present ? durationMs.value : this.durationMs,
        fileSizeBytes:
            fileSizeBytes.present ? fileSizeBytes.value : this.fileSizeBytes,
        thumbnailPath:
            thumbnailPath.present ? thumbnailPath.value : this.thumbnailPath,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  MediaAsset copyWithCompanion(MediaAssetsCompanion data) {
    return MediaAsset(
      id: data.id.present ? data.id.value : this.id,
      pieceId: data.pieceId.present ? data.pieceId.value : this.pieceId,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      remoteUrl: data.remoteUrl.present ? data.remoteUrl.value : this.remoteUrl,
      format: data.format.present ? data.format.value : this.format,
      durationMs:
          data.durationMs.present ? data.durationMs.value : this.durationMs,
      fileSizeBytes: data.fileSizeBytes.present
          ? data.fileSizeBytes.value
          : this.fileSizeBytes,
      thumbnailPath: data.thumbnailPath.present
          ? data.thumbnailPath.value
          : this.thumbnailPath,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MediaAsset(')
          ..write('id: $id, ')
          ..write('pieceId: $pieceId, ')
          ..write('filePath: $filePath, ')
          ..write('remoteUrl: $remoteUrl, ')
          ..write('format: $format, ')
          ..write('durationMs: $durationMs, ')
          ..write('fileSizeBytes: $fileSizeBytes, ')
          ..write('thumbnailPath: $thumbnailPath, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, pieceId, filePath, remoteUrl, format,
      durationMs, fileSizeBytes, thumbnailPath, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MediaAsset &&
          other.id == this.id &&
          other.pieceId == this.pieceId &&
          other.filePath == this.filePath &&
          other.remoteUrl == this.remoteUrl &&
          other.format == this.format &&
          other.durationMs == this.durationMs &&
          other.fileSizeBytes == this.fileSizeBytes &&
          other.thumbnailPath == this.thumbnailPath &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class MediaAssetsCompanion extends UpdateCompanion<MediaAsset> {
  final Value<String> id;
  final Value<String> pieceId;
  final Value<String> filePath;
  final Value<String?> remoteUrl;
  final Value<String> format;
  final Value<int?> durationMs;
  final Value<int?> fileSizeBytes;
  final Value<String?> thumbnailPath;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const MediaAssetsCompanion({
    this.id = const Value.absent(),
    this.pieceId = const Value.absent(),
    this.filePath = const Value.absent(),
    this.remoteUrl = const Value.absent(),
    this.format = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.fileSizeBytes = const Value.absent(),
    this.thumbnailPath = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MediaAssetsCompanion.insert({
    required String id,
    required String pieceId,
    required String filePath,
    this.remoteUrl = const Value.absent(),
    required String format,
    this.durationMs = const Value.absent(),
    this.fileSizeBytes = const Value.absent(),
    this.thumbnailPath = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        pieceId = Value(pieceId),
        filePath = Value(filePath),
        format = Value(format),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<MediaAsset> custom({
    Expression<String>? id,
    Expression<String>? pieceId,
    Expression<String>? filePath,
    Expression<String>? remoteUrl,
    Expression<String>? format,
    Expression<int>? durationMs,
    Expression<int>? fileSizeBytes,
    Expression<String>? thumbnailPath,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (pieceId != null) 'piece_id': pieceId,
      if (filePath != null) 'file_path': filePath,
      if (remoteUrl != null) 'remote_url': remoteUrl,
      if (format != null) 'format': format,
      if (durationMs != null) 'duration_ms': durationMs,
      if (fileSizeBytes != null) 'file_size_bytes': fileSizeBytes,
      if (thumbnailPath != null) 'thumbnail_path': thumbnailPath,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MediaAssetsCompanion copyWith(
      {Value<String>? id,
      Value<String>? pieceId,
      Value<String>? filePath,
      Value<String?>? remoteUrl,
      Value<String>? format,
      Value<int?>? durationMs,
      Value<int?>? fileSizeBytes,
      Value<String?>? thumbnailPath,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return MediaAssetsCompanion(
      id: id ?? this.id,
      pieceId: pieceId ?? this.pieceId,
      filePath: filePath ?? this.filePath,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      format: format ?? this.format,
      durationMs: durationMs ?? this.durationMs,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (pieceId.present) {
      map['piece_id'] = Variable<String>(pieceId.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (remoteUrl.present) {
      map['remote_url'] = Variable<String>(remoteUrl.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (fileSizeBytes.present) {
      map['file_size_bytes'] = Variable<int>(fileSizeBytes.value);
    }
    if (thumbnailPath.present) {
      map['thumbnail_path'] = Variable<String>(thumbnailPath.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MediaAssetsCompanion(')
          ..write('id: $id, ')
          ..write('pieceId: $pieceId, ')
          ..write('filePath: $filePath, ')
          ..write('remoteUrl: $remoteUrl, ')
          ..write('format: $format, ')
          ..write('durationMs: $durationMs, ')
          ..write('fileSizeBytes: $fileSizeBytes, ')
          ..write('thumbnailPath: $thumbnailPath, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MediaMatchCandidatesTable extends MediaMatchCandidates
    with TableInfo<$MediaMatchCandidatesTable, MediaMatchCandidate> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MediaMatchCandidatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _mediaAssetIdMeta =
      const VerificationMeta('mediaAssetId');
  @override
  late final GeneratedColumn<String> mediaAssetId = GeneratedColumn<String>(
      'media_asset_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES media_assets (id)'));
  static const VerificationMeta _pieceIdMeta =
      const VerificationMeta('pieceId');
  @override
  late final GeneratedColumn<String> pieceId = GeneratedColumn<String>(
      'piece_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES pieces (id)'));
  static const VerificationMeta _scoreVersionIdMeta =
      const VerificationMeta('scoreVersionId');
  @override
  late final GeneratedColumn<String> scoreVersionId = GeneratedColumn<String>(
      'score_version_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES score_versions (id)'));
  static const VerificationMeta _similarityScoreMeta =
      const VerificationMeta('similarityScore');
  @override
  late final GeneratedColumn<double> similarityScore = GeneratedColumn<double>(
      'similarity_score', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _aiNotesMeta =
      const VerificationMeta('aiNotes');
  @override
  late final GeneratedColumn<String> aiNotes = GeneratedColumn<String>(
      'ai_notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        mediaAssetId,
        pieceId,
        scoreVersionId,
        similarityScore,
        status,
        aiNotes,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'media_match_candidates';
  @override
  VerificationContext validateIntegrity(
      Insertable<MediaMatchCandidate> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('media_asset_id')) {
      context.handle(
          _mediaAssetIdMeta,
          mediaAssetId.isAcceptableOrUnknown(
              data['media_asset_id']!, _mediaAssetIdMeta));
    } else if (isInserting) {
      context.missing(_mediaAssetIdMeta);
    }
    if (data.containsKey('piece_id')) {
      context.handle(_pieceIdMeta,
          pieceId.isAcceptableOrUnknown(data['piece_id']!, _pieceIdMeta));
    } else if (isInserting) {
      context.missing(_pieceIdMeta);
    }
    if (data.containsKey('score_version_id')) {
      context.handle(
          _scoreVersionIdMeta,
          scoreVersionId.isAcceptableOrUnknown(
              data['score_version_id']!, _scoreVersionIdMeta));
    } else if (isInserting) {
      context.missing(_scoreVersionIdMeta);
    }
    if (data.containsKey('similarity_score')) {
      context.handle(
          _similarityScoreMeta,
          similarityScore.isAcceptableOrUnknown(
              data['similarity_score']!, _similarityScoreMeta));
    } else if (isInserting) {
      context.missing(_similarityScoreMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('ai_notes')) {
      context.handle(_aiNotesMeta,
          aiNotes.isAcceptableOrUnknown(data['ai_notes']!, _aiNotesMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MediaMatchCandidate map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MediaMatchCandidate(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      mediaAssetId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}media_asset_id'])!,
      pieceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}piece_id'])!,
      scoreVersionId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}score_version_id'])!,
      similarityScore: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}similarity_score'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      aiNotes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}ai_notes']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $MediaMatchCandidatesTable createAlias(String alias) {
    return $MediaMatchCandidatesTable(attachedDatabase, alias);
  }
}

class MediaMatchCandidate extends DataClass
    implements Insertable<MediaMatchCandidate> {
  final String id;
  final String mediaAssetId;
  final String pieceId;
  final String scoreVersionId;
  final double similarityScore;
  final String status;
  final String? aiNotes;
  final DateTime createdAt;
  const MediaMatchCandidate(
      {required this.id,
      required this.mediaAssetId,
      required this.pieceId,
      required this.scoreVersionId,
      required this.similarityScore,
      required this.status,
      this.aiNotes,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['media_asset_id'] = Variable<String>(mediaAssetId);
    map['piece_id'] = Variable<String>(pieceId);
    map['score_version_id'] = Variable<String>(scoreVersionId);
    map['similarity_score'] = Variable<double>(similarityScore);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || aiNotes != null) {
      map['ai_notes'] = Variable<String>(aiNotes);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  MediaMatchCandidatesCompanion toCompanion(bool nullToAbsent) {
    return MediaMatchCandidatesCompanion(
      id: Value(id),
      mediaAssetId: Value(mediaAssetId),
      pieceId: Value(pieceId),
      scoreVersionId: Value(scoreVersionId),
      similarityScore: Value(similarityScore),
      status: Value(status),
      aiNotes: aiNotes == null && nullToAbsent
          ? const Value.absent()
          : Value(aiNotes),
      createdAt: Value(createdAt),
    );
  }

  factory MediaMatchCandidate.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MediaMatchCandidate(
      id: serializer.fromJson<String>(json['id']),
      mediaAssetId: serializer.fromJson<String>(json['mediaAssetId']),
      pieceId: serializer.fromJson<String>(json['pieceId']),
      scoreVersionId: serializer.fromJson<String>(json['scoreVersionId']),
      similarityScore: serializer.fromJson<double>(json['similarityScore']),
      status: serializer.fromJson<String>(json['status']),
      aiNotes: serializer.fromJson<String?>(json['aiNotes']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'mediaAssetId': serializer.toJson<String>(mediaAssetId),
      'pieceId': serializer.toJson<String>(pieceId),
      'scoreVersionId': serializer.toJson<String>(scoreVersionId),
      'similarityScore': serializer.toJson<double>(similarityScore),
      'status': serializer.toJson<String>(status),
      'aiNotes': serializer.toJson<String?>(aiNotes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  MediaMatchCandidate copyWith(
          {String? id,
          String? mediaAssetId,
          String? pieceId,
          String? scoreVersionId,
          double? similarityScore,
          String? status,
          Value<String?> aiNotes = const Value.absent(),
          DateTime? createdAt}) =>
      MediaMatchCandidate(
        id: id ?? this.id,
        mediaAssetId: mediaAssetId ?? this.mediaAssetId,
        pieceId: pieceId ?? this.pieceId,
        scoreVersionId: scoreVersionId ?? this.scoreVersionId,
        similarityScore: similarityScore ?? this.similarityScore,
        status: status ?? this.status,
        aiNotes: aiNotes.present ? aiNotes.value : this.aiNotes,
        createdAt: createdAt ?? this.createdAt,
      );
  MediaMatchCandidate copyWithCompanion(MediaMatchCandidatesCompanion data) {
    return MediaMatchCandidate(
      id: data.id.present ? data.id.value : this.id,
      mediaAssetId: data.mediaAssetId.present
          ? data.mediaAssetId.value
          : this.mediaAssetId,
      pieceId: data.pieceId.present ? data.pieceId.value : this.pieceId,
      scoreVersionId: data.scoreVersionId.present
          ? data.scoreVersionId.value
          : this.scoreVersionId,
      similarityScore: data.similarityScore.present
          ? data.similarityScore.value
          : this.similarityScore,
      status: data.status.present ? data.status.value : this.status,
      aiNotes: data.aiNotes.present ? data.aiNotes.value : this.aiNotes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MediaMatchCandidate(')
          ..write('id: $id, ')
          ..write('mediaAssetId: $mediaAssetId, ')
          ..write('pieceId: $pieceId, ')
          ..write('scoreVersionId: $scoreVersionId, ')
          ..write('similarityScore: $similarityScore, ')
          ..write('status: $status, ')
          ..write('aiNotes: $aiNotes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, mediaAssetId, pieceId, scoreVersionId,
      similarityScore, status, aiNotes, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MediaMatchCandidate &&
          other.id == this.id &&
          other.mediaAssetId == this.mediaAssetId &&
          other.pieceId == this.pieceId &&
          other.scoreVersionId == this.scoreVersionId &&
          other.similarityScore == this.similarityScore &&
          other.status == this.status &&
          other.aiNotes == this.aiNotes &&
          other.createdAt == this.createdAt);
}

class MediaMatchCandidatesCompanion
    extends UpdateCompanion<MediaMatchCandidate> {
  final Value<String> id;
  final Value<String> mediaAssetId;
  final Value<String> pieceId;
  final Value<String> scoreVersionId;
  final Value<double> similarityScore;
  final Value<String> status;
  final Value<String?> aiNotes;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const MediaMatchCandidatesCompanion({
    this.id = const Value.absent(),
    this.mediaAssetId = const Value.absent(),
    this.pieceId = const Value.absent(),
    this.scoreVersionId = const Value.absent(),
    this.similarityScore = const Value.absent(),
    this.status = const Value.absent(),
    this.aiNotes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MediaMatchCandidatesCompanion.insert({
    required String id,
    required String mediaAssetId,
    required String pieceId,
    required String scoreVersionId,
    required double similarityScore,
    required String status,
    this.aiNotes = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        mediaAssetId = Value(mediaAssetId),
        pieceId = Value(pieceId),
        scoreVersionId = Value(scoreVersionId),
        similarityScore = Value(similarityScore),
        status = Value(status),
        createdAt = Value(createdAt);
  static Insertable<MediaMatchCandidate> custom({
    Expression<String>? id,
    Expression<String>? mediaAssetId,
    Expression<String>? pieceId,
    Expression<String>? scoreVersionId,
    Expression<double>? similarityScore,
    Expression<String>? status,
    Expression<String>? aiNotes,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (mediaAssetId != null) 'media_asset_id': mediaAssetId,
      if (pieceId != null) 'piece_id': pieceId,
      if (scoreVersionId != null) 'score_version_id': scoreVersionId,
      if (similarityScore != null) 'similarity_score': similarityScore,
      if (status != null) 'status': status,
      if (aiNotes != null) 'ai_notes': aiNotes,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MediaMatchCandidatesCompanion copyWith(
      {Value<String>? id,
      Value<String>? mediaAssetId,
      Value<String>? pieceId,
      Value<String>? scoreVersionId,
      Value<double>? similarityScore,
      Value<String>? status,
      Value<String?>? aiNotes,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return MediaMatchCandidatesCompanion(
      id: id ?? this.id,
      mediaAssetId: mediaAssetId ?? this.mediaAssetId,
      pieceId: pieceId ?? this.pieceId,
      scoreVersionId: scoreVersionId ?? this.scoreVersionId,
      similarityScore: similarityScore ?? this.similarityScore,
      status: status ?? this.status,
      aiNotes: aiNotes ?? this.aiNotes,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (mediaAssetId.present) {
      map['media_asset_id'] = Variable<String>(mediaAssetId.value);
    }
    if (pieceId.present) {
      map['piece_id'] = Variable<String>(pieceId.value);
    }
    if (scoreVersionId.present) {
      map['score_version_id'] = Variable<String>(scoreVersionId.value);
    }
    if (similarityScore.present) {
      map['similarity_score'] = Variable<double>(similarityScore.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (aiNotes.present) {
      map['ai_notes'] = Variable<String>(aiNotes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MediaMatchCandidatesCompanion(')
          ..write('id: $id, ')
          ..write('mediaAssetId: $mediaAssetId, ')
          ..write('pieceId: $pieceId, ')
          ..write('scoreVersionId: $scoreVersionId, ')
          ..write('similarityScore: $similarityScore, ')
          ..write('status: $status, ')
          ..write('aiNotes: $aiNotes, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProcessingJobsTable extends ProcessingJobs
    with TableInfo<$ProcessingJobsTable, ProcessingJob> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProcessingJobsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _mediaAssetIdMeta =
      const VerificationMeta('mediaAssetId');
  @override
  late final GeneratedColumn<String> mediaAssetId = GeneratedColumn<String>(
      'media_asset_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _pieceIdMeta =
      const VerificationMeta('pieceId');
  @override
  late final GeneratedColumn<String> pieceId = GeneratedColumn<String>(
      'piece_id', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES pieces (id)'));
  static const VerificationMeta _scoreVersionIdMeta =
      const VerificationMeta('scoreVersionId');
  @override
  late final GeneratedColumn<String> scoreVersionId = GeneratedColumn<String>(
      'score_version_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _progressMeta =
      const VerificationMeta('progress');
  @override
  late final GeneratedColumn<double> progress = GeneratedColumn<double>(
      'progress', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _errorMessageMeta =
      const VerificationMeta('errorMessage');
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
      'error_message', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _resultMeta = const VerificationMeta('result');
  @override
  late final GeneratedColumn<String> result = GeneratedColumn<String>(
      'result', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _completedAtMeta =
      const VerificationMeta('completedAt');
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
      'completed_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        type,
        mediaAssetId,
        pieceId,
        scoreVersionId,
        status,
        progress,
        errorMessage,
        result,
        createdAt,
        completedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'processing_jobs';
  @override
  VerificationContext validateIntegrity(Insertable<ProcessingJob> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('media_asset_id')) {
      context.handle(
          _mediaAssetIdMeta,
          mediaAssetId.isAcceptableOrUnknown(
              data['media_asset_id']!, _mediaAssetIdMeta));
    }
    if (data.containsKey('piece_id')) {
      context.handle(_pieceIdMeta,
          pieceId.isAcceptableOrUnknown(data['piece_id']!, _pieceIdMeta));
    }
    if (data.containsKey('score_version_id')) {
      context.handle(
          _scoreVersionIdMeta,
          scoreVersionId.isAcceptableOrUnknown(
              data['score_version_id']!, _scoreVersionIdMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('progress')) {
      context.handle(_progressMeta,
          progress.isAcceptableOrUnknown(data['progress']!, _progressMeta));
    }
    if (data.containsKey('error_message')) {
      context.handle(
          _errorMessageMeta,
          errorMessage.isAcceptableOrUnknown(
              data['error_message']!, _errorMessageMeta));
    }
    if (data.containsKey('result')) {
      context.handle(_resultMeta,
          result.isAcceptableOrUnknown(data['result']!, _resultMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
          _completedAtMeta,
          completedAt.isAcceptableOrUnknown(
              data['completed_at']!, _completedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProcessingJob map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProcessingJob(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      mediaAssetId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}media_asset_id']),
      pieceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}piece_id']),
      scoreVersionId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}score_version_id']),
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      progress: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}progress']),
      errorMessage: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}error_message']),
      result: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}result']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      completedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}completed_at']),
    );
  }

  @override
  $ProcessingJobsTable createAlias(String alias) {
    return $ProcessingJobsTable(attachedDatabase, alias);
  }
}

class ProcessingJob extends DataClass implements Insertable<ProcessingJob> {
  final String id;
  final String type;
  final String? mediaAssetId;
  final String? pieceId;
  final String? scoreVersionId;
  final String status;
  final double? progress;
  final String? errorMessage;
  final String? result;
  final DateTime createdAt;
  final DateTime? completedAt;
  const ProcessingJob(
      {required this.id,
      required this.type,
      this.mediaAssetId,
      this.pieceId,
      this.scoreVersionId,
      required this.status,
      this.progress,
      this.errorMessage,
      this.result,
      required this.createdAt,
      this.completedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || mediaAssetId != null) {
      map['media_asset_id'] = Variable<String>(mediaAssetId);
    }
    if (!nullToAbsent || pieceId != null) {
      map['piece_id'] = Variable<String>(pieceId);
    }
    if (!nullToAbsent || scoreVersionId != null) {
      map['score_version_id'] = Variable<String>(scoreVersionId);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || progress != null) {
      map['progress'] = Variable<double>(progress);
    }
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    if (!nullToAbsent || result != null) {
      map['result'] = Variable<String>(result);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    return map;
  }

  ProcessingJobsCompanion toCompanion(bool nullToAbsent) {
    return ProcessingJobsCompanion(
      id: Value(id),
      type: Value(type),
      mediaAssetId: mediaAssetId == null && nullToAbsent
          ? const Value.absent()
          : Value(mediaAssetId),
      pieceId: pieceId == null && nullToAbsent
          ? const Value.absent()
          : Value(pieceId),
      scoreVersionId: scoreVersionId == null && nullToAbsent
          ? const Value.absent()
          : Value(scoreVersionId),
      status: Value(status),
      progress: progress == null && nullToAbsent
          ? const Value.absent()
          : Value(progress),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
      result:
          result == null && nullToAbsent ? const Value.absent() : Value(result),
      createdAt: Value(createdAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
    );
  }

  factory ProcessingJob.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProcessingJob(
      id: serializer.fromJson<String>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      mediaAssetId: serializer.fromJson<String?>(json['mediaAssetId']),
      pieceId: serializer.fromJson<String?>(json['pieceId']),
      scoreVersionId: serializer.fromJson<String?>(json['scoreVersionId']),
      status: serializer.fromJson<String>(json['status']),
      progress: serializer.fromJson<double?>(json['progress']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
      result: serializer.fromJson<String?>(json['result']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'type': serializer.toJson<String>(type),
      'mediaAssetId': serializer.toJson<String?>(mediaAssetId),
      'pieceId': serializer.toJson<String?>(pieceId),
      'scoreVersionId': serializer.toJson<String?>(scoreVersionId),
      'status': serializer.toJson<String>(status),
      'progress': serializer.toJson<double?>(progress),
      'errorMessage': serializer.toJson<String?>(errorMessage),
      'result': serializer.toJson<String?>(result),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
    };
  }

  ProcessingJob copyWith(
          {String? id,
          String? type,
          Value<String?> mediaAssetId = const Value.absent(),
          Value<String?> pieceId = const Value.absent(),
          Value<String?> scoreVersionId = const Value.absent(),
          String? status,
          Value<double?> progress = const Value.absent(),
          Value<String?> errorMessage = const Value.absent(),
          Value<String?> result = const Value.absent(),
          DateTime? createdAt,
          Value<DateTime?> completedAt = const Value.absent()}) =>
      ProcessingJob(
        id: id ?? this.id,
        type: type ?? this.type,
        mediaAssetId:
            mediaAssetId.present ? mediaAssetId.value : this.mediaAssetId,
        pieceId: pieceId.present ? pieceId.value : this.pieceId,
        scoreVersionId:
            scoreVersionId.present ? scoreVersionId.value : this.scoreVersionId,
        status: status ?? this.status,
        progress: progress.present ? progress.value : this.progress,
        errorMessage:
            errorMessage.present ? errorMessage.value : this.errorMessage,
        result: result.present ? result.value : this.result,
        createdAt: createdAt ?? this.createdAt,
        completedAt: completedAt.present ? completedAt.value : this.completedAt,
      );
  ProcessingJob copyWithCompanion(ProcessingJobsCompanion data) {
    return ProcessingJob(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      mediaAssetId: data.mediaAssetId.present
          ? data.mediaAssetId.value
          : this.mediaAssetId,
      pieceId: data.pieceId.present ? data.pieceId.value : this.pieceId,
      scoreVersionId: data.scoreVersionId.present
          ? data.scoreVersionId.value
          : this.scoreVersionId,
      status: data.status.present ? data.status.value : this.status,
      progress: data.progress.present ? data.progress.value : this.progress,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
      result: data.result.present ? data.result.value : this.result,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      completedAt:
          data.completedAt.present ? data.completedAt.value : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProcessingJob(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('mediaAssetId: $mediaAssetId, ')
          ..write('pieceId: $pieceId, ')
          ..write('scoreVersionId: $scoreVersionId, ')
          ..write('status: $status, ')
          ..write('progress: $progress, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('result: $result, ')
          ..write('createdAt: $createdAt, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      type,
      mediaAssetId,
      pieceId,
      scoreVersionId,
      status,
      progress,
      errorMessage,
      result,
      createdAt,
      completedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProcessingJob &&
          other.id == this.id &&
          other.type == this.type &&
          other.mediaAssetId == this.mediaAssetId &&
          other.pieceId == this.pieceId &&
          other.scoreVersionId == this.scoreVersionId &&
          other.status == this.status &&
          other.progress == this.progress &&
          other.errorMessage == this.errorMessage &&
          other.result == this.result &&
          other.createdAt == this.createdAt &&
          other.completedAt == this.completedAt);
}

class ProcessingJobsCompanion extends UpdateCompanion<ProcessingJob> {
  final Value<String> id;
  final Value<String> type;
  final Value<String?> mediaAssetId;
  final Value<String?> pieceId;
  final Value<String?> scoreVersionId;
  final Value<String> status;
  final Value<double?> progress;
  final Value<String?> errorMessage;
  final Value<String?> result;
  final Value<DateTime> createdAt;
  final Value<DateTime?> completedAt;
  final Value<int> rowid;
  const ProcessingJobsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.mediaAssetId = const Value.absent(),
    this.pieceId = const Value.absent(),
    this.scoreVersionId = const Value.absent(),
    this.status = const Value.absent(),
    this.progress = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.result = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProcessingJobsCompanion.insert({
    required String id,
    required String type,
    this.mediaAssetId = const Value.absent(),
    this.pieceId = const Value.absent(),
    this.scoreVersionId = const Value.absent(),
    required String status,
    this.progress = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.result = const Value.absent(),
    required DateTime createdAt,
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        type = Value(type),
        status = Value(status),
        createdAt = Value(createdAt);
  static Insertable<ProcessingJob> custom({
    Expression<String>? id,
    Expression<String>? type,
    Expression<String>? mediaAssetId,
    Expression<String>? pieceId,
    Expression<String>? scoreVersionId,
    Expression<String>? status,
    Expression<double>? progress,
    Expression<String>? errorMessage,
    Expression<String>? result,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? completedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (mediaAssetId != null) 'media_asset_id': mediaAssetId,
      if (pieceId != null) 'piece_id': pieceId,
      if (scoreVersionId != null) 'score_version_id': scoreVersionId,
      if (status != null) 'status': status,
      if (progress != null) 'progress': progress,
      if (errorMessage != null) 'error_message': errorMessage,
      if (result != null) 'result': result,
      if (createdAt != null) 'created_at': createdAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProcessingJobsCompanion copyWith(
      {Value<String>? id,
      Value<String>? type,
      Value<String?>? mediaAssetId,
      Value<String?>? pieceId,
      Value<String?>? scoreVersionId,
      Value<String>? status,
      Value<double?>? progress,
      Value<String?>? errorMessage,
      Value<String?>? result,
      Value<DateTime>? createdAt,
      Value<DateTime?>? completedAt,
      Value<int>? rowid}) {
    return ProcessingJobsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      mediaAssetId: mediaAssetId ?? this.mediaAssetId,
      pieceId: pieceId ?? this.pieceId,
      scoreVersionId: scoreVersionId ?? this.scoreVersionId,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
      result: result ?? this.result,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (mediaAssetId.present) {
      map['media_asset_id'] = Variable<String>(mediaAssetId.value);
    }
    if (pieceId.present) {
      map['piece_id'] = Variable<String>(pieceId.value);
    }
    if (scoreVersionId.present) {
      map['score_version_id'] = Variable<String>(scoreVersionId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (progress.present) {
      map['progress'] = Variable<double>(progress.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (result.present) {
      map['result'] = Variable<String>(result.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProcessingJobsCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('mediaAssetId: $mediaAssetId, ')
          ..write('pieceId: $pieceId, ')
          ..write('scoreVersionId: $scoreVersionId, ')
          ..write('status: $status, ')
          ..write('progress: $progress, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('result: $result, ')
          ..write('createdAt: $createdAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReviewItemsTable extends ReviewItems
    with TableInfo<$ReviewItemsTable, ReviewItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReviewItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _pieceIdMeta =
      const VerificationMeta('pieceId');
  @override
  late final GeneratedColumn<String> pieceId = GeneratedColumn<String>(
      'piece_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES pieces (id)'));
  static const VerificationMeta _mediaAssetIdMeta =
      const VerificationMeta('mediaAssetId');
  @override
  late final GeneratedColumn<String> mediaAssetId = GeneratedColumn<String>(
      'media_asset_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _scoreVersionIdMeta =
      const VerificationMeta('scoreVersionId');
  @override
  late final GeneratedColumn<String> scoreVersionId = GeneratedColumn<String>(
      'score_version_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _instructorNotesMeta =
      const VerificationMeta('instructorNotes');
  @override
  late final GeneratedColumn<String> instructorNotes = GeneratedColumn<String>(
      'instructor_notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _overallRatingMeta =
      const VerificationMeta('overallRating');
  @override
  late final GeneratedColumn<double> overallRating = GeneratedColumn<double>(
      'overall_rating', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _reviewedAtMeta =
      const VerificationMeta('reviewedAt');
  @override
  late final GeneratedColumn<DateTime> reviewedAt = GeneratedColumn<DateTime>(
      'reviewed_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        pieceId,
        mediaAssetId,
        scoreVersionId,
        status,
        instructorNotes,
        overallRating,
        createdAt,
        reviewedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'review_items';
  @override
  VerificationContext validateIntegrity(Insertable<ReviewItem> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('piece_id')) {
      context.handle(_pieceIdMeta,
          pieceId.isAcceptableOrUnknown(data['piece_id']!, _pieceIdMeta));
    } else if (isInserting) {
      context.missing(_pieceIdMeta);
    }
    if (data.containsKey('media_asset_id')) {
      context.handle(
          _mediaAssetIdMeta,
          mediaAssetId.isAcceptableOrUnknown(
              data['media_asset_id']!, _mediaAssetIdMeta));
    }
    if (data.containsKey('score_version_id')) {
      context.handle(
          _scoreVersionIdMeta,
          scoreVersionId.isAcceptableOrUnknown(
              data['score_version_id']!, _scoreVersionIdMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('instructor_notes')) {
      context.handle(
          _instructorNotesMeta,
          instructorNotes.isAcceptableOrUnknown(
              data['instructor_notes']!, _instructorNotesMeta));
    }
    if (data.containsKey('overall_rating')) {
      context.handle(
          _overallRatingMeta,
          overallRating.isAcceptableOrUnknown(
              data['overall_rating']!, _overallRatingMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('reviewed_at')) {
      context.handle(
          _reviewedAtMeta,
          reviewedAt.isAcceptableOrUnknown(
              data['reviewed_at']!, _reviewedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReviewItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReviewItem(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      pieceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}piece_id'])!,
      mediaAssetId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}media_asset_id']),
      scoreVersionId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}score_version_id']),
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      instructorNotes: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}instructor_notes']),
      overallRating: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}overall_rating']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      reviewedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}reviewed_at']),
    );
  }

  @override
  $ReviewItemsTable createAlias(String alias) {
    return $ReviewItemsTable(attachedDatabase, alias);
  }
}

class ReviewItem extends DataClass implements Insertable<ReviewItem> {
  final String id;
  final String pieceId;
  final String? mediaAssetId;
  final String? scoreVersionId;
  final String status;
  final String? instructorNotes;
  final double? overallRating;
  final DateTime createdAt;
  final DateTime? reviewedAt;
  const ReviewItem(
      {required this.id,
      required this.pieceId,
      this.mediaAssetId,
      this.scoreVersionId,
      required this.status,
      this.instructorNotes,
      this.overallRating,
      required this.createdAt,
      this.reviewedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['piece_id'] = Variable<String>(pieceId);
    if (!nullToAbsent || mediaAssetId != null) {
      map['media_asset_id'] = Variable<String>(mediaAssetId);
    }
    if (!nullToAbsent || scoreVersionId != null) {
      map['score_version_id'] = Variable<String>(scoreVersionId);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || instructorNotes != null) {
      map['instructor_notes'] = Variable<String>(instructorNotes);
    }
    if (!nullToAbsent || overallRating != null) {
      map['overall_rating'] = Variable<double>(overallRating);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || reviewedAt != null) {
      map['reviewed_at'] = Variable<DateTime>(reviewedAt);
    }
    return map;
  }

  ReviewItemsCompanion toCompanion(bool nullToAbsent) {
    return ReviewItemsCompanion(
      id: Value(id),
      pieceId: Value(pieceId),
      mediaAssetId: mediaAssetId == null && nullToAbsent
          ? const Value.absent()
          : Value(mediaAssetId),
      scoreVersionId: scoreVersionId == null && nullToAbsent
          ? const Value.absent()
          : Value(scoreVersionId),
      status: Value(status),
      instructorNotes: instructorNotes == null && nullToAbsent
          ? const Value.absent()
          : Value(instructorNotes),
      overallRating: overallRating == null && nullToAbsent
          ? const Value.absent()
          : Value(overallRating),
      createdAt: Value(createdAt),
      reviewedAt: reviewedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(reviewedAt),
    );
  }

  factory ReviewItem.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReviewItem(
      id: serializer.fromJson<String>(json['id']),
      pieceId: serializer.fromJson<String>(json['pieceId']),
      mediaAssetId: serializer.fromJson<String?>(json['mediaAssetId']),
      scoreVersionId: serializer.fromJson<String?>(json['scoreVersionId']),
      status: serializer.fromJson<String>(json['status']),
      instructorNotes: serializer.fromJson<String?>(json['instructorNotes']),
      overallRating: serializer.fromJson<double?>(json['overallRating']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      reviewedAt: serializer.fromJson<DateTime?>(json['reviewedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'pieceId': serializer.toJson<String>(pieceId),
      'mediaAssetId': serializer.toJson<String?>(mediaAssetId),
      'scoreVersionId': serializer.toJson<String?>(scoreVersionId),
      'status': serializer.toJson<String>(status),
      'instructorNotes': serializer.toJson<String?>(instructorNotes),
      'overallRating': serializer.toJson<double?>(overallRating),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'reviewedAt': serializer.toJson<DateTime?>(reviewedAt),
    };
  }

  ReviewItem copyWith(
          {String? id,
          String? pieceId,
          Value<String?> mediaAssetId = const Value.absent(),
          Value<String?> scoreVersionId = const Value.absent(),
          String? status,
          Value<String?> instructorNotes = const Value.absent(),
          Value<double?> overallRating = const Value.absent(),
          DateTime? createdAt,
          Value<DateTime?> reviewedAt = const Value.absent()}) =>
      ReviewItem(
        id: id ?? this.id,
        pieceId: pieceId ?? this.pieceId,
        mediaAssetId:
            mediaAssetId.present ? mediaAssetId.value : this.mediaAssetId,
        scoreVersionId:
            scoreVersionId.present ? scoreVersionId.value : this.scoreVersionId,
        status: status ?? this.status,
        instructorNotes: instructorNotes.present
            ? instructorNotes.value
            : this.instructorNotes,
        overallRating:
            overallRating.present ? overallRating.value : this.overallRating,
        createdAt: createdAt ?? this.createdAt,
        reviewedAt: reviewedAt.present ? reviewedAt.value : this.reviewedAt,
      );
  ReviewItem copyWithCompanion(ReviewItemsCompanion data) {
    return ReviewItem(
      id: data.id.present ? data.id.value : this.id,
      pieceId: data.pieceId.present ? data.pieceId.value : this.pieceId,
      mediaAssetId: data.mediaAssetId.present
          ? data.mediaAssetId.value
          : this.mediaAssetId,
      scoreVersionId: data.scoreVersionId.present
          ? data.scoreVersionId.value
          : this.scoreVersionId,
      status: data.status.present ? data.status.value : this.status,
      instructorNotes: data.instructorNotes.present
          ? data.instructorNotes.value
          : this.instructorNotes,
      overallRating: data.overallRating.present
          ? data.overallRating.value
          : this.overallRating,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      reviewedAt:
          data.reviewedAt.present ? data.reviewedAt.value : this.reviewedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReviewItem(')
          ..write('id: $id, ')
          ..write('pieceId: $pieceId, ')
          ..write('mediaAssetId: $mediaAssetId, ')
          ..write('scoreVersionId: $scoreVersionId, ')
          ..write('status: $status, ')
          ..write('instructorNotes: $instructorNotes, ')
          ..write('overallRating: $overallRating, ')
          ..write('createdAt: $createdAt, ')
          ..write('reviewedAt: $reviewedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, pieceId, mediaAssetId, scoreVersionId,
      status, instructorNotes, overallRating, createdAt, reviewedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReviewItem &&
          other.id == this.id &&
          other.pieceId == this.pieceId &&
          other.mediaAssetId == this.mediaAssetId &&
          other.scoreVersionId == this.scoreVersionId &&
          other.status == this.status &&
          other.instructorNotes == this.instructorNotes &&
          other.overallRating == this.overallRating &&
          other.createdAt == this.createdAt &&
          other.reviewedAt == this.reviewedAt);
}

class ReviewItemsCompanion extends UpdateCompanion<ReviewItem> {
  final Value<String> id;
  final Value<String> pieceId;
  final Value<String?> mediaAssetId;
  final Value<String?> scoreVersionId;
  final Value<String> status;
  final Value<String?> instructorNotes;
  final Value<double?> overallRating;
  final Value<DateTime> createdAt;
  final Value<DateTime?> reviewedAt;
  final Value<int> rowid;
  const ReviewItemsCompanion({
    this.id = const Value.absent(),
    this.pieceId = const Value.absent(),
    this.mediaAssetId = const Value.absent(),
    this.scoreVersionId = const Value.absent(),
    this.status = const Value.absent(),
    this.instructorNotes = const Value.absent(),
    this.overallRating = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.reviewedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReviewItemsCompanion.insert({
    required String id,
    required String pieceId,
    this.mediaAssetId = const Value.absent(),
    this.scoreVersionId = const Value.absent(),
    required String status,
    this.instructorNotes = const Value.absent(),
    this.overallRating = const Value.absent(),
    required DateTime createdAt,
    this.reviewedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        pieceId = Value(pieceId),
        status = Value(status),
        createdAt = Value(createdAt);
  static Insertable<ReviewItem> custom({
    Expression<String>? id,
    Expression<String>? pieceId,
    Expression<String>? mediaAssetId,
    Expression<String>? scoreVersionId,
    Expression<String>? status,
    Expression<String>? instructorNotes,
    Expression<double>? overallRating,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? reviewedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (pieceId != null) 'piece_id': pieceId,
      if (mediaAssetId != null) 'media_asset_id': mediaAssetId,
      if (scoreVersionId != null) 'score_version_id': scoreVersionId,
      if (status != null) 'status': status,
      if (instructorNotes != null) 'instructor_notes': instructorNotes,
      if (overallRating != null) 'overall_rating': overallRating,
      if (createdAt != null) 'created_at': createdAt,
      if (reviewedAt != null) 'reviewed_at': reviewedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReviewItemsCompanion copyWith(
      {Value<String>? id,
      Value<String>? pieceId,
      Value<String?>? mediaAssetId,
      Value<String?>? scoreVersionId,
      Value<String>? status,
      Value<String?>? instructorNotes,
      Value<double?>? overallRating,
      Value<DateTime>? createdAt,
      Value<DateTime?>? reviewedAt,
      Value<int>? rowid}) {
    return ReviewItemsCompanion(
      id: id ?? this.id,
      pieceId: pieceId ?? this.pieceId,
      mediaAssetId: mediaAssetId ?? this.mediaAssetId,
      scoreVersionId: scoreVersionId ?? this.scoreVersionId,
      status: status ?? this.status,
      instructorNotes: instructorNotes ?? this.instructorNotes,
      overallRating: overallRating ?? this.overallRating,
      createdAt: createdAt ?? this.createdAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (pieceId.present) {
      map['piece_id'] = Variable<String>(pieceId.value);
    }
    if (mediaAssetId.present) {
      map['media_asset_id'] = Variable<String>(mediaAssetId.value);
    }
    if (scoreVersionId.present) {
      map['score_version_id'] = Variable<String>(scoreVersionId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (instructorNotes.present) {
      map['instructor_notes'] = Variable<String>(instructorNotes.value);
    }
    if (overallRating.present) {
      map['overall_rating'] = Variable<double>(overallRating.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (reviewedAt.present) {
      map['reviewed_at'] = Variable<DateTime>(reviewedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReviewItemsCompanion(')
          ..write('id: $id, ')
          ..write('pieceId: $pieceId, ')
          ..write('mediaAssetId: $mediaAssetId, ')
          ..write('scoreVersionId: $scoreVersionId, ')
          ..write('status: $status, ')
          ..write('instructorNotes: $instructorNotes, ')
          ..write('overallRating: $overallRating, ')
          ..write('createdAt: $createdAt, ')
          ..write('reviewedAt: $reviewedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PieceHistoryDraftsTable extends PieceHistoryDrafts
    with TableInfo<$PieceHistoryDraftsTable, PieceHistoryDraft> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PieceHistoryDraftsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _pieceIdMeta =
      const VerificationMeta('pieceId');
  @override
  late final GeneratedColumn<String> pieceId = GeneratedColumn<String>(
      'piece_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES pieces (id)'));
  static const VerificationMeta _totalPracticeSessionsMeta =
      const VerificationMeta('totalPracticeSessions');
  @override
  late final GeneratedColumn<int> totalPracticeSessions = GeneratedColumn<int>(
      'total_practice_sessions', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _totalPracticeTimeMsMeta =
      const VerificationMeta('totalPracticeTimeMs');
  @override
  late final GeneratedColumn<BigInt> totalPracticeTimeMs =
      GeneratedColumn<BigInt>('total_practice_time_ms', aliasedName, false,
          type: DriftSqlType.bigInt, requiredDuringInsert: true);
  static const VerificationMeta _lastPlayedPageMeta =
      const VerificationMeta('lastPlayedPage');
  @override
  late final GeneratedColumn<int> lastPlayedPage = GeneratedColumn<int>(
      'last_played_page', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _currentFocusMeta =
      const VerificationMeta('currentFocus');
  @override
  late final GeneratedColumn<String> currentFocus = GeneratedColumn<String>(
      'current_focus', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _lastPracticedAtMeta =
      const VerificationMeta('lastPracticedAt');
  @override
  late final GeneratedColumn<DateTime> lastPracticedAt =
      GeneratedColumn<DateTime>('last_practiced_at', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        pieceId,
        totalPracticeSessions,
        totalPracticeTimeMs,
        lastPlayedPage,
        currentFocus,
        lastPracticedAt,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'piece_history_drafts';
  @override
  VerificationContext validateIntegrity(Insertable<PieceHistoryDraft> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('piece_id')) {
      context.handle(_pieceIdMeta,
          pieceId.isAcceptableOrUnknown(data['piece_id']!, _pieceIdMeta));
    } else if (isInserting) {
      context.missing(_pieceIdMeta);
    }
    if (data.containsKey('total_practice_sessions')) {
      context.handle(
          _totalPracticeSessionsMeta,
          totalPracticeSessions.isAcceptableOrUnknown(
              data['total_practice_sessions']!, _totalPracticeSessionsMeta));
    } else if (isInserting) {
      context.missing(_totalPracticeSessionsMeta);
    }
    if (data.containsKey('total_practice_time_ms')) {
      context.handle(
          _totalPracticeTimeMsMeta,
          totalPracticeTimeMs.isAcceptableOrUnknown(
              data['total_practice_time_ms']!, _totalPracticeTimeMsMeta));
    } else if (isInserting) {
      context.missing(_totalPracticeTimeMsMeta);
    }
    if (data.containsKey('last_played_page')) {
      context.handle(
          _lastPlayedPageMeta,
          lastPlayedPage.isAcceptableOrUnknown(
              data['last_played_page']!, _lastPlayedPageMeta));
    }
    if (data.containsKey('current_focus')) {
      context.handle(
          _currentFocusMeta,
          currentFocus.isAcceptableOrUnknown(
              data['current_focus']!, _currentFocusMeta));
    }
    if (data.containsKey('last_practiced_at')) {
      context.handle(
          _lastPracticedAtMeta,
          lastPracticedAt.isAcceptableOrUnknown(
              data['last_practiced_at']!, _lastPracticedAtMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PieceHistoryDraft map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PieceHistoryDraft(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      pieceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}piece_id'])!,
      totalPracticeSessions: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}total_practice_sessions'])!,
      totalPracticeTimeMs: attachedDatabase.typeMapping.read(
          DriftSqlType.bigInt,
          data['${effectivePrefix}total_practice_time_ms'])!,
      lastPlayedPage: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}last_played_page']),
      currentFocus: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}current_focus']),
      lastPracticedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_practiced_at']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $PieceHistoryDraftsTable createAlias(String alias) {
    return $PieceHistoryDraftsTable(attachedDatabase, alias);
  }
}

class PieceHistoryDraft extends DataClass
    implements Insertable<PieceHistoryDraft> {
  final String id;
  final String pieceId;
  final int totalPracticeSessions;
  final BigInt totalPracticeTimeMs;
  final int? lastPlayedPage;
  final String? currentFocus;
  final DateTime? lastPracticedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  const PieceHistoryDraft(
      {required this.id,
      required this.pieceId,
      required this.totalPracticeSessions,
      required this.totalPracticeTimeMs,
      this.lastPlayedPage,
      this.currentFocus,
      this.lastPracticedAt,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['piece_id'] = Variable<String>(pieceId);
    map['total_practice_sessions'] = Variable<int>(totalPracticeSessions);
    map['total_practice_time_ms'] = Variable<BigInt>(totalPracticeTimeMs);
    if (!nullToAbsent || lastPlayedPage != null) {
      map['last_played_page'] = Variable<int>(lastPlayedPage);
    }
    if (!nullToAbsent || currentFocus != null) {
      map['current_focus'] = Variable<String>(currentFocus);
    }
    if (!nullToAbsent || lastPracticedAt != null) {
      map['last_practiced_at'] = Variable<DateTime>(lastPracticedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PieceHistoryDraftsCompanion toCompanion(bool nullToAbsent) {
    return PieceHistoryDraftsCompanion(
      id: Value(id),
      pieceId: Value(pieceId),
      totalPracticeSessions: Value(totalPracticeSessions),
      totalPracticeTimeMs: Value(totalPracticeTimeMs),
      lastPlayedPage: lastPlayedPage == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPlayedPage),
      currentFocus: currentFocus == null && nullToAbsent
          ? const Value.absent()
          : Value(currentFocus),
      lastPracticedAt: lastPracticedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPracticedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory PieceHistoryDraft.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PieceHistoryDraft(
      id: serializer.fromJson<String>(json['id']),
      pieceId: serializer.fromJson<String>(json['pieceId']),
      totalPracticeSessions:
          serializer.fromJson<int>(json['totalPracticeSessions']),
      totalPracticeTimeMs:
          serializer.fromJson<BigInt>(json['totalPracticeTimeMs']),
      lastPlayedPage: serializer.fromJson<int?>(json['lastPlayedPage']),
      currentFocus: serializer.fromJson<String?>(json['currentFocus']),
      lastPracticedAt: serializer.fromJson<DateTime?>(json['lastPracticedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'pieceId': serializer.toJson<String>(pieceId),
      'totalPracticeSessions': serializer.toJson<int>(totalPracticeSessions),
      'totalPracticeTimeMs': serializer.toJson<BigInt>(totalPracticeTimeMs),
      'lastPlayedPage': serializer.toJson<int?>(lastPlayedPage),
      'currentFocus': serializer.toJson<String?>(currentFocus),
      'lastPracticedAt': serializer.toJson<DateTime?>(lastPracticedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  PieceHistoryDraft copyWith(
          {String? id,
          String? pieceId,
          int? totalPracticeSessions,
          BigInt? totalPracticeTimeMs,
          Value<int?> lastPlayedPage = const Value.absent(),
          Value<String?> currentFocus = const Value.absent(),
          Value<DateTime?> lastPracticedAt = const Value.absent(),
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      PieceHistoryDraft(
        id: id ?? this.id,
        pieceId: pieceId ?? this.pieceId,
        totalPracticeSessions:
            totalPracticeSessions ?? this.totalPracticeSessions,
        totalPracticeTimeMs: totalPracticeTimeMs ?? this.totalPracticeTimeMs,
        lastPlayedPage:
            lastPlayedPage.present ? lastPlayedPage.value : this.lastPlayedPage,
        currentFocus:
            currentFocus.present ? currentFocus.value : this.currentFocus,
        lastPracticedAt: lastPracticedAt.present
            ? lastPracticedAt.value
            : this.lastPracticedAt,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  PieceHistoryDraft copyWithCompanion(PieceHistoryDraftsCompanion data) {
    return PieceHistoryDraft(
      id: data.id.present ? data.id.value : this.id,
      pieceId: data.pieceId.present ? data.pieceId.value : this.pieceId,
      totalPracticeSessions: data.totalPracticeSessions.present
          ? data.totalPracticeSessions.value
          : this.totalPracticeSessions,
      totalPracticeTimeMs: data.totalPracticeTimeMs.present
          ? data.totalPracticeTimeMs.value
          : this.totalPracticeTimeMs,
      lastPlayedPage: data.lastPlayedPage.present
          ? data.lastPlayedPage.value
          : this.lastPlayedPage,
      currentFocus: data.currentFocus.present
          ? data.currentFocus.value
          : this.currentFocus,
      lastPracticedAt: data.lastPracticedAt.present
          ? data.lastPracticedAt.value
          : this.lastPracticedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PieceHistoryDraft(')
          ..write('id: $id, ')
          ..write('pieceId: $pieceId, ')
          ..write('totalPracticeSessions: $totalPracticeSessions, ')
          ..write('totalPracticeTimeMs: $totalPracticeTimeMs, ')
          ..write('lastPlayedPage: $lastPlayedPage, ')
          ..write('currentFocus: $currentFocus, ')
          ..write('lastPracticedAt: $lastPracticedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      pieceId,
      totalPracticeSessions,
      totalPracticeTimeMs,
      lastPlayedPage,
      currentFocus,
      lastPracticedAt,
      createdAt,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PieceHistoryDraft &&
          other.id == this.id &&
          other.pieceId == this.pieceId &&
          other.totalPracticeSessions == this.totalPracticeSessions &&
          other.totalPracticeTimeMs == this.totalPracticeTimeMs &&
          other.lastPlayedPage == this.lastPlayedPage &&
          other.currentFocus == this.currentFocus &&
          other.lastPracticedAt == this.lastPracticedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class PieceHistoryDraftsCompanion extends UpdateCompanion<PieceHistoryDraft> {
  final Value<String> id;
  final Value<String> pieceId;
  final Value<int> totalPracticeSessions;
  final Value<BigInt> totalPracticeTimeMs;
  final Value<int?> lastPlayedPage;
  final Value<String?> currentFocus;
  final Value<DateTime?> lastPracticedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const PieceHistoryDraftsCompanion({
    this.id = const Value.absent(),
    this.pieceId = const Value.absent(),
    this.totalPracticeSessions = const Value.absent(),
    this.totalPracticeTimeMs = const Value.absent(),
    this.lastPlayedPage = const Value.absent(),
    this.currentFocus = const Value.absent(),
    this.lastPracticedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PieceHistoryDraftsCompanion.insert({
    required String id,
    required String pieceId,
    required int totalPracticeSessions,
    required BigInt totalPracticeTimeMs,
    this.lastPlayedPage = const Value.absent(),
    this.currentFocus = const Value.absent(),
    this.lastPracticedAt = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        pieceId = Value(pieceId),
        totalPracticeSessions = Value(totalPracticeSessions),
        totalPracticeTimeMs = Value(totalPracticeTimeMs),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<PieceHistoryDraft> custom({
    Expression<String>? id,
    Expression<String>? pieceId,
    Expression<int>? totalPracticeSessions,
    Expression<BigInt>? totalPracticeTimeMs,
    Expression<int>? lastPlayedPage,
    Expression<String>? currentFocus,
    Expression<DateTime>? lastPracticedAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (pieceId != null) 'piece_id': pieceId,
      if (totalPracticeSessions != null)
        'total_practice_sessions': totalPracticeSessions,
      if (totalPracticeTimeMs != null)
        'total_practice_time_ms': totalPracticeTimeMs,
      if (lastPlayedPage != null) 'last_played_page': lastPlayedPage,
      if (currentFocus != null) 'current_focus': currentFocus,
      if (lastPracticedAt != null) 'last_practiced_at': lastPracticedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PieceHistoryDraftsCompanion copyWith(
      {Value<String>? id,
      Value<String>? pieceId,
      Value<int>? totalPracticeSessions,
      Value<BigInt>? totalPracticeTimeMs,
      Value<int?>? lastPlayedPage,
      Value<String?>? currentFocus,
      Value<DateTime?>? lastPracticedAt,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return PieceHistoryDraftsCompanion(
      id: id ?? this.id,
      pieceId: pieceId ?? this.pieceId,
      totalPracticeSessions:
          totalPracticeSessions ?? this.totalPracticeSessions,
      totalPracticeTimeMs: totalPracticeTimeMs ?? this.totalPracticeTimeMs,
      lastPlayedPage: lastPlayedPage ?? this.lastPlayedPage,
      currentFocus: currentFocus ?? this.currentFocus,
      lastPracticedAt: lastPracticedAt ?? this.lastPracticedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (pieceId.present) {
      map['piece_id'] = Variable<String>(pieceId.value);
    }
    if (totalPracticeSessions.present) {
      map['total_practice_sessions'] =
          Variable<int>(totalPracticeSessions.value);
    }
    if (totalPracticeTimeMs.present) {
      map['total_practice_time_ms'] =
          Variable<BigInt>(totalPracticeTimeMs.value);
    }
    if (lastPlayedPage.present) {
      map['last_played_page'] = Variable<int>(lastPlayedPage.value);
    }
    if (currentFocus.present) {
      map['current_focus'] = Variable<String>(currentFocus.value);
    }
    if (lastPracticedAt.present) {
      map['last_practiced_at'] = Variable<DateTime>(lastPracticedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PieceHistoryDraftsCompanion(')
          ..write('id: $id, ')
          ..write('pieceId: $pieceId, ')
          ..write('totalPracticeSessions: $totalPracticeSessions, ')
          ..write('totalPracticeTimeMs: $totalPracticeTimeMs, ')
          ..write('lastPlayedPage: $lastPlayedPage, ')
          ..write('currentFocus: $currentFocus, ')
          ..write('lastPracticedAt: $lastPracticedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncStatesTable extends SyncStates
    with TableInfo<$SyncStatesTable, SyncState> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _entityTypeMeta =
      const VerificationMeta('entityType');
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
      'entity_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _entityIdMeta =
      const VerificationMeta('entityId');
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
      'entity_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _lastSyncHashMeta =
      const VerificationMeta('lastSyncHash');
  @override
  late final GeneratedColumn<String> lastSyncHash = GeneratedColumn<String>(
      'last_sync_hash', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _lastSyncAtMeta =
      const VerificationMeta('lastSyncAt');
  @override
  late final GeneratedColumn<DateTime> lastSyncAt = GeneratedColumn<DateTime>(
      'last_sync_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _lastDirectionMeta =
      const VerificationMeta('lastDirection');
  @override
  late final GeneratedColumn<String> lastDirection = GeneratedColumn<String>(
      'last_direction', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _errorMessageMeta =
      const VerificationMeta('errorMessage');
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
      'error_message', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        entityType,
        entityId,
        lastSyncHash,
        lastSyncAt,
        lastDirection,
        status,
        errorMessage
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_states';
  @override
  VerificationContext validateIntegrity(Insertable<SyncState> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('entity_type')) {
      context.handle(
          _entityTypeMeta,
          entityType.isAcceptableOrUnknown(
              data['entity_type']!, _entityTypeMeta));
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(_entityIdMeta,
          entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta));
    }
    if (data.containsKey('last_sync_hash')) {
      context.handle(
          _lastSyncHashMeta,
          lastSyncHash.isAcceptableOrUnknown(
              data['last_sync_hash']!, _lastSyncHashMeta));
    } else if (isInserting) {
      context.missing(_lastSyncHashMeta);
    }
    if (data.containsKey('last_sync_at')) {
      context.handle(
          _lastSyncAtMeta,
          lastSyncAt.isAcceptableOrUnknown(
              data['last_sync_at']!, _lastSyncAtMeta));
    } else if (isInserting) {
      context.missing(_lastSyncAtMeta);
    }
    if (data.containsKey('last_direction')) {
      context.handle(
          _lastDirectionMeta,
          lastDirection.isAcceptableOrUnknown(
              data['last_direction']!, _lastDirectionMeta));
    } else if (isInserting) {
      context.missing(_lastDirectionMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('error_message')) {
      context.handle(
          _errorMessageMeta,
          errorMessage.isAcceptableOrUnknown(
              data['error_message']!, _errorMessageMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {entityType, entityId};
  @override
  SyncState map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncState(
      entityType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entity_type'])!,
      entityId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entity_id']),
      lastSyncHash: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_sync_hash'])!,
      lastSyncAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}last_sync_at'])!,
      lastDirection: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_direction'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      errorMessage: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}error_message']),
    );
  }

  @override
  $SyncStatesTable createAlias(String alias) {
    return $SyncStatesTable(attachedDatabase, alias);
  }
}

class SyncState extends DataClass implements Insertable<SyncState> {
  final String entityType;
  final String? entityId;
  final String lastSyncHash;
  final DateTime lastSyncAt;
  final String lastDirection;
  final String status;
  final String? errorMessage;
  const SyncState(
      {required this.entityType,
      this.entityId,
      required this.lastSyncHash,
      required this.lastSyncAt,
      required this.lastDirection,
      required this.status,
      this.errorMessage});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['entity_type'] = Variable<String>(entityType);
    if (!nullToAbsent || entityId != null) {
      map['entity_id'] = Variable<String>(entityId);
    }
    map['last_sync_hash'] = Variable<String>(lastSyncHash);
    map['last_sync_at'] = Variable<DateTime>(lastSyncAt);
    map['last_direction'] = Variable<String>(lastDirection);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    return map;
  }

  SyncStatesCompanion toCompanion(bool nullToAbsent) {
    return SyncStatesCompanion(
      entityType: Value(entityType),
      entityId: entityId == null && nullToAbsent
          ? const Value.absent()
          : Value(entityId),
      lastSyncHash: Value(lastSyncHash),
      lastSyncAt: Value(lastSyncAt),
      lastDirection: Value(lastDirection),
      status: Value(status),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
    );
  }

  factory SyncState.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncState(
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String?>(json['entityId']),
      lastSyncHash: serializer.fromJson<String>(json['lastSyncHash']),
      lastSyncAt: serializer.fromJson<DateTime>(json['lastSyncAt']),
      lastDirection: serializer.fromJson<String>(json['lastDirection']),
      status: serializer.fromJson<String>(json['status']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String?>(entityId),
      'lastSyncHash': serializer.toJson<String>(lastSyncHash),
      'lastSyncAt': serializer.toJson<DateTime>(lastSyncAt),
      'lastDirection': serializer.toJson<String>(lastDirection),
      'status': serializer.toJson<String>(status),
      'errorMessage': serializer.toJson<String?>(errorMessage),
    };
  }

  SyncState copyWith(
          {String? entityType,
          Value<String?> entityId = const Value.absent(),
          String? lastSyncHash,
          DateTime? lastSyncAt,
          String? lastDirection,
          String? status,
          Value<String?> errorMessage = const Value.absent()}) =>
      SyncState(
        entityType: entityType ?? this.entityType,
        entityId: entityId.present ? entityId.value : this.entityId,
        lastSyncHash: lastSyncHash ?? this.lastSyncHash,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
        lastDirection: lastDirection ?? this.lastDirection,
        status: status ?? this.status,
        errorMessage:
            errorMessage.present ? errorMessage.value : this.errorMessage,
      );
  SyncState copyWithCompanion(SyncStatesCompanion data) {
    return SyncState(
      entityType:
          data.entityType.present ? data.entityType.value : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      lastSyncHash: data.lastSyncHash.present
          ? data.lastSyncHash.value
          : this.lastSyncHash,
      lastSyncAt:
          data.lastSyncAt.present ? data.lastSyncAt.value : this.lastSyncAt,
      lastDirection: data.lastDirection.present
          ? data.lastDirection.value
          : this.lastDirection,
      status: data.status.present ? data.status.value : this.status,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncState(')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('lastSyncHash: $lastSyncHash, ')
          ..write('lastSyncAt: $lastSyncAt, ')
          ..write('lastDirection: $lastDirection, ')
          ..write('status: $status, ')
          ..write('errorMessage: $errorMessage')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(entityType, entityId, lastSyncHash,
      lastSyncAt, lastDirection, status, errorMessage);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncState &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.lastSyncHash == this.lastSyncHash &&
          other.lastSyncAt == this.lastSyncAt &&
          other.lastDirection == this.lastDirection &&
          other.status == this.status &&
          other.errorMessage == this.errorMessage);
}

class SyncStatesCompanion extends UpdateCompanion<SyncState> {
  final Value<String> entityType;
  final Value<String?> entityId;
  final Value<String> lastSyncHash;
  final Value<DateTime> lastSyncAt;
  final Value<String> lastDirection;
  final Value<String> status;
  final Value<String?> errorMessage;
  final Value<int> rowid;
  const SyncStatesCompanion({
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.lastSyncHash = const Value.absent(),
    this.lastSyncAt = const Value.absent(),
    this.lastDirection = const Value.absent(),
    this.status = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncStatesCompanion.insert({
    required String entityType,
    this.entityId = const Value.absent(),
    required String lastSyncHash,
    required DateTime lastSyncAt,
    required String lastDirection,
    required String status,
    this.errorMessage = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : entityType = Value(entityType),
        lastSyncHash = Value(lastSyncHash),
        lastSyncAt = Value(lastSyncAt),
        lastDirection = Value(lastDirection),
        status = Value(status);
  static Insertable<SyncState> custom({
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<String>? lastSyncHash,
    Expression<DateTime>? lastSyncAt,
    Expression<String>? lastDirection,
    Expression<String>? status,
    Expression<String>? errorMessage,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (lastSyncHash != null) 'last_sync_hash': lastSyncHash,
      if (lastSyncAt != null) 'last_sync_at': lastSyncAt,
      if (lastDirection != null) 'last_direction': lastDirection,
      if (status != null) 'status': status,
      if (errorMessage != null) 'error_message': errorMessage,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncStatesCompanion copyWith(
      {Value<String>? entityType,
      Value<String?>? entityId,
      Value<String>? lastSyncHash,
      Value<DateTime>? lastSyncAt,
      Value<String>? lastDirection,
      Value<String>? status,
      Value<String?>? errorMessage,
      Value<int>? rowid}) {
    return SyncStatesCompanion(
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      lastSyncHash: lastSyncHash ?? this.lastSyncHash,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastDirection: lastDirection ?? this.lastDirection,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (lastSyncHash.present) {
      map['last_sync_hash'] = Variable<String>(lastSyncHash.value);
    }
    if (lastSyncAt.present) {
      map['last_sync_at'] = Variable<DateTime>(lastSyncAt.value);
    }
    if (lastDirection.present) {
      map['last_direction'] = Variable<String>(lastDirection.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStatesCompanion(')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('lastSyncHash: $lastSyncHash, ')
          ..write('lastSyncAt: $lastSyncAt, ')
          ..write('lastDirection: $lastDirection, ')
          ..write('status: $status, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PracticeRecordingsTable extends PracticeRecordings
    with TableInfo<$PracticeRecordingsTable, PracticeRecordingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PracticeRecordingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _pieceIdMeta =
      const VerificationMeta('pieceId');
  @override
  late final GeneratedColumn<String> pieceId = GeneratedColumn<String>(
      'piece_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES pieces (id)'));
  static const VerificationMeta _profileIdMeta =
      const VerificationMeta('profileId');
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
      'profile_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _scoreVersionIdMeta =
      const VerificationMeta('scoreVersionId');
  @override
  late final GeneratedColumn<String> scoreVersionId = GeneratedColumn<String>(
      'score_version_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _filePathMeta =
      const VerificationMeta('filePath');
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
      'file_path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _durationMsMeta =
      const VerificationMeta('durationMs');
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
      'duration_ms', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _isSentToTeacherMeta =
      const VerificationMeta('isSentToTeacher');
  @override
  late final GeneratedColumn<bool> isSentToTeacher = GeneratedColumn<bool>(
      'is_sent_to_teacher', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_sent_to_teacher" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        pieceId,
        profileId,
        scoreVersionId,
        filePath,
        durationMs,
        createdAt,
        isSentToTeacher
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'practice_recordings';
  @override
  VerificationContext validateIntegrity(
      Insertable<PracticeRecordingRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('piece_id')) {
      context.handle(_pieceIdMeta,
          pieceId.isAcceptableOrUnknown(data['piece_id']!, _pieceIdMeta));
    } else if (isInserting) {
      context.missing(_pieceIdMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(_profileIdMeta,
          profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta));
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('score_version_id')) {
      context.handle(
          _scoreVersionIdMeta,
          scoreVersionId.isAcceptableOrUnknown(
              data['score_version_id']!, _scoreVersionIdMeta));
    }
    if (data.containsKey('file_path')) {
      context.handle(_filePathMeta,
          filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta));
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
          _durationMsMeta,
          durationMs.isAcceptableOrUnknown(
              data['duration_ms']!, _durationMsMeta));
    } else if (isInserting) {
      context.missing(_durationMsMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('is_sent_to_teacher')) {
      context.handle(
          _isSentToTeacherMeta,
          isSentToTeacher.isAcceptableOrUnknown(
              data['is_sent_to_teacher']!, _isSentToTeacherMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PracticeRecordingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PracticeRecordingRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      pieceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}piece_id'])!,
      profileId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}profile_id'])!,
      scoreVersionId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}score_version_id']),
      filePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}file_path'])!,
      durationMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}duration_ms'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      isSentToTeacher: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}is_sent_to_teacher'])!,
    );
  }

  @override
  $PracticeRecordingsTable createAlias(String alias) {
    return $PracticeRecordingsTable(attachedDatabase, alias);
  }
}

class PracticeRecordingRow extends DataClass
    implements Insertable<PracticeRecordingRow> {
  final String id;
  final String pieceId;
  final String profileId;
  final String? scoreVersionId;
  final String filePath;
  final int durationMs;
  final DateTime createdAt;
  final bool isSentToTeacher;
  const PracticeRecordingRow(
      {required this.id,
      required this.pieceId,
      required this.profileId,
      this.scoreVersionId,
      required this.filePath,
      required this.durationMs,
      required this.createdAt,
      required this.isSentToTeacher});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['piece_id'] = Variable<String>(pieceId);
    map['profile_id'] = Variable<String>(profileId);
    if (!nullToAbsent || scoreVersionId != null) {
      map['score_version_id'] = Variable<String>(scoreVersionId);
    }
    map['file_path'] = Variable<String>(filePath);
    map['duration_ms'] = Variable<int>(durationMs);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['is_sent_to_teacher'] = Variable<bool>(isSentToTeacher);
    return map;
  }

  PracticeRecordingsCompanion toCompanion(bool nullToAbsent) {
    return PracticeRecordingsCompanion(
      id: Value(id),
      pieceId: Value(pieceId),
      profileId: Value(profileId),
      scoreVersionId: scoreVersionId == null && nullToAbsent
          ? const Value.absent()
          : Value(scoreVersionId),
      filePath: Value(filePath),
      durationMs: Value(durationMs),
      createdAt: Value(createdAt),
      isSentToTeacher: Value(isSentToTeacher),
    );
  }

  factory PracticeRecordingRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PracticeRecordingRow(
      id: serializer.fromJson<String>(json['id']),
      pieceId: serializer.fromJson<String>(json['pieceId']),
      profileId: serializer.fromJson<String>(json['profileId']),
      scoreVersionId: serializer.fromJson<String?>(json['scoreVersionId']),
      filePath: serializer.fromJson<String>(json['filePath']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      isSentToTeacher: serializer.fromJson<bool>(json['isSentToTeacher']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'pieceId': serializer.toJson<String>(pieceId),
      'profileId': serializer.toJson<String>(profileId),
      'scoreVersionId': serializer.toJson<String?>(scoreVersionId),
      'filePath': serializer.toJson<String>(filePath),
      'durationMs': serializer.toJson<int>(durationMs),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'isSentToTeacher': serializer.toJson<bool>(isSentToTeacher),
    };
  }

  PracticeRecordingRow copyWith(
          {String? id,
          String? pieceId,
          String? profileId,
          Value<String?> scoreVersionId = const Value.absent(),
          String? filePath,
          int? durationMs,
          DateTime? createdAt,
          bool? isSentToTeacher}) =>
      PracticeRecordingRow(
        id: id ?? this.id,
        pieceId: pieceId ?? this.pieceId,
        profileId: profileId ?? this.profileId,
        scoreVersionId:
            scoreVersionId.present ? scoreVersionId.value : this.scoreVersionId,
        filePath: filePath ?? this.filePath,
        durationMs: durationMs ?? this.durationMs,
        createdAt: createdAt ?? this.createdAt,
        isSentToTeacher: isSentToTeacher ?? this.isSentToTeacher,
      );
  PracticeRecordingRow copyWithCompanion(PracticeRecordingsCompanion data) {
    return PracticeRecordingRow(
      id: data.id.present ? data.id.value : this.id,
      pieceId: data.pieceId.present ? data.pieceId.value : this.pieceId,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      scoreVersionId: data.scoreVersionId.present
          ? data.scoreVersionId.value
          : this.scoreVersionId,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      durationMs:
          data.durationMs.present ? data.durationMs.value : this.durationMs,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      isSentToTeacher: data.isSentToTeacher.present
          ? data.isSentToTeacher.value
          : this.isSentToTeacher,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PracticeRecordingRow(')
          ..write('id: $id, ')
          ..write('pieceId: $pieceId, ')
          ..write('profileId: $profileId, ')
          ..write('scoreVersionId: $scoreVersionId, ')
          ..write('filePath: $filePath, ')
          ..write('durationMs: $durationMs, ')
          ..write('createdAt: $createdAt, ')
          ..write('isSentToTeacher: $isSentToTeacher')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, pieceId, profileId, scoreVersionId,
      filePath, durationMs, createdAt, isSentToTeacher);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PracticeRecordingRow &&
          other.id == this.id &&
          other.pieceId == this.pieceId &&
          other.profileId == this.profileId &&
          other.scoreVersionId == this.scoreVersionId &&
          other.filePath == this.filePath &&
          other.durationMs == this.durationMs &&
          other.createdAt == this.createdAt &&
          other.isSentToTeacher == this.isSentToTeacher);
}

class PracticeRecordingsCompanion
    extends UpdateCompanion<PracticeRecordingRow> {
  final Value<String> id;
  final Value<String> pieceId;
  final Value<String> profileId;
  final Value<String?> scoreVersionId;
  final Value<String> filePath;
  final Value<int> durationMs;
  final Value<DateTime> createdAt;
  final Value<bool> isSentToTeacher;
  final Value<int> rowid;
  const PracticeRecordingsCompanion({
    this.id = const Value.absent(),
    this.pieceId = const Value.absent(),
    this.profileId = const Value.absent(),
    this.scoreVersionId = const Value.absent(),
    this.filePath = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.isSentToTeacher = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PracticeRecordingsCompanion.insert({
    required String id,
    required String pieceId,
    required String profileId,
    this.scoreVersionId = const Value.absent(),
    required String filePath,
    required int durationMs,
    required DateTime createdAt,
    this.isSentToTeacher = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        pieceId = Value(pieceId),
        profileId = Value(profileId),
        filePath = Value(filePath),
        durationMs = Value(durationMs),
        createdAt = Value(createdAt);
  static Insertable<PracticeRecordingRow> custom({
    Expression<String>? id,
    Expression<String>? pieceId,
    Expression<String>? profileId,
    Expression<String>? scoreVersionId,
    Expression<String>? filePath,
    Expression<int>? durationMs,
    Expression<DateTime>? createdAt,
    Expression<bool>? isSentToTeacher,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (pieceId != null) 'piece_id': pieceId,
      if (profileId != null) 'profile_id': profileId,
      if (scoreVersionId != null) 'score_version_id': scoreVersionId,
      if (filePath != null) 'file_path': filePath,
      if (durationMs != null) 'duration_ms': durationMs,
      if (createdAt != null) 'created_at': createdAt,
      if (isSentToTeacher != null) 'is_sent_to_teacher': isSentToTeacher,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PracticeRecordingsCompanion copyWith(
      {Value<String>? id,
      Value<String>? pieceId,
      Value<String>? profileId,
      Value<String?>? scoreVersionId,
      Value<String>? filePath,
      Value<int>? durationMs,
      Value<DateTime>? createdAt,
      Value<bool>? isSentToTeacher,
      Value<int>? rowid}) {
    return PracticeRecordingsCompanion(
      id: id ?? this.id,
      pieceId: pieceId ?? this.pieceId,
      profileId: profileId ?? this.profileId,
      scoreVersionId: scoreVersionId ?? this.scoreVersionId,
      filePath: filePath ?? this.filePath,
      durationMs: durationMs ?? this.durationMs,
      createdAt: createdAt ?? this.createdAt,
      isSentToTeacher: isSentToTeacher ?? this.isSentToTeacher,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (pieceId.present) {
      map['piece_id'] = Variable<String>(pieceId.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (scoreVersionId.present) {
      map['score_version_id'] = Variable<String>(scoreVersionId.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (isSentToTeacher.present) {
      map['is_sent_to_teacher'] = Variable<bool>(isSentToTeacher.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PracticeRecordingsCompanion(')
          ..write('id: $id, ')
          ..write('pieceId: $pieceId, ')
          ..write('profileId: $profileId, ')
          ..write('scoreVersionId: $scoreVersionId, ')
          ..write('filePath: $filePath, ')
          ..write('durationMs: $durationMs, ')
          ..write('createdAt: $createdAt, ')
          ..write('isSentToTeacher: $isSentToTeacher, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ProfilesTable profiles = $ProfilesTable(this);
  late final $PiecesTable pieces = $PiecesTable(this);
  late final $ScoreVersionsTable scoreVersions = $ScoreVersionsTable(this);
  late final $AnnotationLayersTable annotationLayers =
      $AnnotationLayersTable(this);
  late final $AnnotationStrokesTable annotationStrokes =
      $AnnotationStrokesTable(this);
  late final $AnnotationNotesTable annotationNotes =
      $AnnotationNotesTable(this);
  late final $MediaAssetsTable mediaAssets = $MediaAssetsTable(this);
  late final $MediaMatchCandidatesTable mediaMatchCandidates =
      $MediaMatchCandidatesTable(this);
  late final $ProcessingJobsTable processingJobs = $ProcessingJobsTable(this);
  late final $ReviewItemsTable reviewItems = $ReviewItemsTable(this);
  late final $PieceHistoryDraftsTable pieceHistoryDrafts =
      $PieceHistoryDraftsTable(this);
  late final $SyncStatesTable syncStates = $SyncStatesTable(this);
  late final $PracticeRecordingsTable practiceRecordings =
      $PracticeRecordingsTable(this);
  late final AppDatabaseDao appDatabaseDao =
      AppDatabaseDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        profiles,
        pieces,
        scoreVersions,
        annotationLayers,
        annotationStrokes,
        annotationNotes,
        mediaAssets,
        mediaMatchCandidates,
        processingJobs,
        reviewItems,
        pieceHistoryDrafts,
        syncStates,
        practiceRecordings
      ];
}

typedef $$ProfilesTableCreateCompanionBuilder = ProfilesCompanion Function({
  required String id,
  required String displayName,
  required String role,
  required bool parentPinRequired,
  required bool isDefaultOnDevice,
  Value<String?> localPin,
  Value<String?> email,
  Value<String?> avatarUrl,
  required String instrument,
  Value<int?> gradeLevel,
  Value<String?> subtitle,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$ProfilesTableUpdateCompanionBuilder = ProfilesCompanion Function({
  Value<String> id,
  Value<String> displayName,
  Value<String> role,
  Value<bool> parentPinRequired,
  Value<bool> isDefaultOnDevice,
  Value<String?> localPin,
  Value<String?> email,
  Value<String?> avatarUrl,
  Value<String> instrument,
  Value<int?> gradeLevel,
  Value<String?> subtitle,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$ProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get role => $composableBuilder(
      column: $table.role, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get parentPinRequired => $composableBuilder(
      column: $table.parentPinRequired,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isDefaultOnDevice => $composableBuilder(
      column: $table.isDefaultOnDevice,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get localPin => $composableBuilder(
      column: $table.localPin, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get avatarUrl => $composableBuilder(
      column: $table.avatarUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get instrument => $composableBuilder(
      column: $table.instrument, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get gradeLevel => $composableBuilder(
      column: $table.gradeLevel, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get subtitle => $composableBuilder(
      column: $table.subtitle, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$ProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get role => $composableBuilder(
      column: $table.role, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get parentPinRequired => $composableBuilder(
      column: $table.parentPinRequired,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isDefaultOnDevice => $composableBuilder(
      column: $table.isDefaultOnDevice,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get localPin => $composableBuilder(
      column: $table.localPin, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get avatarUrl => $composableBuilder(
      column: $table.avatarUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get instrument => $composableBuilder(
      column: $table.instrument, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get gradeLevel => $composableBuilder(
      column: $table.gradeLevel, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get subtitle => $composableBuilder(
      column: $table.subtitle, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$ProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<bool> get parentPinRequired => $composableBuilder(
      column: $table.parentPinRequired, builder: (column) => column);

  GeneratedColumn<bool> get isDefaultOnDevice => $composableBuilder(
      column: $table.isDefaultOnDevice, builder: (column) => column);

  GeneratedColumn<String> get localPin =>
      $composableBuilder(column: $table.localPin, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get avatarUrl =>
      $composableBuilder(column: $table.avatarUrl, builder: (column) => column);

  GeneratedColumn<String> get instrument => $composableBuilder(
      column: $table.instrument, builder: (column) => column);

  GeneratedColumn<int> get gradeLevel => $composableBuilder(
      column: $table.gradeLevel, builder: (column) => column);

  GeneratedColumn<String> get subtitle =>
      $composableBuilder(column: $table.subtitle, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ProfilesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ProfilesTable,
    ProfileRow,
    $$ProfilesTableFilterComposer,
    $$ProfilesTableOrderingComposer,
    $$ProfilesTableAnnotationComposer,
    $$ProfilesTableCreateCompanionBuilder,
    $$ProfilesTableUpdateCompanionBuilder,
    (ProfileRow, BaseReferences<_$AppDatabase, $ProfilesTable, ProfileRow>),
    ProfileRow,
    PrefetchHooks Function()> {
  $$ProfilesTableTableManager(_$AppDatabase db, $ProfilesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> displayName = const Value.absent(),
            Value<String> role = const Value.absent(),
            Value<bool> parentPinRequired = const Value.absent(),
            Value<bool> isDefaultOnDevice = const Value.absent(),
            Value<String?> localPin = const Value.absent(),
            Value<String?> email = const Value.absent(),
            Value<String?> avatarUrl = const Value.absent(),
            Value<String> instrument = const Value.absent(),
            Value<int?> gradeLevel = const Value.absent(),
            Value<String?> subtitle = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ProfilesCompanion(
            id: id,
            displayName: displayName,
            role: role,
            parentPinRequired: parentPinRequired,
            isDefaultOnDevice: isDefaultOnDevice,
            localPin: localPin,
            email: email,
            avatarUrl: avatarUrl,
            instrument: instrument,
            gradeLevel: gradeLevel,
            subtitle: subtitle,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String displayName,
            required String role,
            required bool parentPinRequired,
            required bool isDefaultOnDevice,
            Value<String?> localPin = const Value.absent(),
            Value<String?> email = const Value.absent(),
            Value<String?> avatarUrl = const Value.absent(),
            required String instrument,
            Value<int?> gradeLevel = const Value.absent(),
            Value<String?> subtitle = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              ProfilesCompanion.insert(
            id: id,
            displayName: displayName,
            role: role,
            parentPinRequired: parentPinRequired,
            isDefaultOnDevice: isDefaultOnDevice,
            localPin: localPin,
            email: email,
            avatarUrl: avatarUrl,
            instrument: instrument,
            gradeLevel: gradeLevel,
            subtitle: subtitle,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ProfilesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ProfilesTable,
    ProfileRow,
    $$ProfilesTableFilterComposer,
    $$ProfilesTableOrderingComposer,
    $$ProfilesTableAnnotationComposer,
    $$ProfilesTableCreateCompanionBuilder,
    $$ProfilesTableUpdateCompanionBuilder,
    (ProfileRow, BaseReferences<_$AppDatabase, $ProfilesTable, ProfileRow>),
    ProfileRow,
    PrefetchHooks Function()>;
typedef $$PiecesTableCreateCompanionBuilder = PiecesCompanion Function({
  required String id,
  required String title,
  Value<String?> composer,
  Value<String?> serverPieceId,
  Value<String?> assignedProfileId,
  required String visibleToProfileIds,
  Value<String?> previousVisibleToProfileIds,
  Value<String?> primaryInstrument,
  Value<String?> bookOrCollection,
  required String libraryStatus,
  required String normalizedTitle,
  Value<String?> normalizedComposer,
  required String sortTitle,
  Value<String?> sortComposer,
  Value<String?> opus,
  Value<String?> movement,
  Value<String?> keySignature,
  Value<String?> tempo,
  Value<String?> difficulty,
  Value<String?> genre,
  Value<String?> notes,
  Value<String?> processedMetadata,
  Value<String> pieceKind,
  Value<String?> sourceBookId,
  Value<int?> sourcePageStart,
  Value<int?> sourcePageEnd,
  Value<String?> catalogMetadata,
  Value<String?> catalogSuggestions,
  Value<String?> validationWarnings,
  Value<double?> splitConfidence,
  Value<String?> sourceContentSha256,
  Value<bool> workflowClosed,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$PiecesTableUpdateCompanionBuilder = PiecesCompanion Function({
  Value<String> id,
  Value<String> title,
  Value<String?> composer,
  Value<String?> serverPieceId,
  Value<String?> assignedProfileId,
  Value<String> visibleToProfileIds,
  Value<String?> previousVisibleToProfileIds,
  Value<String?> primaryInstrument,
  Value<String?> bookOrCollection,
  Value<String> libraryStatus,
  Value<String> normalizedTitle,
  Value<String?> normalizedComposer,
  Value<String> sortTitle,
  Value<String?> sortComposer,
  Value<String?> opus,
  Value<String?> movement,
  Value<String?> keySignature,
  Value<String?> tempo,
  Value<String?> difficulty,
  Value<String?> genre,
  Value<String?> notes,
  Value<String?> processedMetadata,
  Value<String> pieceKind,
  Value<String?> sourceBookId,
  Value<int?> sourcePageStart,
  Value<int?> sourcePageEnd,
  Value<String?> catalogMetadata,
  Value<String?> catalogSuggestions,
  Value<String?> validationWarnings,
  Value<double?> splitConfidence,
  Value<String?> sourceContentSha256,
  Value<bool> workflowClosed,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

final class $$PiecesTableReferences
    extends BaseReferences<_$AppDatabase, $PiecesTable, PieceRow> {
  $$PiecesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ScoreVersionsTable, List<ScoreVersionRow>>
      _scoreVersionsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.scoreVersions,
              aliasName:
                  $_aliasNameGenerator(db.pieces.id, db.scoreVersions.pieceId));

  $$ScoreVersionsTableProcessedTableManager get scoreVersionsRefs {
    final manager = $$ScoreVersionsTableTableManager($_db, $_db.scoreVersions)
        .filter((f) => f.pieceId.id($_item.id));

    final cache = $_typedResult.readTableOrNull(_scoreVersionsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$MediaAssetsTable, List<MediaAsset>>
      _mediaAssetsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.mediaAssets,
              aliasName:
                  $_aliasNameGenerator(db.pieces.id, db.mediaAssets.pieceId));

  $$MediaAssetsTableProcessedTableManager get mediaAssetsRefs {
    final manager = $$MediaAssetsTableTableManager($_db, $_db.mediaAssets)
        .filter((f) => f.pieceId.id($_item.id));

    final cache = $_typedResult.readTableOrNull(_mediaAssetsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$MediaMatchCandidatesTable,
      List<MediaMatchCandidate>> _mediaMatchCandidatesRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.mediaMatchCandidates,
          aliasName: $_aliasNameGenerator(
              db.pieces.id, db.mediaMatchCandidates.pieceId));

  $$MediaMatchCandidatesTableProcessedTableManager
      get mediaMatchCandidatesRefs {
    final manager =
        $$MediaMatchCandidatesTableTableManager($_db, $_db.mediaMatchCandidates)
            .filter((f) => f.pieceId.id($_item.id));

    final cache =
        $_typedResult.readTableOrNull(_mediaMatchCandidatesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$ProcessingJobsTable, List<ProcessingJob>>
      _processingJobsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.processingJobs,
              aliasName: $_aliasNameGenerator(
                  db.pieces.id, db.processingJobs.pieceId));

  $$ProcessingJobsTableProcessedTableManager get processingJobsRefs {
    final manager = $$ProcessingJobsTableTableManager($_db, $_db.processingJobs)
        .filter((f) => f.pieceId.id($_item.id));

    final cache = $_typedResult.readTableOrNull(_processingJobsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$ReviewItemsTable, List<ReviewItem>>
      _reviewItemsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.reviewItems,
              aliasName:
                  $_aliasNameGenerator(db.pieces.id, db.reviewItems.pieceId));

  $$ReviewItemsTableProcessedTableManager get reviewItemsRefs {
    final manager = $$ReviewItemsTableTableManager($_db, $_db.reviewItems)
        .filter((f) => f.pieceId.id($_item.id));

    final cache = $_typedResult.readTableOrNull(_reviewItemsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$PieceHistoryDraftsTable, List<PieceHistoryDraft>>
      _pieceHistoryDraftsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.pieceHistoryDrafts,
              aliasName: $_aliasNameGenerator(
                  db.pieces.id, db.pieceHistoryDrafts.pieceId));

  $$PieceHistoryDraftsTableProcessedTableManager get pieceHistoryDraftsRefs {
    final manager =
        $$PieceHistoryDraftsTableTableManager($_db, $_db.pieceHistoryDrafts)
            .filter((f) => f.pieceId.id($_item.id));

    final cache =
        $_typedResult.readTableOrNull(_pieceHistoryDraftsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$PracticeRecordingsTable,
      List<PracticeRecordingRow>> _practiceRecordingsRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.practiceRecordings,
          aliasName: $_aliasNameGenerator(
              db.pieces.id, db.practiceRecordings.pieceId));

  $$PracticeRecordingsTableProcessedTableManager get practiceRecordingsRefs {
    final manager =
        $$PracticeRecordingsTableTableManager($_db, $_db.practiceRecordings)
            .filter((f) => f.pieceId.id($_item.id));

    final cache =
        $_typedResult.readTableOrNull(_practiceRecordingsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$PiecesTableFilterComposer
    extends Composer<_$AppDatabase, $PiecesTable> {
  $$PiecesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get composer => $composableBuilder(
      column: $table.composer, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get serverPieceId => $composableBuilder(
      column: $table.serverPieceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get assignedProfileId => $composableBuilder(
      column: $table.assignedProfileId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get visibleToProfileIds => $composableBuilder(
      column: $table.visibleToProfileIds,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get previousVisibleToProfileIds => $composableBuilder(
      column: $table.previousVisibleToProfileIds,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get primaryInstrument => $composableBuilder(
      column: $table.primaryInstrument,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bookOrCollection => $composableBuilder(
      column: $table.bookOrCollection,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get libraryStatus => $composableBuilder(
      column: $table.libraryStatus, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get normalizedTitle => $composableBuilder(
      column: $table.normalizedTitle,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get normalizedComposer => $composableBuilder(
      column: $table.normalizedComposer,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sortTitle => $composableBuilder(
      column: $table.sortTitle, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sortComposer => $composableBuilder(
      column: $table.sortComposer, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get opus => $composableBuilder(
      column: $table.opus, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get movement => $composableBuilder(
      column: $table.movement, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get keySignature => $composableBuilder(
      column: $table.keySignature, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tempo => $composableBuilder(
      column: $table.tempo, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get difficulty => $composableBuilder(
      column: $table.difficulty, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get genre => $composableBuilder(
      column: $table.genre, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get processedMetadata => $composableBuilder(
      column: $table.processedMetadata,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get pieceKind => $composableBuilder(
      column: $table.pieceKind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sourceBookId => $composableBuilder(
      column: $table.sourceBookId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sourcePageStart => $composableBuilder(
      column: $table.sourcePageStart,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sourcePageEnd => $composableBuilder(
      column: $table.sourcePageEnd, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get catalogMetadata => $composableBuilder(
      column: $table.catalogMetadata,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get catalogSuggestions => $composableBuilder(
      column: $table.catalogSuggestions,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get validationWarnings => $composableBuilder(
      column: $table.validationWarnings,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get splitConfidence => $composableBuilder(
      column: $table.splitConfidence,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sourceContentSha256 => $composableBuilder(
      column: $table.sourceContentSha256,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get workflowClosed => $composableBuilder(
      column: $table.workflowClosed,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  Expression<bool> scoreVersionsRefs(
      Expression<bool> Function($$ScoreVersionsTableFilterComposer f) f) {
    final $$ScoreVersionsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.scoreVersions,
        getReferencedColumn: (t) => t.pieceId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ScoreVersionsTableFilterComposer(
              $db: $db,
              $table: $db.scoreVersions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> mediaAssetsRefs(
      Expression<bool> Function($$MediaAssetsTableFilterComposer f) f) {
    final $$MediaAssetsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.mediaAssets,
        getReferencedColumn: (t) => t.pieceId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MediaAssetsTableFilterComposer(
              $db: $db,
              $table: $db.mediaAssets,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> mediaMatchCandidatesRefs(
      Expression<bool> Function($$MediaMatchCandidatesTableFilterComposer f)
          f) {
    final $$MediaMatchCandidatesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.mediaMatchCandidates,
        getReferencedColumn: (t) => t.pieceId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MediaMatchCandidatesTableFilterComposer(
              $db: $db,
              $table: $db.mediaMatchCandidates,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> processingJobsRefs(
      Expression<bool> Function($$ProcessingJobsTableFilterComposer f) f) {
    final $$ProcessingJobsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.processingJobs,
        getReferencedColumn: (t) => t.pieceId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProcessingJobsTableFilterComposer(
              $db: $db,
              $table: $db.processingJobs,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> reviewItemsRefs(
      Expression<bool> Function($$ReviewItemsTableFilterComposer f) f) {
    final $$ReviewItemsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.reviewItems,
        getReferencedColumn: (t) => t.pieceId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ReviewItemsTableFilterComposer(
              $db: $db,
              $table: $db.reviewItems,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> pieceHistoryDraftsRefs(
      Expression<bool> Function($$PieceHistoryDraftsTableFilterComposer f) f) {
    final $$PieceHistoryDraftsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.pieceHistoryDrafts,
        getReferencedColumn: (t) => t.pieceId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PieceHistoryDraftsTableFilterComposer(
              $db: $db,
              $table: $db.pieceHistoryDrafts,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> practiceRecordingsRefs(
      Expression<bool> Function($$PracticeRecordingsTableFilterComposer f) f) {
    final $$PracticeRecordingsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.practiceRecordings,
        getReferencedColumn: (t) => t.pieceId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PracticeRecordingsTableFilterComposer(
              $db: $db,
              $table: $db.practiceRecordings,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$PiecesTableOrderingComposer
    extends Composer<_$AppDatabase, $PiecesTable> {
  $$PiecesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get composer => $composableBuilder(
      column: $table.composer, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get serverPieceId => $composableBuilder(
      column: $table.serverPieceId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get assignedProfileId => $composableBuilder(
      column: $table.assignedProfileId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get visibleToProfileIds => $composableBuilder(
      column: $table.visibleToProfileIds,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get previousVisibleToProfileIds => $composableBuilder(
      column: $table.previousVisibleToProfileIds,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get primaryInstrument => $composableBuilder(
      column: $table.primaryInstrument,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bookOrCollection => $composableBuilder(
      column: $table.bookOrCollection,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get libraryStatus => $composableBuilder(
      column: $table.libraryStatus,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get normalizedTitle => $composableBuilder(
      column: $table.normalizedTitle,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get normalizedComposer => $composableBuilder(
      column: $table.normalizedComposer,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sortTitle => $composableBuilder(
      column: $table.sortTitle, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sortComposer => $composableBuilder(
      column: $table.sortComposer,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get opus => $composableBuilder(
      column: $table.opus, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get movement => $composableBuilder(
      column: $table.movement, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get keySignature => $composableBuilder(
      column: $table.keySignature,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tempo => $composableBuilder(
      column: $table.tempo, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get difficulty => $composableBuilder(
      column: $table.difficulty, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get genre => $composableBuilder(
      column: $table.genre, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get processedMetadata => $composableBuilder(
      column: $table.processedMetadata,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get pieceKind => $composableBuilder(
      column: $table.pieceKind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sourceBookId => $composableBuilder(
      column: $table.sourceBookId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sourcePageStart => $composableBuilder(
      column: $table.sourcePageStart,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sourcePageEnd => $composableBuilder(
      column: $table.sourcePageEnd,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get catalogMetadata => $composableBuilder(
      column: $table.catalogMetadata,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get catalogSuggestions => $composableBuilder(
      column: $table.catalogSuggestions,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get validationWarnings => $composableBuilder(
      column: $table.validationWarnings,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get splitConfidence => $composableBuilder(
      column: $table.splitConfidence,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sourceContentSha256 => $composableBuilder(
      column: $table.sourceContentSha256,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get workflowClosed => $composableBuilder(
      column: $table.workflowClosed,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$PiecesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PiecesTable> {
  $$PiecesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get composer =>
      $composableBuilder(column: $table.composer, builder: (column) => column);

  GeneratedColumn<String> get serverPieceId => $composableBuilder(
      column: $table.serverPieceId, builder: (column) => column);

  GeneratedColumn<String> get assignedProfileId => $composableBuilder(
      column: $table.assignedProfileId, builder: (column) => column);

  GeneratedColumn<String> get visibleToProfileIds => $composableBuilder(
      column: $table.visibleToProfileIds, builder: (column) => column);

  GeneratedColumn<String> get previousVisibleToProfileIds => $composableBuilder(
      column: $table.previousVisibleToProfileIds, builder: (column) => column);

  GeneratedColumn<String> get primaryInstrument => $composableBuilder(
      column: $table.primaryInstrument, builder: (column) => column);

  GeneratedColumn<String> get bookOrCollection => $composableBuilder(
      column: $table.bookOrCollection, builder: (column) => column);

  GeneratedColumn<String> get libraryStatus => $composableBuilder(
      column: $table.libraryStatus, builder: (column) => column);

  GeneratedColumn<String> get normalizedTitle => $composableBuilder(
      column: $table.normalizedTitle, builder: (column) => column);

  GeneratedColumn<String> get normalizedComposer => $composableBuilder(
      column: $table.normalizedComposer, builder: (column) => column);

  GeneratedColumn<String> get sortTitle =>
      $composableBuilder(column: $table.sortTitle, builder: (column) => column);

  GeneratedColumn<String> get sortComposer => $composableBuilder(
      column: $table.sortComposer, builder: (column) => column);

  GeneratedColumn<String> get opus =>
      $composableBuilder(column: $table.opus, builder: (column) => column);

  GeneratedColumn<String> get movement =>
      $composableBuilder(column: $table.movement, builder: (column) => column);

  GeneratedColumn<String> get keySignature => $composableBuilder(
      column: $table.keySignature, builder: (column) => column);

  GeneratedColumn<String> get tempo =>
      $composableBuilder(column: $table.tempo, builder: (column) => column);

  GeneratedColumn<String> get difficulty => $composableBuilder(
      column: $table.difficulty, builder: (column) => column);

  GeneratedColumn<String> get genre =>
      $composableBuilder(column: $table.genre, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get processedMetadata => $composableBuilder(
      column: $table.processedMetadata, builder: (column) => column);

  GeneratedColumn<String> get pieceKind =>
      $composableBuilder(column: $table.pieceKind, builder: (column) => column);

  GeneratedColumn<String> get sourceBookId => $composableBuilder(
      column: $table.sourceBookId, builder: (column) => column);

  GeneratedColumn<int> get sourcePageStart => $composableBuilder(
      column: $table.sourcePageStart, builder: (column) => column);

  GeneratedColumn<int> get sourcePageEnd => $composableBuilder(
      column: $table.sourcePageEnd, builder: (column) => column);

  GeneratedColumn<String> get catalogMetadata => $composableBuilder(
      column: $table.catalogMetadata, builder: (column) => column);

  GeneratedColumn<String> get catalogSuggestions => $composableBuilder(
      column: $table.catalogSuggestions, builder: (column) => column);

  GeneratedColumn<String> get validationWarnings => $composableBuilder(
      column: $table.validationWarnings, builder: (column) => column);

  GeneratedColumn<double> get splitConfidence => $composableBuilder(
      column: $table.splitConfidence, builder: (column) => column);

  GeneratedColumn<String> get sourceContentSha256 => $composableBuilder(
      column: $table.sourceContentSha256, builder: (column) => column);

  GeneratedColumn<bool> get workflowClosed => $composableBuilder(
      column: $table.workflowClosed, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> scoreVersionsRefs<T extends Object>(
      Expression<T> Function($$ScoreVersionsTableAnnotationComposer a) f) {
    final $$ScoreVersionsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.scoreVersions,
        getReferencedColumn: (t) => t.pieceId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ScoreVersionsTableAnnotationComposer(
              $db: $db,
              $table: $db.scoreVersions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> mediaAssetsRefs<T extends Object>(
      Expression<T> Function($$MediaAssetsTableAnnotationComposer a) f) {
    final $$MediaAssetsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.mediaAssets,
        getReferencedColumn: (t) => t.pieceId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MediaAssetsTableAnnotationComposer(
              $db: $db,
              $table: $db.mediaAssets,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> mediaMatchCandidatesRefs<T extends Object>(
      Expression<T> Function($$MediaMatchCandidatesTableAnnotationComposer a)
          f) {
    final $$MediaMatchCandidatesTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.mediaMatchCandidates,
            getReferencedColumn: (t) => t.pieceId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$MediaMatchCandidatesTableAnnotationComposer(
                  $db: $db,
                  $table: $db.mediaMatchCandidates,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }

  Expression<T> processingJobsRefs<T extends Object>(
      Expression<T> Function($$ProcessingJobsTableAnnotationComposer a) f) {
    final $$ProcessingJobsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.processingJobs,
        getReferencedColumn: (t) => t.pieceId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProcessingJobsTableAnnotationComposer(
              $db: $db,
              $table: $db.processingJobs,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> reviewItemsRefs<T extends Object>(
      Expression<T> Function($$ReviewItemsTableAnnotationComposer a) f) {
    final $$ReviewItemsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.reviewItems,
        getReferencedColumn: (t) => t.pieceId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ReviewItemsTableAnnotationComposer(
              $db: $db,
              $table: $db.reviewItems,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> pieceHistoryDraftsRefs<T extends Object>(
      Expression<T> Function($$PieceHistoryDraftsTableAnnotationComposer a) f) {
    final $$PieceHistoryDraftsTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.pieceHistoryDrafts,
            getReferencedColumn: (t) => t.pieceId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$PieceHistoryDraftsTableAnnotationComposer(
                  $db: $db,
                  $table: $db.pieceHistoryDrafts,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }

  Expression<T> practiceRecordingsRefs<T extends Object>(
      Expression<T> Function($$PracticeRecordingsTableAnnotationComposer a) f) {
    final $$PracticeRecordingsTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.practiceRecordings,
            getReferencedColumn: (t) => t.pieceId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$PracticeRecordingsTableAnnotationComposer(
                  $db: $db,
                  $table: $db.practiceRecordings,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }
}

class $$PiecesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PiecesTable,
    PieceRow,
    $$PiecesTableFilterComposer,
    $$PiecesTableOrderingComposer,
    $$PiecesTableAnnotationComposer,
    $$PiecesTableCreateCompanionBuilder,
    $$PiecesTableUpdateCompanionBuilder,
    (PieceRow, $$PiecesTableReferences),
    PieceRow,
    PrefetchHooks Function(
        {bool scoreVersionsRefs,
        bool mediaAssetsRefs,
        bool mediaMatchCandidatesRefs,
        bool processingJobsRefs,
        bool reviewItemsRefs,
        bool pieceHistoryDraftsRefs,
        bool practiceRecordingsRefs})> {
  $$PiecesTableTableManager(_$AppDatabase db, $PiecesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PiecesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PiecesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PiecesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String?> composer = const Value.absent(),
            Value<String?> serverPieceId = const Value.absent(),
            Value<String?> assignedProfileId = const Value.absent(),
            Value<String> visibleToProfileIds = const Value.absent(),
            Value<String?> previousVisibleToProfileIds = const Value.absent(),
            Value<String?> primaryInstrument = const Value.absent(),
            Value<String?> bookOrCollection = const Value.absent(),
            Value<String> libraryStatus = const Value.absent(),
            Value<String> normalizedTitle = const Value.absent(),
            Value<String?> normalizedComposer = const Value.absent(),
            Value<String> sortTitle = const Value.absent(),
            Value<String?> sortComposer = const Value.absent(),
            Value<String?> opus = const Value.absent(),
            Value<String?> movement = const Value.absent(),
            Value<String?> keySignature = const Value.absent(),
            Value<String?> tempo = const Value.absent(),
            Value<String?> difficulty = const Value.absent(),
            Value<String?> genre = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<String?> processedMetadata = const Value.absent(),
            Value<String> pieceKind = const Value.absent(),
            Value<String?> sourceBookId = const Value.absent(),
            Value<int?> sourcePageStart = const Value.absent(),
            Value<int?> sourcePageEnd = const Value.absent(),
            Value<String?> catalogMetadata = const Value.absent(),
            Value<String?> catalogSuggestions = const Value.absent(),
            Value<String?> validationWarnings = const Value.absent(),
            Value<double?> splitConfidence = const Value.absent(),
            Value<String?> sourceContentSha256 = const Value.absent(),
            Value<bool> workflowClosed = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PiecesCompanion(
            id: id,
            title: title,
            composer: composer,
            serverPieceId: serverPieceId,
            assignedProfileId: assignedProfileId,
            visibleToProfileIds: visibleToProfileIds,
            previousVisibleToProfileIds: previousVisibleToProfileIds,
            primaryInstrument: primaryInstrument,
            bookOrCollection: bookOrCollection,
            libraryStatus: libraryStatus,
            normalizedTitle: normalizedTitle,
            normalizedComposer: normalizedComposer,
            sortTitle: sortTitle,
            sortComposer: sortComposer,
            opus: opus,
            movement: movement,
            keySignature: keySignature,
            tempo: tempo,
            difficulty: difficulty,
            genre: genre,
            notes: notes,
            processedMetadata: processedMetadata,
            pieceKind: pieceKind,
            sourceBookId: sourceBookId,
            sourcePageStart: sourcePageStart,
            sourcePageEnd: sourcePageEnd,
            catalogMetadata: catalogMetadata,
            catalogSuggestions: catalogSuggestions,
            validationWarnings: validationWarnings,
            splitConfidence: splitConfidence,
            sourceContentSha256: sourceContentSha256,
            workflowClosed: workflowClosed,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String title,
            Value<String?> composer = const Value.absent(),
            Value<String?> serverPieceId = const Value.absent(),
            Value<String?> assignedProfileId = const Value.absent(),
            required String visibleToProfileIds,
            Value<String?> previousVisibleToProfileIds = const Value.absent(),
            Value<String?> primaryInstrument = const Value.absent(),
            Value<String?> bookOrCollection = const Value.absent(),
            required String libraryStatus,
            required String normalizedTitle,
            Value<String?> normalizedComposer = const Value.absent(),
            required String sortTitle,
            Value<String?> sortComposer = const Value.absent(),
            Value<String?> opus = const Value.absent(),
            Value<String?> movement = const Value.absent(),
            Value<String?> keySignature = const Value.absent(),
            Value<String?> tempo = const Value.absent(),
            Value<String?> difficulty = const Value.absent(),
            Value<String?> genre = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<String?> processedMetadata = const Value.absent(),
            Value<String> pieceKind = const Value.absent(),
            Value<String?> sourceBookId = const Value.absent(),
            Value<int?> sourcePageStart = const Value.absent(),
            Value<int?> sourcePageEnd = const Value.absent(),
            Value<String?> catalogMetadata = const Value.absent(),
            Value<String?> catalogSuggestions = const Value.absent(),
            Value<String?> validationWarnings = const Value.absent(),
            Value<double?> splitConfidence = const Value.absent(),
            Value<String?> sourceContentSha256 = const Value.absent(),
            Value<bool> workflowClosed = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              PiecesCompanion.insert(
            id: id,
            title: title,
            composer: composer,
            serverPieceId: serverPieceId,
            assignedProfileId: assignedProfileId,
            visibleToProfileIds: visibleToProfileIds,
            previousVisibleToProfileIds: previousVisibleToProfileIds,
            primaryInstrument: primaryInstrument,
            bookOrCollection: bookOrCollection,
            libraryStatus: libraryStatus,
            normalizedTitle: normalizedTitle,
            normalizedComposer: normalizedComposer,
            sortTitle: sortTitle,
            sortComposer: sortComposer,
            opus: opus,
            movement: movement,
            keySignature: keySignature,
            tempo: tempo,
            difficulty: difficulty,
            genre: genre,
            notes: notes,
            processedMetadata: processedMetadata,
            pieceKind: pieceKind,
            sourceBookId: sourceBookId,
            sourcePageStart: sourcePageStart,
            sourcePageEnd: sourcePageEnd,
            catalogMetadata: catalogMetadata,
            catalogSuggestions: catalogSuggestions,
            validationWarnings: validationWarnings,
            splitConfidence: splitConfidence,
            sourceContentSha256: sourceContentSha256,
            workflowClosed: workflowClosed,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$PiecesTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: (
              {scoreVersionsRefs = false,
              mediaAssetsRefs = false,
              mediaMatchCandidatesRefs = false,
              processingJobsRefs = false,
              reviewItemsRefs = false,
              pieceHistoryDraftsRefs = false,
              practiceRecordingsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (scoreVersionsRefs) db.scoreVersions,
                if (mediaAssetsRefs) db.mediaAssets,
                if (mediaMatchCandidatesRefs) db.mediaMatchCandidates,
                if (processingJobsRefs) db.processingJobs,
                if (reviewItemsRefs) db.reviewItems,
                if (pieceHistoryDraftsRefs) db.pieceHistoryDrafts,
                if (practiceRecordingsRefs) db.practiceRecordings
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (scoreVersionsRefs)
                    await $_getPrefetchedData(
                        currentTable: table,
                        referencedTable:
                            $$PiecesTableReferences._scoreVersionsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$PiecesTableReferences(db, table, p0)
                                .scoreVersionsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.pieceId == item.id),
                        typedResults: items),
                  if (mediaAssetsRefs)
                    await $_getPrefetchedData(
                        currentTable: table,
                        referencedTable:
                            $$PiecesTableReferences._mediaAssetsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$PiecesTableReferences(db, table, p0)
                                .mediaAssetsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.pieceId == item.id),
                        typedResults: items),
                  if (mediaMatchCandidatesRefs)
                    await $_getPrefetchedData(
                        currentTable: table,
                        referencedTable: $$PiecesTableReferences
                            ._mediaMatchCandidatesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$PiecesTableReferences(db, table, p0)
                                .mediaMatchCandidatesRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.pieceId == item.id),
                        typedResults: items),
                  if (processingJobsRefs)
                    await $_getPrefetchedData(
                        currentTable: table,
                        referencedTable: $$PiecesTableReferences
                            ._processingJobsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$PiecesTableReferences(db, table, p0)
                                .processingJobsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.pieceId == item.id),
                        typedResults: items),
                  if (reviewItemsRefs)
                    await $_getPrefetchedData(
                        currentTable: table,
                        referencedTable:
                            $$PiecesTableReferences._reviewItemsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$PiecesTableReferences(db, table, p0)
                                .reviewItemsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.pieceId == item.id),
                        typedResults: items),
                  if (pieceHistoryDraftsRefs)
                    await $_getPrefetchedData(
                        currentTable: table,
                        referencedTable: $$PiecesTableReferences
                            ._pieceHistoryDraftsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$PiecesTableReferences(db, table, p0)
                                .pieceHistoryDraftsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.pieceId == item.id),
                        typedResults: items),
                  if (practiceRecordingsRefs)
                    await $_getPrefetchedData(
                        currentTable: table,
                        referencedTable: $$PiecesTableReferences
                            ._practiceRecordingsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$PiecesTableReferences(db, table, p0)
                                .practiceRecordingsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.pieceId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$PiecesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PiecesTable,
    PieceRow,
    $$PiecesTableFilterComposer,
    $$PiecesTableOrderingComposer,
    $$PiecesTableAnnotationComposer,
    $$PiecesTableCreateCompanionBuilder,
    $$PiecesTableUpdateCompanionBuilder,
    (PieceRow, $$PiecesTableReferences),
    PieceRow,
    PrefetchHooks Function(
        {bool scoreVersionsRefs,
        bool mediaAssetsRefs,
        bool mediaMatchCandidatesRefs,
        bool processingJobsRefs,
        bool reviewItemsRefs,
        bool pieceHistoryDraftsRefs,
        bool practiceRecordingsRefs})>;
typedef $$ScoreVersionsTableCreateCompanionBuilder = ScoreVersionsCompanion
    Function({
  required String id,
  required String pieceId,
  required String title,
  required String filePath,
  Value<String?> remoteUrl,
  Value<String?> versionType,
  required String format,
  Value<int?> pageCount,
  Value<String?> checksum,
  required bool isPrimary,
  required bool isStudentVisible,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$ScoreVersionsTableUpdateCompanionBuilder = ScoreVersionsCompanion
    Function({
  Value<String> id,
  Value<String> pieceId,
  Value<String> title,
  Value<String> filePath,
  Value<String?> remoteUrl,
  Value<String?> versionType,
  Value<String> format,
  Value<int?> pageCount,
  Value<String?> checksum,
  Value<bool> isPrimary,
  Value<bool> isStudentVisible,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

final class $$ScoreVersionsTableReferences extends BaseReferences<_$AppDatabase,
    $ScoreVersionsTable, ScoreVersionRow> {
  $$ScoreVersionsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $PiecesTable _pieceIdTable(_$AppDatabase db) => db.pieces.createAlias(
      $_aliasNameGenerator(db.scoreVersions.pieceId, db.pieces.id));

  $$PiecesTableProcessedTableManager? get pieceId {
    if ($_item.pieceId == null) return null;
    final manager = $$PiecesTableTableManager($_db, $_db.pieces)
        .filter((f) => f.id($_item.pieceId!));
    final item = $_typedResult.readTableOrNull(_pieceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$MediaMatchCandidatesTable,
      List<MediaMatchCandidate>> _mediaMatchCandidatesRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.mediaMatchCandidates,
          aliasName: $_aliasNameGenerator(
              db.scoreVersions.id, db.mediaMatchCandidates.scoreVersionId));

  $$MediaMatchCandidatesTableProcessedTableManager
      get mediaMatchCandidatesRefs {
    final manager =
        $$MediaMatchCandidatesTableTableManager($_db, $_db.mediaMatchCandidates)
            .filter((f) => f.scoreVersionId.id($_item.id));

    final cache =
        $_typedResult.readTableOrNull(_mediaMatchCandidatesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$ScoreVersionsTableFilterComposer
    extends Composer<_$AppDatabase, $ScoreVersionsTable> {
  $$ScoreVersionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get remoteUrl => $composableBuilder(
      column: $table.remoteUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get versionType => $composableBuilder(
      column: $table.versionType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get format => $composableBuilder(
      column: $table.format, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get pageCount => $composableBuilder(
      column: $table.pageCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get checksum => $composableBuilder(
      column: $table.checksum, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isPrimary => $composableBuilder(
      column: $table.isPrimary, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isStudentVisible => $composableBuilder(
      column: $table.isStudentVisible,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  $$PiecesTableFilterComposer get pieceId {
    final $$PiecesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.pieceId,
        referencedTable: $db.pieces,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PiecesTableFilterComposer(
              $db: $db,
              $table: $db.pieces,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<bool> mediaMatchCandidatesRefs(
      Expression<bool> Function($$MediaMatchCandidatesTableFilterComposer f)
          f) {
    final $$MediaMatchCandidatesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.mediaMatchCandidates,
        getReferencedColumn: (t) => t.scoreVersionId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MediaMatchCandidatesTableFilterComposer(
              $db: $db,
              $table: $db.mediaMatchCandidates,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ScoreVersionsTableOrderingComposer
    extends Composer<_$AppDatabase, $ScoreVersionsTable> {
  $$ScoreVersionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get remoteUrl => $composableBuilder(
      column: $table.remoteUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get versionType => $composableBuilder(
      column: $table.versionType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get format => $composableBuilder(
      column: $table.format, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get pageCount => $composableBuilder(
      column: $table.pageCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get checksum => $composableBuilder(
      column: $table.checksum, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isPrimary => $composableBuilder(
      column: $table.isPrimary, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isStudentVisible => $composableBuilder(
      column: $table.isStudentVisible,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  $$PiecesTableOrderingComposer get pieceId {
    final $$PiecesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.pieceId,
        referencedTable: $db.pieces,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PiecesTableOrderingComposer(
              $db: $db,
              $table: $db.pieces,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ScoreVersionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ScoreVersionsTable> {
  $$ScoreVersionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<String> get remoteUrl =>
      $composableBuilder(column: $table.remoteUrl, builder: (column) => column);

  GeneratedColumn<String> get versionType => $composableBuilder(
      column: $table.versionType, builder: (column) => column);

  GeneratedColumn<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<int> get pageCount =>
      $composableBuilder(column: $table.pageCount, builder: (column) => column);

  GeneratedColumn<String> get checksum =>
      $composableBuilder(column: $table.checksum, builder: (column) => column);

  GeneratedColumn<bool> get isPrimary =>
      $composableBuilder(column: $table.isPrimary, builder: (column) => column);

  GeneratedColumn<bool> get isStudentVisible => $composableBuilder(
      column: $table.isStudentVisible, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$PiecesTableAnnotationComposer get pieceId {
    final $$PiecesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.pieceId,
        referencedTable: $db.pieces,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PiecesTableAnnotationComposer(
              $db: $db,
              $table: $db.pieces,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<T> mediaMatchCandidatesRefs<T extends Object>(
      Expression<T> Function($$MediaMatchCandidatesTableAnnotationComposer a)
          f) {
    final $$MediaMatchCandidatesTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.mediaMatchCandidates,
            getReferencedColumn: (t) => t.scoreVersionId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$MediaMatchCandidatesTableAnnotationComposer(
                  $db: $db,
                  $table: $db.mediaMatchCandidates,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }
}

class $$ScoreVersionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ScoreVersionsTable,
    ScoreVersionRow,
    $$ScoreVersionsTableFilterComposer,
    $$ScoreVersionsTableOrderingComposer,
    $$ScoreVersionsTableAnnotationComposer,
    $$ScoreVersionsTableCreateCompanionBuilder,
    $$ScoreVersionsTableUpdateCompanionBuilder,
    (ScoreVersionRow, $$ScoreVersionsTableReferences),
    ScoreVersionRow,
    PrefetchHooks Function({bool pieceId, bool mediaMatchCandidatesRefs})> {
  $$ScoreVersionsTableTableManager(_$AppDatabase db, $ScoreVersionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScoreVersionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ScoreVersionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ScoreVersionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> pieceId = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> filePath = const Value.absent(),
            Value<String?> remoteUrl = const Value.absent(),
            Value<String?> versionType = const Value.absent(),
            Value<String> format = const Value.absent(),
            Value<int?> pageCount = const Value.absent(),
            Value<String?> checksum = const Value.absent(),
            Value<bool> isPrimary = const Value.absent(),
            Value<bool> isStudentVisible = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ScoreVersionsCompanion(
            id: id,
            pieceId: pieceId,
            title: title,
            filePath: filePath,
            remoteUrl: remoteUrl,
            versionType: versionType,
            format: format,
            pageCount: pageCount,
            checksum: checksum,
            isPrimary: isPrimary,
            isStudentVisible: isStudentVisible,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String pieceId,
            required String title,
            required String filePath,
            Value<String?> remoteUrl = const Value.absent(),
            Value<String?> versionType = const Value.absent(),
            required String format,
            Value<int?> pageCount = const Value.absent(),
            Value<String?> checksum = const Value.absent(),
            required bool isPrimary,
            required bool isStudentVisible,
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              ScoreVersionsCompanion.insert(
            id: id,
            pieceId: pieceId,
            title: title,
            filePath: filePath,
            remoteUrl: remoteUrl,
            versionType: versionType,
            format: format,
            pageCount: pageCount,
            checksum: checksum,
            isPrimary: isPrimary,
            isStudentVisible: isStudentVisible,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$ScoreVersionsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {pieceId = false, mediaMatchCandidatesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (mediaMatchCandidatesRefs) db.mediaMatchCandidates
              ],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (pieceId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.pieceId,
                    referencedTable:
                        $$ScoreVersionsTableReferences._pieceIdTable(db),
                    referencedColumn:
                        $$ScoreVersionsTableReferences._pieceIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (mediaMatchCandidatesRefs)
                    await $_getPrefetchedData(
                        currentTable: table,
                        referencedTable: $$ScoreVersionsTableReferences
                            ._mediaMatchCandidatesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ScoreVersionsTableReferences(db, table, p0)
                                .mediaMatchCandidatesRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.scoreVersionId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$ScoreVersionsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ScoreVersionsTable,
    ScoreVersionRow,
    $$ScoreVersionsTableFilterComposer,
    $$ScoreVersionsTableOrderingComposer,
    $$ScoreVersionsTableAnnotationComposer,
    $$ScoreVersionsTableCreateCompanionBuilder,
    $$ScoreVersionsTableUpdateCompanionBuilder,
    (ScoreVersionRow, $$ScoreVersionsTableReferences),
    ScoreVersionRow,
    PrefetchHooks Function({bool pieceId, bool mediaMatchCandidatesRefs})>;
typedef $$AnnotationLayersTableCreateCompanionBuilder
    = AnnotationLayersCompanion Function({
  required String id,
  required String profileId,
  required String scoreVersionId,
  required int pageNumber,
  required String strokes,
  required String notes,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$AnnotationLayersTableUpdateCompanionBuilder
    = AnnotationLayersCompanion Function({
  Value<String> id,
  Value<String> profileId,
  Value<String> scoreVersionId,
  Value<int> pageNumber,
  Value<String> strokes,
  Value<String> notes,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

final class $$AnnotationLayersTableReferences extends BaseReferences<
    _$AppDatabase, $AnnotationLayersTable, AnnotationLayerRow> {
  $$AnnotationLayersTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$AnnotationStrokesTable, List<AnnotationStrokeRow>>
      _annotationStrokesRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.annotationStrokes,
              aliasName: $_aliasNameGenerator(
                  db.annotationLayers.id, db.annotationStrokes.layerId));

  $$AnnotationStrokesTableProcessedTableManager get annotationStrokesRefs {
    final manager =
        $$AnnotationStrokesTableTableManager($_db, $_db.annotationStrokes)
            .filter((f) => f.layerId.id($_item.id));

    final cache =
        $_typedResult.readTableOrNull(_annotationStrokesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$AnnotationNotesTable, List<AnnotationNoteRow>>
      _annotationNotesRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.annotationNotes,
              aliasName: $_aliasNameGenerator(
                  db.annotationLayers.id, db.annotationNotes.layerId));

  $$AnnotationNotesTableProcessedTableManager get annotationNotesRefs {
    final manager =
        $$AnnotationNotesTableTableManager($_db, $_db.annotationNotes)
            .filter((f) => f.layerId.id($_item.id));

    final cache =
        $_typedResult.readTableOrNull(_annotationNotesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$AnnotationLayersTableFilterComposer
    extends Composer<_$AppDatabase, $AnnotationLayersTable> {
  $$AnnotationLayersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get profileId => $composableBuilder(
      column: $table.profileId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get scoreVersionId => $composableBuilder(
      column: $table.scoreVersionId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get pageNumber => $composableBuilder(
      column: $table.pageNumber, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get strokes => $composableBuilder(
      column: $table.strokes, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  Expression<bool> annotationStrokesRefs(
      Expression<bool> Function($$AnnotationStrokesTableFilterComposer f) f) {
    final $$AnnotationStrokesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.annotationStrokes,
        getReferencedColumn: (t) => t.layerId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AnnotationStrokesTableFilterComposer(
              $db: $db,
              $table: $db.annotationStrokes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> annotationNotesRefs(
      Expression<bool> Function($$AnnotationNotesTableFilterComposer f) f) {
    final $$AnnotationNotesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.annotationNotes,
        getReferencedColumn: (t) => t.layerId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AnnotationNotesTableFilterComposer(
              $db: $db,
              $table: $db.annotationNotes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$AnnotationLayersTableOrderingComposer
    extends Composer<_$AppDatabase, $AnnotationLayersTable> {
  $$AnnotationLayersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get profileId => $composableBuilder(
      column: $table.profileId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get scoreVersionId => $composableBuilder(
      column: $table.scoreVersionId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get pageNumber => $composableBuilder(
      column: $table.pageNumber, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get strokes => $composableBuilder(
      column: $table.strokes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$AnnotationLayersTableAnnotationComposer
    extends Composer<_$AppDatabase, $AnnotationLayersTable> {
  $$AnnotationLayersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<String> get scoreVersionId => $composableBuilder(
      column: $table.scoreVersionId, builder: (column) => column);

  GeneratedColumn<int> get pageNumber => $composableBuilder(
      column: $table.pageNumber, builder: (column) => column);

  GeneratedColumn<String> get strokes =>
      $composableBuilder(column: $table.strokes, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> annotationStrokesRefs<T extends Object>(
      Expression<T> Function($$AnnotationStrokesTableAnnotationComposer a) f) {
    final $$AnnotationStrokesTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.annotationStrokes,
            getReferencedColumn: (t) => t.layerId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$AnnotationStrokesTableAnnotationComposer(
                  $db: $db,
                  $table: $db.annotationStrokes,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }

  Expression<T> annotationNotesRefs<T extends Object>(
      Expression<T> Function($$AnnotationNotesTableAnnotationComposer a) f) {
    final $$AnnotationNotesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.annotationNotes,
        getReferencedColumn: (t) => t.layerId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AnnotationNotesTableAnnotationComposer(
              $db: $db,
              $table: $db.annotationNotes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$AnnotationLayersTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AnnotationLayersTable,
    AnnotationLayerRow,
    $$AnnotationLayersTableFilterComposer,
    $$AnnotationLayersTableOrderingComposer,
    $$AnnotationLayersTableAnnotationComposer,
    $$AnnotationLayersTableCreateCompanionBuilder,
    $$AnnotationLayersTableUpdateCompanionBuilder,
    (AnnotationLayerRow, $$AnnotationLayersTableReferences),
    AnnotationLayerRow,
    PrefetchHooks Function(
        {bool annotationStrokesRefs, bool annotationNotesRefs})> {
  $$AnnotationLayersTableTableManager(
      _$AppDatabase db, $AnnotationLayersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AnnotationLayersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AnnotationLayersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AnnotationLayersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> profileId = const Value.absent(),
            Value<String> scoreVersionId = const Value.absent(),
            Value<int> pageNumber = const Value.absent(),
            Value<String> strokes = const Value.absent(),
            Value<String> notes = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AnnotationLayersCompanion(
            id: id,
            profileId: profileId,
            scoreVersionId: scoreVersionId,
            pageNumber: pageNumber,
            strokes: strokes,
            notes: notes,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String profileId,
            required String scoreVersionId,
            required int pageNumber,
            required String strokes,
            required String notes,
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              AnnotationLayersCompanion.insert(
            id: id,
            profileId: profileId,
            scoreVersionId: scoreVersionId,
            pageNumber: pageNumber,
            strokes: strokes,
            notes: notes,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$AnnotationLayersTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {annotationStrokesRefs = false, annotationNotesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (annotationStrokesRefs) db.annotationStrokes,
                if (annotationNotesRefs) db.annotationNotes
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (annotationStrokesRefs)
                    await $_getPrefetchedData(
                        currentTable: table,
                        referencedTable: $$AnnotationLayersTableReferences
                            ._annotationStrokesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$AnnotationLayersTableReferences(db, table, p0)
                                .annotationStrokesRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.layerId == item.id),
                        typedResults: items),
                  if (annotationNotesRefs)
                    await $_getPrefetchedData(
                        currentTable: table,
                        referencedTable: $$AnnotationLayersTableReferences
                            ._annotationNotesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$AnnotationLayersTableReferences(db, table, p0)
                                .annotationNotesRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.layerId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$AnnotationLayersTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AnnotationLayersTable,
    AnnotationLayerRow,
    $$AnnotationLayersTableFilterComposer,
    $$AnnotationLayersTableOrderingComposer,
    $$AnnotationLayersTableAnnotationComposer,
    $$AnnotationLayersTableCreateCompanionBuilder,
    $$AnnotationLayersTableUpdateCompanionBuilder,
    (AnnotationLayerRow, $$AnnotationLayersTableReferences),
    AnnotationLayerRow,
    PrefetchHooks Function(
        {bool annotationStrokesRefs, bool annotationNotesRefs})>;
typedef $$AnnotationStrokesTableCreateCompanionBuilder
    = AnnotationStrokesCompanion Function({
  required String id,
  required String layerId,
  required String color,
  required double strokeWidth,
  required String points,
  required String tool,
  Value<int> rowid,
});
typedef $$AnnotationStrokesTableUpdateCompanionBuilder
    = AnnotationStrokesCompanion Function({
  Value<String> id,
  Value<String> layerId,
  Value<String> color,
  Value<double> strokeWidth,
  Value<String> points,
  Value<String> tool,
  Value<int> rowid,
});

final class $$AnnotationStrokesTableReferences extends BaseReferences<
    _$AppDatabase, $AnnotationStrokesTable, AnnotationStrokeRow> {
  $$AnnotationStrokesTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $AnnotationLayersTable _layerIdTable(_$AppDatabase db) =>
      db.annotationLayers.createAlias($_aliasNameGenerator(
          db.annotationStrokes.layerId, db.annotationLayers.id));

  $$AnnotationLayersTableProcessedTableManager? get layerId {
    if ($_item.layerId == null) return null;
    final manager =
        $$AnnotationLayersTableTableManager($_db, $_db.annotationLayers)
            .filter((f) => f.id($_item.layerId!));
    final item = $_typedResult.readTableOrNull(_layerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$AnnotationStrokesTableFilterComposer
    extends Composer<_$AppDatabase, $AnnotationStrokesTable> {
  $$AnnotationStrokesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get color => $composableBuilder(
      column: $table.color, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get strokeWidth => $composableBuilder(
      column: $table.strokeWidth, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get points => $composableBuilder(
      column: $table.points, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tool => $composableBuilder(
      column: $table.tool, builder: (column) => ColumnFilters(column));

  $$AnnotationLayersTableFilterComposer get layerId {
    final $$AnnotationLayersTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.layerId,
        referencedTable: $db.annotationLayers,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AnnotationLayersTableFilterComposer(
              $db: $db,
              $table: $db.annotationLayers,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$AnnotationStrokesTableOrderingComposer
    extends Composer<_$AppDatabase, $AnnotationStrokesTable> {
  $$AnnotationStrokesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get color => $composableBuilder(
      column: $table.color, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get strokeWidth => $composableBuilder(
      column: $table.strokeWidth, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get points => $composableBuilder(
      column: $table.points, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tool => $composableBuilder(
      column: $table.tool, builder: (column) => ColumnOrderings(column));

  $$AnnotationLayersTableOrderingComposer get layerId {
    final $$AnnotationLayersTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.layerId,
        referencedTable: $db.annotationLayers,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AnnotationLayersTableOrderingComposer(
              $db: $db,
              $table: $db.annotationLayers,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$AnnotationStrokesTableAnnotationComposer
    extends Composer<_$AppDatabase, $AnnotationStrokesTable> {
  $$AnnotationStrokesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<double> get strokeWidth => $composableBuilder(
      column: $table.strokeWidth, builder: (column) => column);

  GeneratedColumn<String> get points =>
      $composableBuilder(column: $table.points, builder: (column) => column);

  GeneratedColumn<String> get tool =>
      $composableBuilder(column: $table.tool, builder: (column) => column);

  $$AnnotationLayersTableAnnotationComposer get layerId {
    final $$AnnotationLayersTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.layerId,
        referencedTable: $db.annotationLayers,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AnnotationLayersTableAnnotationComposer(
              $db: $db,
              $table: $db.annotationLayers,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$AnnotationStrokesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AnnotationStrokesTable,
    AnnotationStrokeRow,
    $$AnnotationStrokesTableFilterComposer,
    $$AnnotationStrokesTableOrderingComposer,
    $$AnnotationStrokesTableAnnotationComposer,
    $$AnnotationStrokesTableCreateCompanionBuilder,
    $$AnnotationStrokesTableUpdateCompanionBuilder,
    (AnnotationStrokeRow, $$AnnotationStrokesTableReferences),
    AnnotationStrokeRow,
    PrefetchHooks Function({bool layerId})> {
  $$AnnotationStrokesTableTableManager(
      _$AppDatabase db, $AnnotationStrokesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AnnotationStrokesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AnnotationStrokesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AnnotationStrokesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> layerId = const Value.absent(),
            Value<String> color = const Value.absent(),
            Value<double> strokeWidth = const Value.absent(),
            Value<String> points = const Value.absent(),
            Value<String> tool = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AnnotationStrokesCompanion(
            id: id,
            layerId: layerId,
            color: color,
            strokeWidth: strokeWidth,
            points: points,
            tool: tool,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String layerId,
            required String color,
            required double strokeWidth,
            required String points,
            required String tool,
            Value<int> rowid = const Value.absent(),
          }) =>
              AnnotationStrokesCompanion.insert(
            id: id,
            layerId: layerId,
            color: color,
            strokeWidth: strokeWidth,
            points: points,
            tool: tool,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$AnnotationStrokesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({layerId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (layerId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.layerId,
                    referencedTable:
                        $$AnnotationStrokesTableReferences._layerIdTable(db),
                    referencedColumn:
                        $$AnnotationStrokesTableReferences._layerIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$AnnotationStrokesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AnnotationStrokesTable,
    AnnotationStrokeRow,
    $$AnnotationStrokesTableFilterComposer,
    $$AnnotationStrokesTableOrderingComposer,
    $$AnnotationStrokesTableAnnotationComposer,
    $$AnnotationStrokesTableCreateCompanionBuilder,
    $$AnnotationStrokesTableUpdateCompanionBuilder,
    (AnnotationStrokeRow, $$AnnotationStrokesTableReferences),
    AnnotationStrokeRow,
    PrefetchHooks Function({bool layerId})>;
typedef $$AnnotationNotesTableCreateCompanionBuilder = AnnotationNotesCompanion
    Function({
  required String id,
  required String layerId,
  required double x,
  required double y,
  required String noteText,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$AnnotationNotesTableUpdateCompanionBuilder = AnnotationNotesCompanion
    Function({
  Value<String> id,
  Value<String> layerId,
  Value<double> x,
  Value<double> y,
  Value<String> noteText,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

final class $$AnnotationNotesTableReferences extends BaseReferences<
    _$AppDatabase, $AnnotationNotesTable, AnnotationNoteRow> {
  $$AnnotationNotesTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $AnnotationLayersTable _layerIdTable(_$AppDatabase db) =>
      db.annotationLayers.createAlias($_aliasNameGenerator(
          db.annotationNotes.layerId, db.annotationLayers.id));

  $$AnnotationLayersTableProcessedTableManager? get layerId {
    if ($_item.layerId == null) return null;
    final manager =
        $$AnnotationLayersTableTableManager($_db, $_db.annotationLayers)
            .filter((f) => f.id($_item.layerId!));
    final item = $_typedResult.readTableOrNull(_layerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$AnnotationNotesTableFilterComposer
    extends Composer<_$AppDatabase, $AnnotationNotesTable> {
  $$AnnotationNotesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get x => $composableBuilder(
      column: $table.x, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get y => $composableBuilder(
      column: $table.y, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get noteText => $composableBuilder(
      column: $table.noteText, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  $$AnnotationLayersTableFilterComposer get layerId {
    final $$AnnotationLayersTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.layerId,
        referencedTable: $db.annotationLayers,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AnnotationLayersTableFilterComposer(
              $db: $db,
              $table: $db.annotationLayers,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$AnnotationNotesTableOrderingComposer
    extends Composer<_$AppDatabase, $AnnotationNotesTable> {
  $$AnnotationNotesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get x => $composableBuilder(
      column: $table.x, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get y => $composableBuilder(
      column: $table.y, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get noteText => $composableBuilder(
      column: $table.noteText, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  $$AnnotationLayersTableOrderingComposer get layerId {
    final $$AnnotationLayersTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.layerId,
        referencedTable: $db.annotationLayers,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AnnotationLayersTableOrderingComposer(
              $db: $db,
              $table: $db.annotationLayers,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$AnnotationNotesTableAnnotationComposer
    extends Composer<_$AppDatabase, $AnnotationNotesTable> {
  $$AnnotationNotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get x =>
      $composableBuilder(column: $table.x, builder: (column) => column);

  GeneratedColumn<double> get y =>
      $composableBuilder(column: $table.y, builder: (column) => column);

  GeneratedColumn<String> get noteText =>
      $composableBuilder(column: $table.noteText, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$AnnotationLayersTableAnnotationComposer get layerId {
    final $$AnnotationLayersTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.layerId,
        referencedTable: $db.annotationLayers,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AnnotationLayersTableAnnotationComposer(
              $db: $db,
              $table: $db.annotationLayers,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$AnnotationNotesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AnnotationNotesTable,
    AnnotationNoteRow,
    $$AnnotationNotesTableFilterComposer,
    $$AnnotationNotesTableOrderingComposer,
    $$AnnotationNotesTableAnnotationComposer,
    $$AnnotationNotesTableCreateCompanionBuilder,
    $$AnnotationNotesTableUpdateCompanionBuilder,
    (AnnotationNoteRow, $$AnnotationNotesTableReferences),
    AnnotationNoteRow,
    PrefetchHooks Function({bool layerId})> {
  $$AnnotationNotesTableTableManager(
      _$AppDatabase db, $AnnotationNotesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AnnotationNotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AnnotationNotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AnnotationNotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> layerId = const Value.absent(),
            Value<double> x = const Value.absent(),
            Value<double> y = const Value.absent(),
            Value<String> noteText = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AnnotationNotesCompanion(
            id: id,
            layerId: layerId,
            x: x,
            y: y,
            noteText: noteText,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String layerId,
            required double x,
            required double y,
            required String noteText,
            required DateTime createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              AnnotationNotesCompanion.insert(
            id: id,
            layerId: layerId,
            x: x,
            y: y,
            noteText: noteText,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$AnnotationNotesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({layerId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (layerId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.layerId,
                    referencedTable:
                        $$AnnotationNotesTableReferences._layerIdTable(db),
                    referencedColumn:
                        $$AnnotationNotesTableReferences._layerIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$AnnotationNotesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AnnotationNotesTable,
    AnnotationNoteRow,
    $$AnnotationNotesTableFilterComposer,
    $$AnnotationNotesTableOrderingComposer,
    $$AnnotationNotesTableAnnotationComposer,
    $$AnnotationNotesTableCreateCompanionBuilder,
    $$AnnotationNotesTableUpdateCompanionBuilder,
    (AnnotationNoteRow, $$AnnotationNotesTableReferences),
    AnnotationNoteRow,
    PrefetchHooks Function({bool layerId})>;
typedef $$MediaAssetsTableCreateCompanionBuilder = MediaAssetsCompanion
    Function({
  required String id,
  required String pieceId,
  required String filePath,
  Value<String?> remoteUrl,
  required String format,
  Value<int?> durationMs,
  Value<int?> fileSizeBytes,
  Value<String?> thumbnailPath,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$MediaAssetsTableUpdateCompanionBuilder = MediaAssetsCompanion
    Function({
  Value<String> id,
  Value<String> pieceId,
  Value<String> filePath,
  Value<String?> remoteUrl,
  Value<String> format,
  Value<int?> durationMs,
  Value<int?> fileSizeBytes,
  Value<String?> thumbnailPath,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

final class $$MediaAssetsTableReferences
    extends BaseReferences<_$AppDatabase, $MediaAssetsTable, MediaAsset> {
  $$MediaAssetsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PiecesTable _pieceIdTable(_$AppDatabase db) => db.pieces
      .createAlias($_aliasNameGenerator(db.mediaAssets.pieceId, db.pieces.id));

  $$PiecesTableProcessedTableManager? get pieceId {
    if ($_item.pieceId == null) return null;
    final manager = $$PiecesTableTableManager($_db, $_db.pieces)
        .filter((f) => f.id($_item.pieceId!));
    final item = $_typedResult.readTableOrNull(_pieceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$MediaMatchCandidatesTable,
      List<MediaMatchCandidate>> _mediaMatchCandidatesRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.mediaMatchCandidates,
          aliasName: $_aliasNameGenerator(
              db.mediaAssets.id, db.mediaMatchCandidates.mediaAssetId));

  $$MediaMatchCandidatesTableProcessedTableManager
      get mediaMatchCandidatesRefs {
    final manager =
        $$MediaMatchCandidatesTableTableManager($_db, $_db.mediaMatchCandidates)
            .filter((f) => f.mediaAssetId.id($_item.id));

    final cache =
        $_typedResult.readTableOrNull(_mediaMatchCandidatesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$MediaAssetsTableFilterComposer
    extends Composer<_$AppDatabase, $MediaAssetsTable> {
  $$MediaAssetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get remoteUrl => $composableBuilder(
      column: $table.remoteUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get format => $composableBuilder(
      column: $table.format, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get durationMs => $composableBuilder(
      column: $table.durationMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get fileSizeBytes => $composableBuilder(
      column: $table.fileSizeBytes, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get thumbnailPath => $composableBuilder(
      column: $table.thumbnailPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  $$PiecesTableFilterComposer get pieceId {
    final $$PiecesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.pieceId,
        referencedTable: $db.pieces,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PiecesTableFilterComposer(
              $db: $db,
              $table: $db.pieces,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<bool> mediaMatchCandidatesRefs(
      Expression<bool> Function($$MediaMatchCandidatesTableFilterComposer f)
          f) {
    final $$MediaMatchCandidatesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.mediaMatchCandidates,
        getReferencedColumn: (t) => t.mediaAssetId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MediaMatchCandidatesTableFilterComposer(
              $db: $db,
              $table: $db.mediaMatchCandidates,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$MediaAssetsTableOrderingComposer
    extends Composer<_$AppDatabase, $MediaAssetsTable> {
  $$MediaAssetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get remoteUrl => $composableBuilder(
      column: $table.remoteUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get format => $composableBuilder(
      column: $table.format, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get durationMs => $composableBuilder(
      column: $table.durationMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get fileSizeBytes => $composableBuilder(
      column: $table.fileSizeBytes,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get thumbnailPath => $composableBuilder(
      column: $table.thumbnailPath,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  $$PiecesTableOrderingComposer get pieceId {
    final $$PiecesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.pieceId,
        referencedTable: $db.pieces,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PiecesTableOrderingComposer(
              $db: $db,
              $table: $db.pieces,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$MediaAssetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MediaAssetsTable> {
  $$MediaAssetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<String> get remoteUrl =>
      $composableBuilder(column: $table.remoteUrl, builder: (column) => column);

  GeneratedColumn<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
      column: $table.durationMs, builder: (column) => column);

  GeneratedColumn<int> get fileSizeBytes => $composableBuilder(
      column: $table.fileSizeBytes, builder: (column) => column);

  GeneratedColumn<String> get thumbnailPath => $composableBuilder(
      column: $table.thumbnailPath, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$PiecesTableAnnotationComposer get pieceId {
    final $$PiecesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.pieceId,
        referencedTable: $db.pieces,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PiecesTableAnnotationComposer(
              $db: $db,
              $table: $db.pieces,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<T> mediaMatchCandidatesRefs<T extends Object>(
      Expression<T> Function($$MediaMatchCandidatesTableAnnotationComposer a)
          f) {
    final $$MediaMatchCandidatesTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.mediaMatchCandidates,
            getReferencedColumn: (t) => t.mediaAssetId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$MediaMatchCandidatesTableAnnotationComposer(
                  $db: $db,
                  $table: $db.mediaMatchCandidates,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }
}

class $$MediaAssetsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $MediaAssetsTable,
    MediaAsset,
    $$MediaAssetsTableFilterComposer,
    $$MediaAssetsTableOrderingComposer,
    $$MediaAssetsTableAnnotationComposer,
    $$MediaAssetsTableCreateCompanionBuilder,
    $$MediaAssetsTableUpdateCompanionBuilder,
    (MediaAsset, $$MediaAssetsTableReferences),
    MediaAsset,
    PrefetchHooks Function({bool pieceId, bool mediaMatchCandidatesRefs})> {
  $$MediaAssetsTableTableManager(_$AppDatabase db, $MediaAssetsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MediaAssetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MediaAssetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MediaAssetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> pieceId = const Value.absent(),
            Value<String> filePath = const Value.absent(),
            Value<String?> remoteUrl = const Value.absent(),
            Value<String> format = const Value.absent(),
            Value<int?> durationMs = const Value.absent(),
            Value<int?> fileSizeBytes = const Value.absent(),
            Value<String?> thumbnailPath = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MediaAssetsCompanion(
            id: id,
            pieceId: pieceId,
            filePath: filePath,
            remoteUrl: remoteUrl,
            format: format,
            durationMs: durationMs,
            fileSizeBytes: fileSizeBytes,
            thumbnailPath: thumbnailPath,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String pieceId,
            required String filePath,
            Value<String?> remoteUrl = const Value.absent(),
            required String format,
            Value<int?> durationMs = const Value.absent(),
            Value<int?> fileSizeBytes = const Value.absent(),
            Value<String?> thumbnailPath = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              MediaAssetsCompanion.insert(
            id: id,
            pieceId: pieceId,
            filePath: filePath,
            remoteUrl: remoteUrl,
            format: format,
            durationMs: durationMs,
            fileSizeBytes: fileSizeBytes,
            thumbnailPath: thumbnailPath,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$MediaAssetsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {pieceId = false, mediaMatchCandidatesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (mediaMatchCandidatesRefs) db.mediaMatchCandidates
              ],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (pieceId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.pieceId,
                    referencedTable:
                        $$MediaAssetsTableReferences._pieceIdTable(db),
                    referencedColumn:
                        $$MediaAssetsTableReferences._pieceIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (mediaMatchCandidatesRefs)
                    await $_getPrefetchedData(
                        currentTable: table,
                        referencedTable: $$MediaAssetsTableReferences
                            ._mediaMatchCandidatesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$MediaAssetsTableReferences(db, table, p0)
                                .mediaMatchCandidatesRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.mediaAssetId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$MediaAssetsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $MediaAssetsTable,
    MediaAsset,
    $$MediaAssetsTableFilterComposer,
    $$MediaAssetsTableOrderingComposer,
    $$MediaAssetsTableAnnotationComposer,
    $$MediaAssetsTableCreateCompanionBuilder,
    $$MediaAssetsTableUpdateCompanionBuilder,
    (MediaAsset, $$MediaAssetsTableReferences),
    MediaAsset,
    PrefetchHooks Function({bool pieceId, bool mediaMatchCandidatesRefs})>;
typedef $$MediaMatchCandidatesTableCreateCompanionBuilder
    = MediaMatchCandidatesCompanion Function({
  required String id,
  required String mediaAssetId,
  required String pieceId,
  required String scoreVersionId,
  required double similarityScore,
  required String status,
  Value<String?> aiNotes,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$MediaMatchCandidatesTableUpdateCompanionBuilder
    = MediaMatchCandidatesCompanion Function({
  Value<String> id,
  Value<String> mediaAssetId,
  Value<String> pieceId,
  Value<String> scoreVersionId,
  Value<double> similarityScore,
  Value<String> status,
  Value<String?> aiNotes,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

final class $$MediaMatchCandidatesTableReferences extends BaseReferences<
    _$AppDatabase, $MediaMatchCandidatesTable, MediaMatchCandidate> {
  $$MediaMatchCandidatesTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $MediaAssetsTable _mediaAssetIdTable(_$AppDatabase db) =>
      db.mediaAssets.createAlias($_aliasNameGenerator(
          db.mediaMatchCandidates.mediaAssetId, db.mediaAssets.id));

  $$MediaAssetsTableProcessedTableManager? get mediaAssetId {
    if ($_item.mediaAssetId == null) return null;
    final manager = $$MediaAssetsTableTableManager($_db, $_db.mediaAssets)
        .filter((f) => f.id($_item.mediaAssetId!));
    final item = $_typedResult.readTableOrNull(_mediaAssetIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $PiecesTable _pieceIdTable(_$AppDatabase db) => db.pieces.createAlias(
      $_aliasNameGenerator(db.mediaMatchCandidates.pieceId, db.pieces.id));

  $$PiecesTableProcessedTableManager? get pieceId {
    if ($_item.pieceId == null) return null;
    final manager = $$PiecesTableTableManager($_db, $_db.pieces)
        .filter((f) => f.id($_item.pieceId!));
    final item = $_typedResult.readTableOrNull(_pieceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $ScoreVersionsTable _scoreVersionIdTable(_$AppDatabase db) =>
      db.scoreVersions.createAlias($_aliasNameGenerator(
          db.mediaMatchCandidates.scoreVersionId, db.scoreVersions.id));

  $$ScoreVersionsTableProcessedTableManager? get scoreVersionId {
    if ($_item.scoreVersionId == null) return null;
    final manager = $$ScoreVersionsTableTableManager($_db, $_db.scoreVersions)
        .filter((f) => f.id($_item.scoreVersionId!));
    final item = $_typedResult.readTableOrNull(_scoreVersionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$MediaMatchCandidatesTableFilterComposer
    extends Composer<_$AppDatabase, $MediaMatchCandidatesTable> {
  $$MediaMatchCandidatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get similarityScore => $composableBuilder(
      column: $table.similarityScore,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get aiNotes => $composableBuilder(
      column: $table.aiNotes, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  $$MediaAssetsTableFilterComposer get mediaAssetId {
    final $$MediaAssetsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.mediaAssetId,
        referencedTable: $db.mediaAssets,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MediaAssetsTableFilterComposer(
              $db: $db,
              $table: $db.mediaAssets,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$PiecesTableFilterComposer get pieceId {
    final $$PiecesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.pieceId,
        referencedTable: $db.pieces,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PiecesTableFilterComposer(
              $db: $db,
              $table: $db.pieces,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ScoreVersionsTableFilterComposer get scoreVersionId {
    final $$ScoreVersionsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.scoreVersionId,
        referencedTable: $db.scoreVersions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ScoreVersionsTableFilterComposer(
              $db: $db,
              $table: $db.scoreVersions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$MediaMatchCandidatesTableOrderingComposer
    extends Composer<_$AppDatabase, $MediaMatchCandidatesTable> {
  $$MediaMatchCandidatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get similarityScore => $composableBuilder(
      column: $table.similarityScore,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get aiNotes => $composableBuilder(
      column: $table.aiNotes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  $$MediaAssetsTableOrderingComposer get mediaAssetId {
    final $$MediaAssetsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.mediaAssetId,
        referencedTable: $db.mediaAssets,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MediaAssetsTableOrderingComposer(
              $db: $db,
              $table: $db.mediaAssets,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$PiecesTableOrderingComposer get pieceId {
    final $$PiecesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.pieceId,
        referencedTable: $db.pieces,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PiecesTableOrderingComposer(
              $db: $db,
              $table: $db.pieces,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ScoreVersionsTableOrderingComposer get scoreVersionId {
    final $$ScoreVersionsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.scoreVersionId,
        referencedTable: $db.scoreVersions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ScoreVersionsTableOrderingComposer(
              $db: $db,
              $table: $db.scoreVersions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$MediaMatchCandidatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MediaMatchCandidatesTable> {
  $$MediaMatchCandidatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get similarityScore => $composableBuilder(
      column: $table.similarityScore, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get aiNotes =>
      $composableBuilder(column: $table.aiNotes, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$MediaAssetsTableAnnotationComposer get mediaAssetId {
    final $$MediaAssetsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.mediaAssetId,
        referencedTable: $db.mediaAssets,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MediaAssetsTableAnnotationComposer(
              $db: $db,
              $table: $db.mediaAssets,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$PiecesTableAnnotationComposer get pieceId {
    final $$PiecesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.pieceId,
        referencedTable: $db.pieces,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PiecesTableAnnotationComposer(
              $db: $db,
              $table: $db.pieces,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ScoreVersionsTableAnnotationComposer get scoreVersionId {
    final $$ScoreVersionsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.scoreVersionId,
        referencedTable: $db.scoreVersions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ScoreVersionsTableAnnotationComposer(
              $db: $db,
              $table: $db.scoreVersions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$MediaMatchCandidatesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $MediaMatchCandidatesTable,
    MediaMatchCandidate,
    $$MediaMatchCandidatesTableFilterComposer,
    $$MediaMatchCandidatesTableOrderingComposer,
    $$MediaMatchCandidatesTableAnnotationComposer,
    $$MediaMatchCandidatesTableCreateCompanionBuilder,
    $$MediaMatchCandidatesTableUpdateCompanionBuilder,
    (MediaMatchCandidate, $$MediaMatchCandidatesTableReferences),
    MediaMatchCandidate,
    PrefetchHooks Function(
        {bool mediaAssetId, bool pieceId, bool scoreVersionId})> {
  $$MediaMatchCandidatesTableTableManager(
      _$AppDatabase db, $MediaMatchCandidatesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MediaMatchCandidatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MediaMatchCandidatesTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MediaMatchCandidatesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> mediaAssetId = const Value.absent(),
            Value<String> pieceId = const Value.absent(),
            Value<String> scoreVersionId = const Value.absent(),
            Value<double> similarityScore = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String?> aiNotes = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MediaMatchCandidatesCompanion(
            id: id,
            mediaAssetId: mediaAssetId,
            pieceId: pieceId,
            scoreVersionId: scoreVersionId,
            similarityScore: similarityScore,
            status: status,
            aiNotes: aiNotes,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String mediaAssetId,
            required String pieceId,
            required String scoreVersionId,
            required double similarityScore,
            required String status,
            Value<String?> aiNotes = const Value.absent(),
            required DateTime createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              MediaMatchCandidatesCompanion.insert(
            id: id,
            mediaAssetId: mediaAssetId,
            pieceId: pieceId,
            scoreVersionId: scoreVersionId,
            similarityScore: similarityScore,
            status: status,
            aiNotes: aiNotes,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$MediaMatchCandidatesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {mediaAssetId = false, pieceId = false, scoreVersionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (mediaAssetId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.mediaAssetId,
                    referencedTable: $$MediaMatchCandidatesTableReferences
                        ._mediaAssetIdTable(db),
                    referencedColumn: $$MediaMatchCandidatesTableReferences
                        ._mediaAssetIdTable(db)
                        .id,
                  ) as T;
                }
                if (pieceId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.pieceId,
                    referencedTable:
                        $$MediaMatchCandidatesTableReferences._pieceIdTable(db),
                    referencedColumn: $$MediaMatchCandidatesTableReferences
                        ._pieceIdTable(db)
                        .id,
                  ) as T;
                }
                if (scoreVersionId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.scoreVersionId,
                    referencedTable: $$MediaMatchCandidatesTableReferences
                        ._scoreVersionIdTable(db),
                    referencedColumn: $$MediaMatchCandidatesTableReferences
                        ._scoreVersionIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$MediaMatchCandidatesTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $MediaMatchCandidatesTable,
        MediaMatchCandidate,
        $$MediaMatchCandidatesTableFilterComposer,
        $$MediaMatchCandidatesTableOrderingComposer,
        $$MediaMatchCandidatesTableAnnotationComposer,
        $$MediaMatchCandidatesTableCreateCompanionBuilder,
        $$MediaMatchCandidatesTableUpdateCompanionBuilder,
        (MediaMatchCandidate, $$MediaMatchCandidatesTableReferences),
        MediaMatchCandidate,
        PrefetchHooks Function(
            {bool mediaAssetId, bool pieceId, bool scoreVersionId})>;
typedef $$ProcessingJobsTableCreateCompanionBuilder = ProcessingJobsCompanion
    Function({
  required String id,
  required String type,
  Value<String?> mediaAssetId,
  Value<String?> pieceId,
  Value<String?> scoreVersionId,
  required String status,
  Value<double?> progress,
  Value<String?> errorMessage,
  Value<String?> result,
  required DateTime createdAt,
  Value<DateTime?> completedAt,
  Value<int> rowid,
});
typedef $$ProcessingJobsTableUpdateCompanionBuilder = ProcessingJobsCompanion
    Function({
  Value<String> id,
  Value<String> type,
  Value<String?> mediaAssetId,
  Value<String?> pieceId,
  Value<String?> scoreVersionId,
  Value<String> status,
  Value<double?> progress,
  Value<String?> errorMessage,
  Value<String?> result,
  Value<DateTime> createdAt,
  Value<DateTime?> completedAt,
  Value<int> rowid,
});

final class $$ProcessingJobsTableReferences
    extends BaseReferences<_$AppDatabase, $ProcessingJobsTable, ProcessingJob> {
  $$ProcessingJobsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $PiecesTable _pieceIdTable(_$AppDatabase db) => db.pieces.createAlias(
      $_aliasNameGenerator(db.processingJobs.pieceId, db.pieces.id));

  $$PiecesTableProcessedTableManager? get pieceId {
    if ($_item.pieceId == null) return null;
    final manager = $$PiecesTableTableManager($_db, $_db.pieces)
        .filter((f) => f.id($_item.pieceId!));
    final item = $_typedResult.readTableOrNull(_pieceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$ProcessingJobsTableFilterComposer
    extends Composer<_$AppDatabase, $ProcessingJobsTable> {
  $$ProcessingJobsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mediaAssetId => $composableBuilder(
      column: $table.mediaAssetId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get scoreVersionId => $composableBuilder(
      column: $table.scoreVersionId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get progress => $composableBuilder(
      column: $table.progress, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get errorMessage => $composableBuilder(
      column: $table.errorMessage, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get result => $composableBuilder(
      column: $table.result, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => ColumnFilters(column));

  $$PiecesTableFilterComposer get pieceId {
    final $$PiecesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.pieceId,
        referencedTable: $db.pieces,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PiecesTableFilterComposer(
              $db: $db,
              $table: $db.pieces,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ProcessingJobsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProcessingJobsTable> {
  $$ProcessingJobsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mediaAssetId => $composableBuilder(
      column: $table.mediaAssetId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get scoreVersionId => $composableBuilder(
      column: $table.scoreVersionId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get progress => $composableBuilder(
      column: $table.progress, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get errorMessage => $composableBuilder(
      column: $table.errorMessage,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get result => $composableBuilder(
      column: $table.result, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => ColumnOrderings(column));

  $$PiecesTableOrderingComposer get pieceId {
    final $$PiecesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.pieceId,
        referencedTable: $db.pieces,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PiecesTableOrderingComposer(
              $db: $db,
              $table: $db.pieces,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ProcessingJobsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProcessingJobsTable> {
  $$ProcessingJobsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get mediaAssetId => $composableBuilder(
      column: $table.mediaAssetId, builder: (column) => column);

  GeneratedColumn<String> get scoreVersionId => $composableBuilder(
      column: $table.scoreVersionId, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<double> get progress =>
      $composableBuilder(column: $table.progress, builder: (column) => column);

  GeneratedColumn<String> get errorMessage => $composableBuilder(
      column: $table.errorMessage, builder: (column) => column);

  GeneratedColumn<String> get result =>
      $composableBuilder(column: $table.result, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => column);

  $$PiecesTableAnnotationComposer get pieceId {
    final $$PiecesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.pieceId,
        referencedTable: $db.pieces,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PiecesTableAnnotationComposer(
              $db: $db,
              $table: $db.pieces,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ProcessingJobsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ProcessingJobsTable,
    ProcessingJob,
    $$ProcessingJobsTableFilterComposer,
    $$ProcessingJobsTableOrderingComposer,
    $$ProcessingJobsTableAnnotationComposer,
    $$ProcessingJobsTableCreateCompanionBuilder,
    $$ProcessingJobsTableUpdateCompanionBuilder,
    (ProcessingJob, $$ProcessingJobsTableReferences),
    ProcessingJob,
    PrefetchHooks Function({bool pieceId})> {
  $$ProcessingJobsTableTableManager(
      _$AppDatabase db, $ProcessingJobsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProcessingJobsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProcessingJobsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProcessingJobsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<String?> mediaAssetId = const Value.absent(),
            Value<String?> pieceId = const Value.absent(),
            Value<String?> scoreVersionId = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<double?> progress = const Value.absent(),
            Value<String?> errorMessage = const Value.absent(),
            Value<String?> result = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> completedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ProcessingJobsCompanion(
            id: id,
            type: type,
            mediaAssetId: mediaAssetId,
            pieceId: pieceId,
            scoreVersionId: scoreVersionId,
            status: status,
            progress: progress,
            errorMessage: errorMessage,
            result: result,
            createdAt: createdAt,
            completedAt: completedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String type,
            Value<String?> mediaAssetId = const Value.absent(),
            Value<String?> pieceId = const Value.absent(),
            Value<String?> scoreVersionId = const Value.absent(),
            required String status,
            Value<double?> progress = const Value.absent(),
            Value<String?> errorMessage = const Value.absent(),
            Value<String?> result = const Value.absent(),
            required DateTime createdAt,
            Value<DateTime?> completedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ProcessingJobsCompanion.insert(
            id: id,
            type: type,
            mediaAssetId: mediaAssetId,
            pieceId: pieceId,
            scoreVersionId: scoreVersionId,
            status: status,
            progress: progress,
            errorMessage: errorMessage,
            result: result,
            createdAt: createdAt,
            completedAt: completedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$ProcessingJobsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({pieceId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (pieceId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.pieceId,
                    referencedTable:
                        $$ProcessingJobsTableReferences._pieceIdTable(db),
                    referencedColumn:
                        $$ProcessingJobsTableReferences._pieceIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$ProcessingJobsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ProcessingJobsTable,
    ProcessingJob,
    $$ProcessingJobsTableFilterComposer,
    $$ProcessingJobsTableOrderingComposer,
    $$ProcessingJobsTableAnnotationComposer,
    $$ProcessingJobsTableCreateCompanionBuilder,
    $$ProcessingJobsTableUpdateCompanionBuilder,
    (ProcessingJob, $$ProcessingJobsTableReferences),
    ProcessingJob,
    PrefetchHooks Function({bool pieceId})>;
typedef $$ReviewItemsTableCreateCompanionBuilder = ReviewItemsCompanion
    Function({
  required String id,
  required String pieceId,
  Value<String?> mediaAssetId,
  Value<String?> scoreVersionId,
  required String status,
  Value<String?> instructorNotes,
  Value<double?> overallRating,
  required DateTime createdAt,
  Value<DateTime?> reviewedAt,
  Value<int> rowid,
});
typedef $$ReviewItemsTableUpdateCompanionBuilder = ReviewItemsCompanion
    Function({
  Value<String> id,
  Value<String> pieceId,
  Value<String?> mediaAssetId,
  Value<String?> scoreVersionId,
  Value<String> status,
  Value<String?> instructorNotes,
  Value<double?> overallRating,
  Value<DateTime> createdAt,
  Value<DateTime?> reviewedAt,
  Value<int> rowid,
});

final class $$ReviewItemsTableReferences
    extends BaseReferences<_$AppDatabase, $ReviewItemsTable, ReviewItem> {
  $$ReviewItemsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PiecesTable _pieceIdTable(_$AppDatabase db) => db.pieces
      .createAlias($_aliasNameGenerator(db.reviewItems.pieceId, db.pieces.id));

  $$PiecesTableProcessedTableManager? get pieceId {
    if ($_item.pieceId == null) return null;
    final manager = $$PiecesTableTableManager($_db, $_db.pieces)
        .filter((f) => f.id($_item.pieceId!));
    final item = $_typedResult.readTableOrNull(_pieceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$ReviewItemsTableFilterComposer
    extends Composer<_$AppDatabase, $ReviewItemsTable> {
  $$ReviewItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mediaAssetId => $composableBuilder(
      column: $table.mediaAssetId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get scoreVersionId => $composableBuilder(
      column: $table.scoreVersionId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get instructorNotes => $composableBuilder(
      column: $table.instructorNotes,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get overallRating => $composableBuilder(
      column: $table.overallRating, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get reviewedAt => $composableBuilder(
      column: $table.reviewedAt, builder: (column) => ColumnFilters(column));

  $$PiecesTableFilterComposer get pieceId {
    final $$PiecesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.pieceId,
        referencedTable: $db.pieces,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PiecesTableFilterComposer(
              $db: $db,
              $table: $db.pieces,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ReviewItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $ReviewItemsTable> {
  $$ReviewItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mediaAssetId => $composableBuilder(
      column: $table.mediaAssetId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get scoreVersionId => $composableBuilder(
      column: $table.scoreVersionId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get instructorNotes => $composableBuilder(
      column: $table.instructorNotes,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get overallRating => $composableBuilder(
      column: $table.overallRating,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get reviewedAt => $composableBuilder(
      column: $table.reviewedAt, builder: (column) => ColumnOrderings(column));

  $$PiecesTableOrderingComposer get pieceId {
    final $$PiecesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.pieceId,
        referencedTable: $db.pieces,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PiecesTableOrderingComposer(
              $db: $db,
              $table: $db.pieces,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ReviewItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReviewItemsTable> {
  $$ReviewItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get mediaAssetId => $composableBuilder(
      column: $table.mediaAssetId, builder: (column) => column);

  GeneratedColumn<String> get scoreVersionId => $composableBuilder(
      column: $table.scoreVersionId, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get instructorNotes => $composableBuilder(
      column: $table.instructorNotes, builder: (column) => column);

  GeneratedColumn<double> get overallRating => $composableBuilder(
      column: $table.overallRating, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get reviewedAt => $composableBuilder(
      column: $table.reviewedAt, builder: (column) => column);

  $$PiecesTableAnnotationComposer get pieceId {
    final $$PiecesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.pieceId,
        referencedTable: $db.pieces,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PiecesTableAnnotationComposer(
              $db: $db,
              $table: $db.pieces,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ReviewItemsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ReviewItemsTable,
    ReviewItem,
    $$ReviewItemsTableFilterComposer,
    $$ReviewItemsTableOrderingComposer,
    $$ReviewItemsTableAnnotationComposer,
    $$ReviewItemsTableCreateCompanionBuilder,
    $$ReviewItemsTableUpdateCompanionBuilder,
    (ReviewItem, $$ReviewItemsTableReferences),
    ReviewItem,
    PrefetchHooks Function({bool pieceId})> {
  $$ReviewItemsTableTableManager(_$AppDatabase db, $ReviewItemsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReviewItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReviewItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReviewItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> pieceId = const Value.absent(),
            Value<String?> mediaAssetId = const Value.absent(),
            Value<String?> scoreVersionId = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String?> instructorNotes = const Value.absent(),
            Value<double?> overallRating = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> reviewedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ReviewItemsCompanion(
            id: id,
            pieceId: pieceId,
            mediaAssetId: mediaAssetId,
            scoreVersionId: scoreVersionId,
            status: status,
            instructorNotes: instructorNotes,
            overallRating: overallRating,
            createdAt: createdAt,
            reviewedAt: reviewedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String pieceId,
            Value<String?> mediaAssetId = const Value.absent(),
            Value<String?> scoreVersionId = const Value.absent(),
            required String status,
            Value<String?> instructorNotes = const Value.absent(),
            Value<double?> overallRating = const Value.absent(),
            required DateTime createdAt,
            Value<DateTime?> reviewedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ReviewItemsCompanion.insert(
            id: id,
            pieceId: pieceId,
            mediaAssetId: mediaAssetId,
            scoreVersionId: scoreVersionId,
            status: status,
            instructorNotes: instructorNotes,
            overallRating: overallRating,
            createdAt: createdAt,
            reviewedAt: reviewedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$ReviewItemsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({pieceId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (pieceId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.pieceId,
                    referencedTable:
                        $$ReviewItemsTableReferences._pieceIdTable(db),
                    referencedColumn:
                        $$ReviewItemsTableReferences._pieceIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$ReviewItemsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ReviewItemsTable,
    ReviewItem,
    $$ReviewItemsTableFilterComposer,
    $$ReviewItemsTableOrderingComposer,
    $$ReviewItemsTableAnnotationComposer,
    $$ReviewItemsTableCreateCompanionBuilder,
    $$ReviewItemsTableUpdateCompanionBuilder,
    (ReviewItem, $$ReviewItemsTableReferences),
    ReviewItem,
    PrefetchHooks Function({bool pieceId})>;
typedef $$PieceHistoryDraftsTableCreateCompanionBuilder
    = PieceHistoryDraftsCompanion Function({
  required String id,
  required String pieceId,
  required int totalPracticeSessions,
  required BigInt totalPracticeTimeMs,
  Value<int?> lastPlayedPage,
  Value<String?> currentFocus,
  Value<DateTime?> lastPracticedAt,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$PieceHistoryDraftsTableUpdateCompanionBuilder
    = PieceHistoryDraftsCompanion Function({
  Value<String> id,
  Value<String> pieceId,
  Value<int> totalPracticeSessions,
  Value<BigInt> totalPracticeTimeMs,
  Value<int?> lastPlayedPage,
  Value<String?> currentFocus,
  Value<DateTime?> lastPracticedAt,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

final class $$PieceHistoryDraftsTableReferences extends BaseReferences<
    _$AppDatabase, $PieceHistoryDraftsTable, PieceHistoryDraft> {
  $$PieceHistoryDraftsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $PiecesTable _pieceIdTable(_$AppDatabase db) => db.pieces.createAlias(
      $_aliasNameGenerator(db.pieceHistoryDrafts.pieceId, db.pieces.id));

  $$PiecesTableProcessedTableManager? get pieceId {
    if ($_item.pieceId == null) return null;
    final manager = $$PiecesTableTableManager($_db, $_db.pieces)
        .filter((f) => f.id($_item.pieceId!));
    final item = $_typedResult.readTableOrNull(_pieceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$PieceHistoryDraftsTableFilterComposer
    extends Composer<_$AppDatabase, $PieceHistoryDraftsTable> {
  $$PieceHistoryDraftsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get totalPracticeSessions => $composableBuilder(
      column: $table.totalPracticeSessions,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<BigInt> get totalPracticeTimeMs => $composableBuilder(
      column: $table.totalPracticeTimeMs,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get lastPlayedPage => $composableBuilder(
      column: $table.lastPlayedPage,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currentFocus => $composableBuilder(
      column: $table.currentFocus, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastPracticedAt => $composableBuilder(
      column: $table.lastPracticedAt,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  $$PiecesTableFilterComposer get pieceId {
    final $$PiecesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.pieceId,
        referencedTable: $db.pieces,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PiecesTableFilterComposer(
              $db: $db,
              $table: $db.pieces,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PieceHistoryDraftsTableOrderingComposer
    extends Composer<_$AppDatabase, $PieceHistoryDraftsTable> {
  $$PieceHistoryDraftsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get totalPracticeSessions => $composableBuilder(
      column: $table.totalPracticeSessions,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<BigInt> get totalPracticeTimeMs => $composableBuilder(
      column: $table.totalPracticeTimeMs,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get lastPlayedPage => $composableBuilder(
      column: $table.lastPlayedPage,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currentFocus => $composableBuilder(
      column: $table.currentFocus,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastPracticedAt => $composableBuilder(
      column: $table.lastPracticedAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  $$PiecesTableOrderingComposer get pieceId {
    final $$PiecesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.pieceId,
        referencedTable: $db.pieces,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PiecesTableOrderingComposer(
              $db: $db,
              $table: $db.pieces,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PieceHistoryDraftsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PieceHistoryDraftsTable> {
  $$PieceHistoryDraftsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get totalPracticeSessions => $composableBuilder(
      column: $table.totalPracticeSessions, builder: (column) => column);

  GeneratedColumn<BigInt> get totalPracticeTimeMs => $composableBuilder(
      column: $table.totalPracticeTimeMs, builder: (column) => column);

  GeneratedColumn<int> get lastPlayedPage => $composableBuilder(
      column: $table.lastPlayedPage, builder: (column) => column);

  GeneratedColumn<String> get currentFocus => $composableBuilder(
      column: $table.currentFocus, builder: (column) => column);

  GeneratedColumn<DateTime> get lastPracticedAt => $composableBuilder(
      column: $table.lastPracticedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$PiecesTableAnnotationComposer get pieceId {
    final $$PiecesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.pieceId,
        referencedTable: $db.pieces,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PiecesTableAnnotationComposer(
              $db: $db,
              $table: $db.pieces,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PieceHistoryDraftsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PieceHistoryDraftsTable,
    PieceHistoryDraft,
    $$PieceHistoryDraftsTableFilterComposer,
    $$PieceHistoryDraftsTableOrderingComposer,
    $$PieceHistoryDraftsTableAnnotationComposer,
    $$PieceHistoryDraftsTableCreateCompanionBuilder,
    $$PieceHistoryDraftsTableUpdateCompanionBuilder,
    (PieceHistoryDraft, $$PieceHistoryDraftsTableReferences),
    PieceHistoryDraft,
    PrefetchHooks Function({bool pieceId})> {
  $$PieceHistoryDraftsTableTableManager(
      _$AppDatabase db, $PieceHistoryDraftsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PieceHistoryDraftsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PieceHistoryDraftsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PieceHistoryDraftsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> pieceId = const Value.absent(),
            Value<int> totalPracticeSessions = const Value.absent(),
            Value<BigInt> totalPracticeTimeMs = const Value.absent(),
            Value<int?> lastPlayedPage = const Value.absent(),
            Value<String?> currentFocus = const Value.absent(),
            Value<DateTime?> lastPracticedAt = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PieceHistoryDraftsCompanion(
            id: id,
            pieceId: pieceId,
            totalPracticeSessions: totalPracticeSessions,
            totalPracticeTimeMs: totalPracticeTimeMs,
            lastPlayedPage: lastPlayedPage,
            currentFocus: currentFocus,
            lastPracticedAt: lastPracticedAt,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String pieceId,
            required int totalPracticeSessions,
            required BigInt totalPracticeTimeMs,
            Value<int?> lastPlayedPage = const Value.absent(),
            Value<String?> currentFocus = const Value.absent(),
            Value<DateTime?> lastPracticedAt = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              PieceHistoryDraftsCompanion.insert(
            id: id,
            pieceId: pieceId,
            totalPracticeSessions: totalPracticeSessions,
            totalPracticeTimeMs: totalPracticeTimeMs,
            lastPlayedPage: lastPlayedPage,
            currentFocus: currentFocus,
            lastPracticedAt: lastPracticedAt,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$PieceHistoryDraftsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({pieceId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (pieceId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.pieceId,
                    referencedTable:
                        $$PieceHistoryDraftsTableReferences._pieceIdTable(db),
                    referencedColumn: $$PieceHistoryDraftsTableReferences
                        ._pieceIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$PieceHistoryDraftsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PieceHistoryDraftsTable,
    PieceHistoryDraft,
    $$PieceHistoryDraftsTableFilterComposer,
    $$PieceHistoryDraftsTableOrderingComposer,
    $$PieceHistoryDraftsTableAnnotationComposer,
    $$PieceHistoryDraftsTableCreateCompanionBuilder,
    $$PieceHistoryDraftsTableUpdateCompanionBuilder,
    (PieceHistoryDraft, $$PieceHistoryDraftsTableReferences),
    PieceHistoryDraft,
    PrefetchHooks Function({bool pieceId})>;
typedef $$SyncStatesTableCreateCompanionBuilder = SyncStatesCompanion Function({
  required String entityType,
  Value<String?> entityId,
  required String lastSyncHash,
  required DateTime lastSyncAt,
  required String lastDirection,
  required String status,
  Value<String?> errorMessage,
  Value<int> rowid,
});
typedef $$SyncStatesTableUpdateCompanionBuilder = SyncStatesCompanion Function({
  Value<String> entityType,
  Value<String?> entityId,
  Value<String> lastSyncHash,
  Value<DateTime> lastSyncAt,
  Value<String> lastDirection,
  Value<String> status,
  Value<String?> errorMessage,
  Value<int> rowid,
});

class $$SyncStatesTableFilterComposer
    extends Composer<_$AppDatabase, $SyncStatesTable> {
  $$SyncStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get entityId => $composableBuilder(
      column: $table.entityId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastSyncHash => $composableBuilder(
      column: $table.lastSyncHash, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastSyncAt => $composableBuilder(
      column: $table.lastSyncAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastDirection => $composableBuilder(
      column: $table.lastDirection, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get errorMessage => $composableBuilder(
      column: $table.errorMessage, builder: (column) => ColumnFilters(column));
}

class $$SyncStatesTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncStatesTable> {
  $$SyncStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get entityId => $composableBuilder(
      column: $table.entityId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastSyncHash => $composableBuilder(
      column: $table.lastSyncHash,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastSyncAt => $composableBuilder(
      column: $table.lastSyncAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastDirection => $composableBuilder(
      column: $table.lastDirection,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get errorMessage => $composableBuilder(
      column: $table.errorMessage,
      builder: (column) => ColumnOrderings(column));
}

class $$SyncStatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncStatesTable> {
  $$SyncStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get lastSyncHash => $composableBuilder(
      column: $table.lastSyncHash, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSyncAt => $composableBuilder(
      column: $table.lastSyncAt, builder: (column) => column);

  GeneratedColumn<String> get lastDirection => $composableBuilder(
      column: $table.lastDirection, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get errorMessage => $composableBuilder(
      column: $table.errorMessage, builder: (column) => column);
}

class $$SyncStatesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SyncStatesTable,
    SyncState,
    $$SyncStatesTableFilterComposer,
    $$SyncStatesTableOrderingComposer,
    $$SyncStatesTableAnnotationComposer,
    $$SyncStatesTableCreateCompanionBuilder,
    $$SyncStatesTableUpdateCompanionBuilder,
    (SyncState, BaseReferences<_$AppDatabase, $SyncStatesTable, SyncState>),
    SyncState,
    PrefetchHooks Function()> {
  $$SyncStatesTableTableManager(_$AppDatabase db, $SyncStatesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncStatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> entityType = const Value.absent(),
            Value<String?> entityId = const Value.absent(),
            Value<String> lastSyncHash = const Value.absent(),
            Value<DateTime> lastSyncAt = const Value.absent(),
            Value<String> lastDirection = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String?> errorMessage = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncStatesCompanion(
            entityType: entityType,
            entityId: entityId,
            lastSyncHash: lastSyncHash,
            lastSyncAt: lastSyncAt,
            lastDirection: lastDirection,
            status: status,
            errorMessage: errorMessage,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String entityType,
            Value<String?> entityId = const Value.absent(),
            required String lastSyncHash,
            required DateTime lastSyncAt,
            required String lastDirection,
            required String status,
            Value<String?> errorMessage = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncStatesCompanion.insert(
            entityType: entityType,
            entityId: entityId,
            lastSyncHash: lastSyncHash,
            lastSyncAt: lastSyncAt,
            lastDirection: lastDirection,
            status: status,
            errorMessage: errorMessage,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SyncStatesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SyncStatesTable,
    SyncState,
    $$SyncStatesTableFilterComposer,
    $$SyncStatesTableOrderingComposer,
    $$SyncStatesTableAnnotationComposer,
    $$SyncStatesTableCreateCompanionBuilder,
    $$SyncStatesTableUpdateCompanionBuilder,
    (SyncState, BaseReferences<_$AppDatabase, $SyncStatesTable, SyncState>),
    SyncState,
    PrefetchHooks Function()>;
typedef $$PracticeRecordingsTableCreateCompanionBuilder
    = PracticeRecordingsCompanion Function({
  required String id,
  required String pieceId,
  required String profileId,
  Value<String?> scoreVersionId,
  required String filePath,
  required int durationMs,
  required DateTime createdAt,
  Value<bool> isSentToTeacher,
  Value<int> rowid,
});
typedef $$PracticeRecordingsTableUpdateCompanionBuilder
    = PracticeRecordingsCompanion Function({
  Value<String> id,
  Value<String> pieceId,
  Value<String> profileId,
  Value<String?> scoreVersionId,
  Value<String> filePath,
  Value<int> durationMs,
  Value<DateTime> createdAt,
  Value<bool> isSentToTeacher,
  Value<int> rowid,
});

final class $$PracticeRecordingsTableReferences extends BaseReferences<
    _$AppDatabase, $PracticeRecordingsTable, PracticeRecordingRow> {
  $$PracticeRecordingsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $PiecesTable _pieceIdTable(_$AppDatabase db) => db.pieces.createAlias(
      $_aliasNameGenerator(db.practiceRecordings.pieceId, db.pieces.id));

  $$PiecesTableProcessedTableManager? get pieceId {
    if ($_item.pieceId == null) return null;
    final manager = $$PiecesTableTableManager($_db, $_db.pieces)
        .filter((f) => f.id($_item.pieceId!));
    final item = $_typedResult.readTableOrNull(_pieceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$PracticeRecordingsTableFilterComposer
    extends Composer<_$AppDatabase, $PracticeRecordingsTable> {
  $$PracticeRecordingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get profileId => $composableBuilder(
      column: $table.profileId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get scoreVersionId => $composableBuilder(
      column: $table.scoreVersionId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get durationMs => $composableBuilder(
      column: $table.durationMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isSentToTeacher => $composableBuilder(
      column: $table.isSentToTeacher,
      builder: (column) => ColumnFilters(column));

  $$PiecesTableFilterComposer get pieceId {
    final $$PiecesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.pieceId,
        referencedTable: $db.pieces,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PiecesTableFilterComposer(
              $db: $db,
              $table: $db.pieces,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PracticeRecordingsTableOrderingComposer
    extends Composer<_$AppDatabase, $PracticeRecordingsTable> {
  $$PracticeRecordingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get profileId => $composableBuilder(
      column: $table.profileId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get scoreVersionId => $composableBuilder(
      column: $table.scoreVersionId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get durationMs => $composableBuilder(
      column: $table.durationMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isSentToTeacher => $composableBuilder(
      column: $table.isSentToTeacher,
      builder: (column) => ColumnOrderings(column));

  $$PiecesTableOrderingComposer get pieceId {
    final $$PiecesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.pieceId,
        referencedTable: $db.pieces,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PiecesTableOrderingComposer(
              $db: $db,
              $table: $db.pieces,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PracticeRecordingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PracticeRecordingsTable> {
  $$PracticeRecordingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<String> get scoreVersionId => $composableBuilder(
      column: $table.scoreVersionId, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
      column: $table.durationMs, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get isSentToTeacher => $composableBuilder(
      column: $table.isSentToTeacher, builder: (column) => column);

  $$PiecesTableAnnotationComposer get pieceId {
    final $$PiecesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.pieceId,
        referencedTable: $db.pieces,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PiecesTableAnnotationComposer(
              $db: $db,
              $table: $db.pieces,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PracticeRecordingsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PracticeRecordingsTable,
    PracticeRecordingRow,
    $$PracticeRecordingsTableFilterComposer,
    $$PracticeRecordingsTableOrderingComposer,
    $$PracticeRecordingsTableAnnotationComposer,
    $$PracticeRecordingsTableCreateCompanionBuilder,
    $$PracticeRecordingsTableUpdateCompanionBuilder,
    (PracticeRecordingRow, $$PracticeRecordingsTableReferences),
    PracticeRecordingRow,
    PrefetchHooks Function({bool pieceId})> {
  $$PracticeRecordingsTableTableManager(
      _$AppDatabase db, $PracticeRecordingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PracticeRecordingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PracticeRecordingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PracticeRecordingsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> pieceId = const Value.absent(),
            Value<String> profileId = const Value.absent(),
            Value<String?> scoreVersionId = const Value.absent(),
            Value<String> filePath = const Value.absent(),
            Value<int> durationMs = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<bool> isSentToTeacher = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PracticeRecordingsCompanion(
            id: id,
            pieceId: pieceId,
            profileId: profileId,
            scoreVersionId: scoreVersionId,
            filePath: filePath,
            durationMs: durationMs,
            createdAt: createdAt,
            isSentToTeacher: isSentToTeacher,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String pieceId,
            required String profileId,
            Value<String?> scoreVersionId = const Value.absent(),
            required String filePath,
            required int durationMs,
            required DateTime createdAt,
            Value<bool> isSentToTeacher = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PracticeRecordingsCompanion.insert(
            id: id,
            pieceId: pieceId,
            profileId: profileId,
            scoreVersionId: scoreVersionId,
            filePath: filePath,
            durationMs: durationMs,
            createdAt: createdAt,
            isSentToTeacher: isSentToTeacher,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$PracticeRecordingsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({pieceId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (pieceId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.pieceId,
                    referencedTable:
                        $$PracticeRecordingsTableReferences._pieceIdTable(db),
                    referencedColumn: $$PracticeRecordingsTableReferences
                        ._pieceIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$PracticeRecordingsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PracticeRecordingsTable,
    PracticeRecordingRow,
    $$PracticeRecordingsTableFilterComposer,
    $$PracticeRecordingsTableOrderingComposer,
    $$PracticeRecordingsTableAnnotationComposer,
    $$PracticeRecordingsTableCreateCompanionBuilder,
    $$PracticeRecordingsTableUpdateCompanionBuilder,
    (PracticeRecordingRow, $$PracticeRecordingsTableReferences),
    PracticeRecordingRow,
    PrefetchHooks Function({bool pieceId})>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ProfilesTableTableManager get profiles =>
      $$ProfilesTableTableManager(_db, _db.profiles);
  $$PiecesTableTableManager get pieces =>
      $$PiecesTableTableManager(_db, _db.pieces);
  $$ScoreVersionsTableTableManager get scoreVersions =>
      $$ScoreVersionsTableTableManager(_db, _db.scoreVersions);
  $$AnnotationLayersTableTableManager get annotationLayers =>
      $$AnnotationLayersTableTableManager(_db, _db.annotationLayers);
  $$AnnotationStrokesTableTableManager get annotationStrokes =>
      $$AnnotationStrokesTableTableManager(_db, _db.annotationStrokes);
  $$AnnotationNotesTableTableManager get annotationNotes =>
      $$AnnotationNotesTableTableManager(_db, _db.annotationNotes);
  $$MediaAssetsTableTableManager get mediaAssets =>
      $$MediaAssetsTableTableManager(_db, _db.mediaAssets);
  $$MediaMatchCandidatesTableTableManager get mediaMatchCandidates =>
      $$MediaMatchCandidatesTableTableManager(_db, _db.mediaMatchCandidates);
  $$ProcessingJobsTableTableManager get processingJobs =>
      $$ProcessingJobsTableTableManager(_db, _db.processingJobs);
  $$ReviewItemsTableTableManager get reviewItems =>
      $$ReviewItemsTableTableManager(_db, _db.reviewItems);
  $$PieceHistoryDraftsTableTableManager get pieceHistoryDrafts =>
      $$PieceHistoryDraftsTableTableManager(_db, _db.pieceHistoryDrafts);
  $$SyncStatesTableTableManager get syncStates =>
      $$SyncStatesTableTableManager(_db, _db.syncStates);
  $$PracticeRecordingsTableTableManager get practiceRecordings =>
      $$PracticeRecordingsTableTableManager(_db, _db.practiceRecordings);
}

mixin _$AppDatabaseDaoMixin on DatabaseAccessor<AppDatabase> {
  $PiecesTable get pieces => attachedDatabase.pieces;
  $PracticeRecordingsTable get practiceRecordings =>
      attachedDatabase.practiceRecordings;
}
