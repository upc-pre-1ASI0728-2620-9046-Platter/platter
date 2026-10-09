import 'package:flutter/material.dart';

import '../../api/error_messages.dart';
import '../../config.dart';
import '../../models/models.dart';
import '../../state/session.dart';
import '../../utils/format.dart';
import '../../widgets/state_views.dart';

/// Perfil del restaurante, plan y uso, cierre de sesión.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _address = TextEditingController();
  List<Plan>? _plans;
  String? _plansError;
  bool _savingProfile = false;
  String? _changingPlan;

  @override
  void initState() {
    super.initState();
    _fillProfile(SessionScope.read(context).restaurant);
    _refresh();
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    super.dispose();
  }

  void _fillProfile(Restaurant? r) {
    _name.text = r?.name ?? '';
    _address.text = r?.address ?? '';
  }

  Future<void> _refresh() async {
    final session = SessionScope.read(context);
    setState(() => _plansError = null);
    await session.refreshRestaurant();
    if (mounted) _fillProfile(session.restaurant);
    try {
      final plans = await session.api.plans();
      if (mounted) setState(() => _plans = plans);
    } catch (e) {
      if (mounted) setState(() => _plansError = friendlyError(e));
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final session = SessionScope.read(context);
    setState(() => _savingProfile = true);
    try {
      final r = await session.api.updateRestaurant(
        name: _name.text.trim(),
        address: _address.text.trim().isEmpty ? null : _address.text.trim(),
      );
      session.setRestaurant(r);
      if (mounted) showSnack(context, 'Datos del restaurante guardados');
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _changePlan(Plan plan) async {
    final ok = await confirmDialog(
      context,
      title: 'Cambiar a ${plan.name}',
      message: 'Tu plan cambiará a ${plan.name} (${formatSoles(plan.priceSoles)} al mes). '
          'En esta versión no se realiza ningún cobro.',
      confirmLabel: 'Cambiar plan',
    );
    if (!ok || !mounted) return;
    final session = SessionScope.read(context);
    setState(() => _changingPlan = plan.code);
    try {
      session.setRestaurant(await session.api.changePlan(plan.code));
      if (mounted) showSnack(context, 'Ahora tienes el plan ${plan.name}');
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _changingPlan = null);
    }
  }

  Future<void> _logout() async {
    final ok = await confirmDialog(
      context,
      title: 'Cerrar sesión',
      message: '¿Quieres cerrar tu sesión en este dispositivo?',
      confirmLabel: 'Cerrar sesión',
    );
    if (ok && mounted) await SessionScope.read(context).logout();
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final restaurant = session.restaurant;
    final plan = restaurant?.plan;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Cuenta')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (session.user != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  child: Text(session.user!.name.isNotEmpty ? session.user!.name[0].toUpperCase() : '?'),
                ),
                title: Text(session.user!.name),
                subtitle: Text(session.user!.email),
              ),
            const SizedBox(height: 8),
            Text('Restaurante', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa el nombre' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _address,
                    decoration: const InputDecoration(labelText: 'Dirección'),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonal(
                      onPressed: _savingProfile ? null : _saveProfile,
                      child: Text(_savingProfile ? 'Guardando…' : 'Guardar datos'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Plan y uso', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            if (plan != null)
              Card(
                margin: EdgeInsets.zero,
                color: theme.colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Plan ${plan.name}', style: theme.textTheme.titleLarge),
                      Text('${formatSoles(plan.priceSoles)} / mes'
                          '${plan.aiAnalysis ? ' · Incluye análisis con IA' : ' · Sin análisis con IA'}'),
                      const SizedBox(height: 16),
                      _UsageBar(label: 'Mesas', used: restaurant!.tableCount, max: plan.maxTables),
                      const SizedBox(height: 12),
                      _UsageBar(label: 'Platos', used: restaurant.dishCount, max: plan.maxDishes),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            if (_plansError != null)
              ErrorBanner(message: _plansError!, onRetry: _refresh)
            else if (_plans == null)
              const LinearProgressIndicator()
            else
              for (final p in _plans!)
                _PlanTile(
                  plan: p,
                  current: p.code == plan?.code,
                  busy: _changingPlan == p.code,
                  enabled: _changingPlan == null,
                  onSelect: () => _changePlan(p),
                ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text('Cerrar sesión'),
            ),
            const SizedBox(height: 16),
            Text(
              'API: ${AppConfig.apiBaseUrl}',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _UsageBar extends StatelessWidget {
  const _UsageBar({required this.label, required this.used, required this.max});

  final String label;
  final int used;
  final int? max;

  @override
  Widget build(BuildContext context) {
    final limit = max;
    final reached = limit != null && used >= limit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(
              limit == null ? '$used · ilimitado' : '$used de $limit',
              style: reached ? TextStyle(color: Theme.of(context).colorScheme.error) : null,
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: limit == null || limit == 0 ? 0 : (used / limit).clamp(0, 1).toDouble(),
          color: reached ? Theme.of(context).colorScheme.error : null,
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
      ],
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({
    required this.plan,
    required this.current,
    required this.busy,
    required this.enabled,
    required this.onSelect,
  });

  final Plan plan;
  final bool current;
  final bool busy;
  final bool enabled;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    String limit(int? n, String what) => n == null ? '$what ilimitados' : 'hasta $n $what';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text('${plan.name} · ${formatSoles(plan.priceSoles)} / mes'),
        subtitle: Text(
          '${limit(plan.maxTables, 'mesas')}, ${limit(plan.maxDishes, 'platos')}'
          '${plan.aiAnalysis ? ', análisis con IA' : ''}',
        ),
        trailing: current
            ? const Chip(label: Text('Actual'))
            : busy
                ? const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : TextButton(onPressed: enabled ? onSelect : null, child: const Text('Elegir')),
      ),
    );
  }
}
