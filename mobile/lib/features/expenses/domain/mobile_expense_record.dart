class MobileExpenseRecord {
  const MobileExpenseRecord({
    required this.localId,
    required this.description,
    required this.amount,
    required this.categoryId,
    required this.categoryName,
    required this.paymentMethod,
    required this.expenseDate,
    required this.syncStatus,
    this.items = const [],
    this.cardId,
    this.bankAccountId,
    this.serverId,
  });

  final String localId;
  final int? serverId;
  final String description;
  final double amount;
  final int categoryId;
  final String categoryName;
  final String paymentMethod;
  final String expenseDate;
  final String syncStatus;
  final List<Map<String, dynamic>> items;
  final int? cardId;
  final int? bankAccountId;

  MobileExpenseRecord copyWith({
    int? serverId,
    String? syncStatus,
  }) {
    return MobileExpenseRecord(
      localId: localId,
      serverId: serverId ?? this.serverId,
      description: description,
      amount: amount,
      categoryId: categoryId,
      categoryName: categoryName,
      paymentMethod: paymentMethod,
      expenseDate: expenseDate,
      syncStatus: syncStatus ?? this.syncStatus,
      items: items,
      cardId: cardId,
      bankAccountId: bankAccountId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'local_id': localId,
      'server_id': serverId,
      'description': description,
      'amount': amount,
      'category_id': categoryId,
      'category_name': categoryName,
      'payment_method': paymentMethod,
      'expense_date': expenseDate,
      'sync_status': syncStatus,
      'items': items,
      'card_id': cardId,
      'bank_account_id': bankAccountId,
    };
  }

  factory MobileExpenseRecord.fromMap(Map<String, dynamic> map) {
    return MobileExpenseRecord(
      localId: map['local_id'] as String,
      serverId: map['server_id'] as int?,
      description: map['description'] as String? ?? '',
      amount: (map['amount'] as num).toDouble(),
      categoryId: map['category_id'] as int,
      categoryName: map['category_name'] as String? ?? '',
      paymentMethod: map['payment_method'] as String? ?? 'Efectivo',
      expenseDate: map['expense_date'] as String? ?? '',
      syncStatus: map['sync_status'] as String? ?? 'pending',
      items: ((map['items'] as List?) ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(),
      cardId: map['card_id'] as int?,
      bankAccountId: map['bank_account_id'] as int?,
    );
  }
}
