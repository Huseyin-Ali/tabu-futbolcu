import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'tabu_futbolcu.g.dart';

@HiveType(typeId: 34)
class TabuFutbolcu extends HiveObject {
  @HiveField(0)
  final String isim;

  @HiveField(1)
  final List<String> tabuKelimeler;

  @HiveField(2)
  final DateTime sonGuncelleme;

  TabuFutbolcu({
    required this.isim,
    required this.tabuKelimeler,
    required this.sonGuncelleme,
  });

  Map<String, dynamic> toMap() {
    return {
      'isim': isim,
      'tabu_kelimeler': tabuKelimeler,
    };
  }

  factory TabuFutbolcu.fromMap(Map<String, dynamic> map) {
    // Firestore'dan gelen updatedAt'ı kullan, yoksa şu anki zamanı kullan
    DateTime sonGuncelleme;
    if (map['updatedAt'] != null) {
      final updatedAt = map['updatedAt'];
      if (updatedAt is DateTime) {
        sonGuncelleme = updatedAt;
      } else if (updatedAt is Timestamp) {
        sonGuncelleme = updatedAt.toDate();
      } else {
        sonGuncelleme = DateTime.now();
      }
    } else {
      sonGuncelleme = DateTime.now();
    }
    
    return TabuFutbolcu(
      isim: map['isim'] as String,
      tabuKelimeler: List<String>.from(map['tabu_kelimeler']),
      sonGuncelleme: sonGuncelleme,
    );
  }
} 