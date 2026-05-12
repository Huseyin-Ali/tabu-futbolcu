import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/kariyer_futbolcu.dart';
import '../utils/logger.dart';

class CareerModeService {
  /// Firestore'dan kariyer_yolu dolu futbolcuları çeker.
  /// Önce sunucudan taze veri alır, başarısız olursa yerel cache'e düşer.
  /// Veri bulunamazsa boş liste döner — demo fallback yoktur.
  static Future<List<KariyerFutbolcu>> getKariyerFutbolculari({
    String zorluk = 'karışık',
  }) async {
    QuerySnapshot<Map<String, dynamic>>? snap;

    try {
      snap = await FirebaseFirestore.instance
          .collection('tumAktifFutbolcular')
          .get(const GetOptions(source: Source.server));
      AppLogger.info('[CareerMode] Sunucudan ${snap.docs.length} döküman çekildi');
    } catch (serverErr) {
      AppLogger.warning('[CareerMode] Sunucuya ulaşılamadı, cache deneniyor: $serverErr');
      try {
        snap = await FirebaseFirestore.instance
            .collection('tumAktifFutbolcular')
            .get(const GetOptions(source: Source.cache));
        AppLogger.info('[CareerMode] Cache\'den ${snap.docs.length} döküman çekildi');
      } catch (cacheErr) {
        AppLogger.error('[CareerMode] Cache de başarısız', cacheErr);
      }
    }

    if (snap == null) {
      AppLogger.warning('[CareerMode] Veri kaynağına ulaşılamadı, boş liste dönülüyor');
      return [];
    }

    final tumListe = snap.docs
        .map((d) => KariyerFutbolcu.fromDoc(d))
        .where((f) => f.isim.isNotEmpty && f.kariyerYolu.isNotEmpty)
        .toList();

    AppLogger.info(
        '[CareerMode] ${tumListe.length} kariyer futbolcu hazır (zorluk: $zorluk)');

    if (zorluk == 'karışık') return tumListe;
    return tumListe.where((f) => f.zorluk == zorluk).toList();
  }

  /// Normalizes a player name for fuzzy comparison:
  /// - lowercases
  /// - replaces Turkish characters (ç→c, ğ→g, ı→i, ö→o, ş→s, ü→u)
  /// - replaces accented Latin characters (á,à,ä,â→a; é,è,ë,ê→e; etc.)
  /// - collapses extra whitespace
  static String normalizePlayerName(String text) {
    return text
        .toLowerCase()
        // Turkish characters first
        .replaceAll('ı', 'i')
        .replaceAll('i̇', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ş', 's')
        .replaceAll('ç', 'c')
        .replaceAll('ö', 'o')
        .replaceAll('ü', 'u')
        // Accented Latin vowels
        .replaceAll(RegExp(r'[áàäâã]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòôõ]'), 'o')
        .replaceAll(RegExp(r'[úùû]'), 'u')
        // Other accented characters
        .replaceAll('ñ', 'n')
        .replaceAll('ł', 'l')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Returns 'dogru', 'yakin', or 'yanlis' based on how close
  /// the user's guess is to the correct answer.
  ///
  /// Rules:
  /// - Input shorter than 4 characters → always 'yanlis'
  /// - Normalized exact match → 'dogru'
  /// - Single word (≥5 chars) exactly matching any word in the answer → 'dogru'
  /// - Levenshtein similarity ≥ 0.82 (full name or any single word) → 'dogru'
  /// - Levenshtein similarity ≥ 0.60 (full name or any single word) → 'yakin'
  /// - Otherwise → 'yanlis'
  static String checkGuess(String guess, String answer) {
    final normGuess = normalizePlayerName(guess);
    final normAnswer = normalizePlayerName(answer);

    if (normGuess.length < 4) return 'yanlis';
    if (normGuess == normAnswer) return 'dogru';

    final answerWords = normAnswer.split(' ');

    // Single-word match: accepts well-known surnames / mono-name players
    if (normGuess.length >= 5) {
      for (final word in answerWords) {
        if (word == normGuess) return 'dogru';
      }
    }

    // Full-name fuzzy similarity
    final fullScore = _similarityScore(normGuess, normAnswer);
    if (fullScore >= 0.82) return 'dogru';

    // Word-by-word fuzzy similarity
    for (final word in answerWords) {
      if (_similarityScore(normGuess, word) >= 0.82) return 'dogru';
    }

    // Close but not correct
    if (fullScore >= 0.60) return 'yakin';
    for (final word in answerWords) {
      if (_similarityScore(normGuess, word) >= 0.60) return 'yakin';
    }

    return 'yanlis';
  }

  /// Legacy wrapper kept for API compatibility — delegates to [checkGuess].
  static bool isCorrectGuess(String guess, String answer) {
    return checkGuess(guess, answer) == 'dogru';
  }

  // ── Şık üretimi ──────────────────────────────────────────────────────────

  /// Doğru oyuncu için 4 şık üretir: 1 doğru + 3 yanlış.
  ///
  /// Yanlış şık seçim önceliği:
  ///   Aşama 1 → aynı zorluk + aynı son takım
  ///   Aşama 2 → aynı son takım, herhangi zorluk
  ///   Aşama 3 → aynı zorluk, herhangi son takım
  ///   Aşama 4 → tüm havuzdan random
  ///
  /// Döndürülen liste her çağrıda farklı sırada karıştırılmıştır.
  static List<String> generateChoices({
    required KariyerFutbolcu dogru,
    required List<KariyerFutbolcu> tumListe,
  }) {
    final rng = Random();

    String sonTakimNorm(KariyerFutbolcu f) =>
        f.kariyerYolu.isNotEmpty ? normalizePlayerName(f.kariyerYolu.last) : '';

    final dogruSonTakim = sonTakimNorm(dogru);
    final dogruZorluk = dogru.zorluk;

    // Adaylar: doğru oyuncu ve boş isimli oyuncular çıkarıldı
    final adaylar = tumListe
        .where((f) => f.id != dogru.id && f.isim.trim().isNotEmpty)
        .toList();

    final secilen = <String>[];
    final secilenIsimler = <String>{dogru.isim};

    void ekle(List<KariyerFutbolcu> havuz, String asama) {
      final musait = havuz
          .where((f) => !secilenIsimler.contains(f.isim))
          .toList()
        ..shuffle(rng);
      for (final f in musait) {
        if (secilen.length >= 3) break;
        secilen.add(f.isim);
        secilenIsimler.add(f.isim);
        if (kDebugMode) {
          AppLogger.info(
              '[CareerMode][ŞIK][$asama] ${f.isim} | '
              'son: ${f.kariyerYolu.isNotEmpty ? f.kariyerYolu.last : "-"} | '
              'zorluk: ${f.zorluk}');
        }
      }
    }

    if (kDebugMode) {
      AppLogger.info(
          '[CareerMode][ŞIK] ── Yeni kart ──────────────────────────\n'
          '  Doğru oyuncu : ${dogru.isim}\n'
          '  Zorluk       : $dogruZorluk\n'
          '  Son takım    : ${dogru.kariyerYolu.isNotEmpty ? dogru.kariyerYolu.last : "-"}');
    }

    // Aşama 1: aynı zorluk + aynı son takım
    ekle(
      adaylar
          .where((f) =>
              f.zorluk == dogruZorluk && sonTakimNorm(f) == dogruSonTakim)
          .toList(),
      'Aşama1(zorluk+takım)',
    );

    // Aşama 2: aynı son takım, herhangi zorluk
    if (secilen.length < 3) {
      ekle(
        adaylar.where((f) => sonTakimNorm(f) == dogruSonTakim).toList(),
        'Aşama2(sadece_takım)',
      );
    }

    // Aşama 3: aynı zorluk, herhangi takım
    if (secilen.length < 3) {
      ekle(
        adaylar.where((f) => f.zorluk == dogruZorluk).toList(),
        'Aşama3(sadece_zorluk)',
      );
    }

    // Aşama 4: tüm havuzdan random
    if (secilen.length < 3) {
      ekle(adaylar, 'Aşama4(random)');
    }

    final sonuc = [dogru.isim, ...secilen]..shuffle(rng);

    if (kDebugMode) {
      AppLogger.info('[CareerMode][ŞIK] Karıştırılmış şıklar: $sonuc');
    }

    return sonuc;
  }

  /// Normalized Levenshtein similarity: 1.0 = identical, 0.0 = completely different.
  static double _similarityScore(String a, String b) {
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;
    final distance = _levenshtein(a, b);
    return 1.0 - distance / max(a.length, b.length);
  }

  static int _levenshtein(String a, String b) {
    final m = a.length;
    final n = b.length;
    final dp = List.generate(m + 1, (_) => List.filled(n + 1, 0));
    for (int i = 0; i <= m; i++) dp[i][0] = i;
    for (int j = 0; j <= n; j++) dp[0][j] = j;
    for (int i = 1; i <= m; i++) {
      for (int j = 1; j <= n; j++) {
        if (a[i - 1] == b[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1];
        } else {
          dp[i][j] =
              1 + [dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1]].reduce(min);
        }
      }
    }
    return dp[m][n];
  }

}
