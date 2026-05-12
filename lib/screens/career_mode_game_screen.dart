import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../models/kariyer_futbolcu.dart';
import '../services/career_mode_service.dart';
import '../utils/logger.dart';
import 'career_mode_result_screen.dart';
import 'welcome_screen.dart';

class CareerModeGameScreen extends StatefulWidget {
  final int sure;
  final String zorluk;

  const CareerModeGameScreen({
    super.key,
    required this.sure,
    required this.zorluk,
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

  // Combo sistemi
  int _comboCount = 0;
  int _maxCombo = 0;
  int _bonusScore = 0;
  bool _canKazanildi = false;

  // Can sistemi
  static const int _basLangicCan = 3;
  int _currentLives = _basLangicCan;

  // İpucu sistemi
  bool _oyunIpucuKullanildi = false;
  bool _kartIpucuAcik = false;
  String? _kartIpucuMetni;
  int _hintedCorrectCount = 0;

  // Risk animasyonları
  late AnimationController _popupEntryCtrl;  // popup giriş (300ms)
  late AnimationController _pulseCtrl;       // popup glow pulse (1400ms, repeat)
  late AnimationController _shakeCtrl;       // screen shake (220ms)
  late AnimationController _scoreFloatCtrl;  // floating +N (700ms)
  late AnimationController _flashCtrl;       // kırmızı flash (350ms)

  late Animation<double> _popupScale;
  late Animation<double> _popupFade;
  late Animation<double> _pulseAnim;
  late Animation<double> _shakeAnim;
  late Animation<double> _scoreFloatFade;
  late Animation<Offset> _scoreFloatSlide;
  late Animation<double> _flashOpacity;

  String _floatingScoreText = '';
  bool _showFlash = false;

  AudioPlayer? _riskAudioPlayer;

  // Risk kartı sistemi
  bool _isRiskKarti = false;
  bool _riskKabulEdildi = false;
  bool _riskPopupGosteriliyor = false;
  int _kartIndex = 0;
  int _lastRiskKartiIndex = -10; // başlangıçta uzakta tut
  int _totalRiskCount = 0;
  int _acceptedRiskCount = 0;
  int _wonRiskCount = 0;
  int _lostRiskCount = 0;
  int _riskScoreGain = 0;
  int _riskScoreLoss = 0;

  String get _skorStr =>
      _skor % 1 == 0 ? '${_skor.toInt()}' : _skor.toStringAsFixed(1);

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
    _yukleFutbolcular();
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
  }

  @override
  void dispose() {
    _timer?.cancel();
    _popupEntryCtrl.dispose();
    _pulseCtrl.dispose();
    _shakeCtrl.dispose();
    _scoreFloatCtrl.dispose();
    _flashCtrl.dispose();
    _riskAudioPlayer?.dispose();
    super.dispose();
  }

  Future<void> _yukleFutbolcular() async {
    final liste = await CareerModeService.getKariyerFutbolculari(
      zorluk: widget.zorluk,
    );

    if (!mounted) return;

    if (liste.isEmpty) {
      setState(() {
        _yukleniyor = false;
      });
      return;
    }

    final shuffled = List<KariyerFutbolcu>.from(liste)..shuffle(Random());

    setState(() {
      _tumFutbolcular = shuffled;
      _yukleniyor = false;
    });

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
        } else {
          t.cancel();
          _oyunuBitir();
        }
      });
    });
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

    final secilen = musait[Random().nextInt(musait.length)];

    _kartIndex++;

    // Risk kartı kararı: min 5 normal kart, %15 ihtimal, üst üste gelmesin
    final riskMumkun = _kartIndex >= 5 &&
        (_kartIndex - _lastRiskKartiIndex) >= 5;
    final bool riskOlsun =
        riskMumkun && Random().nextDouble() < 0.15;

    if (riskOlsun) {
      _lastRiskKartiIndex = _kartIndex;
      _totalRiskCount++;
      if (kDebugMode) {
        final rv = _riskValues;
        AppLogger.info(
          '[Risk] Risk kartı oluştu! kart#: $_kartIndex | '
          'zorluk: ${secilen.zorluk} | '
          '+${rv.reward} / -${rv.penalty}',
        );
      }
    }
    if (riskOlsun) {
      // Animasyonları setState'den sonra tetikle
      WidgetsBinding.instance.addPostFrameCallback((_) => _onRiskKartiGeldi());
    }

    setState(() {
      _mevcutFutbolcu = secilen;
      _kullanilmisIdler.add(secilen.id);
      _geribildrim = null;
      _secilenSecenekIsim = null;
      _dogruIsim = '';
      _kartIpucuAcik = false;
      _kartIpucuMetni = null;
      _isRiskKarti = riskOlsun;
      _riskKabulEdildi = false;
      _riskPopupGosteriliyor = riskOlsun;
      _mevcutSecenekler = CareerModeService.generateChoices(
        dogru: secilen,
        tumListe: _tumFutbolcular,
      );
    });
  }

  void _secenekSec(String isim) {
    if (_mevcutFutbolcu == null || _geribildrim != null) return;

    final dogru = isim == _mevcutFutbolcu!.isim;

    // Risk flag'ini şimdi yakala (Future.delayed'de kullanmak için)
    final bool wasRiskCard = _riskKabulEdildi;

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
      } else if (dogru) {
        // ══ Normal / ipuçlu doğru ═════════════════════════════════════════
        _dogruSayisi++;
        if (_kartIpucuAcik) {
          _skor += 0.5;
          _hintedCorrectCount++;
          _geribildrim = 'dogru_ipucu';
          if (kDebugMode) {
            AppLogger.info(
              '[Hint] İpuçlu doğru → +0.5 | combo etkilenmedi ($_comboCount)',
            );
          }
        } else {
          _skor += 1;
          _comboCount++;
          if (_comboCount > _maxCombo) _maxCombo = _comboCount;
          final threshold = _comboBonusThreshold;
          final isBonus = _comboCount % threshold == 0;
          if (isBonus) {
            _skor += 1;
            _bonusScore++;
            _currentLives++;
            _canKazanildi = true;
            _geribildrim = 'dogru_bonus';
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
            _geribildrim = 'dogru';
          }
          if (kDebugMode) {
            AppLogger.info(
              '[Combo] combo: $_comboCount/$threshold | maxCombo: $_maxCombo',
            );
          }
        }
      } else {
        // ══ Normal yanlış (can gider) ══════════════════════════════════════
        _yanlisSayisi++;
        _comboCount = 0;
        _currentLives--;
        _geribildrim = 'yanlis';
        if (kDebugMode) {
          AppLogger.info('[Lives] can azaldı → kalan: $_currentLives');
          AppLogger.info('[Combo] combo sıfırlandı');
        }
      }
    });

    final delay = dogru ? 900 : 1300;
    Future.delayed(Duration(milliseconds: delay), () {
      if (!mounted || _oyunBitti) return;
      // Risk kartında can gitmediğinden sadece normal kart yanlışında kontrol et
      if (!wasRiskCard && _currentLives <= 0) {
        if (kDebugMode) AppLogger.info('[Game] Can bitti → oyun sona eriyor');
        _oyunuBitir();
      } else {
        _sonrakiKart();
      }
    });
  }

  void _onRiskKartiGeldi() {
    _popupEntryCtrl.forward(from: 0.0);
    _pulseCtrl.repeat(reverse: true);
    _shakeCtrl.forward(from: 0.0);
    _playRiskSound();
  }

  void _playRiskSound() async {
    try {
      _riskAudioPlayer?.dispose();
      _riskAudioPlayer = AudioPlayer();
      await _riskAudioPlayer!.play(AssetSource('sounds/whistle.mp3'));
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
    if (kDebugMode) AppLogger.info('[Risk] Kullanıcı kabul etti');
  }

  void _riskPasGec() {
    if (!_riskPopupGosteriliyor) return;
    _stopRiskAnimations();
    if (kDebugMode) AppLogger.info('[Risk] Kullanıcı pas geçti');
    setState(() {
      _riskPopupGosteriliyor = false;
      _isRiskKarti = false;
      _riskKabulEdildi = false;
    });
    _sonrakiKart();
  }

  void _pas() {
    if (_mevcutFutbolcu == null || _geribildrim != null) return;
    setState(() {
      _pasSayisi++;
      _comboCount = 0;
    });
    if (kDebugMode) AppLogger.info('[Combo] Pas → combo sıfırlandı');
    _sonrakiKart();
  }

  void _oyunuBitir() {
    if (_oyunBitti) return;
    _timer?.cancel();
    setState(() => _oyunBitti = true);

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
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => CareerModeGameScreen(
          sure: widget.sure,
          zorluk: widget.zorluk,
        ),
      ),
    );
  }

  void _anaMenuye() {
    _timer?.cancel();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  Color get _timerColor {
    // Risk kartı aktifken turuncu
    if (_isRiskKarti && _riskKabulEdildi && _geribildrim == null) {
      return Colors.orangeAccent;
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
                  'Bu zorluk için kariyer yolu olan\nfutbolcu bulunamadı.',
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
          // ── Satır 1: Pause | Timer | Skor
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
          // ── Satır 2: Can ❤️❤️❤️ | Combo 🔥
          Row(
            children: [
              _buildLivesRow(),
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
    Color borderColor = isRiskAktif
        ? Colors.orangeAccent.withOpacity(0.6)
        : Colors.white.withOpacity(0.4);
    if (_geribildrim == 'dogru' ||
        _geribildrim == 'dogru_bonus' ||
        _geribildrim == 'dogru_ipucu' ||
        _geribildrim == 'dogru_risk' ||
        _geribildrim == 'dogru_risk_bonus') borderColor = Colors.greenAccent;
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
              const Text(
                'KARİYER YOLU',
                style: TextStyle(
                  color: Colors.white60,
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
                        : Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(8),
                    border: isRiskAktif
                        ? Border.all(
                            color: Colors.orangeAccent.withOpacity(0.25),
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
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange.withOpacity(0.85),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.orange.withOpacity(0.25),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: aktif ? _pas : null,
        icon: const Icon(Icons.skip_next, size: 20),
        label: const Text(
          'Pas',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
