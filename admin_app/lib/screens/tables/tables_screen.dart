import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api/api_exception.dart';
import '../../api/error_messages.dart';
import '../../models/dining_table.dart';
import '../../state/session.dart';
import '../../theme/platter_theme.dart';
import '../../utils/launch.dart';
import '../../widgets/brand.dart';
import '../../widgets/state_views.dart';

/// Mesas y códigos QR (US11/US12).
class TablesScreen extends StatefulWidget {
  const TablesScreen({super.key});

  @override
  State<TablesScreen> createState() => _TablesScreenState();
}

class _TablesScreenState extends State<TablesScreen> {
  List<DiningTable>? _tables;
  String? _error;
  final _selected = <String>{};
  final _pending = <String>{};

  bool get _selecting => _selected.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final tables = await SessionScope.read(context).api.tables();
      if (!mounted) return;
      setState(() {
        _tables = tables;
        _selected.removeWhere((id) => !tables.any((t) => t.id == id));
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  String _tableError(Object e) {
    if (e is ApiException && e.code == 'PLAN_LIMIT_REACHED') {
      final max = SessionScope.read(context).restaurant?.plan?.maxTables;
      return max == null
          ? 'Alcanzaste el límite de mesas de tu plan. Mejóralo en la pestaña Cuenta.'
          : 'Tu plan permite hasta $max mesas. Mejóralo en la pestaña Cuenta para agregar más.';
    }
    if (e is ApiException && e.code == 'DUPLICATE_TABLE') {
      return 'Ya existe una mesa con esa etiqueta. Usa un nombre distinto.';
    }
    return friendlyError(e);
  }

  Future<void> _afterCreate(String message) async {
    showSnack(context, message);
    await _load();
    if (mounted) await SessionScope.read(context).refreshRestaurant();
  }

  Future<void> _addTable() async {
    final label = await showDialog<String>(context: context, builder: (_) => const _AddTableDialog());
    if (label == null || !mounted) return;
    try {
      final t = await SessionScope.read(context).api.createTable(label);
      if (mounted) await _afterCreate('Se creó "${t.label}"');
    } catch (e) {
      if (mounted) showSnack(context, _tableError(e), error: true);
    }
  }

  Future<void> _generateTables() async {
    final req = await showDialog<_BatchRequest>(context: context, builder: (_) => const _BatchDialog());
    if (req == null || !mounted) return;
    try {
      final created = await SessionScope.read(
        context,
      ).api.createTablesBatch(from: req.from, to: req.to, prefix: req.prefix);
      if (!mounted) return;
      final requested = req.to - req.from + 1;
      final msg = created.isEmpty
          ? 'No se crearon mesas: todas las etiquetas ya existían.'
          : created.length < requested
          ? 'Se crearon ${created.length} mesas (se omitieron ${requested - created.length} existentes).'
          : 'Se crearon ${created.length} mesas.';
      await _afterCreate(msg);
    } catch (e) {
      if (mounted) showSnack(context, _tableError(e), error: true);
    }
  }

  Future<void> _toggleActive(DiningTable t, bool active) async {
    setState(() {
      _pending.add(t.id);
      _replace(t.copyWith(active: active));
    });
    try {
      final updated = await SessionScope.read(context).api.setTableActive(t.id, active);
      if (mounted) setState(() => _replace(updated));
    } catch (e) {
      if (!mounted) return;
      setState(() => _replace(t));
      showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _pending.remove(t.id));
    }
  }

  void _replace(DiningTable t) {
    final list = _tables;
    if (list == null) return;
    final i = list.indexWhere((x) => x.id == t.id);
    if (i >= 0) list[i] = t;
  }

  void _downloadPdf({List<String>? ids}) {
    final session = SessionScope.read(context);
    final token = session.token;
    if (token == null) return;
    openExternal(context, session.api.qrSheetUri(ids: ids, token: token));
  }

  void _toggleSelection(DiningTable t) {
    setState(() => _selected.contains(t.id) ? _selected.remove(t.id) : _selected.add(t.id));
  }

  void _showQr(DiningTable t) {
    showDialog<void>(
      context: context,
      builder: (_) => _QrDialog(
        table: t,
        onDownloadPdf: () => _downloadPdf(ids: [t.id]),
      ),
    );
  }

  void _showAddMenu() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text('Generar mesas'),
              subtitle: const Text('Crea un rango, p. ej. Mesa 1 a Mesa 20'),
              onTap: () {
                Navigator.pop(context);
                _generateTables();
              },
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Agregar mesa'),
              subtitle: const Text('Con una etiqueta libre, p. ej. Terraza 01'),
              onTap: () {
                Navigator.pop(context);
                _addTable();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _selecting
          ? AppBar(
              leading: IconButton(
                tooltip: 'Cancelar selección',
                icon: const Icon(Icons.close),
                onPressed: () => setState(_selected.clear),
              ),
              title: Text('${_selected.length} seleccionada${_selected.length == 1 ? '' : 's'}'),
              actions: [
                IconButton(
                  tooltip: 'Seleccionar todas',
                  icon: const Icon(Icons.select_all),
                  onPressed: () => setState(() => _selected.addAll(_tables?.map((t) => t.id) ?? const [])),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: FilledButton.icon(
                    onPressed: () => _downloadPdf(ids: _selected.toList()),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('PDF'),
                  ),
                ),
              ],
            )
          : null,
      floatingActionButton: _tables?.isNotEmpty == true && !_selecting
          ? FloatingActionButton.extended(
              onPressed: _showAddMenu,
              icon: const Icon(Icons.add),
              label: const Text('Agregar mesas'),
            )
          : null,
      body: SafeArea(bottom: false, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_error != null && _tables == null) return ErrorView(message: _error!, onRetry: _load);
    final tables = _tables;
    if (tables == null) return const LoadingView();
    if (tables.isEmpty) {
      return EmptyView(
        icon: Icons.qr_code_2,
        title: 'Aún no tienes mesas',
        message:
            'Crea tus mesas para generar un código QR por cada una. '
            'Tus comensales lo escanean para ver la carta en realidad aumentada.',
        action: Column(
          children: [
            FilledButton.icon(
              onPressed: _generateTables,
              icon: const Icon(Icons.playlist_add),
              label: const Text('Generar mesas'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(onPressed: _addTable, icon: const Icon(Icons.add), label: const Text('Agregar una mesa')),
          ],
        ),
      );
    }
    final session = SessionScope.of(context);
    final restaurant = session.restaurant;
    final max = restaurant?.plan?.maxTables;
    final active = tables.where((t) => t.active).length;
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        slivers: [
          if (!_selecting)
            SliverToBoxAdapter(
              child: PageHeader(
                title: 'Mesas y QR',
                subtitle:
                    'Cada mesa tiene su propio código. Toca una para verlo; mantén presionado para elegir varias.',
                actions: [IconButton(tooltip: 'Actualizar', onPressed: _load, icon: const Icon(Icons.refresh_rounded))],
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: PlatterColors.sidebarGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Wrap(
                  spacing: 24,
                  runSpacing: 16,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    _Stat(value: '${tables.length}', label: max != null ? 'mesas de $max' : 'mesas'),
                    _Stat(value: '$active', label: 'activas'),
                    if (restaurant?.plan != null) _Stat(value: restaurant!.plan!.name, label: 'tu plan'),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: PlatterColors.aji,
                        foregroundColor: PlatterColors.ink,
                      ),
                      onPressed: _downloadPdf,
                      icon: const Icon(Icons.print_rounded),
                      label: const Text('Imprimir todos los QR'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                mainAxisExtent: 250,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
              delegate: SliverChildBuilderDelegate((context, i) {
                final t = tables[i];
                final selected = _selected.contains(t.id);
                return _TableCard(
                  table: t,
                  qrUrl: session.api.tableQrUrl(t.id, size: 256),
                  selected: selected,
                  selecting: _selecting,
                  busy: _pending.contains(t.id),
                  onTap: _selecting ? () => _toggleSelection(t) : () => _showQr(t),
                  onLongPress: () => _toggleSelection(t),
                  onActiveChanged: (v) => _toggleActive(t, v),
                  theme: theme,
                );
              }, childCount: tables.length),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: theme.textTheme.headlineMedium?.copyWith(color: PlatterColors.cream, fontWeight: FontWeight.w700),
        ),
        Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: PlatterColors.cream.withValues(alpha: 0.7))),
      ],
    );
  }
}

class _TableCard extends StatelessWidget {
  const _TableCard({
    required this.table,
    required this.qrUrl,
    required this.selected,
    required this.selecting,
    required this.busy,
    required this.onTap,
    required this.onLongPress,
    required this.onActiveChanged,
    required this.theme,
  });

  final DiningTable table;
  final String qrUrl;
  final bool selected;
  final bool selecting;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final ValueChanged<bool> onActiveChanged;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: selected ? scheme.primary : scheme.outlineVariant, width: selected ? 2 : 1),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 8, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Center(
                  child: Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                        child: Opacity(
                          opacity: table.active ? 1 : 0.35,
                          child: _QrImage(url: qrUrl, size: 116),
                        ),
                      ),
                      if (selecting)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Icon(
                            selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                            color: selected ? scheme.primary : scheme.outline,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                table.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(fontSize: 18),
              ),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: table.active ? PlatterColors.huacatayLight : scheme.outline,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      table.active ? 'Activa' : 'Inactiva',
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                  Transform.scale(
                    scale: 0.8,
                    child: Switch(value: table.active, onChanged: busy || selecting ? null : onActiveChanged),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Imagen del QR (endpoint autenticado) con el JWT en la cabecera.
class _QrImage extends StatelessWidget {
  const _QrImage({required this.url, required this.size});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final api = SessionScope.read(context).api;
    return Container(
      width: size,
      height: size,
      color: Colors.white,
      child: Image.network(
        url,
        headers: api.client.authHeaders,
        width: size,
        height: size,
        filterQuality: FilterQuality.none,
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : const Center(child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))),
        errorBuilder: (_, _, _) => Icon(Icons.qr_code_2, size: size * 0.7, color: Colors.black54),
      ),
    );
  }
}

class _QrDialog extends StatelessWidget {
  const _QrDialog({required this.table, required this.onDownloadPdf});

  final DiningTable table;
  final VoidCallback onDownloadPdf;

  @override
  Widget build(BuildContext context) {
    final api = SessionScope.read(context).api;
    return AlertDialog(
      title: Text(table.label),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _QrImage(url: api.tableQrUrl(table.id, size: 512), size: 240),
            ),
            const SizedBox(height: 12),
            SelectableText(table.menuUrl, textAlign: TextAlign.center),
            if (!table.active)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Esta mesa está inactiva.', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ],
        ),
      ),
      actionsOverflowButtonSpacing: 4,
      actions: [
        TextButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: table.menuUrl));
            showSnack(context, 'Enlace copiado');
          },
          icon: const Icon(Icons.copy),
          label: const Text('Copiar enlace'),
        ),
        TextButton.icon(
          onPressed: () => openExternal(context, Uri.parse(table.menuUrl)),
          icon: const Icon(Icons.open_in_new),
          label: const Text('Abrir carta'),
        ),
        FilledButton.icon(
          onPressed: onDownloadPdf,
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('Descargar PDF'),
        ),
      ],
    );
  }
}

class _AddTableDialog extends StatefulWidget {
  const _AddTableDialog();

  @override
  State<_AddTableDialog> createState() => _AddTableDialogState();
}

class _AddTableDialogState extends State<_AddTableDialog> {
  final _formKey = GlobalKey<FormState>();
  final _label = TextEditingController();

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) Navigator.pop(context, _label.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Agregar mesa'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _label,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Etiqueta', hintText: 'Terraza 01'),
          onFieldSubmitted: (_) => _submit(),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa una etiqueta' : null,
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _submit, child: const Text('Agregar')),
      ],
    );
  }
}

class _BatchRequest {
  const _BatchRequest(this.from, this.to, this.prefix);
  final int from;
  final int to;
  final String prefix;
}

class _BatchDialog extends StatefulWidget {
  const _BatchDialog();

  @override
  State<_BatchDialog> createState() => _BatchDialogState();
}

class _BatchDialogState extends State<_BatchDialog> {
  final _formKey = GlobalKey<FormState>();
  final _from = TextEditingController(text: '1');
  final _to = TextEditingController(text: '10');
  final _prefix = TextEditingController(text: 'Mesa');

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    _prefix.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, _BatchRequest(int.parse(_from.text), int.parse(_to.text), _prefix.text.trim()));
  }

  String? _number(String? v) {
    final n = int.tryParse(v ?? '');
    if (n == null || n < 1) return 'Número ≥ 1';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final digits = [FilteringTextInputFormatter.digitsOnly];
    return AlertDialog(
      title: const Text('Generar mesas'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _prefix,
              decoration: const InputDecoration(labelText: 'Prefijo'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa un prefijo' : null,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _from,
                    keyboardType: TextInputType.number,
                    inputFormatters: digits,
                    decoration: const InputDecoration(labelText: 'Desde'),
                    validator: _number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _to,
                    keyboardType: TextInputType.number,
                    inputFormatters: digits,
                    decoration: const InputDecoration(labelText: 'Hasta'),
                    validator: (v) {
                      final base = _number(v);
                      if (base != null) return base;
                      final from = int.tryParse(_from.text) ?? 1;
                      final to = int.parse(v!);
                      if (to < from) return 'Debe ser ≥ desde';
                      if (to - from >= 200) return 'Máx. 200 a la vez';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListenableBuilder(
              listenable: Listenable.merge([_prefix, _from, _to]),
              builder: (context, _) => Text(
                'Se crearán: ${_prefix.text.trim()} ${_from.text} … ${_prefix.text.trim()} ${_to.text}\n'
                'Las etiquetas que ya existan se omitirán.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _submit, child: const Text('Generar')),
      ],
    );
  }
}
