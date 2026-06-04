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
      final doc = await FirebaseFirestore.instance
          .collection(_collection)
          .doc(_documentId)
          .get(const GetOptions(source: Source.server));

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
      'blitzRate=${config.blitzSpawnRate}',
      _logTag,
    );
  }

  static MatchConfig _activeConfig() => _cachedConfig ?? MatchConfig.defaults();

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
