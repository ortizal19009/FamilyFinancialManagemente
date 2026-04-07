import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../home/presentation/home_shell.dart';
import '../../settings/presentation/backend_settings_screen.dart';
import '../data/auth_service.dart';
import '../domain/user_session.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _restoreSession() async {
    final session = await _authService.restoreSession();
    if (!mounted || session == null) {
      return;
    }
    _openHome(session);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final session = await _authService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) {
        return;
      }
      _openHome(session);
    } catch (error) {
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _openHome(UserSession session) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => HomeShell(session: session),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF7F0E6),
              Color(0xFFEBDDCB),
              Color(0xFFDDEAE3),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: -30,
                left: -40,
                child: _GlowOrb(
                  size: 190,
                  colors: const [Color(0x55BF6D4F), Color(0x00BF6D4F)],
                ),
              ),
              Positioned(
                right: -30,
                top: 120,
                child: _GlowOrb(
                  size: 170,
                  colors: const [Color(0x551F5C57), Color(0x001F5C57)],
                ),
              ),
              Positioned(
                bottom: -60,
                left: 60,
                child: _GlowOrb(
                  size: 220,
                  colors: const [Color(0x33D8BFA7), Color(0x00D8BFA7)],
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 470),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const _LogoBadge(),
                              const SizedBox(height: 20),
                              Text(
                                'Family Finance',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.headlineMedium,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Controla tus finanzas familiares con una experiencia elegante, local y sincronizable.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: AppTheme.pineDeep.withValues(alpha: 0.78),
                                    ),
                              ),
                              const SizedBox(height: 28),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  labelText: 'Correo',
                                  prefixIcon: Icon(Icons.alternate_email_rounded),
                                ),
                                validator: (value) =>
                                    value == null || value.isEmpty ? 'Ingresa tu correo' : null,
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: true,
                                decoration: const InputDecoration(
                                  labelText: 'Contrasena',
                                  prefixIcon: Icon(Icons.lock_outline_rounded),
                                ),
                                validator: (value) => value == null || value.isEmpty
                                    ? 'Ingresa tu contrasena'
                                    : null,
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF2EF),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0x33B94A48),
                                    ),
                                  ),
                                  child: Text(
                                    _error!,
                                    style: const TextStyle(color: Color(0xFFB94A48)),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 20),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [AppTheme.pine, AppTheme.pineDeep],
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.pineDeep.withValues(alpha: 0.16),
                                      blurRadius: 22,
                                      offset: const Offset(0, 12),
                                    ),
                                  ],
                                ),
                                child: FilledButton(
                                  onPressed: _loading ? null : _submit,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                  ),
                                  child: Text(_loading ? 'Ingresando...' : 'Ingresar'),
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextButton(
                                onPressed: _loading
                                    ? null
                                    : () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => const RegisterScreen(),
                                          ),
                                        );
                                      },
                                child: const Text('Crear cuenta'),
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: _loading
                                    ? null
                                    : () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => const BackendSettingsScreen(),
                                          ),
                                        );
                                      },
                                icon: const Icon(Icons.settings_ethernet_rounded),
                                label: const Text('Configurar backend'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoBadge extends StatelessWidget {
  const _LogoBadge();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 104,
        height: 104,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.clay, AppTheme.pine],
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.pineDeep.withValues(alpha: 0.18),
              blurRadius: 26,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.16),
              ),
            ),
            const Icon(
              Icons.account_balance_wallet_rounded,
              size: 46,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
    required this.size,
    required this.colors,
  });

  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: colors),
        ),
      ),
    );
  }
}
