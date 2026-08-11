import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
class SettingsStorage {
  static Future<void> kaydetAyarlar({
    required int zamanLimiti,
    required int pasHakki,
    required int tabuCezasi,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('zamanLimiti', zamanLimiti);
    await prefs.setInt('pasHakki', pasHakki);
    await prefs.setInt('tabuCezasi', tabuCezasi);
  }

  static Future<Map<String, int>> yukleAyarlar() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'zamanLimiti': prefs.getInt('zamanLimiti') ?? 60,
      'pasHakki': (prefs.getInt('pasHakki') ?? 3)
          .clamp(AppConstants.minPasHakki, AppConstants.maxPasHakki),
      'tabuCezasi': (prefs.getInt('tabuCezasi') ?? 2)
          .clamp(AppConstants.minTabuCezasi, AppConstants.maxTabuCezasi),
    };
  }

  /// Ses açık/kapalı tercihi — Tabu ve Kariyer Avı ortak kullanır.
  static Future<bool> getSesAcik() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.keySesAcik) ??
        AppConstants.defaultSesAcik;
  }

  static Future<void> setSesAcik(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keySesAcik, value);
  }
}
