class SyncStatus {
  const SyncStatus({
    required this.isOnline,
    required this.isSyncing,
    required this.pendingCount,
    this.lastMessage,
    this.lastSyncedAt,
  });

  final bool isOnline;
  final bool isSyncing;
  final int pendingCount;
  final String? lastMessage;
  final DateTime? lastSyncedAt;

  SyncStatus copyWith({
    bool? isOnline,
    bool? isSyncing,
    int? pendingCount,
    String? lastMessage,
    DateTime? lastSyncedAt,
  }) {
    return SyncStatus(
      isOnline: isOnline ?? this.isOnline,
      isSyncing: isSyncing ?? this.isSyncing,
      pendingCount: pendingCount ?? this.pendingCount,
      lastMessage: lastMessage ?? this.lastMessage,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }

  factory SyncStatus.initial() => const SyncStatus(
        isOnline: false,
        isSyncing: false,
        pendingCount: 0,
      );
}
