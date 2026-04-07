import '../../../core/network/api_client.dart';
import '../../../core/offline/local_cache_storage.dart';
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

      await _cacheStorage.saveCollection(
        _cardsCacheKey,
        cards.map((item) => item.toMap()).toList(),
      );
      await _cacheStorage.saveCollection(
        _loansCacheKey,
        loans.map((item) => item.toMap()).toList(),
      );

      return CardsSnapshot(
        cards: cards,
        loans: loans,
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
    final response = await _apiClient.get('/banks/');
    return (response as List<dynamic>)
        .map((item) => BankSummary.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
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
    await _apiClient.post('/cards_loans/cards', {
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
    await _apiClient.delete('/cards_loans/cards/$cardId');
  }
}
