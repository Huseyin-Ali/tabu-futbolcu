import 'package:shared_preferences/shared_preferences.dart';

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
      'pasHakki': prefs.getInt('pasHakki') ?? 3,
      'tabuCezasi': prefs.getInt('tabuCezasi') ?? 2,
    };
  }
}
