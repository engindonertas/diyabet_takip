import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diyabet_takip/main.dart';
import 'package:diyabet_takip/models/profile_model.dart';

void main() {
  testWidgets('Diyabet Takip uygulaması sekmeleri ve üst köşe açılır menü testi', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const DiyabetTakipApp());

    // Alt menüde yalnızca Öğünlerim ve Profil sekmeleri olmalı
    expect(find.text('Öğünlerim'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);
    expect(find.text('KH Sayımı'), findsNothing);

    // Öğünlerim sekmesi, 7 günlük takvim ve 2. saat tokluk hatırlatıcısı kontrolü
    expect(find.text('Gluko • Öğün & İnsülin Takibi'), findsOneWidget);
    expect(find.text('Öğün Ekle'), findsOneWidget);
    expect(find.text('2. Saat Tokluk Kan Şekeri Hatırlatıcıları'), findsOneWidget);
    expect(find.text('Bazal İnsülin'), findsOneWidget);
    expect(find.text('Gece 03:00 Kan Şekeri'), findsOneWidget);

    // Üst köşe açılır menüyü aç ve seçenekleri kontrol et
    await tester.tap(find.byKey(const Key('top_corner_menu_button')));
    await tester.pumpAndSettle();

    expect(find.text('Glukobot'), findsOneWidget);
    expect(find.text('Karbonhidrat Sayımı'), findsOneWidget);
    expect(find.text('Uygulama Kullanım Rehberi'), findsOneWidget);
    expect(find.text('Ayarlar'), findsOneWidget);
    expect(find.text('Yasal Uyarılar'), findsOneWidget);
    expect(find.text('Bizi Puanla'), findsOneWidget);

    // Glukobot ekranına geçiş ve sekmeleri kontrol et
    await tester.tap(find.text('Glukobot'));
    await tester.pumpAndSettle();
    expect(find.text('Glukobot Sohbet'), findsOneWidget);
    expect(find.text('Öğün Hipo/Hiper'), findsOneWidget);

    // Ana ekrana geri dön ve Karbonhidrat Sayımı ekranını kontrol et
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('top_corner_menu_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Karbonhidrat Sayımı'));
    await tester.pumpAndSettle();
    expect(find.text('Karbonhidrat Sayım Tepsisi'), findsOneWidget);
    expect(find.text('Yemek Ekle'), findsWidgets);

    // Ana ekrana geri dön
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Profil sekmesine geçiş (Sabah/Öğle/Akşam ayrı K/İ oranları ve Sensör Pop-up kontrolü)
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    expect(find.text('Kişisel Bilgiler'), findsOneWidget);
    expect(find.text('Diyabet Bilgileri'), findsOneWidget);
    expect(find.text('Sabah K/İ Oranı ve Saat Aralığı'), findsOneWidget);
    expect(find.text('Öğle K/İ Oranı ve Saat Aralığı'), findsOneWidget);
    expect(find.text('Akşam K/İ Oranı ve Saat Aralığı'), findsOneWidget);
    expect(find.text('Sabah, Öğle ve Akşam K/İ Oranlarını Kaydet'), findsOneWidget);
    expect(find.text(kMedicalDisclaimerText), findsOneWidget);
    expect(find.text('FreeStyle Libre 2'), findsOneWidget);

    // Sensör seçim alanına tıklayınca açılan pop-up menüyü kontrol et
    final sensorTrigger = find.byKey(const Key('sensor_popup_trigger'));
    await tester.ensureVisible(sensorTrigger);
    await tester.tap(sensorTrigger);
    await tester.pumpAndSettle();
    expect(find.text('Şeker Takip Sensörü Seçin'), findsOneWidget);
    expect(find.text('Dexcom G7'), findsOneWidget);
  });
}
