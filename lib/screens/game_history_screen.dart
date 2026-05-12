import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../constants/app_constants.dart';
import '../models/career_game_history.dart';
import '../models/game_history.dart';
import '../utils/logger.dart';
import '../widgets/app_back_button.dart';
import '../widgets/background_with_logo.dart';
import '../widgets/common_title.dart';

class GameHistoryScreen extends StatefulWidget {
  const GameHistoryScreen({Key? key}) : super(key: key);

  @override
  State<GameHistoryScreen> createState() => _GameHistoryScreenState();
}

class _GameHistoryScreenState extends State<GameHistoryScreen> {
  // 'tabu' | 'career'
  String _seciliMod = 'tabu';

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      AppLogger.info('[GameHistory] Seçili mod: $_seciliMod');
    }

    return Scaffold(
      body: Stack(
        children: [
          BackgroundWithLogo(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CommonTitle('Kirli Defter'),
                    const SizedBox(height: 16),
                    _buildModSecici(),
                    const SizedBox(height: 20),
                    Expanded(child: _buildListe()),
                  ],
                ),
              ),
            ),
          ),
          const AppBackButton(),
        ],
      ),
    );
  }

  // ── Mod Seçici ────────────────────────────────────────────────────────────

  Widget _buildModSecici() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _modButon(
            label: 'Tabu Oyunu',
            icon: Icons.sports_soccer,
            aktif: _seciliMod == 'tabu',
            onTap: () => setState(() => _seciliMod = 'tabu'),
          ),
          _modButon(
            label: 'Kariyer Avı',
            icon: Icons.emoji_events_outlined,
            aktif: _seciliMod == 'career',
            onTap: () => setState(() => _seciliMod = 'career'),
          ),
        ],
      ),
    );
  }

  Widget _modButon({
    required String label,
    required IconData icon,
    required bool aktif,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: aktif
                ? const Color(0xFF1565C0).withOpacity(0.85)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: aktif
                ? [
                    BoxShadow(
                      color: Colors.blueAccent.withOpacity(0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: aktif ? Colors.white : Colors.white54,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: aktif ? Colors.white : Colors.white54,
                  fontWeight:
                      aktif ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Liste ─────────────────────────────────────────────────────────────────

  Widget _buildListe() {
    if (_seciliMod == 'tabu') {
      return _buildTabuListe();
    }
    return _buildKariyerListe();
  }

  // Tabu geçmişi — mevcut mantık korundu
  Widget _buildTabuListe() {
    return ValueListenableBuilder(
      valueListenable:
          Hive.box<GameHistory>(AppConstants.gameHistoryBox).listenable(),
      builder: (context, Box<GameHistory> box, _) {
        final oyunlar = box.values.toList()
          ..sort((a, b) => b.tarih.compareTo(a.tarih));

        if (kDebugMode) {
          AppLogger.info(
              '[GameHistory] Tabu kayıt sayısı: ${oyunlar.length}');
        }

        if (oyunlar.isEmpty) {
          return _bosEkran('Bu mod için henüz oyun geçmişi yok.');
        }

        return ListView.builder(
          itemCount: oyunlar.length,
          itemBuilder: (context, index) =>
              _buildTabuKart(oyunlar[index]),
        );
      },
    );
  }

  Widget _buildTabuKart(GameHistory oyun) {
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');
    return Container(
      padding:
          const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  oyun.takim1Skor > oyun.takim2Skor
                      ? oyun.takim1Ismi
                      : oyun.takim2Ismi,
                  style: TextStyle(
                    color: oyun.takim1Skor > oyun.takim2Skor
                        ? Colors.green
                        : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  dateFormat.format(oyun.tarih),
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            '${oyun.takim1Skor} - ${oyun.takim2Skor}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              oyun.takim2Ismi,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: oyun.takim2Skor > oyun.takim1Skor
                    ? Colors.green
                    : Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Kariyer Avı geçmişi — gameBox içindeki Map listesinden okur
  Widget _buildKariyerListe() {
    return ValueListenableBuilder(
      valueListenable: Hive.box(AppConstants.gameBox).listenable(
        keys: [AppConstants.kariyerGecmisKey],
      ),
      builder: (context, Box box, _) {
        final rawList = box.get(AppConstants.kariyerGecmisKey) ?? [];
        final oyunlar = (rawList as List)
            .map((e) =>
                CareerGameHistory.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList()
          ..sort((a, b) => b.tarih.compareTo(a.tarih));

        if (kDebugMode) {
          AppLogger.info(
              '[GameHistory] Kariyer kayıt sayısı: ${oyunlar.length}');
        }

        if (oyunlar.isEmpty) {
          return _bosEkran('Bu mod için henüz oyun geçmişi yok.');
        }

        return ListView.builder(
          itemCount: oyunlar.length,
          itemBuilder: (context, index) =>
              _buildKariyerKart(oyunlar[index]),
        );
      },
    );
  }

  Widget _buildKariyerKart(CareerGameHistory oyun) {
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');
    final zorlukRengi = _zorlukRengi(oyun.zorluk);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Üst satır: mod adı + tarih
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.emoji_events_outlined,
                      color: Color(0xFFFFD700), size: 16),
                  const SizedBox(width: 6),
                  const Text(
                    'Kariyer Avı',
                    style: TextStyle(
                      color: Color(0xFFFFD700),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              Text(
                dateFormat.format(oyun.tarih),
                style: const TextStyle(
                    color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Skor — büyük
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${oyun.skor}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(width: 6),
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(
                  'puan',
                  style:
                      TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
              const Spacer(),
              // Başarı oranı
              _oranBadge(oyun.basariOrani),
            ],
          ),
          const SizedBox(height: 10),

          // ── İstatistik satırı
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _statChip(
                  Icons.check_circle_outline, '${oyun.dogruSayisi}',
                  color: const Color(0xFF4CAF50)),
              _statChip(Icons.cancel_outlined, '${oyun.yanlisSayisi}',
                  color: const Color(0xFFEF5350)),
              _statChip(Icons.skip_next, '${oyun.pasSayisi}',
                  color: const Color(0xFFFFB300)),
              _statChip(Icons.style_outlined,
                  '${oyun.oynanankartSayisi} kart',
                  color: Colors.white54),
            ],
          ),
          const SizedBox(height: 10),

          // ── Alt satır: zorluk + süre + max combo
          Row(
            children: [
              _pillBadge(
                  oyun.zorluk[0].toUpperCase() + oyun.zorluk.substring(1),
                  zorlukRengi),
              const SizedBox(width: 8),
              _pillBadge('${oyun.sure} sn', Colors.white24),
              if (oyun.maxCombo > 0) ...[
                const SizedBox(width: 8),
                _pillBadge('🔥 x${oyun.maxCombo}', Colors.deepOrangeAccent),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ── Yardımcı widget'lar ───────────────────────────────────────────────────

  Widget _bosEkran(String mesaj) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off,
              size: 52, color: Colors.white.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            mesaj,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _oranBadge(double oran) {
    Color renk;
    if (oran >= 70) {
      renk = const Color(0xFF4CAF50);
    } else if (oran >= 40) {
      renk = const Color(0xFFFFB300);
    } else {
      renk = const Color(0xFFEF5350);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: renk.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: renk.withOpacity(0.6)),
      ),
      child: Text(
        '%${oran.toStringAsFixed(0)}',
        style: TextStyle(
          color: renk,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _statChip(IconData icon, String label, {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color ?? Colors.white70),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                color: color ?? Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _pillBadge(String label, Color color) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color == Colors.white24 ? Colors.white70 : color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _zorlukRengi(String zorluk) {
    switch (zorluk.toLowerCase()) {
      case 'kolay':
        return const Color(0xFF4CAF50);
      case 'orta':
        return const Color(0xFFFFB300);
      case 'zor':
        return const Color(0xFFEF5350);
      default:
        return Colors.white54;
    }
  }
}
