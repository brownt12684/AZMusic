import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../domain/entities/profile.dart';

final availableProfilesProvider = Provider<List<Profile>>((ref) {
  final now = DateTime.utc(2026, 5, 19);
  if (AppConfig.isProductionBuild) {
    final profiles = <Profile>[
      Profile(
        id: 'parent-main',
        displayName: 'Parent',
        role: ProfileRole.parent,
        parentPinRequired: true,
        localPin: '0000',
        subtitle: 'PIN required',
        createdAt: now,
        updatedAt: now,
      ),
    ];
    if (AppConfig.pairedProfileRole == 'student' &&
        AppConfig.pairedProfileId != null) {
      profiles.insert(
        0,
        Profile(
          id: AppConfig.pairedProfileId!,
          displayName: AppConfig.pairedProfileName ?? 'Student',
          role: ProfileRole.student,
          isDefaultOnDevice: true,
          subtitle: 'Paired student device',
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    return profiles;
  }
  return [
    Profile(
      id: 'student-alyse',
      displayName: 'Alyse',
      role: ProfileRole.student,
      isDefaultOnDevice: true,
      instrument: InstrumentType.violin,
      gradeLevel: 4,
      subtitle: 'Student · Grade 4',
      createdAt: now,
      updatedAt: now,
    ),
    Profile(
      id: 'student-zora',
      displayName: 'Zora',
      role: ProfileRole.student,
      localPin: '0000',
      instrument: InstrumentType.violin,
      gradeLevel: 2,
      subtitle: 'Student · Grade 2 · PIN',
      createdAt: now,
      updatedAt: now,
    ),
    Profile(
      id: 'parent-main',
      displayName: 'Parent',
      role: ProfileRole.parent,
      parentPinRequired: true,
      localPin: '0000',
      subtitle: 'PIN required',
      createdAt: now,
      updatedAt: now,
    ),
  ];
});

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
