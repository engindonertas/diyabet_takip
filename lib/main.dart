import 'dart:async';
import 'package:flutter/material.dart';
import 'models/meal_models.dart';
import 'models/profile_model.dart';
import 'screens/ai_assistant_screen.dart';
import 'screens/carb_calculator_screen.dart';
import 'screens/meals_screen.dart';
import 'screens/menu_dialogs_and_screens.dart';
import 'screens/profile_screen.dart';

void main() {
  runApp(const DiyabetTakipApp());
}

class DiyabetTakipApp extends StatefulWidget {
  const DiyabetTakipApp({super.key});

  @override
  State<DiyabetTakipApp> createState() => _DiyabetTakipAppState();
}

class _DiyabetTakipAppState extends State<DiyabetTakipApp> {
  AppSettings _appSettings = const AppSettings();

  void _updateAppSettings(AppSettings updated) {
    setState(() {
      _appSettings = updated;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gluko',
      debugShowCheckedModeBanner: false,
      themeMode: _appSettings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D9488),
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D9488),
          brightness: Brightness.dark,
        ),
      ),
      home: MainHomePage(
        appSettings: _appSettings,
        onUpdateSettings: _updateAppSettings,
      ),
    );
  }
}

class MainHomePage extends StatefulWidget {
  final AppSettings appSettings;
  final ValueChanged<AppSettings> onUpdateSettings;

  const MainHomePage({
    super.key,
    required this.appSettings,
    required this.onUpdateSettings,
  });

  @override
  State<MainHomePage> createState() => _MainHomePageState();
}

class _MainHomePageState extends State<MainHomePage> {
  int _selectedIndex = 0;
  DateTime _selectedDate = DateTime.now();
  Timer? _reminderCheckTimer;
  final Map<String, Timer> _mealTimers = {};
  bool _isNotificationDialogOpen = false;

  /// Hazır yemekler veritabanı (Kullanıcının Karbonhidrat Sayımı -> Yemek Ekle bölümünden eklediği yemekler de buraya dahil edilir)
  late final List<FoodReference> _foodDatabase = List.of(kTurkishFoodDatabase);

  void _addCustomFood(FoodReference newFood) {
    setState(() {
      _foodDatabase.insert(0, newFood);
    });
  }

  /// Her gün için ayrı Günlük Not, Bazal İnsülin (Saat & Doz) ve Gece 03:00 Kan Şekeri kayıtları
  late final Map<String, DailyExtraLog> _dailyExtraLogs = {
    _dateKey(DateTime.now()): const DailyExtraLog(
      dailyNote: 'Akşam yürüyüşü (30 dk) yapıldı.',
      basalInsulinTime: '22:00',
      basalInsulinUnits: 18.0,
      night3AmBloodSugar: 105,
    ),
    _dateKey(DateTime.now().subtract(const Duration(days: 1))):
        const DailyExtraLog(
          dailyNote: 'Akşam 21:00 halı saha maçı yaptık, maç sonrası gece hipoglisemi yaşandı.',
          basalInsulinTime: '22:00',
          basalInsulinUnits: 18.0,
          night3AmBloodSugar: 58,
        ),
    _dateKey(DateTime.now().subtract(const Duration(days: 3))):
        const DailyExtraLog(
          dailyNote: 'Arkadaşlarla halı saha maçı yapıldı (yoğun efor).',
          basalInsulinTime: '22:00',
          basalInsulinUnits: 18.0,
          night3AmBloodSugar: 62,
        ),
  };

  /// Vurulan Ek Dozlar (Düzeltme İnsülini) ve etki takibi
  late final List<ExtraDoseRecord> _extraDoses = [
    ExtraDoseRecord(
      id: 'ed_today_1',
      dateTime: DateTime.now()
          .subtract(const Duration(hours: 2))
          .copyWith(minute: 15),
      insulinUnits: 2,
      bloodSugarBefore: 230,
      bloodSugarAfter: 146,
      note: 'Ana ekrandan kaydedilen ek doz',
    ),
    ExtraDoseRecord(
      id: 'ed_1',
      dateTime: DateTime.now()
          .subtract(const Duration(days: 1))
          .copyWith(hour: 21, minute: 30),
      insulinUnits: 2,
      bloodSugarBefore: 242,
      bloodSugarAfter: 156,
      note: 'Pirinç pilavlı akşam yemeği sonrası yükseklik düzeltmesi',
    ),
    ExtraDoseRecord(
      id: 'ed_2',
      dateTime: DateTime.now()
          .subtract(const Duration(days: 3))
          .copyWith(hour: 16, minute: 15),
      insulinUnits: 1,
      bloodSugarBefore: 215,
      bloodSugarAfter: 172,
      note: 'Öğleden sonra ara ölçüm yüksekliği için ek doz',
    ),
  ];

  /// Yapay Zeka Botunun kullanıcı tarafından eklenen ek hafıza kayıtları
  final List<AiMemoryItem> _customMemories = [];

  static String _dateKey(DateTime d) {
    final y = d.year.toString();
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  DailyExtraLog _getExtraLogForDate(DateTime date) {
    return _dailyExtraLogs[_dateKey(date)] ??
        const DailyExtraLog(basalInsulinTime: '22:00');
  }

  void _updateExtraLogForDate(DateTime date, DailyExtraLog updated) {
    setState(() {
      _dailyExtraLogs[_dateKey(date)] = updated;
    });
  }

  late UserProfile _userProfile = UserProfile(
    firstName: 'Ahmet',
    lastName: 'Yılmaz',
    birthDate: DateTime(1998, 5, 14),
    heightCm: 176,
    weightKg: 72,
    selectedSensorId: 'freestyle_libre_2',
    diabetesType: 'Tip 1 Diyabet',
  );

  late final List<MealRecord> _meals = [
    MealRecord(
      id: 'sample_1',
      mealType: MealType.kahvalti,
      dateTime: DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
        8,
        30,
      ),
      foods: const [
        FoodItemEntry(
          id: 'f1',
          foodName: 'Tam Buğday Ekmeği',
          grams: 70,
          carbs: 30.1,
        ),
        FoodItemEntry(
          id: 'f2',
          foodName: 'Süt',
          grams: 200,
          carbs: 9.6,
        ),
      ],
      insulinUnits: 5.0,
      fastingBloodSugar: 108,
      postprandialBloodSugar: 136,
      isPostprandialNotified: true,
      notes: 'Sabah kahvaltısı',
    ),
    MealRecord(
      id: 'sample_2',
      mealType: MealType.ogle,
      dateTime: DateTime.now().subtract(const Duration(minutes: 45)),
      foods: const [
        FoodItemEntry(
          id: 'f3',
          foodName: 'Mercimek Çorbası',
          grams: 200,
          carbs: 17.0,
        ),
        FoodItemEntry(
          id: 'f4',
          foodName: 'Bulgur Pilavı (Pişmiş)',
          grams: 150,
          carbs: 33.0,
        ),
        FoodItemEntry(
          id: 'f5',
          foodName: 'Yoğurt (Tam Yağlı)',
          grams: 150,
          carbs: 7.1,
        ),
      ],
      insulinUnits: 6.0,
      fastingBloodSugar: 118,
      postprandialBloodSugar: null,
      isPostprandialNotified: false,
      notes: 'Öğle yemeği',
    ),
    MealRecord(
      id: 'sample_yesterday',
      mealType: MealType.aksam,
      dateTime: DateTime.now()
          .subtract(const Duration(days: 1))
          .copyWith(hour: 19, minute: 15),
      foods: const [
        FoodItemEntry(
          id: 'f6',
          foodName: 'Pirinç Pilavı (Pişmiş)',
          grams: 150,
          carbs: 42.0,
        ),
        FoodItemEntry(
          id: 'f7',
          foodName: 'Yoğurt (Tam Yağlı)',
          grams: 150,
          carbs: 7.1,
        ),
      ],
      insulinUnits: 4.0,
      extraInsulinUnits: 1.0,
      fastingBloodSugar: 115,
      postprandialBloodSugar: 218,
      isPostprandialNotified: true,
      notes: 'Pirinç pilavı sonrası tokluk yükseldi',
    ),
    MealRecord(
      id: 'sample_2days_ago_lunch',
      mealType: MealType.ogle,
      dateTime: DateTime.now()
          .subtract(const Duration(days: 2))
          .copyWith(hour: 13, minute: 0),
      foods: const [
        FoodItemEntry(
          id: 'f8',
          foodName: 'Mercimek Çorbası',
          grams: 200,
          carbs: 17.0,
        ),
        FoodItemEntry(
          id: 'f9',
          foodName: 'Tam Buğday Ekmeği',
          grams: 35,
          carbs: 15.0,
        ),
      ],
      insulinUnits: 5.0,
      fastingBloodSugar: 102,
      postprandialBloodSugar: 63,
      isPostprandialNotified: true,
      notes: 'Öğün sonrası yürüyüşe çıkınca hipoglisemi yaşandı',
    ),
    MealRecord(
      id: 'sample_3days_ago_dinner',
      mealType: MealType.aksam,
      dateTime: DateTime.now()
          .subtract(const Duration(days: 3))
          .copyWith(hour: 19, minute: 30),
      foods: const [
        FoodItemEntry(
          id: 'f10',
          foodName: 'Makarna (Haşlanmış)',
          grams: 200,
          carbs: 60.0,
        ),
      ],
      insulinUnits: 5.0,
      fastingBloodSugar: 124,
      postprandialBloodSugar: 226,
      isPostprandialNotified: true,
      notes: 'Halı saha öncesi makarna yenildi',
    ),
  ];

  @override
  void initState() {
    super.initState();
    for (final meal in _meals) {
      _scheduleExactTimerForMeal(meal);
    }
    _reminderCheckTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _checkDuePostprandialReminders(),
    );
  }

  @override
  void dispose() {
    _reminderCheckTimer?.cancel();
    for (final timer in _mealTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  DateTime _reminderTimeForMeal(MealRecord meal) {
    return meal.dateTime.add(
      Duration(minutes: widget.appSettings.postprandialReminderMinutes),
    );
  }

  void _scheduleExactTimerForMeal(MealRecord meal) {
    _mealTimers[meal.id]?.cancel();
    if (!widget.appSettings.notificationsEnabled) {
      return;
    }
    if (meal.postprandialBloodSugar != null || meal.isPostprandialNotified) {
      return;
    }

    final now = DateTime.now();
    final reminderTime = _reminderTimeForMeal(meal);
    final diff = reminderTime.difference(now);
    if (diff.isNegative) {
      _mealTimers[meal.id] = Timer(const Duration(seconds: 2), () {
        _triggerPostprandialNotification(meal);
      });
    } else {
      _mealTimers[meal.id] = Timer(diff, () {
        _triggerPostprandialNotification(meal);
      });
    }
  }

  void _checkDuePostprandialReminders() {
    if (!mounted ||
        _isNotificationDialogOpen ||
        !widget.appSettings.notificationsEnabled) {
      return;
    }
    final now = DateTime.now();
    for (final meal in _meals) {
      final reminderTime = _reminderTimeForMeal(meal);
      if (meal.postprandialBloodSugar == null &&
          !meal.isPostprandialNotified &&
          !now.isBefore(reminderTime)) {
        _triggerPostprandialNotification(meal);
        break;
      }
    }
  }

  void _triggerPostprandialNotification(
    MealRecord meal, {
    bool isManualTrigger = false,
  }) {
    if (!mounted || _isNotificationDialogOpen) return;
    if (!isManualTrigger && !widget.appSettings.notificationsEnabled) return;

    // Seçili bildirim sesini çal
    if (widget.appSettings.notificationsEnabled) {
      playSelectedNotificationSound(widget.appSettings.notificationSound);
    }

    final index = _meals.indexWhere((m) => m.id == meal.id);
    if (index != -1) {
      setState(() {
        _meals[index] = _meals[index].copyWith(isPostprandialNotified: true);
      });
    }

    _isNotificationDialogOpen = true;
    final sugarController = TextEditingController();
    final reminderTime = _reminderTimeForMeal(meal);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
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
                  Icons.notifications_active,
                  color: Color(0xFFB45309),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  '2. Saat Tokluk Kan Şekeri Bildirimi',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${meal.mealType.label} öğününüzü saat ${_formatTime(meal.dateTime)} olarak kaydetmiştiniz. Öğününüzün üzerinden 2 saat geçti (${_formatTime(reminderTime)}).',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 6),
              Text(
                '🔊 Bildirim Sesi: ${widget.appSettings.notificationSound}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Lütfen 2. saat tokluk kan şekeri ölçümünüzü girin:',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: sugarController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText:
                      'Tokluk Kan Şekeri (${widget.appSettings.glucoseUnit})',
                  hintText: 'Örn: 140',
                  suffixText: widget.appSettings.glucoseUnit,
                  prefixIcon: const Icon(Icons.bloodtype),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _isNotificationDialogOpen = false;
                Navigator.of(ctx).pop();
              },
              child: const Text('Daha Sonra Gir'),
            ),
            FilledButton.icon(
              onPressed: () {
                final val = double.tryParse(
                  sugarController.text.trim().replaceAll(',', '.'),
                );
                if (val != null && val > 0) {
                  _updateMeal(
                    meal.copyWith(
                      postprandialBloodSugar: val,
                      isPostprandialNotified: true,
                    ),
                  );
                }
                _isNotificationDialogOpen = false;
                Navigator.of(ctx).pop();
              },
              icon: const Icon(Icons.check),
              label: const Text('Tokluk Şekerini Kaydet'),
            ),
          ],
        );
      },
    ).then((_) {
      _isNotificationDialogOpen = false;
    });
  }

  void _addMeal(MealRecord meal) {
    setState(() {
      _meals.insert(0, meal);
      _selectedDate = DateTime(
        meal.dateTime.year,
        meal.dateTime.month,
        meal.dateTime.day,
      );
    });
    _scheduleExactTimerForMeal(meal);

    if (meal.postprandialBloodSugar == null && mounted) {
      final reminderTime = _reminderTimeForMeal(meal);
      final notifNote = widget.appSettings.notificationsEnabled
          ? '🔔 ${meal.mealType.label} (${_formatTime(meal.dateTime)}) kaydedildi! Saat ${_formatTime(reminderTime)}\'de tokluk şekerinizi girmeniz için bildirim (${widget.appSettings.notificationSound}) gelecektir.'
          : '✅ ${meal.mealType.label} (${_formatTime(meal.dateTime)}) kaydedildi. (Bildirimler ayarlardan kapalıdır.)';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 4),
          content: Text(notifNote),
        ),
      );
    }
  }

  void _updateMeal(MealRecord updated) {
    setState(() {
      final index = _meals.indexWhere((m) => m.id == updated.id);
      if (index != -1) {
        _meals[index] = updated;
      }
    });
    _scheduleExactTimerForMeal(updated);
  }

  void _deleteMeal(String id) {
    _mealTimers[id]?.cancel();
    _mealTimers.remove(id);
    setState(() {
      _meals.removeWhere((m) => m.id == id);
    });
  }

  void _updateProfile(UserProfile updatedProfile) {
    setState(() {
      _userProfile = updatedProfile;
    });
  }

  void _openAiAssistantScreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StatefulBuilder(
          builder: (ctx, setModalState) {
            return AiAssistantScreen(
              meals: _meals,
              dailyExtraLogs: _dailyExtraLogs,
              extraDoses: _extraDoses,
              onAddExtraDose: (dose) {
                setState(() {
                  _extraDoses.insert(0, dose);
                });
                setModalState(() {});
              },
              onUpdateExtraDose: (updated) {
                setState(() {
                  final idx = _extraDoses.indexWhere((d) => d.id == updated.id);
                  if (idx != -1) {
                    _extraDoses[idx] = updated;
                  }
                });
                setModalState(() {});
              },
              onDeleteExtraDose: (id) {
                setState(() {
                  _extraDoses.removeWhere((d) => d.id == id);
                });
                setModalState(() {});
              },
              customMemories: _customMemories,
              onAddMemory: (mem) {
                setState(() {
                  _customMemories.insert(0, mem);
                });
                setModalState(() {});
              },
              onDeleteMemory: (id) {
                setState(() {
                  _customMemories.removeWhere((m) => m.id == id);
                });
                setModalState(() {});
              },
              userProfile: _userProfile,
              appSettings: widget.appSettings,
            );
          },
        ),
      ),
    );
  }

  void _openCarbCalculatorScreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (ctx) => CarbCalculatorScreen(
          userProfile: _userProfile,
          foodDatabase: _foodDatabase,
          onAddCustomFood: _addCustomFood,
          showAppBar: true,
          onSaveMealFromCalculator: (meal) {
            _addMeal(meal);
            Navigator.of(ctx).pop();
            setState(() {
              _selectedIndex = 0;
            });
          },
        ),
      ),
    );
  }

  void _openAppGuideScreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const AppGuideScreen(),
      ),
    );
  }

  void _openSettingsScreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(
          settings: widget.appSettings,
          onSettingsChanged: (newSettings) {
            widget.onUpdateSettings(newSettings);
            if (!newSettings.notificationsEnabled) {
              for (final timer in _mealTimers.values) {
                timer.cancel();
              }
              _mealTimers.clear();
            } else {
              for (final meal in _meals) {
                _scheduleExactTimerForMeal(meal);
              }
            }
          },
        ),
      ),
    );
  }

  void _handleTopMenuSelection(String value) {
    switch (value) {
      case 'ai_assistant':
        _openAiAssistantScreen();
        break;
      case 'carb_calculator':
        _openCarbCalculatorScreen();
        break;
      case 'app_guide':
        _openAppGuideScreen();
        break;
      case 'settings':
        _openSettingsScreen();
        break;
      case 'legal_disclaimer':
        showLegalDisclaimerDialog(context);
        break;
      case 'rate_us':
        showRateAppDialog(context);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final titles = [
      'Gluko • Öğün & İnsülin Takibi',
      'Gluko • Profil & Diyabet Bilgileri',
    ];
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          titles[_selectedIndex],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        actions: [
          PopupMenuButton<String>(
            key: const Key('top_corner_menu_button'),
            tooltip: 'Menü',
            position: PopupMenuPosition.under,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onSelected: _handleTopMenuSelection,
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'ai_assistant',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: CircleAvatar(
                    backgroundColor: Color(0xFFEDE9FE),
                    child: Icon(
                      Icons.smart_toy_outlined,
                      color: Color(0xFF6D28D9),
                    ),
                  ),
                  title: Text(
                    'Glukobot',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'carb_calculator',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(
                      Icons.calculate,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  title: const Text(
                    'Karbonhidrat Sayımı',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'app_guide',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(Icons.menu_book_outlined, color: Color(0xFF2563EB)),
                  title: Text('Uygulama Kullanım Rehberi'),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'settings',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(Icons.settings_outlined, color: Color(0xFF0D9488)),
                  title: Text('Ayarlar'),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'legal_disclaimer',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(Icons.gavel_outlined, color: Color(0xFFD97706)),
                  title: Text('Yasal Uyarılar'),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'rate_us',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(Icons.star_rate_rounded, color: Color(0xFFF59E0B)),
                  title: Text('Bizi Puanla'),
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.menu_rounded,
                      size: 20,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Menü',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          MealsScreen(
            meals: _meals,
            foodDatabase: _foodDatabase,
            extraDoses: _extraDoses,
            onAddExtraDose: (dose) {
              setState(() {
                _extraDoses.insert(0, dose);
              });
            },
            onUpdateExtraDose: (updated) {
              setState(() {
                final idx = _extraDoses.indexWhere((d) => d.id == updated.id);
                if (idx != -1) {
                  _extraDoses[idx] = updated;
                }
              });
            },
            onDeleteExtraDose: (id) {
              setState(() {
                _extraDoses.removeWhere((d) => d.id == id);
              });
            },
            selectedDate: _selectedDate,
            onSelectDate: (day) {
              setState(() {
                _selectedDate = day;
              });
            },
            userProfile: _userProfile,
            currentDayExtraLog: _getExtraLogForDate(_selectedDate),
            onUpdateDailyExtraLog: (log) =>
                _updateExtraLogForDate(_selectedDate, log),
            onAddMeal: _addMeal,
            onUpdateMeal: _updateMeal,
            onDeleteMeal: _deleteMeal,
            onTriggerPostprandialNotification: (meal) =>
                _triggerPostprandialNotification(meal, isManualTrigger: true),
          ),
          ProfileScreen(
            userProfile: _userProfile,
            onSaveProfile: _updateProfile,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (idx) {
          setState(() {
            _selectedIndex = idx;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.restaurant_outlined),
            selectedIcon: Icon(Icons.restaurant),
            label: 'Öğünlerim',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
