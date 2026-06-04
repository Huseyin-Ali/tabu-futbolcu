class MatchConfig {
  final bool riskCardEnabled;
  final double riskSpawnRate;
  final bool blitzEnabled;
  final double blitzSpawnRate;
  final bool passLimitEnabled;
  final int maxPassCount;
  final int passComboPenalty;
  final bool darkCardEnabled;
  final bool reverseCardEnabled;
  final bool multiplierCardEnabled;
  final bool curseCardEnabled;

  const MatchConfig({
    required this.riskCardEnabled,
    required this.riskSpawnRate,
    required this.blitzEnabled,
    required this.blitzSpawnRate,
    required this.passLimitEnabled,
    required this.maxPassCount,
    required this.passComboPenalty,
    required this.darkCardEnabled,
    required this.reverseCardEnabled,
    required this.multiplierCardEnabled,
    required this.curseCardEnabled,
  });

  factory MatchConfig.defaults() {
    return const MatchConfig(
      riskCardEnabled: true,
      riskSpawnRate: 0.10,
      blitzEnabled: true,
      blitzSpawnRate: 0.05,
      passLimitEnabled: false,
      maxPassCount: 3,
      passComboPenalty: 1,
      darkCardEnabled: false,
      reverseCardEnabled: false,
      multiplierCardEnabled: false,
      curseCardEnabled: false,
    );
  }

  factory MatchConfig.fromMap(Map<String, dynamic> map) {
    final defaults = MatchConfig.defaults();

    return MatchConfig(
      riskCardEnabled:
          map['riskCardEnabled'] as bool? ?? defaults.riskCardEnabled,
      riskSpawnRate:
          (map['riskSpawnRate'] as num?)?.toDouble() ?? defaults.riskSpawnRate,
      blitzEnabled: map['blitzEnabled'] as bool? ?? defaults.blitzEnabled,
      blitzSpawnRate: (map['blitzSpawnRate'] as num?)?.toDouble() ??
          defaults.blitzSpawnRate,
      passLimitEnabled:
          map['passLimitEnabled'] as bool? ?? defaults.passLimitEnabled,
      maxPassCount:
          (map['maxPassCount'] as num?)?.toInt() ?? defaults.maxPassCount,
      passComboPenalty: (map['passComboPenalty'] as num?)?.toInt() ??
          defaults.passComboPenalty,
      darkCardEnabled:
          map['darkCardEnabled'] as bool? ?? defaults.darkCardEnabled,
      reverseCardEnabled:
          map['reverseCardEnabled'] as bool? ?? defaults.reverseCardEnabled,
      multiplierCardEnabled: map['multiplierCardEnabled'] as bool? ??
          defaults.multiplierCardEnabled,
      curseCardEnabled:
          map['curseCardEnabled'] as bool? ?? defaults.curseCardEnabled,
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
      'passComboPenalty': passComboPenalty,
      'darkCardEnabled': darkCardEnabled,
      'reverseCardEnabled': reverseCardEnabled,
      'multiplierCardEnabled': multiplierCardEnabled,
      'curseCardEnabled': curseCardEnabled,
    };
  }
}
