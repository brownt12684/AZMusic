import 'package:azmusic/domain/entities/profile.dart';
import 'package:azmusic/presentation/providers/profile_providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildAvailableProfilesForState', () {
    test('production student devices expose only the paired student profile',
        () {
      final profiles = buildAvailableProfilesForState(
        now: DateTime.utc(2026, 6, 4),
        localStudents: const [],
        isProductionBuild: true,
        hasParentPin: true,
        pairedProfileId: 'student-kai',
        pairedProfileRole: 'student',
        pairedProfileName: 'Kai',
      );

      expect(profiles, hasLength(1));
      expect(profiles.single.id, 'student-kai');
      expect(profiles.single.displayName, 'Kai');
      expect(profiles.single.role, ProfileRole.student);
      expect(profiles.single.isDefaultOnDevice, isTrue);
    });

    test('production parent devices still expose the parent profile', () {
      final profiles = buildAvailableProfilesForState(
        now: DateTime.utc(2026, 6, 4),
        localStudents: const [],
        isProductionBuild: true,
        hasParentPin: false,
      );

      expect(profiles, hasLength(1));
      expect(profiles.single.id, 'parent-main');
      expect(profiles.single.role, ProfileRole.parent);
      expect(profiles.single.subtitle, 'Set up parent PIN');
    });
  });
}
