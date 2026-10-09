import 'package:flutter/material.dart';

import '../../models/catalog.dart';

/// Galería horizontal de la biblioteca de modelos 3D (US10).
/// `selectedId == null` significa "modelo por defecto de la categoría".
class ModelPicker extends StatelessWidget {
  const ModelPicker({
    super.key,
    required this.models,
    required this.selectedId,
    required this.onSelected,
    this.category = '',
  });

  final List<Model3D>? models;
  final String? selectedId;
  final String category;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final list = models;
    if (list == null) {
      return const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator());
    }
    final cat = category.toLowerCase();
    final sorted = [...list]..sort((a, b) {
        final am = a.category.toLowerCase() == cat ? 0 : 1;
        final bm = b.category.toLowerCase() == cat ? 0 : 1;
        return am != bm ? am - bm : a.name.compareTo(b.name);
      });
    return SizedBox(
      height: 150,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _ModelCard(
            icon: Icons.auto_mode,
            title: 'Automático',
            subtitle: 'Modelo por defecto de la categoría',
            selected: selectedId == null,
            onTap: () => onSelected(null),
          ),
          for (final m in sorted)
            _ModelCard(
              icon: Icons.view_in_ar,
              title: m.name,
              subtitle: m.dimensions?.centimeters ?? '',
              caption: m.category,
              selected: m.id == selectedId,
              onTap: () => onSelected(m.id),
            ),
        ],
      ),
    );
  }
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.caption,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? caption;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 10, bottom: 4),
      child: SizedBox(
        width: 150,
        child: Card(
          margin: EdgeInsets.zero,
          color: selected ? scheme.primaryContainer : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: selected ? scheme.onPrimaryContainer : scheme.primary),
                      const Spacer(),
                      if (selected) Icon(Icons.check_circle, size: 18, color: scheme.primary),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                  const Spacer(),
                  if (caption != null && caption!.isNotEmpty)
                    Text(caption!, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelSmall),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
