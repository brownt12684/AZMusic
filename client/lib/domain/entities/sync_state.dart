/// Tracks the sync state between local and remote data stores.
class SyncState {
  final String entityType;
  final String? entityId;
  final String lastSyncHash;
  final DateTime lastSyncAt;
  final SyncDirection lastDirection;
  final SyncStatus status;
  final String? errorMessage;

  const SyncState({
    required this.entityType,
    this.entityId,
    required this.lastSyncHash,
    required this.lastSyncAt,
    required this.lastDirection,
    required this.status,
    this.errorMessage,
  });

  SyncState copyWith({
    String? entityType,
    String? entityId,
    String? lastSyncHash,
    DateTime? lastSyncAt,
    SyncDirection? lastDirection,
    SyncStatus? status,
    String? errorMessage,
  }) {
    return SyncState(
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      lastSyncHash: lastSyncHash ?? this.lastSyncHash,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastDirection: lastDirection ?? this.lastDirection,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'entity_type': entityType,
      'entity_id': entityId,
      'last_sync_hash': lastSyncHash,
      'last_sync_at': lastSyncAt.toIso8601String(),
      'last_direction': lastDirection.name,
      'status': status.name,
      'error_message': errorMessage,
    };
  }

  factory SyncState.fromMap(Map<String, dynamic> map) {
    return SyncState(
      entityType: map['entity_type'] as String,
      entityId: map['entity_id'] as String?,
      lastSyncHash: map['last_sync_hash'] as String,
      lastSyncAt: DateTime.parse(map['last_sync_at'] as String),
      lastDirection: SyncDirection.values.firstWhere(
        (e) => e.name == map['last_direction'],
        orElse: () => SyncDirection.localToRemote,
      ),
      status: SyncStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => SyncStatus.pending,
      ),
      errorMessage: map['error_message'] as String?,
    );
  }

  Map<String, dynamic> toJson() => toMap();
  factory SyncState.fromJson(Map<String, dynamic> json) =>
      SyncState.fromMap(json);

  /// Whether this entity is fully synced with no conflicts.
  bool get isSynced => status == SyncStatus.synced;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncState &&
          entityType == other.entityType &&
          entityId == other.entityId;

  @override
  int get hashCode => Object.hash(entityType, entityId);

  @override
  String toString() =>
      'SyncState(entity: $entityType, id: $entityId, status: $status)';
}

/// Direction of the last sync operation.
enum SyncDirection {
  localToRemote,
  remoteToLocal,
}

/// Sync status for an entity.
enum SyncStatus { pending, syncing, synced, conflict, failed }
