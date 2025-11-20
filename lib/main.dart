import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'providers/game_provider.dart';
import 'providers/ai_provider.dart';
import 'providers/ai_logging_provider.dart';
import 'multiplayer_v2/providers/multiplayer_client.dart';
import 'services/game_logging_service.dart';
import 'screens/home_screen.dart';
import 'screens/game_screen.dart';
import 'screens/ai_game_setup_screen.dart';
import 'screens/logging_settings_screen.dart';

void main() async {
  // Ensure Flutter is initialized properly to fix debugging context issues
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set preferred orientations for better game experience
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  
  // Set system UI overlay style for proper Arabic interface
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  
  // Initialize AI logging service
  try {
    await GameLoggingService.instance.initialize();
    print('✅ AI Logging Service initialized');
  } catch (e) {
    print('⚠️ AI Logging Service initialization failed: $e');
  }
  
  runApp(const TrixApp());
}

class TrixApp extends StatelessWidget {
  const TrixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GameProvider()),
        ChangeNotifierProvider(create: (_) => AIProvider()),
        ChangeNotifierProvider(create: (_) => AILoggingProvider()),
        ChangeNotifierProvider(create: (_) => MultiplayerClient()),
      ],
      child: MaterialApp(
        title: 'تريكس - لعبة الورق العربية',
        debugShowCheckedModeBanner: false,
        
        // Arabic localization support as per project guidelines
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('ar', 'SA'), // Arabic (Saudi Arabia)
          Locale('ar', 'EG'), // Arabic (Egypt)
          Locale('ar', ''),   // Arabic (generic)
          Locale('en', 'US'), // English fallback
        ],
        locale: const Locale('ar', 'SA'), // Default to Arabic

        // Theme with Arabic font support
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2E7D32),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          
          // Arabic font configuration with proper fonts
          fontFamily: 'Noto Kufi Arabic',
          textTheme: const TextTheme().apply(
            bodyColor: Colors.black87,
            displayColor: Colors.black87,
            fontFamily: 'Noto Kufi Arabic',
          ),
          
          // RTL support as per project guidelines
          visualDensity: VisualDensity.adaptivePlatformDensity,
          
          // Card theme for game cards
          cardTheme: const CardThemeData(
            elevation: 4,
            margin: EdgeInsets.all(4),
          ),
          
          // AppBar theme with Arabic support
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF2E7D32),
            foregroundColor: Colors.white,
            titleTextStyle: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          
          // Button themes with Arabic font
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),

        home: const HomeScreen(),
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case '/game':
              return MaterialPageRoute(
                builder: (context) => const GameScreen(),
                settings: settings, // This ensures arguments are passed
              );
            case '/ai-game-setup':
              return MaterialPageRoute(
                builder: (context) => const AIGameSetupScreen(),
                settings: settings,
              );
            case '/logging_settings':
              return MaterialPageRoute(
                builder: (context) => const LoggingSettingsScreen(),
                settings: settings,
              );
            default:
              return null;
          }
        },
      ),
    );
  }
}
