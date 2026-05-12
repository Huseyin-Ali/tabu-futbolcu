/// Kariyer Avı oyununun geçmiş kaydı.
/// Map<String, dynamic> olarak gameBox'a yazılır — Hive adapter gerektirmez.
class CareerGameHistory {
  final int skor;
  final int dogruSayisi;
  final int yanlisSayisi;
  final int pasSayisi;
  final int oynanankartSayisi;
  final String zorluk;
  final int sure;
  final double basariOrani;
  final DateTime tarih;

  CareerGameHistory({
    required this.skor,
    required this.dogruSayisi,
    required this.yanlisSayisi,
    required this.pasSayisi,
    required this.oynanankartSayisi,
    required this.zorluk,
    required this.sure,
    required this.basariOrani,
    required this.tarih,
  });

  Map<String, dynamic> toMap() => {
        'mode': 'career',
        'skor': skor,
        'dogruSayisi': dogruSayisi,
        'yanlisSayisi': yanlisSayisi,
        'pasSayisi': pasSayisi,
        'oynanankartSayisi': oynanankartSayisi,
        'zorluk': zorluk,
        'sure': sure,
        'basariOrani': basariOrani,
        'tarih': tarih.toIso8601String(),
      };

  static CareerGameHistory fromMap(Map<String, dynamic> map) =>
      CareerGameHistory(
        skor: (map['skor'] as num).toInt(),
        dogruSayisi: (map['dogruSayisi'] as num).toInt(),
        yanlisSayisi: (map['yanlisSayisi'] as num).toInt(),
        pasSayisi: (map['pasSayisi'] as num).toInt(),
        oynanankartSayisi: (map['oynanankartSayisi'] as num).toInt(),
        zorluk: map['zorluk'] as String,
        sure: (map['sure'] as num).toInt(),
        basariOrani: (map['basariOrani'] as num).toDouble(),
        tarih: DateTime.parse(map['tarih'] as String),
      );
}
