import 'package:flutter/material.dart';

class CommonCard extends StatelessWidget {
  final Widget child;
  final String? title;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  const CommonCard({
    Key? key,
    required this.child,
    this.title,
    this.padding,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 3.0, left: 2.0),
            child: Text(
              title!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.left,
            ),
          ),
        Container(
          decoration: BoxDecoration(
            color: color ?? Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white, width: 2),
          ),
          padding: padding ??
              const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          constraints: const BoxConstraints(
            minHeight: 56,
            maxWidth: 500,
            minWidth: 200,
          ),
          child: child,
        ),
      ],
    );
  }
}
