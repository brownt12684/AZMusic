import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'routes/app_router.dart';

class ScoreReaderLaunchRequest {
  const ScoreReaderLaunchRequest({
    required this.pieceId,
    required this.scoreVersionId,
  });

  final String pieceId;
  final String scoreVersionId;

  @override
  bool operator ==(Object other) {
    return other is ScoreReaderLaunchRequest &&
        other.pieceId == pieceId &&
        other.scoreVersionId == scoreVersionId;
  }

  @override
  int get hashCode => Object.hash(pieceId, scoreVersionId);
}

abstract class ScoreReaderLauncher {
  Future<void> open(
    BuildContext context,
    ScoreReaderLaunchRequest request,
  );
}

class NavigatorScoreReaderLauncher implements ScoreReaderLauncher {
  @override
  Future<void> open(
    BuildContext context,
    ScoreReaderLaunchRequest request,
  ) async {
    await Navigator.of(context).pushNamed(
      AppRouter.reader,
      arguments: {
        'pieceId': request.pieceId,
        'scoreVersionId': request.scoreVersionId,
      },
    );
  }
}

final scoreReaderLauncherProvider = Provider<ScoreReaderLauncher>(
  (ref) => NavigatorScoreReaderLauncher(),
);
