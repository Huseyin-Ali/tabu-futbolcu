/// Uygulama genelinde kullanılan sabitler
class AppConstants {
  // Hive Box İsimleri
  static const String gameHistoryBox = 'gameHistory';
  static const String gameBox = 'gameBox';
  static const String futbolcularBox = 'futbolcular';
  static const String kariyerFutbolcularCacheBox = 'kariyerFutbolcularCache';
  static const String kariyerGecmisKey = 'kariyerGecmisOyunlar';

  // SharedPreferences Keys
  static const String keyZamanLimiti = 'zamanLimiti';
  static const String keyPasHakki = 'pasHakki';
  static const String keyTabuCezasi = 'tabuCezasi';
  static const String keyPuanHedefi = 'puanHedefi';
  static const String keyTakim1Sirasi = 'takim1Sirasi';
  static const String keyTakim1Ismi = 'takim1Ismi';
  static const String keyTakim2Ismi = 'takim2Ismi';
  static const String keyTabuKartTipi = 'tabuKartTipi';
  static const String keySesAcik = 'sesAcik';
  static const String keyFutbolcularLastSync = 'futbolcularLastSync';

  // Varsayılan Değerler
  static const int defaultZamanLimiti = 60;
  static const int defaultPasHakki = 3;
  static const int defaultTabuCezasi = 2;
  static const int defaultPuanHedefi = 50;
  static const String defaultTabuKartTipi = 'karışık';
  static const bool defaultSesAcik = true;

  // Oyun Ayarları Limitleri
  static const int minZamanLimiti = 10;
  static const int maxZamanLimiti = 300;
  static const int minPasHakki = 0;
  static const int maxPasHakki = 5;
  static const int minTabuCezasi = 1;
  static const int maxTabuCezasi = 10;
  static const int minPuanHedefi = 10;
  static const int maxPuanHedefi = 200;

  // Ses Dosyaları
  static const String soundWhistle = 'sounds/whistle.mp3';
  static const String soundGol = 'sounds/gol.mp3';
  static const String soundAlkis = 'sounds/alkis.mp3';
  static const String soundBlitzStart = 'sounds/blitz_start.mp3.mp3';
  static const String soundRisk = 'sounds/risk_v1.mp3';

  // Ses Seviyeleri (0.0-1.0) — ffmpeg loudnorm ölçümüne göre dengelendi
  static const double soundWhistleVolume = 0.50;
  static const double soundGolVolume = 0.85;
  static const double soundBlitzVolume = 0.30;
  static const double soundRiskVolume = 0.35;

  // Asset Yolları
  static const String assetDuvarKagidi = 'assets/duvar_kagidi.jpg';
  static const String assetLogo = 'assets/sampiyonlar_ligi_logo.png';
  static const String assetFutbolcuListesi = 'assets/futbolcu_listesi.json';
  static const String assetNasilOynanir = 'assets/nasıl_oynanır.txt';

  // UI Sabitleri
  static const double logoHeight = 200.0;
  static const double logoTopPadding = 175.0;
  static const int countdownBalls = 3;
  static const int maxBallDisplay = 10;
}
