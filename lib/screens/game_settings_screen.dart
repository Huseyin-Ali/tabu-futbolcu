import 'package:flutter/material.dart';
import '../widgets/background_with_logo.dart';
import '../widgets/app_back_button.dart';
import '../widgets/common_title.dart';
import '../widgets/common_card.dart';
import 'game_screen.dart' as game;
import '../constants/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GameSettingsScreen extends StatefulWidget {
  const GameSettingsScreen({Key? key}) : super(key: key);

  @override
  State<GameSettingsScreen> createState() => _GameSettingsScreenState();
}

class _GameSettingsScreenState extends State<GameSettingsScreen> {
  int _zamanLimiti = 60;
  int _pasHakki = 3;
  int _tabuCezasi = 2;
  int _puanHedefi = 50;
  bool _takim1Sirasi = true;
  String _takim1Ismi = '';
  String _takim2Ismi = '';
  String _kartTipi = AppConstants.defaultTabuKartTipi;

  static const List<String> _kartTipiSecenekleri = [
    'aktif',
    'veteran',
    'karışık',
  ];

  @override
  void initState() {
    super.initState();
    _ayarYukle();
  }

  Future<void> _ayarYukle() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _zamanLimiti = prefs.getInt(AppConstants.keyZamanLimiti) ??
          AppConstants.defaultZamanLimiti;
      _pasHakki =
          prefs.getInt(AppConstants.keyPasHakki) ?? AppConstants.defaultPasHakki;
      _tabuCezasi = prefs.getInt(AppConstants.keyTabuCezasi) ??
          AppConstants.defaultTabuCezasi;
      _puanHedefi =
          prefs.getInt(AppConstants.keyPuanHedefi) ?? AppConstants.defaultPuanHedefi;
      _takim1Sirasi = prefs.getBool(AppConstants.keyTakim1Sirasi) ?? true;
      _takim1Ismi = prefs.getString(AppConstants.keyTakim1Ismi) ?? '';
      _takim2Ismi = prefs.getString(AppConstants.keyTakim2Ismi) ?? '';
      _kartTipi = prefs.getString(AppConstants.keyTabuKartTipi) ??
          AppConstants.defaultTabuKartTipi;
    });
  }

  Future<void> _ayarlariKaydet() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConstants.keyZamanLimiti, _zamanLimiti);
    await prefs.setInt(AppConstants.keyPasHakki, _pasHakki);
    await prefs.setInt(AppConstants.keyTabuCezasi, _tabuCezasi);
    await prefs.setInt(AppConstants.keyPuanHedefi, _puanHedefi);
    await prefs.setBool(AppConstants.keyTakim1Sirasi, _takim1Sirasi);
    await prefs.setString(AppConstants.keyTakim1Ismi, _takim1Ismi);
    await prefs.setString(AppConstants.keyTakim2Ismi, _takim2Ismi);
    await prefs.setString(AppConstants.keyTabuKartTipi, _kartTipi);
  }

  // FittedBox yalnızca kart içindeki kısa metin için — tüm ekran değil.
  Widget _ayarCard({
    required String label,
    required int value,
    required VoidCallback onInc,
    required VoidCallback onDec,
    String? unit,
    int min = 1,
    int max = 120,
    required EdgeInsetsGeometry cardPad,
    required double iconMinSize,
  }) {
    return CommonCard(
      padding: cardPad,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            constraints:
                BoxConstraints(minWidth: iconMinSize, minHeight: iconMinSize),
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.chevron_left, color: Colors.white, size: 20),
            onPressed: value > min ? onDec : null,
          ),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                unit == null
                    ? '$label: $value'
                    : label == 'Süre'
                        ? '$label: $value SANİYE'
                        : label == 'Pas Hakkı'
                            ? '$label: $value PAS'
                            : '$label: $value',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
          IconButton(
            constraints:
                BoxConstraints(minWidth: iconMinSize, minHeight: iconMinSize),
            padding: EdgeInsets.zero,
            icon:
                const Icon(Icons.chevron_right, color: Colors.white, size: 20),
            onPressed: value < max ? onInc : null,
          ),
        ],
      ),
    );
  }

  Widget _kartTipiSecimi({
    required double cardGap,
    required bool isUltraCompact,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: cardGap),
        Text(
          'Kart Tipi',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: isUltraCompact ? 14 : 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: cardGap),
        Row(
          children: _kartTipiSecenekleri.map((tip) {
            final selected = _kartTipi == tip;
            final color = _kartTipiRengi(tip);
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: tip == _kartTipiSecenekleri.first ? 0 : 4,
                  right: tip == _kartTipiSecenekleri.last ? 0 : 4,
                ),
                child: GestureDetector(
                  onTap: () => setState(() => _kartTipi = tip),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    alignment: Alignment.center,
                    padding: EdgeInsets.symmetric(
                      vertical: isUltraCompact ? 8 : 10,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? color.withOpacity(0.25)
                          : Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? color
                            : Colors.white.withOpacity(0.3),
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      _kartTipiEtiketi(tip),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isUltraCompact ? 12 : 14,
                        fontWeight:
                            selected ? FontWeight.bold : FontWeight.normal,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  String _kartTipiEtiketi(String tip) {
    switch (tip) {
      case 'aktif':
        return 'Aktif';
      case 'veteran':
        return 'Veteran';
      case 'karışık':
        return 'Karışık';
      default:
        return tip;
    }
  }

  Color _kartTipiRengi(String tip) {
    switch (tip) {
      case 'aktif':
        return Colors.lightBlueAccent;
      case 'veteran':
        return Colors.amber;
      case 'karışık':
        return Colors.purpleAccent;
      default:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          BackgroundWithLogo(
            // BackgroundWithLogo: arka plan + logo üstte, içerik logonun altında.
            // LayoutBuilder burada logoTopPadding sonrası kalan yüksekliği verir.
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availH = constraints.maxHeight;

                // ── 3 Tier Threshold ─────────────────────────────────────
                // availH = ekran yüksekliği − safeArea − logoTopPadding(175dp)
                //
                // Ultra compact (availH < 370):
                //   titleH  = 6+6+28 = 40dp
                //   cardsH  = 4×56 + 3×3 = 233dp  (iconMin=36, pad=v:4)
                //   btnArea = 4+48+4 = 56dp
                //   Toplam  = 40+4+233+56 = 333dp → 370dp'de 37dp fazla ✓
                //
                // Compact (370–430):
                //   titleH  = 8+8+28 = 44dp
                //   cardsH  = 4×56 + 3×4 = 236dp  (iconMin=36, pad=v:6)
                //   btnArea = 6+48+6 = 60dp
                //   Toplam  = 44+4+236+60 = 344dp → 370dp'de 26dp fazla ✓
                //
                // Normal (≥430):
                //   titleH  = 12+12+28 = 52dp
                //   cardsH  = 4×60 + 3×8 = 264dp  (iconMin=44, pad=v:8)
                //   btnArea = 10+48+10 = 68dp
                //   Toplam  = 52+4+264+68 = 388dp → 430dp'de 42dp fazla ✓
                // ─────────────────────────────────────────────────────────

                final bool isUltraCompact = availH < 370;
                final bool isCompact = availH < 430;

                final double titleVertPad =
                    isUltraCompact ? 6 : isCompact ? 8 : 12;
                final double cardVertPad =
                    isUltraCompact ? 4 : isCompact ? 6 : 8;
                final double cardHorizPad =
                    isUltraCompact ? 8 : isCompact ? 12 : 16;
                final double cardGap =
                    isUltraCompact ? 3 : isCompact ? 4 : 8;
                final double btnVertPad =
                    isUltraCompact ? 4 : isCompact ? 6 : 10;
                final double iconMinSize =
                    isUltraCompact ? 36 : isCompact ? 36 : 44;

                final cardPad = EdgeInsets.symmetric(
                    vertical: cardVertPad, horizontal: cardHorizPad);

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── BÖLGE 1: Başlık ───────────────────────────────
                      CommonTitle(
                        'Oyun Ayarları',
                        padding:
                            EdgeInsets.symmetric(vertical: titleVertPad),
                      ),
                      const SizedBox(height: 4),

                      // ── BÖLGE 2: Kartlar (Expanded) ───────────────────
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _ayarCard(
                              label: 'Süre',
                              value: _zamanLimiti,
                              unit: ' sn',
                              min: 30,
                              max: 300,
                              cardPad: cardPad,
                              iconMinSize: iconMinSize,
                              onInc: () => setState(() => _zamanLimiti =
                                  (_zamanLimiti + 15 <= 300)
                                      ? _zamanLimiti + 15
                                      : 300),
                              onDec: () => setState(() => _zamanLimiti =
                                  (_zamanLimiti - 15 >= 30)
                                      ? _zamanLimiti - 15
                                      : 30),
                            ),
                            SizedBox(height: cardGap),
                            _ayarCard(
                              label: 'Pas Hakkı',
                              value: _pasHakki,
                              min: 0,
                              max: 5,
                              cardPad: cardPad,
                              iconMinSize: iconMinSize,
                              onInc: () => setState(() => _pasHakki++),
                              onDec: () => setState(() => _pasHakki--),
                            ),
                            SizedBox(height: cardGap),
                            _ayarCard(
                              label: 'Tabu Cezası',
                              value: _tabuCezasi,
                              unit: ' puan',
                              min: 0,
                              max: 10,
                              cardPad: cardPad,
                              iconMinSize: iconMinSize,
                              onInc: () => setState(() => _tabuCezasi++),
                              onDec: () => setState(() => _tabuCezasi--),
                            ),
                            SizedBox(height: cardGap),
                            _ayarCard(
                              label: 'Puan Hedefi',
                              value: _puanHedefi,
                              unit: ' puan',
                              min: 10,
                              max: 100,
                              cardPad: cardPad,
                              iconMinSize: iconMinSize,
                              onInc: () => setState(() => _puanHedefi =
                                  (_puanHedefi + 5 <= 100)
                                      ? _puanHedefi + 5
                                      : 100),
                              onDec: () => setState(() => _puanHedefi =
                                  (_puanHedefi - 5 >= 10)
                                      ? _puanHedefi - 5
                                      : 10),
                            ),
                            _kartTipiSecimi(
                              cardGap: cardGap,
                              isUltraCompact: isUltraCompact,
                            ),
                          ],
                        ),
                      ),
                      ),

                      // ── BÖLGE 3: Buton (her zaman görünür) ───────────
                      SizedBox(height: btnVertPad),
                      Center(
                        child: ElevatedButton(
                          onPressed: () async {
                            await _ayarlariKaydet();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => game.GameScreen(
                                  oyuncu1Adi: _takim1Ismi,
                                  oyuncu2Adi: _takim2Ismi,
                                  turSayisi: 10,
                                  sure: _zamanLimiti,
                                  kartTipi: _kartTipi,
                                ),
                              ),
                            );
                          },
                          child: const Text('Kaydet'),
                        ),
                      ),
                      SizedBox(height: btnVertPad),
                    ],
                  ),
                );
              },
            ),
          ),
          const AppBackButton(),
        ],
      ),
    );
  }
}
