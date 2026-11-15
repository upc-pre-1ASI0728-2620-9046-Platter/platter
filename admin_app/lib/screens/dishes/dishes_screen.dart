import 'package:flutter/material.dart';

import '../../api/error_messages.dart';
import '../../models/dish.dart';
import '../../state/session.dart';
import '../../theme/platter_theme.dart';
import '../../utils/format.dart';
import '../../widgets/brand.dart';
import '../../widgets/dish_widgets.dart';
import '../../widgets/state_views.dart';
import 'dish_form_screen.dart';
import 'new_dish_screen.dart';

/// Carta: platos en tarjetas con foto, filtro por categoría y búsqueda (US18: agotado en un toque).
class DishesScreen extends StatefulWidget {
  const DishesScreen({super.key});

  @override
  State<DishesScreen> createState() => _DishesScreenState();
}

class _DishesScreenState extends State<DishesScreen> {
  List<Dish>? _dishes;
  String? _error;
  String? _category; // null = todas
  String _query = '';
  final _pending = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final dishes = await SessionScope.read(context).api.dishes();
      if (!mounted) return;
      setState(() {
        _dishes = dishes;
        if (_category != null && !dishes.any((d) => d.category == _category)) _category = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  Future<void> _toggleAvailability(Dish dish, bool available) async {
    final session = SessionScope.read(context);
    setState(() {
      _pending.add(dish.id);
      _replace(dish.copyWith(available: available));
    });
    try {
      final updated = await session.api.setDishAvailability(dish.id, available);
      if (mounted) setState(() => _replace(updated));
      if (mounted) {
        showSnack(context, available ? '${dish.name} está disponible' : '${dish.name}: agotado por hoy');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _replace(dish));
      showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _pending.remove(dish.id));
    }
  }

  void _replace(Dish d) {
    final list = _dishes;
    if (list == null) return;
    final i = list.indexWhere((x) => x.id == d.id);
    if (i >= 0) list[i] = d;
  }

  Future<void> _openNew() async {
    final created = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const NewDishScreen()));
    if (created == true && mounted) {
      _load();
      SessionScope.read(context).refreshRestaurant();
    }
  }

  Future<void> _openEdit(Dish dish) async {
    final changed = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => DishFormScreen.edit(dish: dish)));
    if (changed == true && mounted) {
      _load();
      SessionScope.read(context).refreshRestaurant();
    }
  }

  String _catOf(Dish d) => d.category.isEmpty ? 'Sin categoría' : d.category;

  @override
  Widget build(BuildContext context) {
    final dishes = _dishes;
    return Scaffold(
      floatingActionButton: dishes == null || dishes.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _openNew,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Nuevo plato'),
            ),
      body: SafeArea(bottom: false, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_error != null && _dishes == null) return ErrorView(message: _error!, onRetry: _load);
    final dishes = _dishes;
    if (dishes == null) return const LoadingView();
    final published = dishes.where((d) => d.status == DishStatus.published).length;
    final header = PageHeader(
      title: 'Carta',
      subtitle: dishes.isEmpty
          ? 'Aún no tienes platos'
          : '${dishes.length} platos · $published publicados · ${dishes.where((d) => !d.available).length} agotados hoy',
      actions: [IconButton(tooltip: 'Actualizar', onPressed: _load, icon: const Icon(Icons.refresh_rounded))],
    );
    if (dishes.isEmpty) {
      return Column(
        children: [
          header,
          Expanded(
            child: EmptyView(
              icon: Icons.restaurant_menu_rounded,
              title: 'Tu carta está vacía',
              message: 'Toma una foto de tu primer plato y la IA te ayudará a completar la ficha.',
              action: FilledButton.icon(
                onPressed: _openNew,
                icon: const Icon(Icons.add_a_photo_outlined),
                label: const Text('Nuevo plato'),
              ),
            ),
          ),
        ],
      );
    }

    final categories = <String>[];
    for (final d in dishes) {
      if (!categories.contains(_catOf(d))) categories.add(_catOf(d));
    }
    final q = _query.trim().toLowerCase();
    final visible = dishes
        .where((d) => _category == null || _catOf(d) == _category)
        .where((d) => q.isEmpty || d.name.toLowerCase().contains(q) || d.category.toLowerCase().contains(q))
        .toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: header),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                  hintText: 'Buscar plato o categoría',
                  prefixIcon: Icon(Icons.search_rounded),
                  isDense: true,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 60,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                children: [
                  _CategoryChip(
                    label: 'Todas',
                    count: dishes.length,
                    selected: _category == null,
                    onTap: () => setState(() => _category = null),
                  ),
                  for (final c in categories)
                    _CategoryChip(
                      label: c,
                      count: dishes.where((d) => _catOf(d) == c).length,
                      selected: _category == c,
                      onTap: () => setState(() => _category = c),
                    ),
                ],
              ),
            ),
          ),
          if (visible.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyView(icon: Icons.search_off_rounded, title: 'No hay platos que coincidan'),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 110),
              sliver: SliverLayoutBuilder(
                builder: (context, constraints) => SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    // Tarjetas de al menos ~260 px: una columna en celulares, varias en tablet y web.
                    crossAxisCount: (constraints.crossAxisExtent / 260).floor().clamp(1, 6),
                    mainAxisExtent: 318,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _DishCard(
                      dish: visible[i],
                      busy: _pending.contains(visible[i].id),
                      onTap: () => _openEdit(visible[i]),
                      onAvailabilityChanged: (v) => _toggleAvailability(visible[i], v),
                    ),
                    childCount: visible.length,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.count, required this.selected, required this.onTap});

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        showCheckmark: false,
        label: Text('$label  $count'),
        selected: selected,
        onSelected: (_) => onTap(),
        labelStyle: TextStyle(fontWeight: FontWeight.w600, color: selected ? scheme.onSecondary : scheme.onSurface),
      ),
    );
  }
}

class _DishCard extends StatelessWidget {
  const _DishCard({required this.dish, required this.busy, required this.onTap, required this.onAvailabilityChanged});

  final Dish dish;
  final bool busy;
  final VoidCallback onTap;
  final ValueChanged<bool> onAvailabilityChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final published = dish.status == DishStatus.published;
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 168,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColorFiltered(
                    colorFilter: dish.available
                        ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
                        : const ColorFilter.matrix(<double>[
                            0.33, 0.33, 0.33, 0, 0, //
                            0.33, 0.33, 0.33, 0, 0, //
                            0.33, 0.33, 0.33, 0, 0, //
                            0, 0, 0, 1, 0,
                          ]),
                    child: DishCover(url: dish.photoUrl),
                  ),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: Pill(
                      label: published ? 'Publicado' : 'Borrador',
                      icon: published ? Icons.check_circle_rounded : Icons.edit_note_rounded,
                      background: published ? PlatterColors.huacatay : const Color(0xFFFCE8BF),
                      foreground: published ? Colors.white : const Color(0xFF5A3D00),
                    ),
                  ),
                  if (dish.model != null)
                    Positioned(
                      right: 12,
                      top: 12,
                      child: Tooltip(
                        message: 'Con modelo 3D',
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.view_in_ar_rounded, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  if (!dish.available)
                    Positioned(
                      left: 12,
                      bottom: 12,
                      child: Pill(label: 'Agotado por hoy', background: scheme.error, foreground: scheme.onError),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dish.category.isEmpty ? 'Sin categoría' : dish.category.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: PlatterColors.terracotta,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dish.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(fontSize: 19, height: 1.15),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Text(
                          formatSoles(dish.priceSoles),
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const Spacer(),
                        Text(
                          dish.available ? 'Disponible' : 'Agotado',
                          style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        Transform.scale(
                          scale: 0.85,
                          child: Switch(value: dish.available, onChanged: busy ? null : onAvailabilityChanged),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
