import 'package:flutter/material.dart';

import '../models/dish.dart';
import '../state/session.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final DishStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final published = status == DishStatus.published;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: published ? scheme.tertiaryContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: published ? scheme.onTertiaryContainer : scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

/// Foto del plato desde la API (URL absoluta o relativa) con placeholder.
class DishPhoto extends StatelessWidget {
  const DishPhoto({super.key, required this.url, this.size = 56, this.radius = 10});

  final String? url;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = Container(
      width: size,
      height: size,
      color: scheme.surfaceContainerHighest,
      child: Icon(Icons.restaurant, color: scheme.onSurfaceVariant, size: size * 0.45),
    );
    final u = url;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: (u == null || u.isEmpty)
          ? placeholder
          : Image.network(
              SessionScope.read(context).api.client.resolveUrl(u),
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => placeholder,
            ),
    );
  }
}
