import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/repositories/annotation_repository.dart';
import '../../domain/entities/annotation_layer.dart';
import '../../injection/container.dart';

final annotationRepositoryProvider = Provider<AnnotationRepository>(
  (ref) {
    final repository = AnnotationRepository(
      appDirectory: ref.watch(appDirectoryProvider),
    );
    ref.onDispose(() {
      unawaited(repository.close());
    });
    return repository;
  },
);

class AnnotationPageState {
  const AnnotationPageState({
    this.layer,
    this.isVisible = true,
    this.isDrawing = false,
    this.activeStroke = const <OffsetPoint>[],
  });

  final AnnotationLayer? layer;
  final bool isVisible;
  final bool isDrawing;
  final List<OffsetPoint> activeStroke;

  List<AnnotationStroke> get strokes => layer?.strokes ?? const [];

  AnnotationPageState copyWith({
    AnnotationLayer? layer,
    bool? isVisible,
    bool? isDrawing,
    List<OffsetPoint>? activeStroke,
  }) {
    return AnnotationPageState(
      layer: layer ?? this.layer,
      isVisible: isVisible ?? this.isVisible,
      isDrawing: isDrawing ?? this.isDrawing,
      activeStroke: activeStroke ?? this.activeStroke,
    );
  }
}

final annotationPageProvider = AsyncNotifierProvider.family<
    AnnotationPageNotifier,
    AnnotationPageState,
    ({String profileId, String scoreVersionId, int pageNumber})>(
  AnnotationPageNotifier.new,
);

class AnnotationPageNotifier extends FamilyAsyncNotifier<AnnotationPageState,
    ({String profileId, String scoreVersionId, int pageNumber})> {
  final Uuid _uuid = const Uuid();

  @override
  Future<AnnotationPageState> build(
    ({String profileId, String scoreVersionId, int pageNumber}) arg,
  ) async {
    final layer = await ref.read(annotationRepositoryProvider).loadLayer(
          profileId: arg.profileId,
          scoreVersionId: arg.scoreVersionId,
          pageNumber: arg.pageNumber,
        );
    return AnnotationPageState(layer: layer);
  }

  void toggleVisibility() {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }
    setVisibility(!current.isVisible);
  }

  void setVisibility(bool isVisible) {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }
    state = AsyncValue.data(
      current.copyWith(
        isVisible: isVisible,
        isDrawing: isVisible ? current.isDrawing : false,
        activeStroke: const <OffsetPoint>[],
      ),
    );
  }

  void toggleDrawing() {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }
    setDrawing(!current.isDrawing);
  }

  void setDrawing(bool isDrawing) {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }
    state = AsyncValue.data(
      current.copyWith(
        isDrawing: isDrawing,
        activeStroke: const <OffsetPoint>[],
      ),
    );
  }

  void beginStroke() {
    final current = state.valueOrNull;
    if (current == null || !current.isDrawing) {
      return;
    }
    state = AsyncValue.data(current.copyWith(activeStroke: const []));
  }

  void addPoint(OffsetPoint point) {
    final current = state.valueOrNull;
    if (current == null || !current.isDrawing) {
      return;
    }
    state = AsyncValue.data(
      current.copyWith(
        activeStroke: [...current.activeStroke, point],
      ),
    );
  }

  Future<void> commitStroke() async {
    final current = state.valueOrNull;
    if (current == null || current.activeStroke.length < 2) {
      state = AsyncValue.data(
        current?.copyWith(activeStroke: const <OffsetPoint>[]) ??
            const AnnotationPageState(),
      );
      return;
    }

    final nextStrokes = [
      ...current.strokes,
      AnnotationStroke(
        id: _uuid.v4(),
        color: StrokeColor.orange,
        strokeWidth: 3,
        points: current.activeStroke,
        tool: StrokeTool.pen,
      ),
    ];
    await _saveStrokes(nextStrokes, current);
  }

  Future<void> clear() async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    await ref.read(annotationRepositoryProvider).clearLayer(
          profileId: arg.profileId,
          scoreVersionId: arg.scoreVersionId,
          pageNumber: arg.pageNumber,
        );
    state = AsyncValue.data(
      current.copyWith(
        layer: current.layer?.copyWith(strokes: const []),
        activeStroke: const <OffsetPoint>[],
      ),
    );
  }

  Future<void> _saveStrokes(
    List<AnnotationStroke> strokes,
    AnnotationPageState current,
  ) async {
    final layer = await ref.read(annotationRepositoryProvider).saveLayer(
          profileId: arg.profileId,
          scoreVersionId: arg.scoreVersionId,
          pageNumber: arg.pageNumber,
          strokes: strokes,
        );
    state = AsyncValue.data(
      current.copyWith(
        layer: layer,
        activeStroke: const <OffsetPoint>[],
      ),
    );
  }
}
