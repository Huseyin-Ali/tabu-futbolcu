import 'package:hive_flutter/hive_flutter.dart';
import '../constants/app_constants.dart';

class HiveGameStorage {
  static Future<void> kaydetTakimlar(
      String takim1,
      int takim1OyuncuSayisi,
      String takim2,
      int takim2OyuncuSayisi) async {
    if (!Hive.isBoxOpen(AppConstants.gameBox)) {
      await Hive.openBox(AppConstants.gameBox);
    }
    final box = Hive.box(AppConstants.gameBox);
    await box.put('takim1', {
      'takim': takim1,
      'oyuncuSayisi': takim1OyuncuSayisi,
    });
    await box.put('takim2', {
      'takim': takim2,
      'oyuncuSayisi': takim2OyuncuSayisi,
    });
  }

  static Map<String, dynamic>? getirTakim1() {
    if (!Hive.isBoxOpen(AppConstants.gameBox)) {
      return null;
    }
    final box = Hive.box(AppConstants.gameBox);
    return box.get('takim1');
  }

  static Map<String, dynamic>? getirTakim2() {
    if (!Hive.isBoxOpen(AppConstants.gameBox)) {
      return null;
    }
    final box = Hive.box(AppConstants.gameBox);
    return box.get('takim2');
  }

  static Future<void> ekleGecmisOyun(Map<String, dynamic> oyun) async {
    if (!Hive.isBoxOpen(AppConstants.gameBox)) {
      await Hive.openBox(AppConstants.gameBox);
    }
    final box = Hive.box(AppConstants.gameBox);
    List<Map<String, dynamic>> oyunlar =
        List<Map<String, dynamic>>.from(box.get('gecmisOyunlar') ?? []);
    oyunlar.add(oyun);
    await box.put('gecmisOyunlar', oyunlar);
  }

  static List<Map<String, dynamic>> getirGecmisOyunlar() {
    if (!Hive.isBoxOpen(AppConstants.gameBox)) {
      return [];
    }
    final box = Hive.box(AppConstants.gameBox);
    return List<Map<String, dynamic>>.from(box.get('gecmisOyunlar') ?? []);
  }
}
