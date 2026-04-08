import 'package:flutter/material.dart';
import '../models/game_history.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Geçmiş Oyunlar'),
      ),
      body: ValueListenableBuilder(
        valueListenable: Hive.box<GameHistory>('gameHistory').listenable(),
        builder: (context, Box<GameHistory> box, _) {
          if (box.isEmpty) {
            return const Center(
              child: Text(
                'Henüz oyun geçmişi bulunmuyor.',
                style: TextStyle(fontSize: 18),
              ),
            );
          }

          final games = box.values.toList()
            ..sort((a, b) => b.tarih.compareTo(a.tarih));

          return ListView.builder(
            itemCount: games.length,
            itemBuilder: (context, index) {
              final game = games[index];
              final dateFormat = DateFormat('dd.MM.yyyy HH:mm');

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          game.takim1Ismi,
                          style: TextStyle(
                            fontWeight: game.takim1Skor > game.takim2Skor
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      Text(
                        '${game.takim1Skor} - ${game.takim2Skor}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          game.takim2Ismi,
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontWeight: game.takim2Skor > game.takim1Skor
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    dateFormat.format(game.tarih),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
