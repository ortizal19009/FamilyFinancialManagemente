class SyncStatus {
  const SyncStatus({
    required this.isOnline,
    required this.isSyncing,
    required this.pendingCount,
    this.lastMessage,
  });

  final bool isOnline;
  final bool isSyncing;
  final int pendingCount;
  final String? lastMessage;

  SyncStatus copyWith({
    bool? isOnline,
    bool? isSyncing,
    int? pendingCount,
    String? lastMessage,
  }) {
    return SyncStatus(
      isOnline: isOnline ?? this.isOnline,
      isSyncing: isSyncing ?? this.isSyncing,
      pendingCount: pendingCount ?? this.pendingCount,
      lastMessage: lastMessage ?? this.lastMessage,
    );
  }

  factory SyncStatus.initial() => const SyncStatus(
        isOnline: false,
        isSyncing: false,
        pendingCount: 0,
      );
}
