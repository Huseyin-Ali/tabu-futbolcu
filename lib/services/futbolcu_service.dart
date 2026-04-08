import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tabu_futbolcu.dart';
import '../models/futbolcu.dart';
import '../constants/app_constants.dart';
import '../utils/logger.dart';

class FutbolcuService {
  static const String _boxName = AppConstants.futbolcularBox;

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

    // 3. Firestore'dan aktif futbolcuları çek (arka planda)
    // Not: updatedAt kontrolü client-side'da yapılıyor (index gereksinimini önlemek için)
    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('futbolcular')
          .where('durum', isEqualTo: 'aktif')
          .get();

      if (snapshot.docs.isNotEmpty) {
        // Tüm aktif futbolcuları al
        final allFutbolcular = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id; // ID'yi ekle (güncelleme için)
          return TabuFutbolcu.fromMap(data);
        }).toList();

        // Client-side'da updatedAt kontrolü yap (index gereksinimini önler)
        List<TabuFutbolcu> updatedFutbolcular;
        if (lastSync != null) {
          updatedFutbolcular = allFutbolcular.where((futbolcu) {
            return futbolcu.sonGuncelleme.isAfter(lastSync!);
          }).toList();
        } else {
          // İlk senkronizasyon: Tüm aktif futbolcuları al
          updatedFutbolcular = allFutbolcular;
        }

        if (updatedFutbolcular.isNotEmpty) {
          AppLogger.info('Firestore\'dan ${updatedFutbolcular.length} güncellenmiş futbolcu çekildi (toplam ${allFutbolcular.length} aktif)');

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
        final QuerySnapshot snapshot = await FirebaseFirestore.instance
            .collection('futbolcular')
            .where('durum', isEqualTo: 'aktif')
            .get();

        final futbolcular = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return TabuFutbolcu.fromMap(data);
        }).toList();

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
  static Future<List<Futbolcu>> getFutbolcularProduction() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('futbolcular')
          .where('durum', isEqualTo: 'aktif')
          .get(const GetOptions(source: Source.serverAndCache));

      return snap.docs.map((d) => Futbolcu.fromDoc(d)).toList();
    } catch (e, stackTrace) {
      AppLogger.error('Futbolcular yüklenirken hata oluştu', e, stackTrace);
      return [];
    }
  }
} 