import '../../../core/app_services.dart';
import '../../../core/network/api_client.dart';
import '../../../core/offline/local_cache_storage.dart';
import '../../../core/offline/offline_operation.dart';
import '../../banks/domain/bank_models.dart';
import '../../cards/domain/cards_models.dart';
import '../domain/expense_category.dart';
import '../domain/mobile_expense_record.dart';

class MobileExpensesRepository {
  MobileExpensesRepository({
    ApiClient? apiClient,
    LocalCacheStorage? cacheStorage,
  })  : _apiClient = apiClient ?? ApiClient(),
        _cacheStorage = cacheStorage ?? LocalCacheStorage();

  final ApiClient _apiClient;
  final LocalCacheStorage _cacheStorage;

  static const _expensesCacheKey = 'mobile_expenses_cache';
  static const _categoriesCacheKey = 'mobile_expense_categories_cache';

  Future<List<ExpenseCategory>> loadCategories() async {
    try {
      final response = await _apiClient.get('/expenses/categories');
      final categories = (response as List<dynamic>)
          .map((item) => ExpenseCategory.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList();
      await _cacheStorage.saveCollection(
        _categoriesCacheKey,
        categories.map((item) => item.toMap()).toList(),
      );
      return categories;
    } catch (_) {
      final cached = await _cacheStorage.getCollection(_categoriesCacheKey);
      return cached.map(ExpenseCategory.fromMap).toList();
    }
  }

  Future<List<MobileExpenseRecord>> loadExpenses() async {
    try {
      final response = await _apiClient.get('/expenses/');
      final expenses = (response as List<dynamic>).map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        final amount = ((map['total_amount'] ?? map['amount']) as num?)?.toDouble() ?? 0;
        return MobileExpenseRecord(
          localId: 'server-${map['id']}',
          serverId: map['id'] as int?,
          description: map['description'] as String? ?? '',
          amount: amount,
          categoryId: ((map['items'] as List?)?.isNotEmpty ?? false)
              ? ((map['items'] as List).first as Map)['category_id'] as int? ?? 0
              : 0,
          categoryName: map['category_name'] as String? ?? '',
          paymentMethod: map['payment_method'] as String? ?? 'Efectivo',
          expenseDate: map['expense_date'] as String? ?? '',
          syncStatus: 'synced',
          items: ((map['items'] as List?) ?? const [])
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList(),
          cardId: map['card_id'] as int?,
          bankAccountId: map['bank_account_id'] as int?,
        );
      }).toList();

      final pending = await _loadPendingLocalExpenses();
      final merged = [...pending, ...expenses];

      await _cacheStorage.saveCollection(
        _expensesCacheKey,
        merged.map((item) => item.toMap()).toList(),
      );
      return merged;
    } catch (_) {
      final cached = await _cacheStorage.getCollection(_expensesCacheKey);
      return cached.map(MobileExpenseRecord.fromMap).toList();
    }
  }

  Future<void> addExpenseOffline({
    required String description,
    required List<Map<String, dynamic>> items,
    required String paymentMethod,
    required String expenseDate,
    int? cardId,
    int? bankAccountId,
    String? receiptPath,
  }) async {
    if (receiptPath != null && receiptPath.isNotEmpty) {
      await _apiClient.postMultipart(
        '/expenses/',
        fields: {
          'description': description,
          'payment_method': paymentMethod,
          'expense_date': expenseDate,
          'card_id': cardId,
          'bank_account_id': bankAccountId,
          'items': items,
        },
        fileField: 'receipt',
        filePath: receiptPath,
      );
      return;
    }

    final localId = 'local-${DateTime.now().millisecondsSinceEpoch}';
    final operation = OfflineOperation(
      id: localId,
      module: 'expenses',
      method: 'POST',
      path: '/expenses/',
      payload: {
        'description': description,
        'payment_method': paymentMethod,
        'expense_date': expenseDate,
        'card_id': cardId,
        'bank_account_id': bankAccountId,
        'items': items,
      },
      createdAt: DateTime.now(),
    );

    await AppServices.syncService.enqueue(operation);

    final cached = await _cacheStorage.getCollection(_expensesCacheKey);
    final firstItem = items.first;
    final amount = (firstItem['amount'] as num?)?.toDouble() ?? 0;
    final categoryId = firstItem['category_id'] as int? ?? 0;
    final matchedCategory = await loadCategories();
    final categoryName = matchedCategory
        .where((item) => item.id == categoryId)
        .map((item) => item.name)
        .firstWhere(
          (item) => item.isNotEmpty,
          orElse: () => '',
        );
    final localExpense = MobileExpenseRecord(
      localId: localId,
      description: description,
      amount: amount,
      categoryId: categoryId,
      categoryName: categoryName,
      paymentMethod: paymentMethod,
      expenseDate: expenseDate,
      syncStatus: 'pending',
      items: items,
      cardId: cardId,
      bankAccountId: bankAccountId,
    );

    final updated = [
      localExpense.toMap(),
      ...cached.where((item) => item['local_id'] != localId),
    ];
    await _cacheStorage.saveCollection(_expensesCacheKey, updated);
  }

  Future<List<MobileExpenseRecord>> _loadPendingLocalExpenses() async {
    final pendingOperations = await AppServices.syncService.getPendingOperations();
    final pendingIds = pendingOperations.map((item) => item.id).toSet();
    final cached = await _cacheStorage.getCollection(_expensesCacheKey);
    return cached
        .map(MobileExpenseRecord.fromMap)
        .where((item) => item.syncStatus != 'synced' && pendingIds.contains(item.localId))
        .toList();
  }

  Future<List<CardSummary>> loadCards() async {
    final response = await _apiClient.get('/cards_loans/cards');
    return (response as List<dynamic>)
        .map((item) => CardSummary.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<List<BankAccountSummary>> loadAccounts() async {
    final response = await _apiClient.get('/banks/accounts');
    return (response as List<dynamic>)
        .map((item) => BankAccountSummary.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<void> updateExpense({
    required int expenseId,
    required String description,
    required String paymentMethod,
    required String expenseDate,
    required List<Map<String, dynamic>> items,
    int? cardId,
    int? bankAccountId,
  }) async {
    await _apiClient.put('/expenses/$expenseId', {
      'description': description,
      'payment_method': paymentMethod,
      'expense_date': expenseDate,
      'card_id': cardId,
      'bank_account_id': bankAccountId,
      'items': items,
    });
  }

  Future<void> deleteExpense(int expenseId) async {
    await _apiClient.delete('/expenses/$expenseId');
  }
}
