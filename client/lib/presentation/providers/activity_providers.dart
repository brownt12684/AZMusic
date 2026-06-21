import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/activity_repository.dart';
import '../../domain/entities/activity.dart';

final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  return ActivityRepository();
});

final activityFeedProvider = FutureProvider.family<List<ActivityEvent>, String?>((ref, studentId) {
  final repo = ref.read(activityRepositoryProvider);
  return repo.fetchActivityFeed(studentId: studentId);
});

final studioEventsProvider = FutureProvider<List<StudioEvent>>((ref) {
  final repo = ref.read(activityRepositoryProvider);
  return repo.fetchEvents();
});

final practiceSessionsProvider = FutureProvider.family<List<PracticeSession>, String>((ref, studentId) {
  final repo = ref.read(activityRepositoryProvider);
  return repo.fetchPracticeSessions(studentId);
});

final goalsProvider = FutureProvider.family<List<Goal>, String>((ref, studentId) {
  final repo = ref.read(activityRepositoryProvider);
  return repo.fetchGoals(studentId);
});
