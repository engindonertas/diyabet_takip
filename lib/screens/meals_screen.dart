import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/meal_models.dart';
import '../models/profile_model.dart';
import '../widgets/scrollable_time_picker.dart';

class MealsScreen extends StatefulWidget {
  final List<MealRecord> meals;
  final List<FoodReference> foodDatabase;
  final List<ExtraDoseRecord> extraDoses;
  final ValueChanged<ExtraDoseRecord> onAddExtraDose;
  final ValueChanged<ExtraDoseRecord> onUpdateExtraDose;
  final ValueChanged<String> onDeleteExtraDose;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelectDate;
  final UserProfile userProfile;
  final DailyExtraLog currentDayExtraLog;
  final ValueChanged<DailyExtraLog> onUpdateDailyExtraLog;
  final ValueChanged<MealRecord> onAddMeal;
  final ValueChanged<MealRecord> onUpdateMeal;
  final ValueChanged<String> onDeleteMeal;
  final ValueChanged<MealRecord> onTriggerPostprandialNotification;

  const MealsScreen({
    super.key,
    required this.meals,
    this.foodDatabase = kTurkishFoodDatabase,
    this.extraDoses = const [],
    this.onAddExtraDose = _defaultExtraDoseCallback,
    this.onUpdateExtraDose = _defaultExtraDoseCallback,
    this.onDeleteExtraDose = _defaultDeleteCallback,
    required this.selectedDate,
    required this.onSelectDate,
    required this.userProfile,
    required this.currentDayExtraLog,
    required this.onUpdateDailyExtraLog,
    required this.onAddMeal,
    required this.onUpdateMeal,
    required this.onDeleteMeal,
    required this.onTriggerPostprandialNotification,
  });

  static void _defaultExtraDoseCallback(ExtraDoseRecord _) {}
  static void _defaultDeleteCallback(String _) {}

  @override
  State<MealsScreen> createState() => _MealsScreenState();
}

class _MealsScreenState extends State<MealsScreen> {
  static const int _initialWeekPage = 500;
  late final PageController _weekPageController;
  late DateTime _baseMonday;

  // Ek Doz (Düzeltme İnsülini) kontrolcüleri (Not alma kısmının üstünde)
  late String _extraDoseTime;
  final TextEditingController _extraDoseUnitsController =
      TextEditingController();
  final TextEditingController _extraDoseBeforeSugarController =
      TextEditingController();
  final TextEditingController _extraDoseAfterSugarController =
      TextEditingController();

  // Günlük Not, Bazal İnsülin (Saat & Doz) ve Gece 03:00 Kan Şekeri kontrolcüleri
  late final TextEditingController _dailyNoteController;
  late String _basalTime;
  late final TextEditingController _basalUnitsController;
  late final TextEditingController _night3AmSugarController;

  @override
  void initState() {
    super.initState();
    _baseMonday = _mondayOfWeek(DateTime.now());
    _weekPageController = PageController(initialPage: _initialWeekPage);
    final now = DateTime.now();
    _extraDoseTime =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final extra = widget.currentDayExtraLog;
    _dailyNoteController = TextEditingController(text: extra.dailyNote);
    _basalTime = extra.basalInsulinTime.isEmpty
        ? '22:00'
        : extra.basalInsulinTime;
    _basalUnitsController = TextEditingController(
      text: extra.basalInsulinUnits != null
          ? extra.basalInsulinUnits!.toStringAsFixed(0)
          : '',
    );
    _night3AmSugarController = TextEditingController(
      text: extra.night3AmBloodSugar != null
          ? extra.night3AmBloodSugar!.toStringAsFixed(0)
          : '',
    );
  }

  @override
  void didUpdateWidget(covariant MealsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isSameDay(oldWidget.selectedDate, widget.selectedDate)) {
      final extra = widget.currentDayExtraLog;
      _dailyNoteController.text = extra.dailyNote;
      _basalTime = extra.basalInsulinTime.isEmpty
          ? '22:00'
          : extra.basalInsulinTime;
      _basalUnitsController.text = extra.basalInsulinUnits != null
          ? extra.basalInsulinUnits!.toStringAsFixed(0)
          : '';
      _night3AmSugarController.text = extra.night3AmBloodSugar != null
          ? extra.night3AmBloodSugar!.toStringAsFixed(0)
          : '';
    }
  }

  @override
  void dispose() {
    _weekPageController.dispose();
    _extraDoseUnitsController.dispose();
    _extraDoseBeforeSugarController.dispose();
    _extraDoseAfterSugarController.dispose();
    _dailyNoteController.dispose();
    _basalUnitsController.dispose();
    _night3AmSugarController.dispose();
    super.dispose();
  }

  List<ExtraDoseRecord> get _extraDosesForSelectedDate {
    final filtered = widget.extraDoses
        .where((d) => _isSameDay(d.dateTime, widget.selectedDate))
        .toList();
    filtered.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return filtered;
  }

  Future<void> _pickExtraDoseTime() async {
    int initialHour = DateTime.now().hour;
    int initialMinute = DateTime.now().minute;
    final parts = _extraDoseTime.split(':');
    if (parts.length == 2) {
      initialHour = int.tryParse(parts[0]) ?? initialHour;
      initialMinute = int.tryParse(parts[1]) ?? initialMinute;
    }

    final picked = await showScrollableTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: initialHour.clamp(0, 23),
        minute: initialMinute.clamp(0, 59),
      ),
      title: 'Ek Doz Vurulan Saati Seçin',
    );

    if (picked != null) {
      setState(() {
        _extraDoseTime =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  void _saveInlineExtraDose() {
    final units = int.tryParse(_extraDoseUnitsController.text.trim());
    final beforeSugar = double.tryParse(
      _extraDoseBeforeSugarController.text.trim().replaceAll(',', '.'),
    );
    final afterSugar = double.tryParse(
      _extraDoseAfterSugarController.text.trim().replaceAll(',', '.'),
    );

    if (units == null ||
        units <= 0 ||
        beforeSugar == null ||
        beforeSugar <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Lütfen vurulan ek doz ünitesini ve öncesi kan şekerini girin.',
          ),
        ),
      );
      return;
    }

    final parts = _extraDoseTime.split(':');
    final hour = parts.length == 2 ? (int.tryParse(parts[0]) ?? 12) : 12;
    final minute = parts.length == 2 ? (int.tryParse(parts[1]) ?? 0) : 0;

    final record = ExtraDoseRecord(
      id: 'ed_${DateTime.now().microsecondsSinceEpoch}',
      dateTime: DateTime(
        widget.selectedDate.year,
        widget.selectedDate.month,
        widget.selectedDate.day,
        hour,
        minute,
      ),
      insulinUnits: units.toDouble(),
      bloodSugarBefore: beforeSugar,
      bloodSugarAfter: afterSugar,
      note: 'Ana ekrandan kaydedilen ek doz',
    );

    widget.onAddExtraDose(record);
    setState(() {
      _extraDoseUnitsController.clear();
      _extraDoseBeforeSugarController.clear();
      _extraDoseAfterSugarController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          afterSugar != null
              ? '💉 $units Ünite ek doz ($_extraDoseTime) kaydedildi ve Glukobot Ek Doz analizine eklendi!'
              : '💉 $units Ünite ek doz ($_extraDoseTime) kaydedildi. Sonrası kan şekerini ölçtüğünüzde güncelleyebilirsiniz.',
        ),
      ),
    );
  }

  void _openEditExtraDoseDialog(ExtraDoseRecord dose) {
    String editTime =
        '${dose.dateTime.hour.toString().padLeft(2, '0')}:${dose.dateTime.minute.toString().padLeft(2, '0')}';
    final unitsCtrl = TextEditingController(
      text: dose.insulinUnits.toStringAsFixed(0),
    );
    final beforeCtrl = TextEditingController(
      text: dose.bloodSugarBefore.toStringAsFixed(0),
    );
    final afterCtrl = TextEditingController(
      text: dose.bloodSugarAfter != null
          ? dose.bloodSugarAfter!.toStringAsFixed(0)
          : '',
    );

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text(
            'Ek Doz Kaydını Düzenle',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScrollableTimeSelectorBox(
                  label: 'Vurulan Saat',
                  timeText: editTime,
                  onTap: () async {
                    final parts = editTime.split(':');
                    final h = int.tryParse(parts[0]) ?? 12;
                    final m = int.tryParse(parts[1]) ?? 0;
                    final picked = await showScrollableTimePicker(
                      context: ctx,
                      initialTime: TimeOfDay(hour: h, minute: m),
                      title: 'Ek Doz Saatini Seçin',
                    );
                    if (picked != null) {
                      setDialogState(() {
                        editTime =
                            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                      });
                    }
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: unitsCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'İnsülin Dozu (Ünite)',
                    suffixText: 'Ünite',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: beforeCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Öncesi KŞ',
                          suffixText: 'mg/dL',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: afterCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Sonrası KŞ',
                          suffixText: 'mg/dL',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () {
                final u = int.tryParse(unitsCtrl.text.trim());
                final b = double.tryParse(beforeCtrl.text.trim());
                final a = double.tryParse(afterCtrl.text.trim());
                if (u == null || u <= 0 || b == null || b <= 0) return;
                final parts = editTime.split(':');
                final h = int.tryParse(parts[0]) ?? dose.dateTime.hour;
                final m = int.tryParse(parts[1]) ?? dose.dateTime.minute;
                widget.onUpdateExtraDose(
                  dose.copyWith(
                    dateTime: DateTime(
                      dose.dateTime.year,
                      dose.dateTime.month,
                      dose.dateTime.day,
                      h,
                      m,
                    ),
                    insulinUnits: u.toDouble(),
                    bloodSugarBefore: b,
                    bloodSugarAfter: a,
                  ),
                );
                Navigator.of(ctx).pop();
              },
              child: const Text('Güncelle'),
            ),
          ],
        ),
      ),
    );
  }

  void _syncExtraLog({bool showFeedback = false, String? message}) {
    final basalUnits = int.tryParse(
      _basalUnitsController.text.trim(),
    )?.toDouble();
    final nightSugar = double.tryParse(
      _night3AmSugarController.text.trim().replaceAll(',', '.'),
    );

    final updated = DailyExtraLog(
      dailyNote: _dailyNoteController.text,
      basalInsulinTime: _basalTime,
      basalInsulinUnits: basalUnits,
      night3AmBloodSugar: nightSugar,
    );

    widget.onUpdateDailyExtraLog(updated);

    if (showFeedback && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          content: Text(message ?? 'Günlük kayıt güncellendi.'),
        ),
      );
    }
  }

  Future<void> _pickBasalTime() async {
    int initialHour = 22;
    int initialMinute = 0;
    final parts = _basalTime.split(':');
    if (parts.length == 2) {
      initialHour = int.tryParse(parts[0]) ?? 22;
      initialMinute = int.tryParse(parts[1]) ?? 0;
    }

    final picked = await showScrollableTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: initialHour.clamp(0, 23),
        minute: initialMinute.clamp(0, 59),
      ),
      title: 'Bazal İnsülin Vurulan Saati Seçin',
    );

    if (picked != null) {
      final formatted =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        _basalTime = formatted;
      });
      _syncExtraLog();
    }
  }

  static DateTime _mondayOfWeek(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized.subtract(Duration(days: normalized.weekday - 1));
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _jumpCalendarToDate(DateTime target) {
    final targetMonday = _mondayOfWeek(target);
    final diffDays = targetMonday.difference(_baseMonday).inDays;
    final targetPage = _initialWeekPage + (diffDays ~/ 7);
    if (_weekPageController.hasClients) {
      _weekPageController.animateToPage(
        targetPage,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
    widget.onSelectDate(DateTime(target.year, target.month, target.day));
  }

  Future<void> _pickDateFromCalendar() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.selectedDate,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2035, 12, 31),
      helpText: 'Takvimden Gün Seçin',
      cancelText: 'İptal',
      confirmText: 'Seç',
    );
    if (picked != null) {
      _jumpCalendarToDate(picked);
    }
  }

  List<MealRecord> get _mealsForSelectedDate {
    final filtered = widget.meals
        .where((m) => _isSameDay(m.dateTime, widget.selectedDate))
        .toList();
    filtered.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return filtered;
  }

  bool _hasMealsOnDay(DateTime day) {
    return widget.meals.any((m) => _isSameDay(m.dateTime, day));
  }

  double get _totalDailyCarbs =>
      _mealsForSelectedDate.fold(0.0, (sum, meal) => sum + meal.totalCarbs);

  double get _totalDailyGrams =>
      _mealsForSelectedDate.fold(0.0, (sum, meal) => sum + meal.totalGrams);

  double get _totalDailyInsulin =>
      _mealsForSelectedDate.fold(0.0, (sum, meal) => sum + meal.insulinUnits);

  void _openMealForm(BuildContext context, {MealRecord? existingMeal}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => MealEntrySheet(
        existingMeal: existingMeal,
        initialDate: widget.selectedDate,
        userProfile: widget.userProfile,
        foodDatabase: widget.foodDatabase,
        onSave: (record) {
          if (existingMeal != null) {
            widget.onUpdateMeal(record);
          } else {
            widget.onAddMeal(record);
          }
        },
      ),
    );
  }

  void _promptPostprandialEntry(MealRecord meal) {
    final controller = TextEditingController(
      text: meal.postprandialBloodSugar != null
          ? meal.postprandialBloodSugar!.toStringAsFixed(0)
          : '',
    );

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.bloodtype_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text('${meal.mealType.label} • Tokluk Kan Şekeri'),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Öğün Saati: ${_formatTime(meal.dateTime)} • 2. Saat Ölçüm Zamanı: ${_formatTime(meal.postprandialReminderTime)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (meal.fastingBloodSugar != null) ...[
              const SizedBox(height: 4),
              Text(
                'Açlık Kan Şekeri: ${meal.fastingBloodSugar!.toStringAsFixed(0)} mg/dL',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: '2. Saat Tokluk Kan Şekeri (mg/dL)',
                hintText: 'Örn: 140',
                suffixText: 'mg/dL',
                prefixIcon: Icon(Icons.bloodtype),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('İptal'),
          ),
          FilledButton.icon(
            onPressed: () {
              final val = double.tryParse(
                controller.text.trim().replaceAll(',', '.'),
              );
              if (val != null && val > 0) {
                widget.onUpdateMeal(
                  meal.copyWith(
                    postprandialBloodSugar: val,
                    isPostprandialNotified: true,
                  ),
                );
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${meal.mealType.label} için tokluk kan şekeri (${val.toStringAsFixed(0)} mg/dL) kaydedildi.',
                    ),
                  ),
                );
              }
            },
            icon: const Icon(Icons.check),
            label: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatFullDate(DateTime dt) {
    const months = [
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  static const List<String> _shortWeekdays = [
    'Pzt',
    'Sal',
    'Çar',
    'Per',
    'Cum',
    'Cmt',
    'Paz',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dayMeals = _mealsForSelectedDate;
    final pendingPostprandialMeals = dayMeals
        .where((m) => m.postprandialBloodSugar == null)
        .toList();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Üst 7 Günlük Kaydırılabilir Takvim Şeridi
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_month,
                                  size: 20,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _formatFullDate(widget.selectedDate),
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                if (!_isSameDay(
                                  widget.selectedDate,
                                  DateTime.now(),
                                ))
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    onPressed: () =>
                                        _jumpCalendarToDate(DateTime.now()),
                                    child: const Text('Bugün'),
                                  ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  tooltip: 'Önceki Hafta',
                                  onPressed: () {
                                    _weekPageController.previousPage(
                                      duration: const Duration(
                                        milliseconds: 250,
                                      ),
                                      curve: Curves.easeOut,
                                    );
                                  },
                                  icon: const Icon(Icons.chevron_left),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  tooltip: 'Sonraki Hafta',
                                  onPressed: () {
                                    _weekPageController.nextPage(
                                      duration: const Duration(
                                        milliseconds: 250,
                                      ),
                                      curve: Curves.easeOut,
                                    );
                                  },
                                  icon: const Icon(Icons.chevron_right),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  tooltip: 'Takvimden Seç',
                                  onPressed: _pickDateFromCalendar,
                                  icon: const Icon(Icons.edit_calendar_outlined),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 70,
                          child: PageView.builder(
                            controller: _weekPageController,
                            onPageChanged: (page) {
                              final weekOffset = page - _initialWeekPage;
                              final newMonday = _baseMonday.add(
                                Duration(days: weekOffset * 7),
                              );
                              final currentWeekdayOffset =
                                  widget.selectedDate.weekday - 1;
                              final newSelected = newMonday.add(
                                Duration(days: currentWeekdayOffset),
                              );
                              widget.onSelectDate(newSelected);
                            },
                            itemBuilder: (context, pageIndex) {
                              final weekOffset = pageIndex - _initialWeekPage;
                              final weekStart = _baseMonday.add(
                                Duration(days: weekOffset * 7),
                              );
                              return Row(
                                children: List.generate(7, (dayIdx) {
                                  final day = DateTime(
                                    weekStart.year,
                                    weekStart.month,
                                    weekStart.day + dayIdx,
                                  );
                                  final isSelected = _isSameDay(
                                    day,
                                    widget.selectedDate,
                                  );
                                  final isToday = _isSameDay(
                                    day,
                                    DateTime.now(),
                                  );
                                  final hasMeals = _hasMealsOnDay(day);

                                  return Expanded(
                                    child: GestureDetector(
                                      onTap: () => widget.onSelectDate(day),
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 180,
                                        ),
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? theme.colorScheme.primary
                                              : isToday
                                              ? theme
                                                    .colorScheme
                                                    .primaryContainer
                                              : theme.colorScheme.surface,
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          border: Border.all(
                                            color: isSelected
                                                ? theme.colorScheme.primary
                                                : isToday
                                                ? theme.colorScheme.primary
                                                : theme
                                                      .colorScheme
                                                      .outlineVariant,
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              _shortWeekdays[dayIdx],
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: isSelected
                                                    ? theme
                                                          .colorScheme
                                                          .onPrimary
                                                    : theme
                                                          .colorScheme
                                                          .onSurfaceVariant,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${day.day}',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: isSelected
                                                    ? theme
                                                          .colorScheme
                                                          .onPrimary
                                                    : theme
                                                          .colorScheme
                                                          .onSurface,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Container(
                                              width: 6,
                                              height: 6,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: hasMeals
                                                    ? (isSelected
                                                          ? Colors.white
                                                          : theme
                                                                .colorScheme
                                                                .primary)
                                                    : Colors.transparent,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Üst karşılama satırı (Sadece Merhaba ve İsim)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Merhaba, ${widget.userProfile.firstName.isEmpty ? "Kullanıcı" : widget.userProfile.firstName}',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () => _openMealForm(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Öğün Ekle'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 2. Saat Tokluk Kan Şekeri Hatırlatıcı Bölümü
                  if (pendingPostprandialMeals.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFF59E0B)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.notifications_active_outlined,
                                color: Color(0xFFB45309),
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '2. Saat Tokluk Kan Şekeri Hatırlatıcıları',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ...pendingPostprandialMeals.map((m) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '• ${m.mealType.label} (${_formatTime(m.dateTime)}) → 2. Saat Tokluk Ölçümü: ${_formatTime(m.postprandialReminderTime)}',
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        color: Color(0xFF92400E),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    onPressed: () =>
                                        widget.onTriggerPostprandialNotification(
                                          m,
                                        ),
                                    child: const Text('Bildirimi Gör'),
                                  ),
                                  FilledButton.tonal(
                                    style: FilledButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    onPressed: () =>
                                        _promptPostprandialEntry(m),
                                    child: const Text('Tokluk Gir'),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Seçili Günün Özet Kartı
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.tertiary,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.25,
                          ),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${_formatFullDate(widget.selectedDate)} Özeti',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${dayMeals.length} Öğün',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _SummaryMetricTile(
                                label: 'Toplam Karbonhidrat',
                                value:
                                    '${_totalDailyCarbs.toStringAsFixed(1)} g',
                                icon: Icons.grain,
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: Colors.white24,
                            ),
                            Expanded(
                              child: _SummaryMetricTile(
                                label: 'Toplam Gramaj',
                                value:
                                    '${_totalDailyGrams.toStringAsFixed(0)} g',
                                icon: Icons.scale_outlined,
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: Colors.white24,
                            ),
                            Expanded(
                              child: _SummaryMetricTile(
                                label: 'Öğün İnsülini',
                                value:
                                    '${_totalDailyInsulin.toStringAsFixed(0)} Ü',
                                icon: Icons.vaccines_outlined,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Seçili Gündeki Öğünler (${dayMeals.length})',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (dayMeals.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 20.0,
                ),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.35,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.restaurant_menu_outlined,
                        size: 44,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_formatFullDate(widget.selectedDate)} tarihinde öğün kaydı yok.',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Bu güne öğün, saat, açlık/tokluk kan şekeri, karbonhidrat ve insülin kaydı eklemek için "Öğün Ekle" butonuna dokunun.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              sliver: SliverList.separated(
                itemCount: dayMeals.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final meal = dayMeals[index];
                  final mealSchedule = widget.userProfile.getScheduleForTime(
                    meal.dateTime,
                  );
                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Öğün Başlığı + Saat + İnsülin Rozeti
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: meal.mealType.color.withValues(
                                  alpha: 0.15,
                                ),
                                foregroundColor: meal.mealType.color,
                                child: Icon(meal.mealType.icon),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      meal.mealType.label,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    Text(
                                      'Öğün Saati: ${_formatTime(meal.dateTime)} • ${mealSchedule.periodName} K/İ: 1Ü=${mealSchedule.carbToInsulinRatio.toStringAsFixed(0)}g',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              // Vurulan İnsülin Rozeti
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.vaccines,
                                      size: 16,
                                      color:
                                          theme.colorScheme.onPrimaryContainer,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${meal.insulinUnits.toStringAsFixed(0)} Ü İnsülin',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: theme
                                            .colorScheme
                                            .onPrimaryContainer,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (action) {
                                  if (action == 'edit') {
                                    _openMealForm(
                                      context,
                                      existingMeal: meal,
                                    );
                                  } else if (action == 'tokluk') {
                                    _promptPostprandialEntry(meal);
                                  } else if (action == 'delete') {
                                    widget.onDeleteMeal(meal.id);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'tokluk',
                                    child: Row(
                                      children: [
                                        Icon(Icons.bloodtype_outlined, size: 18),
                                        SizedBox(width: 8),
                                        Text('Tokluk Kan Şekeri Gir'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit_outlined, size: 18),
                                        SizedBox(width: 8),
                                        Text('Düzenle'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.delete_outline,
                                          size: 18,
                                          color: Colors.red,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Sil',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Açlık ve Tokluk Kan Şekeri Bilgisi Satırı
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: theme
                                      .colorScheme
                                      .surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.water_drop_outlined,
                                      size: 15,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      meal.fastingBloodSugar != null
                                          ? 'Açlık Şekeri: ${meal.fastingBloodSugar!.toStringAsFixed(0)} mg/dL'
                                          : 'Açlık Şekeri: Girilmedi',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              InkWell(
                                onTap: () => _promptPostprandialEntry(meal),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: meal.postprandialBloodSugar != null
                                        ? theme.colorScheme.tertiaryContainer
                                        : const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        meal.postprandialBloodSugar != null
                                            ? Icons.check_circle_outline
                                            : Icons.alarm,
                                        size: 15,
                                        color:
                                            meal.postprandialBloodSugar != null
                                            ? theme
                                                  .colorScheme
                                                  .onTertiaryContainer
                                            : const Color(0xFFB45309),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        meal.postprandialBloodSugar != null
                                            ? 'Tokluk Şekeri (2. Saat): ${meal.postprandialBloodSugar!.toStringAsFixed(0)} mg/dL'
                                            : 'Tokluk Şekeri Gir (Ölçüm: ${_formatTime(meal.postprandialReminderTime)})',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color:
                                                  meal.postprandialBloodSugar !=
                                                      null
                                                  ? theme
                                                        .colorScheme
                                                        .onTertiaryContainer
                                                  : const Color(0xFF92400E),
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const Divider(height: 22),

                          // Yenilen yemeklerin tablosu (Yemek, Gramı, Karbonhidratı)
                          Row(
                            children: [
                              Expanded(
                                flex: 5,
                                child: Text(
                                  'Yenilen Yemek',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  'Miktar (Gram)',
                                  textAlign: TextAlign.right,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  'Karbonhidrat',
                                  textAlign: TextAlign.right,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...meal.foods.map(
                            (food) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 5,
                                    child: Text(
                                      food.foodName,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      '${food.grams.toStringAsFixed(0)} g',
                                      textAlign: TextAlign.right,
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      '${food.carbs.toStringAsFixed(1)} g KH',
                                      textAlign: TextAlign.right,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.primary,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Divider(height: 20),

                          // Öğün Toplamı Satırı
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Öğün Toplamı (${meal.foods.length} çeşit)',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    '${meal.totalGrams.toStringAsFixed(0)} g yemek',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          theme.colorScheme.secondaryContainer,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Toplam: ${meal.totalCarbs.toStringAsFixed(1)} g Karbonhidrat',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: theme
                                            .colorScheme
                                            .onSecondaryContainer,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (meal.notes.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Not: ${meal.notes}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontStyle: FontStyle.italic,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          // ANA MENÜ EN ALT KISIM:
          // 0) Not Alma Kısmının Üstünde: Ek Doz (Düzeltme İnsülini) Not Etme Kısmı
          // 1) O Gün İçin Günlük Not Kısmı
          // 2) Onun Altında Yan Yana: Bazal İnsülin (Saat & Doz) ve Gece 03:00 Kan Şekeri Kısmı
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 0. EK DOZ NOT ETME KISMI (NOT ALMA KISMININ ÜSTÜNDE)
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.add_moderator_outlined,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Ek Doz Not Etme (${_formatFullDate(widget.selectedDate)})',
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: _saveInlineExtraDose,
                                icon: const Icon(Icons.save_outlined, size: 16),
                                label: const Text('Ek Dozu Kaydet'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Vurulan saati, insülin dozunu, öncesi ve sonrası kan şekerini kaydedin. Kayıtlar Glukobot > Ek Doz sekmesine otomatik aktarılır ve ortalama etkisi hesaplanır.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 11.5,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: ScrollableTimeSelectorBox(
                                  label: 'Vurulan Saat',
                                  timeText: _extraDoseTime,
                                  onTap: _pickExtraDoseTime,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _extraDoseUnitsController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: 'İnsülin Dozu',
                                    hintText: 'Örn: 2',
                                    suffixText: 'Ünite',
                                    prefixIcon: Icon(
                                      Icons.vaccines_outlined,
                                      size: 18,
                                    ),
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _extraDoseBeforeSugarController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'Öncesi Kan Şekeri',
                                    hintText: 'Örn: 240',
                                    suffixText: 'mg/dL',
                                    prefixIcon: Icon(
                                      Icons.bloodtype_outlined,
                                      size: 18,
                                    ),
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _extraDoseAfterSugarController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'Sonrası Kan Şekeri',
                                    hintText: 'Örn: 150',
                                    suffixText: 'mg/dL',
                                    prefixIcon: Icon(
                                      Icons.water_drop_outlined,
                                      size: 18,
                                    ),
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_extraDosesForSelectedDate.isNotEmpty) ...[
                            const Divider(height: 22),
                            Text(
                              'Bu Günün Ek Doz Kayıtları (${_extraDosesForSelectedDate.length})',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            ..._extraDosesForSelectedDate.map((dose) {
                              final timeStr = _formatTime(dose.dateTime);
                              final afterStr = dose.bloodSugarAfter != null
                                  ? '${dose.bloodSugarAfter!.toStringAsFixed(0)} mg/dL'
                                  : 'Girilmedi';
                              final dropPerUnit = dose.dropPerUnit;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: theme
                                      .colorScheme
                                      .surfaceContainerHighest
                                      .withValues(alpha: 0.45),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Saat $timeStr • ${dose.insulinUnits.toStringAsFixed(0)} Ünite Ek Doz',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12.5,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Öncesi: ${dose.bloodSugarBefore.toStringAsFixed(0)} mg/dL → Sonrası: $afterStr'
                                            '${dropPerUnit != null ? "  (1Ü = -${dropPerUnit.toStringAsFixed(0)} mg/dL)" : ""}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      tooltip: 'Düzenle / Sonrası Şekeri Gir',
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 18,
                                      ),
                                      onPressed: () =>
                                          _openEditExtraDoseDialog(dose),
                                    ),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      tooltip: 'Sil',
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 18,
                                        color: Colors.red,
                                      ),
                                      onPressed: () =>
                                          widget.onDeleteExtraDose(dose.id),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 1. O GÜN İÇİN NOT KISMI
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.edit_note_outlined,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Günün Notu (${_formatFullDate(widget.selectedDate)})',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () => _syncExtraLog(
                                  showFeedback: true,
                                  message: 'Günlük notunuz kaydedildi.',
                                ),
                                icon: const Icon(Icons.save_outlined, size: 16),
                                label: const Text('Kaydet'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _dailyNoteController,
                            maxLines: 3,
                            minLines: 2,
                            onChanged: (_) => _syncExtraLog(),
                            decoration: const InputDecoration(
                              hintText:
                                  'Bugün için not etmek istediğiniz durumları (halı saha, egzersiz, stres, hipoglisemi, sensör değişimi vb.) buraya yazabilirsiniz...',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                          if (_dailyNoteController.text.toLowerCase().contains('halı saha') ||
                              _dailyNoteController.text.toLowerCase().contains('hali saha') ||
                              _dailyNoteController.text.toLowerCase().contains('futbol') ||
                              _dailyNoteController.text.toLowerCase().contains('maç')) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEDE9FE),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF7C3AED)),
                              ),
                              child: const Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.smart_toy_outlined,
                                    color: Color(0xFF6D28D9),
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '🤖 Glukobot Hafıza Uyarısı: Geçmişte halı saha / maç yaptığınız günlerde gece 03:00 kan şekerinizin hipoglisemi (<70 mg/dL) sınırının altına düştüğü hafızada kayıtlıdır! Gece şeker takibine dikkat edin ve doz/ara öğün için doktorunuza danışın.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF4C1D95),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 2. ONUN ALTINDA YAN YANA (EŞİT BOYUTTA): BAZAL İNSÜLİN VE GECE 03:00 KAN ŞEKERİ
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Sol: Bazal İnsülin Not Kısmı (Vurulan Saat ve Doz)
                        Expanded(
                          child: Card(
                            elevation: 0,
                            margin: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                              side: BorderSide(
                                color: theme.colorScheme.outlineVariant,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.vaccines_outlined,
                                        size: 20,
                                        color: theme.colorScheme.primary,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Bazal İnsülin',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Vurulan saat ve doz',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  ScrollableTimeSelectorBox(
                                    label: 'Vurulan Saat',
                                    timeText: _basalTime,
                                    onTap: _pickBasalTime,
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: _basalUnitsController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    onChanged: (_) => _syncExtraLog(),
                                    decoration: const InputDecoration(
                                      labelText: 'Doz (Ünite)',
                                      hintText: 'Örn: 18',
                                      suffixText: 'Ünite',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                  ),
                                  const Spacer(),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.tonal(
                                      style: FilledButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      onPressed: () => _syncExtraLog(
                                        showFeedback: true,
                                        message:
                                            'Bazal insülin saati ve dozu kaydedildi.',
                                      ),
                                      child: const Text('Bazal Kaydet'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Sağ: Gece 03:00 Kan Şekeri Kısmı (Sadece Kan Şekeri Girilir)
                        Expanded(
                          child: Card(
                            elevation: 0,
                            margin: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                              side: BorderSide(
                                color: theme.colorScheme.outlineVariant,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.nights_stay_outlined,
                                        size: 20,
                                        color: Color(0xFF6366F1),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Gece 03:00 Kan Şekeri',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Gece 03:00 ölçümü',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: _night3AmSugarController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    onChanged: (_) => _syncExtraLog(),
                                    decoration: const InputDecoration(
                                      labelText: 'Kan Şekeri',
                                      hintText: 'Örn: 110',
                                      suffixText: 'mg/dL',
                                      prefixIcon: Icon(
                                        Icons.bloodtype_outlined,
                                        size: 18,
                                      ),
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                  ),
                                  const Spacer(),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.tonal(
                                      style: FilledButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      onPressed: () => _syncExtraLog(
                                        showFeedback: true,
                                        message:
                                            'Gece 03:00 kan şekeri kaydedildi.',
                                      ),
                                      child: const Text('Şekeri Kaydet'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
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

class _SummaryMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SummaryMetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }
}

class MealEntrySheet extends StatefulWidget {
  final MealRecord? existingMeal;
  final DateTime initialDate;
  final UserProfile userProfile;
  final List<FoodReference> foodDatabase;
  final ValueChanged<MealRecord> onSave;

  const MealEntrySheet({
    super.key,
    this.existingMeal,
    required this.initialDate,
    required this.userProfile,
    this.foodDatabase = kTurkishFoodDatabase,
    required this.onSave,
  });

  @override
  State<MealEntrySheet> createState() => _MealEntrySheetState();
}

class _MealEntrySheetState extends State<MealEntrySheet> {
  late MealType _selectedMealType;
  late DateTime _mealDateTime;
  late List<FoodItemEntry> _foods;
  final TextEditingController _fastingSugarController = TextEditingController();
  final TextEditingController _postprandialSugarController =
      TextEditingController();
  final TextEditingController _insulinController = TextEditingController();
  final TextEditingController _extraInsulinController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  // Yeni yemek ekleme alanları
  final TextEditingController _foodNameController = TextEditingController();
  final TextEditingController _gramsController = TextEditingController();
  final TextEditingController _carbsController = TextEditingController();
  FoodReference? _selectedReferenceFood;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingMeal;
    final now = DateTime.now();
    _selectedMealType = existing?.mealType ?? MealType.kahvalti;
    _mealDateTime =
        existing?.dateTime ??
        DateTime(
          widget.initialDate.year,
          widget.initialDate.month,
          widget.initialDate.day,
          now.hour,
          now.minute,
        );
    _foods = existing != null ? List.of(existing.foods) : [];
    _fastingSugarController.text = existing?.fastingBloodSugar != null
        ? existing!.fastingBloodSugar!.toStringAsFixed(0)
        : '';
    _postprandialSugarController.text = existing?.postprandialBloodSugar != null
        ? existing!.postprandialBloodSugar!.toStringAsFixed(0)
        : '';
    _insulinController.text = existing != null
        ? existing.insulinUnits.toStringAsFixed(0)
        : '';
    _extraInsulinController.text =
        (existing != null && existing.extraInsulinUnits > 0)
        ? existing.extraInsulinUnits.toStringAsFixed(0)
        : '';
    _notesController.text = existing?.notes ?? '';
  }

  @override
  void dispose() {
    _fastingSugarController.dispose();
    _postprandialSugarController.dispose();
    _insulinController.dispose();
    _extraInsulinController.dispose();
    _notesController.dispose();
    _foodNameController.dispose();
    _gramsController.dispose();
    _carbsController.dispose();
    super.dispose();
  }

  CarbRatioSchedule get _activeSchedule =>
      widget.userProfile.getScheduleForTime(_mealDateTime);

  double get _currentTotalCarbs =>
      _foods.fold(0.0, (sum, item) => sum + item.carbs);

  double get _currentTotalGrams =>
      _foods.fold(0.0, (sum, item) => sum + item.grams);

  double get _suggestedInsulin {
    final ratio = _activeSchedule.carbToInsulinRatio;
    if (ratio <= 0 || _currentTotalCarbs <= 0) return 0.0;
    return _currentTotalCarbs / ratio;
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _pickMealTime() async {
    final picked = await showScrollableTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_mealDateTime),
      title: 'Öğün Saatini Kaydırarak Seçin',
    );
    if (picked != null) {
      setState(() {
        _mealDateTime = DateTime(
          _mealDateTime.year,
          _mealDateTime.month,
          _mealDateTime.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  void _onReferenceSelected(FoodReference? ref) {
    setState(() {
      _selectedReferenceFood = ref;
      if (ref != null) {
        _foodNameController.text = ref.name;
        _gramsController.text = ref.defaultPortionGrams.toStringAsFixed(0);
        final calculated = ref.calculateCarbs(ref.defaultPortionGrams);
        _carbsController.text = calculated.toStringAsFixed(1);
      }
    });
  }

  void _onGramsChanged(String value) {
    final grams = double.tryParse(value.replaceAll(',', '.'));
    if (grams != null && _selectedReferenceFood != null) {
      final carbs = _selectedReferenceFood!.calculateCarbs(grams);
      _carbsController.text = carbs.toStringAsFixed(1);
    }
  }

  void _addFoodToList() {
    final name = _foodNameController.text.trim();
    final grams = double.tryParse(_gramsController.text.replaceAll(',', '.'));
    final carbs = double.tryParse(_carbsController.text.replaceAll(',', '.'));

    if (name.isEmpty ||
        grams == null ||
        grams <= 0 ||
        carbs == null ||
        carbs < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Lütfen yemek adını, gramını ve karbonhidrat miktarını geçerli girin.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _foods.add(
        FoodItemEntry(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          foodName: name,
          grams: grams,
          carbs: carbs,
        ),
      );
      _selectedReferenceFood = null;
      _foodNameController.clear();
      _gramsController.clear();
      _carbsController.clear();
    });
  }

  void _saveMeal() {
    if (_foodNameController.text.trim().isNotEmpty &&
        _gramsController.text.trim().isNotEmpty &&
        _carbsController.text.trim().isNotEmpty) {
      final name = _foodNameController.text.trim();
      final grams = double.tryParse(_gramsController.text.replaceAll(',', '.'));
      final carbs = double.tryParse(_carbsController.text.replaceAll(',', '.'));
      if (name.isNotEmpty &&
          grams != null &&
          grams > 0 &&
          carbs != null &&
          carbs >= 0) {
        _foods.add(
          FoodItemEntry(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            foodName: name,
            grams: grams,
            carbs: carbs,
          ),
        );
      }
    }

    if (_foods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen öğüne en az bir yemek ekleyin.'),
        ),
      );
      return;
    }

    final insulin =
        (int.tryParse(_insulinController.text.trim()) ?? 0).toDouble();
    final extraInsulin =
        (int.tryParse(_extraInsulinController.text.trim()) ?? 0).toDouble();
    final fastingSugar = double.tryParse(
      _fastingSugarController.text.trim().replaceAll(',', '.'),
    );
    final postprandialSugar = double.tryParse(
      _postprandialSugarController.text.trim().replaceAll(',', '.'),
    );

    final record = MealRecord(
      id:
          widget.existingMeal?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      mealType: _selectedMealType,
      dateTime: _mealDateTime,
      foods: _foods,
      insulinUnits: insulin,
      extraInsulinUnits: extraInsulin,
      fastingBloodSugar: fastingSugar,
      postprandialBloodSugar: postprandialSugar,
      isPostprandialNotified: postprandialSugar != null,
      notes: _notesController.text.trim(),
    );

    widget.onSave(record);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final schedule = _activeSchedule;
    final reminderTime = _mealDateTime.add(const Duration(hours: 2));

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.existingMeal != null
                        ? 'Öğünü Düzenle'
                        : 'Yeni Öğün, Saat & Kan Şekeri Kaydı',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Öğün Tipi Seçimi
            Text(
              'Öğün Seçin',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: MealType.values.map((type) {
                final selected = _selectedMealType == type;
                return ChoiceChip(
                  avatar: Icon(
                    type.icon,
                    size: 18,
                    color: selected ? Colors.white : type.color,
                  ),
                  label: Text(type.label),
                  selected: selected,
                  selectedColor: type.color,
                  labelStyle: TextStyle(
                    color: selected
                        ? Colors.white
                        : theme.colorScheme.onSurface,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (_) {
                    setState(() => _selectedMealType = type);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Öğün Saati ve Açlık / Tokluk Kan Şekeri Alanları
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.45,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Öğün Saati ve Açlık / Tokluk Kan Şekeri',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: ScrollableTimeSelectorBox(
                          label: 'Öğün Saati',
                          timeText: _formatTime(_mealDateTime),
                          onTap: _pickMealTime,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 5,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFF59E0B)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.notifications_active_outlined,
                                size: 18,
                                color: Color(0xFFB45309),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '2 saat sonra (${_formatTime(reminderTime)}) tokluk şekeri bildirimi gelecek',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _fastingSugarController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Açlık Kan Şekeri',
                            hintText: 'Örn: 110',
                            suffixText: 'mg/dL',
                            prefixIcon: Icon(Icons.water_drop_outlined),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _postprandialSugarController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Tokluk Kan Şekeri (2. Saat)',
                            hintText: 'Sonra da girilebilir',
                            suffixText: 'mg/dL',
                            prefixIcon: Icon(Icons.bloodtype_outlined),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Hızlı Besin Seçimi (Otomatik Karbonhidrat Hesaplama)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.45,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Yemek, Gram ve Karbonhidrat Ekle',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<FoodReference>(
                    key: ValueKey(_selectedReferenceFood),
                    initialValue: _selectedReferenceFood,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Hazır Yemekler / Besin Listesinden Seç (Opsiyonel)',
                      prefixIcon: Icon(Icons.menu_book_outlined),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: widget.foodDatabase.map((food) {
                      return DropdownMenuItem<FoodReference>(
                        value: food,
                        child: Text(
                          '${food.name} (${food.defaultPortionGrams.toStringAsFixed(0)}g • 100g\'da ${food.carbsPer100g}g KH)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: _onReferenceSelected,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _foodNameController,
                    decoration: const InputDecoration(
                      labelText: 'Yenilen Yemek Adı',
                      hintText: 'Örn: Bulgur Pilavı, Elma, Çorba...',
                      prefixIcon: Icon(Icons.restaurant_outlined),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _gramsController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: _onGramsChanged,
                          decoration: const InputDecoration(
                            labelText: 'Yemeğin Gramı (g)',
                            hintText: 'Örn: 150',
                            suffixText: 'g',
                            prefixIcon: Icon(Icons.scale_outlined),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _carbsController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Karbonhidrat (g)',
                            hintText: 'Örn: 33',
                            suffixText: 'g KH',
                            prefixIcon: Icon(Icons.grain),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _addFoodToList,
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Yemeği Öğün Listesine Ekle'),
                    ),
                  ),
                ],
              ),
            ),

            // Eklenen yemekler listesi
            if (_foods.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'Bu Öğündeki Yemekler (${_foods.length})',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              ..._foods.map(
                (item) => Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    dense: true,
                    title: Text(
                      item.foodName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Miktar: ${item.grams.toStringAsFixed(0)} g  •  Karbonhidrat: ${item.carbs.toStringAsFixed(1)} g',
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: Colors.red,
                      ),
                      onPressed: () {
                        setState(() {
                          _foods.removeWhere((f) => f.id == item.id);
                        });
                      },
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Saat Aralığına Göre K/İ Tavsiyesi, Tıbbi Uyarı ve Vurulan İnsülin Miktarı
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Toplam Gram: ${_currentTotalGrams.toStringAsFixed(0)} g',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Toplam KH: ${_currentTotalCarbs.toStringAsFixed(1)} g',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Saat aralığına uygun K/İ ve tavsiye edilen insülin bilgisi
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Seçili Saat (${_formatTime(_mealDateTime)}) → ${schedule.periodName} Aralığı (${schedule.formattedTimeRange}) • K/İ Oranı: 1 Ünite = ${schedule.carbToInsulinRatio.toStringAsFixed(1)} g KH',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                _currentTotalCarbs > 0
                                    ? 'Aldığınız ${_currentTotalCarbs.toStringAsFixed(1)} g karbonhidrata karşılık ${schedule.periodName} K/İ oranınıza göre tavsiye edilen insülin: ${_suggestedInsulin.toStringAsFixed(1)} Ünite'
                                    : 'Yemek eklediğinizde ${schedule.periodName} K/İ oranınıza (1Ü=${schedule.carbToInsulinRatio.toStringAsFixed(0)}g KH) göre tavsiye edilen insülin dozu hesaplanacaktır.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (_suggestedInsulin > 0)
                              TextButton.icon(
                                onPressed: () {
                                  _insulinController.text = _suggestedInsulin
                                      .round()
                                      .toString();
                                },
                                icon: const Icon(
                                  Icons.check_circle_outline,
                                  size: 16,
                                ),
                                label: const Text('Aktar'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Doktor Uyarısı Kutusu
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFF59E0B)),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Color(0xFFB45309),
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  kMedicalDisclaimerText,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFF92400E),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _insulinController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Vurulan İnsülin (Ünite)',
                            hintText: 'Örn: 5',
                            suffixText: 'Ü',
                            prefixIcon: Icon(Icons.vaccines_outlined),
                            border: OutlineInputBorder(),
                            filled: true,
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _extraInsulinController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Ek Doz / Düzeltme (Opsiyonel)',
                            hintText: 'Örn: 2',
                            suffixText: 'Ü',
                            prefixIcon: Icon(Icons.add_moderator_outlined),
                            border: OutlineInputBorder(),
                            filled: true,
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Öğün Notu (Opsiyonel)',
                      hintText: 'Örn: Egzersiz öncesi öğün',
                      prefixIcon: Icon(Icons.notes_outlined),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: _saveMeal,
                icon: const Icon(Icons.check),
                label: const Text(
                  'Öğünü Kaydet ve 2 Saat Sonraya Bildirim Kur',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
