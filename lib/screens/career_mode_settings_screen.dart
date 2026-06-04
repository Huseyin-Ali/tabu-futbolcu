import 'package:flutter/material.dart';
import '../widgets/background_with_logo.dart';
import '../widgets/app_back_button.dart';
import '../widgets/common_title.dart';
import 'career_mode_game_screen.dart';

class CareerModeSettingsScreen extends StatefulWidget {
  const CareerModeSettingsScreen({super.key});

  @override
  State<CareerModeSettingsScreen> createState() =>
      _CareerModeSettingsScreenState();
}

class _CareerModeSettingsScreenState extends State<CareerModeSettingsScreen> {
  int _selectedTime = 60;
  String _selectedDifficulty = 'karışık';
  String _selectedCollection = 'karışık';

  static const int _minSure = 60;
  static const int _maxSure = 300;
  static const int _surAdim = 30;

  static const List<String> _difficultyOptions = ['kolay', 'orta', 'zor', 'karışık'];
  static const List<String> _collectionOptions = ['aktif', 'veteran', 'karışık'];

  void _sureAzalt() {
    if (_selectedTime > _minSure) {
      setState(() => _selectedTime -= _surAdim);
    }
  }

  void _sureArtir() {
    if (_selectedTime < _maxSure) {
      setState(() => _selectedTime += _surAdim);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          BackgroundWithLogo(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const CommonTitle('Kariyer Avı'),
                  _sectionLabel('Süre Seç'),
                  const SizedBox(height: 10),
                  _buildSureStepper(),
                  const SizedBox(height: 24),
                  _sectionLabel('Zorluk Seç'),
                  const SizedBox(height: 10),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 2.6,
                    children: _difficultyOptions.map((d) {
                      return _OptionChip(
                        label: _difficultyLabel(d),
                        selected: _selectedDifficulty == d,
                        accentColor: _difficultyColor(d),
                        onTap: () => setState(() => _selectedDifficulty = d),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  _sectionLabel('Futbolcu Koleksiyonu'),
                  const SizedBox(height: 10),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.8,
                    children: _collectionOptions.map((c) {
                      return _OptionChip(
                        label: _collectionLabel(c),
                        selected: _selectedCollection == c,
                        accentColor: _collectionColor(c),
                        onTap: () => setState(() => _selectedCollection = c),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CareerModeGameScreen(
                            sure: _selectedTime,
                            zorluk: _selectedDifficulty,
                            koleksiyonTipi: _selectedCollection,
                          ),
                        ),
                      );
                    },
                    child: const Text(
                      'Oyunu Başlat',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const AppBackButton(),
        ],
      ),
    );
  }

  Widget _buildSureStepper() {
    final canDecrease = _selectedTime > _minSure;
    final canIncrease = _selectedTime < _maxSure;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.lightBlueAccent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.lightBlueAccent.withOpacity(0.35),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _arrowButton(
            icon: Icons.chevron_left_rounded,
            enabled: canDecrease,
            onTap: _sureAzalt,
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  '$_selectedTime',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(
                  'saniye',
                  style: TextStyle(
                    color: Colors.lightBlueAccent.withOpacity(0.75),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                // Progress dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    ((_maxSure - _minSure) ~/ _surAdim) + 1,
                    (i) {
                      final val = _minSure + i * _surAdim;
                      final isActive = val == _selectedTime;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        width: isActive ? 16 : 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isActive
                              ? Colors.lightBlueAccent
                              : Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          _arrowButton(
            icon: Icons.chevron_right_rounded,
            enabled: canIncrease,
            onTap: _sureArtir,
          ),
        ],
      ),
    );
  }

  Widget _arrowButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: enabled
              ? Colors.lightBlueAccent.withOpacity(0.18)
              : Colors.white.withOpacity(0.04),
          shape: BoxShape.circle,
          border: Border.all(
            color: enabled
                ? Colors.lightBlueAccent.withOpacity(0.55)
                : Colors.white.withOpacity(0.1),
            width: 1.5,
          ),
        ),
        child: Icon(
          icon,
          color: enabled ? Colors.lightBlueAccent : Colors.white24,
          size: 22,
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  String _difficultyLabel(String d) {
    switch (d) {
      case 'kolay':
        return 'Kolay';
      case 'orta':
        return 'Orta';
      case 'zor':
        return 'Zor';
      case 'karışık':
        return 'Karışık';
      default:
        return d;
    }
  }

  Color _difficultyColor(String d) {
    switch (d) {
      case 'kolay':
        return Colors.green;
      case 'orta':
        return Colors.orange;
      case 'zor':
        return Colors.red;
      case 'karışık':
        return Colors.purpleAccent;
      default:
        return Colors.white;
    }
  }

  String _collectionLabel(String c) {
    switch (c) {
      case 'aktif':
        return 'Aktif';
      case 'veteran':
        return 'Veteran';
      case 'karışık':
        return 'Karışık';
      default:
        return c;
    }
  }

  Color _collectionColor(String c) {
    switch (c) {
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
}

class _OptionChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  const _OptionChip({
    required this.label,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: selected
              ? accentColor.withOpacity(0.25)
              : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? accentColor : Colors.white.withOpacity(0.3),
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
