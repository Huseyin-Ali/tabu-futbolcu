import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../constants/app_constants.dart';
import '../models/career_game_history.dart';
import '../utils/logger.dart';

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

  // ── Kariyer Avı geçmişi ─────────────────────────────────────────────────

  static Future<void> ekleKariyerOyunu(CareerGameHistory kayit) async {
    if (!Hive.isBoxOpen(AppConstants.gameBox)) {
      await Hive.openBox(AppConstants.gameBox);
    }
    final box = Hive.box(AppConstants.gameBox);
    final List<Map<String, dynamic>> liste = List<Map<String, dynamic>>.from(
      (box.get(AppConstants.kariyerGecmisKey) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map)),
    );
    liste.add(kayit.toMap());
    await box.put(AppConstants.kariyerGecmisKey, liste);

    if (kDebugMode) {
      AppLogger.info(
        '[CareerHistory] Kayıt eklendi — '
        'skor: ${kayit.skor}, zorluk: ${kayit.zorluk}, '
        'toplam kayıt: ${liste.length}',
      );
    }
  }

  static List<CareerGameHistory> getirKariyerOyunlari() {
    if (!Hive.isBoxOpen(AppConstants.gameBox)) {
      return [];
    }
    final box = Hive.box(AppConstants.gameBox);
    final rawList = box.get(AppConstants.kariyerGecmisKey) ?? [];
    final liste = (rawList as List)
        .map((e) => CareerGameHistory.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    liste.sort((a, b) => b.tarih.compareTo(a.tarih));
    return liste;
  }
}
