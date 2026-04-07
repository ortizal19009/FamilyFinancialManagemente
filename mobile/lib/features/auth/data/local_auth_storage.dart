import '../../../core/offline/local_database.dart';

class LocalAuthStorage {
  Future<List<LocalAuthUser>> getUsers() async {
    final db = await LocalDatabase.instance.database;
    final rows = await db.query(
      'local_users',
      orderBy: 'created_at DESC',
    );
    return rows
        .map((item) => LocalAuthUser.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<LocalAuthUser?> findByEmail(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    final users = await getUsers();
    for (final user in users) {
      if (user.email.trim().toLowerCase() == normalizedEmail) {
        return user;
      }
    }
    return null;
  }

  Future<void> saveUser(LocalAuthUser user) async {
    final users = await getUsers();
    final normalizedEmail = user.email.trim().toLowerCase();
    final updated = [
      user,
      ...users.where((item) => item.email.trim().toLowerCase() != normalizedEmail),
    ];
    await _saveUsers(updated);
  }

  Future<LocalAuthUser?> validateCredentials({
    required String email,
    required String password,
  }) async {
    final user = await findByEmail(email);
    if (user == null || user.password != password) {
      return null;
    }
    return user;
  }

  Future<void> markServerSynced(String email) async {
    final user = await findByEmail(email);
    if (user == null) {
      return;
    }

    await saveUser(
      user.copyWith(
        serverSynced: true,
        lastSyncedAt: DateTime.now().toIso8601String(),
      ),
    );
  }

  Future<void> _saveUsers(List<LocalAuthUser> users) async {
    final db = await LocalDatabase.instance.database;
    await db.transaction((txn) async {
      await txn.delete('local_users');
      for (final user in users) {
        final map = user.toMap();
        await txn.insert('local_users', {
          'email': map['email'],
          'full_name': map['full_name'],
          'password': map['password'],
          'role': map['role'],
          'created_at': map['created_at'],
          'server_synced': (map['server_synced'] as bool) ? 1 : 0,
          'last_synced_at': map['last_synced_at'],
        });
      }
    });
  }
}

class LocalAuthUser {
  const LocalAuthUser({
    required this.fullName,
    required this.email,
    required this.password,
    required this.role,
    required this.createdAt,
    required this.serverSynced,
    this.lastSyncedAt,
  });

  final String fullName;
  final String email;
  final String password;
  final String role;
  final String createdAt;
  final bool serverSynced;
  final String? lastSyncedAt;

  LocalAuthUser copyWith({
    String? fullName,
    String? email,
    String? password,
    String? role,
    String? createdAt,
    bool? serverSynced,
    String? lastSyncedAt,
  }) {
    return LocalAuthUser(
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      password: password ?? this.password,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      serverSynced: serverSynced ?? this.serverSynced,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'full_name': fullName,
      'email': email,
      'password': password,
      'role': role,
      'created_at': createdAt,
      'server_synced': serverSynced,
      'last_synced_at': lastSyncedAt,
    };
  }

  factory LocalAuthUser.fromMap(Map<String, dynamic> map) {
    return LocalAuthUser(
      fullName: map['full_name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      password: map['password'] as String? ?? '',
      role: map['role'] as String? ?? 'member',
      createdAt: map['created_at'] as String? ?? DateTime.now().toIso8601String(),
      serverSynced: map['server_synced'] is int
          ? (map['server_synced'] as int) == 1
          : map['server_synced'] as bool? ?? false,
      lastSyncedAt: map['last_synced_at'] as String?,
    );
  }
}
