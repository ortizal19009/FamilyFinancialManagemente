class ExpenseCategory {
  const ExpenseCategory({
    required this.id,
    required this.name,
    this.icon,
  });

  final int id;
  final String name;
  final String? icon;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
    };
  }

  factory ExpenseCategory.fromMap(Map<String, dynamic> map) {
    return ExpenseCategory(
      id: map['id'] as int,
      name: map['name'] as String? ?? '',
      icon: map['icon'] as String?,
    );
  }
}
