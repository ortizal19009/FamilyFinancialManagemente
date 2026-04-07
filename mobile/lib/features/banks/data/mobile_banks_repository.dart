import '../../../core/network/api_client.dart';
import '../../../core/offline/local_cache_storage.dart';
import '../domain/bank_models.dart';

class MobileBanksRepository {
  MobileBanksRepository({
    ApiClient? apiClient,
    LocalCacheStorage? cacheStorage,
  })  : _apiClient = apiClient ?? ApiClient(),
        _cacheStorage = cacheStorage ?? LocalCacheStorage();

  final ApiClient _apiClient;
  final LocalCacheStorage _cacheStorage;

  static const _banksCacheKey = 'mobile_banks_cache';
  static const _accountsCacheKey = 'mobile_bank_accounts_cache';

  Future<BanksSnapshot> loadSnapshot() async {
    try {
      final banksResponse = await _apiClient.get('/banks/');
      final accountsResponse = await _apiClient.get('/banks/accounts');

      final banks = (banksResponse as List<dynamic>)
          .map((item) => BankSummary.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList();
      final accounts = (accountsResponse as List<dynamic>)
          .map((item) => BankAccountSummary.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList();

      await _cacheStorage.saveCollection(
        _banksCacheKey,
        banks.map((item) => item.toMap()).toList(),
      );
      await _cacheStorage.saveCollection(
        _accountsCacheKey,
        accounts.map((item) => item.toMap()).toList(),
      );

      return BanksSnapshot(
        banks: banks,
        accounts: accounts,
        loadedFromCache: false,
      );
    } catch (_) {
      final banksCache = await _cacheStorage.getCollection(_banksCacheKey);
      final accountsCache = await _cacheStorage.getCollection(_accountsCacheKey);
      return BanksSnapshot(
        banks: banksCache.map(BankSummary.fromMap).toList(),
        accounts: accountsCache.map(BankAccountSummary.fromMap).toList(),
        loadedFromCache: true,
      );
    }
  }

  Future<void> createBank({
    required String name,
    String? description,
  }) async {
    await _apiClient.post('/banks/', {
      'name': name,
      'description': description,
    });
  }

  Future<void> updateBank({
    required int bankId,
    required String name,
    String? description,
  }) async {
    await _apiClient.put('/banks/$bankId', {
      'name': name,
      'description': description,
    });
  }

  Future<void> deleteBank(int bankId) async {
    await _apiClient.delete('/banks/$bankId');
  }

  Future<void> createAccount({
    required int bankId,
    required String accountNumber,
    String? accountType,
    String? owner,
    double currentBalance = 0,
  }) async {
    await _apiClient.post('/banks/accounts', {
      'bank_id': bankId,
      'account_number': accountNumber,
      'account_type': accountType,
      'owner': owner,
      'current_balance': currentBalance,
    });
  }

  Future<void> updateAccount({
    required int accountId,
    required int bankId,
    required String accountNumber,
    String? accountType,
    String? owner,
    double currentBalance = 0,
  }) async {
    await _apiClient.put('/banks/accounts/$accountId', {
      'bank_id': bankId,
      'account_number': accountNumber,
      'account_type': accountType,
      'owner': owner,
      'current_balance': currentBalance,
    });
  }

  Future<void> deleteAccount(int accountId) async {
    await _apiClient.delete('/banks/accounts/$accountId');
  }
}
