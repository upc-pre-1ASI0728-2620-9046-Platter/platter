import 'package:flutter/material.dart';

import '../../theme/platter_theme.dart';
import '../../widgets/brand.dart';

/// Diseño compartido de login y registro: panel de marca a la izquierda (pantallas anchas)
/// o encabezado compacto (celular), y el formulario en una tarjeta.
class AuthLayout extends StatelessWidget {
  const AuthLayout({super.key, required this.title, required this.subtitle, required this.child, this.leading});

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 900;
          final form = Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: wide ? 48 : 20, vertical: 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (leading != null) Align(alignment: Alignment.centerLeft, child: leading!),
                    if (!wide) ...[const Center(child: PlatterLogo(size: 40)), const SizedBox(height: 28)],
                    Text(title, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 28),
                    child,
                  ],
                ),
              ),
            ),
          );
          if (!wide) return SafeArea(child: form);
          return Row(
            children: [
              const Expanded(flex: 5, child: _BrandPanel()),
              Expanded(flex: 4, child: SafeArea(child: form)),
            ],
          );
        },
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const cream = PlatterColors.cream;
    Widget feature(IconData icon, String title, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: PlatterColors.aji, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(color: cream, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: cream.withValues(alpha: 0.72))),
              ],
            ),
          ),
        ],
      ),
    );
    return Container(
      decoration: const BoxDecoration(gradient: PlatterColors.sidebarGradient),
      child: Stack(
        children: [
          const Positioned.fill(child: PlateRings(opacity: 0.07)),
          Positioned(
            right: -80,
            bottom: -80,
            child: Opacity(opacity: 0.9, child: PlatterMark(size: 320, onDark: true)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(56, 48, 56, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PlatterLogo(size: 38, onDark: true),
                const Spacer(),
                Text(
                  'Tu carta,\nsobre la mesa de\ntus clientes.',
                  style: theme.textTheme.displaySmall?.copyWith(color: cream, fontWeight: FontWeight.w600, height: 1.1),
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Text(
                    'Publica tus platos con una foto y deja que tus comensales los vean en 3D, a tamaño real, '
                    'escaneando el QR de su mesa.',
                    style: theme.textTheme.bodyLarge?.copyWith(color: cream.withValues(alpha: 0.8)),
                  ),
                ),
                const SizedBox(height: 36),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    children: [
                      feature(
                        Icons.auto_awesome_rounded,
                        'Fichas con IA',
                        'Ingredientes, alérgenos y descripción desde una foto.',
                      ),
                      feature(
                        Icons.view_in_ar_rounded,
                        'Realidad Aumentada',
                        'Sin apps ni registro para tus clientes.',
                      ),
                      feature(Icons.insights_rounded, 'Métricas reales', 'Descubre qué platos miran y piden más.'),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  'Hecho en Lima para restaurantes del Perú',
                  style: theme.textTheme.bodySmall?.copyWith(color: cream.withValues(alpha: 0.5)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
