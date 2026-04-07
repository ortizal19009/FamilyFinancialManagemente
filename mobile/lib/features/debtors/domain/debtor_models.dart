class DebtorSummary {
  const DebtorSummary({
    required this.id,
    required this.name,
    required this.amountOwed,
    required this.description,
    required this.dueDate,
    required this.status,
  });

  final int id;
  final String name;
  final double amountOwed;
  final String? description;
  final String? dueDate;
  final String status;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'amount_owed': amountOwed,
      'description': description,
      'due_date': dueDate,
      'status': status,
    };
  }

  factory DebtorSummary.fromMap(Map<String, dynamic> map) {
    return DebtorSummary(
      id: map['id'] as int? ?? 0,
      name: map['name'] as String? ?? '',
      amountOwed: (map['amount_owed'] as num?)?.toDouble() ?? 0,
      description: map['description'] as String?,
      dueDate: map['due_date'] as String?,
      status: map['status'] as String? ?? '',
    );
  }
}

class SmallDebtSummary {
  const SmallDebtSummary({
    required this.id,
    required this.lenderName,
    required this.amount,
    required this.description,
    required this.borrowedDate,
    required this.dueDate,
    required this.status,
  });

  final int id;
  final String lenderName;
  final double amount;
  final String? description;
  final String? borrowedDate;
  final String? dueDate;
  final String status;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'lender_name': lenderName,
      'amount': amount,
      'description': description,
      'borrowed_date': borrowedDate,
      'due_date': dueDate,
      'status': status,
    };
  }

  factory SmallDebtSummary.fromMap(Map<String, dynamic> map) {
    return SmallDebtSummary(
      id: map['id'] as int? ?? 0,
      lenderName: map['lender_name'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      description: map['description'] as String?,
      borrowedDate: map['borrowed_date'] as String?,
      dueDate: map['due_date'] as String?,
      status: map['status'] as String? ?? 'pendiente',
    );
  }
}
