class AssetSummary {
  const AssetSummary({
    required this.id,
    required this.name,
    required this.owner,
    required this.value,
    required this.description,
    required this.purchaseDate,
  });

  final int id;
  final String name;
  final String? owner;
  final double value;
  final String? description;
  final String? purchaseDate;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'owner': owner,
      'value': value,
      'description': description,
      'purchase_date': purchaseDate,
    };
  }

  factory AssetSummary.fromMap(Map<String, dynamic> map) {
    return AssetSummary(
      id: map['id'] as int? ?? 0,
      name: map['name'] as String? ?? '',
      owner: map['owner'] as String?,
      value: (map['value'] as num?)?.toDouble() ?? 0,
      description: map['description'] as String?,
      purchaseDate: map['purchase_date'] as String?,
    );
  }
}

class IncomeSummary {
  const IncomeSummary({
    required this.id,
    required this.userName,
    required this.amount,
    required this.source,
    required this.incomeDate,
    required this.description,
  });

  final int id;
  final String? userName;
  final double amount;
  final String source;
  final String incomeDate;
  final String? description;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_name': userName,
      'amount': amount,
      'source': source,
      'income_date': incomeDate,
      'description': description,
    };
  }

  factory IncomeSummary.fromMap(Map<String, dynamic> map) {
    return IncomeSummary(
      id: map['id'] as int? ?? 0,
      userName: map['user_name'] as String?,
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      source: map['source'] as String? ?? '',
      incomeDate: map['income_date'] as String? ?? '',
      description: map['description'] as String?,
    );
  }
}

class AssetsSnapshot {
  const AssetsSnapshot({
    required this.assets,
    required this.income,
    required this.loadedFromCache,
  });

  final List<AssetSummary> assets;
  final List<IncomeSummary> income;
  final bool loadedFromCache;
}
