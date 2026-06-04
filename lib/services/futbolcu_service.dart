import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tabu_futbolcu.dart';
import '../models/futbolcu.dart';
import '../constants/app_constants.dart';
import '../utils/logger.dart';

class FutbolcuService {
  static const String _boxName = AppConstants.futbolcularBox;
  static const String _aktifKoleksiyon = 'tumAktifFutbolcular';
  static const String _emekliKoleksiyon = 'tumEmekliFutbolcular';

  static bool _isValidTabuFutbolcu(Futbolcu futbolcu) {
    return futbolcu.isim.trim().isNotEmpty &&
        futbolcu.isim != 'Bilinmeyen Futbolcu' &&
        futbolcu.tabuKelimeler.isNotEmpty;
  }

  static List<TabuFutbolcu> _mapDocsToTabuFutbolcular(
    QuerySnapshot snapshot,
  ) {
    return snapshot.docs
        .map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return TabuFutbolcu.fromMap(data);
        })
        .where((f) => f.isim.trim().isNotEmpty && f.tabuKelimeler.isNotEmpty)
        .toList();
  }

  static Future<List<Futbolcu>> _fetchAktifTabuFutbolcular() async {
    final snap = await FirebaseFirestore.instance
        .collection(_aktifKoleksiyon)
        .get(const GetOptions(source: Source.serverAndCache));

    return snap.docs
        .map((d) => Futbolcu.fromDoc(d, idPrefix: 'aktif_'))
        .where(_isValidTabuFutbolcu)
        .toList();
  }

  static Future<List<TabuFutbolcu>> _fetchAktifTabuFutbolcularForHive() async {
    final snap = await FirebaseFirestore.instance
        .collection(_aktifKoleksiyon)
        .get();

    return _mapDocsToTabuFutbolcular(snap);
  }

  static Future<List<Futbolcu>> _fetchEmekliTabuFutbolcular() async {
    final snap = await FirebaseFirestore.instance
        .collection(_emekliKoleksiyon)
        .get(const GetOptions(source: Source.serverAndCache));

    return snap.docs
        .map((d) => Futbolcu.fromDoc(d, idPrefix: 'emekli_'))
        .where(_isValidTabuFutbolcu)
        .toList();
  }

  static Future<List<TabuFutbolcu>> _fetchEmekliTabuFutbolcularForHive() async {
    final snap = await FirebaseFirestore.instance
        .collection(_emekliKoleksiyon)
        .get();

    return _mapDocsToTabuFutbolcular(snap);
  }

  /// Offline-first mantığı: Önce Hive'dan oku, sonra güncellemeleri çek
  static Future<List<TabuFutbolcu>> getFutbolcular() async {
    // Hive kutusunu aç
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox<TabuFutbolcu>(_boxName);
    }
    final box = Hive.box<TabuFutbolcu>(_boxName);

    // 1. OFFLINE FIRST: Önce Hive'dan oku (hızlı başlangıç)
    List<TabuFutbolcu> cachedFutbolcular = [];
    if (box.isNotEmpty) {
      cachedFutbolcular = box.values.toList();
      AppLogger.info('Hive\'dan ${cachedFutbolcular.length} futbolcu yüklendi');
    }

    // 2. lastSync zamanını al
    final prefs = await SharedPreferences.getInstance();
    final lastSyncMillis = prefs.getInt(AppConstants.keyFutbolcularLastSync);
    DateTime? lastSync;
    if (lastSyncMillis != null) {
      lastSync = DateTime.fromMillisecondsSinceEpoch(lastSyncMillis);
    }

    // 3. Firestore'dan aktif ve emekli futbolcuları çek (arka planda)
    // Not: updatedAt kontrolü client-side'da yapılıyor (index gereksinimini önlemek için)
    try {
      final snapshots = await Future.wait<List<TabuFutbolcu>>([
        _fetchAktifTabuFutbolcularForHive(),
        _fetchEmekliTabuFutbolcularForHive(),
      ]);

      final aktifFutbolcular = snapshots[0];
      final emekliFutbolcular = snapshots[1];

      final allFutbolcular = [
        ...aktifFutbolcular,
        ...emekliFutbolcular,
      ];

      if (allFutbolcular.isNotEmpty) {
        // Client-side'da updatedAt kontrolü yap (index gereksinimini önler)
        List<TabuFutbolcu> updatedFutbolcular;
        if (lastSync != null) {
          updatedFutbolcular = allFutbolcular.where((futbolcu) {
            return futbolcu.sonGuncelleme.isAfter(lastSync!);
          }).toList();
        } else {
          // İlk senkronizasyon: Tüm futbolcuları al
          updatedFutbolcular = allFutbolcular;
        }

        if (updatedFutbolcular.isNotEmpty) {
          AppLogger.info(
              'Firestore\'dan ${updatedFutbolcular.length} güncellenmiş futbolcu çekildi '
              '(toplam ${allFutbolcular.length}: aktif + emekli)');

        // Hive'da güncelle veya ekle
        for (final futbolcu in updatedFutbolcular) {
          // Aynı isimde futbolcu var mı kontrol et
          final existingIndex = cachedFutbolcular.indexWhere(
            (f) => f.isim == futbolcu.isim,
          );

          if (existingIndex != -1) {
            // Güncelle
            cachedFutbolcular[existingIndex] = futbolcu;
          } else {
            // Yeni ekle
            cachedFutbolcular.add(futbolcu);
          }
        }

        // Tüm listeyi Hive'a yaz (güncellemeler dahil)
        await box.clear();
        await box.addAll(cachedFutbolcular);

          // lastSync'ı güncelle
          await prefs.setInt(
            AppConstants.keyFutbolcularLastSync,
            DateTime.now().millisecondsSinceEpoch,
          );
        } else {
          AppLogger.info('Güncellenmiş futbolcu yok');
        }
      }
    } catch (e, stackTrace) {
      AppLogger.error('Firestore\'dan futbolcular güncellenirken hata oluştu', e, stackTrace);
      
      // Hata durumunda cache'deki verileri kullan (offline-first)
      if (cachedFutbolcular.isNotEmpty) {
        AppLogger.info('Hata nedeniyle cache\'den futbolcular kullanılıyor');
        return cachedFutbolcular;
      }
    }

    // 4. İlk açılışta cache boşsa, tüm verileri çek
    if (cachedFutbolcular.isEmpty) {
      AppLogger.info('İlk açılış: Tüm futbolcular Firestore\'dan çekiliyor');
      try {
        final snapshots = await Future.wait<List<TabuFutbolcu>>([
          _fetchAktifTabuFutbolcularForHive(),
          _fetchEmekliTabuFutbolcularForHive(),
        ]);

        final aktifFutbolcular = snapshots[0];
        final emekliFutbolcular = snapshots[1];
        final futbolcular = [
          ...aktifFutbolcular,
          ...emekliFutbolcular,
        ];

        // Hive'a kaydet
        await box.clear();
        await box.addAll(futbolcular);

        // lastSync'ı güncelle
        await prefs.setInt(
          AppConstants.keyFutbolcularLastSync,
          DateTime.now().millisecondsSinceEpoch,
        );

        AppLogger.info('${futbolcular.length} futbolcu Hive\'a kaydedildi');
        return futbolcular;
      } catch (e, stackTrace) {
        AppLogger.error('İlk açılışta futbolcular yüklenirken hata oluştu', e, stackTrace);
        
        // Hata durumunda varsayılan bir futbolcu döndür
        return [
          TabuFutbolcu(
            isim: 'Hata Oluştu',
            tabuKelimeler: ['Lütfen', 'Tekrar', 'Deneyin'],
            sonGuncelleme: DateTime.now(),
          )
        ];
      }
    }

    // Cache'den döndür
    return cachedFutbolcular;
  }

  static Future<void> clearCache() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox<TabuFutbolcu>(_boxName);
    }
    final box = Hive.box<TabuFutbolcu>(_boxName);
    await box.clear();
  }

  /// Production-ready: Doc ID ile takip, validation, cache desteği
  static Future<List<Futbolcu>> getFutbolcularProduction({
    String koleksiyonTipi = 'karışık',
  }) async {
    try {
      final secilenKoleksiyon = koleksiyonTipi.toLowerCase().trim();

      List<Futbolcu> aktifFutbolcular = [];
      List<Futbolcu> emekliFutbolcular = [];

      switch (secilenKoleksiyon) {
        case 'aktif':
          aktifFutbolcular = await _fetchAktifTabuFutbolcular();
          break;
        case 'veteran':
          emekliFutbolcular = await _fetchEmekliTabuFutbolcular();
          break;
        case 'karışık':
          final results = await Future.wait([
            _fetchAktifTabuFutbolcular(),
            _fetchEmekliTabuFutbolcular(),
          ]);
          aktifFutbolcular = results[0];
          emekliFutbolcular = results[1];
          break;
        default:
          AppLogger.warning(
              '[Tabu] Bilinmeyen kart tipi: $koleksiyonTipi, karışık kullanılıyor');
          final results = await Future.wait([
            _fetchAktifTabuFutbolcular(),
            _fetchEmekliTabuFutbolcular(),
          ]);
          aktifFutbolcular = results[0];
          emekliFutbolcular = results[1];
          break;
      }

      final tumListe = [...aktifFutbolcular, ...emekliFutbolcular];

      AppLogger.info(
          'Tabu modu: ${tumListe.length} futbolcu '
          '(kart tipi: $secilenKoleksiyon, aktif: ${aktifFutbolcular.length}, '
          'emekli: ${emekliFutbolcular.length})');

      return tumListe;
    } catch (e, stackTrace) {
      AppLogger.error('Futbolcular yüklenirken hata oluştu', e, stackTrace);
      return [];
    }
  }
} 