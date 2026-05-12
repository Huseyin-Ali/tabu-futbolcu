import 'package:cloud_firestore/cloud_firestore.dart';

class KariyerFutbolcu {
  final String id;
  final String isim;
  final List<String> kariyerYolu;
  final String zorluk;

  const KariyerFutbolcu({
    required this.id,
    required this.isim,
    required this.kariyerYolu,
    required this.zorluk,
  });

  factory KariyerFutbolcu.fromDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    final isim = (data['isim'] ?? '').toString().trim();

    final raw = data['kariyer_yolu'];
    List<String> kariyerYolu = [];
    if (raw is List) {
      kariyerYolu = raw
          .where((e) => e != null)
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList();
    } else if (raw is String && raw.isNotEmpty) {
      kariyerYolu = raw
          .split(RegExp(r'[,→\n]'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }

    final zorluk =
        (data['zorluk'] ?? 'orta').toString().toLowerCase().trim();

    return KariyerFutbolcu(
      id: doc.id,
      isim: isim,
      kariyerYolu: kariyerYolu,
      zorluk: zorluk,
    );
  }
}
