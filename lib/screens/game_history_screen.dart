import 'package:flutter/material.dart';
import '../widgets/background_with_logo.dart';
import '../widgets/app_back_button.dart';
import '../widgets/common_title.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/game_history.dart';
import '../constants/app_constants.dart';

class GameHistoryScreen extends StatelessWidget {
  const GameHistoryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
                    const CommonTitle('Geçmiş Oyunlar'),
                    const SizedBox(height: 24),
                    Expanded(
                      child: ValueListenableBuilder(
                        valueListenable: Hive.box<GameHistory>(
                                AppConstants.gameHistoryBox)
                            .listenable(),
                        builder: (context, Box<GameHistory> box, _) {
                          if (box.isEmpty) {
                            return const Center(
                              child: Text(
                                'Henüz oyun oynanmamış',
                                style:
                                    TextStyle(color: Colors.white, fontSize: 18),
                              ),
                            );
                          }

                          final oyunlar = box.values.toList()
                            ..sort((a, b) => b.tarih.compareTo(a.tarih));

                          return ListView.builder(
                            itemCount: oyunlar.length,
                            itemBuilder: (context, index) {
                              final oyun = oyunlar[index];

                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 16),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Colors.white.withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        oyun.takim1Skor > oyun.takim2Skor
                                            ? oyun.takim1Ismi
                                            : oyun.takim2Ismi,
                                        style: TextStyle(
                                          color: oyun.takim1Skor >
                                                  oyun.takim2Skor
                                              ? Colors.green
                                              : Colors.red,
                                          fontWeight: FontWeight.bold,
                                        ),
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
                                          color: oyun.takim2Skor >
                                                  oyun.takim1Skor
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
                            },
                          );
                        },
                      ),
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
