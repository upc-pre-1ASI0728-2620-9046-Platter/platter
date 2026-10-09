import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/auth/login_screen.dart';
import 'screens/home_screen.dart';
import 'state/session.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final session = Session()..load();
  runApp(PlatterAdminApp(session: session));
}

/// Terracota: color cálido, amigable con la comida.
const Color platterSeed = Color(0xFFC0532F);

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: platterSeed, brightness: brightness);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
    cardTheme: const CardThemeData(clipBehavior: Clip.antiAlias),
  );
}

class PlatterAdminApp extends StatefulWidget {
  const PlatterAdminApp({super.key, required this.session});

  final Session session;

  @override
  State<PlatterAdminApp> createState() => _PlatterAdminAppState();
}

class _PlatterAdminAppState extends State<PlatterAdminApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  bool _wasAuthenticated = false;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSessionChanged);
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged() {
    final auth = widget.session.isAuthenticated;
    if (_wasAuthenticated && !auth) {
      // Cierra cualquier pantalla abierta y vuelve al login.
      _navigatorKey.currentState?.popUntil((r) => r.isFirst);
      if (widget.session.expiredFlag) {
        _messengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Tu sesión expiró. Vuelve a iniciar sesión.')),
        );
      }
    }
    _wasAuthenticated = auth;
  }

  @override
  Widget build(BuildContext context) {
    return SessionScope(
      session: widget.session,
      child: MaterialApp(
        title: 'Platter Admin',
        debugShowCheckedModeBanner: false,
        navigatorKey: _navigatorKey,
        scaffoldMessengerKey: _messengerKey,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        locale: const Locale('es', 'PE'),
        supportedLocales: const [Locale('es', 'PE'), Locale('es')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const _AuthGate(),
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    if (!session.isLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return session.isAuthenticated ? const HomeScreen() : const LoginScreen();
  }
}
