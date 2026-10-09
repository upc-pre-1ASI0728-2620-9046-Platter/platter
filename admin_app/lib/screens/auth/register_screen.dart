import 'package:flutter/material.dart';

import '../../api/api_exception.dart';
import '../../api/error_messages.dart';
import '../../state/session.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ownerName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _restaurantName = TextEditingController();
  final _address = TextEditingController();
  bool _loading = false;
  String? _error;
  Map<String, String> _fieldErrors = const {};

  @override
  void dispose() {
    for (final c in [_ownerName, _email, _password, _restaurantName, _address]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _fieldErrors = const {});
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await SessionScope.read(context).register(
        ownerName: _ownerName.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
        restaurantName: _restaurantName.text.trim(),
        address: _address.text.trim(),
      );
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        if (e is ApiException) _fieldErrors = e.fieldErrors;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _required(String? v, String msg) => (v == null || v.trim().isEmpty) ? msg : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registra tu restaurante')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _ownerName,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Tu nombre',
                        prefixIcon: const Icon(Icons.person_outline),
                        errorText: _fieldErrors['ownerName'],
                      ),
                      validator: (v) => _required(v, 'Ingresa tu nombre'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Correo electrónico',
                        prefixIcon: const Icon(Icons.email_outlined),
                        errorText: _fieldErrors['email'],
                      ),
                      validator: validateEmail,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        helperText: 'Mínimo 8 caracteres',
                        prefixIcon: const Icon(Icons.lock_outline),
                        errorText: _fieldErrors['password'],
                      ),
                      validator: (v) => (v == null || v.length < 8) ? 'Mínimo 8 caracteres' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _restaurantName,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Nombre del restaurante',
                        prefixIcon: const Icon(Icons.storefront_outlined),
                        errorText: _fieldErrors['restaurantName'],
                      ),
                      validator: (v) => _required(v, 'Ingresa el nombre del restaurante'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _address,
                      decoration: InputDecoration(
                        labelText: 'Dirección (opcional)',
                        prefixIcon: const Icon(Icons.place_outlined),
                        errorText: _fieldErrors['address'],
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Crear cuenta'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
