import 'package:cloud_firestore/cloud_firestore.dart';

class Futbolcu {
  final String id;
  final String isim;
  final List<String> tabuKelimeler;

  Futbolcu({
    required this.id,
    required this.isim,
    required this.tabuKelimeler,
  });

  factory Futbolcu.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    // İsim validation: null, boş string kontrolü
    final isimRaw = data['isim'];
    final isim = (isimRaw == null || isimRaw.toString().trim().isEmpty)
        ? 'Bilinmeyen Futbolcu'
        : isimRaw.toString().trim();

    // Tabu kelimeler validation: null, boş liste, boş string kontrolü
    // Sadece gerçek tabu kelimeleri döndür (null/boş olanları gösterme)
    final raw = data['tabu_kelimeler'];
    final List<String> tabu = (raw is List)
        ? raw
            .where((e) => e != null) // null değerleri filtrele
            .map((e) => e.toString().trim())
            .where((s) => s.isNotEmpty) // boş string'leri filtrele
            .take(5) // Maximum 5 kelime (fazlasını kes)
            .toList()
        : <String>[];

    // Sadece gerçek tabu kelimeleri döndür (placeholder ekleme)

    return Futbolcu(
      id: doc.id,
      isim: isim,
      tabuKelimeler: tabu, // Boş liste olabilir, UI'da kontrol edilecek
    );
  }
}
