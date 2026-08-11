import 'package:flutter_test/flutter_test.dart';
import 'package:oyuncu_tahmin_oyunu/models/kariyer_futbolcu.dart';
import 'package:oyuncu_tahmin_oyunu/services/career_mode_service.dart';

KariyerFutbolcu _oyuncu(
  String id,
  String isim,
  List<String> yol, {
  String zorluk = 'orta',
}) =>
    KariyerFutbolcu(id: id, isim: isim, kariyerYolu: yol, zorluk: zorluk);

void main() {
  group('CareerModeService.careerPathKey', () {
    test('boşluk ve büyük/küçük harf farkını normalize eder', () {
      final a = _oyuncu('1', 'A', ['Barcelona B', ' Barcelona ']);
      final b = _oyuncu('2', 'B', ['barcelona   b', 'BARCELONA']);
      expect(
        CareerModeService.careerPathKey(a),
        CareerModeService.careerPathKey(b),
      );
    });

    test('kulüp sırası önemlidir', () {
      final a = _oyuncu('1', 'A', ['Barcelona', 'Barcelona B']);
      final b = _oyuncu('2', 'B', ['Barcelona B', 'Barcelona']);
      expect(
        CareerModeService.careerPathKey(a),
        isNot(CareerModeService.careerPathKey(b)),
      );
    });

    test('benzer ama farklı kulüp adlarını fuzzy eşleştirmez', () {
      final a = _oyuncu('1', 'A', ['Barcelona']);
      final b = _oyuncu('2', 'B', ['Barcelone']);
      expect(
        CareerModeService.careerPathKey(a),
        isNot(CareerModeService.careerPathKey(b)),
      );
    });

    test('Türkçe/aksanlı karakter farkını sadeleştirmez (isim normalizasyonundan '
        'kasıtlı olarak farklı davranır)', () {
      // "Galatasaray" vs "Galatasaräy" gibi aksan farkı olan iki kulüp adı
      // careerPathKey içinde ASLA aynılaştırılmamalı.
      final a = _oyuncu('1', 'A', ['Galatasaray']);
      final b = _oyuncu('2', 'B', ['Galatasaräy']);
      expect(
        CareerModeService.careerPathKey(a),
        isNot(CareerModeService.careerPathKey(b)),
      );

      // Türkçe İ/ı farkı da aynı şekilde korunmalı.
      final c = _oyuncu('3', 'C', ['Fenerbahçe']);
      final d = _oyuncu('4', 'D', ['Fenerbahce']);
      expect(
        CareerModeService.careerPathKey(c),
        isNot(CareerModeService.careerPathKey(d)),
      );
    });
  });

  group('CareerModeService.generateChoices', () {
    test('doğru oyuncuyla birebir aynı kariyer yoluna sahip adayı eler', () {
      final dogru = _oyuncu('1', 'Dogru Oyuncu', ['Barcelona B', 'Barcelona']);
      final ayniYol = _oyuncu('2', 'Ayni Yol', ['Barcelona B', 'Barcelona']);
      final farkli1 =
          _oyuncu('3', 'Farkli 1', ['Real Madrid B', 'Real Madrid']);
      final farkli2 = _oyuncu('4', 'Farkli 2', ['Ajax B', 'Ajax']);
      final farkli3 = _oyuncu('5', 'Farkli 3', ['Bayern B', 'Bayern']);

      final secenekler = CareerModeService.generateChoices(
        dogru: dogru,
        tumListe: [dogru, ayniYol, farkli1, farkli2, farkli3],
      );

      expect(secenekler, isNot(contains('Ayni Yol')));
      expect(secenekler, contains('Dogru Oyuncu'));
      expect(secenekler.length, 4);
    });

    test('üç yanlış seçeneğin kariyer yolları kendi aralarında da benzersiz',
        () {
      final dogru = _oyuncu('1', 'Dogru', ['A Kulubu']);
      final ayni1 = _oyuncu('2', 'Ayni 1', ['B Kulubu']);
      final ayni2 = _oyuncu('3', 'Ayni 2', ['B Kulubu']); // ayni1 ile aynı
      final farkli1 = _oyuncu('4', 'Farkli 1', ['C Kulubu']);
      final farkli2 = _oyuncu('5', 'Farkli 2', ['D Kulubu']);

      final secenekler = CareerModeService.generateChoices(
        dogru: dogru,
        tumListe: [dogru, ayni1, ayni2, farkli1, farkli2],
      );

      final secilenIsimler = secenekler.toSet();
      final ikisiDeVar = secilenIsimler.contains('Ayni 1') &&
          secilenIsimler.contains('Ayni 2');
      expect(ikisiDeVar, isFalse);
      expect(secenekler.length, 4);
    });

    test('yalnızca kısmi ortak kariyeri olan aday gereksiz elenmez', () {
      final dogru = _oyuncu('1', 'Dogru', ['Barcelona B', 'Barcelona']);
      final kismiOrtak =
          _oyuncu('2', 'Kismi Ortak', ['Barcelona B', 'Barcelona', 'PSG']);
      final dolgu1 = _oyuncu('3', 'Dolgu 1', ['Ajax']);
      final dolgu2 = _oyuncu('4', 'Dolgu 2', ['Bayern']);

      final secenekler = CareerModeService.generateChoices(
        dogru: dogru,
        tumListe: [dogru, kismiOrtak, dolgu1, dolgu2],
      );

      expect(secenekler, contains('Kismi Ortak'));
    });

    test('aynı kulüpler farklı sıradaysa birebir aynı sayılmaz', () {
      final dogru = _oyuncu('1', 'Dogru', ['Barcelona', 'Barcelona B']);
      final tersSira = _oyuncu('2', 'Ters Sira', ['Barcelona B', 'Barcelona']);
      final dolgu1 = _oyuncu('3', 'Dolgu 1', ['Ajax']);
      final dolgu2 = _oyuncu('4', 'Dolgu 2', ['Bayern']);

      final secenekler = CareerModeService.generateChoices(
        dogru: dogru,
        tumListe: [dogru, tersSira, dolgu1, dolgu2],
      );

      expect(secenekler, contains('Ters Sira'));
    });

    test('boşluk/büyük-küçük harf farkı filtreyi aşamaz', () {
      final dogru = _oyuncu('1', 'Dogru', ['Barcelona B', 'Barcelona']);
      final ayniAmaFarkliYazim =
          _oyuncu('2', 'Farkli Yazim', ['barcelona   b', ' BARCELONA ']);
      final dolgu1 = _oyuncu('3', 'Dolgu 1', ['Ajax']);
      final dolgu2 = _oyuncu('4', 'Dolgu 2', ['Bayern']);

      final secenekler = CareerModeService.generateChoices(
        dogru: dogru,
        tumListe: [dogru, ayniAmaFarkliYazim, dolgu1, dolgu2],
      );

      expect(secenekler, isNot(contains('Farkli Yazim')));
    });

    test('havuz yeterince zenginse 4 farklı futbolcu/benzersiz yol üretir',
        () {
      final dogru = _oyuncu('1', 'Dogru', ['A', 'B']);
      final havuz = [
        dogru,
        for (var i = 2; i <= 10; i++)
          _oyuncu('$i', 'Oyuncu $i', ['X$i', 'Y$i']),
      ];

      final secenekler = CareerModeService.generateChoices(
        dogru: dogru,
        tumListe: havuz,
      );

      expect(secenekler.length, 4);
      expect(secenekler.toSet().length, 4);
    });

    test(
        'yetersiz benzersiz aday varsa (< 3 yanlış) boş liste döner, '
        'hiçbir zaman eksik/kısmi liste üretmez', () {
      final dogru = _oyuncu('1', 'Dogru', ['A']);
      final tekAday = _oyuncu('2', 'Tek Aday', ['A']); // dogru ile aynı yol

      final secenekler = CareerModeService.generateChoices(
        dogru: dogru,
        tumListe: [dogru, tekAday],
      );

      expect(secenekler, isEmpty);
    });

    test(
        'iki benzersiz yanlış aday varken de (3 gerekirken) boş liste döner',
        () {
      final dogru = _oyuncu('1', 'Dogru', ['A']);
      final aday1 = _oyuncu('2', 'Aday 1', ['B']);
      final aday2 = _oyuncu('3', 'Aday 2', ['C']);

      final secenekler = CareerModeService.generateChoices(
        dogru: dogru,
        tumListe: [dogru, aday1, aday2],
      );

      expect(secenekler, isEmpty);
    });

    test('generateChoices hiçbir başarılı durumda 4ten az seçenek üretmiyor '
        '(ya tam 4 ya da 0)', () {
      // Küçükten büyüğe farklı havuz büyüklükleriyle dene; sonuç her zaman
      // ya tam 4 ya da tam 0 olmalı, asla 1-2-3 olmamalı.
      for (var poolSize = 0; poolSize <= 6; poolSize++) {
        final dogru = _oyuncu('0', 'Dogru', ['A']);
        final havuz = [
          dogru,
          for (var i = 1; i <= poolSize; i++)
            _oyuncu('$i', 'Aday $i', ['B$i']),
        ];

        final secenekler = CareerModeService.generateChoices(
          dogru: dogru,
          tumListe: havuz,
        );

        expect(
          secenekler.isEmpty || secenekler.length == 4,
          isTrue,
          reason: 'poolSize=$poolSize için uzunluk ${secenekler.length}',
        );
      }
    });

    test('farklı zorluk etiketleriyle de doğru çalışır', () {
      final dogru = _oyuncu('1', 'Dogru', ['A', 'B'], zorluk: 'zor');
      final havuz = [
        dogru,
        _oyuncu('2', 'Kolay 1', ['C', 'D'], zorluk: 'kolay'),
        _oyuncu('3', 'Zor 1', ['E', 'F'], zorluk: 'zor'),
        _oyuncu('4', 'Karisik 1', ['G', 'H'], zorluk: 'karışık'),
      ];

      final secenekler = CareerModeService.generateChoices(
        dogru: dogru,
        tumListe: havuz,
      );

      expect(secenekler.length, 4);
      expect(secenekler.toSet().length, 4);
    });

    test(
        'aynı son takım önceliği (Aşama 1/2) korunuyor: yeterli aday '
        'varken uzak/rastgele bir aday yerine aynı son takımlı aday seçilir',
        () {
      final dogru = _oyuncu('1', 'Dogru', ['X', 'Ortak Takim']);
      // Aynı son takım + aynı zorluk (Aşama 1 adayları) — tam 3 tane.
      final ayniTakim1 =
          _oyuncu('2', 'Ayni Takim 1', ['Y', 'Ortak Takim'], zorluk: 'orta');
      final ayniTakim2 =
          _oyuncu('3', 'Ayni Takim 2', ['Z', 'Ortak Takim'], zorluk: 'orta');
      final ayniTakim3 =
          _oyuncu('4', 'Ayni Takim 3', ['W', 'Ortak Takim'], zorluk: 'orta');
      // Alakasız, farklı son takımlı doldurma adayları.
      final uzak1 = _oyuncu('5', 'Uzak 1', ['Farkli Takim 1']);
      final uzak2 = _oyuncu('6', 'Uzak 2', ['Farkli Takim 2']);

      final secenekler = CareerModeService.generateChoices(
        dogru: dogru,
        tumListe: [
          dogru,
          ayniTakim1,
          ayniTakim2,
          ayniTakim3,
          uzak1,
          uzak2,
        ],
      );

      expect(secenekler.length, 4);
      expect(secenekler, contains('Ayni Takim 1'));
      expect(secenekler, contains('Ayni Takim 2'));
      expect(secenekler, contains('Ayni Takim 3'));
      expect(secenekler, isNot(contains('Uzak 1')));
      expect(secenekler, isNot(contains('Uzak 2')));
    });
  });

  group('CareerModeService.pickCardWithValidChoices', () {
    // İlk 20 doğru-oyuncu adayının hepsi aynı ismi ("Ortak İsim")
    // paylaşıyor; generateChoices'in mevcut isim-bazlı tekrar-önleme
    // kuralı (secilenIsimler) yüzünden, bu adaylardan biri "dogru" olarak
    // sorgulandığında kendisiyle aynı isme sahip diğer bütün adaylar
    // (19 diğer "kötü" aday + 3 "iyi" çeşitlendirici) şık havuzundan
    // elenir; geriye tek bir farklı-isimli aday (21. aday) kalır — bu da
    // 3 benzersiz yanlış şık için yetersizdir, dolayısıyla ilk 20 aday
    // generateChoices ile 4 şık ÜRETEMEZ. 21. aday ("Farklı İsim") kendi
    // ismiyle sorgulandığında bu isim-filtresi devreye girmez ve 3
    // birbirinden farklı kariyer yoluna sahip çeşitlendirici aday
    // bulunabildiği için tam 4 şık üretir.
    List<KariyerFutbolcu> buildPool() {
      final kotuAdaylar = [
        for (var i = 1; i <= 20; i++)
          _oyuncu('kotu$i', 'Ortak İsim', ['Kotu Yolu $i']),
      ];
      final cesitlendiriciler = [
        _oyuncu('cesit1', 'Ortak İsim', ['Cesit A']),
        _oyuncu('cesit2', 'Ortak İsim', ['Cesit B']),
        _oyuncu('cesit3', 'Ortak İsim', ['Cesit C']),
      ];
      final iyiAday =
          _oyuncu('iyi21', 'Farklı İsim', ['İyi Aday Yolu']);
      return [...kotuAdaylar, ...cesitlendiriciler, iyiAday];
    }

    test(
        'sabit 20 aday sınırı yok: ilk 20 aday 4 şık üretemese bile '
        '21. aday geçerliyse o seçilir', () {
      final havuz = buildPool();
      // Deneme sırası tam olarak havuzdaki gibi: önce 20 "kötü" aday,
      // sonra çeşitlendiriciler, en sonda "iyi" aday.
      final denemeSirasi = [
        for (final f in havuz) f,
      ];

      // Önce doğrulama: ilk 20 aday gerçekten tek başına 4 şık üretemiyor.
      for (var i = 0; i < 20; i++) {
        final secenekler = CareerModeService.generateChoices(
          dogru: denemeSirasi[i],
          tumListe: havuz,
        );
        expect(
          secenekler,
          isEmpty,
          reason: '"kotu${i + 1}" adayı beklenmedik şekilde 4 şık üretti',
        );
      }

      final sonuc = CareerModeService.pickCardWithValidChoices(
        adaylar: denemeSirasi,
        tumListe: havuz,
      );

      expect(sonuc, isNotNull);
      expect(sonuc!.dogru.id, 'iyi21');
      expect(sonuc.secenekler.length, 4);
      expect(sonuc.secenekler, contains('Farklı İsim'));
    });

    test(
        'her aday en fazla bir kez denenir: listede önce başarısız bir '
        'aday tekrar etse bile arama sonsuza gitmez ve ilk gerçek başarılı '
        'adayda durur', () {
      final basarisiz = _oyuncu('basarisiz', 'X', ['Tek Yol']);
      final basarili = _oyuncu('basarili', 'Y', ['Farklı Yol']);
      final decoy1 = _oyuncu('d1', 'X', ['D1']);
      final decoy2 = _oyuncu('d2', 'X', ['D2']);
      final decoy3 = _oyuncu('d3', 'X', ['D3']);
      final tumListe = [basarisiz, basarili, decoy1, decoy2, decoy3];

      // "basarisiz" adayı, isim çakışması yüzünden decoy1/2/3'ü (hepsi
      // aynı isme sahip) elediği için 4 şık üretemez.
      expect(
        CareerModeService.generateChoices(dogru: basarisiz, tumListe: tumListe),
        isEmpty,
      );

      // Aynı başarısız aday listede İKİ KEZ geçse bile (örn. iki farklı
      // fallback aşamasından aynı oyuncunun sıraya girmesi gibi bir
      // senaryoyu simüle eder), tarama sonsuza gitmeden gerçek başarılı
      // adaya ulaşır ve orada durur.
      final adaylar = [basarisiz, basarisiz, basarili];
      final sonuc = CareerModeService.pickCardWithValidChoices(
        adaylar: adaylar,
        tumListe: tumListe,
      );

      expect(sonuc, isNotNull);
      expect(sonuc!.dogru.id, 'basarili');
      expect(sonuc.secenekler.length, 4);
    });

    test(
        'hiç geçerli aday yoksa tarama havuzun sonunda güvenle biter '
        '(null döner, eksik şıklı kart üretmez)', () {
      // Tüm adaylar birbiriyle aynı kariyer yoluna sahip — hiçbiri için
      // 3 benzersiz yanlış şık bulunamaz.
      final havuz = [
        for (var i = 1; i <= 5; i++) _oyuncu('$i', 'Oyuncu $i', ['Ayni Yol']),
      ];

      final sonuc = CareerModeService.pickCardWithValidChoices(
        adaylar: havuz,
        tumListe: havuz,
      );

      expect(sonuc, isNull);
    });

    test('dönen sonuç varsa şık sayısı her zaman tam 4 — eksik şıklı kart '
        'asla döndürülmez', () {
      final havuz = buildPool();
      final sonuc = CareerModeService.pickCardWithValidChoices(
        adaylar: havuz,
        tumListe: havuz,
      );

      expect(sonuc, isNotNull);
      expect(sonuc!.secenekler.length, 4);
    });
  });
}
