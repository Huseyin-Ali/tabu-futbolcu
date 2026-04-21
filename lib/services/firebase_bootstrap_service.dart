import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';
import '../utils/logger.dart';

/// Firebase başlatma sonucunu taşıyan değişmez model.
///
/// [firebaseInitialized] : Firebase.initializeApp() başarıyla tamamlandı mı.
/// [analyticsAvailable]  : Analytics event'leri gönderilebilir mi.
/// [firebaseErrorMessage]: Başlatma başarısız olduysa hata metni; aksi hâlde null.
class AppBootstrapResult {
  final bool firebaseInitialized;
  final bool analyticsAvailable;
  final String? firebaseErrorMessage;

  const AppBootstrapResult({
    required this.firebaseInitialized,
    required this.analyticsAvailable,
    this.firebaseErrorMessage,
  });

  /// Firebase başarıyla başlatıldığında kullanılan sabit sonuç.
  static const AppBootstrapResult success = AppBootstrapResult(
    firebaseInitialized: true,
    analyticsAvailable: true,
  );
}

/// Firebase'i başlatır ve sonucu [AppBootstrapResult] olarak döner.
///
/// Bu sınıf yalnızca Firebase servislerini başlatır.
/// Firestore veri çekme, cache yönetimi veya oyun verisi bu sınıfın sorumluluğu değildir.
class FirebaseBootstrapService {
  static Future<AppBootstrapResult> initialize() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      AppLogger.info('[Bootstrap] Firebase başarıyla başlatıldı');
      return AppBootstrapResult.success;
    } catch (e, stackTrace) {
      AppLogger.error('[Bootstrap] Firebase başlatılamadı', e, stackTrace);
      return AppBootstrapResult(
        firebaseInitialized: false,
        analyticsAvailable: false,
        firebaseErrorMessage: e.toString(),
      );
    }
  }
}
