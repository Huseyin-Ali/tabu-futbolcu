class MatchConfig {
  final bool riskCardEnabled;
  final double riskSpawnRate;
  final bool blitzEnabled;
  final double blitzSpawnRate;
  final bool passLimitEnabled;
  final int maxPassCount;
  final int normalPassComboPenalty;
  final int extraPassComboPenalty;
  final bool darkCardEnabled;
  final bool reverseCardEnabled;
  final bool multiplierCardEnabled;
  final bool curseCardEnabled;
  final bool adaptiveDirectorEnabled;
  final int riskMinGap;
  final int blitzMinGap;
  final double riskMaxRate;
  final double blitzMaxRate;
  final bool scoreBoostCardEnabled;
  final double scoreBoostSpawnRate;
  final int scoreBoostCorrectAnswerCount;
  final int scoreBoostValue;
  final int scoreBoostMinGap;

  const MatchConfig({
    required this.riskCardEnabled,
    required this.riskSpawnRate,
    required this.blitzEnabled,
    required this.blitzSpawnRate,
    required this.passLimitEnabled,
    required this.maxPassCount,
    required this.normalPassComboPenalty,
    required this.extraPassComboPenalty,
    required this.darkCardEnabled,
    required this.reverseCardEnabled,
    required this.multiplierCardEnabled,
    required this.curseCardEnabled,
    required this.adaptiveDirectorEnabled,
    required this.riskMinGap,
    required this.blitzMinGap,
    required this.riskMaxRate,
    required this.blitzMaxRate,
    required this.scoreBoostCardEnabled,
    required this.scoreBoostSpawnRate,
    required this.scoreBoostCorrectAnswerCount,
    required this.scoreBoostValue,
    required this.scoreBoostMinGap,
  });

  factory MatchConfig.defaults() {
    return const MatchConfig(
      riskCardEnabled: true,
      riskSpawnRate: 0.10,
      blitzEnabled: true,
      blitzSpawnRate: 0.05,
      passLimitEnabled: true,
      maxPassCount: 3,
      normalPassComboPenalty: 1,
      extraPassComboPenalty: 2,
      darkCardEnabled: false,
      reverseCardEnabled: false,
      multiplierCardEnabled: false,
      curseCardEnabled: false,
      adaptiveDirectorEnabled: true,
      riskMinGap: 4,
      blitzMinGap: 5,
      riskMaxRate: 0.25,
      blitzMaxRate: 0.15,
      scoreBoostCardEnabled: false,
      scoreBoostSpawnRate: 0.04,
      scoreBoostCorrectAnswerCount: 3,
      scoreBoostValue: 2,
      scoreBoostMinGap: 8,
    );
  }

  factory MatchConfig.fromMap(Map<String, dynamic> map) {
    final defaults = MatchConfig.defaults();

    final legacyPassPenalty = (map['passComboPenalty'] as num?)?.toInt();

    bool parseBool(String key, bool defaultValue) {
      final value = map[key];
      if (value == null) return defaultValue;
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        if (normalized == 'true' || normalized == '1') return true;
        if (normalized == 'false' || normalized == '0') return false;
      }
      return defaultValue;
    }

    double parseDouble(String key, double defaultValue) {
      final value = map[key];
      if (value == null) return defaultValue;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? defaultValue;
      return defaultValue;
    }

    int parseInt(String key, int defaultValue) {
      final value = map[key];
      if (value == null) return defaultValue;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? defaultValue;
      return defaultValue;
    }

    return MatchConfig(
      riskCardEnabled:
          parseBool('riskCardEnabled', defaults.riskCardEnabled),
      riskSpawnRate:
          parseDouble('riskSpawnRate', defaults.riskSpawnRate),
      blitzEnabled: parseBool('blitzEnabled', defaults.blitzEnabled),
      blitzSpawnRate:
          parseDouble('blitzSpawnRate', defaults.blitzSpawnRate),
      passLimitEnabled:
          parseBool('passLimitEnabled', defaults.passLimitEnabled),
      maxPassCount:
          parseInt('maxPassCount', defaults.maxPassCount),
      normalPassComboPenalty: map.containsKey('normalPassComboPenalty')
          ? parseInt('normalPassComboPenalty', defaults.normalPassComboPenalty)
          : (legacyPassPenalty ?? defaults.normalPassComboPenalty),
      extraPassComboPenalty: parseInt(
          'extraPassComboPenalty', defaults.extraPassComboPenalty),
      darkCardEnabled:
          parseBool('darkCardEnabled', defaults.darkCardEnabled),
      reverseCardEnabled:
          parseBool('reverseCardEnabled', defaults.reverseCardEnabled),
      multiplierCardEnabled: parseBool(
          'multiplierCardEnabled', defaults.multiplierCardEnabled),
      curseCardEnabled:
          parseBool('curseCardEnabled', defaults.curseCardEnabled),
      adaptiveDirectorEnabled: parseBool(
          'adaptiveDirectorEnabled', defaults.adaptiveDirectorEnabled),
      riskMinGap:
          parseInt('riskMinGap', defaults.riskMinGap),
      blitzMinGap:
          parseInt('blitzMinGap', defaults.blitzMinGap),
      riskMaxRate:
          parseDouble('riskMaxRate', defaults.riskMaxRate),
      blitzMaxRate:
          parseDouble('blitzMaxRate', defaults.blitzMaxRate),
      scoreBoostCardEnabled: parseBool(
          'scoreBoostCardEnabled', defaults.scoreBoostCardEnabled),
      scoreBoostSpawnRate: parseDouble(
          'scoreBoostSpawnRate', defaults.scoreBoostSpawnRate),
      scoreBoostCorrectAnswerCount:
          parseInt('scoreBoostCorrectAnswerCount',
              defaults.scoreBoostCorrectAnswerCount),
      scoreBoostValue: parseInt('scoreBoostValue', defaults.scoreBoostValue),
      scoreBoostMinGap: parseInt(
          'scoreBoostMinGap', defaults.scoreBoostMinGap),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'riskCardEnabled': riskCardEnabled,
      'riskSpawnRate': riskSpawnRate,
      'blitzEnabled': blitzEnabled,
      'blitzSpawnRate': blitzSpawnRate,
      'passLimitEnabled': passLimitEnabled,
      'maxPassCount': maxPassCount,
      'normalPassComboPenalty': normalPassComboPenalty,
      'extraPassComboPenalty': extraPassComboPenalty,
      'darkCardEnabled': darkCardEnabled,
      'reverseCardEnabled': reverseCardEnabled,
      'multiplierCardEnabled': multiplierCardEnabled,
      'curseCardEnabled': curseCardEnabled,
      'adaptiveDirectorEnabled': adaptiveDirectorEnabled,
      'riskMinGap': riskMinGap,
      'blitzMinGap': blitzMinGap,
      'riskMaxRate': riskMaxRate,
      'blitzMaxRate': blitzMaxRate,
      'scoreBoostCardEnabled': scoreBoostCardEnabled,
      'scoreBoostSpawnRate': scoreBoostSpawnRate,
      'scoreBoostCorrectAnswerCount': scoreBoostCorrectAnswerCount,
      'scoreBoostValue': scoreBoostValue,
      'scoreBoostMinGap': scoreBoostMinGap,
    };
  }
}
