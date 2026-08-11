import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import '../utils/logger.dart';

/// Tüm oyun içi Firebase Analytics event'lerinin merkezi servisi.
///
/// [configure] bootstrap tamamlandıktan sonra çağrılmalıdır.
/// Firebase başlatılmadıysa event'ler sessizce atlanır;
/// debug modda atlanma sebebi loglanır.
class AnalyticsService {
  static final FirebaseAnalytics _fa = FirebaseAnalytics.instance;

  /// Bootstrap sonucuna göre set edilir. false ise hiçbir event gönderilmez.
  static bool _available = true;

  // ── Event adı sabitleri ────────────────────────────────────────────────
  static const String _matchStarted = 'match_started';
  static const String _countdownStarted = 'countdown_started';
  static const String _turnStarted = 'turn_started';
  static const String _matchPaused = 'match_paused';
  static const String _matchResumed = 'match_resumed';
  static const String _correctGuess = 'correct_guess';
  static const String _tabuFail = 'tabu_fail';
  static const String _passUsed = 'pass_used';
  static const String _turnTimeout = 'turn_timeout';
  static const String _cardShown = 'card_shown';
  static const String _matchFinished = 'match_finished';
  static const String _audioToggled = 'audio_toggled';

  // ── Kariyer Avı event adı sabitleri ──────────────────────────────────────
  static const String _careerGameStarted = 'career_game_started';
  static const String _careerCardShown = 'career_card_shown';
  static const String _careerAnswerCorrect = 'career_answer_correct';
  static const String _careerAnswerWrong = 'career_answer_wrong';
  static const String _careerPassUsed = 'career_pass_used';
  static const String _careerHintUsed = 'career_hint_used';
  static const String _careerComboReached = 'career_combo_reached';
  static const String _careerLifeGained = 'career_life_gained';
  static const String _careerLifeLost = 'career_life_lost';
  static const String _careerRiskCardShown = 'career_risk_card_shown';
  static const String _careerRiskCardAccepted = 'career_risk_card_accepted';
  static const String _careerRiskCardRejected = 'career_risk_card_rejected';
  static const String _careerBlitzStarted = 'career_blitz_started';
  static const String _careerBlitzFinished = 'career_blitz_finished';
  static const String _careerGameFinished = 'career_game_finished';

  // ── Bootstrap ─────────────────────────────────────────────────────────

  /// [AppBootstrapResult.analyticsAvailable] değeriyle çağrılmalıdır.
  /// Bu method çağrılmadan önce eventler varsayılan olarak gönderilmeye çalışılır.
  static void configure({required bool analyticsAvailable}) {
    _available = analyticsAvailable;
    if (kDebugMode && !_available) {
      AppLogger.debug(
        '[Analytics] Pasif — Firebase başlatılmadığı için eventler loglanmayacak',
      );
    }
  }

  // ── İç yardımcılar ────────────────────────────────────────────────────

  static Future<void> _log(String name, Map<String, Object> parameters) async {
    if (!_available) {
      if (kDebugMode) {
        AppLogger.debug('[Analytics] Atlandı: $name (analytics pasif)');
      }
      return;
    }
    try {
      await _fa.logEvent(name: name, parameters: parameters);
    } catch (e) {
      if (kDebugMode) {
        AppLogger.warning(
            '[Analytics] Event gönderilemedi: $name', e.toString());
      }
    }
  }

  /// Firebase Analytics event parametreleri yalnızca String/sayısal
  /// değerleri destekler — `bool` desteklenmez ve gönderilirse logEvent
  /// sessizce/hata ile başarısız olur. Bool'lar 0/1 int'e çevrilir.
  static int _b(bool value) => value ? 1 : 0;

  static Future<void> _logSimple(String name) async {
    if (!_available) {
      if (kDebugMode) {
        AppLogger.debug('[Analytics] Atlandı: $name (analytics pasif)');
      }
      return;
    }
    try {
      await _fa.logEvent(name: name);
    } catch (e) {
      if (kDebugMode) {
        AppLogger.warning(
            '[Analytics] Event gönderilemedi: $name', e.toString());
      }
    }
  }

  // ── Public API ─────────────────────────────────────────────────────────

  /// Kullanıcı "Maçı Başlat" tuşuna bastığında.
  static Future<void> logMatchStarted({
    required int timeLimit,
    required int targetScore,
  }) =>
      _log(_matchStarted, {
        'screen_name': 'game_screen',
        'mode': 'multiplayer',
        'time_limit': timeLimit,
        'target_score': targetScore,
      });

  /// 3-2-1 geri sayım animasyonu başladığında.
  static Future<void> logCountdownStarted() => _logSimple(_countdownStarted);

  /// Geri sayım bitip aktif oyun zamanlayıcısı başladığında.
  static Future<void> logTurnStarted({
    required String activeTeam,
    required int remainingTime,
  }) =>
      _log(_turnStarted, {
        'active_team': activeTeam,
        'remaining_time': remainingTime,
      });

  /// Pause butonuna basıldığında.
  static Future<void> logMatchPaused() => _logSimple(_matchPaused);

  /// Pause diyaloğunda "Devam Et" seçildiğinde.
  static Future<void> logMatchResumed() => _logSimple(_matchResumed);

  /// DOĞRU butonuna basıldığında; parametreler setState sonrası güncel skorları içerir.
  static Future<void> logCorrectGuess({
    required String activeTeam,
    required int team1Score,
    required int team2Score,
    required String currentPlayer,
    required int remainingTime,
  }) =>
      _log(_correctGuess, {
        'active_team': activeTeam,
        'team1_score': team1Score,
        'team2_score': team2Score,
        'current_player': currentPlayer,
        'remaining_time': remainingTime,
      });

  /// TABU butonuna basıldığında; parametreler setState sonrası güncel skorları içerir.
  static Future<void> logTabuFail({
    required String activeTeam,
    required int team1Score,
    required int team2Score,
    required String currentPlayer,
    required int remainingTime,
  }) =>
      _log(_tabuFail, {
        'active_team': activeTeam,
        'team1_score': team1Score,
        'team2_score': team2Score,
        'current_player': currentPlayer,
        'remaining_time': remainingTime,
      });

  /// PAS butonuna basıldığında.
  static Future<void> logPassUsed({
    required String activeTeam,
    required int remainingPassCount,
    required String currentPlayer,
    required int remainingTime,
  }) =>
      _log(_passUsed, {
        'active_team': activeTeam,
        'remaining_pass_count': remainingPassCount,
        'current_player': currentPlayer,
        'remaining_time': remainingTime,
      });

  /// Süre dolup sıra değiştiğinde.
  static Future<void> logTurnTimeout({
    required String previousTeam,
    required String nextTeam,
  }) =>
      _log(_turnTimeout, {
        'previous_team': previousTeam,
        'next_team': nextTeam,
      });

  /// Ekranda yeni bir futbolcu kartı göründüğünde.
  /// Aynı kart için tekrar loglanmaz; bu kontrolü çağıran taraf yapar.
  static Future<void> logCardShown({
    required String playerId,
    required String playerName,
  }) =>
      _log(_cardShown, {
        'player_id': playerId,
        'player_name': playerName,
      });

  /// Birisi puan hedefine ulaşıp oyun bittiğinde; navigasyondan önce loglanır.
  static Future<void> logMatchFinished({
    required String winnerTeam,
    required int team1Score,
    required int team2Score,
    required int targetScore,
  }) =>
      _log(_matchFinished, {
        'winner_team': winnerTeam,
        'team1_score': team1Score,
        'team2_score': team2Score,
        'target_score': targetScore,
      });

  /// Ses simgesine dokunulduğunda.
  static Future<void> logAudioToggled({required bool isSoundOn}) =>
      _log(_audioToggled, {'is_sound_on': _b(isSoundOn)});

  // ── Kariyer Avı Public API ────────────────────────────────────────────

  /// Kariyer Avı futbolcuları yüklenip ilk kart gösterilmeden hemen önce.
  static Future<void> logCareerGameStarted({
    required String difficulty,
    required String collectionType,
    required int durationLimit,
    required int passLimit,
    required int startingLives,
  }) =>
      _log(_careerGameStarted, {
        'game_mode': 'career',
        'difficulty': difficulty,
        'collection_type': collectionType,
        'duration_limit': durationLimit,
        'pass_limit': passLimit,
        'starting_lives': startingLives,
      });

  /// Ekranda yeni bir Kariyer Avı kartı göründüğünde. Yüksek kardinaliteli
  /// oyuncu kimliği/ismi kasıtlı olarak gönderilmez.
  static Future<void> logCareerCardShown({
    required String difficulty,
    required int cardIndex,
    required bool isRiskCard,
    required bool isScoreBoostCard,
    required bool isBlitzActive,
  }) =>
      _log(_careerCardShown, {
        'difficulty': difficulty,
        'card_index': cardIndex,
        'is_risk_card': _b(isRiskCard),
        'is_score_boost_card': _b(isScoreBoostCard),
        'is_blitz_active': _b(isBlitzActive),
      });

  /// Kariyer Avı'nda doğru cevap verildiğinde.
  static Future<void> logCareerAnswerCorrect({
    required String difficulty,
    required int combo,
    required int currentLives,
    required bool isRiskCard,
    required bool isScoreBoostCard,
    required bool isHintUsed,
  }) =>
      _log(_careerAnswerCorrect, {
        'difficulty': difficulty,
        'combo': combo,
        'current_lives': currentLives,
        'is_risk_card': _b(isRiskCard),
        'is_score_boost_card': _b(isScoreBoostCard),
        'is_hint_used': _b(isHintUsed),
      });

  /// Kariyer Avı'nda yanlış cevap verildiğinde.
  static Future<void> logCareerAnswerWrong({
    required String difficulty,
    required int currentLives,
    required bool isRiskCard,
    required bool isScoreBoostCard,
    required bool isHintUsed,
  }) =>
      _log(_careerAnswerWrong, {
        'difficulty': difficulty,
        'current_lives': currentLives,
        'is_risk_card': _b(isRiskCard),
        'is_score_boost_card': _b(isScoreBoostCard),
        'is_hint_used': _b(isHintUsed),
      });

  /// PAS kullanıldığında (normal veya ekstra pas).
  static Future<void> logCareerPassUsed({
    required String difficulty,
    required int remainingPassCount,
    required bool isExtraPass,
    required int comboAfter,
  }) =>
      _log(_careerPassUsed, {
        'difficulty': difficulty,
        'remaining_pass_count': remainingPassCount,
        'is_extra_pass': _b(isExtraPass),
        'combo_after': comboAfter,
      });

  /// İpucu kullanıldığında (oyun başına tek hak).
  static Future<void> logCareerHintUsed({
    required String difficulty,
    required int cardIndex,
  }) =>
      _log(_careerHintUsed, {
        'difficulty': difficulty,
        'card_index': cardIndex,
      });

  /// Combo bonus eşiğine ulaşılıp +1 puan verildiğinde.
  static Future<void> logCareerComboReached({
    required String difficulty,
    required int combo,
    required int threshold,
  }) =>
      _log(_careerComboReached, {
        'difficulty': difficulty,
        'combo': combo,
        'threshold': threshold,
      });

  /// Combo bonusuyla can kazanıldığında.
  static Future<void> logCareerLifeGained({
    required String difficulty,
    required int currentLives,
    required String source,
  }) =>
      _log(_careerLifeGained, {
        'difficulty': difficulty,
        'current_lives': currentLives,
        'source': source,
      });

  /// Yanlış cevapla can kaybedildiğinde (Risk kartı can düşürmez).
  static Future<void> logCareerLifeLost({
    required String difficulty,
    required int currentLives,
    required String source,
  }) =>
      _log(_careerLifeLost, {
        'difficulty': difficulty,
        'current_lives': currentLives,
        'source': source,
      });

  /// Risk kartı ekrana geldiğinde.
  static Future<void> logCareerRiskCardShown({
    required String difficulty,
    required int cardIndex,
    required int reward,
    required int penalty,
  }) =>
      _log(_careerRiskCardShown, {
        'difficulty': difficulty,
        'card_index': cardIndex,
        'reward': reward,
        'penalty': penalty,
      });

  /// Risk kartı kabul edildiğinde.
  static Future<void> logCareerRiskCardAccepted({
    required String difficulty,
  }) =>
      _log(_careerRiskCardAccepted, {'difficulty': difficulty});

  /// Risk kartı pas geçildiğinde.
  static Future<void> logCareerRiskCardRejected({
    required String difficulty,
  }) =>
      _log(_careerRiskCardRejected, {'difficulty': difficulty});

  /// Blitz modu başladığında (normal veya wrongStreak>=3 zorlamalı tetikleme).
  static Future<void> logCareerBlitzStarted({
    required String difficulty,
    required int comboAtTrigger,
    required int triggerCount,
  }) =>
      _log(_careerBlitzStarted, {
        'difficulty': difficulty,
        'combo_at_trigger': comboAtTrigger,
        'trigger_count': triggerCount,
      });

  /// Blitz modu süresi dolduğunda. Sayaçlar bu oyun için kümülatiftir
  /// (yalnızca bu Blitz oturumuna ait değildir) — [CareerGameHistory] ile
  /// aynı toplam sayaçlar kullanılır, yeni bir oturum sayaç eklenmez.
  static Future<void> logCareerBlitzFinished({
    required String difficulty,
    required int correctCountTotal,
    required int bonusScoreTotal,
  }) =>
      _log(_careerBlitzFinished, {
        'difficulty': difficulty,
        'correct_count_total': correctCountTotal,
        'bonus_score_total': bonusScoreTotal,
      });

  /// Kariyer Avı oyunu bittiğinde — can bitti, süre bitti veya oyuncu
  /// bitirmeden ana menüye/yeniden başlatmaya çıktı.
  /// [gameResult] `win`/`lose`/`timeout`/`quit` kümesine normalize edilir;
  /// tanınmayan bir değer güvenli varsayılan olarak `quit`'e düşer.
  /// Not: Kariyer Avı'nda şu an bir "kazanma" koşulu yok, bu yüzden `win`
  /// üretilmez — küme yalnızca gelecekteki bir kazanma koşuluna hazırlıktır.
  static Future<void> logCareerGameFinished({
    required String difficulty,
    required int score,
    required int durationSeconds,
    required int correctAnswers,
    required int wrongAnswers,
    required int passUsedCount,
    required int hintUsedCount,
    required int maxCombo,
    required String gameResult,
  }) {
    const allowedResults = {'win', 'lose', 'timeout', 'quit'};
    final normalizedResult =
        allowedResults.contains(gameResult) ? gameResult : 'quit';
    return _log(_careerGameFinished, {
      'game_mode': 'career',
      'difficulty': difficulty,
      'score': score,
      'duration': durationSeconds,
      'correct_answers': correctAnswers,
      'wrong_answers': wrongAnswers,
      'pass_used_count': passUsedCount,
      'hint_used_count': hintUsedCount,
      'max_combo': maxCombo,
      'game_result': normalizedResult,
    });
  }
}
