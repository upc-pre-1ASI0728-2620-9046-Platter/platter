import 'package:flutter/material.dart';

import '../../api/error_messages.dart';
import '../../state/session.dart';
import 'register_screen.dart';

String? validateEmail(String? v) {
  final value = v?.trim() ?? '';
  if (value.isEmpty) return 'Ingresa tu correo';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) return 'Correo no válido';
  return null;
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await SessionScope.read(context).login(_email.text.trim(), _password.text);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(Icons.restaurant_menu, size: 64, color: theme.colorScheme.primary),
                      const SizedBox(height: 12),
                      Text('Platter', textAlign: TextAlign.center, style: theme.textTheme.headlineMedium),
                      const SizedBox(height: 4),
                      Text(
                        'Tu carta digital con realidad aumentada',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 32),
                      TextFormField(
                        key: const Key('login-email'),
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Correo electrónico',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: validateEmail,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('login-password'),
                        controller: _password,
                        obscureText: _obscure,
                        autofillHints: const [AutofillHints.password],
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: _obscure ? 'Mostrar' : 'Ocultar',
                            icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? 'Ingresa tu contraseña' : null,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Iniciar sesión'),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _loading
                            ? null
                            : () => Navigator.of(context)
                                .push(MaterialPageRoute<void>(builder: (_) => const RegisterScreen())),
                        child: const Text('¿Nuevo en Platter? Registra tu restaurante'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
