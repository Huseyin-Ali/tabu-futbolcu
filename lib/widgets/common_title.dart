import 'package:flutter/material.dart';

class CommonTitle extends StatelessWidget {
  final String text;
  final EdgeInsetsGeometry? padding;
  const CommonTitle(this.text, {this.padding, super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.only(top: 32.0, bottom: 24.0),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
