import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/game_history.dart';
import 'models/tabu_futbolcu.dart';
import 'constants/app_constants.dart';
import 'utils/logger.dart';
import 'screens/welcome_screen.dart';
import 'services/analytics_service.dart';
import 'services/firebase_bootstrap_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── 1. Firebase bootstrap ─────────────────────────────────────────────
  final bootstrap = await FirebaseBootstrapService.initialize();
  AnalyticsService.configure(analyticsAvailable: bootstrap.analyticsAvailable);

  if (kDebugMode && !bootstrap.firebaseInitialized) {
    AppLogger.warning(
      '[Bootstrap] Firebase başlatılamadı — Analytics pasif.\n'
      'Hata: ${bootstrap.firebaseErrorMessage}',
    );
  }

  // ── 2. Hive — yerel cache katmanı ─────────────────────────────────────
  // Cache-first veri mimarisi bu adıma bağlıdır; Firebase'den bağımsızdır.
  try {
    await Hive.initFlutter();
    Hive.registerAdapter(GameHistoryAdapter());
    Hive.registerAdapter(TabuFutbolcuAdapter());

    await _openHiveBox<GameHistory>(AppConstants.gameHistoryBox);
    await _openHiveBox<dynamic>(AppConstants.gameBox);
    await _openHiveBox<TabuFutbolcu>(AppConstants.futbolcularBox);
    await _openHiveBox<dynamic>(AppConstants.kariyerFutbolcularCacheBox);
  } catch (e, stackTrace) {
    AppLogger.error('[Hive] Başlatma sırasında kritik hata', e, stackTrace);
  }

  runApp(MyApp(bootstrap: bootstrap));
}

/// Verilen Hive kutusunu açar; hata olursa loglar ve devam eder.
Future<void> _openHiveBox<T>(String name) async {
  try {
    await Hive.openBox<T>(name);
    AppLogger.info('[Hive] Kutu açıldı: $name');
  } catch (e) {
    AppLogger.error('[Hive] Kutu açılamadı: $name', e);
  }
}

class MyApp extends StatelessWidget {
  final AppBootstrapResult bootstrap;

  const MyApp({super.key, required this.bootstrap});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Futbol Tabu Oyunu',
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardColor: Colors.black,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.black),
          bodyMedium: TextStyle(color: Colors.black),
        ),
        colorScheme: const ColorScheme.light(
          primary: Colors.black,
          onPrimary: Colors.white,
          secondary: Colors.white,
        ),
        useMaterial3: true,
      ),
      home: const WelcomeScreen(),
    );
  }
}
