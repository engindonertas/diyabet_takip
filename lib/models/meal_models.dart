import 'package:flutter/material.dart';

enum MealType {
  kahvalti('Kahvaltı', Icons.wb_sunny_outlined, Color(0xFFF59E0B)),
  ogle('Öğle Yemeği', Icons.wb_sunny, Color(0xFF10B981)),
  aksam('Akşam Yemeği', Icons.nights_stay_outlined, Color(0xFF6366F1)),
  araOgun('Ara Öğün', Icons.apple_outlined, Color(0xFFEC4899));

  final String label;
  final IconData icon;
  final Color color;
  const MealType(this.label, this.icon, this.color);
}

class FoodReference {
  final String name;
  final String category;
  final double carbsPer100g;
  final double defaultPortionGrams;
  final String portionDescription;

  const FoodReference({
    required this.name,
    required this.category,
    required this.carbsPer100g,
    required this.defaultPortionGrams,
    required this.portionDescription,
  });

  double calculateCarbs(double grams) {
    return double.parse(((grams * carbsPer100g) / 100.0).toStringAsFixed(1));
  }
}

class FoodItemEntry {
  final String id;
  final String foodName;
  final double grams;
  final double carbs;

  const FoodItemEntry({
    required this.id,
    required this.foodName,
    required this.grams,
    required this.carbs,
  });

  FoodItemEntry copyWith({
    String? id,
    String? foodName,
    double? grams,
    double? carbs,
  }) {
    return FoodItemEntry(
      id: id ?? this.id,
      foodName: foodName ?? this.foodName,
      grams: grams ?? this.grams,
      carbs: carbs ?? this.carbs,
    );
  }
}

class MealRecord {
  final String id;
  final MealType mealType;
  final DateTime dateTime;
  final List<FoodItemEntry> foods;
  final double insulinUnits;
  final double extraInsulinUnits; // Vurulan ek doz / düzeltme insülini (Ünite)
  final double? fastingBloodSugar; // Açlık kan şekeri (mg/dL)
  final double? postprandialBloodSugar; // Tokluk kan şekeri - 2 saat sonra (mg/dL)
  final bool isPostprandialNotified;
  final String notes;

  const MealRecord({
    required this.id,
    required this.mealType,
    required this.dateTime,
    required this.foods,
    required this.insulinUnits,
    this.extraInsulinUnits = 0.0,
    this.fastingBloodSugar,
    this.postprandialBloodSugar,
    this.isPostprandialNotified = false,
    this.notes = '',
  });

  double get totalGrams => foods.fold(0.0, (sum, item) => sum + item.grams);

  double get totalCarbs => foods.fold(0.0, (sum, item) => sum + item.carbs);

  /// Öğün saatinden 2 saat sonraki tokluk kan şekeri ölçüm zamanı
  DateTime get postprandialReminderTime =>
      dateTime.add(const Duration(hours: 2));

  MealRecord copyWith({
    String? id,
    MealType? mealType,
    DateTime? dateTime,
    List<FoodItemEntry>? foods,
    double? insulinUnits,
    double? extraInsulinUnits,
    double? fastingBloodSugar,
    double? postprandialBloodSugar,
    bool clearFastingBloodSugar = false,
    bool clearPostprandialBloodSugar = false,
    bool? isPostprandialNotified,
    String? notes,
  }) {
    return MealRecord(
      id: id ?? this.id,
      mealType: mealType ?? this.mealType,
      dateTime: dateTime ?? this.dateTime,
      foods: foods ?? this.foods,
      insulinUnits: insulinUnits ?? this.insulinUnits,
      extraInsulinUnits: extraInsulinUnits ?? this.extraInsulinUnits,
      fastingBloodSugar: clearFastingBloodSugar
          ? null
          : (fastingBloodSugar ?? this.fastingBloodSugar),
      postprandialBloodSugar: clearPostprandialBloodSugar
          ? null
          : (postprandialBloodSugar ?? this.postprandialBloodSugar),
      isPostprandialNotified:
          isPostprandialNotified ?? this.isPostprandialNotified,
      notes: notes ?? this.notes,
    );
  }
}

/// Öğün dışı veya yüksek şeker düzeltmesi için vurulan Ek Doz (Düzeltme İnsülini) kaydı
class ExtraDoseRecord {
  final String id;
  final DateTime dateTime;
  final double insulinUnits; // Tam sayı ünite
  final double bloodSugarBefore; // Ek doz öncesi kan şekeri (mg/dL)
  final double? bloodSugarAfter; // Ek doz sonrası kontrol kan şekeri (mg/dL)
  final String note;

  const ExtraDoseRecord({
    required this.id,
    required this.dateTime,
    required this.insulinUnits,
    required this.bloodSugarBefore,
    this.bloodSugarAfter,
    this.note = '',
  });

  /// 1 ünite ek dozun kan şekerini kaç mg/dL düşürdüğü (Etkinlik)
  double? get dropPerUnit {
    if (bloodSugarAfter == null || insulinUnits <= 0) return null;
    final totalDrop = bloodSugarBefore - bloodSugarAfter!;
    return totalDrop / insulinUnits;
  }

  /// Toplam kan şekeri düşüşü (mg/dL)
  double? get totalDrop {
    if (bloodSugarAfter == null) return null;
    return bloodSugarBefore - bloodSugarAfter!;
  }

  ExtraDoseRecord copyWith({
    String? id,
    DateTime? dateTime,
    double? insulinUnits,
    double? bloodSugarBefore,
    double? bloodSugarAfter,
    String? note,
  }) {
    return ExtraDoseRecord(
      id: id ?? this.id,
      dateTime: dateTime ?? this.dateTime,
      insulinUnits: insulinUnits ?? this.insulinUnits,
      bloodSugarBefore: bloodSugarBefore ?? this.bloodSugarBefore,
      bloodSugarAfter: bloodSugarAfter ?? this.bloodSugarAfter,
      note: note ?? this.note,
    );
  }
}

/// Yapay Zeka Botunun hafızasında tuttuğu kalıcı örüntü ve öğrenilen bilgi modeli
class AiMemoryItem {
  final String id;
  final String title;
  final String description;
  final String category; // 'aktivite_hipo', 'ogun_hipo_hiper', 'ek_doz', 'kullanici_notu'
  final String triggerKeyword;
  final int occurrences;
  final DateTime updatedAt;
  final bool isAutoDetected;

  const AiMemoryItem({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    this.triggerKeyword = '',
    this.occurrences = 1,
    required this.updatedAt,
    this.isAutoDetected = true,
  });

  AiMemoryItem copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    String? triggerKeyword,
    int? occurrences,
    DateTime? updatedAt,
    bool? isAutoDetected,
  }) {
    return AiMemoryItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      triggerKeyword: triggerKeyword ?? this.triggerKeyword,
      occurrences: occurrences ?? this.occurrences,
      updatedAt: updatedAt ?? this.updatedAt,
      isAutoDetected: isAutoDetected ?? this.isAutoDetected,
    );
  }
}

/// Seçilen gün için Günlük Not, Bazal İnsülin (Saat & Doz) ve Gece 03:00 Kan Şekeri modeli
class DailyExtraLog {
  final String dailyNote;
  final String basalInsulinTime; // Örn: "22:00"
  final double? basalInsulinUnits; // Bazal insülin dozu (Ünite)
  final double? night3AmBloodSugar; // Gece 03:00 kan şekeri (mg/dL)

  const DailyExtraLog({
    this.dailyNote = '',
    this.basalInsulinTime = '',
    this.basalInsulinUnits,
    this.night3AmBloodSugar,
  });

  DailyExtraLog copyWith({
    String? dailyNote,
    String? basalInsulinTime,
    double? basalInsulinUnits,
    double? night3AmBloodSugar,
    bool clearBasalUnits = false,
    bool clearNight3AmSugar = false,
  }) {
    return DailyExtraLog(
      dailyNote: dailyNote ?? this.dailyNote,
      basalInsulinTime: basalInsulinTime ?? this.basalInsulinTime,
      basalInsulinUnits: clearBasalUnits
          ? null
          : (basalInsulinUnits ?? this.basalInsulinUnits),
      night3AmBloodSugar: clearNight3AmSugar
          ? null
          : (night3AmBloodSugar ?? this.night3AmBloodSugar),
    );
  }
}

/// Yaygın tüketilen besinler için 100 gramdaki karbonhidrat değerleri
const List<FoodReference> kTurkishFoodDatabase = [
  FoodReference(
    name: 'Beyaz Ekmek',
    category: 'Ekmek & Tahıl',
    carbsPer100g: 50.0,
    defaultPortionGrams: 30,
    portionDescription: '1 ince dilim (30g)',
  ),
  FoodReference(
    name: 'Tam Buğday Ekmeği',
    category: 'Ekmek & Tahıl',
    carbsPer100g: 43.0,
    defaultPortionGrams: 35,
    portionDescription: '1 dilim (35g)',
  ),
  FoodReference(
    name: 'Pirinç Pilavı (Pişmiş)',
    category: 'Ekmek & Tahıl',
    carbsPer100g: 28.0,
    defaultPortionGrams: 150,
    portionDescription: '1 porsiyon / 6 yemek kaşığı (150g)',
  ),
  FoodReference(
    name: 'Bulgur Pilavı (Pişmiş)',
    category: 'Ekmek & Tahıl',
    carbsPer100g: 22.0,
    defaultPortionGrams: 150,
    portionDescription: '1 porsiyon / 6 yemek kaşığı (150g)',
  ),
  FoodReference(
    name: 'Makarna (Haşlanmış)',
    category: 'Ekmek & Tahıl',
    carbsPer100g: 30.0,
    defaultPortionGrams: 150,
    portionDescription: '1 tabak (150g)',
  ),
  FoodReference(
    name: 'Yulaf Ezmesi (Çiğ)',
    category: 'Ekmek & Tahıl',
    carbsPer100g: 66.0,
    defaultPortionGrams: 40,
    portionDescription: '4 yemek kaşığı (40g)',
  ),
  FoodReference(
    name: 'Mercimek Çorbası',
    category: 'Çorba & Baklagil',
    carbsPer100g: 8.5,
    defaultPortionGrams: 200,
    portionDescription: '1 kase (200g)',
  ),
  FoodReference(
    name: 'Kuru Fasulye / Nohut Yemeği',
    category: 'Çorba & Baklagil',
    carbsPer100g: 15.0,
    defaultPortionGrams: 150,
    portionDescription: '1 porsiyon (150g)',
  ),
  FoodReference(
    name: 'Haşlanmış / Fırın Patates',
    category: 'Sebze',
    carbsPer100g: 17.0,
    defaultPortionGrams: 120,
    portionDescription: '1 orta boy (120g)',
  ),
  FoodReference(
    name: 'Elma',
    category: 'Meyve',
    carbsPer100g: 14.0,
    defaultPortionGrams: 150,
    portionDescription: '1 orta boy (150g)',
  ),
  FoodReference(
    name: 'Muz',
    category: 'Meyve',
    carbsPer100g: 23.0,
    defaultPortionGrams: 120,
    portionDescription: '1 orta boy (120g)',
  ),
  FoodReference(
    name: 'Portakal / Mandalina',
    category: 'Meyve',
    carbsPer100g: 12.0,
    defaultPortionGrams: 130,
    portionDescription: '1 orta boy (130g)',
  ),
  FoodReference(
    name: 'Yoğurt (Tam Yağlı)',
    category: 'Süt Ürünleri',
    carbsPer100g: 4.7,
    defaultPortionGrams: 150,
    portionDescription: '1 kase (150g)',
  ),
  FoodReference(
    name: 'Süt',
    category: 'Süt Ürünleri',
    carbsPer100g: 4.8,
    defaultPortionGrams: 200,
    portionDescription: '1 su bardağı (200ml)',
  ),
  FoodReference(
    name: 'Simit',
    category: 'Ekmek & Tahıl',
    carbsPer100g: 58.0,
    defaultPortionGrams: 100,
    portionDescription: '1 tam simit (100g)',
  ),
];
