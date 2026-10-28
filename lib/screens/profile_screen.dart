import 'package:flutter/material.dart';
import '../models/profile_model.dart';
import '../widgets/scrollable_time_picker.dart';

class ProfileScreen extends StatefulWidget {
  final UserProfile userProfile;
  final ValueChanged<UserProfile> onSaveProfile;

  const ProfileScreen({
    super.key,
    required this.userProfile,
    required this.onSaveProfile,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _heightController;
  late final TextEditingController _weightController;

  // Sabah, Öğle, Akşam K/İ oranı metin kontrolcüleri
  late final TextEditingController _morningRatioController;
  late final TextEditingController _noonRatioController;
  late final TextEditingController _eveningRatioController;

  late DateTime _birthDate;
  late String _selectedSensorId;
  late String _diabetesType;

  late CarbRatioSchedule _morningSchedule;
  late CarbRatioSchedule _noonSchedule;
  late CarbRatioSchedule _eveningSchedule;

  final List<String> _diabetesTypes = const [
    'Tip 1 Diyabet',
    'Tip 2 Diyabet',
    'LADA (Erişkin Tip 1)',
    'Gestasyonel Diyabet',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.userProfile;
    _firstNameController = TextEditingController(text: p.firstName);
    _lastNameController = TextEditingController(text: p.lastName);
    _heightController = TextEditingController(
      text: p.heightCm > 0 ? p.heightCm.toStringAsFixed(0) : '',
    );
    _weightController = TextEditingController(
      text: p.weightKg > 0 ? p.weightKg.toStringAsFixed(1) : '',
    );

    _morningSchedule = p.morningSchedule;
    _noonSchedule = p.noonSchedule;
    _eveningSchedule = p.eveningSchedule;

    _morningRatioController = TextEditingController(
      text: _morningSchedule.carbToInsulinRatio.toStringAsFixed(0),
    );
    _noonRatioController = TextEditingController(
      text: _noonSchedule.carbToInsulinRatio.toStringAsFixed(0),
    );
    _eveningRatioController = TextEditingController(
      text: _eveningSchedule.carbToInsulinRatio.toStringAsFixed(0),
    );

    _birthDate = p.birthDate;
    _selectedSensorId = p.selectedSensorId;
    _diabetesType = p.diabetesType;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _morningRatioController.dispose();
    _noonRatioController.dispose();
    _eveningRatioController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }

  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age < 0 ? 0 : age;
  }

  double? get _currentBmi {
    final h = double.tryParse(_heightController.text.replaceAll(',', '.'));
    final w = double.tryParse(_weightController.text.replaceAll(',', '.'));
    if (h == null || w == null || h <= 0 || w <= 0) return null;
    final hm = h / 100.0;
    return w / (hm * hm);
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate,
      firstDate: DateTime(1920, 1, 1),
      lastDate: now,
      helpText: 'Doğum Tarihinizi Seçin',
      cancelText: 'İptal',
      confirmText: 'Seç',
    );
    if (picked != null) {
      setState(() {
        _birthDate = picked;
      });
      _syncProfileSilently();
    }
  }

  Future<void> _pickScheduleTime({
    required CarbRatioSchedule current,
    required bool isStart,
    required ValueChanged<CarbRatioSchedule> onChanged,
  }) async {
    final initial = TimeOfDay(
      hour: isStart ? current.startHour : current.endHour,
      minute: isStart ? current.startMinute : current.endMinute,
    );
    final picked = await showScrollableTimePicker(
      context: context,
      initialTime: initial,
      title:
          '${current.periodName} ${isStart ? "Başlangıç" : "Bitiş"} Saatini Kaydırarak Seçin',
    );
    if (picked != null) {
      onChanged(
        isStart
            ? current.copyWith(
                startHour: picked.hour,
                startMinute: picked.minute,
              )
            : current.copyWith(
                endHour: picked.hour,
                endMinute: picked.minute,
              ),
      );
      _syncProfileSilently();
    }
  }

  UserProfile _buildCurrentProfile() {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final height =
        double.tryParse(_heightController.text.replaceAll(',', '.')) ?? 0.0;
    final weight =
        double.tryParse(_weightController.text.replaceAll(',', '.')) ?? 0.0;

    final morningRatio =
        double.tryParse(_morningRatioController.text.replaceAll(',', '.')) ??
        _morningSchedule.carbToInsulinRatio;
    final noonRatio =
        double.tryParse(_noonRatioController.text.replaceAll(',', '.')) ??
        _noonSchedule.carbToInsulinRatio;
    final eveningRatio =
        double.tryParse(_eveningRatioController.text.replaceAll(',', '.')) ??
        _eveningSchedule.carbToInsulinRatio;

    _morningSchedule = _morningSchedule.copyWith(
      carbToInsulinRatio: morningRatio <= 0 ? 8.0 : morningRatio,
    );
    _noonSchedule = _noonSchedule.copyWith(
      carbToInsulinRatio: noonRatio <= 0 ? 10.0 : noonRatio,
    );
    _eveningSchedule = _eveningSchedule.copyWith(
      carbToInsulinRatio: eveningRatio <= 0 ? 12.0 : eveningRatio,
    );

    return UserProfile(
      firstName: firstName.isEmpty ? widget.userProfile.firstName : firstName,
      lastName: lastName.isEmpty ? widget.userProfile.lastName : lastName,
      birthDate: _birthDate,
      heightCm: height,
      weightKg: weight,
      selectedSensorId: _selectedSensorId,
      diabetesType: _diabetesType,
      morningSchedule: _morningSchedule,
      noonSchedule: _noonSchedule,
      eveningSchedule: _eveningSchedule,
    );
  }

  void _syncProfileSilently() {
    final updated = _buildCurrentProfile();
    setState(() {});
    widget.onSaveProfile(updated);
  }

  void _saveCarbRatiosOnly() {
    final updated = _buildCurrentProfile();
    setState(() {});
    widget.onSaveProfile(updated);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'K/İ Oranları kaydedildi: Sabah (${updated.morningSchedule.formattedTimeRange}) 1Ü=${updated.morningSchedule.carbToInsulinRatio.toStringAsFixed(0)}g • Öğle (${updated.noonSchedule.formattedTimeRange}) 1Ü=${updated.noonSchedule.carbToInsulinRatio.toStringAsFixed(0)}g • Akşam (${updated.eveningSchedule.formattedTimeRange}) 1Ü=${updated.eveningSchedule.carbToInsulinRatio.toStringAsFixed(0)}g',
        ),
      ),
    );
  }

  void _openSensorSelectionPopup() {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.sensors, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Şeker Takip Sensörü Seçin',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => Navigator.of(ctx).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: kAvailableGlucoseSensors.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final sensor = kAvailableGlucoseSensors[index];
                final isSelected = sensor.id == _selectedSensorId;
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedSensorId = sensor.id;
                    });
                    _syncProfileSilently();
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        duration: const Duration(seconds: 2),
                        content: Text(
                          'Aktif sensör "${sensor.name}" olarak seçildi.',
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.colorScheme.primaryContainer.withValues(
                              alpha: 0.65,
                            )
                          : theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      sensor.name,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          theme.colorScheme.secondaryContainer,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${sensor.brand} • ${sensor.durationText}',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: theme
                                            .colorScheme
                                            .onSecondaryContainer,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                sensor.description,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Kapat'),
            ),
          ],
        );
      },
    );
  }

  void _saveProfile() {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();

    if (firstName.isEmpty || lastName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen isim ve soyisim alanlarını doldurun.'),
        ),
      );
      return;
    }

    final updated = _buildCurrentProfile();
    setState(() {});
    widget.onSaveProfile(updated);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Kişisel bilgiler, sensör ve Sabah/Öğle/Akşam K/İ oranlarınız kaydedildi!',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedSensor = kAvailableGlucoseSensors.firstWhere(
      (s) => s.id == _selectedSensorId,
      orElse: () => kAvailableGlucoseSensors.first,
    );
    final bmi = _currentBmi;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Üst Profil Özet Kartı
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        child: Text(
                          _firstNameController.text.trim().isNotEmpty
                              ? _firstNameController.text.trim()[0].toUpperCase()
                              : 'D',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'
                                      .trim()
                                      .isEmpty
                                  ? 'Profil Bilgileri'
                                  : '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$_diabetesType • Yaş: ${_calculateAge(_birthDate)}${bmi != null ? " • VKİ: ${bmi.toStringAsFixed(1)}" : ""}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  Icons.sensors,
                                  size: 16,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'Aktif Sensör: ${selectedSensor.name}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
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
                  const Divider(height: 20),
                  Text(
                    'Kaydedilmiş K/İ Oranları:',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: _SavedRatioSummaryBadge(
                          title: 'Sabah',
                          timeRange: _morningSchedule.formattedTimeRange,
                          ratioText:
                              '1Ü = ${_morningSchedule.carbToInsulinRatio.toStringAsFixed(0)}g KH',
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _SavedRatioSummaryBadge(
                          title: 'Öğle',
                          timeRange: _noonSchedule.formattedTimeRange,
                          ratioText:
                              '1Ü = ${_noonSchedule.carbToInsulinRatio.toStringAsFixed(0)}g KH',
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _SavedRatioSummaryBadge(
                          title: 'Akşam',
                          timeRange: _eveningSchedule.formattedTimeRange,
                          ratioText:
                              '1Ü = ${_eveningSchedule.carbToInsulinRatio.toStringAsFixed(0)}g KH',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 1. BÖLÜM: KİŞİSEL BİLGİLER
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Kişisel Bilgiler',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'İsim, soyisim, doğum tarihi, boy ve kilo bilgilerinizi girin.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // İsim ve Soyisim
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _firstNameController,
                            onChanged: (_) => _syncProfileSilently(),
                            decoration: const InputDecoration(
                              labelText: 'İsim',
                              prefixIcon: Icon(Icons.badge_outlined),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _lastNameController,
                            onChanged: (_) => _syncProfileSilently(),
                            decoration: const InputDecoration(
                              labelText: 'Soyisim',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Doğum Tarihi
                    InkWell(
                      onTap: _pickBirthDate,
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Doğum Tarihi',
                          prefixIcon: Icon(Icons.cake_outlined),
                          suffixIcon: Icon(Icons.calendar_month_outlined),
                          border: OutlineInputBorder(),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDate(_birthDate),
                              style: theme.textTheme.bodyLarge,
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${_calculateAge(_birthDate)} Yaşında',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSecondaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Boy ve Kilo
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _heightController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: (_) => _syncProfileSilently(),
                            decoration: const InputDecoration(
                              labelText: 'Boy (cm)',
                              hintText: 'Örn: 175',
                              suffixText: 'cm',
                              prefixIcon: Icon(Icons.height),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _weightController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: (_) => _syncProfileSilently(),
                            decoration: const InputDecoration(
                              labelText: 'Kilo (kg)',
                              hintText: 'Örn: 70',
                              suffixText: 'kg',
                              prefixIcon: Icon(Icons.monitor_weight_outlined),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 2. BÖLÜM: DİYABET BİLGİLERİ, SABAH/ÖĞLE/AKŞAM K/İ ORANLARI & SENSÖR SEÇİMİ
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.medical_information_outlined,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Diyabet Bilgileri',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sabah, Öğle ve Akşam saat aralıkları için ayrı K/İ oranlarınızı kaydedin ve güncel şeker takip sensörünüzü seçin.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Diyabet Tipi
                    DropdownButtonFormField<String>(
                      initialValue: _diabetesType,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Diyabet Tipi',
                        border: OutlineInputBorder(),
                      ),
                      items: _diabetesTypes.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(
                            type,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _diabetesType = val);
                          _syncProfileSilently();
                        }
                      },
                    ),
                    const SizedBox(height: 20),

                    // Sabah, Öğle, Akşam Saat Aralıklı K/İ Oranları
                    Text(
                      'Sabah, Öğle ve Akşam K/İ Oranları (Ayrı Ayrı Kaydedilir)',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Her zaman dilimi için başlangıç/bitiş saatini ve 1 Ünite insülinin karşıladığı karbonhidrat miktarını (gram) ayrı ayrı girin.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Sabah K/İ Kartı
                    _CarbScheduleRowCard(
                      icon: Icons.wb_sunny_outlined,
                      color: const Color(0xFFF59E0B),
                      schedule: _morningSchedule,
                      ratioController: _morningRatioController,
                      onRatioChanged: (_) => _syncProfileSilently(),
                      onPickStart: () => _pickScheduleTime(
                        current: _morningSchedule,
                        isStart: true,
                        onChanged: (s) => setState(() => _morningSchedule = s),
                      ),
                      onPickEnd: () => _pickScheduleTime(
                        current: _morningSchedule,
                        isStart: false,
                        onChanged: (s) => setState(() => _morningSchedule = s),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Öğle K/İ Kartı
                    _CarbScheduleRowCard(
                      icon: Icons.wb_sunny,
                      color: const Color(0xFF10B981),
                      schedule: _noonSchedule,
                      ratioController: _noonRatioController,
                      onRatioChanged: (_) => _syncProfileSilently(),
                      onPickStart: () => _pickScheduleTime(
                        current: _noonSchedule,
                        isStart: true,
                        onChanged: (s) => setState(() => _noonSchedule = s),
                      ),
                      onPickEnd: () => _pickScheduleTime(
                        current: _noonSchedule,
                        isStart: false,
                        onChanged: (s) => setState(() => _noonSchedule = s),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Akşam K/İ Kartı
                    _CarbScheduleRowCard(
                      icon: Icons.nights_stay_outlined,
                      color: const Color(0xFF6366F1),
                      schedule: _eveningSchedule,
                      ratioController: _eveningRatioController,
                      onRatioChanged: (_) => _syncProfileSilently(),
                      onPickStart: () => _pickScheduleTime(
                        current: _eveningSchedule,
                        isStart: true,
                        onChanged: (s) => setState(() => _eveningSchedule = s),
                      ),
                      onPickEnd: () => _pickScheduleTime(
                        current: _eveningSchedule,
                        isStart: false,
                        onChanged: (s) => setState(() => _eveningSchedule = s),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Sabah/Öğle/Akşam K/İ Oranlarını Hemen Kaydet Butonu
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        onPressed: _saveCarbRatiosOnly,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text(
                          'Sabah, Öğle ve Akşam K/İ Oranlarını Kaydet',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Tıbbi Uyarı Kutusu
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFF59E0B)),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Color(0xFFB45309),
                            size: 22,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              kMedicalDisclaimerText,
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF92400E),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Güncel Kullanılan Şeker Takip Sensörü Seçimi (Tıklanınca Açılan Pop-up Menü)
                    Text(
                      'Güncel Kullanılan Şeker Takip Sensörü Seçimi',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Kullandığınız sensörü değiştirmek için aşağıdaki alana dokunarak açılan pop-up menüden seçim yapabilirsiniz.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      key: const Key('sensor_popup_trigger'),
                      onTap: _openSensorSelectionPopup,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withValues(
                            alpha: 0.45,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: theme.colorScheme.primary,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                              child: const Icon(Icons.sensors),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          selectedSensor.name,
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: theme
                                              .colorScheme
                                              .secondaryContainer,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          '${selectedSensor.brand} • ${selectedSensor.durationText}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: theme
                                                .colorScheme
                                                .onSecondaryContainer,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    selectedSensor.description,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.open_in_new,
                                  size: 20,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Seç',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Kaydet Butonu
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _saveProfile,
                icon: const Icon(Icons.save_outlined),
                label: const Text(
                  'Kişisel ve Diyabet Bilgilerini Kaydet',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedRatioSummaryBadge extends StatelessWidget {
  final String title;
  final String timeRange;
  final String ratioText;

  const _SavedRatioSummaryBadge({
    required this.title,
    required this.timeRange,
    required this.ratioText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: theme.colorScheme.primary,
            ),
          ),
          Text(
            timeRange,
            style: const TextStyle(fontSize: 10),
          ),
          const SizedBox(height: 2),
          Text(
            ratioText,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _CarbScheduleRowCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final CarbRatioSchedule schedule;
  final TextEditingController ratioController;
  final ValueChanged<String> onRatioChanged;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  const _CarbScheduleRowCard({
    required this.icon,
    required this.color,
    required this.schedule,
    required this.ratioController,
    required this.onRatioChanged,
    required this.onPickStart,
    required this.onPickEnd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: color.withValues(alpha: 0.18),
                foregroundColor: color,
                child: Icon(icon, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${schedule.periodName} K/İ Oranı ve Saat Aralığı',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: OutlinedButton.icon(
                  onPressed: onPickStart,
                  icon: const Icon(Icons.schedule, size: 16),
                  label: Text(
                    'Başlangıç: ${schedule.formattedStart}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 3,
                child: OutlinedButton.icon(
                  onPressed: onPickEnd,
                  icon: const Icon(Icons.schedule, size: 16),
                  label: Text(
                    'Bitiş: ${schedule.formattedEnd}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: TextField(
                  controller: ratioController,
                  onChanged: onRatioChanged,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: '1Ü = ? KH',
                    suffixText: 'g',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
