import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

class BackgroundWithLogo extends StatelessWidget {
  final Widget child;
  const BackgroundWithLogo({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            AppConstants.assetDuvarKagidi,
            fit: BoxFit.cover,
          ),
        ),
        Positioned.fill(
          child: Container(
            color: Colors.black.withOpacity(0.4),
          ),
        ),
        // En üstte logo
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Center(
              child: Image.asset(
                AppConstants.assetLogo,
                height: AppConstants.logoHeight,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        // İçerik logonun altında
        Positioned.fill(
          child: SafeArea(
            child: Column(
              children: [
                SizedBox(height: AppConstants.logoTopPadding),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
