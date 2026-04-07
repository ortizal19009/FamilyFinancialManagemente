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
