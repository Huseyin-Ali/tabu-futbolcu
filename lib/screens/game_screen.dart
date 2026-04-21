import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../widgets/common_title.dart';
import '../widgets/common_card.dart';
import '../storage/hive_game_storage.dart';
import '../services/futbolcu_service.dart';
import '../models/futbolcu.dart';
import '../constants/app_constants.dart';
import '../services/analytics_service.dart';
import 'winner_screen.dart';
import 'welcome_screen.dart';

class GameScreen extends StatefulWidget {
  final String oyuncu1Adi;
  final String oyuncu2Adi;
  final int turSayisi;
  final int sure;

  const GameScreen({
    Key? key,
    required this.oyuncu1Adi,
    required this.oyuncu2Adi,
    required this.turSayisi,
    required this.sure,
  }) : super(key: key);

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  int _ballsLeft = 3;
  bool _showStartButton = true;
  bool _showCountdown = false;
  bool _isFirstStart = true;
  String _team1Ismi = '';
  String _team2Ismi = '';
  bool _team1Sirasi = true;
  bool _sesAcik = true;
  bool _isPaused = false;

  int _totalTime = 60;
  int _currentTime = 60;
  late Ticker _ticker;
  Duration _pausedElapsed = Duration.zero;
  DateTime? _tickerStartTime;

  String _secilenFutbolcu = '';
  List<String> _secilenTabuKelimeler = [];
  List<double> _ballTops = [];
  int _team1PasHakki = 3;
  int _team2PasHakki = 3;
  int _tabuCezasi = 2;
  int _dogruSayisi = 0;
  int _team1Skor = 0;
  int _team2Skor = 0;
  int _puanHedefi = 50;

  List<Futbolcu> _onbellekFutbolcular = [];
  bool _onbellekYuklendi = false;
  final Set<String> _kullanilmisFutbolcular = <String>{};
  final List<int> _kartSirasi = <int>[];
  int _kartIndex = 0;

  /// Aynı kartın `card_shown` event'ini tekrar loglamasını önler.
  String? _lastShownPlayerId;

  final AudioPlayer _audioPlayer = AudioPlayer();

  // ── İş mantığı metodları — hiçbiri değişmedi ──────────────────────────

  @override
  void initState() {
    super.initState();
    _ayarlariYukle();
    _takimIsimleriniYukle();
    _ticker = createTicker(_onTick);
    _futbolculariYukle();
    _sesDurumunuYukle();
  }

  Future<void> _ayarlariYukle() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pasHakki =
          prefs.getInt(AppConstants.keyPasHakki) ?? AppConstants.defaultPasHakki;
      setState(() {
        _totalTime = prefs.getInt(AppConstants.keyZamanLimiti) ??
            AppConstants.defaultZamanLimiti;
        _currentTime = _totalTime;
        _team1PasHakki = pasHakki;
        _team2PasHakki = pasHakki;
        _tabuCezasi = prefs.getInt(AppConstants.keyTabuCezasi) ??
            AppConstants.defaultTabuCezasi;
        _puanHedefi = prefs.getInt(AppConstants.keyPuanHedefi) ??
            AppConstants.defaultPuanHedefi;
      });
    } catch (e) {
      setState(() {
        _totalTime = AppConstants.defaultZamanLimiti;
        _currentTime = AppConstants.defaultZamanLimiti;
        _team1PasHakki = AppConstants.defaultPasHakki;
        _team2PasHakki = AppConstants.defaultPasHakki;
        _tabuCezasi = AppConstants.defaultTabuCezasi;
        _puanHedefi = AppConstants.defaultPuanHedefi;
      });
    }
  }

  void _takimIsimleriniYukle() {
    try {
      final takim1 = HiveGameStorage.getirTakim1();
      final takim2 = HiveGameStorage.getirTakim2();
      if (takim1 != null && takim2 != null) {
        setState(() {
          _team1Ismi = takim1['takim']?.toString() ?? '';
          _team2Ismi = takim2['takim']?.toString() ?? '';
        });
      }
    } catch (e) {
      print('Takım isimleri yüklenirken hata oluştu: $e');
    }
  }

  Future<void> _sesDurumunuYukle() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _sesAcik =
          prefs.getBool(AppConstants.keySesAcik) ?? AppConstants.defaultSesAcik;
    });
  }

  Future<void> _sesDurumunuDegistir() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _sesAcik = !_sesAcik;
      prefs.setBool(AppConstants.keySesAcik, _sesAcik);
    });
    AnalyticsService.logAudioToggled(isSoundOn: _sesAcik);
  }

  Future<void> _sesCal(String sesDosyasi) async {
    if (!_sesAcik) return;
    try {
      await _audioPlayer.stop();
      await _audioPlayer.setSource(AssetSource(sesDosyasi));
      await _audioPlayer.resume();
    } catch (e) {
      // Ses çalma hatası kritik değil
    }
  }

  void _pauseOyun() {
    if (_isPaused) {
      setState(() {
        _isPaused = false;
        _tickerStartTime = DateTime.now();
      });
      _ticker.start();
    } else {
      if (_tickerStartTime != null) {
        final now = DateTime.now();
        final elapsedSinceStart = now.difference(_tickerStartTime!);
        _pausedElapsed += elapsedSinceStart;
      }
      setState(() {
        _isPaused = true;
      });
      _ticker.stop();
      AnalyticsService.logMatchPaused();

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Colors.white,
            contentPadding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            content: const Text(
              'Oyun duraklatıldı. Ana menüye dönmek istediğinizden emin misiniz?',
              style: TextStyle(color: Colors.black, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  setState(() {
                    _isPaused = false;
                    _tickerStartTime = DateTime.now();
                  });
                  _ticker.start();
                  AnalyticsService.logMatchResumed();
                },
                child: const Text('Devam Et',
                    style: TextStyle(color: Colors.green, fontSize: 16)),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                        builder: (context) => const WelcomeScreen()),
                    (route) => false,
                  );
                },
                child: const Text('Ana Menüye Dön',
                    style: TextStyle(color: Colors.red, fontSize: 16)),
              ),
            ],
          );
        },
      );
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    if (_isPaused) return;
    if (_currentTime <= 0) return;

    final totalElapsed = _pausedElapsed + elapsed;
    final computed = _totalTime - totalElapsed.inSeconds;

    if (computed <= 0) {
      _handleTurnTimeout();
    } else {
      setState(() => _currentTime = computed);
    }
  }

  /// Süre dolduğunda sırayı değiştirir ve `turn_timeout` event'ini loglar.
  void _handleTurnTimeout() {
    final previousTeam = _team1Sirasi ? _team1Ismi : _team2Ismi;
    final nextTeam = _team1Sirasi ? _team2Ismi : _team1Ismi;

    AnalyticsService.logTurnTimeout(
      previousTeam: previousTeam,
      nextTeam: nextTeam,
    );

    setState(() {
      _currentTime = 0;
      _ticker.stop();
      _team1Sirasi = !_team1Sirasi;
      _dogruSayisi = 0;
      _ballTops.clear();
      _pausedElapsed = Duration.zero;
      _showStartButton = true;
      _showCountdown = false;
      _isFirstStart = false;
      _ballsLeft = 3;
      if (_onbellekFutbolcular.isNotEmpty) {
        _kartHavuzunuHazirla();
      }
      _futbolcuSec();
    });
  }

  void _startGameTimer() {
    setState(() {
      if (_pausedElapsed == Duration.zero) {
        _currentTime = _totalTime;
      }
      _tickerStartTime = DateTime.now();
    });
    _ticker.start();
  }

  void _baslatMac() {
    AnalyticsService.logMatchStarted(
      timeLimit: _totalTime,
      targetScore: _puanHedefi,
    );
    setState(() {
      _showStartButton = false;
      _showCountdown = true;
      _ballsLeft = 3;
    });
    _startCountdown();
  }

  void _startCountdown() async {
    AnalyticsService.logCountdownStarted();
    for (int i = 3; i > 0; i--) {
      if (!mounted) return;
      setState(() {
        _ballsLeft = i;
      });
      await Future.delayed(const Duration(seconds: 1));
    }
    if (!mounted) return;
    setState(() {
      _showCountdown = false;
    });
    AnalyticsService.logTurnStarted(
      activeTeam: _team1Sirasi ? _team1Ismi : _team2Ismi,
      remainingTime: _totalTime,
    );
    _startGameTimer();
  }

  void _kartHavuzunuHazirla() {
    _kullanilmisFutbolcular.clear();
    _kartSirasi
      ..clear()
      ..addAll(List<int>.generate(_onbellekFutbolcular.length, (i) => i));
    _kartSirasi.shuffle(Random());
    _kartIndex = 0;
  }

  Future<void> _futbolculariYukle() async {
    try {
      final futbolcular = await FutbolcuService.getFutbolcularProduction();
      if (!mounted) return;
      setState(() {
        _onbellekFutbolcular = futbolcular;
        _onbellekYuklendi = true;
      });
      if (_onbellekFutbolcular.isNotEmpty) {
        _kartHavuzunuHazirla();
        await _futbolcuSec();
      } else {
        setState(() {
          _secilenFutbolcu = 'Futbolcu bulunamadı';
          _secilenTabuKelimeler = ['Veri', 'Yok', 'Lütfen', 'Kontrol', 'Edin'];
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _onbellekYuklendi = true;
        _secilenFutbolcu = 'Hata Oluştu';
        _secilenTabuKelimeler = ['Lütfen', 'Tekrar', 'Deneyin'];
      });
    }
  }

  Future<void> _futbolcuSec() async {
    if (!_onbellekYuklendi || _onbellekFutbolcular.isEmpty) return;
    if (_kartIndex >= _kartSirasi.length) {
      _kartHavuzunuHazirla();
    }
    final int maxTry = _onbellekFutbolcular.length;
    for (int t = 0; t < maxTry; t++) {
      final idx = _kartSirasi[_kartIndex];
      _kartIndex++;
      final Futbolcu secilen = _onbellekFutbolcular[idx];
      if (_kullanilmisFutbolcular.contains(secilen.id)) {
        if (_kartIndex >= _kartSirasi.length) {
          _kartHavuzunuHazirla();
        }
        continue;
      }
      _kullanilmisFutbolcular.add(secilen.id);
      if (!mounted) return;
      setState(() {
        _secilenFutbolcu = secilen.isim;
        _secilenTabuKelimeler = secilen.tabuKelimeler;
      });
      _logCardShownIfNew(secilen.id, secilen.isim);
      return;
    }
    // Tüm kartlar kullanıldı — havuzu sıfırla ve ilk kartı göster.
    _kartHavuzunuHazirla();
    if (!mounted) return;
    final fallback = _onbellekFutbolcular[_kartSirasi.first];
    setState(() {
      _secilenFutbolcu = fallback.isim;
      _secilenTabuKelimeler = fallback.tabuKelimeler;
    });
    _logCardShownIfNew(fallback.id, fallback.isim);
  }

  /// Yalnızca öncekinden farklı bir kart gösterildiğinde loglar.
  void _logCardShownIfNew(String playerId, String playerName) {
    if (_lastShownPlayerId == playerId) return;
    _lastShownPlayerId = playerId;
    AnalyticsService.logCardShown(playerId: playerId, playerName: playerName);
  }

  void _dogruBildi() async {
    await _sesCal(AppConstants.soundGol);

    // setState öncesi anlık değerleri yakala (futbolcuSec sonrası değişir).
    final activeTeam = _team1Sirasi ? _team1Ismi : _team2Ismi;
    final currentPlayer = _secilenFutbolcu;
    final remainingTime = _currentTime;

    bool kazananVar = false;
    int yeniTeam1Skor = _team1Skor;
    int yeniTeam2Skor = _team2Skor;
    setState(() {
      if (_team1Sirasi) {
        yeniTeam1Skor = _team1Skor + 1;
        _team1Skor = yeniTeam1Skor;
        if (yeniTeam1Skor >= _puanHedefi) {
          kazananVar = true;
        } else {
          _dogruSayisi++;
          if (_dogruSayisi <= 10) _ballTops.add(0);
          _futbolcuSec();
        }
      } else {
        yeniTeam2Skor = _team2Skor + 1;
        _team2Skor = yeniTeam2Skor;
        if (yeniTeam2Skor >= _puanHedefi) {
          kazananVar = true;
        } else {
          _dogruSayisi++;
          if (_dogruSayisi <= 10) _ballTops.add(0);
          _futbolcuSec();
        }
      }
    });

    AnalyticsService.logCorrectGuess(
      activeTeam: activeTeam,
      team1Score: yeniTeam1Skor,
      team2Score: yeniTeam2Skor,
      currentPlayer: currentPlayer,
      remainingTime: remainingTime,
    );

    if (kazananVar) {
      final winnerTeam =
          yeniTeam1Skor >= _puanHedefi ? _team1Ismi : _team2Ismi;
      await AnalyticsService.logMatchFinished(
        winnerTeam: winnerTeam,
        team1Score: yeniTeam1Skor,
        team2Score: yeniTeam2Skor,
        targetScore: _puanHedefi,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => WinnerScreen(
            takim1Ismi: _team1Ismi,
            takim2Ismi: _team2Ismi,
            takim1Skor: yeniTeam1Skor,
            takim2Skor: yeniTeam2Skor,
            puanHedefi: _puanHedefi,
          ),
        ),
      );
    }
  }

  void _tabuYapildi() async {
    await _sesCal(AppConstants.soundWhistle);

    final activeTeam = _team1Sirasi ? _team1Ismi : _team2Ismi;
    final currentPlayer = _secilenFutbolcu;
    final remainingTime = _currentTime;

    setState(() {
      if (_team1Sirasi) {
        if (_team1Skor >= _tabuCezasi) {
          _team1Skor -= _tabuCezasi;
          _dogruSayisi -= _tabuCezasi;
          if (_ballTops.length >= _tabuCezasi) {
            _ballTops.removeRange(0, _tabuCezasi);
          } else {
            _ballTops.clear();
            for (int i = 0; i < _tabuCezasi - _ballTops.length; i++) {
              _ballTops.add(0);
            }
          }
        } else {
          int eksikTop = _tabuCezasi - _team1Skor;
          _team1Skor = -eksikTop;
          _dogruSayisi = -eksikTop;
          _ballTops.clear();
          for (int i = 0; i < eksikTop.abs(); i++) {
            _ballTops.add(0);
          }
        }
      } else {
        if (_team2Skor >= _tabuCezasi) {
          _team2Skor -= _tabuCezasi;
          _dogruSayisi -= _tabuCezasi;
          if (_ballTops.length >= _tabuCezasi) {
            _ballTops.removeRange(0, _tabuCezasi);
          } else {
            _ballTops.clear();
            for (int i = 0; i < _tabuCezasi - _ballTops.length; i++) {
              _ballTops.add(0);
            }
          }
        } else {
          int eksikTop = _tabuCezasi - _team2Skor;
          _team2Skor = -eksikTop;
          _dogruSayisi = -eksikTop;
          _ballTops.clear();
          for (int i = 0; i < eksikTop.abs(); i++) {
            _ballTops.add(0);
          }
        }
      }
      _futbolcuSec();
    });

    AnalyticsService.logTabuFail(
      activeTeam: activeTeam,
      team1Score: _team1Skor,
      team2Score: _team2Skor,
      currentPlayer: currentPlayer,
      remainingTime: remainingTime,
    );
  }

  void _pasYap() {
    final currentPlayer = _secilenFutbolcu;
    final remainingTime = _currentTime;

    if (_team1Sirasi) {
      if (_team1PasHakki > 0) {
        setState(() {
          _team1PasHakki--;
          _futbolcuSec();
        });
        AnalyticsService.logPassUsed(
          activeTeam: _team1Ismi,
          remainingPassCount: _team1PasHakki,
          currentPlayer: currentPlayer,
          remainingTime: remainingTime,
        );
      }
    } else {
      if (_team2PasHakki > 0) {
        setState(() {
          _team2PasHakki--;
          _futbolcuSec();
        });
        AnalyticsService.logPassUsed(
          activeTeam: _team2Ismi,
          remainingPassCount: _team2PasHakki,
          currentPlayer: currentPlayer,
          remainingTime: remainingTime,
        );
      }
    }
  }

  // Doğru göstergesi — iş mantığı değişmedi, artık Positioned değil satır içi
  Widget _buildDogruOverlay(int dogruSayisi) {
    final negatif = dogruSayisi < 0;
    final n = dogruSayisi.abs();
    final bottomCount = n >= 5 ? 5 : n;
    final topCount = n > 5 ? (n >= 10 ? 5 : n - 5) : 0;
    final extra = n > 10 ? (n - 10) : 0;

    Widget row(int count) => Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            count,
            (_) => Icon(Icons.sports_soccer, size: 20,
                color: negatif ? Colors.red : Colors.white),
          ),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (extra > 0)
          Text(
            negatif ? '-$extra' : '+$extra',
            style: TextStyle(
                color: negatif ? Colors.red : Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                height: 1.0),
          ),
        if (extra > 0) const SizedBox(height: 2),
        if (topCount > 0) row(topCount),
        if (topCount > 0) const SizedBox(height: 2),
        row(bottomCount),
      ],
    );
  }

  // ── UI build metodları ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Arka plan — BackgroundWithLogo'nun logoTopPadding rezervasyonu
          // olmadan, stadyum görseli ve overlay doğrudan uygulandı.
          Positioned.fill(
            child: Image.asset(
              AppConstants.assetDuvarKagidi,
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.4)),
          ),

          // İçerik — SafeArea ile cihaza özgü inset'ler hesabı
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availH = constraints.maxHeight;
                final availW = constraints.maxWidth;
                final isUltra = availH < 360;
                final isCompact = availH < 430;

                if (_showStartButton) {
                  return _buildStartScreen(isCompact);
                }
                if (_showCountdown) {
                  return _buildCountdownScreen(isCompact);
                }
                return _buildActiveGameScreen(
                    availW, availH, isUltra, isCompact);
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Maçı Başlat / Devam Et ekranı ──────────────────────────────────────
  Widget _buildStartScreen(bool isCompact) {
    final logoH = isCompact ? 80.0 : 120.0;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Center(
          child: Image.asset(
            AppConstants.assetLogo,
            height: logoH,
            fit: BoxFit.contain,
          ),
        ),
        SizedBox(height: isCompact ? 16 : 24),
        CommonTitle(_isFirstStart ? 'Maçı Başlat' : 'Maça Devam Et'),
        SizedBox(height: isCompact ? 16 : 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: CommonCard(
            color: Colors.transparent,
            child: InkWell(
              onTap: _baslatMac,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  _isFirstStart ? 'BAŞLAT' : 'DEVAM ET',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Geri sayım ekranı ──────────────────────────────────────────────────
  Widget _buildCountdownScreen(bool isCompact) {
    final logoH = isCompact ? 80.0 : 120.0;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Center(
          child: Image.asset(
            AppConstants.assetLogo,
            height: logoH,
            fit: BoxFit.contain,
          ),
        ),
        SizedBox(height: isCompact ? 16 : 24),
        const CommonTitle('Maç Başlıyor'),
        SizedBox(height: isCompact ? 16 : 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            3,
            (i) => AnimatedOpacity(
              opacity: i < _ballsLeft ? 1.0 : 0.2,
              duration: const Duration(milliseconds: 300),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Icon(Icons.sports_soccer, size: 40, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Aktif oyun ekranı ──────────────────────────────────────────────────
  // 6 bölge: A=kontrol, B=skor, C=takım+süre, D=kart, E=göstergeler, F=butonlar
  Widget _buildActiveGameScreen(
      double availW, double availH, bool isUltra, bool isCompact) {
    // Threshold değerleri
    final hPad = isUltra ? 10.0 : 14.0;
    final gap = isUltra ? 3.0 : isCompact ? 5.0 : 8.0;
    final bottomPad = isUltra ? 4.0 : 8.0;

    // Skor sahası ölçüleri — responsive, sabit piksel yok
    final fieldW = (availW - hPad * 2) * 0.55;
    final fieldH = (fieldW * 0.26).clamp(32.0, 48.0);

    // Metin boyutları
    final teamFontSize = isUltra ? 13.0 : isCompact ? 14.0 : 16.0;
    final playerFontSize = isUltra ? 17.0 : isCompact ? 19.0 : 22.0;
    final tabuFontSize = isUltra ? 14.0 : isCompact ? 16.0 : 18.0;

    // Kart iç padding
    final cardPad = isUltra ? 8.0 : isCompact ? 10.0 : 12.0;

    // Buton dikey padding
    final btnVertPad = isUltra ? 4.0 : isCompact ? 6.0 : 8.0;

    // Aktif takımın pas hakkı
    final pasHakki = _team1Sirasi ? _team1PasHakki : _team2PasHakki;

    // Büyük ekranlarda kart sınırsız büyümesin; 560dp altında serbest
    final isLarge = availH >= 560;
    final maxCardH = isLarge ? 300.0 : double.infinity;

    // Kart için sabit yükseklik: ekranın ~%47'si, min-max ile kısıtlı
    final cardH = (availH * 0.47).clamp(
      isUltra ? 160.0 : 190.0,
      maxCardH.isInfinite ? 9999.0 : maxCardH,
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── A: Üst kontrol satırı (pause sol, ses sağ) ──────────────
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.pause, color: Colors.white, size: 28),
                onPressed: _pauseOyun,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  _sesAcik ? Icons.volume_up : Icons.volume_off,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: _sesDurumunuDegistir,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
          SizedBox(height: gap),

          // ── B: Skor/saha alanı — responsive, sabit px yok ───────────
          Center(
            child: SizedBox(
              width: fieldW,
              height: fieldH,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                        painter: FieldLinesPainter(opacity: 1.0)),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$_team1Skor',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: _team1Sirasi ? Colors.blue : Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: fieldW * 0.18),
                      Expanded(
                        child: Text(
                          '$_team2Skor',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: !_team1Sirasi ? Colors.blue : Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: gap),

          // ── C + D: Takım/süre ve kart — tek Expanded zone ───────────
          // mainAxisAlignment.center ile C+D bloğu ortalanır.
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // C: Takım adı + süre
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: isUltra ? 6 : 10,
                      vertical: isUltra ? 3 : 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _team1Sirasi ? _team1Ismi : _team2Ismi,
                          style: TextStyle(
                            fontSize: teamFontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isUltra ? 8 : 12,
                          vertical: isUltra ? 2 : 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Text(
                          '${(_currentTime ~/ 60).toString().padLeft(2, '0')}:'
                          '${(_currentTime % 60).toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: teamFontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: gap),

                // D: Oyuncu kartı — sabit yükseklik
                SizedBox(
                  height: cardH,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    padding: EdgeInsets.all(cardPad),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _secilenFutbolcu,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: playerFontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: cardPad * 0.7),
                        Container(height: 2, color: Colors.white70),
                        SizedBox(height: cardPad * 0.7),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                for (int i = 0;
                                    i < _secilenTabuKelimeler.length;
                                    i++) ...[
                                  if (i > 0)
                                    Divider(
                                      height: isUltra ? 10 : 14,
                                      color: Colors.white70,
                                    ),
                                  Text(
                                    _secilenTabuKelimeler[i],
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: tabuFontSize,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: gap),

          // ── E: Göstergeler — buton hizalı, sabit yükseklik ───────────
          SizedBox(
            height: isUltra ? 44.0 : isCompact ? 52.0 : 62.0,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Expanded(child: SizedBox.shrink()),
                const SizedBox(width: 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: pasHakki > 0
                        ? Wrap(
                            alignment: WrapAlignment.center,
                            children: List.generate(
                              pasHakki,
                              (_) => const Icon(
                                Icons.sports_soccer,
                                size: 20,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: _dogruSayisi != 0
                        ? _buildDogruOverlay(_dogruSayisi)
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: gap),

          // ── F: Alt butonlar ───────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: CommonCard(
                  padding: EdgeInsets.symmetric(
                      vertical: btnVertPad, horizontal: 8),
                  color: const Color(0xFFFF5252),
                  child: InkWell(
                    onTap: _tabuYapildi,
                    child: const Text(
                      'TABU',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CommonCard(
                  padding: EdgeInsets.symmetric(
                      vertical: btnVertPad, horizontal: 8),
                  color: const Color(0xFFFFEB3B),
                  child: InkWell(
                    onTap: _pasYap,
                    child: const Text(
                      'PAS',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CommonCard(
                  padding: EdgeInsets.symmetric(
                      vertical: btnVertPad, horizontal: 8),
                  color: const Color(0xFF4CAF50),
                  child: InkWell(
                    onTap: _dogruBildi,
                    child: const Text(
                      'DOĞRU',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: bottomPad),
        ],
      ),
    );
  }
}

// ── FieldLinesPainter — değişmedi ─────────────────────────────────────────
class FieldLinesPainter extends CustomPainter {
  final double opacity;
  FieldLinesPainter({this.opacity = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..color = const Color(0xFF145A32).withOpacity(opacity)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(12),
      ),
      bgPaint,
    );
    final paint = Paint()
      ..color = Colors.white.withOpacity(opacity)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawRect(
        Rect.fromLTWH(2, 2, size.width - 4, size.height - 4), paint);
    canvas.drawLine(Offset(size.width / 2, 2),
        Offset(size.width / 2, size.height - 2), paint);
    canvas.drawCircle(
        Offset(size.width / 2, size.height / 2), 12, paint);
    double penaltyWidth = 18;
    double penaltyHeight = size.height - 20;
    canvas.drawRect(
      Rect.fromLTWH(
          2, (size.height - penaltyHeight) / 2, penaltyWidth, penaltyHeight),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width - penaltyWidth - 2,
          (size.height - penaltyHeight) / 2, penaltyWidth, penaltyHeight),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant FieldLinesPainter oldDelegate) =>
      oldDelegate.opacity != opacity;
}
