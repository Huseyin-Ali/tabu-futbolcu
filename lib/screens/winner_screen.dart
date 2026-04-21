import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/background_with_logo.dart';
import 'package:confetti/confetti.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/game_history.dart';
import '../constants/app_constants.dart';

class WinnerScreen extends StatefulWidget {
  final String takim1Ismi;
  final String takim2Ismi;
  final int takim1Skor;
  final int takim2Skor;
  final int puanHedefi;

  const WinnerScreen({
    Key? key,
    required this.takim1Ismi,
    required this.takim2Ismi,
    required this.takim1Skor,
    required this.takim2Skor,
    required this.puanHedefi,
  }) : super(key: key);

  @override
  State<WinnerScreen> createState() => _WinnerScreenState();
}

class _WinnerScreenState extends State<WinnerScreen>
    with TickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _pulseController;
  late AnimationController _trophyController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _trophyAnimation;

  @override
  void initState() {
    super.initState();

    // Confetti animasyonu
    _confettiController = ConfettiController(duration: const Duration(seconds: 5));
    _confettiController.play();

    // Pulse animasyonu (kazanan takım için)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Trophy animasyonu
    _trophyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _trophyAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _trophyController, curve: Curves.elasticOut),
    );

    // Haptic feedback (titreşim)
    HapticFeedback.mediumImpact();

    // Oyun geçmişine kaydet
    _oyunGecmisineKaydet();

  }

  void _oyunGecmisineKaydet() {
    final gameHistory = GameHistory(
      takim1Ismi: widget.takim1Ismi,
      takim2Ismi: widget.takim2Ismi,
      takim1Skor: widget.takim1Skor,
      takim2Skor: widget.takim2Skor,
      tarih: DateTime.now(),
    );

    final box = Hive.box<GameHistory>(AppConstants.gameHistoryBox);
    box.add(gameHistory);
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _pulseController.dispose();
    _trophyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kazananTakim = widget.takim1Skor > widget.takim2Skor
        ? widget.takim1Ismi
        : widget.takim2Ismi;

    return Scaffold(
      body: BackgroundWithLogo(
        child: Stack(
          children: [
            // Confetti efekti
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirection: 3.14 / 2,
                maxBlastForce: 5,
                minBlastForce: 2,
                emissionFrequency: 0.05,
                numberOfParticles: 50,
                gravity: 0.1,
              ),
            ),
            // Ana içerik
            Center(
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final screenHeight = constraints.maxHeight;
                    final titleSize = screenHeight * 0.035;
                    final teamNameSize = screenHeight * 0.025;
                    final scoreSize = screenHeight * 0.05;

                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 20),
                          // Trophy icon animasyonu
                          AnimatedBuilder(
                            animation: _trophyAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: 0.8 + (_trophyAnimation.value * 0.2),
                                child: Transform.rotate(
                                  angle: (1 - _trophyAnimation.value) * 0.1,
                                  child: Icon(
                                    Icons.emoji_events,
                                    size: 80,
                                    color: Colors.amber,
                                    shadows: [
                                      Shadow(
                                        color: Colors.amber.withOpacity(0.8),
                                        blurRadius: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          // Kazanan takım - pulse animasyonu ile
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _pulseAnimation.value,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 12),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.amber.shade400,
                                        Colors.orange.shade600,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.amber.withOpacity(0.5),
                                        blurRadius: 20,
                                        spreadRadius: 5,
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    'KAZANAN: $kazananTakim',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: titleSize,
                                      fontWeight: FontWeight.bold,
                                      shadows: [
                                        const Shadow(
                                          color: Colors.black54,
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 24),
                          // Skor kartları
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildScoreCard(
                                teamName: widget.takim1Ismi,
                                score: widget.takim1Skor,
                                isWinner: widget.takim1Skor > widget.takim2Skor,
                                teamNameSize: teamNameSize,
                                scoreSize: scoreSize,
                              ),
                              const SizedBox(width: 16),
                              _buildScoreCard(
                                teamName: widget.takim2Ismi,
                                score: widget.takim2Skor,
                                isWinner: widget.takim2Skor > widget.takim1Skor,
                                teamNameSize: teamNameSize,
                                scoreSize: scoreSize,
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              Navigator.of(context)
                                  .popUntil((route) => route.isFirst);
                            },
                            icon: const Icon(Icons.home),
                            label: const Text('Ana Menüye Dön'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              textStyle: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreCard({
    required String teamName,
    required int score,
    required bool isWinner,
    required double teamNameSize,
    required double scoreSize,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isWinner
            ? Colors.green.withOpacity(0.3)
            : Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isWinner ? Colors.green : Colors.white.withOpacity(0.3),
          width: isWinner ? 3 : 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            teamName,
            style: TextStyle(
              color: Colors.white,
              fontSize: teamNameSize,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '$score',
            style: TextStyle(
              color: isWinner ? Colors.green.shade300 : Colors.white,
              fontSize: scoreSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (isWinner) ...[
            const SizedBox(height: 4),
            Icon(
              Icons.star,
              color: Colors.amber,
              size: 20,
            ),
          ],
        ],
      ),
    );
  }
}
