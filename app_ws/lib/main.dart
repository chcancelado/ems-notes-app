import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_env.dart';
import 'features/chart/index.dart';
import 'features/home/index.dart';
import 'features/login/index.dart';
import 'features/patient_info/index.dart';
import 'features/report/index.dart';
import 'features/sessions/index.dart';
import 'features/vitals/index.dart';

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

class EMSNotesApp extends StatelessWidget {
  const EMSNotesApp({super.key, required this.initialRoute});

  final String initialRoute;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EMS Notes',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          primary: Colors.blue,
          secondary: Colors.blueAccent,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
      },
    );
  }
}
