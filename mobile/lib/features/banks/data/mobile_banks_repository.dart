import '../../../core/app_services.dart';
import '../../../core/network/api_client.dart';
import '../../../core/offline/local_cache_storage.dart';
import '../../../core/offline/offline_operation.dart';
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
      final pendingBanks = await _loadPendingLocalBanks();
      final pendingAccounts = await _loadPendingLocalAccounts();
      final mergedBanks = [...pendingBanks, ...banks];
      final mergedAccounts = [...pendingAccounts, ...accounts];

      await _cacheStorage.saveCollection(
        _banksCacheKey,
        mergedBanks.map((item) => item.toMap()).toList(),
      );
      await _cacheStorage.saveCollection(
        _accountsCacheKey,
        mergedAccounts.map((item) => item.toMap()).toList(),
      );

      return BanksSnapshot(
        banks: mergedBanks,
        accounts: mergedAccounts,
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
    final localBank = BankSummary(
      id: _nextLocalId(),
      name: name,
      description: description,
    );
    final cached = await _cacheStorage.getCollection(_banksCacheKey);
    await _cacheStorage.saveCollection(
      _banksCacheKey,
      [localBank.toMap(), ...cached],
    );
    await AppServices.syncService.enqueue(OfflineOperation(
      id: 'bank-${localBank.id}',
      module: 'banks',
      method: 'POST',
      path: '/banks/',
      payload: {
        'name': name,
        'description': description,
      },
      createdAt: DateTime.now(),
    ));
  }

  Future<List<BankSummary>> _loadPendingLocalBanks() async {
    final cached = await _cacheStorage.getCollection(_banksCacheKey);
    return cached
        .map(BankSummary.fromMap)
        .where((item) => item.id < 0)
        .toList();
  }

  Future<List<BankAccountSummary>> _loadPendingLocalAccounts() async {
    final cached = await _cacheStorage.getCollection(_accountsCacheKey);
    return cached
        .map(BankAccountSummary.fromMap)
        .where((item) => item.id < 0)
        .toList();
  }

  int _nextLocalId() => -DateTime.now().microsecondsSinceEpoch;

  Future<void> updateBank({
    required int bankId,
    required String name,
    String? description,
  }) async {
    if (bankId < 0) {
      final cached = await _cacheStorage.getCollection(_banksCacheKey);
      final updated = cached
          .map((item) => item['id'] == bankId
              ? {
                  ...item,
                  'name': name,
                  'description': description,
                }
              : item)
          .toList();
      await _cacheStorage.saveCollection(_banksCacheKey, updated);
      return;
    }
    await _apiClient.put('/banks/$bankId', {
      'name': name,
      'description': description,
    });
  }

  Future<void> deleteBank(int bankId) async {
    if (bankId < 0) {
      final cached = await _cacheStorage.getCollection(_banksCacheKey);
      await _cacheStorage.saveCollection(
        _banksCacheKey,
        cached.where((item) => item['id'] != bankId).toList(),
      );
      return;
    }
    await _apiClient.delete('/banks/$bankId');
  }

  Future<void> createAccount({
    required int bankId,
    required String accountNumber,
    String? accountType,
    String? owner,
    double currentBalance = 0,
  }) async {
    final banks = await _cacheStorage.getCollection(_banksCacheKey);
    final matchedBank = banks.firstWhere(
      (item) => item['id'] == bankId,
      orElse: () => <String, dynamic>{},
    );
    final localAccount = BankAccountSummary(
      id: _nextLocalId(),
      bankId: bankId,
      bankName: matchedBank['name'] as String? ?? '',
      accountNumber: accountNumber,
      accountType: accountType,
      owner: owner,
      currentBalance: currentBalance,
    );
    final cached = await _cacheStorage.getCollection(_accountsCacheKey);
    await _cacheStorage.saveCollection(
      _accountsCacheKey,
      [localAccount.toMap(), ...cached],
    );
    await AppServices.syncService.enqueue(OfflineOperation(
      id: 'bank-account-${localAccount.id}',
      module: 'banks',
      method: 'POST',
      path: '/banks/accounts',
      payload: {
        'bank_id': bankId,
        'account_number': accountNumber,
        'account_type': accountType,
        'owner': owner,
        'current_balance': currentBalance,
      },
      createdAt: DateTime.now(),
    ));
  }

  Future<void> updateAccount({
    required int accountId,
    required int bankId,
    required String accountNumber,
    String? accountType,
    String? owner,
    double currentBalance = 0,
  }) async {
    if (accountId < 0) {
      final banks = await _cacheStorage.getCollection(_banksCacheKey);
      final matchedBank = banks.firstWhere(
        (item) => item['id'] == bankId,
        orElse: () => <String, dynamic>{},
      );
      final cached = await _cacheStorage.getCollection(_accountsCacheKey);
      final updated = cached
          .map((item) => item['id'] == accountId
              ? {
                  ...item,
                  'bank_id': bankId,
                  'bank_name': matchedBank['name'] as String? ?? '',
                  'account_number': accountNumber,
                  'account_type': accountType,
                  'owner': owner,
                  'current_balance': currentBalance,
                }
              : item)
          .toList();
      await _cacheStorage.saveCollection(_accountsCacheKey, updated);
      return;
    }
    await _apiClient.put('/banks/accounts/$accountId', {
      'bank_id': bankId,
      'account_number': accountNumber,
      'account_type': accountType,
      'owner': owner,
      'current_balance': currentBalance,
    });
  }

  Future<void> deleteAccount(int accountId) async {
    if (accountId < 0) {
      final cached = await _cacheStorage.getCollection(_accountsCacheKey);
      await _cacheStorage.saveCollection(
        _accountsCacheKey,
        cached.where((item) => item['id'] != accountId).toList(),
      );
      return;
    }
    await _apiClient.delete('/banks/accounts/$accountId');
  }
}
