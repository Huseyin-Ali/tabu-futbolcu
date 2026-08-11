import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../models/kariyer_futbolcu.dart';
import '../models/match_config.dart';
import '../services/analytics_service.dart';
import '../services/career_mode_service.dart';
import '../services/match_director_service.dart';
import '../storage/settings_storage.dart';
import '../utils/logger.dart';
import 'career_mode_result_screen.dart';
import 'welcome_screen.dart';

class CareerModeGameScreen extends StatefulWidget {
  final int sure;
  final String zorluk;
  final String koleksiyonTipi;

  const CareerModeGameScreen({
    super.key,
    required this.sure,
    required this.zorluk,
    this.koleksiyonTipi = 'karışık',
  });

  @override
  State<CareerModeGameScreen> createState() => _CareerModeGameScreenState();
}

class _CareerModeGameScreenState extends State<CareerModeGameScreen>
    with TickerProviderStateMixin {
  List<KariyerFutbolcu> _tumFutbolcular = [];
  final Set<String> _kullanilmisIdler = {};

  KariyerFutbolcu? _mevcutFutbolcu;

  late int _kalanSure;
  double _skor = 0.0;   // double: ipuçlu doğru +0.5, normal doğru +1
  int _dogruSayisi = 0;
  int _yanlisSayisi = 0;
  int _pasSayisi = 0;
  int _maxPasHakki = MatchConfig.defaults().maxPassCount;
  int _kalanPasHakki = MatchConfig.defaults().maxPassCount;

  // Combo sistemi
  int _comboCount = 0;
  int _maxCombo = 0;
  int _bonusScore = 0;
  bool _canKazanildi = false;

  // Adaptive Match Director sayaçları
  int _cardsSinceLastRisk = 0;
  int _cardsSinceLastBlitz = 0;
  int _wrongStreak = 0;

  // Can sistemi
  static const int _basLangicCan = 3;
  int _currentLives = _basLangicCan;

  // İpucu sistemi
  bool _oyunIpucuKullanildi = false;
  bool _kartIpucuAcik = false;
  String? _kartIpucuMetni;
  int _hintedCorrectCount = 0;

  // Risk animasyonları
  late AnimationController _popupEntryCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _shakeCtrl;
  late AnimationController _scoreFloatCtrl;
  late AnimationController _flashCtrl;
  // Blitz animasyonları
  late AnimationController _blitzIntroCtrl;  // intro banner (700ms)
  late AnimationController _blitzPulseCtrl;  // arka plan glow (900ms, repeat)

  late Animation<double> _popupScale;
  late Animation<double> _popupFade;
  late Animation<double> _pulseAnim;
  late Animation<double> _shakeAnim;
  late Animation<double> _scoreFloatFade;
  late Animation<Offset> _scoreFloatSlide;
  late Animation<double> _flashOpacity;
  late Animation<double> _blitzIntroScale;
  late Animation<double> _blitzIntroFade;
  late Animation<double> _blitzPulseAnim;

  String _floatingScoreText = '';
  bool _showFlash = false;
  bool _showBlitzIntro = false;

  AudioPlayer? _riskAudioPlayer;
  AudioPlayer? _blitzAudioPlayer;

  // Ses ayarı — Tabu ile ortak (AppConstants.keySesAcik).
  bool _sesAcik = true;

  // Blitz sistemi
  static const int _blitzDuration = 15;
  static const int _blitzBonus = 2;
  static const int _legacyBlitzCooldown = 10;

  bool _isBlitzMode = false;
  int _blitzRemainingSeconds = 0;
  int _lastBlitzTriggerIndex = -20;
  int _blitzTriggerCount = 0;
  int _blitzCorrectCount = 0;
  int _blitzBonusScore = 0;

  // Risk kartı sistemi
  bool _isRiskKarti = false;
  bool _riskKabulEdildi = false;
  bool _riskPopupGosteriliyor = false;
  int _kartIndex = 0;
  // İlk kart hiçbir zaman Risk olmamalı — bu, o korumayı uygular.
  bool _ilkKartGosterildi = false;
  int _lastRiskKartiIndex = -10;
  int _totalRiskCount = 0;
  int _acceptedRiskCount = 0;
  int _wonRiskCount = 0;
  int _lostRiskCount = 0;
  int _riskScoreGain = 0;
  int _riskScoreLoss = 0;

  // Çarpan Kartı (scoreBoost) sistemi
  bool _isScoreBoostKarti = false;
  bool _isScoreBoostActive = false;
  int _remainingScoreBoostCorrectAnswers = 0;
  int _cardsSinceLastScoreBoost = 0;

  String get _skorStr =>
      _skor % 1 == 0 ? '${_skor.toInt()}' : _skor.toStringAsFixed(1);

  MatchConfig get _matchConfig =>
      MatchDirectorService.currentConfig ?? MatchConfig.defaults();

  bool get _passLimitAktif => _matchConfig.passLimitEnabled;

  /// Zorluğa göre kaç üst üste doğruda +1 bonus verilir.
  int get _comboBonusThreshold {
    switch (widget.zorluk) {
      case 'kolay':
        return 6;
      case 'orta':
        return 5;
      case 'karisik':
      case 'karışık':
        return 4;
      case 'zor':
        return 3;
      case 'cok zor':
      case 'çok zor':
        return 3;
      default:
        return 4;
    }
  }

  /// Risk kartı ödül/ceza değerleri.
  ({int reward, int penalty}) get _riskValues {
    switch (widget.zorluk) {
      case 'kolay':      return (reward: 3, penalty: 1);
      case 'orta':       return (reward: 4, penalty: 1);
      case 'karisik':
      case 'karışık':    return (reward: 4, penalty: 2);
      case 'zor':        return (reward: 5, penalty: 2);
      case 'cok zor':
      case 'çok zor':    return (reward: 6, penalty: 2);
      default:           return (reward: 4, penalty: 1);
    }
  }

  Timer? _timer;
  bool _yukleniyor = true;
  bool _oyunBitti = false;
  bool _durduruldu = false;

  // career_game_finished'in oturum başına en fazla bir kez gönderilmesini
  // garanti eden ayrık guard (_oyunBitti'nin genel oyun state'inden bağımsız).
  bool _careerGameFinishedLogged = false;

  // Şık sistemi
  List<String> _mevcutSecenekler = [];
  String? _secilenSecenekIsim;

  // 'dogru' | 'dogru_bonus' | 'yanlis' | null — feedback state
  String? _geribildrim;
  String _dogruIsim = '';

  @override
  void initState() {
    super.initState();
    _kalanSure = widget.sure;
    _initRiskAnimations();
    _sesDurumunuYukle();
    _yukleFutbolcular();
  }

  Future<void> _sesDurumunuYukle() async {
    final acik = await SettingsStorage.getSesAcik();
    if (!mounted) return;
    setState(() {
      _sesAcik = acik;
    });
  }

  Future<void> _sesDurumunuDegistir() async {
    setState(() {
      _sesAcik = !_sesAcik;
    });
    await SettingsStorage.setSesAcik(_sesAcik);
    AnalyticsService.logAudioToggled(isSoundOn: _sesAcik);
  }

  void _initRiskAnimations() {
    _popupEntryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _popupScale = Tween<double>(begin: 0.82, end: 1.0).animate(
        CurvedAnimation(parent: _popupEntryCtrl, curve: Curves.easeOutBack));
    _popupFade = CurvedAnimation(
        parent: _popupEntryCtrl, curve: Curves.easeOut);

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 220));
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 7.0),  weight: 10),
      TweenSequenceItem(tween: Tween(begin: 7.0, end: -6.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 4.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 4.0, end: -3.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: -3.0, end: 0.0), weight: 30),
    ]).animate(_shakeCtrl);

    _scoreFloatCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 750));
    _scoreFloatFade = Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(
            parent: _scoreFloatCtrl,
            curve: const Interval(0.35, 1.0, curve: Curves.easeOut)));
    _scoreFloatSlide =
        Tween<Offset>(begin: Offset.zero, end: const Offset(0, -1.4)).animate(
            CurvedAnimation(parent: _scoreFloatCtrl, curve: Curves.easeOut));

    _flashCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _flashOpacity = Tween<double>(begin: 0.40, end: 0.0).animate(
        CurvedAnimation(parent: _flashCtrl, curve: Curves.easeOut));

    // Blitz intro banner animasyonu
    _blitzIntroCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));
    _blitzIntroScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.4, end: 1.1), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.1, end: 1.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.85), weight: 35),
    ]).animate(_blitzIntroCtrl);
    _blitzIntroFade = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 40),
    ]).animate(_blitzIntroCtrl);

    // Blitz arka plan pulse
    _blitzPulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _blitzPulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _blitzPulseCtrl, curve: Curves.easeInOut));
  }

  /// career_game_finished'i oturum başına en fazla bir kez gönderir
  /// ([_careerGameFinishedLogged] guard'ı). Oyun bittiğinde Blitz hâlâ
  /// aktifse doğal _endBlitzMode() hiç çalışmamış olur; bu durumda
  /// career_blitz_finished'i de burada (tek seferlik) tamamlıyoruz — oyun
  /// state'i (_isBlitzMode vb.) kasıtlı olarak değiştirilmiyor, yalnızca
  /// analytics event'i gönderiliyor.
  void _logCareerGameFinished(String gameResult) {
    if (_careerGameFinishedLogged) return;
    _careerGameFinishedLogged = true;

    if (_isBlitzMode) {
      AnalyticsService.logCareerBlitzFinished(
        difficulty: widget.zorluk,
        correctCountTotal: _blitzCorrectCount,
        bonusScoreTotal: _blitzBonusScore,
      );
    }

    AnalyticsService.logCareerGameFinished(
      difficulty: widget.zorluk,
      score: _skor.round(),
      durationSeconds: widget.sure - _kalanSure,
      correctAnswers: _dogruSayisi,
      wrongAnswers: _yanlisSayisi,
      passUsedCount: _pasSayisi,
      hintUsedCount: _oyunIpucuKullanildi ? 1 : 0,
      maxCombo: _maxCombo,
      gameResult: gameResult,
    );
  }

  @override
  void dispose() {
    if (_mevcutFutbolcu != null && !_careerGameFinishedLogged) {
      // Ekran oyun bitmeden kapandı (Ana Menü, Baştan Başlat veya geri
      // gezinme) — gerçek tetiklenme noktası bu, çünkü hepsi buradan geçer.
      _logCareerGameFinished('quit');
    }
    _timer?.cancel();
    _popupEntryCtrl.dispose();
    _pulseCtrl.dispose();
    _shakeCtrl.dispose();
    _scoreFloatCtrl.dispose();
    _flashCtrl.dispose();
    _blitzIntroCtrl.dispose();
    _blitzPulseCtrl.dispose();
    _riskAudioPlayer?.dispose();
    _blitzAudioPlayer?.dispose();
    super.dispose();
  }

  Future<void> _yukleFutbolcular() async {
    final results = await Future.wait([
      CareerModeService.getKariyerFutbolculari(
        zorluk: widget.zorluk,
        koleksiyonTipi: widget.koleksiyonTipi,
      ),
      MatchDirectorService.loadConfig(),
    ]);
    final liste = results[0] as List<KariyerFutbolcu>;

    if (!mounted) return;

    if (liste.isEmpty) {
      setState(() {
        _yukleniyor = false;
      });
      return;
    }

    final shuffled = List<KariyerFutbolcu>.from(liste)..shuffle(Random());
    final config = MatchDirectorService.currentConfig ?? MatchConfig.defaults();
    final maxPas = config.passLimitEnabled ? config.maxPassCount : 0;

    setState(() {
      _tumFutbolcular = shuffled;
      _maxPasHakki = maxPas;
      _kalanPasHakki = maxPas;
      _cardsSinceLastRisk = config.riskMinGap;
      _cardsSinceLastBlitz = config.blitzMinGap;
      _yukleniyor = false;
    });

    AnalyticsService.logCareerGameStarted(
      difficulty: widget.zorluk,
      collectionType: widget.koleksiyonTipi,
      durationLimit: widget.sure,
      passLimit: maxPas,
      startingLives: _currentLives,
    );

    _sonrakiKart();
    _timerBaslat();
  }

  void _timerBaslat() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_kalanSure > 0) {
          _kalanSure--;
          // Blitz geri sayım
          if (_isBlitzMode) {
            _blitzRemainingSeconds--;
            if (_blitzRemainingSeconds <= 0) {
              _endBlitzMode();
            }
          }
        } else {
          t.cancel();
          _oyunuBitir();
        }
      });
    });
  }

  void _startBlitzMode() {
    if (_isBlitzMode || _oyunBitti) return;
    _blitzTriggerCount++;
    _cardsSinceLastBlitz = 0;
    _lastBlitzTriggerIndex = _kartIndex;
    setState(() {
      _isBlitzMode = true;
      _blitzRemainingSeconds = _blitzDuration;
      _showBlitzIntro = true;
    });
    _blitzIntroCtrl.forward(from: 0.0).then((_) {
      if (mounted) setState(() => _showBlitzIntro = false);
    });
    _blitzPulseCtrl.repeat(reverse: true);
    _playBlitzSound();
    AnalyticsService.logCareerBlitzStarted(
      difficulty: widget.zorluk,
      comboAtTrigger: _comboCount,
      triggerCount: _blitzTriggerCount,
    );
    if (kDebugMode) {
      AppLogger.info(
        '[Blitz] BLITZ MODE başladı! combo: $_comboCount | '
        'trigger#: $_blitzTriggerCount',
      );
    }
  }

  void _endBlitzMode() {
    if (!_isBlitzMode) return;
    _blitzPulseCtrl.stop();
    _blitzPulseCtrl.reset();
    setState(() {
      _isBlitzMode = false;
      _blitzRemainingSeconds = 0;
    });
    AnalyticsService.logCareerBlitzFinished(
      difficulty: widget.zorluk,
      correctCountTotal: _blitzCorrectCount,
      bonusScoreTotal: _blitzBonusScore,
    );
    if (kDebugMode) {
      AppLogger.info(
        '[Blitz] Blitz bitti! doğru: $_blitzCorrectCount | '
        'bonus: $_blitzBonusScore',
      );
    }
  }

  void _playBlitzSound() async {
    if (!_sesAcik) return;
    try {
      _stopBlitzSound();
      _blitzAudioPlayer = AudioPlayer();
      await _blitzAudioPlayer!.play(
        AssetSource(AppConstants.soundBlitzStart),
        volume: AppConstants.soundBlitzVolume,
      );
    } catch (_) {}
  }

  /// Idempotent: `_blitzAudioPlayer` zaten null ise hiçbir şey yapmaz.
  /// `dispose()` içeride `release()` → `stop()` çağırır; burada ayrıca
  /// `stop()` da çağırmak aynı native player'a çakışan iki stop komutu
  /// gönderiyordu — bu, Blitz sesi aktifken restart sırasında native
  /// MediaPlayer'ın kilitlenip uygulamayı dondurmasına yol açıyordu
  /// ("stop called in state 1" / "error (-38, 0)"). Tek güvenli çağrı:
  /// yalnızca dispose(); hata olursa yutulur, çağıran akışı bloklamaz.
  void _stopBlitzSound() {
    final p = _blitzAudioPlayer;
    _blitzAudioPlayer = null;
    if (p == null) return;
    unawaited(p.dispose().catchError((_) {}));
  }

  /// Ekrandan gerçek çıkış noktalarının (oyun bitti / baştan başlat / ana
  /// menü) hepsinde çağrılır — hâlâ çalan Risk/Blitz ses ve animasyonlarının
  /// bir sonraki ekrana/oyuna sızmasını önler. Oyun state'ine (_isBlitzMode
  /// vb.) veya analytics'e dokunmaz.
  void _cikistaEfektleriDurdur() {
    _stopRiskSound();
    if (_isBlitzMode) {
      _blitzPulseCtrl.stop();
      _stopBlitzSound();
    }
  }

  bool _scoreBoostUygulanabilirMi() =>
      _isScoreBoostActive &&
      !_isBlitzMode &&
      !_kartIpucuAcik &&
      !_isRiskKarti &&
      !_isScoreBoostKarti;

  int _normalDogruPuan() =>
      _scoreBoostUygulanabilirMi() ? _matchConfig.scoreBoostValue : 1;

  void _scoreBoostTuket() {
    if (!_scoreBoostUygulanabilirMi()) return;

    _remainingScoreBoostCorrectAnswers--;
    if (_remainingScoreBoostCorrectAnswers <= 0) {
      _isScoreBoostActive = false;
      _remainingScoreBoostCorrectAnswers = 0;
      AppLogger.info('[ScoreBoost] Expired');
    } else {
      AppLogger.info(
        '[ScoreBoost] Applied | remaining=$_remainingScoreBoostCorrectAnswers',
      );
    }
  }

  void _scoreBoostAktifEt() {
    final config = _matchConfig;
    _isScoreBoostActive = true;
    _remainingScoreBoostCorrectAnswers = config.scoreBoostCorrectAnswerCount;
    AppLogger.info(
      '[ScoreBoost] Activated | nextCorrect=${config.scoreBoostCorrectAnswerCount} '
      '| value=${config.scoreBoostValue}',
    );
  }

  void _maybeTriggerBlitz({
    required bool wasRiskCard,
    required bool wasScoreBoostCard,
    required bool dogru,
  }) {
    if (_currentLives <= 0) return;
    if (wasRiskCard || wasScoreBoostCard || _kartIpucuAcik || _isBlitzMode) {
      return;
    }

    final config = _matchConfig;
    final bool shouldEvaluate;
    if (config.adaptiveDirectorEnabled) {
      // Adaptif: yanlış seride destek; doğru cevapta combo eşiği korunur
      shouldEvaluate = dogru ? _comboCount >= 5 : true;
    } else {
      shouldEvaluate = dogru && _comboCount >= 5;
    }

    if (!shouldEvaluate) return;

    final bool blitzTetiklensin;
    if (config.adaptiveDirectorEnabled) {
      blitzTetiklensin = MatchDirectorService.shouldSpawnBlitzAdaptive(
        currentCombo: _comboCount,
        wrongStreak: _wrongStreak,
        remainingLives: _currentLives,
        cardsSinceLastRisk: _cardsSinceLastRisk,
        cardsSinceLastBlitz: _cardsSinceLastBlitz,
      );
    } else {
      blitzTetiklensin = (_kartIndex - _lastBlitzTriggerIndex) >=
              _legacyBlitzCooldown &&
          MatchDirectorService.shouldSpawnBlitz();
    }

    if (!blitzTetiklensin) return;

    Future.delayed(const Duration(milliseconds: 960), () {
      if (mounted && !_oyunBitti) _startBlitzMode();
    });
    if (kDebugMode) {
      AppLogger.info(
        '[Blitz] Blitz tetiklendi! combo: $_comboCount | '
        'wrongStreak: $_wrongStreak',
      );
    }
  }

  void _sonrakiKart() {
    var musait = _tumFutbolcular
        .where((f) => !_kullanilmisIdler.contains(f.id))
        .toList();

    // Tüm kartlar gösterildi — yeniden başla, oyun süre bitince biter.
    if (musait.isEmpty) {
      _kullanilmisIdler.clear();
      musait = List<KariyerFutbolcu>.from(_tumFutbolcular)..shuffle(Random());
    }

    // Tam 4 benzersiz şıklı (1 doğru + 3 kariyer-yolu-benzersiz yanlış)
    // bir doğru oyuncu bulana kadar sırayla dener (bkz.
    // CareerModeService.pickCardWithValidChoices — havuzdaki uygun
    // adayların TAMAMI, her biri en fazla bir kez denenir; sabit bir "20
    // deneme" tavanı yoktur, üst sınır zaten havuzdaki benzersiz aday
    // sayısıdır, bu yüzden sonsuz döngü oluşamaz). İlk sırada denenen
    // aday, önceki davranışla tutarlı biçimde rastgele seçilen "tercih
    // edilen" adaydır (shuffle sonrası ilk eleman); bulunamazsa sıradaki
    // adaylara geçilir. Hiçbir aday 4 şık üretemezse eksik şıklı bir kart
    // ASLA gösterilmez; oyun güvenle sonlandırılır.
    final denemeSirasi = List<KariyerFutbolcu>.from(musait)..shuffle(Random());

    final sonuc = CareerModeService.pickCardWithValidChoices(
      adaylar: denemeSirasi,
      tumListe: _tumFutbolcular,
    );

    if (sonuc == null) {
      // Havuzdaki bütün uygun adaylar birer kez denendi, hiçbiri 4
      // benzersiz şıklı geçerli bir kart üretemedi — eksik şıklı kart
      // göstermek yerine akışı güvenle sonlandır (dondurma/setState
      // döngüsü yok, _oyunuBitir zaten idempotent).
      AppLogger.warning(
        '[CareerMode] ${denemeSirasi.length} adayın tamamı denendi, 4 '
        'benzersiz şıklı kart bulunamadı — oyun güvenli şekilde '
        'sonlandırılıyor',
      );
      if (mounted && !_oyunBitti) _oyunuBitir();
      return;
    }

    final secilenOyuncu = sonuc.dogru;
    final secenekler = sonuc.secenekler;

    _kartIndex++;

    final config = _matchConfig;

    // İlk kart hiçbir zaman Risk olmamalı; bayrağı bu kart için tüket.
    final bool ilkKart = !_ilkKartGosterildi;
    _ilkKartGosterildi = true;

    // Yeni kart gap sayaçları (adaptif mod)
    if (config.adaptiveDirectorEnabled) {
      _cardsSinceLastRisk++;
      _cardsSinceLastBlitz++;
      _cardsSinceLastScoreBoost++;
    }

    // Risk kartı kararı: adaptif veya legacy spawn (öncelik 1)
    final bool riskOlsun;
    if (ilkKart) {
      // İlk karttaki Risk olasılığını/gap sayaçlarını değiştirmeden,
      // yalnızca bu kart için Risk kartı seçimini devre dışı bırak.
      riskOlsun = false;
    } else if (config.adaptiveDirectorEnabled) {
      riskOlsun = MatchDirectorService.shouldSpawnRiskCardAdaptive(
        currentCombo: _comboCount,
        wrongStreak: _wrongStreak,
        remainingLives: _currentLives,
        cardsSinceLastRisk: _cardsSinceLastRisk,
        cardsSinceLastBlitz: _cardsSinceLastBlitz,
      );
      if (riskOlsun) {
        _cardsSinceLastRisk = 0;
      }
    } else {
      final riskMumkun = _kartIndex >= 5 &&
          (_kartIndex - _lastRiskKartiIndex) >= 5;
      riskOlsun = riskMumkun && MatchDirectorService.shouldSpawnRiskCard();
      if (riskOlsun) {
        _lastRiskKartiIndex = _kartIndex;
      } else {
        _cardsSinceLastScoreBoost++;
      }
    }

    // Çarpan Kartı kararı: risk yoksa ve blitz modunda değilse (öncelik 3)
    bool scoreBoostOlsun = false;
    if (!riskOlsun && !_isBlitzMode && config.scoreBoostCardEnabled) {
      if (config.adaptiveDirectorEnabled) {
        scoreBoostOlsun =
            MatchDirectorService.shouldSpawnScoreBoostCardAdaptive(
          currentCombo: _comboCount,
          wrongStreak: _wrongStreak,
          remainingLives: _currentLives,
          cardsSinceLastScoreBoost: _cardsSinceLastScoreBoost,
          isScoreBoostActive: _isScoreBoostActive,
        );
      } else if (!_isScoreBoostActive &&
          _cardsSinceLastScoreBoost >= config.scoreBoostMinGap) {
        scoreBoostOlsun = MatchDirectorService.shouldSpawnScoreBoostCard();
      }

      if (scoreBoostOlsun) {
        _cardsSinceLastScoreBoost = 0;
      }
    }

    if (riskOlsun) {
      _totalRiskCount++;
      final rv = _riskValues;
      if (kDebugMode) {
        AppLogger.info(
          '[Risk] Risk kartı oluştu! kart#: $_kartIndex | '
          'zorluk: ${secilenOyuncu.zorluk} | '
          '+${rv.reward} / -${rv.penalty}',
        );
      }
      AnalyticsService.logCareerRiskCardShown(
        difficulty: secilenOyuncu.zorluk,
        cardIndex: _kartIndex,
        reward: rv.reward,
        penalty: rv.penalty,
      );
    }
    if (riskOlsun) {
      // Animasyonları setState'den sonra tetikle
      WidgetsBinding.instance.addPostFrameCallback((_) => _onRiskKartiGeldi());
    }

    setState(() {
      _mevcutFutbolcu = secilenOyuncu;
      _kullanilmisIdler.add(secilenOyuncu.id);
      _geribildrim = null;
      _secilenSecenekIsim = null;
      _dogruIsim = '';
      _kartIpucuAcik = false;
      _kartIpucuMetni = null;
      _isRiskKarti = riskOlsun;
      _isScoreBoostKarti = scoreBoostOlsun;
      _riskKabulEdildi = false;
      _riskPopupGosteriliyor = riskOlsun;
      _mevcutSecenekler = secenekler;
    });

    AnalyticsService.logCareerCardShown(
      difficulty: secilenOyuncu.zorluk,
      cardIndex: _kartIndex,
      isRiskCard: riskOlsun,
      isScoreBoostCard: scoreBoostOlsun,
      isBlitzActive: _isBlitzMode,
    );
  }

  void _secenekSec(String isim) {
    if (_mevcutFutbolcu == null || _geribildrim != null) return;

    final dogru = isim == _mevcutFutbolcu!.isim;

    // Risk flag'ini şimdi yakala (Future.delayed'de kullanmak için)
    final bool wasRiskCard = _riskKabulEdildi;
    final bool wasScoreBoostCard = _isScoreBoostKarti;
    final int livesBefore = _currentLives;
    final int comboBefore = _comboCount;

    setState(() {
      _secilenSecenekIsim = isim;
      _dogruIsim = _mevcutFutbolcu!.isim;

      if (_riskKabulEdildi) {
        // ══ Risk kartı cevabı ═════════════════════════════════════════════
        final rv = _riskValues;
        if (dogru) {
          _dogruSayisi++;
          _skor += rv.reward;
          _wonRiskCount++;
          _riskScoreGain += rv.reward;
          _wrongStreak = 0;
          // Combo normal artar + bonus sistemi çalışır
          _comboCount++;
          if (_comboCount > _maxCombo) _maxCombo = _comboCount;
          final threshold = _comboBonusThreshold;
          final isBonus = _comboCount % threshold == 0;
          if (isBonus) {
            _skor += 1;
            _bonusScore++;
            _currentLives++;
            _canKazanildi = true;
            _geribildrim = 'dogru_risk_bonus';
            Future.delayed(const Duration(milliseconds: 1400), () {
              if (mounted) setState(() => _canKazanildi = false);
            });
          } else {
            _geribildrim = 'dogru_risk';
          }
          if (kDebugMode) {
            AppLogger.info(
              '[Risk] Doğru! +${rv.reward} puan | '
              'combo: $_comboCount/$threshold | skor: $_skorStr',
            );
          }
          // Floating score animasyonu
          WidgetsBinding.instance.addPostFrameCallback(
              (_) => _triggerFloatingScore('+${rv.reward}'));
        } else {
          _yanlisSayisi++;
          _lostRiskCount++;
          _skor -= rv.penalty;
          _riskScoreLoss += rv.penalty;
          _comboCount = 0; // combo sıfırla, CAN GİTMEZ
          _wrongStreak++;
          _geribildrim = 'yanlis_risk';
          if (kDebugMode) {
            AppLogger.info(
              '[Risk] Yanlış! -${rv.penalty} puan | '
              'skor: $_skorStr | combo sıfırlandı | can DEĞİŞMEDİ',
            );
          }
          // Kırmızı flash
          WidgetsBinding.instance.addPostFrameCallback(
              (_) => _triggerRedFlash());
        }
      } else if (wasScoreBoostCard) {
        // ══ Çarpan Kartı cevabı ═══════════════════════════════════════════
        if (dogru) {
          _dogruSayisi++;
          if (_kartIpucuAcik) {
            _skor += 0.5;
            _hintedCorrectCount++;
            _wrongStreak = 0;
            _geribildrim = 'dogru_ipucu';
          } else {
            _skor += 1;
            _wrongStreak = 0;
            _comboCount++;
            if (_comboCount > _maxCombo) _maxCombo = _comboCount;
            final threshold = _comboBonusThreshold;
            final isBonus = _comboCount % threshold == 0;
            if (isBonus) {
              _skor += 1;
              _bonusScore++;
              _currentLives++;
              _canKazanildi = true;
              _geribildrim = 'dogru_score_boost_card_bonus';
              Future.delayed(const Duration(milliseconds: 1400), () {
                if (mounted) setState(() => _canKazanildi = false);
              });
            } else {
              _geribildrim = 'dogru_score_boost_card';
            }
            _scoreBoostAktifEt();
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _triggerFloatingScore('+1'),
            );
          }
        } else {
          _yanlisSayisi++;
          _comboCount = 0;
          _wrongStreak++;
          _currentLives--;
          _geribildrim = 'yanlis';
        }
      } else if (dogru) {
        // ══ Normal / ipuçlu doğru ═════════════════════════════════════════
        _dogruSayisi++;
        if (_kartIpucuAcik) {
          _skor += 0.5;
          _hintedCorrectCount++;
          _wrongStreak = 0;
          _geribildrim = 'dogru_ipucu';
          if (kDebugMode) {
            AppLogger.info(
              '[Hint] İpuçlu doğru → +0.5 | combo etkilenmedi ($_comboCount)',
            );
          }
        } else {
          final normalPuan = _normalDogruPuan();
          _skor += normalPuan;
          _wrongStreak = 0;
          if (_scoreBoostUygulanabilirMi()) {
            _scoreBoostTuket();
          }
          // Blitz bonusu
          if (_isBlitzMode) {
            _skor += _blitzBonus;
            _blitzCorrectCount++;
            _blitzBonusScore += _blitzBonus;
          }
          _comboCount++;
          if (_comboCount > _maxCombo) _maxCombo = _comboCount;
          final threshold = _comboBonusThreshold;
          final isBonus = _comboCount % threshold == 0;
          if (isBonus) {
            _skor += 1;
            _bonusScore++;
            _currentLives++;
            _canKazanildi = true;
            if (_isBlitzMode) {
              _geribildrim = 'dogru_blitz_bonus';
            } else if (normalPuan > 1) {
              _geribildrim = 'dogru_score_boost_bonus';
            } else {
              _geribildrim = 'dogru_bonus';
            }
            Future.delayed(const Duration(milliseconds: 1400), () {
              if (mounted) setState(() => _canKazanildi = false);
            });
            if (kDebugMode) {
              AppLogger.info(
                '[Combo] BONUS +1 (eşik: $threshold) → '
                'bonusScore: $_bonusScore | can: $_currentLives',
              );
            }
          } else {
            if (_isBlitzMode) {
              _geribildrim = 'dogru_blitz';
            } else if (normalPuan > 1) {
              _geribildrim = 'dogru_score_boost';
            } else {
              _geribildrim = 'dogru';
            }
          }
          if (kDebugMode) {
            AppLogger.info(
              '[Combo] combo: $_comboCount/$threshold | maxCombo: $_maxCombo'
              '${_isBlitzMode ? ' | ⚡ BLITZ +$_blitzBonus' : ''}'
              '${normalPuan > 1 ? ' | ⭐ SCORE BOOST +$normalPuan' : ''}',
            );
          }
          if (_isBlitzMode) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _triggerFloatingScore('⚡+${1 + _blitzBonus}'),
            );
          } else if (normalPuan > 1) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _triggerFloatingScore('⭐+$normalPuan'),
            );
          }
        }
      } else {
        // ══ Normal yanlış (can gider) ══════════════════════════════════════
        _yanlisSayisi++;
        _comboCount = 0;
        _wrongStreak++;
        _currentLives--;
        _geribildrim = 'yanlis';
        if (kDebugMode) {
          AppLogger.info('[Lives] can azaldı → kalan: $_currentLives');
          AppLogger.info('[Combo] combo sıfırlandı');
        }
      }
    });

    if (dogru) {
      AnalyticsService.logCareerAnswerCorrect(
        difficulty: widget.zorluk,
        combo: _comboCount,
        currentLives: _currentLives,
        isRiskCard: wasRiskCard,
        isScoreBoostCard: wasScoreBoostCard,
        isHintUsed: _kartIpucuAcik,
      );
      if (_comboCount > comboBefore &&
          _comboCount % _comboBonusThreshold == 0) {
        AnalyticsService.logCareerComboReached(
          difficulty: widget.zorluk,
          combo: _comboCount,
          threshold: _comboBonusThreshold,
        );
      }
    } else {
      AnalyticsService.logCareerAnswerWrong(
        difficulty: widget.zorluk,
        currentLives: _currentLives,
        isRiskCard: wasRiskCard,
        isScoreBoostCard: wasScoreBoostCard,
        isHintUsed: _kartIpucuAcik,
      );
    }

    if (_currentLives > livesBefore) {
      AnalyticsService.logCareerLifeGained(
        difficulty: widget.zorluk,
        currentLives: _currentLives,
        source: 'combo_bonus',
      );
    } else if (_currentLives < livesBefore) {
      AnalyticsService.logCareerLifeLost(
        difficulty: widget.zorluk,
        currentLives: _currentLives,
        source: wasScoreBoostCard ? 'score_boost_card_wrong' : 'normal_wrong',
      );
    }

    if (!wasRiskCard && _currentLives <= 0) {
      if (kDebugMode) AppLogger.info('[Game] Can bitti → oyun sona eriyor');
      Future.delayed(const Duration(milliseconds: 1300), () {
        if (!mounted || _oyunBitti) return;
        _oyunuBitir();
      });
      return;
    }

    if (_currentLives > 0) {
      _maybeTriggerBlitz(
        wasRiskCard: wasRiskCard,
        wasScoreBoostCard: wasScoreBoostCard,
        dogru: dogru,
      );
    }

    final delay = dogru ? 900 : 1300;
    Future.delayed(Duration(milliseconds: delay), () {
      if (!mounted || _oyunBitti) return;
      if (wasRiskCard) _stopRiskSound();
      _sonrakiKart();
    });
  }

  void _onRiskKartiGeldi() {
    _popupEntryCtrl.forward(from: 0.0);
    _pulseCtrl.repeat(reverse: true);
    _shakeCtrl.forward(from: 0.0);
    _playRiskSound();
  }

  /// Idempotent — bkz. [_stopBlitzSound] (aynı çakışan çift-stop riski
  /// burada da vardı, aynı sebeple tek `dispose()` çağrısına indirildi).
  void _stopRiskSound() {
    final p = _riskAudioPlayer;
    _riskAudioPlayer = null;
    if (p == null) return;
    unawaited(p.dispose().catchError((_) {}));
  }

  void _playRiskSound() async {
    if (!_sesAcik) return;
    try {
      _stopRiskSound();
      final player = AudioPlayer();
      _riskAudioPlayer = player;
      await player.setReleaseMode(ReleaseMode.loop);
      await player.play(
        AssetSource(AppConstants.soundRisk),
        volume: AppConstants.soundRiskVolume,
      );
    } catch (_) {}
  }

  void _stopRiskAnimations() {
    _pulseCtrl.stop();
    _pulseCtrl.reset();
  }

  void _triggerFloatingScore(String text) {
    setState(() => _floatingScoreText = text);
    _scoreFloatCtrl.forward(from: 0.0).then((_) {
      if (mounted) setState(() => _floatingScoreText = '');
    });
  }

  void _triggerRedFlash() {
    setState(() => _showFlash = true);
    _flashCtrl.forward(from: 0.0).then((_) {
      if (mounted) setState(() => _showFlash = false);
    });
  }

  void _riskKabul() {
    if (!_riskPopupGosteriliyor) return;
    _stopRiskAnimations();
    setState(() {
      _riskPopupGosteriliyor = false;
      _riskKabulEdildi = true;
      _acceptedRiskCount++;
    });
    AnalyticsService.logCareerRiskCardAccepted(difficulty: widget.zorluk);
    if (kDebugMode) AppLogger.info('[Risk] Kullanıcı kabul etti');
  }

  void _riskPasGec() {
    if (!_riskPopupGosteriliyor) return;
    _stopRiskSound();
    _stopRiskAnimations();
    if (kDebugMode) AppLogger.info('[Risk] Kullanıcı pas geçti');
    setState(() {
      _riskPopupGosteriliyor = false;
      _isRiskKarti = false;
      _riskKabulEdildi = false;
    });
    AnalyticsService.logCareerRiskCardRejected(difficulty: widget.zorluk);
    _sonrakiKart();
  }

  void _pas() {
    if (_mevcutFutbolcu == null || _geribildrim != null) return;

    final config = _matchConfig;
    final limitEnabled = config.passLimitEnabled;
    final isExtraPass = limitEnabled && _kalanPasHakki <= 0;
    final penalty = isExtraPass
        ? config.extraPassComboPenalty
        : config.normalPassComboPenalty;
    final oldCombo = _comboCount;
    final newCombo = max(0, oldCombo - penalty);

    setState(() {
      _pasSayisi++;
      if (limitEnabled && _kalanPasHakki > 0) {
        _kalanPasHakki--;
      }
      _comboCount = newCombo;
    });

    AnalyticsService.logCareerPassUsed(
      difficulty: widget.zorluk,
      remainingPassCount: _kalanPasHakki,
      isExtraPass: isExtraPass,
      comboAfter: newCombo,
    );

    if (kDebugMode) {
      if (isExtraPass) {
        AppLogger.info(
          '[Pass] Extra pass used | combo $oldCombo -> $newCombo',
        );
      } else {
        AppLogger.info(
          '[Pass] Normal pass used | combo $oldCombo -> $newCombo',
        );
      }
    }

    _sonrakiKart();
  }

  void _oyunuBitir() {
    if (_oyunBitti) return;
    // _isBlitzMode kasıtlı olarak değiştirilmiyor — career_blitz_finished
    // event'i zaten _logCareerGameFinished() içinde tek seferlik gönderiliyor.
    _cikistaEfektleriDurdur();
    _timer?.cancel();
    setState(() => _oyunBitti = true);

    _logCareerGameFinished(_currentLives <= 0 ? 'lose' : 'timeout');

    if (kDebugMode) {
      final neden = _currentLives <= 0 ? 'Can bitti' : 'Süre bitti';
      AppLogger.info(
        '[Game] Oyun bitti ($neden) — '
        'skor: $_skorStr | maxCombo: $_maxCombo | '
        'bonus: $_bonusScore | kalanCan: $_currentLives | '
        'ipucu: $_oyunIpucuKullanildi | ipuçlu doğru: $_hintedCorrectCount',
      );
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => CareerModeResultScreen(
          skor: _skor.round(),
          dogruSayisi: _dogruSayisi,
          yanlisSayisi: _yanlisSayisi,
          pasSayisi: _pasSayisi,
          sure: widget.sure,
          zorluk: widget.zorluk,
          maxCombo: _maxCombo,
          bonusScore: _bonusScore,
          remainingLives: _currentLives.clamp(0, _basLangicCan),
          usedHintCount: _oyunIpucuKullanildi ? 1 : 0,
          hintedCorrectCount: _hintedCorrectCount,
          totalRiskCount: _totalRiskCount,
          acceptedRiskCount: _acceptedRiskCount,
          wonRiskCount: _wonRiskCount,
          lostRiskCount: _lostRiskCount,
          riskScoreGain: _riskScoreGain,
          riskScoreLoss: _riskScoreLoss,
          blitzTriggerCount: _blitzTriggerCount,
          blitzCorrectCount: _blitzCorrectCount,
          blitzBonusScore: _blitzBonusScore,
        ),
      ),
    );
  }

  void _duraklat() {
    if (_oyunBitti || _durduruldu) return;
    _timer?.cancel();
    setState(() => _durduruldu = true);
  }

  void _devamEt() {
    if (!_durduruldu) return;
    setState(() => _durduruldu = false);
    _timerBaslat();
  }

  void _basdanBaslat() {
    _timer?.cancel();
    _cikistaEfektleriDurdur();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => CareerModeGameScreen(
          sure: widget.sure,
          zorluk: widget.zorluk,
          koleksiyonTipi: widget.koleksiyonTipi,
        ),
      ),
    );
  }

  void _anaMenuye() {
    _timer?.cancel();
    _cikistaEfektleriDurdur();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  Color get _timerColor {
    if (_isBlitzMode) return const Color(0xFF00E5FF); // cyan blitz
    if (_isRiskKarti && _riskKabulEdildi && _geribildrim == null) {
      return Colors.orangeAccent; // risk
    }
    final ratio = _kalanSure / widget.sure;
    if (ratio > 0.5) return Colors.greenAccent;
    if (ratio > 0.25) return Colors.orange;
    return Colors.redAccent;
  }

  Color _difficultyColor(String z) {
    switch (z) {
      case 'kolay':
        return Colors.green;
      case 'orta':
        return Colors.orange;
      case 'zor':
        return Colors.red;
      default:
        return Colors.purpleAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_yukleniyor) {
      return const Scaffold(
        backgroundColor: Colors.black87,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Futbolcular yükleniyor...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    if (_tumFutbolcular.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black87,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.search_off, color: Colors.white54, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Seçilen ayarlar için kariyer yolu olan\nfutbolcu bulunamadı.',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Geri Dön'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              AppConstants.assetDuvarKagidi,
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.6)),
          ),
          // Blitz arka plan glow (hafif cyan pulse)
          if (_isBlitzMode)
            AnimatedBuilder(
              animation: _blitzPulseCtrl,
              builder: (_, __) => Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.topCenter,
                        radius: 1.4,
                        colors: [
                          const Color(0xFF00E5FF)
                              .withOpacity(0.04 + _blitzPulseAnim.value * 0.05),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // Kırmızı flash overlay
          if (_showFlash)
            AnimatedBuilder(
              animation: _flashCtrl,
              builder: (_, __) => Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    color: Colors.red.withOpacity(_flashOpacity.value),
                  ),
                ),
              ),
            ),
          // Screen shake wrapper
          AnimatedBuilder(
            animation: _shakeCtrl,
            builder: (_, child) => Transform.translate(
              offset: Offset(_shakeAnim.value, 0),
              child: child,
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _buildTopBar(),
                  Expanded(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      child: Column(
                        children: [
                          _buildKariyerKart(),
                          const SizedBox(height: 8),
                          _buildIpucuAlani(),
                          const SizedBox(height: 10),
                          _buildSeceneklerGrid(),
                          const SizedBox(height: 10),
                          _buildPasButonu(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Floating score (+N)
          if (_floatingScoreText.isNotEmpty) _buildFloatingScore(),
          // Blitz intro banner
          if (_showBlitzIntro) _buildBlitzIntro(),
          // Risk kartı popup
          if (_riskPopupGosteriliyor) _buildRiskPopup(),
          // Pause overlay
          if (_durduruldu) _buildPauseOverlay(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // ── Satır 1: Pause | Ses | Süre | Skor
          Row(
            children: [
              GestureDetector(
                onTap: _duraklat,
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.3), width: 1.5),
                  ),
                  child: const Icon(Icons.pause_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _sesDurumunuDegistir,
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.3), width: 1.5),
                  ),
                  child: Icon(
                    _sesAcik ? Icons.volume_up : Icons.volume_off,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _statPill(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timer, color: _timerColor, size: 15),
                    const SizedBox(width: 4),
                    Text(
                      '$_kalanSure',
                      style: TextStyle(
                        color: _timerColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                borderColor: _timerColor,
              ),
              const Spacer(),
              _statPill(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, color: Colors.yellowAccent, size: 15),
                    const SizedBox(width: 4),
                    Text(
                      _skorStr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          // ── Satır 2: Can | Blitz | ScoreBoost | Combo
          Row(
            children: [
              _buildLivesRow(),
              const Spacer(),
              if (_isBlitzMode) _buildBlitzCountdown(),
              if (_isScoreBoostActive &&
                  _remainingScoreBoostCorrectAnswers > 0)
                _buildScoreBoostBadge(),
              const Spacer(),
              _buildComboBadge(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLivesRow() {
    // Kalp sayısı: en fazla _basLangicCan göster, fazlasını + badge ile belirt
    final displayCount = _currentLives.clamp(0, _basLangicCan);
    final overflow = _currentLives > _basLangicCan
        ? _currentLives - _basLangicCan
        : 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Kalpler
        ...List.generate(_basLangicCan, (i) {
          final dolu = i < displayCount;
          return Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Icon(
              dolu ? Icons.favorite : Icons.favorite_border,
              color: dolu ? Colors.redAccent : Colors.white24,
              size: 18,
              shadows: dolu
                  ? const [Shadow(color: Colors.red, blurRadius: 8)]
                  : null,
            ),
          );
        }),
        // Fazla can varsa "+N" badge
        if (overflow > 0)
          Padding(
            padding: const EdgeInsets.only(left: 2, right: 4),
            child: Text(
              '+$overflow',
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        // "+1 ❤️" can kazanma göstergesi
        AnimatedOpacity(
          opacity: _canKazanildi ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF00C853).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF00C853).withOpacity(0.6), width: 1),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x4400C853), blurRadius: 8, spreadRadius: -2),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '+1',
                  style: TextStyle(
                    color: Color(0xFF00E676),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 2),
                Icon(Icons.favorite, color: Color(0xFF00E676), size: 12),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScoreBoostBadge() {
    const color = Color(0xFFFFD54F);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: _statPill(
        borderColor: color,
        child: Text(
          'x${_matchConfig.scoreBoostValue} aktif: '
          '$_remainingScoreBoostCorrectAnswers doğru kaldı',
          style: const TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildComboBadge() {
    if (_comboCount == 0) {
      return const SizedBox.shrink();
    }
    final threshold = _comboBonusThreshold;
    // Bir sonraki bonusa kalan adım (0 = tam üstünde — anlık bonus verildi)
    final progress = _comboCount % threshold == 0
        ? threshold
        : _comboCount % threshold;

    Color color;
    if (progress >= threshold) {
      color = Colors.purpleAccent; // bonus tam eşikte
    } else if (progress >= threshold * 0.6) {
      color = Colors.orangeAccent; // yaklaşıyor
    } else {
      color = Colors.white70;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5), width: 1),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.25), blurRadius: 8, spreadRadius: -2),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 3),
          Text(
            '$progress/$threshold',
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statPill({required Widget child, Color? borderColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: borderColor ?? Colors.white.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: child,
    );
  }

  Widget _buildKariyerKart() {
    final futbolcu = _mevcutFutbolcu;
    if (futbolcu == null) return const SizedBox.shrink();

    final bool isRiskAktif = _isRiskKarti && _riskKabulEdildi;
    final bool isScoreBoostKart = _isScoreBoostKarti;
    Color borderColor = isRiskAktif
        ? Colors.orangeAccent.withOpacity(0.6)
        : isScoreBoostKart
            ? const Color(0xFFFFD54F).withOpacity(0.6)
            : Colors.white.withOpacity(0.4);
    if (_geribildrim == 'dogru' ||
        _geribildrim == 'dogru_bonus' ||
        _geribildrim == 'dogru_ipucu' ||
        _geribildrim == 'dogru_risk' ||
        _geribildrim == 'dogru_risk_bonus' ||
        _geribildrim == 'dogru_blitz' ||
        _geribildrim == 'dogru_blitz_bonus' ||
        _geribildrim == 'dogru_score_boost' ||
        _geribildrim == 'dogru_score_boost_bonus' ||
        _geribildrim == 'dogru_score_boost_card' ||
        _geribildrim == 'dogru_score_boost_card_bonus') {
      borderColor = Colors.greenAccent;
    }
    if (_geribildrim == 'yanlis') borderColor = Colors.redAccent;
    if (_geribildrim == 'yanlis_risk') borderColor = Colors.orangeAccent;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
          width: _geribildrim != null ? 2.5 : 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Kart başlığı
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isScoreBoostKart ? '⭐ ÇARPAN KARTI' : 'KARİYER YOLU',
                style: TextStyle(
                  color: isScoreBoostKart
                      ? const Color(0xFFFFD54F)
                      : Colors.white60,
                  fontSize: 12,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  // Risk badge
                  if (isRiskAktif) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: Colors.orangeAccent, width: 1),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x44FF9800),
                              blurRadius: 8,
                              spreadRadius: -2)
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('⚡', style: TextStyle(fontSize: 9)),
                          SizedBox(width: 3),
                          Text(
                            'RISK',
                            style: TextStyle(
                              color: Colors.orangeAccent,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (isScoreBoostKart) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD54F).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: const Color(0xFFFFD54F), width: 1),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('⭐', style: TextStyle(fontSize: 9)),
                          SizedBox(width: 3),
                          Text(
                            'BOOST',
                            style: TextStyle(
                              color: Color(0xFFFFD54F),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  // Zorluk badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _difficultyColor(futbolcu.zorluk)
                          .withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _difficultyColor(futbolcu.zorluk),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      futbolcu.zorluk.toUpperCase(),
                      style: TextStyle(
                        color: _difficultyColor(futbolcu.zorluk),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (isScoreBoostKart) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD54F).withOpacity(0.10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFFFFD54F).withOpacity(0.35)),
              ),
              child: Text(
                'Bu kartı bilirsen sonraki '
                '${_matchConfig.scoreBoostCorrectAnswerCount} normal doğru cevap '
                'x${_matchConfig.scoreBoostValue} puan!',
                style: const TextStyle(
                  color: Color(0xFFFFECB3),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          const SizedBox(height: 14),
          // Kariyer adımları
          ...List.generate(futbolcu.kariyerYolu.length, (i) {
            final isLast = i == futbolcu.kariyerYolu.length - 1;
            return Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      vertical: 9, horizontal: 14),
                  decoration: BoxDecoration(
                    color: isRiskAktif
                        ? Colors.deepOrange.withOpacity(0.13)
                        : isScoreBoostKart
                            ? const Color(0xFFFFD54F).withOpacity(0.08)
                            : Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(8),
                    border: isRiskAktif
                        ? Border.all(
                            color: Colors.orangeAccent.withOpacity(0.25),
                            width: 1)
                        : isScoreBoostKart
                            ? Border.all(
                                color:
                                    const Color(0xFFFFD54F).withOpacity(0.25),
                                width: 1)
                            : null,
                  ),
                  child: Text(
                    futbolcu.kariyerYolu[i],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                if (!isLast) ...[
                  const SizedBox(height: 3),
                  const Icon(
                    Icons.arrow_downward,
                    color: Colors.white38,
                    size: 14,
                  ),
                  const SizedBox(height: 3),
                ],
              ],
            );
          }),
          // Feedback satırı
          if (_geribildrim != null) ...[
            const SizedBox(height: 10),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 8),
            if (_geribildrim == 'dogru')
              const Text(
                '✓  Doğru!',
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              )
            else if (_geribildrim == 'dogru_blitz')
              Text(
                '⚡  Doğru!  +${1 + _blitzBonus} Blitz Bonus',
                style: const TextStyle(
                  color: Color(0xFF00E5FF),
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              )
            else if (_geribildrim == 'dogru_blitz_bonus')
              Text(
                '⚡  Doğru!  +${1 + _blitzBonus}  🔥  +1 Combo Bonus',
                style: const TextStyle(
                  color: Color(0xFF00E5FF),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              )
            else if (_geribildrim == 'dogru_bonus')
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '✓  Doğru!',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('🔥', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                  Text(
                    'COMBO BONUS +1  (x$_comboBonusThreshold)',
                    style: const TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
            else if (_geribildrim == 'dogru_risk')
              Text(
                '⚡  Doğru!  +${_riskValues.reward} puan',
                style: const TextStyle(
                  color: Colors.orangeAccent,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              )
            else if (_geribildrim == 'dogru_risk_bonus')
              Text(
                '⚡  Doğru!  +${_riskValues.reward} puan  🔥  +1 Bonus',
                style: const TextStyle(
                  color: Colors.orangeAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              )
            else if (_geribildrim == 'dogru_score_boost_card')
              Text(
                '⭐  Doğru!  +1 puan  ·  x${_matchConfig.scoreBoostValue} aktif!',
                style: const TextStyle(
                  color: Color(0xFFFFD54F),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              )
            else if (_geribildrim == 'dogru_score_boost_card_bonus')
              Text(
                '⭐  Doğru!  +1  🔥  +1 Bonus  ·  x${_matchConfig.scoreBoostValue} aktif!',
                style: const TextStyle(
                  color: Color(0xFFFFD54F),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              )
            else if (_geribildrim == 'dogru_score_boost')
              Text(
                '⭐  Doğru!  +${_matchConfig.scoreBoostValue} puan (x${_matchConfig.scoreBoostValue})',
                style: const TextStyle(
                  color: Color(0xFFFFD54F),
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              )
            else if (_geribildrim == 'dogru_score_boost_bonus')
              Text(
                '⭐  Doğru!  +${_matchConfig.scoreBoostValue}  🔥  +1 Combo Bonus',
                style: const TextStyle(
                  color: Color(0xFFFFD54F),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              )
            else if (_geribildrim == 'yanlis_risk')
              Text(
                '⚡  Yanlış!  -${_riskValues.penalty} puan  ·  can değişmedi',
                style: const TextStyle(
                  color: Colors.orangeAccent,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            else if (_geribildrim == 'dogru_ipucu')
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '✓  Doğru!',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text('💡', style: TextStyle(fontSize: 13)),
                  SizedBox(width: 3),
                  Text(
                    '½ puan  ·  ipuçlu',
                    style: TextStyle(
                      color: Colors.amberAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            else
              Text(
                '✗  Yanlış!  ·  $_dogruIsim',
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ],
      ),
    );
  }

  // ── Şık grid ──────────────────────────────────────────────────────────────

  Widget _buildSeceneklerGrid() {
    if (_mevcutSecenekler.isEmpty) return const SizedBox.shrink();
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 2.6,
      children: _mevcutSecenekler
          .map((isim) => _buildSecenekButon(isim))
          .toList(),
    );
  }

  Widget _buildSecenekButon(String isim) {
    final aktif =
        _geribildrim == null && !_oyunBitti && !_riskPopupGosteriliyor;
    final bool isDogruCevap =
        _mevcutFutbolcu != null && isim == _mevcutFutbolcu!.isim;
    final bool isSecilen = isim == _secilenSecenekIsim;

    // Renk mantığı
    Color bgColor;
    Color borderColor;
    Color textColor;
    Widget? trailingIcon;

    if (_geribildrim == null) {
      // Henüz seçim yapılmadı
      bgColor = Colors.white.withOpacity(0.08);
      borderColor = Colors.white.withOpacity(0.28);
      textColor = Colors.white;
    } else if (isDogruCevap) {
      // Doğru cevap her zaman yeşil gösterilir
      bgColor = Colors.green.withOpacity(0.22);
      borderColor = Colors.greenAccent;
      textColor = Colors.greenAccent;
      trailingIcon = const Icon(Icons.check_circle, color: Colors.greenAccent, size: 16);
    } else if (isSecilen) {
      // Seçilen yanlış şık kırmızı
      bgColor = Colors.red.withOpacity(0.20);
      borderColor = Colors.redAccent;
      textColor = Colors.redAccent;
      trailingIcon = const Icon(Icons.cancel, color: Colors.redAccent, size: 16);
    } else {
      // Seçilmemiş diğer yanlış şıklar solar
      bgColor = Colors.white.withOpacity(0.03);
      borderColor = Colors.white.withOpacity(0.10);
      textColor = Colors.white30;
    }

    return GestureDetector(
      onTap: aktif ? () => _secenekSec(isim) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: isDogruCevap && _geribildrim != null
              ? [BoxShadow(color: Colors.greenAccent.withOpacity(0.2), blurRadius: 10)]
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                isim,
                style: TextStyle(
                  color: textColor,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (trailingIcon != null) ...[
              const SizedBox(width: 4),
              trailingIcon,
            ],
          ],
        ),
      ),
    );
  }

  // ── Pause overlay ─────────────────────────────────────────────────────────

  // ── Blitz UI ──────────────────────────────────────────────────────────────

  Widget _buildBlitzIntro() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: AnimatedBuilder(
            animation: _blitzIntroCtrl,
            builder: (_, __) => Opacity(
              opacity: _blitzIntroFade.value,
              child: Transform.scale(
                scale: _blitzIntroScale.value,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF003D4D), Color(0xFF001A22)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: const Color(0xFF00E5FF).withOpacity(0.7),
                        width: 1.5),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x9900E5FF),
                          blurRadius: 40,
                          spreadRadius: -6),
                      BoxShadow(
                          color: Color(0x4400BCD4),
                          blurRadius: 80,
                          spreadRadius: -20),
                    ],
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '⚡ BLITZ MODE ⚡',
                        style: TextStyle(
                          color: Color(0xFF00E5FF),
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          shadows: [
                            Shadow(
                                color: Color(0xAA00E5FF), blurRadius: 16),
                            Shadow(
                                color: Color(0x5500BCD4), blurRadius: 40),
                          ],
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '15 saniye • +3 puan',
                        style: TextStyle(
                          color: Color(0x9900E5FF),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBlitzCountdown() {
    return AnimatedBuilder(
      animation: _blitzPulseCtrl,
      builder: (_, __) {
        final glow = 0.5 + _blitzPulseAnim.value * 0.5;
        return Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF00E5FF).withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: const Color(0xFF00E5FF).withOpacity(glow),
                width: 1.2),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFF00E5FF).withOpacity(0.15 * glow),
                  blurRadius: 10,
                  spreadRadius: -3),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⚡', style: TextStyle(fontSize: 11)),
              const SizedBox(width: 4),
              Text(
                'BLITZ  ${_blitzRemainingSeconds}s',
                style: TextStyle(
                  color: const Color(0xFF00E5FF).withOpacity(glow),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Floating score (+N) ───────────────────────────────────────────────────

  Widget _buildFloatingScore() {
    return Positioned(
      top: 110,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _scoreFloatCtrl,
          builder: (_, __) => FadeTransition(
            opacity: _scoreFloatFade,
            child: SlideTransition(
              position: _scoreFloatSlide,
              child: Center(
                child: Text(
                  _floatingScoreText,
                  style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 52,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                    shadows: [
                      Shadow(color: Color(0xAAFF6D00), blurRadius: 20),
                      Shadow(color: Color(0x66FF9800), blurRadius: 50),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Risk Kartı Popup ──────────────────────────────────────────────────────

  Widget _buildRiskPopup() {
    final rv = _riskValues;
    return Positioned.fill(
      child: FadeTransition(
        opacity: _popupFade,
        child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          color: Colors.black.withOpacity(0.72),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: ScaleTransition(
                scale: _popupScale,
                child: AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, child) {
                    final glow = 40.0 + _pulseAnim.value * 25.0;
                    return Container(
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1A0800), Color(0xFF0D0000)],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                      color: Colors.deepOrange.withOpacity(
                          0.45 + _pulseAnim.value * 0.25),
                      width: 1.5),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xAAFF6D00),
                        blurRadius: glow,
                        spreadRadius: -8),
                    BoxShadow(
                        color: const Color(0x44FF9800),
                        blurRadius: glow * 2,
                        spreadRadius: -20),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ⚡ İkon
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(colors: [
                          Color(0x44FF9800),
                          Color(0x00FF9800),
                        ]),
                        border: Border.all(
                            color: Colors.orangeAccent.withOpacity(0.5),
                            width: 1.5),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x66FF6D00),
                              blurRadius: 20,
                              spreadRadius: -4),
                        ],
                      ),
                      child: const Center(
                        child: Text('⚡',
                            style: TextStyle(fontSize: 26)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'RİSK KARTI',
                      style: TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        shadows: [
                          Shadow(
                              color: Color(0xAAFF6D00), blurRadius: 12),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    // Ödül / Ceza
                    Row(
                      children: [
                        Expanded(
                          child: _riskInfoBox(
                            label: 'DOĞRU',
                            value: '+${rv.reward}',
                            color: const Color(0xFF00E676),
                            icon: Icons.add_circle_outline,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _riskInfoBox(
                            label: 'YANLIŞ',
                            value: '-${rv.penalty}',
                            color: const Color(0xFFFF5252),
                            icon: Icons.remove_circle_outline,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.08)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.favorite_border,
                              color: Colors.white38, size: 13),
                          SizedBox(width: 5),
                          Text(
                            'Yanlış bilsen de CAN GİTMEZ',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // KABUL ET
                    _pauseButton(
                      label: 'Kabul Et  ⚡',
                      icon: Icons.check_circle_outline,
                      gradient: const [
                        Color(0xFFE65100),
                        Color(0xFF6D1A00)
                      ],
                      glowColor: const Color(0xFFFF6D00),
                      onTap: _riskKabul,
                    ),
                    const SizedBox(height: 10),
                    // PAS GEÇ
                    GestureDetector(
                      onTap: _riskPasGec,
                      child: Container(
                        width: double.infinity,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.18),
                              width: 1.5),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.skip_next_rounded,
                                color: Colors.white54, size: 18),
                            SizedBox(width: 7),
                            Text(
                              'Pas Geç',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),              // Column biter
              );               // return Container biter
              },               // AnimatedBuilder builder biter
            ),                 // AnimatedBuilder biter
          ),                   // ScaleTransition biter
        ),                     // Padding biter
      ),                       // Center biter
    ),                         // siyah Container biter
  ),                           // BackdropFilter biter
),                             // FadeTransition biter
);                             // Positioned.fill biter
  }

  Widget _riskInfoBox({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.15),
              blurRadius: 12,
              spreadRadius: -4),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              shadows: [Shadow(color: color.withOpacity(0.5), blurRadius: 8)],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.7),
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPauseOverlay() {
    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          color: Colors.black.withOpacity(0.65),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF0A1535),
                      const Color(0xFF060D22),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.15),
                    width: 1.5,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0xAA0D47A1),
                      blurRadius: 40,
                      spreadRadius: -4,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // İkon + başlık
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.08),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.2), width: 1.5),
                      ),
                      child: const Icon(Icons.pause_rounded,
                          color: Colors.white, size: 26),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Oyun Duraklatıldı',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Ne yapmak istiyorsun?',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.45),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 26),
                    // Devam Et
                    _pauseButton(
                      label: 'Devam Et',
                      icon: Icons.play_arrow_rounded,
                      gradient: const [Color(0xFF00C853), Color(0xFF004D1A)],
                      glowColor: const Color(0xFF00C853),
                      onTap: _devamEt,
                    ),
                    const SizedBox(height: 10),
                    // Baştan Başlat
                    _pauseButton(
                      label: 'Oyunu Baştan Başlat',
                      icon: Icons.replay_rounded,
                      gradient: const [Color(0xFF1565C0), Color(0xFF0A1535)],
                      glowColor: const Color(0xFF42A5F5),
                      onTap: _basdanBaslat,
                    ),
                    const SizedBox(height: 10),
                    // Ana Menü
                    GestureDetector(
                      onTap: _anaMenuye,
                      child: Container(
                        width: double.infinity,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.18), width: 1.5),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.home_rounded,
                                color: Colors.white60, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Ana Menüye Dön',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pauseButton({
    required String label,
    required IconData icon,
    required List<Color> gradient,
    required Color glowColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: glowColor.withOpacity(0.45), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: glowColor.withOpacity(0.30),
              blurRadius: 16,
              spreadRadius: -4,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── İpucu sistemi ─────────────────────────────────────────────────────────

  /// Oyuncu için mevcut ilk ipucunu döner; hiçbiri yoksa null.
  String? _buildHintFor(KariyerFutbolcu f) {
    if (f.ulke != null && f.ulke!.isNotEmpty) return 'Ülke: ${f.ulke}';
    if (f.pozisyon != null && f.pozisyon!.isNotEmpty)
      return 'Pozisyon: ${f.pozisyon}';
    if (f.dogumYili != null) return 'Doğum Yılı: ${f.dogumYili}';
    return null;
  }

  void _ipucuKullan() {
    final futbolcu = _mevcutFutbolcu;
    if (futbolcu == null || _oyunIpucuKullanildi || _kartIpucuAcik) return;

    final hint = _buildHintFor(futbolcu);
    if (hint == null) {
      if (kDebugMode) AppLogger.info('[Hint] Bu futbolcu için ipucu yok.');
      return;
    }

    setState(() {
      _oyunIpucuKullanildi = true;
      _kartIpucuAcik = true;
      _kartIpucuMetni = hint;
    });

    AnalyticsService.logCareerHintUsed(
      difficulty: widget.zorluk,
      cardIndex: _kartIndex,
    );

    if (kDebugMode) {
      AppLogger.info('[Hint] İpucu kullanıldı → "$hint"');
    }
  }

  Widget _buildIpucuAlani() {
    final futbolcu = _mevcutFutbolcu;
    if (futbolcu == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // İpucu metni (açıksa)
        if (_kartIpucuAcik && _kartIpucuMetni != null)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: Colors.amberAccent.withOpacity(0.45), width: 1.2),
              boxShadow: [
                BoxShadow(
                    color: Colors.amber.withOpacity(0.12),
                    blurRadius: 10,
                    spreadRadius: -2),
              ],
            ),
            child: Row(
              children: [
                const Text('💡', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _kartIpucuMetni!,
                    style: const TextStyle(
                      color: Colors.amberAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        // İpucu butonu
        _buildIpucuButon(futbolcu),
      ],
    );
  }

  Widget _buildIpucuButon(KariyerFutbolcu futbolcu) {
    // Geri bildirim aşamasında butonu gizle
    if (_geribildrim != null) return const SizedBox.shrink();

    final hintMevcut = _buildHintFor(futbolcu) != null;

    if (_kartIpucuAcik) {
      // Bu kartta ipucu zaten açık
      return _ipucuChip(
        label: 'İpucu Kullanıldı',
        icon: Icons.lightbulb,
        color: Colors.amberAccent,
        aktif: false,
      );
    }

    if (_oyunIpucuKullanildi) {
      // Bu oyunda ipucu hakkı tükendi
      return _ipucuChip(
        label: 'İpucu Hakkın Kalmadı',
        icon: Icons.lightbulb_outline,
        color: Colors.white30,
        aktif: false,
      );
    }

    if (!hintMevcut) {
      // Bu futbolcu için ipucu verisi yok
      return _ipucuChip(
        label: 'İpucu Yok',
        icon: Icons.lightbulb_outline,
        color: Colors.white24,
        aktif: false,
      );
    }

    // Aktif ipucu butonu
    return _ipucuChip(
      label: 'İpucu Kullan  (1 hak)',
      icon: Icons.lightbulb_outline,
      color: Colors.amberAccent,
      aktif: true,
      onTap: _ipucuKullan,
    );
  }

  Widget _ipucuChip({
    required String label,
    required IconData icon,
    required Color color,
    required bool aktif,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: aktif ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(aktif ? 0.10 : 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: color.withOpacity(aktif ? 0.45 : 0.20), width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Pas butonu ────────────────────────────────────────────────────────────

  Widget _buildPasButonu() {
    final aktif =
        _geribildrim == null && !_oyunBitti && !_riskPopupGosteriliyor;
    final limitEnabled = _passLimitAktif;
    final pasHakkiBitti = limitEnabled && _kalanPasHakki <= 0;
    final sayacGoster = limitEnabled && _maxPasHakki > 0;

    final Color bgColor = pasHakkiBitti
        ? Colors.red.shade700.withOpacity(0.9)
        : Colors.orange.withOpacity(0.85);
    final Color borderColor = pasHakkiBitti
        ? Colors.redAccent
        : Colors.orangeAccent.withOpacity(0.6);

    final String labelText = sayacGoster
        ? 'PAS $_kalanPasHakki/$_maxPasHakki'
        : 'Pas';

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.orange.withOpacity(0.25),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: borderColor, width: 1.5),
          ),
        ),
        onPressed: aktif ? _pas : null,
        icon: const Icon(Icons.skip_next, size: 20),
        label: Text(
          labelText,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: sayacGoster ? 0.5 : 0,
          ),
        ),
      ),
    );
  }
}
