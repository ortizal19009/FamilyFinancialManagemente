class CardSummary {
  const CardSummary({
    required this.id,
    required this.bankId,
    required this.bankName,
    required this.cardName,
    required this.owner,
    required this.cardType,
    required this.lastFourDigits,
    required this.creditLimit,
    required this.currentDebt,
    required this.availableBalance,
  });

  final int id;
  final int bankId;
  final String bankName;
  final String cardName;
  final String? owner;
  final String? cardType;
  final String? lastFourDigits;
  final double creditLimit;
  final double currentDebt;
  final double availableBalance;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bank_id': bankId,
      'bank_name': bankName,
      'card_name': cardName,
      'owner': owner,
      'card_type': cardType,
      'last_four_digits': lastFourDigits,
      'credit_limit': creditLimit,
      'current_debt': currentDebt,
      'available_balance': availableBalance,
    };
  }

  factory CardSummary.fromMap(Map<String, dynamic> map) {
    return CardSummary(
      id: map['id'] as int? ?? 0,
      bankId: map['bank_id'] as int? ?? 0,
      bankName: map['bank_name'] as String? ?? '',
      cardName: map['card_name'] as String? ?? '',
      owner: map['owner'] as String?,
      cardType: map['card_type'] as String?,
      lastFourDigits: map['last_four_digits'] as String?,
      creditLimit: (map['credit_limit'] as num?)?.toDouble() ?? 0,
      currentDebt: (map['current_debt'] as num?)?.toDouble() ?? 0,
      availableBalance: (map['available_balance'] as num?)?.toDouble() ?? 0,
    );
  }
}

class LoanSummary {
  const LoanSummary({
    required this.id,
    required this.bankId,
    required this.bankName,
    required this.description,
    required this.owner,
    required this.initialAmount,
    required this.pendingInstallments,
    required this.totalInstallments,
    required this.monthlyPayment,
    required this.startDate,
  });

  final int id;
  final int? bankId;
  final String bankName;
  final String description;
  final String? owner;
  final double initialAmount;
  final int pendingInstallments;
  final int totalInstallments;
  final double monthlyPayment;
  final String? startDate;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bank_id': bankId,
      'bank_name': bankName,
      'description': description,
      'owner': owner,
      'initial_amount': initialAmount,
      'pending_installments': pendingInstallments,
      'total_installments': totalInstallments,
      'monthly_payment': monthlyPayment,
      'start_date': startDate,
    };
  }

  factory LoanSummary.fromMap(Map<String, dynamic> map) {
    return LoanSummary(
      id: map['id'] as int? ?? 0,
      bankId: map['bank_id'] as int?,
      bankName: map['bank_name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      owner: map['owner'] as String?,
      initialAmount: (map['initial_amount'] as num?)?.toDouble() ?? 0,
      pendingInstallments: map['pending_installments'] as int? ?? 0,
      totalInstallments: map['total_installments'] as int? ?? 0,
      monthlyPayment: (map['monthly_payment'] as num?)?.toDouble() ?? 0,
      startDate: map['start_date'] as String?,
    );
  }
}

class CardsSnapshot {
  const CardsSnapshot({
    required this.cards,
    required this.loans,
    required this.loadedFromCache,
  });

  final List<CardSummary> cards;
  final List<LoanSummary> loans;
  final bool loadedFromCache;
}
