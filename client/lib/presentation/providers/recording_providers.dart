import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/recording_repository.dart';
import '../../data/repositories/server_piece_sync_repository.dart';
import '../../domain/entities/practice_recording.dart';
import '../../injection/container.dart';

// ─── repository provider ──────────────────────────────────────────────────────

final recordingRepositoryProvider = Provider<RecordingRepository>(
  (ref) {
    final repository = LocalRecordingRepository(
      appDocDir: ref.watch(appDirectoryProvider),
      syncRepository: ServerPieceSyncRepository(),
    );
    // Fire-and-forget sync of any pending offline recordings when the repo is initialized.
    repository.syncPendingRecordings();
    return repository;
  },
);

// ─── recording list ──────────────────────────────────────────────────────────

typedef RecordingListKey = ({String pieceId, String profileId});

final recordingListProvider =
    AsyncNotifierProvider.family<RecordingListNotifier, List<PracticeRecording>, RecordingListKey>(
  RecordingListNotifier.new,
);

class RecordingListNotifier extends FamilyAsyncNotifier<List<PracticeRecording>, RecordingListKey> {
  late RecordingRepository _repository;

  @override
  Future<List<PracticeRecording>> build(RecordingListKey arg) async {
    _repository = ref.watch(recordingRepositoryProvider);
    return _repository.listForPiece(
      pieceId: arg.pieceId,
      profileId: arg.profileId,
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _repository.listForPiece(
        pieceId: arg.pieceId,
        profileId: arg.profileId,
      ),
    );
  }

  Future<void> add(PracticeRecording recording) async {
    final current = state.valueOrNull ?? [];
    state = AsyncData([recording, ...current]);
  }

  Future<void> remove(String id) async {
    await _repository.delete(id);
    final current = state.valueOrNull ?? [];
    state = AsyncData(current.where((r) => r.id != id).toList());
  }
}

// ─── recorder state ──────────────────────────────────────────────────────────

enum RecorderStatus { idle, initializing, ready, recording, saving, error }

class RecorderState {
  const RecorderState({
    this.status = RecorderStatus.idle,
    this.elapsedMs = 0,
    this.errorMessage,
    this.cameraController,
  });

  final RecorderStatus status;
  final int elapsedMs;
  final String? errorMessage;
  final CameraController? cameraController;

  bool get isRecording => status == RecorderStatus.recording;
  bool get isBusy => status == RecorderStatus.initializing || status == RecorderStatus.saving;

  String get formattedElapsed {
    final d = Duration(milliseconds: elapsedMs);
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  RecorderState copyWith({
    RecorderStatus? status,
    int? elapsedMs,
    String? errorMessage,
    CameraController? cameraController,
  }) =>
      RecorderState(
        status: status ?? this.status,
        elapsedMs: elapsedMs ?? this.elapsedMs,
        errorMessage: errorMessage,
        cameraController: cameraController ?? this.cameraController,
      );
}

final recorderProvider = StateNotifierProvider.family<
    RecorderNotifier,
    RecorderState,
    ({String pieceId, String profileId, String? scoreVersionId})>(
  (ref, args) {
    final repo = ref.watch(recordingRepositoryProvider);
    return RecorderNotifier(
      repo: repo,
      pieceId: args.pieceId,
      profileId: args.profileId,
      scoreVersionId: args.scoreVersionId,
      onSaved: (recording) {
        ref
            .read(recordingListProvider((pieceId: args.pieceId, profileId: args.profileId)).notifier)
            .add(recording);
      },
    );
  },
);

class RecorderNotifier extends StateNotifier<RecorderState> {
  RecorderNotifier({
    required RecordingRepository repo,
    required String pieceId,
    required String profileId,
    this.scoreVersionId,
    required Function(PracticeRecording) onSaved,
  })  : _repo = repo,
        _pieceId = pieceId,
        _profileId = profileId,
        _onSaved = onSaved,
        super(const RecorderState()) {
    _initCamera();
  }

  final RecordingRepository _repo;
  final String _pieceId;
  final String _profileId;
  final String? scoreVersionId;
  final Function(PracticeRecording) _onSaved;

  CameraController? _cameraController;
  Timer? _elapsedTimer;
  DateTime? _startTime;

  Future<void> _initCamera() async {
    state = state.copyWith(status: RecorderStatus.initializing, errorMessage: null);
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        state = state.copyWith(
          status: RecorderStatus.error,
          errorMessage: 'No cameras available on this device.',
        );
        return;
      }
      
      // Prefer front-facing camera for student practice
      CameraDescription? selectedCamera;
      for (final cam in cameras) {
        if (cam.lensDirection == CameraLensDirection.front) {
          selectedCamera = cam;
          break;
        }
      }
      selectedCamera ??= cameras.first;

      _cameraController = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: true,
      );

      await _cameraController!.initialize();

      state = state.copyWith(
        status: RecorderStatus.ready,
        cameraController: _cameraController,
      );
    } catch (e) {
      state = state.copyWith(
        status: RecorderStatus.error,
        errorMessage: 'Failed to initialize camera: $e',
      );
    }
  }

  Future<void> startRecording() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (_cameraController!.value.isRecordingVideo) return;

    try {
      await _cameraController!.startVideoRecording();
      _startTime = DateTime.now();
      state = state.copyWith(status: RecorderStatus.recording, elapsedMs: 0);

      _elapsedTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        if (_startTime == null) return;
        final elapsed = DateTime.now().difference(_startTime!).inMilliseconds;
        state = state.copyWith(elapsedMs: elapsed);
      });
    } catch (e) {
      state = state.copyWith(
        status: RecorderStatus.error,
        errorMessage: 'Could not start recording: $e',
      );
    }
  }

  Future<void> stopRecording() async {
    if (_cameraController == null || !_cameraController!.value.isRecordingVideo) return;

    _elapsedTimer?.cancel();
    _elapsedTimer = null;

    final finalElapsed = _startTime == null
        ? 0
        : DateTime.now().difference(_startTime!).inMilliseconds;
    _startTime = null;

    state = state.copyWith(status: RecorderStatus.saving);

    try {
      final xFile = await _cameraController!.stopVideoRecording();
      
      final saved = await _repo.save(
        pieceId: _pieceId,
        profileId: _profileId,
        scoreVersionId: scoreVersionId,
        tempPath: xFile.path,
        durationMs: finalElapsed,
      );
      _onSaved(saved);
      state = state.copyWith(status: RecorderStatus.ready, elapsedMs: 0);
    } catch (e) {
      state = state.copyWith(
        status: RecorderStatus.error,
        errorMessage: 'Could not save recording: $e',
      );
    }
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }
}

// ─── playback state ──────────────────────────────────────────────────────────

enum PlaybackStatus { idle, loading, playing, paused, error }

class PlaybackState {
  const PlaybackState({
    this.activeId,
    this.status = PlaybackStatus.idle,
    this.videoController,
  });
  final String? activeId;
  final PlaybackStatus status;
  // Hold the controller so the UI can attach it to a VideoPlayer widget.
  final dynamic videoController; // using dynamic/Object here to avoid direct import coupling if needed, but we'll import video_player

  bool isPlaying(String id) => activeId == id && status == PlaybackStatus.playing;
}

// Playback logic will be handled directly in the UI Dialog since video_player requires a VideoPlayer widget that controls its own aspect ratio and initialization closely.
// For simplicity, we just provide an empty provider or let the UI instantiate the VideoPlayerController.
// Let's create a minimal provider if needed, or remove it entirely and let the Dialog handle state.

