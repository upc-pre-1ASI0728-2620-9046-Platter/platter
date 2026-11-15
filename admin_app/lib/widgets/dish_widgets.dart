import 'package:flutter/material.dart';

import '../models/dish.dart';
import '../state/session.dart';
import '../theme/platter_theme.dart';
import 'brand.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final DishStatus status;

  @override
  Widget build(BuildContext context) {
    final published = status == DishStatus.published;
    return Pill(
      label: status.label,
      background: published ? PlatterColors.huacatay.withValues(alpha: 0.12) : const Color(0xFFFCE8BF),
      foreground: published ? PlatterColors.huacatayLight : const Color(0xFF5A3D00),
    );
  }
}

/// Fondo de respaldo cuando un plato no tiene foto.
class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({required this.iconSize});

  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark ? const [Color(0xFF3A2C24), Color(0xFF2A201B)] : const [Color(0xFFF7E3D6), Color(0xFFEFD2BF)],
        ),
      ),
      child: Center(
        child: Icon(Icons.restaurant_rounded, size: iconSize, color: PlatterColors.terracotta.withValues(alpha: 0.55)),
      ),
    );
  }
}

String? _resolve(BuildContext context, String? url) =>
    (url == null || url.isEmpty) ? null : SessionScope.read(context).api.client.resolveUrl(url);

/// Foto del plato desde la API (URL absoluta o relativa) con placeholder.
class DishPhoto extends StatelessWidget {
  const DishPhoto({super.key, required this.url, this.size = 56, this.radius = 10});

  final String? url;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final placeholder = SizedBox.square(
      dimension: size,
      child: _PhotoPlaceholder(iconSize: size * 0.42),
    );
    final u = _resolve(context, url);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: u == null
          ? placeholder
          : Image.network(u, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, _, _) => placeholder),
    );
  }
}

/// Foto a sangre para portadas de tarjetas.
class DishCover extends StatelessWidget {
  const DishCover({super.key, required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    const placeholder = _PhotoPlaceholder(iconSize: 48);
    final u = _resolve(context, url);
    if (u == null) return placeholder;
    return Image.network(
      u,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => placeholder,
      frameBuilder: (context, child, frame, sync) => AnimatedOpacity(
        opacity: sync || frame != null ? 1 : 0,
        duration: const Duration(milliseconds: 250),
        child: child,
      ),
    );
  }
}
