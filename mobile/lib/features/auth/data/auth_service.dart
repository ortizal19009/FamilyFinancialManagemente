import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../domain/user_session.dart';

class AuthService {
  AuthService({ApiClient? apiClient, TokenStorage? tokenStorage})
      : _apiClient = apiClient ?? ApiClient(tokenStorage: tokenStorage),
        _tokenStorage = tokenStorage ?? TokenStorage();

  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  Future<UserSession> login({
    required String email,
    required String password,
  }) async {
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

    await _tokenStorage.saveSession(
      token: session.token,
      fullName: session.fullName,
      email: session.email,
      role: session.role,
    );

    return session;
  }

  Future<void> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    await _apiClient.post(
      '/auth/register',
      {
        'full_name': fullName,
        'email': email,
        'password': password,
      },
      auth: false,
    );
  }

  Future<UserSession?> restoreSession() async {
    final data = await _tokenStorage.getSession();
    final token = data['token'];
    if (token == null || token.isEmpty) {
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
}
