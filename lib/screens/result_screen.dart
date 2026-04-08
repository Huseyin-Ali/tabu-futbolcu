import 'package:flutter/material.dart';
import '../widgets/background_with_logo.dart';
import '../widgets/app_back_button.dart';
import '../widgets/common_title.dart';

class ResultScreen extends StatelessWidget {
  final String takim1Ismi;
  final String takim2Ismi;
  final int takim1Skor;
  final int takim2Skor;

  const ResultScreen({
    Key? key,
    required this.takim1Ismi,
    required this.takim2Ismi,
    required this.takim1Skor,
    required this.takim2Skor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String kazanan = takim1Skor > takim2Skor
        ? takim1Ismi
        : takim2Skor > takim1Skor
            ? takim2Ismi
            : 'Berabere';

    return Scaffold(
      body: Stack(
        children: [
          BackgroundWithLogo(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CommonTitle('Maç Sonucu'),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Column(
                        children: [
                          Text(
                            takim1Ismi,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$takim1Skor',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'VS',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            takim2Ismi,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$takim2Skor',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Kazanan: $kazanan',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.popUntil(context, (route) => route.isFirst);
                      },
                      child: const Text('Ana Menüye Dön'),
                    ),
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
}
