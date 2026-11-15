import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/platter_theme.dart';

/// Isotipo de Platter: un plato visto desde arriba (tres círculos concéntricos).
class PlatterMark extends StatelessWidget {
  const PlatterMark({super.key, this.size = 32, this.onDark = false});

  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _MarkPainter(onDark: onDark),
  );
}

class _MarkPainter extends CustomPainter {
  _MarkPainter({required this.onDark});

  final bool onDark;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.drawCircle(c, r * 0.94, Paint()..color = onDark ? PlatterColors.ember : PlatterColors.terracotta);
    canvas.drawCircle(c, r * 0.6, Paint()..color = PlatterColors.cream);
    canvas.drawCircle(c, r * 0.34, Paint()..color = onDark ? PlatterColors.aji : PlatterColors.huacatay);
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.onDark != onDark;
}

/// Logotipo completo (isotipo + nombre).
class PlatterLogo extends StatelessWidget {
  const PlatterLogo({super.key, this.size = 32, this.onDark = false, this.subtitle});

  final double size;
  final bool onDark;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = onDark ? PlatterColors.cream : theme.colorScheme.onSurface;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PlatterMark(size: size, onDark: onDark),
        SizedBox(width: size * 0.34),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Platter',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontSize: size * 0.82,
                height: 1,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  subtitle!,
                  style: theme.textTheme.labelSmall?.copyWith(color: color.withValues(alpha: 0.7), letterSpacing: 0.6),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Anillos decorativos (platos) para héroes y paneles de marca.
class PlateRings extends StatelessWidget {
  const PlateRings({super.key, this.color = Colors.white, this.opacity = 0.12});

  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(
      painter: _RingsPainter(color.withValues(alpha: opacity)),
      size: Size.infinite,
    ),
  );
}

class _RingsPainter extends CustomPainter {
  _RingsPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke;
    final fill = Paint()..color = color;
    final big = Offset(size.width * 0.92, size.height * 0.2);
    final r = math.max(size.width, size.height) * 0.42;
    for (var i = 0; i < 4; i++) {
      stroke.strokeWidth = 2 + i * 0.5;
      canvas.drawCircle(big, r * (0.4 + i * 0.22), stroke);
    }
    canvas.drawCircle(big, r * 0.22, fill);
    canvas.drawCircle(Offset(size.width * 0.08, size.height * 1.02), r * 0.5, stroke..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(_RingsPainter old) => old.color != color;
}

/// Encabezado de página con título serif, bajada y acciones.
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.subtitle, this.actions = const [], this.padding});

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600)),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// Tarjeta de indicador con ícono en pastilla de color.
class KpiTile extends StatelessWidget {
  const KpiTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.tone,
    this.caption,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color tone;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: tone.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: tone, size: 22),
            ),
            const SizedBox(height: 16),
            Text(value, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700, height: 1.05)),
            const SizedBox(height: 4),
            Text(label, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            if (caption != null) ...[
              const SizedBox(height: 2),
              Text(caption!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Grilla adaptable de indicadores (2 columnas en celular, 4 en pantallas anchas).
class KpiGrid extends StatelessWidget {
  const KpiGrid({super.key, required this.children, this.spacing = 14});

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final cols = c.maxWidth >= 760 ? 4 : 2;
      final w = (c.maxWidth - spacing * (cols - 1)) / cols;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [for (final child in children) SizedBox(width: w, child: child)],
      );
    },
  );
}

/// Pastilla de estado.
class Pill extends StatelessWidget {
  const Pill({super.key, required this.label, required this.background, required this.foreground, this.icon});

  final String label;
  final Color background;
  final Color foreground;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(99)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 14, color: foreground), const SizedBox(width: 4)],
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: foreground, fontWeight: FontWeight.w700, letterSpacing: 0.2),
        ),
      ],
    ),
  );
}

/// Avatar con iniciales sobre el degradado de marca.
class GradientAvatar extends StatelessWidget {
  const GradientAvatar({super.key, required this.name, this.size = 44});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final initials = parts.isEmpty ? '?' : parts.take(2).map((p) => p[0].toUpperCase()).join();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(gradient: PlatterColors.brandGradient, shape: BoxShape.circle),
      child: Text(
        initials,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: size * 0.38),
      ),
    );
  }
}

/// Título de sección dentro de una tarjeta o página.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
        ?trailing,
      ],
    ),
  );
}

/// Barra horizontal de progreso con degradado de marca.
class GradientBar extends StatelessWidget {
  const GradientBar({super.key, required this.fraction, this.height = 8, this.colors});

  final double fraction;
  final double height;
  final List<Color>? colors;

  @override
  Widget build(BuildContext context) {
    final track = Theme.of(context).colorScheme.surfaceContainerHighest;
    return LayoutBuilder(
      builder: (context, c) => Stack(
        children: [
          Container(
            height: height,
            width: c.maxWidth,
            decoration: BoxDecoration(color: track, borderRadius: BorderRadius.circular(height)),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            height: height,
            width: c.maxWidth * fraction.clamp(0.0, 1.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors ?? const [PlatterColors.ember, PlatterColors.terracotta]),
              borderRadius: BorderRadius.circular(height),
            ),
          ),
        ],
      ),
    );
  }
}

/// Anillo de porcentaje (p. ej. tasa de uso de AR).
class RingGauge extends StatelessWidget {
  const RingGauge({super.key, required this.fraction, this.size = 120, this.stroke = 12, required this.center});

  final double fraction;
  final double size;
  final double stroke;
  final Widget center;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: fraction.clamp(0, 1)),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        builder: (context, v, child) => CustomPaint(
          painter: _RingPainter(v, stroke, scheme.surfaceContainerHighest),
          child: Center(child: child),
        ),
        child: center,
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.stroke, this.track);

  final double value;
  final double stroke;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset(stroke / 2, stroke / 2) & Size(size.width - stroke, size.height - stroke);
    final base = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(rect, 0, math.pi * 2, false, base);
    final arc = Paint()
      ..shader = const SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: math.pi * 1.5,
        colors: [PlatterColors.aji, PlatterColors.ember, PlatterColors.terracotta],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * value, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value || old.track != track;
}
