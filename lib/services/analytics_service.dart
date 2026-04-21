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

  static Future<void> _log(
      String name, Map<String, Object> parameters) async {
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
        AppLogger.warning('[Analytics] Event gönderilemedi: $name', e.toString());
      }
    }
  }

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
        AppLogger.warning('[Analytics] Event gönderilemedi: $name', e.toString());
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
      _log(_audioToggled, {'is_sound_on': isSoundOn});
}
