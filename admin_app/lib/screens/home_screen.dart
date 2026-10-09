import 'package:flutter/material.dart';

import 'account/account_screen.dart';
import 'dishes/dishes_screen.dart';
import 'metrics/metrics_screen.dart';
import 'tables/tables_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  // Las pestañas se construyen al visitarlas por primera vez.
  final _visited = <int>{0};

  static const _tabs = <Widget>[
    DishesScreen(),
    TablesScreen(),
    MetricsScreen(),
    AccountScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          for (var i = 0; i < _tabs.length; i++)
            _visited.contains(i) ? _tabs[i] : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() {
          _index = i;
          _visited.add(i);
        }),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.restaurant_menu_outlined),
            selectedIcon: Icon(Icons.restaurant_menu),
            label: 'Carta',
          ),
          NavigationDestination(
            icon: Icon(Icons.table_restaurant_outlined),
            selectedIcon: Icon(Icons.table_restaurant),
            label: 'Mesas',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Métricas',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Cuenta',
          ),
        ],
      ),
    );
  }
}
