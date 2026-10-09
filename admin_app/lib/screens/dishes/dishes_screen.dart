import 'package:flutter/material.dart';

import '../../api/error_messages.dart';
import '../../models/dish.dart';
import '../../state/session.dart';
import '../../utils/format.dart';
import '../../widgets/dish_widgets.dart';
import '../../widgets/state_views.dart';
import 'dish_form_screen.dart';
import 'new_dish_screen.dart';

/// Carta: lista de platos agrupada por categoría (US18: disponibilidad en un toque).
class DishesScreen extends StatefulWidget {
  const DishesScreen({super.key});

  @override
  State<DishesScreen> createState() => _DishesScreenState();
}

class _DishesScreenState extends State<DishesScreen> {
  List<Dish>? _dishes;
  String? _error;
  String? _category; // null = todas
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
    final created = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => const NewDishScreen()));
    if (created == true && mounted) {
      _load();
      SessionScope.read(context).refreshRestaurant();
    }
  }

  Future<void> _openEdit(Dish dish) async {
    final changed = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => DishFormScreen.edit(dish: dish)));
    if (changed == true && mounted) {
      _load();
      SessionScope.read(context).refreshRestaurant();
    }
  }

  @override
  Widget build(BuildContext context) {
    final restaurant = SessionScope.of(context).restaurant;
    return Scaffold(
      appBar: AppBar(
        title: Text(restaurant?.name.isNotEmpty == true ? 'Carta · ${restaurant!.name}' : 'Carta'),
        actions: [IconButton(tooltip: 'Actualizar', onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNew,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('Nuevo plato'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null && _dishes == null) return ErrorView(message: _error!, onRetry: _load);
    final dishes = _dishes;
    if (dishes == null) return const LoadingView();
    if (dishes.isEmpty) {
      return EmptyView(
        icon: Icons.restaurant_menu,
        title: 'Tu carta está vacía',
        message: 'Toma una foto de tu primer plato y la IA te ayudará a completar la ficha.',
        action: FilledButton.icon(
          onPressed: _openNew,
          icon: const Icon(Icons.add_a_photo_outlined),
          label: const Text('Nuevo plato'),
        ),
      );
    }

    final categories = <String>[];
    for (final d in dishes) {
      final c = d.category.isEmpty ? 'Sin categoría' : d.category;
      if (!categories.contains(c)) categories.add(c);
    }
    String catOf(Dish d) => d.category.isEmpty ? 'Sin categoría' : d.category;
    final visibleCats = _category == null ? categories : [_category!];

    final children = <Widget>[
      SizedBox(
        height: 56,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text('Todas (${dishes.length})'),
                selected: _category == null,
                onSelected: (_) => setState(() => _category = null),
              ),
            ),
            for (final c in categories)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(c),
                  selected: _category == c,
                  onSelected: (_) => setState(() => _category = c),
                ),
              ),
          ],
        ),
      ),
    ];
    for (final c in visibleCats) {
      children.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(c, style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            )),
      ));
      for (final d in dishes.where((d) => catOf(d) == c)) {
        children.add(_DishTile(
          dish: d,
          busy: _pending.contains(d.id),
          onTap: () => _openEdit(d),
          onAvailabilityChanged: (v) => _toggleAvailability(d, v),
        ));
      }
    }
    children.add(const SizedBox(height: 96));

    return RefreshIndicator(onRefresh: _load, child: ListView(children: children));
  }
}

class _DishTile extends StatelessWidget {
  const _DishTile({
    required this.dish,
    required this.busy,
    required this.onTap,
    required this.onAvailabilityChanged,
  });

  final Dish dish;
  final bool busy;
  final VoidCallback onTap;
  final ValueChanged<bool> onAvailabilityChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      leading: Opacity(opacity: dish.available ? 1 : 0.5, child: DishPhoto(url: dish.photoUrl)),
      title: Text(dish.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(formatSoles(dish.priceSoles), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            StatusChip(status: dish.status),
            if (!dish.available)
              Text('Agotado por hoy', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.error)),
          ],
        ),
      ),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(
            value: dish.available,
            onChanged: busy ? null : onAvailabilityChanged,
          ),
          Text(dish.available ? 'Disponible' : 'Agotado', style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}
