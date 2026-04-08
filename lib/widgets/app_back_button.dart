import 'package:flutter/material.dart';
import '../screens/welcome_screen.dart';

class AppBackButton extends StatelessWidget {
  const AppBackButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 16,
      left: 8,
      child: SafeArea(
        child: IconButton(
          icon: const Icon(Icons.home, color: Colors.white, size: 32),
          onPressed: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const WelcomeScreen()),
              (route) => false,
            );
          },
        ),
      ),
    );
  }
}
