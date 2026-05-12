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
  final int maxCombo;
  final int bonusScore;
  final int remainingLives;
  final int usedHintCount;
  final int hintedCorrectCount;
  final int totalRiskCount;
  final int acceptedRiskCount;
  final int wonRiskCount;
  final int lostRiskCount;
  final int riskScoreGain;
  final int riskScoreLoss;

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
    this.maxCombo = 0,
    this.bonusScore = 0,
    this.remainingLives = 0,
    this.usedHintCount = 0,
    this.hintedCorrectCount = 0,
    this.totalRiskCount = 0,
    this.acceptedRiskCount = 0,
    this.wonRiskCount = 0,
    this.lostRiskCount = 0,
    this.riskScoreGain = 0,
    this.riskScoreLoss = 0,
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
        'maxCombo': maxCombo,
        'bonusScore': bonusScore,
        'remainingLives': remainingLives,
        'usedHintCount': usedHintCount,
        'hintedCorrectCount': hintedCorrectCount,
        'totalRiskCount': totalRiskCount,
        'acceptedRiskCount': acceptedRiskCount,
        'wonRiskCount': wonRiskCount,
        'lostRiskCount': lostRiskCount,
        'riskScoreGain': riskScoreGain,
        'riskScoreLoss': riskScoreLoss,
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
        maxCombo: (map['maxCombo'] as num?)?.toInt() ?? 0,
        bonusScore: (map['bonusScore'] as num?)?.toInt() ?? 0,
        remainingLives: (map['remainingLives'] as num?)?.toInt() ?? 0,
        usedHintCount: (map['usedHintCount'] as num?)?.toInt() ?? 0,
        hintedCorrectCount: (map['hintedCorrectCount'] as num?)?.toInt() ?? 0,
        totalRiskCount: (map['totalRiskCount'] as num?)?.toInt() ?? 0,
        acceptedRiskCount: (map['acceptedRiskCount'] as num?)?.toInt() ?? 0,
        wonRiskCount: (map['wonRiskCount'] as num?)?.toInt() ?? 0,
        lostRiskCount: (map['lostRiskCount'] as num?)?.toInt() ?? 0,
        riskScoreGain: (map['riskScoreGain'] as num?)?.toInt() ?? 0,
        riskScoreLoss: (map['riskScoreLoss'] as num?)?.toInt() ?? 0,
      );
}
