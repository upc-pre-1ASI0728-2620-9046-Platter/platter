import 'package:flutter/material.dart';

import '../state/session.dart';
import '../theme/platter_theme.dart';
import '../widgets/brand.dart';
import '../widgets/state_views.dart';
import 'account/account_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'dishes/dishes_screen.dart';
import 'metrics/metrics_screen.dart';
import 'tables/tables_screen.dart';

/// Secciones del panel.
enum HomeTab {
  inicio('Inicio', Icons.space_dashboard_outlined, Icons.space_dashboard_rounded),
  carta('Carta', Icons.restaurant_menu_outlined, Icons.restaurant_menu_rounded),
  mesas('Mesas', Icons.qr_code_2_outlined, Icons.qr_code_2_rounded),
  metricas('Métricas', Icons.insights_outlined, Icons.insights_rounded),
  cuenta('Cuenta', Icons.storefront_outlined, Icons.storefront_rounded);

  const HomeTab(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Permite que una pantalla cambie de sección (p. ej. accesos rápidos del Inicio).
class HomeNav extends InheritedWidget {
  const HomeNav({super.key, required this.goTo, required super.child});

  final ValueChanged<HomeTab> goTo;

  static HomeNav? maybeOf(BuildContext context) => context.getInheritedWidgetOfExactType<HomeNav>();

  @override
  bool updateShouldNotify(HomeNav oldWidget) => false;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  HomeTab _tab = HomeTab.inicio;
  // Las secciones se construyen al visitarlas por primera vez.
  final _visited = <HomeTab>{HomeTab.inicio};

  static const _wideBreakpoint = 960.0;

  void _goTo(HomeTab tab) => setState(() {
    _tab = tab;
    _visited.add(tab);
  });

  Widget _page(HomeTab t) => switch (t) {
    HomeTab.inicio => const DashboardScreen(),
    HomeTab.carta => const DishesScreen(),
    HomeTab.mesas => const TablesScreen(),
    HomeTab.metricas => const MetricsScreen(),
    HomeTab.cuenta => const AccountScreen(),
  };

  @override
  Widget build(BuildContext context) {
    final pages = IndexedStack(
      index: _tab.index,
      children: [for (final t in HomeTab.values) _visited.contains(t) ? _page(t) : const SizedBox.shrink()],
    );
    return HomeNav(
      goTo: _goTo,
      child: LayoutBuilder(
        builder: (context, c) {
          if (c.maxWidth >= _wideBreakpoint) {
            return Scaffold(
              body: Row(
                children: [
                  _Sidebar(selected: _tab, onSelect: _goTo),
                  Expanded(child: pages),
                ],
              ),
            );
          }
          return Scaffold(
            body: pages,
            bottomNavigationBar: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
              ),
              child: NavigationBar(
                selectedIndex: _tab.index,
                onDestinationSelected: (i) => _goTo(HomeTab.values[i]),
                destinations: [
                  for (final t in HomeTab.values)
                    NavigationDestination(icon: Icon(t.icon), selectedIcon: Icon(t.selectedIcon), label: t.label),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.selected, required this.onSelect});

  final HomeTab selected;
  final ValueChanged<HomeTab> onSelect;

  Future<void> _logout(BuildContext context) async {
    final ok = await confirmDialog(
      context,
      title: 'Cerrar sesión',
      message: '¿Quieres cerrar tu sesión en este dispositivo?',
      confirmLabel: 'Cerrar sesión',
    );
    if (ok && context.mounted) await SessionScope.read(context).logout();
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final theme = Theme.of(context);
    final restaurant = session.restaurant;
    const cream = PlatterColors.cream;
    return Container(
      width: 272,
      decoration: const BoxDecoration(gradient: PlatterColors.sidebarGradient),
      child: Stack(
        children: [
          const Positioned.fill(child: PlateRings(opacity: 0.05)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: PlatterLogo(size: 34, onDark: true, subtitle: 'PANEL DEL RESTAURANTE'),
                  ),
                  const SizedBox(height: 28),
                  if (restaurant != null)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: PlatterColors.aji,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              restaurant.name.isNotEmpty ? restaurant.name[0].toUpperCase() : 'P',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: PlatterColors.ink,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  restaurant.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: cream,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (restaurant.plan != null)
                                  Text(
                                    'Plan ${restaurant.plan!.name}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: PlatterColors.aji,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                  for (final t in HomeTab.values) _SideItem(tab: t, selected: t == selected, onTap: () => onSelect(t)),
                  const Spacer(),
                  if (session.user != null)
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                      ),
                      child: Row(
                        children: [
                          GradientAvatar(name: session.user!.name, size: 36),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  session.user!.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: cream,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  session.user!.email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(color: cream.withValues(alpha: 0.6)),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Cerrar sesión',
                            onPressed: () => _logout(context),
                            icon: Icon(Icons.logout_rounded, color: cream.withValues(alpha: 0.8), size: 20),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SideItem extends StatelessWidget {
  const _SideItem({required this.tab, required this.selected, required this.onTap});

  final HomeTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const cream = PlatterColors.cream;
    final style = Theme.of(context).textTheme.bodyLarge?.copyWith(
      color: selected ? cream : cream.withValues(alpha: 0.72),
      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? Colors.white.withValues(alpha: 0.11) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: selected ? PlatterColors.ember : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  selected ? tab.selectedIcon : tab.icon,
                  color: selected ? PlatterColors.ember : cream.withValues(alpha: 0.72),
                  size: 22,
                ),
                const SizedBox(width: 14),
                Text(tab.label, style: style),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
