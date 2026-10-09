import 'package:flutter/material.dart';

import '../../api/error_messages.dart';
import '../../models/analytics.dart';
import '../../state/session.dart';
import '../../utils/format.dart';
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
    try {
      final s = await SessionScope.read(context).api.analyticsSummary(days: days);
      if (mounted && days == _days) setState(() => _summary = s);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Métricas'),
        actions: [IconButton(tooltip: 'Actualizar', onPressed: _load, icon: const Icon(Icons.refresh))],
        bottom: _loading && _summary != null
            ? const PreferredSize(preferredSize: Size.fromHeight(4), child: LinearProgressIndicator())
            : null,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 7, label: Text('Últimos 7 días')),
                ButtonSegment(value: 30, label: Text('Últimos 30 días')),
              ],
              selected: {_days},
              onSelectionChanged: (s) {
                setState(() => _days = s.first);
                _load();
              },
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final s = _summary;
    if (_error != null && s == null) return ErrorView(message: _error!, onRetry: _load);
    if (s == null) return const LoadingView();
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null) ...[ErrorBanner(message: _error!, onRetry: _load), const SizedBox(height: 12)],
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth > 600 ? 4 : 2;
            final w = (c.maxWidth - 12 * (cols - 1)) / cols;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _KpiCard(width: w, icon: Icons.qr_code_scanner, label: 'QR escaneados', value: '${s.qrScans}'),
                _KpiCard(width: w, icon: Icons.visibility_outlined, label: 'Vistas de plato', value: '${s.dishViews}'),
                _KpiCard(width: w, icon: Icons.view_in_ar, label: 'Lanzamientos AR', value: '${s.arLaunches}'),
                _KpiCard(
                  width: w,
                  icon: Icons.timer_outlined,
                  label: 'Tiempo AR promedio',
                  value: formatSeconds(s.avgArSeconds),
                ),
              ],
            );
          }),
          const SizedBox(height: 24),
          Text('Platos más vistos', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (s.topDishes.isEmpty)
            const _EmptyRanking(text: 'Aún no hay vistas de platos en este periodo.')
          else
            ..._rankingRows(
              s.topDishes.map((d) => (d.name, d.views, '${d.views} vistas · ${d.arLaunches} AR')).toList(),
            ),
          const SizedBox(height: 24),
          Text('Mesas con más escaneos', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (s.topTables.isEmpty)
            const _EmptyRanking(text: 'Aún no hay escaneos de QR en este periodo.')
          else
            ..._rankingRows(s.topTables.map((t) => (t.label, t.scans, '${t.scans} escaneos')).toList()),
        ],
      ),
    );
  }

  List<Widget> _rankingRows(List<(String, int, String)> rows) {
    final max = rows.fold<int>(0, (m, r) => r.$2 > m ? r.$2 : m);
    return [for (final r in rows) _BarRow(label: r.$1, value: r.$2, max: max, caption: r.$3)];
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.width, required this.icon, required this.label, required this.value});

  final double width;
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: Card(
        margin: EdgeInsets.zero,
        color: theme.colorScheme.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text(value, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(label, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({required this.label, required this.value, required this.max, required this.caption});

  final String label;
  final int value;
  final int max;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = max == 0 ? 0.0 : value / max;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
              Text(caption, style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, c) => Stack(
              children: [
                Container(
                  height: 10,
                  width: c.maxWidth,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                Container(
                  height: 10,
                  width: c.maxWidth * fraction,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRanking extends StatelessWidget {
  const _EmptyRanking({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            )),
      );
}
