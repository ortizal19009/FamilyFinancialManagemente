import '../../../core/app_services.dart';
import '../../../core/network/api_client.dart';
import '../../../core/offline/local_cache_storage.dart';
import '../../../core/offline/offline_operation.dart';
import '../../banks/domain/bank_models.dart';
import '../domain/cards_models.dart';

class MobileCardsRepository {
  MobileCardsRepository({
    ApiClient? apiClient,
    LocalCacheStorage? cacheStorage,
  })  : _apiClient = apiClient ?? ApiClient(),
        _cacheStorage = cacheStorage ?? LocalCacheStorage();

  final ApiClient _apiClient;
  final LocalCacheStorage _cacheStorage;

  static const _cardsCacheKey = 'mobile_cards_cache';
  static const _loansCacheKey = 'mobile_loans_cache';

  Future<CardsSnapshot> loadSnapshot() async {
    try {
      final cardsResponse = await _apiClient.get('/cards_loans/cards');
      final loansResponse = await _apiClient.get('/cards_loans/loans');

      final cards = (cardsResponse as List<dynamic>)
          .map((item) => CardSummary.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList();
      final loans = (loansResponse as List<dynamic>)
          .map((item) => LoanSummary.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList();
      final pendingCards = await _loadPendingLocalCards();
      final pendingLoans = await _loadPendingLocalLoans();
      final mergedCards = [...pendingCards, ...cards];
      final mergedLoans = [...pendingLoans, ...loans];

      await _cacheStorage.saveCollection(
        _cardsCacheKey,
        mergedCards.map((item) => item.toMap()).toList(),
      );
      await _cacheStorage.saveCollection(
        _loansCacheKey,
        mergedLoans.map((item) => item.toMap()).toList(),
      );

      return CardsSnapshot(
        cards: mergedCards,
        loans: mergedLoans,
        loadedFromCache: false,
      );
    } catch (_) {
      final cardsCache = await _cacheStorage.getCollection(_cardsCacheKey);
      final loansCache = await _cacheStorage.getCollection(_loansCacheKey);
      return CardsSnapshot(
        cards: cardsCache.map(CardSummary.fromMap).toList(),
        loans: loansCache.map(LoanSummary.fromMap).toList(),
        loadedFromCache: true,
      );
    }
  }

  Future<List<BankSummary>> loadBanks() async {
    try {
      final response = await _apiClient.get('/banks/');
      return (response as List<dynamic>)
          .map((item) => BankSummary.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (_) {
      final cached = await _cacheStorage.getCollection('mobile_banks_cache');
      return cached.map(BankSummary.fromMap).toList();
    }
  }

  Future<void> createCard({
    required int bankId,
    required String cardName,
    String? owner,
    String? lastFourDigits,
    String cardType = 'Débito',
    double creditLimit = 0,
    double currentDebt = 0,
    double availableBalance = 0,
  }) async {
    final banks = await _cacheStorage.getCollection('mobile_banks_cache');
    final matchedBank = banks.firstWhere(
      (item) => item['id'] == bankId,
      orElse: () => <String, dynamic>{},
    );
    final localCard = CardSummary(
      id: _nextLocalId(),
      bankId: bankId,
      bankName: matchedBank['name'] as String? ?? '',
      cardName: cardName,
      owner: owner,
      cardType: cardType,
      lastFourDigits: lastFourDigits,
      creditLimit: creditLimit,
      currentDebt: currentDebt,
      availableBalance: availableBalance,
    );
    final cached = await _cacheStorage.getCollection(_cardsCacheKey);
    await _cacheStorage.saveCollection(_cardsCacheKey, [localCard.toMap(), ...cached]);
    await AppServices.syncService.enqueue(OfflineOperation(
      id: 'card-${localCard.id}',
      module: 'cards',
      method: 'POST',
      path: '/cards_loans/cards',
      payload: {
        'bank_id': bankId,
        'card_name': cardName,
        'owner': owner,
        'last_four_digits': lastFourDigits,
        'card_type': cardType,
        'credit_limit': creditLimit,
        'current_debt': currentDebt,
        'available_balance': availableBalance,
      },
      createdAt: DateTime.now(),
    ));
  }

  Future<List<CardSummary>> _loadPendingLocalCards() async {
    final cached = await _cacheStorage.getCollection(_cardsCacheKey);
    return cached.map(CardSummary.fromMap).where((item) => item.id < 0).toList();
  }

  Future<List<LoanSummary>> _loadPendingLocalLoans() async {
    final cached = await _cacheStorage.getCollection(_loansCacheKey);
    return cached.map(LoanSummary.fromMap).where((item) => item.id < 0).toList();
  }

  int _nextLocalId() => -DateTime.now().microsecondsSinceEpoch;

  Future<void> updateCard({
    required int cardId,
    required int bankId,
    required String cardName,
    String? owner,
    String? lastFourDigits,
    String cardType = 'Débito',
    double creditLimit = 0,
    double currentDebt = 0,
    double availableBalance = 0,
  }) async {
    if (cardId < 0) {
      final banks = await _cacheStorage.getCollection('mobile_banks_cache');
      final matchedBank = banks.firstWhere(
        (item) => item['id'] == bankId,
        orElse: () => <String, dynamic>{},
      );
      final cached = await _cacheStorage.getCollection(_cardsCacheKey);
      final updated = cached
          .map((item) => item['id'] == cardId
              ? {
                  ...item,
                  'bank_id': bankId,
                  'bank_name': matchedBank['name'] as String? ?? '',
                  'card_name': cardName,
                  'owner': owner,
                  'last_four_digits': lastFourDigits,
                  'card_type': cardType,
                  'credit_limit': creditLimit,
                  'current_debt': currentDebt,
                  'available_balance': availableBalance,
                }
              : item)
          .toList();
      await _cacheStorage.saveCollection(_cardsCacheKey, updated);
      return;
    }
    await _apiClient.put('/cards_loans/cards/$cardId', {
      'bank_id': bankId,
      'card_name': cardName,
      'owner': owner,
      'last_four_digits': lastFourDigits,
      'card_type': cardType,
      'credit_limit': creditLimit,
      'current_debt': currentDebt,
      'available_balance': availableBalance,
    });
  }

  Future<void> deleteCard(int cardId) async {
    if (cardId < 0) {
      final cached = await _cacheStorage.getCollection(_cardsCacheKey);
      await _cacheStorage.saveCollection(
        _cardsCacheKey,
        cached.where((item) => item['id'] != cardId).toList(),
      );
      return;
    }
    await _apiClient.delete('/cards_loans/cards/$cardId');
  }

  Future<void> createLoan({
    int? bankId,
    required String description,
    String? owner,
    required double initialAmount,
    required int totalInstallments,
    required int pendingInstallments,
    required double monthlyPayment,
    double? interestRate,
    String? startDate,
  }) async {
    final banks = await _cacheStorage.getCollection('mobile_banks_cache');
    final matchedBank = banks.firstWhere(
      (item) => item['id'] == bankId,
      orElse: () => <String, dynamic>{},
    );
    final localLoan = LoanSummary(
      id: _nextLocalId(),
      bankId: bankId,
      bankName: matchedBank['name'] as String? ?? 'Sin banco',
      description: description,
      owner: owner,
      initialAmount: initialAmount,
      pendingInstallments: pendingInstallments,
      totalInstallments: totalInstallments,
      monthlyPayment: monthlyPayment,
      startDate: startDate,
    );
    final cached = await _cacheStorage.getCollection(_loansCacheKey);
    await _cacheStorage.saveCollection(_loansCacheKey, [localLoan.toMap(), ...cached]);
    await AppServices.syncService.enqueue(OfflineOperation(
      id: 'loan-${localLoan.id}',
      module: 'cards',
      method: 'POST',
      path: '/cards_loans/loans',
      payload: {
        'bank_id': bankId,
        'description': description,
        'owner': owner,
        'initial_amount': initialAmount,
        'total_installments': totalInstallments,
        'pending_installments': pendingInstallments,
        'monthly_payment': monthlyPayment,
        'interest_rate': interestRate,
        'start_date': startDate,
      },
      createdAt: DateTime.now(),
    ));
  }

  Future<void> updateLoan({
    required int loanId,
    int? bankId,
    required String description,
    String? owner,
    required double initialAmount,
    required int totalInstallments,
    required int pendingInstallments,
    required double monthlyPayment,
    double? interestRate,
    String? startDate,
  }) async {
    if (loanId < 0) {
      final banks = await _cacheStorage.getCollection('mobile_banks_cache');
      final matchedBank = banks.firstWhere(
        (item) => item['id'] == bankId,
        orElse: () => <String, dynamic>{},
      );
      final cached = await _cacheStorage.getCollection(_loansCacheKey);
      final updated = cached
          .map((item) => item['id'] == loanId
              ? {
                  ...item,
                  'bank_id': bankId,
                  'bank_name': matchedBank['name'] as String? ?? 'Sin banco',
                  'description': description,
                  'owner': owner,
                  'initial_amount': initialAmount,
                  'total_installments': totalInstallments,
                  'pending_installments': pendingInstallments,
                  'monthly_payment': monthlyPayment,
                  'start_date': startDate,
                }
              : item)
          .toList();
      await _cacheStorage.saveCollection(_loansCacheKey, updated);
      return;
    }
    await _apiClient.put('/cards_loans/loans/$loanId', {
      'bank_id': bankId,
      'description': description,
      'owner': owner,
      'initial_amount': initialAmount,
      'total_installments': totalInstallments,
      'pending_installments': pendingInstallments,
      'monthly_payment': monthlyPayment,
      'interest_rate': interestRate,
      'start_date': startDate,
    });
  }

  Future<void> deleteLoan(int loanId) async {
    if (loanId < 0) {
      final cached = await _cacheStorage.getCollection(_loansCacheKey);
      await _cacheStorage.saveCollection(
        _loansCacheKey,
        cached.where((item) => item['id'] != loanId).toList(),
      );
      return;
    }
    await _apiClient.delete('/cards_loans/loans/$loanId');
  }
}
