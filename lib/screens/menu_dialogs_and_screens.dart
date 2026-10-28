import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppSettings {
  final bool notificationsEnabled;
  final String notificationSound;
  final int postprandialReminderMinutes;
  final bool isDarkMode;
  final String glucoseUnit;
  final int hypoThreshold;
  final int hyperThreshold;
  final int targetFastingMax;
  final int targetPostprandialMax;

  const AppSettings({
    this.notificationsEnabled = true,
    this.notificationSound = 'Klasik Bip (Varsayılan)',
    this.postprandialReminderMinutes = 120,
    this.isDarkMode = false,
    this.glucoseUnit = 'mg/dL',
    this.hypoThreshold = 70,
    this.hyperThreshold = 250,
    this.targetFastingMax = 130,
    this.targetPostprandialMax = 180,
  });

  AppSettings copyWith({
    bool? notificationsEnabled,
    String? notificationSound,
    int? postprandialReminderMinutes,
    bool? isDarkMode,
    String? glucoseUnit,
    int? hypoThreshold,
    int? hyperThreshold,
    int? targetFastingMax,
    int? targetPostprandialMax,
  }) {
    return AppSettings(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      notificationSound: notificationSound ?? this.notificationSound,
      postprandialReminderMinutes:
          postprandialReminderMinutes ?? this.postprandialReminderMinutes,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      glucoseUnit: glucoseUnit ?? this.glucoseUnit,
      hypoThreshold: hypoThreshold ?? this.hypoThreshold,
      hyperThreshold: hyperThreshold ?? this.hyperThreshold,
      targetFastingMax: targetFastingMax ?? this.targetFastingMax,
      targetPostprandialMax:
          targetPostprandialMax ?? this.targetPostprandialMax,
    );
  }
}

const List<String> kAvailableNotificationSounds = [
  'Klasik Bip (Varsayılan)',
  'Yumuşak Melodi (Chime)',
  'Kısa Hatırlatıcı Zil (Bell)',
  'Güçlü Uyarı Sesi (Alarm)',
  'Sessiz (Sadece Görsel Bildirim)',
];

/// Bildirim sesini çalar (seçili sese göre sistem ses/titreşim geri bildirimi verir)
Future<void> playSelectedNotificationSound(String soundName) async {
  if (soundName.startsWith('Sessiz')) {
    await HapticFeedback.vibrate();
    return;
  }
  if (soundName.contains('Alarm')) {
    await SystemSound.play(SystemSoundType.alert);
    await HapticFeedback.heavyImpact();
  } else if (soundName.contains('Melodi') || soundName.contains('Zil')) {
    await SystemSound.play(SystemSoundType.alert);
    await HapticFeedback.mediumImpact();
  } else {
    await SystemSound.play(SystemSoundType.click);
    await HapticFeedback.lightImpact();
  }
}

/// 1. AYARLAR EKRANI
class SettingsScreen extends StatefulWidget {
  final AppSettings settings;
  final ValueChanged<AppSettings> onSettingsChanged;

  const SettingsScreen({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late AppSettings _current;

  @override
  void initState() {
    super.initState();
    _current = widget.settings;
  }

  void _update(AppSettings updated) {
    setState(() {
      _current = updated;
    });
    widget.onSettingsChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Ayarlar',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
        children: [
          // Bildirim Ayarları Kartı
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.notifications_active_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Bildirim ve Ses Ayarları',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Tokluk Kan Şekeri Bildirimlerini Aç',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      _current.notificationsEnabled
                          ? 'Öğün saatinden ${_current.postprandialReminderMinutes ~/ 60} saat sonra tokluk kan şekeri bildirimi gönderilir.'
                          : 'Tüm tokluk kan şekeri hatırlatma bildirimleri kapalı.',
                    ),
                    value: _current.notificationsEnabled,
                    onChanged: (val) {
                      _update(_current.copyWith(notificationsEnabled: val));
                    },
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _current.notificationSound,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Bildirim Sesi Seçimi',
                      prefixIcon: Icon(Icons.volume_up_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: kAvailableNotificationSounds.map((sound) {
                      return DropdownMenuItem(
                        value: sound,
                        child: Text(sound),
                      );
                    }).toList(),
                    onChanged: _current.notificationsEnabled
                        ? (val) {
                            if (val != null) {
                              _update(
                                _current.copyWith(notificationSound: val),
                              );
                              playSelectedNotificationSound(val);
                            }
                          }
                        : null,
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: _current.notificationsEnabled
                          ? () {
                              playSelectedNotificationSound(
                                _current.notificationSound,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  duration: const Duration(seconds: 2),
                                  content: Text(
                                    '🔊 "${_current.notificationSound}" bildirim sesi test edildi.',
                                  ),
                                ),
                              );
                            }
                          : null,
                      icon: const Icon(Icons.play_arrow_outlined, size: 18),
                      label: const Text('Bildirim Sesini Test Et'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    initialValue: _current.postprandialReminderMinutes,
                    decoration: const InputDecoration(
                      labelText: 'Tokluk Şekeri Hatırlatma Süresi',
                      prefixIcon: Icon(Icons.timer_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 60,
                        child: Text('Öğünden 1 Saat Sonra (60 dk)'),
                      ),
                      DropdownMenuItem(
                        value: 90,
                        child: Text('Öğünden 1.5 Saat Sonra (90 dk)'),
                      ),
                      DropdownMenuItem(
                        value: 120,
                        child: Text('Öğünden 2 Saat Sonra (120 dk - Önerilen)'),
                      ),
                      DropdownMenuItem(
                        value: 180,
                        child: Text('Öğünden 3 Saat Sonra (180 dk)'),
                      ),
                    ],
                    onChanged: _current.notificationsEnabled
                        ? (val) {
                            if (val != null) {
                              _update(
                                _current.copyWith(
                                  postprandialReminderMinutes: val,
                                ),
                              );
                            }
                          }
                        : null,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Kan Şekeri Hedef ve Birim Ayarları
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.bloodtype_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Kan Şekeri Hedef & Uyarı Sınırları',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _current.glucoseUnit,
                    decoration: const InputDecoration(
                      labelText: 'Kan Şekeri Ölçüm Birimi',
                      prefixIcon: Icon(Icons.straighten_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'mg/dL',
                        child: Text('mg/dL (Standart)'),
                      ),
                      DropdownMenuItem(
                        value: 'mmol/L',
                        child: Text('mmol/L'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        _update(_current.copyWith(glucoseUnit: val));
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Hipoglisemi (Düşük Şeker) Sınırı: ${_current.hypoThreshold} ${_current.glucoseUnit}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Slider(
                    value: _current.hypoThreshold.toDouble(),
                    min: 50,
                    max: 90,
                    divisions: 8,
                    label: '${_current.hypoThreshold}',
                    onChanged: (val) {
                      _update(_current.copyWith(hypoThreshold: val.round()));
                    },
                  ),
                  Text(
                    'Hedef Tokluk Kan Şekeri Üst Sınırı: ${_current.targetPostprandialMax} ${_current.glucoseUnit}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Slider(
                    value: _current.targetPostprandialMax.toDouble(),
                    min: 140,
                    max: 220,
                    divisions: 8,
                    label: '${_current.targetPostprandialMax}',
                    onChanged: (val) {
                      _update(
                        _current.copyWith(targetPostprandialMax: val.round()),
                      );
                    },
                  ),
                  Text(
                    'Hiperglisemi (Yüksek Şeker) Sınırı: ${_current.hyperThreshold} ${_current.glucoseUnit}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Slider(
                    value: _current.hyperThreshold.toDouble(),
                    min: 180,
                    max: 300,
                    divisions: 12,
                    label: '${_current.hyperThreshold}',
                    onChanged: (val) {
                      _update(_current.copyWith(hyperThreshold: val.round()));
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Görünüm ve Uygulama Hakkında
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.palette_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Görünüm ve Uygulama Hakkında',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Karanlık Tema (Gece Modu)',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Göz yorgunluğunu azaltmak için koyu renk temayı kullanın.',
                    ),
                    value: _current.isDarkMode,
                    onChanged: (val) {
                      _update(_current.copyWith(isDarkMode: val));
                    },
                  ),
                  const Divider(),
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.info_outline),
                    title: Text('Uygulama Sürümü'),
                    subtitle: Text(
                      'Gluko v1.0.0 • Glukobot Yapay Zeka Destekli Diyabet Takip Uygulaması',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 2. YASAL UYARILAR DİYALOĞU
void showLegalDisclaimerDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.gavel_rounded,
                color: Color(0xFFB45309),
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Yasal Uyarılar ve Sorumluluk Reddi',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF59E0B)),
                ),
                child: const Text(
                  '⚠️ ÖNEMLİ TIBBİ VE YASAL UYARI',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF92400E),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '1. Doktor Eşliğinde Kullanım Tavsiyesi:\n'
                'Bu uygulama yalnızca kişisel karbonhidrat sayımı, öğün ve kan şekeri takibini kolaylaştırmak amacıyla geliştirilmiş yardımcı bir araçtır. Uygulamanın mutlaka bir doktor, endokrinoloji uzmanı veya diyabet eğitim hemşiresi eşliğinde kullanılması tavsiye edilir.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Text(
                '2. Tıbbi Tavsiye Niteliği Taşımaz:\n'
                'Uygulama içerisinde yer alan Karbonhidrat/İnsülin (K/İ) oranı hesaplamaları ve tavsiye edilen insülin miktarları tamamen kullanıcının kendi girdiği verilere dayanan matematiksel hesaplamalardır; hiçbir koşulda tıbbi tanı, tedavi veya reçete yerine geçmez.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Text(
                '3. Sorumluluk Reddi Beyanı:\n'
                'Bu uygulamayı geliştirenler ve yayınlayanlar; uygulamanın kullanımından, hesaplama sonuçlarından, olası yazılım/veri hatalarından veya doktor onayı olmadan yapılan insülin dozu uygulamalarından kaynaklanabilecek hipoglisemi, hiperglisemi ya da herhangi bir doğrudan/dolaylı sağlık sorunu ve zarardan dolayı HİÇBİR YASAL VEYA TIBBİ SORUMLULUK KABUL ETMEZ.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Okudum ve Anladım'),
          ),
        ],
      );
    },
  );
}

/// 3. UYGULAMA KULLANIM REHBERİ (SAYFA SAYFA TANITIM)
class AppGuideScreen extends StatefulWidget {
  const AppGuideScreen({super.key});

  @override
  State<AppGuideScreen> createState() => _AppGuideScreenState();
}

class _AppGuideScreenState extends State<AppGuideScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_GuidePageData> _pages = const [
    _GuidePageData(
      icon: Icons.calendar_month_outlined,
      color: Color(0xFF0D9488),
      title: '1. Öğün Takibi ve 7 Günlük Takvim',
      description:
          'Ana ekranın üst kısmındaki 7 günlük takvimi sağa-sola kaydırarak istediğiniz günü seçebilirsiniz.\n\n'
          '"Öğün Ekle" butonuyla her öğün için yediğiniz yemeği, gramını, karbonhidratını, öğün saatini, açlık/tokluk kan şekerinizi ve vurduğunuz tam sayı insülin dozunu kolayca kaydedebilirsiniz.',
    ),
    _GuidePageData(
      icon: Icons.calculate_outlined,
      color: Color(0xFFF59E0B),
      title: '2. Karbonhidrat Sayımı ve Yeni Yemek Ekleme',
      description:
          'Üst köşedeki menüden ulaşabileceğiniz "Karbonhidrat Sayımı" ekranında besinlerin gramajını girerek otomatik karbonhidrat hesabı yapabilirsiniz.\n\n'
          '"Yeni Yemek Ekle" butonuyla kendi yemeklerinizi ve karbonhidrat değerlerini ekleyebilir; eklediğiniz bu yemekleri öğün kaydederken "Hazır Besin Listesi" içinde doğrudan görebilirsiniz.',
    ),
    _GuidePageData(
      icon: Icons.schedule_outlined,
      color: Color(0xFF10B981),
      title: '3. Sabah, Öğle, Akşam K/İ Oranları & Sensör Seçimi',
      description:
          'Profil sekmesinde kişisel bilgilerinizi (isim, soyisim, doğum tarihi, boy, kilo) kaydedebilir ve kullandığınız şeker takip sensörünü açılır pop-up menüden seçebilirsiniz.\n\n'
          'Sabah, Öğle ve Akşam saat aralıkları için ayrı K/İ oranları tanımladığınızda uygulama öğün saatine göre size tavsiye edilen insülin miktarını hesaplar.',
    ),
    _GuidePageData(
      icon: Icons.notifications_active_outlined,
      color: Color(0xFF6366F1),
      title: '4. Tokluk Bildirimi, Bazal İnsülin ve Gece 03:00 Şekeri',
      description:
          'Öğün kaydettiğinizde seçtiğiniz saatten 2 saat sonrası için otomatik tokluk kan şekeri hatırlatıcısı kurulur.\n\n'
          'Ana ekranın en altında ise o güne özel "Günün Notu", "Bazal İnsülin (Vurulan Saat & Doz)" ve "Gece 03:00 Kan Şekeri" kayıt alanları yer alır.',
    ),
    _GuidePageData(
      icon: Icons.medical_information_outlined,
      color: Color(0xFFEC4899),
      title: '5. Ayarlar ve Doktor Eşliğinde Kullanım',
      description:
          'Ayarlar menüsünden bildirimleri açıp kapatabilir, bildirim sesini değiştirebilir, kan şekeri uyarı sınırlarını ve gece modunu özelleştirebilirsiniz.\n\n'
          'Unutmayın: Tüm insülin dozu kararlarınızı mutlaka doktorunuza danışarak uygulamalısınız.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Uygulama Kullanım Rehberi',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (idx) {
                  setState(() => _currentPage = idx);
                },
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.all(28.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color: page.color.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            page.icon,
                            size: 48,
                            color: page.color,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Sayfa ${index + 1} / ${_pages.length}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          page.description,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Sayfa Göstergesi ve İleri / Geri Butonları
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (idx) {
                      final active = idx == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: active ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: active
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      if (_currentPage > 0)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              _pageController.previousPage(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOut,
                              );
                            },
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Önceki Sayfa'),
                          ),
                        )
                      else
                        const Spacer(),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            if (_currentPage < _pages.length - 1) {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOut,
                              );
                            } else {
                              Navigator.of(context).pop();
                            }
                          },
                          icon: Icon(
                            _currentPage < _pages.length - 1
                                ? Icons.arrow_forward
                                : Icons.check,
                          ),
                          label: Text(
                            _currentPage < _pages.length - 1
                                ? 'Sonraki Sayfa'
                                : 'Rehberi Tamamla',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuidePageData {
  final IconData icon;
  final Color color;
  final String title;
  final String description;

  const _GuidePageData({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });
}

/// 4. BİZİ PUANLA DİYALOĞU
void showRateAppDialog(BuildContext context) {
  int selectedStars = 5;
  final commentController = TextEditingController();

  showDialog<void>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 28),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Bizi Puanla',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Gluko uygulamasını ve Glukobot asistanını beğendiniz mi? Deneyiminizi puanlayarak bize destek olabilirsiniz.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final starNumber = index + 1;
                    return IconButton(
                      onPressed: () {
                        setDialogState(() {
                          selectedStars = starNumber;
                        });
                      },
                      icon: Icon(
                        starNumber <= selectedStars
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: const Color(0xFFF59E0B),
                        size: 36,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: commentController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Görüş ve Önerileriniz (Opsiyonel)',
                    hintText: 'Uygulama hakkındaki düşünceleriniz...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Vazgeç'),
              ),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '⭐ $selectedStars yıldız puanınız ve değerli geri bildiriminiz için teşekkür ederiz!',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.send_outlined, size: 18),
                label: const Text('Gönder'),
              ),
            ],
          );
        },
      );
    },
  );
}

