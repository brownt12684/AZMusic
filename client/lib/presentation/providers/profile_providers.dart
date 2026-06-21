import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import '../../core/config/app_config.dart';
import '../../domain/entities/profile.dart';

final localStudentProfilesProvider =
    NotifierProvider<LocalStudentProfilesNotifier, List<Profile>>(
  LocalStudentProfilesNotifier.new,
);

class LocalStudentProfilesNotifier extends Notifier<List<Profile>> {
  @override
  List<Profile> build() {
    final profiles = <Profile>[];
    for (final map in AppConfig.loadStudentProfileMaps()) {
      try {
        final profile = Profile.fromMap(map);
        if (profile.role == ProfileRole.student) {
          profiles.add(profile);
        }
      } catch (_) {
        // Ignore corrupt local setup data instead of blocking login.
      }
    }
    return profiles;
  }

  Future<Profile> addStudent({
    required String displayName,
    InstrumentType instrument = InstrumentType.cello,
    String? pin,
  }) async {
    final trimmedName = displayName.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Student name is required.');
    }

    // Auto-PIN policy: when adding the 2nd student, PIN becomes mandatory.
    final willHaveMultipleStudents = state.isNotEmpty;
    final trimmedPin = pin?.trim();
    if (willHaveMultipleStudents && (trimmedPin == null || trimmedPin.isEmpty)) {
      throw ArgumentError(
        'PIN is required when there are multiple students on this device.',
      );
    }

    final now = DateTime.now().toUtc();
    final profile = Profile(
      id: _studentIdFor(trimmedName, state),
      displayName: trimmedName,
      role: ProfileRole.student,
      instrument: instrument,
      subtitle: _studentSubtitle(instrument),
      localPin: willHaveMultipleStudents ? (trimmedPin ?? '') : null,
      createdAt: now,
      updatedAt: now,
    );
    state = [...state, profile];
    await AppConfig.saveStudentProfileMaps(
      state.map((profile) => profile.toMap()).toList(growable: false),
    );
    return profile;
  }

  Future<void> editStudent({
    required String id,
    String? displayName,
    InstrumentType? instrument,
    String? pin,
  }) async {
    final index = state.indexWhere((p) => p.id == id);
    if (index < 0) {
      throw StateError('Student with id "$id" not found.');
    }

    final existing = state[index];
    final trimmedName = (displayName ?? existing.displayName).trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Student name is required.');
    }

    // Auto-PIN policy: when 2+ students exist, PIN is mandatory.
    final hasMultipleStudents = state.length >= 2;
    final trimmedPin = pin?.trim() ?? '';

    // If clearing the PIN but multiple students remain, reject.
    if (pin == null || trimmedPin.isEmpty) {
      if (hasMultipleStudents && (existing.localPin?.isNotEmpty ?? false)) {
        throw ArgumentError(
          'PIN cannot be cleared while there are multiple students on this device.',
        );
      }
    } else if (trimmedPin.length < 4) {
      throw ArgumentError('PIN must be at least 4 digits.');
    }

    final updated = existing.copyWith(
      displayName: trimmedName,
      instrument: instrument ?? existing.instrument,
      localPin: hasMultipleStudents
          ? (trimmedPin.isNotEmpty ? trimmedPin : null)
          : (trimmedPin.isNotEmpty ? trimmedPin : null),
      updatedAt: DateTime.now().toUtc(),
    );

    state = [...state.sublist(0, index), updated, ...state.sublist(index + 1)];
    await AppConfig.saveStudentProfileMaps(
      state.map((profile) => profile.toMap()).toList(growable: false),
    );
  }

  Future<void> removeStudent(String id) async {
    final index = state.indexWhere((p) => p.id == id);
    if (index < 0) {
      throw StateError('Student with id "$id" not found.');
    }

    // Enforce PIN policy on remaining students:
    // After removal, if count >= 2, all remaining must have PINs.
    final remainingAfterRemoval = state.length - 1;
    if (remainingAfterRemoval >= 2) {
      for (final profile in state) {
        if (profile.id != id && (profile.localPin?.isEmpty ?? true)) {
          throw ArgumentError(
            'All students require a PIN when there are multiple students on this device.',
          );
        }
      }
    }

    state = [...state.sublist(0, index), ...state.sublist(index + 1)];
    await AppConfig.saveStudentProfileMaps(
      state.map((profile) => profile.toMap()).toList(growable: false),
    );
    // Return the removed student's ID for caller to unattribute pieces.
    _lastRemovedStudentId = id;
  }

  /// The ID of the most recently removed student, used by callers to
  /// unattribute their pieces before persisting changes.
  String? get lastRemovedStudentId => _lastRemovedStudentId;
  String? _lastRemovedStudentId;
}

final availableProfilesProvider = Provider<List<Profile>>((ref) {
  final now = DateTime.utc(2026, 5, 19);
  final localStudents = ref.watch(localStudentProfilesProvider);
  return buildAvailableProfilesForState(
    now: now,
    localStudents: localStudents,
    isProductionBuild: AppConfig.isProductionBuild,
    hasParentPin: AppConfig.hasParentPin,
    pairedProfileId: AppConfig.pairedProfileId,
    pairedProfileRole: AppConfig.pairedProfileRole,
    pairedProfileName: AppConfig.pairedProfileName,
  );
});

@visibleForTesting
List<Profile> buildAvailableProfilesForState({
  required DateTime now,
  required List<Profile> localStudents,
  required bool isProductionBuild,
  required bool hasParentPin,
  String? pairedProfileId,
  String? pairedProfileRole,
  String? pairedProfileName,
}) {
  final parentProfile = Profile(
    id: 'parent-main',
    displayName: 'Parent',
    role: ProfileRole.parent,
    parentPinRequired: true,
    subtitle: hasParentPin ? 'PIN required' : 'Set up parent PIN',
    createdAt: now,
    updatedAt: now,
  );

  if (isProductionBuild) {
    final pairedStudent = _pairedStudentProfile(
      now: now,
      pairedProfileId: pairedProfileId,
      pairedProfileRole: pairedProfileRole,
      pairedProfileName: pairedProfileName,
    );
    if (pairedStudent != null) {
      return _deduplicateProfiles([pairedStudent]);
    }
    return _deduplicateProfiles([...localStudents, parentProfile]);
  }

  return _deduplicateProfiles([
    Profile(
      id: 'student-alyse',
      displayName: 'Alyse',
      role: ProfileRole.student,
      isDefaultOnDevice: true,
      instrument: InstrumentType.violin,
      gradeLevel: 4,
      subtitle: 'Student - Grade 4',
      createdAt: now,
      updatedAt: now,
    ),
    Profile(
      id: 'student-zora',
      displayName: 'Zora',
      role: ProfileRole.student,
      instrument: InstrumentType.violin,
      gradeLevel: 2,
      subtitle: 'Student - Grade 2',
      createdAt: now,
      updatedAt: now,
    ),
    ...localStudents,
    parentProfile,
  ]);
}

Profile? _pairedStudentProfile({
  required DateTime now,
  String? pairedProfileId,
  String? pairedProfileRole,
  String? pairedProfileName,
}) {
  if (pairedProfileRole != 'student' ||
      pairedProfileId == null ||
      pairedProfileId.isEmpty) {
    return null;
  }
  return Profile(
    id: pairedProfileId,
    displayName: pairedProfileName ?? 'Student',
    role: ProfileRole.student,
    isDefaultOnDevice: true,
    subtitle: 'Paired student device',
    createdAt: now,
    updatedAt: now,
  );
}

final defaultDeviceProfileProvider = Provider<Profile>((ref) {
  final profiles = ref.watch(availableProfilesProvider);
  return profiles.firstWhere(
    (profile) => profile.isDefaultOnDevice,
    orElse: () => profiles.first,
  );
});

final selectedProfileIdProvider = StateProvider<String?>(
  (ref) => ref.watch(defaultDeviceProfileProvider).id,
);

final activeProfileProvider = Provider<Profile>((ref) {
  final profiles = ref.watch(availableProfilesProvider);
  final selectedId = ref.watch(selectedProfileIdProvider);
  for (final profile in profiles) {
    if (profile.id == selectedId) {
      return profile;
    }
  }
  return profiles.first;
});

final activeStudentProfileProvider = Provider<Profile?>((ref) {
  final profile = ref.watch(activeProfileProvider);
  if (profile.role == ProfileRole.student) {
    return profile;
  }
  return null;
});

final studentProfilesProvider = Provider<List<Profile>>((ref) {
  return ref
      .watch(availableProfilesProvider)
      .where((profile) => profile.role == ProfileRole.student)
      .toList(growable: false);
});

List<Profile> _deduplicateProfiles(List<Profile> profiles) {
  final seen = <String>{};
  final result = <Profile>[];
  for (final profile in profiles) {
    if (seen.add(profile.id)) {
      result.add(profile);
    }
  }
  return result;
}

String _studentIdFor(String displayName, List<Profile> existingProfiles) {
  final slug = displayName
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  final baseId = 'student-${slug.isEmpty ? 'new' : slug}';
  final existingIds = existingProfiles.map((profile) => profile.id).toSet();
  var candidate = baseId;
  var suffix = 2;
  while (existingIds.contains(candidate)) {
    candidate = '$baseId-$suffix';
    suffix += 1;
  }
  return candidate;
}

String _studentSubtitle(InstrumentType instrument) {
  return 'Student - ${_instrumentLabel(instrument)}';
}

String _instrumentLabel(InstrumentType instrument) {
  switch (instrument) {
    case InstrumentType.violin:
      return 'Violin';
    case InstrumentType.viola:
      return 'Viola';
    case InstrumentType.cello:
      return 'Cello';
    case InstrumentType.doubleBass:
      return 'Double bass';
    case InstrumentType.guitar:
      return 'Guitar';
    case InstrumentType.piano:
      return 'Piano';
    case InstrumentType.other:
      return 'Other';
  }
}
