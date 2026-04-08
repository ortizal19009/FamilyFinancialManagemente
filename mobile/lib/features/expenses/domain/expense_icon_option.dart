import 'package:flutter/material.dart';

class ExpenseIconOption {
  const ExpenseIconOption({
    required this.key,
    required this.label,
    required this.icon,
  });

  final String key;
  final String label;
  final IconData icon;
}

const expenseIconOptions = [
  ExpenseIconOption(key: 'food', label: 'Alimentos', icon: Icons.restaurant_rounded),
  ExpenseIconOption(key: 'health', label: 'Medicina', icon: Icons.medical_services_rounded),
  ExpenseIconOption(key: 'home', label: 'Vivienda', icon: Icons.home_rounded),
  ExpenseIconOption(key: 'car', label: 'Transporte', icon: Icons.directions_car_rounded),
  ExpenseIconOption(key: 'school', label: 'Educacion', icon: Icons.school_rounded),
  ExpenseIconOption(key: 'gamepad', label: 'Entretenimiento', icon: Icons.sports_esports_rounded),
  ExpenseIconOption(key: 'bolt', label: 'Servicios', icon: Icons.bolt_rounded),
  ExpenseIconOption(key: 'wallet', label: 'Finanzas', icon: Icons.account_balance_wallet_rounded),
  ExpenseIconOption(key: 'shopping', label: 'Compras', icon: Icons.shopping_bag_rounded),
  ExpenseIconOption(key: 'family', label: 'Familia', icon: Icons.family_restroom_rounded),
  ExpenseIconOption(key: 'work', label: 'Trabajo', icon: Icons.work_rounded),
  ExpenseIconOption(key: 'plus', label: 'Otros', icon: Icons.add_circle_rounded),
];
