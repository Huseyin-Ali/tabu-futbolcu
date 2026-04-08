import 'package:flutter/material.dart';
import '../widgets/background_with_logo.dart';
import '../widgets/app_back_button.dart';
import '../widgets/common_title.dart';
import '../widgets/common_card.dart';
import 'game_settings_screen.dart';
import '../storage/hive_game_storage.dart';

class TeamSetupScreen extends StatefulWidget {
  const TeamSetupScreen({super.key});

  @override
  State<TeamSetupScreen> createState() => _TeamSetupScreenState();
}

class _TeamSetupScreenState extends State<TeamSetupScreen> {
  final _takim1Controller = TextEditingController();
  final _takim2Controller = TextEditingController();
  int _takim1OyuncuSayisi = 1;
  int _takim2OyuncuSayisi = 1;

  @override
  void initState() {
    super.initState();
    _takimBilgileriniYukle();
  }

  @override
  void dispose() {
    _takim1Controller.dispose();
    _takim2Controller.dispose();
    super.dispose();
  }

  void _takimBilgileriniYukle() {
    try {
      final takim1 = HiveGameStorage.getirTakim1();
      final takim2 = HiveGameStorage.getirTakim2();
      if (takim1 != null) {
        _takim1Controller.text = takim1['takim']?.toString() ?? '';
        _takim1OyuncuSayisi = takim1['oyuncuSayisi'] as int? ?? 1;
      }
      if (takim2 != null) {
        _takim2Controller.text = takim2['takim']?.toString() ?? '';
        _takim2OyuncuSayisi = takim2['oyuncuSayisi'] as int? ?? 1;
      }
    } catch (e) {
      print('Takım bilgileri yüklenirken hata oluştu: $e');
    }
  }

  void _devamEt() async {
    if (_takim1Controller.text.isEmpty || _takim2Controller.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen takım isimlerini girin')),
      );
      return;
    }
    try {
      await HiveGameStorage.kaydetTakimlar(
        _takim1Controller.text,
        _takim1OyuncuSayisi,
        _takim2Controller.text,
        _takim2OyuncuSayisi,
      );
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const GameSettingsScreen(),
          ),
        );
      }
    } catch (e) {
      print('Takım bilgileri kaydedilirken hata oluştu: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bir hata oluştu: $e')),
        );
      }
    }
  }

  Widget _oyuncuSayisiKontrol({
    required int deger,
    required VoidCallback onAzalt,
    required VoidCallback onArtir,
    required double iconMinSize,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            constraints:
                BoxConstraints(minWidth: iconMinSize, minHeight: iconMinSize),
            padding: EdgeInsets.zero,
            icon: const Text(
              '<',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
            onPressed: onAzalt,
          ),
          Text(
            '$deger',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold),
          ),
          IconButton(
            constraints:
                BoxConstraints(minWidth: iconMinSize, minHeight: iconMinSize),
            padding: EdgeInsets.zero,
            icon: const Text(
              '>',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
            onPressed: onArtir,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true, // klavye açılınca scaffold küçülsün
      body: Stack(
        children: [
          BackgroundWithLogo(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availH = constraints.maxHeight;

                // ── 2 Tier Threshold ─────────────────────────────────────
                // availH = ekran yüksekliği − safeArea − logoTopPadding(175dp)
                //
                // Compact (availH < 370):
                //   titleH  = 8+8+28 = 44dp
                //   cardsH  = 2×(21+64) = 170dp  (label 21 + container 64, pad=v:8)
                //   gap     = 10dp
                //   btnArea = 8+48+8 = 64dp
                //   Toplam  = 44+4+170+10+64 = 292dp → 370dp'de 78dp fazla ✓
                //
                // Normal (availH ≥ 370):
                //   titleH  = 12+12+28 = 52dp
                //   cardsH  = 2×(21+72) = 186dp  (label 21 + container 72, pad=v:12)
                //   gap     = 14dp
                //   btnArea = 12+48+12 = 72dp
                //   Toplam  = 52+4+186+14+72 = 328dp → 370dp'de 42dp fazla ✓
                // ─────────────────────────────────────────────────────────

                final bool isCompact = availH < 370;

                final double titleVertPad = isCompact ? 8 : 12;
                final double cardVertPad  = isCompact ? 8 : 12;
                final double cardGap      = isCompact ? 10 : 14;
                final double btnVertPad   = isCompact ? 8 : 12;
                final double iconMinSize  = isCompact ? 40 : 48;

                final cardPad = EdgeInsets.symmetric(
                    vertical: cardVertPad, horizontal: 16);

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── BÖLGE 1: Başlık ───────────────────────────────
                      CommonTitle(
                        'Takım Belirle',
                        padding:
                            EdgeInsets.symmetric(vertical: titleVertPad),
                      ),
                      const SizedBox(height: 4),

                      // ── BÖLGE 2: Kartlar (Expanded) ───────────────────
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // 1. Takım
                            CommonCard(
                              title: '1.Takım',
                              color: Colors.white.withOpacity(0.2),
                              padding: cardPad,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _takim1Controller,
                                      style: const TextStyle(
                                          color: Colors.white),
                                      textCapitalization:
                                          TextCapitalization.characters,
                                      onChanged: (value) {
                                        _takim1Controller.text =
                                            value.toUpperCase();
                                        _takim1Controller.selection =
                                            TextSelection.fromPosition(
                                          TextPosition(
                                              offset: _takim1Controller
                                                  .text.length),
                                        );
                                      },
                                      decoration: const InputDecoration(
                                        hintText: '1.Takım İsmi',
                                        hintStyle: TextStyle(
                                            color: Colors.white70),
                                        border: InputBorder.none,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  _oyuncuSayisiKontrol(
                                    deger: _takim1OyuncuSayisi,
                                    iconMinSize: iconMinSize,
                                    onAzalt: () {
                                      if (_takim1OyuncuSayisi > 1) {
                                        setState(
                                            () => _takim1OyuncuSayisi--);
                                      }
                                    },
                                    onArtir: () => setState(
                                        () => _takim1OyuncuSayisi++),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: cardGap),
                            // 2. Takım
                            CommonCard(
                              title: '2.Takım',
                              color: Colors.white.withOpacity(0.2),
                              padding: cardPad,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _takim2Controller,
                                      style: const TextStyle(
                                          color: Colors.white),
                                      textCapitalization:
                                          TextCapitalization.characters,
                                      onChanged: (value) {
                                        _takim2Controller.text =
                                            value.toUpperCase();
                                        _takim2Controller.selection =
                                            TextSelection.fromPosition(
                                          TextPosition(
                                              offset: _takim2Controller
                                                  .text.length),
                                        );
                                      },
                                      decoration: const InputDecoration(
                                        hintText: '2.Takım İsmi',
                                        hintStyle: TextStyle(
                                            color: Colors.white70),
                                        border: InputBorder.none,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  _oyuncuSayisiKontrol(
                                    deger: _takim2OyuncuSayisi,
                                    iconMinSize: iconMinSize,
                                    onAzalt: () {
                                      if (_takim2OyuncuSayisi > 1) {
                                        setState(
                                            () => _takim2OyuncuSayisi--);
                                      }
                                    },
                                    onArtir: () => setState(
                                        () => _takim2OyuncuSayisi++),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── BÖLGE 3: Buton (her zaman görünür) ───────────
                      SizedBox(height: btnVertPad),
                      Center(
                        child: ElevatedButton(
                          onPressed: _devamEt,
                          child: const Text('Oyunu Başlat'),
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
