import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_env.dart';
import 'features/chart/index.dart';
import 'features/home/index.dart';
import 'features/login/index.dart';
import 'features/patient_info/index.dart';
import 'features/help/index.dart';
import 'features/report/index.dart';
import 'features/sessions/index.dart';
import 'features/vitals/index.dart';
import 'features/agency/index.dart';
import 'features/account/index.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } on FileNotFoundError {
    // Ignore missing .env file when relying on dart-define values.
  }
  SupabaseEnv.ensureConfigured();
  await Supabase.initialize(url: SupabaseEnv.url, anonKey: SupabaseEnv.anonKey);
  final hasSession = Supabase.instance.client.auth.currentSession != null;
  runApp(EMSNotesApp(initialRoute: hasSession ? '/home' : '/login'));
}

class NoTransitionsBuilder extends PageTransitionsBuilder {
  const NoTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}

class EMSNotesApp extends StatelessWidget {
  const EMSNotesApp({super.key, required this.initialRoute});

  final String initialRoute;

  @override
  Widget build(BuildContext context) {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0B3D91),
      brightness: Brightness.light,
    );
    return MaterialApp(
      title: 'EMS Notes',
      theme: ThemeData(
        colorScheme: baseScheme.copyWith(
          primary: const Color(0xFF0B3D91),
          onPrimary: Colors.white,
          primaryContainer: const Color(0xFF123E73),
          secondary: const Color(0xFFE53935),
          onSecondary: Colors.white,
          secondaryContainer: const Color(0xFFFFE5E3),
          onSecondaryContainer: const Color(0xFF6E1110),
          surface: const Color(0xFFF8FAFD),
          onSurface: const Color(0xFF0F1C2E),
          surfaceContainerHighest: const Color(0xFFE1E7F2),
          outline: const Color(0xFFB5C0CF),
          shadow: Colors.black26,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F7FB),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: NoTransitionsBuilder(),
            TargetPlatform.iOS: NoTransitionsBuilder(),
            TargetPlatform.macOS: NoTransitionsBuilder(),
            TargetPlatform.linux: NoTransitionsBuilder(),
            TargetPlatform.windows: NoTransitionsBuilder(),
            TargetPlatform.fuchsia: NoTransitionsBuilder(),
          },
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: Color(0xFF0B3D91),
          foregroundColor: Colors.white,
          elevation: 3,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
            backgroundColor: const Color(0xFF0B3D91),
            foregroundColor: Colors.white,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
      initialRoute: initialRoute,
      routes: {
        '/login': (context) => const LoginPage(),
        '/home': (context) => const HomePage(),
        '/patient-info': (context) => const PatientInfoPage(),
        '/vitals': (context) => const VitalsPage(),
        '/chart': (context) => const ChartPage(),
        '/report': (context) => const ReportPage(),
        '/sessions': (context) => const SessionsPage(),
        '/sessions/shared': (context) =>
            const SessionsPage(showSharedOnly: true),
        '/sessions/new': (context) => const SessionStartPage(),
        '/agency': (context) => const AgencyPage(),
        '/account': (context) => const AccountPage(),
        '/help': (context) => const HelpPage(),
      },
    );
  }
}
