import 'package:flutter/material.dart';

import '../../api/error_messages.dart';
import '../../config.dart';
import '../../models/models.dart';
import '../../state/session.dart';
import '../../utils/format.dart';
import '../../theme/platter_theme.dart';
import '../../widgets/brand.dart';
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
      message:
          'Tu plan cambiará a ${plan.name} (${formatSoles(plan.priceSoles)} al mes). '
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
    final user = session.user;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              const PageHeader(title: 'Cuenta', subtitle: 'Datos de tu restaurante, tu plan y tu sesión.'),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 980),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (user != null)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  GradientAvatar(name: user.name, size: 56),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(user.name, style: theme.textTheme.titleLarge),
                                        Text(
                                          user.email,
                                          style: theme.textTheme.bodyMedium?.copyWith(
                                            color: theme.colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: _logout,
                                    icon: const Icon(Icons.logout_rounded),
                                    label: const Text('Cerrar sesión'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const SectionTitle('Restaurante'),
                                  TextFormField(
                                    controller: _name,
                                    textCapitalization: TextCapitalization.words,
                                    decoration: const InputDecoration(
                                      labelText: 'Nombre',
                                      prefixIcon: Icon(Icons.storefront_outlined),
                                    ),
                                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa el nombre' : null,
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _address,
                                    decoration: const InputDecoration(
                                      labelText: 'Dirección',
                                      prefixIcon: Icon(Icons.place_outlined),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: FilledButton.icon(
                                      onPressed: _savingProfile ? null : _saveProfile,
                                      icon: const Icon(Icons.check_rounded),
                                      label: Text(_savingProfile ? 'Guardando…' : 'Guardar cambios'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (plan != null)
                          Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              gradient: PlatterColors.brandGradient,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.workspace_premium_rounded, color: Colors.white),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Plan ${plan.name}',
                                      style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${formatSoles(plan.priceSoles)} / mes',
                                      style: theme.textTheme.titleSmall?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                _UsageBar(label: 'Mesas', used: restaurant!.tableCount, max: plan.maxTables),
                                const SizedBox(height: 14),
                                _UsageBar(label: 'Platos', used: restaurant.dishCount, max: plan.maxDishes),
                              ],
                            ),
                          ),
                        const SizedBox(height: 24),
                        const SectionTitle('Planes disponibles'),
                        if (_plansError != null)
                          ErrorBanner(message: _plansError!, onRetry: _refresh)
                        else if (_plans == null)
                          const LinearProgressIndicator()
                        else
                          LayoutBuilder(
                            builder: (context, c) {
                              final cols = c.maxWidth >= 720 ? 3 : 1;
                              final w = (c.maxWidth - 14 * (cols - 1)) / cols;
                              return Wrap(
                                spacing: 14,
                                runSpacing: 14,
                                children: [
                                  for (final p in _plans!)
                                    SizedBox(
                                      width: w,
                                      child: _PlanCard(
                                        plan: p,
                                        current: p.code == plan?.code,
                                        busy: _changingPlan == p.code,
                                        enabled: _changingPlan == null,
                                        onSelect: () => _changePlan(p),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        const SizedBox(height: 20),
                        Text(
                          'API: ${AppConfig.apiBaseUrl}',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
                        ),
                      ],
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

class _UsageBar extends StatelessWidget {
  const _UsageBar({required this.label, required this.used, required this.max});

  final String label;
  final int used;
  final int? max;

  @override
  Widget build(BuildContext context) {
    final limit = max;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              limit == null ? '$used · ilimitado' : '$used de $limit',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: limit == null || limit == 0 ? 0.04 : (used / limit).clamp(0, 1).toDouble(),
            minHeight: 8,
            color: Colors.white,
            backgroundColor: Colors.white.withValues(alpha: 0.22),
          ),
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    String limit(int? n, String what) =>
        n != null ? 'Hasta $n $what' : (what == 'mesas' ? 'Mesas ilimitadas' : 'Platos ilimitados');
    final features = [
      limit(plan.maxTables, 'mesas'),
      limit(plan.maxDishes, 'platos'),
      if (plan.aiAnalysis) 'Fichas con IA',
      'Carta en Realidad Aumentada',
    ];
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: current ? scheme.primary : scheme.outlineVariant, width: current ? 2 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(plan.name, style: theme.textTheme.titleLarge),
                const Spacer(),
                if (current)
                  Pill(label: 'Tu plan', background: scheme.primaryContainer, foreground: scheme.onPrimaryContainer),
              ],
            ),
            const SizedBox(height: 6),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: formatSoles(plan.priceSoles),
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text: ' / mes',
                    style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            for (final f in features)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(Icons.check_rounded, size: 18, color: PlatterColors.huacatayLight),
                    const SizedBox(width: 8),
                    Expanded(child: Text(f, style: theme.textTheme.bodyMedium)),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: current
                  ? OutlinedButton(onPressed: null, child: const Text('Plan actual'))
                  : busy
                  ? const Center(
                      child: SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : FilledButton(onPressed: enabled ? onSelect : null, child: Text('Cambiar a ${plan.name}')),
            ),
          ],
        ),
      ),
    );
  }
}
