class BankSummary {
  const BankSummary({
    required this.id,
    required this.name,
    required this.description,
  });

  final int id;
  final String name;
  final String? description;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
    };
  }

  factory BankSummary.fromMap(Map<String, dynamic> map) {
    return BankSummary(
      id: map['id'] as int? ?? 0,
      name: map['name'] as String? ?? '',
      description: map['description'] as String?,
    );
  }
}

class BankAccountSummary {
  const BankAccountSummary({
    required this.id,
    required this.bankId,
    required this.bankName,
    required this.accountNumber,
    required this.accountType,
    required this.owner,
    required this.currentBalance,
  });

  final int id;
  final int bankId;
  final String bankName;
  final String accountNumber;
  final String? accountType;
  final String? owner;
  final double currentBalance;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bank_id': bankId,
      'bank_name': bankName,
      'account_number': accountNumber,
      'account_type': accountType,
      'owner': owner,
      'current_balance': currentBalance,
    };
  }

  factory BankAccountSummary.fromMap(Map<String, dynamic> map) {
    return BankAccountSummary(
      id: map['id'] as int? ?? 0,
      bankId: map['bank_id'] as int? ?? 0,
      bankName: map['bank_name'] as String? ?? '',
      accountNumber: map['account_number'] as String? ?? '',
      accountType: map['account_type'] as String?,
      owner: map['owner'] as String?,
      currentBalance: (map['current_balance'] as num?)?.toDouble() ?? 0,
    );
  }
}

class BanksSnapshot {
  const BanksSnapshot({
    required this.banks,
    required this.accounts,
    required this.loadedFromCache,
  });

  final List<BankSummary> banks;
  final List<BankAccountSummary> accounts;
  final bool loadedFromCache;
}
