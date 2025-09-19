import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/welcome_screen.dart';
import 'screens/chatbot_screen.dart';
import 'screens/triage_screen.dart';
import 'screens/results_screen.dart';
import 'screens/clinic_screen.dart';
import 'screens/login_screen.dart';
import 'i18n/app_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/message_model.dart';
import 'screens/settings_screen.dart';
import 'screens/consent_dialog.dart';
import 'services/consent_service.dart';
import 'screens/map_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Hive for offline storage and register adapters
  await Hive.initFlutter();
  Hive.registerAdapter(MessageModelAdapter());
  final saved = await LanguageScope.loadSavedLocale();
  runApp(ProviderScope(child: LanguageScope(initialLocale: saved, child: const HealthAssistantApp())));
}

class HealthAssistantApp extends StatefulWidget {
  const HealthAssistantApp({super.key});

  @override
  State<HealthAssistantApp> createState() => _HealthAssistantAppState();
}

class _HealthAssistantAppState extends State<HealthAssistantApp> {
  bool _checkedConsent = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final consent = ConsentService();
      if (await consent.isFirstRun()) {
        if (!mounted) return;
        final accepted = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const ConsentDialog(),
        );
        // If user canceled dialog, default to no storage/mic/location
        if (accepted != true) {
          await consent.setStoreAllowed(false);
          await consent.setMicAllowed(false);
          await consent.setLocationAllowed(false);
        }
      }
      if (mounted) setState(() => _checkedConsent = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return MaterialApp(
      title: loc.t('app_title'),
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1E88E5),
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF0F4F8),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E88E5),
          foregroundColor: Colors.white,
          centerTitle: false,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E88E5),
            foregroundColor: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(fontSize: 16),
          ),
        ),
      ),
      locale: LanguageScope.of(context),
      supportedLocales: AppLocalizations.supported,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      initialRoute: '/login',
      routes: {
        '/': (context) => const WelcomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/chat': (context) => ChatbotScreen(),
        '/triage': (context) => const TriageScreen(),
        '/results': (context) => const ResultsScreen(),
        '/clinics': (context) => const ClinicScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/map': (context) => const MapScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
