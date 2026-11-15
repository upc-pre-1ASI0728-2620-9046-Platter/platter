import 'package:flutter/material.dart';

import '../../api/error_messages.dart';
import '../../models/models.dart';
import '../../state/session.dart';
import '../../theme/platter_theme.dart';
import '../../utils/format.dart';
import '../../utils/launch.dart';
import '../../widgets/brand.dart';
import '../../widgets/dish_widgets.dart';
import '../../widgets/state_views.dart';
import '../dishes/new_dish_screen.dart';
import '../home_screen.dart';

/// Inicio: resumen del restaurante en una sola pantalla.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Dish>? _dishes;
  List<DiningTable>? _tables;
  AnalyticsSummary? _summary;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = SessionScope.read(context);
    setState(() => _error = null);
    try {
      final results = await Future.wait([
        session.api.dishes(),
        session.api.tables(),
        session.api.analyticsSummary(days: 7),
      ]);
      if (!mounted) return;
      setState(() {
        _dishes = results[0] as List<Dish>;
        _tables = results[1] as List<DiningTable>;
        _summary = results[2] as AnalyticsSummary;
      });
      session.refreshRestaurant();
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  void _go(HomeTab tab) => HomeNav.maybeOf(context)?.goTo(tab);

  Future<void> _newDish() async {
    final created = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const NewDishScreen()));
    if (created == true && mounted) _load();
  }

  String? get _menuUrl {
    final tables = _tables ?? const <DiningTable>[];
    for (final t in tables) {
      if (t.active && t.menuUrl.isNotEmpty) return t.menuUrl;
    }
    return null;
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Buenos días';
    if (h < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && _dishes == null) {
      return Scaffold(
        body: ErrorView(message: _error!, onRetry: _load),
      );
    }
    if (_dishes == null) return const Scaffold(body: LoadingView());
    final session = SessionScope.of(context);
    final theme = Theme.of(context);
    final firstName = (session.user?.name ?? '').split(' ').first;
    final date = MaterialLocalizations.of(context).formatFullDate(DateTime.now());

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 1000;
            final pad = c.maxWidth >= 600 ? 28.0 : 16.0;
            final left = <Widget>[_topDishes(), const SizedBox(height: 18), _quickActions()];
            final right = <Widget>[_menuHealth(), const SizedBox(height: 18), _tablesCard()];
            return ListView(
              padding: EdgeInsets.fromLTRB(pad, pad, pad, 32),
              children: [
                Text(
                  date[0].toUpperCase() + date.substring(1),
                  style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_greeting()}${firstName.isNotEmpty ? ', $firstName' : ''}',
                  style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 20),
                _hero(session.restaurant),
                const SizedBox(height: 20),
                _kpis(),
                const SizedBox(height: 20),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: Column(children: left)),
                      const SizedBox(width: 18),
                      Expanded(flex: 2, child: Column(children: right)),
                    ],
                  )
                else ...[
                  ...left,
                  const SizedBox(height: 18),
                  ...right,
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _hero(Restaurant? r) {
    final theme = Theme.of(context);
    final published = _dishes!.where((d) => d.status == DishStatus.published).length;
    final url = _menuUrl;
    return Container(
      decoration: BoxDecoration(
        gradient: PlatterColors.brandGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: PlatterColors.terracotta.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          const Positioned.fill(child: PlateRings(opacity: 0.13)),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Pill(
                  label: 'CARTA EN VIVO',
                  icon: Icons.circle,
                  background: Color(0x33FFFFFF),
                  foreground: Colors.white,
                ),
                const SizedBox(height: 14),
                Text(
                  r?.name ?? 'Tu restaurante',
                  style: theme.textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  published == 0
                      ? 'Publica tu primer plato para que tus clientes lo vean en su mesa.'
                      : '$published plato${published == 1 ? '' : 's'} visibles en Realidad Aumentada'
                            '${r?.address?.isNotEmpty == true ? ' · ${r!.address}' : ''}',
                  style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white.withValues(alpha: 0.88)),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: PlatterColors.terracottaDeep,
                      ),
                      onPressed: url == null ? null : () => openExternal(context, Uri.parse(url)),
                      icon: const Icon(Icons.view_in_ar_rounded),
                      label: const Text('Ver mi carta'),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.6)),
                      ),
                      onPressed: _newDish,
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: const Text('Nuevo plato'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpis() {
    final s = _summary!;
    final rate = s.dishViews == 0 ? 0 : (s.arLaunches * 100 / s.dishViews).round();
    return KpiGrid(
      children: [
        KpiTile(
          icon: Icons.qr_code_scanner_rounded,
          label: 'Escaneos de QR',
          value: '${s.qrScans}',
          caption: 'Últimos 7 días',
          tone: PlatterColors.terracotta,
        ),
        KpiTile(
          icon: Icons.visibility_outlined,
          label: 'Platos vistos',
          value: '${s.dishViews}',
          caption: 'Fichas abiertas',
          tone: const Color(0xFF2F6FB0),
        ),
        KpiTile(
          icon: Icons.view_in_ar_rounded,
          label: 'Vistas en AR',
          value: '${s.arLaunches}',
          caption: 'Platos sobre la mesa',
          tone: PlatterColors.huacatayLight,
        ),
        KpiTile(
          icon: Icons.bolt_rounded,
          label: 'Tasa de AR',
          value: '$rate%',
          caption: 'De cada 100 vistas',
          tone: const Color(0xFFC98A10),
        ),
      ],
    );
  }

  Widget _topDishes() {
    final theme = Theme.of(context);
    final byId = {for (final d in _dishes!) d.id: d};
    final top = _summary!.topDishes.where((t) => byId.containsKey(t.dishId)).take(5).toList();
    final max = top.fold<int>(1, (m, t) => t.views + t.arLaunches > m ? t.views + t.arLaunches : m);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(
              'Platos estrella',
              trailing: TextButton(onPressed: () => _go(HomeTab.metricas), child: const Text('Ver métricas')),
            ),
            if (top.isEmpty)
              Text(
                'Cuando tus clientes escaneen el QR, aquí verás los platos que más miran.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              )
            else
              for (final (i, t) in top.indexed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 26,
                        child: Text(
                          '${i + 1}',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: i == 0 ? PlatterColors.terracotta : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      DishPhoto(url: byId[t.dishId]!.photoUrl, size: 52, radius: 14),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    t.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                Text(
                                  '${t.views} vistas · ${t.arLaunches} AR',
                                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            GradientBar(fraction: (t.views + t.arLaunches) / max),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _quickActions() {
    final actions = [
      (Icons.add_a_photo_outlined, 'Nuevo plato', 'Foto + IA', _newDish),
      (Icons.qr_code_2_rounded, 'Mesas y QR', 'Imprime tus códigos', () => _go(HomeTab.mesas)),
      (Icons.restaurant_menu_rounded, 'Editar carta', 'Precios y agotados', () => _go(HomeTab.carta)),
      (Icons.workspace_premium_outlined, 'Mi plan', 'Uso y límites', () => _go(HomeTab.cuenta)),
    ];
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle('Accesos rápidos'),
            LayoutBuilder(
              builder: (context, c) {
                final cols = c.maxWidth >= 520 ? 4 : 2;
                final w = (c.maxWidth - 12 * (cols - 1)) / cols;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final a in actions)
                      SizedBox(
                        width: w,
                        child: Material(
                          color: theme.colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: a.$4,
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(a.$1, color: PlatterColors.terracotta),
                                  const SizedBox(height: 10),
                                  Text(a.$2, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                                  Text(
                                    a.$3,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuHealth() {
    final theme = Theme.of(context);
    final dishes = _dishes!;
    final published = dishes.where((d) => d.status == DishStatus.published).length;
    final drafts = dishes.length - published;
    final soldOut = dishes.where((d) => !d.available).length;
    Widget row(IconData icon, Color tone, String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: tone.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 20, color: tone),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
          Text(value, style: theme.textTheme.titleLarge),
        ],
      ),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(
              'Tu carta',
              trailing: TextButton(onPressed: () => _go(HomeTab.carta), child: const Text('Gestionar')),
            ),
            row(Icons.check_circle_rounded, PlatterColors.huacatayLight, 'Publicados', '$published'),
            row(Icons.edit_note_rounded, const Color(0xFFC98A10), 'Borradores', '$drafts'),
            row(Icons.do_not_disturb_on_outlined, theme.colorScheme.error, 'Agotados hoy', '$soldOut'),
            if (SessionScope.of(context).restaurant?.plan?.maxDishes case final max?) ...[
              const SizedBox(height: 12),
              Text(
                '${dishes.length} de $max platos de tu plan',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 6),
              GradientBar(
                fraction: dishes.length / max,
                colors: const [PlatterColors.huacatayLight, PlatterColors.huacatay],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tablesCard() {
    final theme = Theme.of(context);
    final tables = _tables!;
    final active = tables.where((t) => t.active).length;
    final top = _summary!.topTables.isEmpty ? null : _summary!.topTables.first;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(
              'Mesas',
              trailing: TextButton(onPressed: () => _go(HomeTab.mesas), child: const Text('Ver QR')),
            ),
            Row(
              children: [
                RingGauge(
                  fraction: tables.isEmpty ? 0 : active / tables.length,
                  size: 92,
                  stroke: 10,
                  center: Text('$active', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$active de ${tables.length} mesas activas',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        top == null
                            ? 'Aún no hay escaneos esta semana.'
                            : 'La más activa: ${top.label} (${top.scans} escaneos)',
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      if (_summary!.avgArSeconds > 0) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Tiempo medio en AR: ${formatSeconds(_summary!.avgArSeconds)}',
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
