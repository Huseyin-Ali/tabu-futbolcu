import 'package:hive/hive.dart';

part 'game_history.g.dart';

@HiveType(typeId: 33)
class GameHistory extends HiveObject {
  @HiveField(0)
  final String takim1Ismi;

  @HiveField(1)
  final String takim2Ismi;

  @HiveField(2)
  final int takim1Skor;

  @HiveField(3)
  final int takim2Skor;

  @HiveField(4)
  final DateTime tarih;

  GameHistory({
    required this.takim1Ismi,
    required this.takim2Ismi,
    required this.takim1Skor,
    required this.takim2Skor,
    required this.tarih,
  });

  String get kazananTakim {
    if (takim1Skor > takim2Skor) return takim1Ismi;
    if (takim2Skor > takim1Skor) return takim2Ismi;
    return 'Berabere';
  }
} 