import '../../../core/network/api_client.dart';
import '../../../core/offline/local_cache_storage.dart';
import '../../banks/domain/bank_models.dart';
import '../../cards/domain/cards_models.dart';
import '../../expenses/domain/mobile_expense_record.dart';

class DashboardRepository {
  DashboardRepository({
    ApiClient? apiClient,
    LocalCacheStorage? cacheStorage,
  })  : _apiClient = apiClient ?? ApiClient(),
        _cacheStorage = cacheStorage ?? LocalCacheStorage();

  final ApiClient _apiClient;
  final LocalCacheStorage _cacheStorage;
  static const _summaryCacheKey = 'mobile_dashboard_summary_cache';
  static const _accountsCacheKey = 'mobile_bank_accounts_cache';
  static const _cardsCacheKey = 'mobile_cards_cache';
  static const _assetsCacheKey = 'mobile_assets_cache';
  static const _incomeCacheKey = 'mobile_income_cache';
  static const _expensesCacheKey = 'mobile_expenses_cache';

  Future<Map<String, dynamic>> loadSummary() async {
    final localSummary = await _buildLocalSummary();
    try {
      final response = await _apiClient.get('/dashboard/summary');
      final remoteSummary = Map<String, dynamic>.from(response as Map);
      final summary = _mergeSummary(remoteSummary, localSummary);
      await _cacheStorage.saveCollection(_summaryCacheKey, [summary]);
      return summary;
    } catch (_) {
      if (_hasUsefulData(localSummary)) {
        await _cacheStorage.saveCollection(_summaryCacheKey, [localSummary]);
        return localSummary;
      }
      final cached = await _cacheStorage.getCollection(_summaryCacheKey);
      if (cached.isNotEmpty) {
        return cached.first;
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _buildLocalSummary() async {
    final accountsCache = await _cacheStorage.getCollection(_accountsCacheKey);
    final cardsCache = await _cacheStorage.getCollection(_cardsCacheKey);
    final assetsCache = await _cacheStorage.getCollection(_assetsCacheKey);
    final incomeCache = await _cacheStorage.getCollection(_incomeCacheKey);
    final expensesCache = await _cacheStorage.getCollection(_expensesCacheKey);

    final accounts = accountsCache.map(BankAccountSummary.fromMap).toList();
    final cards = cardsCache.map(CardSummary.fromMap).toList();
    final expenses = expensesCache.map(MobileExpenseRecord.fromMap).toList();
    final now = DateTime.now();

    final monthlyExpenses = expenses
        .where((item) {
          final parsed = DateTime.tryParse(item.expenseDate);
          return parsed != null && parsed.month == now.month && parsed.year == now.year;
        })
        .fold<double>(0, (sum, item) => sum + item.amount);

    final monthlyIncome = incomeCache
        .where((item) {
          final parsed = DateTime.tryParse(item['income_date'] as String? ?? '');
          return parsed != null && parsed.month == now.month && parsed.year == now.year;
        })
        .fold<double>(0, (sum, item) => sum + ((item['amount'] as num?)?.toDouble() ?? 0));

    final totalAssets = assetsCache.fold<double>(
      0,
      (sum, item) => sum + ((item['value'] as num?)?.toDouble() ?? 0),
    );

    final totalDebt = cards.fold<double>(0, (sum, item) => sum + item.currentDebt);
    final availableBalance = accounts.fold<double>(0, (sum, item) => sum + item.currentBalance);

    final recentExpenses = [...expenses]
      ..sort((a, b) => b.expenseDate.compareTo(a.expenseDate));

    return {
      'stats': {
        'availableBalance': availableBalance,
        'totalDebt': totalDebt,
        'monthlyExpenses': monthlyExpenses,
        'monthlyIncome': monthlyIncome,
        'totalAssets': totalAssets,
      },
      'accounts': accounts
          .map((item) => {
                'id': item.id,
                'bank_name': item.bankName,
                'account_number': item.accountNumber,
                'account_type': item.accountType,
                'owner': item.owner,
                'current_balance': item.currentBalance,
              })
          .toList(),
      'recentExpenses': recentExpenses
          .take(5)
          .map((item) => {
                'description': item.description,
                'category_name': item.categoryName,
                'payment_method': item.paymentMethod,
                'expense_date': item.expenseDate,
                'amount': item.amount,
              })
          .toList(),
    };
  }

  Map<String, dynamic> _mergeSummary(Map<String, dynamic> remote, Map<String, dynamic> local) {
    final remoteStats = Map<String, dynamic>.from((remote['stats'] as Map?) ?? {});
    final localStats = Map<String, dynamic>.from((local['stats'] as Map?) ?? {});
    return {
      ...remote,
      'stats': {
        ...remoteStats,
        'availableBalance': localStats['availableBalance'] ?? remoteStats['availableBalance'] ?? 0,
        'totalDebt': localStats['totalDebt'] ?? remoteStats['totalDebt'] ?? 0,
        'monthlyExpenses': localStats['monthlyExpenses'] ?? remoteStats['monthlyExpenses'] ?? 0,
        'monthlyIncome': localStats['monthlyIncome'] ?? 0,
        'totalAssets': localStats['totalAssets'] ?? remoteStats['totalAssets'] ?? 0,
      },
      'accounts': local['accounts'] ?? remote['accounts'] ?? const [],
      'recentExpenses': (local['recentExpenses'] as List?)?.isNotEmpty == true
          ? local['recentExpenses']
          : (remote['recentExpenses'] ?? const []),
    };
  }

  bool _hasUsefulData(Map<String, dynamic> summary) {
    final stats = Map<String, dynamic>.from((summary['stats'] as Map?) ?? {});
    final accounts = (summary['accounts'] as List?) ?? const [];
    final recentExpenses = (summary['recentExpenses'] as List?) ?? const [];
    return stats.values.any((value) => (value as num?) != null && value != 0) ||
        accounts.isNotEmpty ||
        recentExpenses.isNotEmpty;
  }
}
