import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/career_game_history.dart';
import '../storage/hive_game_storage.dart';
import '../utils/logger.dart';
import '../widgets/background_with_logo.dart';
import '../widgets/common_title.dart';
import 'career_mode_settings_screen.dart';
import 'welcome_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Result Screen
// ─────────────────────────────────────────────────────────────────────────────

class CareerModeResultScreen extends StatefulWidget {
  final int skor;
  final int dogruSayisi;
  final int yanlisSayisi;
  final int pasSayisi;
  final int sure;
  final String zorluk;

  const CareerModeResultScreen({
    super.key,
    required this.skor,
    required this.dogruSayisi,
    required this.yanlisSayisi,
    required this.pasSayisi,
    required this.sure,
    required this.zorluk,
  });

  @override
  State<CareerModeResultScreen> createState() => _CareerModeResultScreenState();
}

class _CareerModeResultScreenState extends State<CareerModeResultScreen>
    with TickerProviderStateMixin {
  // ── Controllers ───────────────────────────────────────────────────────────
  late final AnimationController _mainCtrl;   // entry sequence
  late final AnimationController _barCtrl;    // bar fill (one-shot)
  late final AnimationController _sweepCtrl;  // bar sweep light (repeating)

  // ── Entry animations ──────────────────────────────────────────────────────
  late final Animation<double> _pageFade;
  late final Animation<Offset> _pageSlide;
  late final Animation<double> _scoreScale;
  late final Animation<double> _scoreFade;
  late final List<Animation<double>> _statFades;
  late final List<Animation<Offset>> _statSlides;
  late final Animation<double> _barFade;
  late final Animation<double> _btnFade;

  // ── Bar ───────────────────────────────────────────────────────────────────
  late final Animation<double> _barFill;

  // ── Helpers ───────────────────────────────────────────────────────────────
  int get _toplamKart =>
      widget.dogruSayisi + widget.yanlisSayisi + widget.pasSayisi;
  double get _dogrulukOrani =>
      _toplamKart > 0 ? (widget.dogruSayisi / _toplamKart * 100) : 0;

  // ── Kayıt guard ───────────────────────────────────────────────────────────
  bool _kaydedildi = false;

  void _sonucuKaydet() {
    if (_kaydedildi) return;
    _kaydedildi = true;

    final kayit = CareerGameHistory(
      skor: widget.skor,
      dogruSayisi: widget.dogruSayisi,
      yanlisSayisi: widget.yanlisSayisi,
      pasSayisi: widget.pasSayisi,
      oynanankartSayisi: _toplamKart,
      zorluk: widget.zorluk,
      sure: widget.sure,
      basariOrani: _dogrulukOrani,
      tarih: DateTime.now(),
    );

    HiveGameStorage.ekleKariyerOyunu(kayit).then((_) {
      if (kDebugMode) {
        AppLogger.info(
          '[CareerResult] Sonuç kaydedildi — '
          'skor: ${kayit.skor}, zorluk: ${kayit.zorluk}, '
          'basariOrani: ${kayit.basariOrani.toStringAsFixed(1)}%',
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();

    _sonucuKaydet();

    _mainCtrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));
    _barCtrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    _sweepCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600));

    // Page
    _pageFade = CurvedAnimation(
        parent: _mainCtrl, curve: const Interval(0.0, 0.35, curve: Curves.easeOut));
    _pageSlide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _mainCtrl,
            curve: const Interval(0.0, 0.45, curve: Curves.easeOutCubic)));

    // Score card
    _scoreScale = Tween<double>(begin: 0.80, end: 1.0).animate(CurvedAnimation(
        parent: _mainCtrl,
        curve: const Interval(0.04, 0.52, curve: Curves.elasticOut)));
    _scoreFade = CurvedAnimation(
        parent: _mainCtrl, curve: const Interval(0.04, 0.30, curve: Curves.easeOut));

    // Stat cards staggered
    const starts = [0.30, 0.40, 0.50, 0.60];
    _statFades = starts
        .map((s) => CurvedAnimation(
            parent: _mainCtrl, curve: Interval(s, s + 0.26, curve: Curves.easeOut)))
        .toList();
    _statSlides = starts
        .map((s) => Tween<Offset>(begin: const Offset(0, 0.40), end: Offset.zero)
            .animate(CurvedAnimation(
                parent: _mainCtrl,
                curve: Interval(s, s + 0.26, curve: Curves.easeOutCubic))))
        .toList();

    // Bar + buttons
    _barFade = CurvedAnimation(
        parent: _mainCtrl, curve: const Interval(0.65, 0.88, curve: Curves.easeOut));
    _btnFade = CurvedAnimation(
        parent: _mainCtrl, curve: const Interval(0.78, 1.0, curve: Curves.easeOut));

    // Bar fill
    _barFill = CurvedAnimation(parent: _barCtrl, curve: Curves.easeOutCubic);

    // Fire
    _mainCtrl.forward();
    Future.delayed(const Duration(milliseconds: 620), () {
      if (!mounted) return;
      _barCtrl.forward().then((_) {
        if (mounted) _sweepCtrl.repeat();
      });
    });
  }

  @override
  void dispose() {
    _mainCtrl.dispose();
    _barCtrl.dispose();
    _sweepCtrl.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BackgroundWithLogo(
        child: FadeTransition(
          opacity: _pageFade,
          child: SlideTransition(
            position: _pageSlide,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CommonTitle('Oyun Bitti!',
                      padding: const EdgeInsets.only(top: 8, bottom: 18)),
                  // ── Score card
                  FadeTransition(
                    opacity: _scoreFade,
                    child: ScaleTransition(
                      scale: _scoreScale,
                      child: _buildScoreCard(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // ── Stat grid
                  _buildStatGrid(),
                  const SizedBox(height: 10),
                  // ── Accuracy bar
                  FadeTransition(opacity: _barFade, child: _buildAccuracyBar()),
                  const SizedBox(height: 22),
                  // ── Buttons
                  FadeTransition(
                    opacity: _btnFade,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildActionButton(
                          label: 'Tekrar Oyna',
                          icon: Icons.replay_rounded,
                          primary: const Color(0xFF00C853),
                          secondary: const Color(0xFF004D1A),
                          onTap: () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const CareerModeSettingsScreen()),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildGlassButton(
                          label: 'Ana Menüye Dön',
                          icon: Icons.home_rounded,
                          onTap: () => Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const WelcomeScreen()),
                            (r) => false,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── SCORE CARD ────────────────────────────────────────────────────────────

  Widget _buildScoreCard() {
    return _GradientBorderBox(
      borderRadius: 24,
      borderWidth: 1.5,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFB3DFFF), Color(0xFF0D47A1), Color(0xFF42A5F5)],
        stops: [0.0, 0.5, 1.0],
      ),
      outerShadows: const [
        BoxShadow(
          color: Color(0xAA0D47A1),
          blurRadius: 50,
          spreadRadius: -5,
          offset: Offset(0, 14),
        ),
        BoxShadow(
          color: Color(0x4442A5F5),
          blurRadius: 80,
          spreadRadius: -20,
        ),
      ],
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22.5),
        child: Stack(
          children: [
            // Base dark gradient
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF060D22), Color(0xFF0A1535), Color(0xFF091228)],
                  ),
                ),
              ),
            ),
            // Dot texture
            Positioned.fill(child: CustomPaint(painter: _DotPatternPainter())),
            // Radial glow behind score number
            Positioned(
              left: 0,
              right: 0,
              top: 70,
              child: Center(
                child: Container(
                  width: 160,
                  height: 100,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x551565C0),
                        blurRadius: 80,
                        spreadRadius: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Top highlight bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 2,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Color(0xCCB3DFFF),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
              child: Column(
                children: [
                  // Trophy icon
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [Color(0x4042A5F5), Color(0x0042A5F5)],
                      ),
                      border: Border.all(color: const Color(0x6090CAF9), width: 1),
                    ),
                    child: const Icon(
                      Icons.emoji_events_rounded,
                      color: Color(0xFFFFD740),
                      size: 24,
                      shadows: [
                        Shadow(color: Color(0xAAFFD740), blurRadius: 12),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Label
                  Text(
                    'TOPLAM SKOR',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.45),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Score number
                  ShaderMask(
                    shaderCallback: (b) => const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.white, Color(0xFFBBDEFB)],
                    ).createShader(b),
                    child: Text(
                      '${widget.skor}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 88,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                        letterSpacing: -2,
                        shadows: [
                          Shadow(color: Color(0xFF82B1FF), blurRadius: 16),
                          Shadow(color: Color(0xFF1565C0), blurRadius: 40),
                          Shadow(color: Color(0x881565C0), blurRadius: 80),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Separator
                  Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [
                        Colors.transparent,
                        Color(0xAA90CAF9),
                        Colors.transparent,
                      ]),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Info chips
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _InfoChip(
                        icon: Icons.bar_chart_rounded,
                        label: _zorlukLabel(widget.zorluk),
                        color: _zorlukColor(widget.zorluk),
                      ),
                      const SizedBox(width: 10),
                      _InfoChip(
                        icon: Icons.timer_rounded,
                        label: '${widget.sure} sn',
                        color: const Color(0xFF90CAF9),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── STAT GRID ─────────────────────────────────────────────────────────────

  Widget _buildStatGrid() {
    final stats = [
      _StatData(
        label: 'Doğru',
        value: '${widget.dogruSayisi}',
        icon: Icons.check_circle_rounded,
        accent: const Color(0xFF00E676),
        darkBg: const Color(0xFF051A0A),
        midBg: const Color(0xFF0A2E12),
      ),
      _StatData(
        label: 'Yanlış',
        value: '${widget.yanlisSayisi}',
        icon: Icons.cancel_rounded,
        accent: const Color(0xFFFF5252),
        darkBg: const Color(0xFF1A0404),
        midBg: const Color(0xFF2E0808),
      ),
      _StatData(
        label: 'Pas',
        value: '${widget.pasSayisi}',
        icon: Icons.skip_next_rounded,
        accent: const Color(0xFFFFD740),
        darkBg: const Color(0xFF1A1100),
        midBg: const Color(0xFF2E1D00),
      ),
      _StatData(
        label: 'Toplam',
        value: '$_toplamKart',
        icon: Icons.style_rounded,
        accent: const Color(0xFF82B1FF),
        darkBg: const Color(0xFF05091A),
        midBg: const Color(0xFF0D1535),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.65,
      ),
      itemCount: 4,
      itemBuilder: (_, i) => FadeTransition(
        opacity: _statFades[i],
        child: SlideTransition(
          position: _statSlides[i],
          child: _buildStatCard(stats[i]),
        ),
      ),
    );
  }

  Widget _buildStatCard(_StatData d) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [d.midBg, d.darkBg],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: d.accent.withOpacity(0.28), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: d.accent.withOpacity(0.22),
              blurRadius: 20,
              spreadRadius: -6,
              offset: const Offset(0, 6)),
          BoxShadow(
              color: Colors.black.withOpacity(0.55),
              blurRadius: 14,
              spreadRadius: -3,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // Diagonal shine
          Positioned.fill(
            child: CustomPaint(painter: _DiagonalShinePainter(d.accent)),
          ),
          // Top-right corner orb
          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  d.accent.withOpacity(0.10),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          // Top highlight line
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 1.5,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  Colors.transparent,
                  d.accent.withOpacity(0.45),
                  Colors.transparent,
                ]),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // Circular icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: d.accent.withOpacity(0.12),
                    border: Border.all(color: d.accent.withOpacity(0.35), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                          color: d.accent.withOpacity(0.3),
                          blurRadius: 10,
                          spreadRadius: -3),
                    ],
                  ),
                  child: Icon(d.icon, color: d.accent, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.value,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          height: 1.05,
                          shadows: [
                            Shadow(color: d.accent.withOpacity(0.7), blurRadius: 10),
                            Shadow(color: d.accent.withOpacity(0.3), blurRadius: 24),
                          ],
                        ),
                      ),
                      Text(
                        d.label,
                        style: TextStyle(
                          color: d.accent.withOpacity(0.75),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── ACCURACY BAR ──────────────────────────────────────────────────────────

  Widget _buildAccuracyBar() {
    final oran = _dogrulukOrani;
    final Color barColor = oran >= 70
        ? const Color(0xFF00E676)
        : oran >= 40
            ? const Color(0xFFFFD740)
            : const Color(0xFFFF5252);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.07),
            Colors.white.withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.10), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: barColor.withOpacity(0.12),
              blurRadius: 20,
              spreadRadius: -4,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Icon(Icons.track_changes_rounded, color: barColor, size: 15),
                const SizedBox(width: 6),
                const Text(
                  'Doğruluk Oranı',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3),
                ),
              ]),
              AnimatedBuilder(
                animation: _barFill,
                builder: (_, __) => Text(
                  '%${(_dogrulukOrani * _barFill.value).toStringAsFixed(0)}',
                  style: TextStyle(
                    color: barColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(color: barColor.withOpacity(0.55), blurRadius: 10),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Track
          Container(
            height: 12,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white.withOpacity(0.06),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AnimatedBuilder(
                animation: Listenable.merge([_barFill, _sweepCtrl]),
                builder: (_, __) {
                  final fill = (oran / 100) * _barFill.value;
                  final sweep = _sweepCtrl.value;
                  return Stack(
                    children: [
                      // Fill bar
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: fill,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [barColor.withOpacity(0.6), barColor],
                            ),
                          ),
                        ),
                      ),
                      // Sweep light — only visible on filled portion
                      if (_barCtrl.isCompleted)
                        Positioned.fill(
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: fill,
                            child: ShaderMask(
                              shaderCallback: (b) => LinearGradient(
                                begin: Alignment(sweep * 3 - 1.5, 0),
                                end: Alignment(sweep * 3 - 0.8, 0),
                                colors: [
                                  Colors.transparent,
                                  Colors.white.withOpacity(0.55),
                                  Colors.transparent,
                                ],
                              ).createShader(b),
                              blendMode: BlendMode.srcATop,
                              child: Container(color: Colors.white),
                            ),
                          ),
                        ),
                      // Top shine layer
                      Positioned.fill(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: FractionallySizedBox(
                            heightFactor: 0.4,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.white.withOpacity(0.22),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── BUTTONS ───────────────────────────────────────────────────────────────

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color primary,
    required Color secondary,
    required VoidCallback onTap,
  }) {
    return _PressableButton(
      onTap: onTap,
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [primary, secondary],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: primary.withOpacity(0.55), width: 1.5),
          boxShadow: [
            BoxShadow(
                color: primary.withOpacity(0.45),
                blurRadius: 24,
                spreadRadius: -5,
                offset: const Offset(0, 6)),
            BoxShadow(
                color: primary.withOpacity(0.18),
                blurRadius: 48,
                spreadRadius: -8,
                offset: const Offset(0, 10)),
          ],
        ),
        child: Stack(
          children: [
            // Top shine strip
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 28,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.18),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Label
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      shadows: [
                        Shadow(color: Colors.black26, blurRadius: 6),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return _PressableButton(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.22), width: 1.5),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 12,
                spreadRadius: -3,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Ana Menüye Dön',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _zorlukLabel(String z) {
    switch (z) {
      case 'kolay':
        return 'Kolay';
      case 'orta':
        return 'Orta';
      case 'zor':
        return 'Zor';
      case 'karışık':
        return 'Karışık';
      default:
        return z;
    }
  }

  Color _zorlukColor(String z) {
    switch (z) {
      case 'kolay':
        return const Color(0xFF00E676);
      case 'orta':
        return const Color(0xFFFFD740);
      case 'zor':
        return const Color(0xFFFF5252);
      default:
        return const Color(0xFFCE93D8);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable widgets
// ─────────────────────────────────────────────────────────────────────────────

class _GradientBorderBox extends StatelessWidget {
  final Widget child;
  final Gradient gradient;
  final List<BoxShadow> outerShadows;
  final double borderRadius;
  final double borderWidth;

  const _GradientBorderBox({
    required this.child,
    required this.gradient,
    required this.outerShadows,
    required this.borderRadius,
    required this.borderWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: outerShadows,
      ),
      padding: EdgeInsets.all(borderWidth),
      child: child,
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.30), width: 1),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.15), blurRadius: 8, spreadRadius: -2),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _PressableButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _PressableButton({required this.child, required this.onTap});

  @override
  State<_PressableButton> createState() => _PressableButtonState();
}

class _PressableButtonState extends State<_PressableButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.94)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom painters
// ─────────────────────────────────────────────────────────────────────────────

/// Subtle dot-grid texture for the score card background.
class _DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.032)
      ..style = PaintingStyle.fill;
    const spacing = 18.0;
    const r = 1.2;
    for (double x = spacing / 2; x < size.width; x += spacing) {
      for (double y = spacing / 2; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), r, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

/// Diagonal light streak for stat card depth effect.
class _DiagonalShinePainter extends CustomPainter {
  final Color color;
  _DiagonalShinePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: const Alignment(-1.6, -1.6),
        end: const Alignment(0.4, 0.4),
        colors: [
          Colors.transparent,
          color.withOpacity(0.07),
          Colors.transparent,
        ],
        stops: const [0.35, 0.5, 0.65],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _DiagonalShinePainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────────

class _StatData {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final Color darkBg;
  final Color midBg;

  const _StatData({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    required this.darkBg,
    required this.midBg,
  });
}
