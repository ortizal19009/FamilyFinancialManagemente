class InvestmentSummary {
  const InvestmentSummary({
    required this.id,
    required this.userName,
    required this.institution,
    required this.investmentType,
    required this.title,
    required this.owner,
    required this.investedAmount,
    required this.currentValue,
    required this.profitLoss,
    required this.expectedReturnRate,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.notes,
  });

  final int id;
  final String? userName;
  final String institution;
  final String investmentType;
  final String title;
  final String? owner;
  final double investedAmount;
  final double currentValue;
  final double profitLoss;
  final double? expectedReturnRate;
  final String? startDate;
  final String? endDate;
  final String status;
  final String? notes;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_name': userName,
      'institution': institution,
      'investment_type': investmentType,
      'title': title,
      'owner': owner,
      'invested_amount': investedAmount,
      'current_value': currentValue,
      'profit_loss': profitLoss,
      'expected_return_rate': expectedReturnRate,
      'start_date': startDate,
      'end_date': endDate,
      'status': status,
      'notes': notes,
    };
  }

  factory InvestmentSummary.fromMap(Map<String, dynamic> map) {
    final investedAmount = (map['invested_amount'] as num?)?.toDouble() ?? 0;
    final currentValue = (map['current_value'] as num?)?.toDouble() ?? 0;
    return InvestmentSummary(
      id: map['id'] as int? ?? 0,
      userName: map['user_name'] as String?,
      institution: map['institution'] as String? ?? '',
      investmentType: map['investment_type'] as String? ?? '',
      title: map['title'] as String? ?? '',
      owner: map['owner'] as String?,
      investedAmount: investedAmount,
      currentValue: currentValue,
      profitLoss: (map['profit_loss'] as num?)?.toDouble() ?? (currentValue - investedAmount),
      expectedReturnRate: (map['expected_return_rate'] as num?)?.toDouble(),
      startDate: map['start_date'] as String?,
      endDate: map['end_date'] as String?,
      status: map['status'] as String? ?? 'activa',
      notes: map['notes'] as String?,
    );
  }
}
