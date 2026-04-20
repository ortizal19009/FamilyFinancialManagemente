import '../../../core/network/api_client.dart';
import '../../../core/offline/offline_operation.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/app_services.dart';
import '../../../core/offline/backend_reachability_service.dart';
import '../domain/user_session.dart';
import 'local_auth_storage.dart';

class AuthService {
  AuthService({
    ApiClient? apiClient,
    TokenStorage? tokenStorage,
    LocalAuthStorage? localAuthStorage,
    BackendReachabilityService? reachabilityService,
  })
      : _apiClient = apiClient ?? ApiClient(tokenStorage: tokenStorage),
        _tokenStorage = tokenStorage ?? TokenStorage(),
        _localAuthStorage = localAuthStorage ?? LocalAuthStorage(),
        _reachabilityService = reachabilityService ?? BackendReachabilityService();

  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;
  final LocalAuthStorage _localAuthStorage;
  final BackendReachabilityService _reachabilityService;

  Future<UserSession> login({
    required String email,
    required String password,
  }) async {
    final localUser = await _localAuthStorage.validateCredentials(
      email: email,
      password: password,
    );

    final canReachBackend = await _reachabilityService.canReachBackend();
    if (canReachBackend) {
      final response = await _apiClient.post(
        '/auth/login',
        {
          'email': email,
          'password': password,
        },
        auth: false,
      );

      final token = response['access_token'] as String;
      final user = response['user'] as Map<String, dynamic>;

      final session = UserSession(
        token: token,
        fullName: user['full_name'] as String? ?? '',
        email: user['email'] as String? ?? '',
        role: user['role'] as String? ?? 'member',
      );

      await _localAuthStorage.saveUser(
        LocalAuthUser(
          fullName: session.fullName,
          email: session.email,
          password: password,
          role: session.role,
          createdAt: DateTime.now().toIso8601String(),
          serverSynced: true,
          lastSyncedAt: DateTime.now().toIso8601String(),
        ),
      );
      await _persistSession(session);
      return session;
    }

    if (localUser != null) {
      final localSession = UserSession(
        token: 'local-${localUser.email}',
        fullName: localUser.fullName,
        email: localUser.email,
        role: localUser.role,
      );
      await _persistSession(localSession);
      return localSession;
    }

    throw Exception('No se pudo iniciar sesion. Verifica conexion o credenciales.');
  }

  Future<void> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final existingUser = await _localAuthStorage.findByEmail(email);
    if (existingUser != null) {
      throw Exception('Ya existe una cuenta local con ese correo');
    }

    final normalizedEmail = email.trim().toLowerCase();
    await _localAuthStorage.saveUser(
      LocalAuthUser(
        fullName: fullName.trim(),
        email: normalizedEmail,
        password: password,
        role: 'member',
        createdAt: DateTime.now().toIso8601String(),
        serverSynced: false,
      ),
    );

    await AppServices.syncService.enqueue(
      OfflineOperation(
        id: 'register-$normalizedEmail',
        module: 'auth',
        method: 'POST',
        path: '/auth/register',
        payload: {
          'full_name': fullName.trim(),
          'email': normalizedEmail,
          'password': password,
        },
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<UserSession?> restoreSession() async {
    final data = await _tokenStorage.getSession();
    final token = data['token'];
    if (token == null || token.isEmpty) {
      return null;
    }

    if (token.startsWith('local-') && await _reachabilityService.canReachBackend()) {
      await _tokenStorage.clear();
      return null;
    }

    return UserSession(
      token: token,
      fullName: data['full_name'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? 'member',
    );
  }

  Future<void> logout() => _tokenStorage.clear();

  Future<void> _persistSession(UserSession session) {
    return _tokenStorage.saveSession(
      token: session.token,
      fullName: session.fullName,
      email: session.email,
      role: session.role,
    );
  }
}
