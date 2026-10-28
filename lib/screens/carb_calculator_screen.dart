import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/meal_models.dart';
import '../models/profile_model.dart';
import '../widgets/scrollable_time_picker.dart';

class CarbCalculatorScreen extends StatefulWidget {
  final UserProfile userProfile;
  final List<FoodReference> foodDatabase;
  final ValueChanged<FoodReference> onAddCustomFood;
  final ValueChanged<MealRecord> onSaveMealFromCalculator;
  final bool showAppBar;

  const CarbCalculatorScreen({
    super.key,
    required this.userProfile,
    required this.foodDatabase,
    required this.onAddCustomFood,
    required this.onSaveMealFromCalculator,
    this.showAppBar = true,
  });

  @override
  State<CarbCalculatorScreen> createState() => _CarbCalculatorScreenState();
}

class _CarbCalculatorScreenState extends State<CarbCalculatorScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'Tümü';
  final List<FoodItemEntry> _trayItems = [];
  MealType _targetMealType = MealType.ogle;
  DateTime _selectedMealTime = DateTime.now();
  final TextEditingController _insulinController = TextEditingController();

  List<String> get _categories {
    final cats = widget.foodDatabase.map((e) => e.category).toSet().toList();
    return ['Tümü', ...cats];
  }

  List<FoodReference> get _filteredFoods {
    return widget.foodDatabase.where((food) {
      final matchesCategory =
          _selectedCategory == 'Tümü' || food.category == _selectedCategory;
      final matchesSearch = food.name.toLowerCase().contains(
            _searchQuery.trim().toLowerCase(),
          );
      return matchesCategory && matchesSearch;
    }).toList();
  }

  CarbRatioSchedule get _activeSchedule =>
      widget.userProfile.getScheduleForTime(_selectedMealTime);

  double get _totalTrayGrams =>
      _trayItems.fold(0.0, (sum, item) => sum + item.grams);

  double get _totalTrayCarbs =>
      _trayItems.fold(0.0, (sum, item) => sum + item.carbs);

  double get _estimatedInsulin {
    final ratio = _activeSchedule.carbToInsulinRatio;
    if (ratio <= 0) return 0.0;
    return _totalTrayCarbs / ratio;
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _pickMealTime() async {
    final picked = await showScrollableTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedMealTime),
      title: 'Öğün Saatini Kaydırarak Seçin',
    );
    if (picked != null) {
      setState(() {
        _selectedMealTime = DateTime(
          _selectedMealTime.year,
          _selectedMealTime.month,
          _selectedMealTime.day,
          picked.hour,
          picked.minute,
        );
        if (_trayItems.isNotEmpty) {
          _insulinController.text = _estimatedInsulin.round().toString();
        }
      });
    }
  }

  @override
  void dispose() {
    _insulinController.dispose();
    super.dispose();
  }

  /// Kullanıcının kendi yemeğini ve karbonhidrat miktarını hazır listeye eklemesini sağlayan pencere
  void _openAddCustomFoodDialog() {
    final nameController = TextEditingController();
    final portionGramsController = TextEditingController(text: '100');
    final portionCarbsController = TextEditingController();
    String selectedCategory = 'Ev Yemeği / Özel';

    final categories = <String>{
      'Ev Yemeği / Özel',
      'Ekmek & Tahıl',
      'Çorba & Baklagil',
      'Sebze',
      'Meyve',
      'Süt Ürünleri',
      'Tatlı & Atıştırmalık',
      ...widget.foodDatabase.map((f) => f.category),
    }.toList();

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final grams =
                double.tryParse(
                  portionGramsController.text.replaceAll(',', '.'),
                ) ??
                100.0;
            final carbs =
                double.tryParse(
                  portionCarbsController.text.replaceAll(',', '.'),
                ) ??
                0.0;
            final carbsPer100 = grams > 0
                ? double.parse(((carbs * 100.0) / grams).toStringAsFixed(1))
                : 0.0;

            return AlertDialog(
              title: Row(
                children: [
                  Icon(
                    Icons.playlist_add_circle_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Hazır Yemeklere Yeni Yemek Ekle',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Buradan eklediğiniz yemekler hem Karbonhidrat Sayımı listesinde hem de Öğün Ekle ekranındaki "Hazır Besin Listesi" bölümünde görünür.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Yemek Adı',
                        hintText: 'Örn: Ev Yapımı Börek, Elmalı Kurabiye...',
                        prefixIcon: Icon(Icons.restaurant_outlined),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategory,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Kategori',
                        prefixIcon: Icon(Icons.category_outlined),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: categories.map((c) {
                        return DropdownMenuItem(value: c, child: Text(c));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedCategory = val);
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: portionGramsController,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                            onChanged: (_) => setDialogState(() {}),
                            decoration: const InputDecoration(
                              labelText: 'Porsiyon Gramı',
                              hintText: '100',
                              suffixText: 'g',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: portionCarbsController,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                            onChanged: (_) => setDialogState(() {}),
                            decoration: const InputDecoration(
                              labelText: 'Karbonhidrat',
                              hintText: 'Örn: 25',
                              suffixText: 'g KH',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '100 gramdaki karbonhidrat değeri: ${carbsPer100.toStringAsFixed(1)} g KH',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('İptal'),
                ),
                FilledButton.icon(
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isEmpty || grams <= 0 || carbs < 0 ||
                        portionCarbsController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Lütfen yemek adını, gramını ve karbonhidrat miktarını girin.',
                          ),
                        ),
                      );
                      return;
                    }

                    final newFood = FoodReference(
                      name: name,
                      category: selectedCategory,
                      carbsPer100g: carbsPer100,
                      defaultPortionGrams: grams,
                      portionDescription:
                          '1 porsiyon (${grams.toStringAsFixed(0)}g)',
                    );

                    widget.onAddCustomFood(newFood);
                    setState(() {});
                    Navigator.of(ctx).pop();

                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '"$name" hazır yemekler listesine eklendi! Öğün eklerken de seçebilirsiniz.',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Yemeği Listeye Kaydet'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _promptGramAndAdd(FoodReference food) {
    final gramController = TextEditingController(
      text: food.defaultPortionGrams.toStringAsFixed(0),
    );
    double currentGrams = food.defaultPortionGrams;

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final calculatedCarbs = food.calculateCarbs(currentGrams);
            return AlertDialog(
              title: Text(food.name),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '100 gramda ${food.carbsPer100g} g karbonhidrat içerir.\nÖrnek porsiyon: ${food.portionDescription}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: gramController,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Yemeğin Gramı (g)',
                      suffixText: 'gram',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      setDialogState(() {
                        currentGrams =
                            double.tryParse(val.replaceAll(',', '.')) ?? 0;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Text('Hesaplanan Karbonhidrat'),
                        const SizedBox(height: 4),
                        Text(
                          '${calculatedCarbs.toStringAsFixed(1)} g KH',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                              ),
                        ),
                      ],
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
                    if (currentGrams <= 0) return;
                    setState(() {
                      _trayItems.add(
                        FoodItemEntry(
                          id: DateTime.now().microsecondsSinceEpoch.toString(),
                          foodName: food.name,
                          grams: currentGrams,
                          carbs: calculatedCarbs,
                        ),
                      );
                      _insulinController.text =
                          _estimatedInsulin.round().toString();
                    });
                    Navigator.of(ctx).pop();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Sayım Listesine Ekle'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _saveTrayAsMeal() {
    if (_trayItems.isEmpty) return;
    final insulin =
        (int.tryParse(_insulinController.text.trim()) ??
                _estimatedInsulin.round())
            .toDouble();

    final newMeal = MealRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      mealType: _targetMealType,
      dateTime: _selectedMealTime,
      foods: List.of(_trayItems),
      insulinUnits: insulin,
      notes: 'Karbonhidrat sayımı hesaplayıcısından eklendi',
    );

    widget.onSaveMealFromCalculator(newMeal);
    setState(() {
      _trayItems.clear();
      _insulinController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${_targetMealType.label} öğünü (${newMeal.totalCarbs.toStringAsFixed(1)} g KH, ${newMeal.insulinUnits.toStringAsFixed(0)} Ü İnsülin) kaydedildi!',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final schedule = _activeSchedule;

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text(
                'Karbonhidrat Sayımı',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: FilledButton.tonalIcon(
                    onPressed: _openAddCustomFoodDialog,
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('Yemek Ekle'),
                  ),
                ),
              ],
            )
          : null,
      body: Column(
        children: [
          // Üst Karbonhidrat Sayım Tepsisi
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.calculate_outlined,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Karbonhidrat Sayım Tepsisi',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.access_time, size: 16),
                          label: Text(
                            '${_formatTime(_selectedMealTime)} (${schedule.periodName} K/İ: 1Ü/${schedule.carbToInsulinRatio.toStringAsFixed(0)}g)',
                            style: const TextStyle(fontSize: 12),
                          ),
                          onPressed: _pickMealTime,
                        ),
                        if (_trayItems.isNotEmpty)
                          IconButton(
                            tooltip: 'Tepsiyi Temizle',
                            onPressed: () {
                              setState(() {
                                _trayItems.clear();
                                _insulinController.clear();
                              });
                            },
                            icon: const Icon(Icons.clear_all, size: 20),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (_trayItems.isEmpty)
                  Text(
                    'Aşağıdaki besin listesinden yediğiniz yemeklere dokunarak gramajına göre karbonhidrat sayımı yapabilir veya "Yeni Yemek Ekle" ile kendi yemeklerinizi hazır yemekler listesine ekleyebilirsiniz.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                else ...[
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 90),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _trayItems.length,
                      itemBuilder: (ctx, i) {
                        final item = _trayItems[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '• ${item.foodName} (${item.grams.toStringAsFixed(0)} g)',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Text(
                                '${item.carbs.toStringAsFixed(1)} g KH',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.close, size: 16),
                                onPressed: () {
                                  setState(() {
                                    _trayItems.removeAt(i);
                                    _insulinController.text =
                                        _estimatedInsulin.round().toString();
                                  });
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Toplam: ${_totalTrayGrams.toStringAsFixed(0)} g yemek • ${_totalTrayCarbs.toStringAsFixed(1)} g KH',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Tavsiye (${schedule.periodName}): ${_estimatedInsulin.toStringAsFixed(1)} Ü İnsülin',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Tıbbi Uyarı Kutusu
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF59E0B)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Color(0xFFB45309),
                          size: 18,
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            kMedicalDisclaimerText,
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF92400E),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<MealType>(
                          initialValue: _targetMealType,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Öğün',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: MealType.values.map((m) {
                            return DropdownMenuItem(
                              value: m,
                              child: Text(m.label),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _targetMealType = val);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _insulinController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Vurulan İnsülin (Ü)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _saveTrayAsMeal,
                        child: const Text('Kaydet'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Arama ve Yeni Yemek Ekle Satırı
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Besin ara (Örn: Ekmek, Pilav, Elma)...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      isDense: true,
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _openAddCustomFoodDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Yeni Yemek Ekle'),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final cat = _categories[i];
                final isSelected = _selectedCategory == cat;
                return ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _selectedCategory = cat),
                );
              },
            ),
          ),

          // Besin Listesi
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: _filteredFoods.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final food = _filteredFoods[index];
                final portionCarbs = food.calculateCarbs(
                  food.defaultPortionGrams,
                );
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                  child: ListTile(
                    onTap: () => _promptGramAndAdd(food),
                    title: Text(
                      food.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${food.category} • ${food.portionDescription} ≈ ${portionCarbs.toStringAsFixed(1)}g KH',
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${food.carbsPer100g} g KH',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '100 gramda',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
