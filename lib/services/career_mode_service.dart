import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../constants/app_constants.dart';
import '../models/kariyer_futbolcu.dart';
import '../utils/logger.dart';

class CareerModeService {
  static const _aktifKoleksiyon = 'tumAktifFutbolcular';
  static const _emekliKoleksiyon = 'tumEmekliFutbolcular';
  static const _configCollection = 'game_configs';
  static const _matchConfigDocumentId = 'default_match_config';
  static const _playersVersionField = 'career_players_meta';
  static const _cacheKeyAktif = 'aktif';
  static const _cacheKeyEmekli = 'emekli';
  static const _cacheKeyMetaVersion = 'meta_version';

  /// Firestore'dan kariyer_yolu dolu futbolcuları çeker.
  /// [koleksiyonTipi]: 'aktif', 'veteran' veya 'karışık'
  /// Önce Hive cache kontrol edilir; veri varsa oyun cache ile başlar,
  /// Firestore güncellemesi arka planda yapılır.
  static Future<List<KariyerFutbolcu>> getKariyerFutbolculari({
    String zorluk = 'karışık',
    String koleksiyonTipi = 'karışık',
  }) async {
    final secilenKoleksiyon = koleksiyonTipi.toLowerCase().trim();
    final box = await _openCacheBox();
    final cachedAktif = _readCachedList(box, _cacheKeyAktif);
    final cachedEmekli = _readCachedList(box, _cacheKeyEmekli);

    if (_isCacheReady(secilenKoleksiyon, cachedAktif, cachedEmekli)) {
      final tumListe = _mergeByKoleksiyon(
        cachedAktif,
        cachedEmekli,
        secilenKoleksiyon,
      );

      AppLogger.info('[CareerMode] Cache kullanıldı');
      AppLogger.info(
        '[CareerMode] ${tumListe.length} kariyer futbolcu hazır '
        '(kaynak: cache, koleksiyon: $secilenKoleksiyon, '
        'aktif: ${cachedAktif.length}, emekli: ${cachedEmekli.length}, '
        'zorluk: $zorluk)',
      );

      _refreshCacheInBackground();
      return _applyZorlukFilter(tumListe, zorluk);
    }

    final fetched = await _fetchFromFirestore(secilenKoleksiyon);
    await _writeCacheFromFetch(box, fetched);

    final remoteVersion = await _fetchRemotePlayersVersion();
    if (remoteVersion != null) {
      await _writeLocalPlayersVersion(box, remoteVersion);
    }

    final tumListe = _mergeByKoleksiyon(
      fetched.aktif,
      fetched.emekli,
      secilenKoleksiyon,
    );

    if (tumListe.isEmpty) {
      AppLogger.warning('[CareerMode] Veri kaynağına ulaşılamadı, boş liste dönülüyor');
      return [];
    }

    AppLogger.info(
      '[CareerMode] ${tumListe.length} kariyer futbolcu hazır '
      '(kaynak: Firestore, koleksiyon: $secilenKoleksiyon, '
      'aktif: ${fetched.aktif.length}, emekli: ${fetched.emekli.length}, '
      'zorluk: $zorluk)',
    );

    return _applyZorlukFilter(tumListe, zorluk);
  }

  static Future<Box> _openCacheBox() async {
    if (!Hive.isBoxOpen(AppConstants.kariyerFutbolcularCacheBox)) {
      await Hive.openBox(AppConstants.kariyerFutbolcularCacheBox);
    }
    return Hive.box(AppConstants.kariyerFutbolcularCacheBox);
  }

  static List<KariyerFutbolcu> _readCachedList(Box box, String key) {
    final raw = box.get(key);
    if (raw is! List) return [];

    return raw
        .whereType<Map>()
        .map((item) => KariyerFutbolcu.fromMap(Map<String, dynamic>.from(item)))
        .where((f) => f.isim.isNotEmpty && f.kariyerYolu.isNotEmpty)
        .toList();
  }

  static Future<void> _writeCachedList(
    Box box,
    String key,
    List<KariyerFutbolcu> futbolcular,
  ) async {
    await box.put(key, futbolcular.map((f) => f.toMap()).toList());
  }

  static bool _isCacheReady(
    String koleksiyonTipi,
    List<KariyerFutbolcu> aktif,
    List<KariyerFutbolcu> emekli,
  ) {
    switch (koleksiyonTipi) {
      case 'aktif':
        return aktif.isNotEmpty;
      case 'veteran':
        return emekli.isNotEmpty;
      case 'karışık':
        return aktif.isNotEmpty && emekli.isNotEmpty;
      default:
        return aktif.isNotEmpty && emekli.isNotEmpty;
    }
  }

  static List<KariyerFutbolcu> _mergeByKoleksiyon(
    List<KariyerFutbolcu> aktif,
    List<KariyerFutbolcu> emekli,
    String koleksiyonTipi,
  ) {
    switch (koleksiyonTipi) {
      case 'aktif':
        return List<KariyerFutbolcu>.from(aktif);
      case 'veteran':
        return List<KariyerFutbolcu>.from(emekli);
      default:
        return [...aktif, ...emekli];
    }
  }

  static List<KariyerFutbolcu> _applyZorlukFilter(
    List<KariyerFutbolcu> liste,
    String zorluk,
  ) {
    if (zorluk == 'karışık') return liste;
    return liste.where((f) => f.zorluk == zorluk).toList();
  }

  static Future<void> _writeCacheFromFetch(
    Box box,
    ({List<KariyerFutbolcu> aktif, List<KariyerFutbolcu> emekli}) fetched,
  ) async {
    if (fetched.aktif.isNotEmpty) {
      await _writeCachedList(box, _cacheKeyAktif, fetched.aktif);
    }
    if (fetched.emekli.isNotEmpty) {
      await _writeCachedList(box, _cacheKeyEmekli, fetched.emekli);
    }
  }

  static int? _readLocalPlayersVersion(Box box) {
    final raw = box.get(_cacheKeyMetaVersion);
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '');
  }

  static Future<void> _writeLocalPlayersVersion(Box box, int version) async {
    await box.put(_cacheKeyMetaVersion, version);
  }

  /// Firestore'daki `game_configs/default_match_config.career_players_meta` alanını okur.
  /// Futbolcu verisi güncellendiğinde bu değer artırılmalıdır.
  static Future<int?> _fetchRemotePlayersVersion() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection(_configCollection)
          .doc(_matchConfigDocumentId)
          .get(const GetOptions(source: Source.server));

      if (!doc.exists || doc.data() == null) return null;

      final rawVersion = doc.data()![_playersVersionField];
      if (rawVersion is num) return rawVersion.toInt();
      return int.tryParse(rawVersion?.toString() ?? '');
    } catch (e, stackTrace) {
      AppLogger.error(
        '[CareerMode] default_match_config.$_playersVersionField okunamadı',
        e,
        stackTrace,
      );
      return null;
    }
  }

  static void _refreshCacheInBackground() {
    AppLogger.info('[CareerMode] Firestore background refresh başladı');
    unawaited(
      _runBackgroundRefresh().catchError((Object e, StackTrace stackTrace) {
        AppLogger.error(
          '[CareerMode] Firestore background refresh başarısız',
          e,
          stackTrace,
        );
      }),
    );
  }

  static Future<void> _runBackgroundRefresh() async {
    final remoteVersion = await _fetchRemotePlayersVersion();
    if (remoteVersion == null) {
      AppLogger.info(
        '[CareerMode] Firestore background refresh atlandı '
        '(default_match_config.$_playersVersionField bulunamadı)',
      );
      return;
    }

    final box = await _openCacheBox();
    final localVersion = _readLocalPlayersVersion(box);

    if (localVersion == remoteVersion) {
      AppLogger.info(
        '[CareerMode] Firestore background refresh atlandı '
        '(veri güncel, version: $remoteVersion)',
      );
      return;
    }

    if (localVersion == null) {
      await _writeLocalPlayersVersion(box, remoteVersion);
      AppLogger.info(
        '[CareerMode] Firestore background refresh atlandı '
        '(veri güncel, version eşitlendi: $remoteVersion)',
      );
      return;
    }

    AppLogger.info(
      '[CareerMode] Firestore veri güncellemesi algılandı '
      '(local: $localVersion, remote: $remoteVersion)',
    );

    final fetched = await _fetchBothCollectionsFromFirestore();
    if (fetched.aktif.isEmpty && fetched.emekli.isEmpty) {
      AppLogger.warning(
        '[CareerMode] Firestore background refresh veri döndürmedi',
      );
      return;
    }

    await _writeCacheFromFetch(box, fetched);
    await _writeLocalPlayersVersion(box, remoteVersion);
    AppLogger.info('[CareerMode] Firestore cache güncellendi');
  }

  static Future<({List<KariyerFutbolcu> aktif, List<KariyerFutbolcu> emekli})>
      _fetchFromFirestore(String koleksiyonTipi) async {
    QuerySnapshot<Map<String, dynamic>>? aktifSnap;
    QuerySnapshot<Map<String, dynamic>>? emekliSnap;

    switch (koleksiyonTipi) {
      case 'aktif':
        aktifSnap = await _getCollectionSnapshot(_aktifKoleksiyon);
        break;
      case 'veteran':
        emekliSnap = await _getCollectionSnapshot(_emekliKoleksiyon);
        break;
      case 'karışık':
        final results = await Future.wait([
          _getCollectionSnapshot(_aktifKoleksiyon),
          _getCollectionSnapshot(_emekliKoleksiyon),
        ]);
        aktifSnap = results[0];
        emekliSnap = results[1];
        break;
      default:
        AppLogger.warning(
          '[CareerMode] Bilinmeyen koleksiyon tipi: $koleksiyonTipi, karışık kullanılıyor',
        );
        final results = await Future.wait([
          _getCollectionSnapshot(_aktifKoleksiyon),
          _getCollectionSnapshot(_emekliKoleksiyon),
        ]);
        aktifSnap = results[0];
        emekliSnap = results[1];
        break;
    }

    return (
      aktif: aktifSnap != null
          ? _parseFutbolcular(aktifSnap, 'aktif_')
          : <KariyerFutbolcu>[],
      emekli: emekliSnap != null
          ? _parseFutbolcular(emekliSnap, 'emekli_')
          : <KariyerFutbolcu>[],
    );
  }

  static Future<({List<KariyerFutbolcu> aktif, List<KariyerFutbolcu> emekli})>
      _fetchBothCollectionsFromFirestore() async {
    final results = await Future.wait([
      _getCollectionSnapshot(_aktifKoleksiyon),
      _getCollectionSnapshot(_emekliKoleksiyon),
    ]);

    final aktifSnap = results[0];
    final emekliSnap = results[1];

    return (
      aktif: aktifSnap != null
          ? _parseFutbolcular(aktifSnap, 'aktif_')
          : <KariyerFutbolcu>[],
      emekli: emekliSnap != null
          ? _parseFutbolcular(emekliSnap, 'emekli_')
          : <KariyerFutbolcu>[],
    );
  }

  static Future<QuerySnapshot<Map<String, dynamic>>?> _getCollectionSnapshot(
    String collectionName,
  ) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection(collectionName)
          .get(const GetOptions(source: Source.server));
      AppLogger.info(
        '[CareerMode] $collectionName sunucudan ${snap.docs.length} döküman çekildi',
      );
      return snap;
    } catch (serverErr) {
      AppLogger.warning(
        '[CareerMode] $collectionName sunucuya ulaşılamadı, Firestore cache deneniyor: $serverErr',
      );
      try {
        final snap = await FirebaseFirestore.instance
            .collection(collectionName)
            .get(const GetOptions(source: Source.cache));
        AppLogger.info(
          '[CareerMode] $collectionName Firestore cache\'den ${snap.docs.length} döküman çekildi',
        );
        return snap;
      } catch (cacheErr) {
        AppLogger.error(
          '[CareerMode] $collectionName Firestore cache de başarısız',
          cacheErr,
        );
        return null;
      }
    }
  }

  static List<KariyerFutbolcu> _parseFutbolcular(
    QuerySnapshot<Map<String, dynamic>> snap,
    String idPrefix,
  ) {
    return snap.docs
        .map((d) => KariyerFutbolcu.fromDoc(d, idPrefix: idPrefix))
        .where((f) => f.isim.isNotEmpty && f.kariyerYolu.isNotEmpty)
        .toList();
  }

  /// Takım adı karşılaştırması için isim normalizasyonu.
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

  // ── Şık üretimi ──────────────────────────────────────────────────────────

  /// Kulüp adı karşılaştırması için hafif normalizasyon: yalnızca baş/son
  /// boşluk temizliği, büyük/küçük harf farkı ve ardışık boşlukların tek
  /// boşluğa indirilmesi. Türkçe/aksanlı karakterler kasıtlı olarak
  /// SADELEŞTİRİLMEZ — bu yalnızca isim eşleştirme (`normalizePlayerName`)
  /// için kullanılan fuzzy bir kural; kariyer yolu karşılaştırmasında farklı
  /// yazılmış (örn. "Barcelona" / "Barcelone") kulüpler asla aynı kabul
  /// edilmemeli.
  static String _normalizeClubName(String text) =>
      text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  /// Bir futbolcunun ekranda gerçekten gösterilen kariyer yolundan (kulüp
  /// sırası korunarak, her kulüp adı [_normalizeClubName] ile normalize
  /// edilerek) karşılaştırma anahtarı üretir. İki futbolcunun anahtarı
  /// eşitse, kartta gösterilen kariyer yolları birebir aynıdır — fuzzy
  /// eşleştirme yapılmaz, yalnızca tam eşitlik kontrol edilir.
  static String careerPathKey(KariyerFutbolcu f) =>
      f.kariyerYolu.map(_normalizeClubName).join('||');

  /// Doğru oyuncu için 4 şık üretmeye çalışır: 1 doğru + 3 yanlış.
  ///
  /// Yanlış şık seçim önceliği:
  ///   Aşama 1 → aynı zorluk + aynı son takım
  ///   Aşama 2 → aynı son takım, herhangi zorluk
  ///   Aşama 3 → aynı zorluk, herhangi son takım
  ///   Aşama 4 → tüm havuzdan random
  ///
  /// Bütün aşamalarda, [careerPathKey] doğru oyuncununkiyle veya daha önce
  /// seçilmiş herhangi bir yanlış şıkkınkiyle birebir aynı olan adaylar
  /// elenir (yalnızca doğru-yanlış arasında değil, yanlış şıklar kendi
  /// aralarında da benzersizdir) — aksi hâlde kartta gösterilen kariyer
  /// yolundan doğru cevap ayırt edilemeyebilir.
  ///
  /// **Ya tam 4 eleman (1 doğru + 3 benzersiz yanlış) döner, ya da boş liste
  /// (`[]`).** 3 benzersiz yanlış şık bulunamazsa hiçbir yarım/eksik liste
  /// üretilmez — bu durumda çağıran taraf bu doğru oyuncuyu atlayıp başka
  /// bir doğru oyuncu denemelidir (bkz. `_sonrakiKart` içindeki deneme
  /// döngüsü). Eksik şıklı bir kart asla UI'a verilmemelidir.
  ///
  /// Başarılı dönüşte liste her çağrıda farklı sırada karıştırılmıştır.
  static List<String> generateChoices({
    required KariyerFutbolcu dogru,
    required List<KariyerFutbolcu> tumListe,
  }) {
    final rng = Random();

    String sonTakimNorm(KariyerFutbolcu f) =>
        f.kariyerYolu.isNotEmpty ? normalizePlayerName(f.kariyerYolu.last) : '';

    final dogruSonTakim = sonTakimNorm(dogru);
    final dogruZorluk = dogru.zorluk;
    final dogruYolAnahtari = careerPathKey(dogru);

    // Adaylar: doğru oyuncu ve boş isimli oyuncular çıkarıldı
    final adaylar = tumListe
        .where((f) => f.id != dogru.id && f.isim.trim().isNotEmpty)
        .toList();

    final secilen = <String>[];
    final secilenIsimler = <String>{dogru.isim};
    final secilenYolAnahtarlari = <String>{dogruYolAnahtari};

    void ekle(List<KariyerFutbolcu> havuz, String asama) {
      final musait = havuz
          .where((f) => !secilenIsimler.contains(f.isim))
          .toList()
        ..shuffle(rng);
      for (final f in musait) {
        if (secilen.length >= 3) break;
        // Anahtar kontrolü döngü içinde (yalnızca ön filtrede değil) yapılır
        // — aynı fallback aşamasındaki iki aday birbiriyle aynı kariyer
        // yoluna sahipse, ikisinin BİRLİKTE seçilmesini de engeller.
        final yolAnahtari = careerPathKey(f);
        if (secilenYolAnahtarlari.contains(yolAnahtari)) continue;
        secilen.add(f.isim);
        secilenIsimler.add(f.isim);
        secilenYolAnahtarlari.add(yolAnahtari);
        if (kDebugMode) {
          AppLogger.info(
            '[CareerMode][ŞIK][$asama] ${f.isim} | '
            'son: ${f.kariyerYolu.isNotEmpty ? f.kariyerYolu.last : "-"} | '
            'zorluk: ${f.zorluk}',
          );
        }
      }
    }

    if (kDebugMode) {
      AppLogger.info(
        '[CareerMode][ŞIK] ── Yeni kart ──────────────────────────\n'
        '  Doğru oyuncu : ${dogru.isim}\n'
        '  Zorluk       : $dogruZorluk\n'
        '  Son takım    : ${dogru.kariyerYolu.isNotEmpty ? dogru.kariyerYolu.last : "-"}',
      );
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

    if (secilen.length < 3) {
      if (kDebugMode) {
        AppLogger.info(
          '[CareerMode][ŞIK] Yetersiz benzersiz yanlış şık '
          '(${secilen.length}/3) — bu doğru oyuncu için kart üretilmiyor: '
          '${dogru.isim}',
        );
      }
      return const <String>[];
    }

    final sonuc = [dogru.isim, ...secilen]..shuffle(rng);

    if (kDebugMode) {
      AppLogger.info('[CareerMode][ŞIK] Karıştırılmış şıklar: $sonuc');
    }

    return sonuc;
  }

  /// [adaylar] listesindeki doğru-oyuncu adaylarını SIRAYLA, HER BİRİNİ EN
  /// FAZLA BİR KEZ dener; [generateChoices] tam 4 şık (1 doğru + 3
  /// benzersiz yanlış) döndüren İLK adayda durur ve o adayı + şıklarını
  /// döndürür. Sabit bir deneme üst sınırı yoktur — üst sınır [adaylar]
  /// listesinin uzunluğudur, bu yüzden hiçbir geçerli aday atlanmaz.
  ///
  /// [adaylar] içindeki hiçbir eleman 4 şık üretemezse (liste tamamen
  /// tarandıktan sonra) `null` döner — eksik şıklı bir kart asla üretilmez,
  /// çağıran taraf bu durumda oyunu güvenle sonlandırmalıdır.
  static ({KariyerFutbolcu dogru, List<String> secenekler})?
      pickCardWithValidChoices({
    required List<KariyerFutbolcu> adaylar,
    required List<KariyerFutbolcu> tumListe,
  }) {
    for (final aday in adaylar) {
      final secenekler = generateChoices(dogru: aday, tumListe: tumListe);
      if (secenekler.length == 4) {
        return (dogru: aday, secenekler: secenekler);
      }
    }
    return null;
  }
}
