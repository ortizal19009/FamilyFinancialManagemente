import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/presentation/login_screen.dart';

class FamilyFinanceApp extends StatefulWidget {
  const FamilyFinanceApp({super.key});

  static _FamilyFinanceAppState? of(BuildContext context) {
    return context.findAncestorStateOfType<_FamilyFinanceAppState>();
  }

  @override
  State<FamilyFinanceApp> createState() => _FamilyFinanceAppState();
}

class _FamilyFinanceAppState extends State<FamilyFinanceApp> {
  final ThemeController _themeController = ThemeController();

  ThemeController get themeController => _themeController;

  @override
  void initState() {
    super.initState();
    _themeController.load();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _themeController,
      builder: (context, _) {
        if (!_themeController.loaded) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        return MaterialApp(
          title: 'Family Finance Mobile',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.byId(_themeController.selectedThemeId),
          home: const LoginScreen(),
        );
      },
    );
  }
}
