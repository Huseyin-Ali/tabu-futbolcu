import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/match_config.dart';
import '../utils/logger.dart';

class MatchDirectorService {
  static const _logTag = 'MatchDirector';
  static const _collection = 'game_configs';
  static const _documentId = 'default_match_config';

  static MatchConfig? _cachedConfig;
  static final Random _rng = Random();

  static MatchConfig? get currentConfig => _cachedConfig;

  /// Firestore'dan gameplay config yükler; başarısız olursa default config kullanır.
  static Future<MatchConfig> loadConfig() async {
    AppLogger.info('[MatchDirector] loadConfig started', _logTag);

    try {
      var doc = await FirebaseFirestore.instance
          .collection(_collection)
          .doc(_documentId)
          .get(const GetOptions(source: Source.server));

      if (!doc.exists || doc.data() == null) {
        doc = await FirebaseFirestore.instance
            .collection(_collection)
            .doc(_documentId)
            .get(const GetOptions(source: Source.cache));
      }

      if (doc.exists && doc.data() != null) {
        _cachedConfig = MatchConfig.fromMap(doc.data()!);
        AppLogger.info(
          '[MatchDirector] Config loaded from Firestore',
          _logTag,
        );
        _logConfigSummary(_cachedConfig!);
        return _cachedConfig!;
      }

      AppLogger.warning(
        '[MatchDirector] Config document not found ($_collection/$_documentId)',
        _logTag,
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        '[MatchDirector] Firestore config read failed',
        e,
        stackTrace,
        _logTag,
      );
    }

    _cachedConfig = MatchConfig.defaults();
    AppLogger.info('[MatchDirector] Config fallback used', _logTag);
    _logConfigSummary(_cachedConfig!);
    return _cachedConfig!;
  }

  static void _logConfigSummary(MatchConfig config) {
    AppLogger.info(
      '[MatchDirector] riskEnabled=${config.riskCardEnabled}, '
      'riskRate=${config.riskSpawnRate}, '
      'blitzEnabled=${config.blitzEnabled}, '
      'blitzRate=${config.blitzSpawnRate}, '
      'passLimit=${config.passLimitEnabled}, '
      'maxPass=${config.maxPassCount}, '
      'normalPassPenalty=${config.normalPassComboPenalty}, '
      'extraPassPenalty=${config.extraPassComboPenalty}, '
      'adaptive=${config.adaptiveDirectorEnabled}, '
      'riskMinGap=${config.riskMinGap}, '
      'blitzMinGap=${config.blitzMinGap}, '
      'riskMaxRate=${config.riskMaxRate}, '
      'blitzMaxRate=${config.blitzMaxRate}, '
      'scoreBoostEnabled=${config.scoreBoostCardEnabled}, '
      'scoreBoostRate=${config.scoreBoostSpawnRate}',
      _logTag,
    );
  }

  static MatchConfig _activeConfig() => _cachedConfig ?? MatchConfig.defaults();

  static const double _maxAdaptiveScoreBoostRate = 0.10;

  /// Oyuncu performansına göre adaptif risk spawn oranı hesaplar.
  static double computeAdaptiveRiskRate({
    required int currentCombo,
    required int wrongStreak,
    required int remainingLives,
    required int cardsSinceLastRisk,
  }) {
    final config = _activeConfig();

    if (!config.riskCardEnabled) return 0;
    if (remainingLives <= 2) return 0;
    if (wrongStreak >= 3) return 0;
    if (cardsSinceLastRisk < config.riskMinGap) return 0;

    var rate = config.riskSpawnRate;
    if (currentCombo >= 20) {
      rate *= 2.5;
    } else if (currentCombo >= 15) {
      rate *= 2.0;
    } else if (currentCombo >= 10) {
      rate *= 1.5;
    }

    return rate.clamp(0.0, config.riskMaxRate);
  }

  /// Oyuncu performansına göre adaptif blitz spawn oranı hesaplar.
  /// [wrongStreak] >= 4 için garanti tetikleme bu metotta değil,
  /// [shouldSpawnBlitzAdaptive] içinde ele alınır.
  static double computeAdaptiveBlitzRate({
    required int currentCombo,
    required int wrongStreak,
    required int remainingLives,
    required int cardsSinceLastBlitz,
  }) {
    final config = _activeConfig();

    if (!config.blitzEnabled) return 0;
    if (cardsSinceLastBlitz < config.blitzMinGap) return 0;

    var rate = config.blitzSpawnRate;
    if (wrongStreak == 3) {
      rate *= 2;
    }
    if (remainingLives <= 2) {
      rate *= 1.5;
    }
    if (currentCombo >= 20) {
      rate *= 0.5;
    }

    return rate.clamp(0.0, config.blitzMaxRate);
  }

  static void _logBlitzDebug({
    required int currentCombo,
    required int wrongStreak,
    required int cardsSinceLastBlitz,
    required double finalRate,
    required bool forced,
    required bool result,
  }) {
    if (!kDebugMode) return;

    AppLogger.debug(
      '[MatchDirectorDebug] blitzCheck combo=$currentCombo '
      'wrongStreak=$wrongStreak sinceBlitz=$cardsSinceLastBlitz '
      'finalRate=${finalRate.toStringAsFixed(3)} forced=$forced result=$result',
      _logTag,
    );
  }

  /// Adaptif risk kartı spawn kararı.
  static bool shouldSpawnRiskCardAdaptive({
    required int currentCombo,
    required int wrongStreak,
    required int remainingLives,
    required int cardsSinceLastRisk,
    required int cardsSinceLastBlitz,
  }) {
    final config = _activeConfig();
    final finalRate = computeAdaptiveRiskRate(
      currentCombo: currentCombo,
      wrongStreak: wrongStreak,
      remainingLives: remainingLives,
      cardsSinceLastRisk: cardsSinceLastRisk,
    );

    final roll = finalRate <= 0 ? 1.0 : _rng.nextDouble();
    final triggered = finalRate > 0 && roll < finalRate;

    if (kDebugMode) {
      AppLogger.debug(
        '[MatchDirectorDebug] riskCheck combo=$currentCombo '
        'wrongStreak=$wrongStreak lives=$remainingLives '
        'sinceRisk=$cardsSinceLastRisk enabled=${config.riskCardEnabled} '
        'finalRate=${finalRate.toStringAsFixed(3)} result=$triggered',
        _logTag,
      );
    }

    if (triggered) {
      AppLogger.info(
        '[MatchDirector] Adaptive risk triggered | combo=$currentCombo | '
        'finalRate=${finalRate.toStringAsFixed(2)}',
        _logTag,
      );
    }
    return triggered;
  }

  /// Adaptif blitz spawn kararı.
  static bool shouldSpawnBlitzAdaptive({
    required int currentCombo,
    required int wrongStreak,
    required int remainingLives,
    required int cardsSinceLastRisk,
    required int cardsSinceLastBlitz,
  }) {
    final config = _activeConfig();

    if (!config.blitzEnabled) {
      _logBlitzDebug(
        currentCombo: currentCombo,
        wrongStreak: wrongStreak,
        cardsSinceLastBlitz: cardsSinceLastBlitz,
        finalRate: 0,
        forced: false,
        result: false,
      );
      return false;
    }

    if (cardsSinceLastBlitz < config.blitzMinGap) {
      _logBlitzDebug(
        currentCombo: currentCombo,
        wrongStreak: wrongStreak,
        cardsSinceLastBlitz: cardsSinceLastBlitz,
        finalRate: 0,
        forced: false,
        result: false,
      );
      return false;
    }

    if (wrongStreak >= 4) {
      _logBlitzDebug(
        currentCombo: currentCombo,
        wrongStreak: wrongStreak,
        cardsSinceLastBlitz: cardsSinceLastBlitz,
        finalRate: 1,
        forced: true,
        result: true,
      );
      AppLogger.info(
        '[MatchDirector] Adaptive blitz forced | combo=$currentCombo | '
        'wrongStreak=$wrongStreak',
        _logTag,
      );
      return true;
    }

    final finalRate = computeAdaptiveBlitzRate(
      currentCombo: currentCombo,
      wrongStreak: wrongStreak,
      remainingLives: remainingLives,
      cardsSinceLastBlitz: cardsSinceLastBlitz,
    );

    final roll = finalRate <= 0 ? 1.0 : _rng.nextDouble();
    final triggered = finalRate > 0 && roll < finalRate;

    _logBlitzDebug(
      currentCombo: currentCombo,
      wrongStreak: wrongStreak,
      cardsSinceLastBlitz: cardsSinceLastBlitz,
      finalRate: finalRate,
      forced: false,
      result: triggered,
    );

    if (triggered) {
      AppLogger.info(
        '[MatchDirector] Adaptive blitz triggered | combo=$currentCombo | '
        'wrongStreak=$wrongStreak | finalRate=${finalRate.toStringAsFixed(3)}',
        _logTag,
      );
    }
    return triggered;
  }

  /// Oyuncu performansına göre adaptif Çarpan Kartı spawn oranı hesaplar.
  static double computeAdaptiveScoreBoostRate({
    required int currentCombo,
    required int wrongStreak,
    required int cardsSinceLastScoreBoost,
    required bool isScoreBoostActive,
  }) {
    final config = _activeConfig();

    if (!config.scoreBoostCardEnabled) return 0;
    if (isScoreBoostActive) return 0;
    if (cardsSinceLastScoreBoost < config.scoreBoostMinGap) return 0;

    var rate = config.scoreBoostSpawnRate;
    if (wrongStreak >= 2) {
      rate *= 1.5;
    }
    if (currentCombo >= 15) {
      rate *= 0.75;
    }

    return rate.clamp(0.0, _maxAdaptiveScoreBoostRate);
  }

  /// Adaptif Çarpan Kartı spawn kararı.
  static bool shouldSpawnScoreBoostCardAdaptive({
    required int currentCombo,
    required int wrongStreak,
    required int remainingLives,
    required int cardsSinceLastScoreBoost,
    required bool isScoreBoostActive,
  }) {
    final finalRate = computeAdaptiveScoreBoostRate(
      currentCombo: currentCombo,
      wrongStreak: wrongStreak,
      cardsSinceLastScoreBoost: cardsSinceLastScoreBoost,
      isScoreBoostActive: isScoreBoostActive,
    );

    if (finalRate <= 0) return false;

    final roll = _rng.nextDouble();
    final triggered = roll < finalRate;
    if (triggered) {
      AppLogger.info('[ScoreBoost] Card triggered', _logTag);
    }
    return triggered;
  }

  /// Çarpan Kartı spawn kararı — [scoreBoostSpawnRate] olasılığına göre.
  static bool shouldSpawnScoreBoostCard() {
    final config = _activeConfig();
    if (!config.scoreBoostCardEnabled) return false;

    final roll = _rng.nextDouble();
    final triggered = roll < config.scoreBoostSpawnRate;
    if (triggered) {
      AppLogger.info('[ScoreBoost] Card triggered', _logTag);
    }
    return triggered;
  }

  /// Risk kartı spawn kararı — [riskSpawnRate] olasılığına göre.
  static bool shouldSpawnRiskCard() {
    final config = _activeConfig();
    final roll = _rng.nextDouble();

    if (kDebugMode) {
      AppLogger.debug(
        '[MatchDirector] Risk check: enabled=${config.riskCardEnabled}, '
        'rate=${config.riskSpawnRate}, roll=${roll.toStringAsFixed(3)}',
        _logTag,
      );
    }

    if (!config.riskCardEnabled) return false;

    final triggered = roll < config.riskSpawnRate;
    if (triggered) {
      AppLogger.info('[MatchDirector] Risk card triggered', _logTag);
    }
    return triggered;
  }

  /// Blitz spawn kararı — [blitzSpawnRate] olasılığına göre.
  static bool shouldSpawnBlitz() {
    final config = _activeConfig();
    final roll = _rng.nextDouble();

    if (kDebugMode) {
      AppLogger.debug(
        '[MatchDirector] Blitz check: enabled=${config.blitzEnabled}, '
        'rate=${config.blitzSpawnRate}, roll=${roll.toStringAsFixed(3)}',
        _logTag,
      );
    }

    if (!config.blitzEnabled) return false;

    final triggered = roll < config.blitzSpawnRate;
    if (triggered) {
      AppLogger.info('[MatchDirector] Blitz triggered', _logTag);
    }
    return triggered;
  }
}
