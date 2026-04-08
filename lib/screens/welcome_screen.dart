import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'team_setup_screen.dart';
import '../widgets/background_with_logo.dart';
import 'game_history_screen.dart';
import '../constants/app_constants.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  Future<String> _loadHowToPlayText() async {
    try {
      return await rootBundle.loadString(AppConstants.assetNasilOynanir);
    } catch (e) {
      return 'Metin yüklenirken bir hata oluştu.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BackgroundWithLogo(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Logo zaten BackgroundWithLogo'da
            const SizedBox(height: 10),
            // TABU kutuları ve FUTFOLCU yazısı
            Center(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _tabuBox('T', Colors.red),
                      const SizedBox(width: 4),
                      _tabuBox('A', Colors.blue),
                      const SizedBox(width: 4),
                      _tabuBox('B', Colors.green),
                      const SizedBox(width: 4),
                      _tabuBox('U', Colors.yellow[700]!),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'FUTBOLCU',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 4,
                      shadows: [
                        Shadow(
                          color: Colors.black54,
                          offset: Offset(2, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Menü seçenekleri
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _menuButton('Yeni Oyun', onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TeamSetupScreen(),
                      ),
                    );
                  }),
                  _menuButton('Kirli Defter', onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const GameHistoryScreen(),
                      ),
                    );
                  }),
                  _menuButton('Özel Oyuncu Kartları', isLoading: true),
                  _menuButton('Nasıl Oynanır', onTap: () async {
                    final howToPlayText = await _loadHowToPlayText();
                    if (!context.mounted) return;

                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          backgroundColor: Colors.white,
                          contentPadding:
                              const EdgeInsets.fromLTRB(24, 32, 24, 24),
                          content: SingleChildScrollView(
                            child: Text(
                              howToPlayText,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                                height: 1.5,
                              ),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: const Text(
                                'Anladım',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  }),
                  _menuButton('Çıkış', onTap: () => SystemNavigator.pop()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuButton(String text, {VoidCallback? onTap, bool isLoading = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: Colors.black54,
                    offset: Offset(1, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            if (isLoading) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.hourglass_empty,
                size: 16,
                color: Colors.white.withOpacity(0.7),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tabuBox(String letter, Color color) {
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Text(
        letter,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 32,
          fontWeight: FontWeight.bold,
          fontFamily: 'Comic Sans MS',
          shadows: [
            Shadow(
              color: Colors.black54,
              offset: Offset(1, 1),
              blurRadius: 2,
            ),
          ],
        ),
      ),
    );
  }
}
