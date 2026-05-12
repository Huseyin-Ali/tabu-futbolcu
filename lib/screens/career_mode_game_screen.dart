import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../models/kariyer_futbolcu.dart';
import '../services/career_mode_service.dart';
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

class _CareerModeGameScreenState extends State<CareerModeGameScreen> {
  List<KariyerFutbolcu> _tumFutbolcular = [];
  final Set<String> _kullanilmisIdler = {};

  KariyerFutbolcu? _mevcutFutbolcu;

  late int _kalanSure;
  int _skor = 0;
  int _dogruSayisi = 0;
  int _yanlisSayisi = 0;
  int _pasSayisi = 0;

  Timer? _timer;
  bool _yukleniyor = true;
  bool _oyunBitti = false;
  bool _durduruldu = false;

  // Şık sistemi
  List<String> _mevcutSecenekler = [];
  String? _secilenSecenekIsim;

  // 'dogru' | 'yanlis' | null — feedback state
  String? _geribildrim;
  String _dogruIsim = '';

  @override
  void initState() {
    super.initState();
    _kalanSure = widget.sure;
    _yukleFutbolcular();
  }

  @override
  void dispose() {
    _timer?.cancel();
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

    setState(() {
      _mevcutFutbolcu = secilen;
      _kullanilmisIdler.add(secilen.id);
      _geribildrim = null;
      _secilenSecenekIsim = null;
      _dogruIsim = '';
      _mevcutSecenekler = CareerModeService.generateChoices(
        dogru: secilen,
        tumListe: _tumFutbolcular,
      );
    });
  }

  void _secenekSec(String isim) {
    if (_mevcutFutbolcu == null || _geribildrim != null) return;

    final dogru = isim == _mevcutFutbolcu!.isim;

    setState(() {
      _secilenSecenekIsim = isim;
      _dogruIsim = _mevcutFutbolcu!.isim;
      if (dogru) {
        _skor++;
        _dogruSayisi++;
        _geribildrim = 'dogru';
      } else {
        _yanlisSayisi++;
        _geribildrim = 'yanlis';
      }
    });

    Future.delayed(Duration(milliseconds: dogru ? 900 : 1300), () {
      if (mounted && !_oyunBitti) _sonrakiKart();
    });
  }

  void _pas() {
    if (_mevcutFutbolcu == null || _geribildrim != null) return;
    setState(() {
      _pasSayisi++;
    });
    _sonrakiKart();
  }

  void _oyunuBitir() {
    if (_oyunBitti) return;
    _timer?.cancel();
    setState(() => _oyunBitti = true);

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => CareerModeResultScreen(
          skor: _skor,
          dogruSayisi: _dogruSayisi,
          yanlisSayisi: _yanlisSayisi,
          pasSayisi: _pasSayisi,
          sure: widget.sure,
          zorluk: widget.zorluk,
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
          SafeArea(
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
                        const SizedBox(height: 12),
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
          // Pause overlay
          if (_durduruldu) _buildPauseOverlay(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Pause butonu
          GestureDetector(
            onTap: _duraklat,
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
              ),
              child: const Icon(Icons.pause_rounded, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 10),
          // Timer
          _statPill(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer, color: _timerColor, size: 16),
                const SizedBox(width: 4),
                Text(
                  '$_kalanSure',
                  style: TextStyle(
                    color: _timerColor,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            borderColor: _timerColor,
          ),
          const Spacer(),
          // Skor
          _statPill(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star, color: Colors.yellowAccent, size: 16),
                const SizedBox(width: 4),
                Text(
                  '$_skor',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Doğru / Pas
          _statPill(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$_dogruSayisi D',
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '$_pasSayisi P',
                  style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
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

    Color borderColor = Colors.white.withOpacity(0.4);
    if (_geribildrim == 'dogru') borderColor = Colors.greenAccent;
    if (_geribildrim == 'yanlis') borderColor = Colors.redAccent;

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
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color:
                      _difficultyColor(futbolcu.zorluk).withOpacity(0.2),
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
                    color: Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(8),
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
    final aktif = _geribildrim == null && !_oyunBitti;
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

  // ── Pas butonu ────────────────────────────────────────────────────────────

  Widget _buildPasButonu() {
    final aktif = _geribildrim == null && !_oyunBitti;
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
