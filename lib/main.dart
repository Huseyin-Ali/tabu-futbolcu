import 'package:flutter/material.dart';
import 'screens/welcome_screen.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/game_history.dart';
import 'models/tabu_futbolcu.dart';
import 'package:firebase_core/firebase_core.dart';
import 'constants/app_constants.dart';
import 'utils/logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // Firebase'i başlat (hata olursa devam et)
    try {
      await Firebase.initializeApp();
      AppLogger.info('Firebase başarıyla başlatıldı');
    } catch (e) {
      AppLogger.warning(
          'Firebase başlatılırken hata oluştu (devam ediliyor)', e.toString());
    }

    await Hive.initFlutter();

    // Adapter'ları kaydet
    Hive.registerAdapter(GameHistoryAdapter());
    Hive.registerAdapter(TabuFutbolcuAdapter());

    // Kutuları aç (varsa aç, yoksa oluştur)
    try {
      await Hive.openBox<GameHistory>(AppConstants.gameHistoryBox);
      AppLogger.info('${AppConstants.gameHistoryBox} kutusu açıldı');
    } catch (e) {
      AppLogger.error(
          '${AppConstants.gameHistoryBox} kutusu açılırken hata', e);
      // Hata durumunda tekrar deneyelim
      try {
        await Hive.openBox<GameHistory>(AppConstants.gameHistoryBox);
      } catch (e2) {
        AppLogger.error(
            '${AppConstants.gameHistoryBox} kutusu ikinci denemede de açılamadı',
            e2);
      }
    }

    try {
      await Hive.openBox(AppConstants.gameBox);
      AppLogger.info('${AppConstants.gameBox} kutusu açıldı');
    } catch (e) {
      AppLogger.error('${AppConstants.gameBox} kutusu açılırken hata', e);
      try {
        await Hive.openBox(AppConstants.gameBox);
      } catch (e2) {
        AppLogger.error(
            '${AppConstants.gameBox} kutusu ikinci denemede de açılamadı', e2);
      }
    }

    try {
      await Hive.openBox<TabuFutbolcu>(AppConstants.futbolcularBox);
      AppLogger.info('${AppConstants.futbolcularBox} kutusu açıldı');
    } catch (e) {
      AppLogger.error(
          '${AppConstants.futbolcularBox} kutusu açılırken hata', e);
      try {
        await Hive.openBox<TabuFutbolcu>(AppConstants.futbolcularBox);
      } catch (e2) {
        AppLogger.error(
            '${AppConstants.futbolcularBox} kutusu ikinci denemede de açılamadı',
            e2);
      }
    }

    runApp(const MyApp());
  } catch (e, stackTrace) {
    AppLogger.error('Uygulama başlatılırken kritik hata oluştu', e, stackTrace);
    // Hata olsa bile uygulamayı başlat
    runApp(const MyApp());
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
        colorScheme: ColorScheme.light(
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
