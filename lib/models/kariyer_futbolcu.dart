import 'package:cloud_firestore/cloud_firestore.dart';

class KariyerFutbolcu {
  final String id;
  final String isim;
  final List<String> kariyerYolu;
  final String zorluk;

  // İpucu alanları — Firestore'da yoksa null
  final String? ulke;
  final String? pozisyon;
  final int? dogumYili;

  const KariyerFutbolcu({
    required this.id,
    required this.isim,
    required this.kariyerYolu,
    required this.zorluk,
    this.ulke,
    this.pozisyon,
    this.dogumYili,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'isim': isim,
      'kariyer_yolu': kariyerYolu,
      'zorluk': zorluk,
      if (ulke != null) 'ulke': ulke,
      if (pozisyon != null) 'pozisyon': pozisyon,
      if (dogumYili != null) 'dogum_yili': dogumYili,
    };
  }

  factory KariyerFutbolcu.fromMap(Map<String, dynamic> map) {
    final raw = map['kariyer_yolu'];
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

    final rawDY = map['dogum_yili'] ?? map['dogumYili'];
    int? dogumYili;
    if (rawDY != null) {
      dogumYili = int.tryParse(rawDY.toString());
    }

    return KariyerFutbolcu(
      id: (map['id'] ?? '').toString(),
      isim: (map['isim'] ?? '').toString().trim(),
      kariyerYolu: kariyerYolu,
      zorluk: (map['zorluk'] ?? 'orta').toString().toLowerCase().trim(),
      ulke: map['ulke']?.toString(),
      pozisyon: map['pozisyon']?.toString(),
      dogumYili: dogumYili,
    );
  }

  factory KariyerFutbolcu.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc, {
    String? idPrefix,
  }) {
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

    // İpucu alanları — birden fazla alan adını dene
    String? ulke;
    final rawUlke = (data['ulke'] ?? data['ülke'] ?? data['country'] ?? '')
        .toString()
        .trim();
    if (rawUlke.isNotEmpty) ulke = rawUlke;

    String? pozisyon;
    final rawPoz =
        (data['pozisyon'] ?? data['position'] ?? '').toString().trim();
    if (rawPoz.isNotEmpty) pozisyon = rawPoz;

    int? dogumYili;
    final rawDY = data['dogum_yili'] ?? data['dogumYili'] ??
        data['birth_year'] ?? data['yil'];
    if (rawDY != null) {
      dogumYili = int.tryParse(rawDY.toString());
    }

    return KariyerFutbolcu(
      id: idPrefix != null ? '$idPrefix${doc.id}' : doc.id,
      isim: isim,
      kariyerYolu: kariyerYolu,
      zorluk: zorluk,
      ulke: ulke,
      pozisyon: pozisyon,
      dogumYili: dogumYili,
    );
  }
}
