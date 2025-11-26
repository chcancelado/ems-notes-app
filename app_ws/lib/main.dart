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
    return MaterialApp(
      title: 'EMS Notes',
      theme: ThemeData(
        colorScheme: const ColorScheme(
          brightness: Brightness.light,
          primary: Color(0xFF0B3D91), // deep navy
          onPrimary: Colors.white,
          primaryContainer: Color(0xFF123E73),
          onPrimaryContainer: Colors.white,
          secondary: Color(0xFFE53935), // bold red accent
          onSecondary: Colors.white,
          secondaryContainer: Color(0xFFFFE5E3),
          onSecondaryContainer: Color(0xFF6E1110),
          tertiary: Color(0xFF1B4965),
          onTertiary: Colors.white,
          error: Color(0xFFB00020),
          onError: Colors.white,
          background: Color(0xFFF5F7FB), // light cool backdrop
          onBackground: Color(0xFF0F1C2E),
          surface: Color(0xFFF8FAFD),
          onSurface: Color(0xFF0F1C2E),
          surfaceVariant: Color(0xFFE1E7F2),
          onSurfaceVariant: Color(0xFF2D3A4F),
          outline: Color(0xFFB5C0CF),
          shadow: Colors.black26,
          inverseSurface: Color(0xFF1F2A3A),
          onInverseSurface: Color(0xFFE6EBF5),
          outlineVariant: Color(0xFFCED7E6),
          scrim: Colors.black54,
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
