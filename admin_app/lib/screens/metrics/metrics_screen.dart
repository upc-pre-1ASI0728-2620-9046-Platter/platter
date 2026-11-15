import 'package:flutter/material.dart';

import '../../api/error_messages.dart';
import '../../models/analytics.dart';
import '../../models/dish.dart';
import '../../state/session.dart';
import '../../theme/platter_theme.dart';
import '../../utils/format.dart';
import '../../widgets/brand.dart';
import '../../widgets/dish_widgets.dart';
import '../../widgets/state_views.dart';

/// Métricas de uso de la carta (US19).
class MetricsScreen extends StatefulWidget {
  const MetricsScreen({super.key});

  @override
  State<MetricsScreen> createState() => _MetricsScreenState();
}

class _MetricsScreenState extends State<MetricsScreen> {
  int _days = 7;
  AnalyticsSummary? _summary;
  Map<String, Dish> _dishes = const {};
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final days = _days;
    final api = SessionScope.read(context).api;
    try {
      final s = await api.analyticsSummary(days: days);
      if (mounted && days == _days) setState(() => _summary = s);
      if (_dishes.isEmpty) {
        final list = await api.dishes();
        if (mounted) setState(() => _dishes = {for (final d in list) d.id: d});
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: SafeArea(bottom: false, child: _buildBody()));
  }

  Widget _buildBody() {
    final s = _summary;
    if (_error != null && s == null) return ErrorView(message: _error!, onRetry: _load);
    if (s == null) return const LoadingView();
    return RefreshIndicator(
      onRefresh: _load,
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 980;
          final pad = c.maxWidth >= 600 ? 20.0 : 16.0;
          return ListView(
            padding: EdgeInsets.fromLTRB(0, 0, 0, 32),
            children: [
              PageHeader(
                title: 'Métricas',
                subtitle: 'Cómo usan tus clientes la carta. Datos anónimos, sin registro.',
                actions: [
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                ],
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: pad, vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 7, label: Text('7 días')),
                      ButtonSegment(value: 30, label: Text('30 días')),
                    ],
                    selected: {_days},
                    onSelectionChanged: (sel) {
                      setState(() => _days = sel.first);
                      _load();
                    },
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: pad, vertical: 8),
                child: Column(
                  children: [
                    if (_error != null) ...[ErrorBanner(message: _error!, onRetry: _load), const SizedBox(height: 12)],
                    KpiGrid(
                      children: [
                        KpiTile(
                          icon: Icons.qr_code_scanner_rounded,
                          label: 'QR escaneados',
                          value: '${s.qrScans}',
                          caption: 'Visitas a la carta',
                          tone: PlatterColors.terracotta,
                        ),
                        KpiTile(
                          icon: Icons.visibility_outlined,
                          label: 'Vistas de plato',
                          value: '${s.dishViews}',
                          caption: s.qrScans == 0
                              ? 'Fichas abiertas'
                              : '${(s.dishViews / s.qrScans).toStringAsFixed(1)} por visita',
                          tone: const Color(0xFF2F6FB0),
                        ),
                        KpiTile(
                          icon: Icons.view_in_ar_rounded,
                          label: 'Lanzamientos AR',
                          value: '${s.arLaunches}',
                          caption: 'Platos vistos en la mesa',
                          tone: PlatterColors.huacatayLight,
                        ),
                        KpiTile(
                          icon: Icons.timer_outlined,
                          label: 'Tiempo en AR',
                          value: formatSeconds(s.avgArSeconds),
                          caption: 'Promedio por sesión',
                          tone: const Color(0xFFC98A10),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: _dishesCard(s)),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: Column(children: [_arCard(s), const SizedBox(height: 16), _tablesCard(s)]),
                          ),
                        ],
                      )
                    else ...[
                      _arCard(s),
                      const SizedBox(height: 16),
                      _dishesCard(s),
                      const SizedBox(height: 16),
                      _tablesCard(s),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _arCard(AnalyticsSummary s) {
    final theme = Theme.of(context);
    final rate = s.dishViews == 0 ? 0.0 : s.arLaunches / s.dishViews;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            RingGauge(
              fraction: rate,
              size: 116,
              center: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(rate * 100).round()}%',
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text('en AR', style: theme.textTheme.labelSmall),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tasa de Realidad Aumentada', style: theme.textTheme.titleLarge?.copyWith(fontSize: 19)),
                  const SizedBox(height: 6),
                  Text(
                    s.dishViews == 0
                        ? 'Aún no hay vistas de platos en este periodo.'
                        : 'De cada 10 clientes que abren un plato, ${(rate * 10).round()} lo ven sobre su mesa.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dishesCard(AnalyticsSummary s) {
    final theme = Theme.of(context);
    final max = s.topDishes.fold<int>(1, (m, d) => d.views > m ? d.views : m);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle('Platos más vistos'),
            if (s.topDishes.isEmpty)
              const _EmptyRanking(text: 'Aún no hay vistas de platos en este periodo.')
            else
              for (final (i, d) in s.topDishes.indexed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text(
                          '${i + 1}',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: i < 3 ? PlatterColors.terracotta : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      DishPhoto(url: _dishes[d.dishId]?.photoUrl, size: 48, radius: 12),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    d.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _MiniStat(icon: Icons.visibility_outlined, value: d.views),
                                const SizedBox(width: 10),
                                _MiniStat(icon: Icons.view_in_ar_rounded, value: d.arLaunches),
                              ],
                            ),
                            const SizedBox(height: 8),
                            GradientBar(fraction: d.views / max),
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

  Widget _tablesCard(AnalyticsSummary s) {
    final theme = Theme.of(context);
    final max = s.topTables.fold<int>(1, (m, t) => t.scans > m ? t.scans : m);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle('Mesas con más escaneos'),
            if (s.topTables.isEmpty)
              const _EmptyRanking(text: 'Aún no hay escaneos de QR en este periodo.')
            else
              for (final t in s.topTables)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: PlatterColors.huacatay.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.table_restaurant_rounded, size: 20, color: PlatterColors.huacatayLight),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text(t.label, style: theme.textTheme.bodyLarge)),
                                Text(
                                  '${t.scans}',
                                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            GradientBar(
                              fraction: t.scans / max,
                              height: 6,
                              colors: const [PlatterColors.huacatayLight, PlatterColors.huacatay],
                            ),
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
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.icon, required this.value});

  final IconData icon;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 3),
        Text('$value', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _EmptyRanking extends StatelessWidget {
  const _EmptyRanking({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );
}
