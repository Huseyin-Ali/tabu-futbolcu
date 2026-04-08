import 'package:flutter/material.dart';
import 'logger.dart';

/// Hata yönetimi için utility sınıfı
class ErrorHandler {
  /// Kullanıcıya hata mesajı gösterir
  static void showError(BuildContext? context, String message, [Object? error]) {
    if (error != null) {
      AppLogger.error(message, error);
    } else {
      AppLogger.warning(message);
    }

    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Tamam',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    }
  }

  /// Başarı mesajı gösterir
  static void showSuccess(BuildContext? context, String message) {
    AppLogger.info(message);

    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Bilgi mesajı gösterir
  static void showInfo(BuildContext? context, String message) {
    AppLogger.info(message);

    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
