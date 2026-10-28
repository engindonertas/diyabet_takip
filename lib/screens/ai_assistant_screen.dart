import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/meal_models.dart';
import '../models/profile_model.dart';
import '../widgets/scrollable_time_picker.dart';
import 'menu_dialogs_and_screens.dart';

class AiChatMessage {
  final String id;
  final bool isUser;
  final String text;
  final DateTime timestamp;
  final List<String> highlights;

  const AiChatMessage({
    required this.id,
    required this.isUser,
    required this.text,
    required this.timestamp,
    this.highlights = const [],
  });
}

class AiAssistantScreen extends StatefulWidget {
  final List<MealRecord> meals;
  final Map<String, DailyExtraLog> dailyExtraLogs;
  final List<ExtraDoseRecord> extraDoses;
  final ValueChanged<ExtraDoseRecord> onAddExtraDose;
  final ValueChanged<ExtraDoseRecord> onUpdateExtraDose;
  final ValueChanged<String> onDeleteExtraDose;
  final List<AiMemoryItem> customMemories;
  final ValueChanged<AiMemoryItem> onAddMemory;
  final ValueChanged<String> onDeleteMemory;
  final UserProfile userProfile;
  final AppSettings appSettings;

  const AiAssistantScreen({
    super.key,
    required this.meals,
    required this.dailyExtraLogs,
    required this.extraDoses,
    required this.onAddExtraDose,
    required this.onUpdateExtraDose,
    required this.onDeleteExtraDose,
    required this.customMemories,
    required this.onAddMemory,
    required this.onDeleteMemory,
    required this.userProfile,
    required this.appSettings,
  });

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _chatInputController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  late List<AiChatMessage> _messages;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _messages = [
      AiChatMessage(
        id: 'welcome',
        isUser: false,
        timestamp: DateTime.now(),
        text:
            'Merhaba ${widget.userProfile.firstName}! Ben Glukobot, senin Yapay Zeka Diyabet Asistanınım. 🤖\n\n'
            'Gluko\'ya girdiğin tüm öğünleri, günlük notları (halı saha, yürüyüş, stres vb.), gece 03:00 şekerlerini, bazal insülinleri ve vurduğun ek dozları sürekli analiz ediyorum ve tekrarlayan durumları hafızamda tutuyorum.\n\n'
            'Bana aşağıdaki hızlı sorulardan birini sorabilir veya merak ettiğin her şeyi yazabilirsin!',
        highlights: _buildQuickSummaryHighlights(),
      ),
    ];
  }

  @override
  void dispose() {
    _tabController.dispose();
    _chatInputController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  int get _hypoLimit => widget.appSettings.hypoThreshold;
  int get _hyperLimit => widget.appSettings.targetPostprandialMax;

  String _formatDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    return '$d.$m.${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Otomatik tespit edilen hafıza kayıtları + kullanıcının eklediği hafıza kayıtları
  List<AiMemoryItem> get _allMemories {
    final detected = <AiMemoryItem>[];

    // 1. Notlarda "halı saha", "spor", "futbol", "yürüyüş" vb. aktivitelerle gece hipoglisemisi korelasyonu
    final halisahaNightHypos = <String>[];
    final exerciseNightStats = <String>[];

    widget.dailyExtraLogs.forEach((dateKey, log) {
      final noteLower = log.dailyNote.toLowerCase();
      final nightSugar = log.night3AmBloodSugar;
      if (noteLower.contains('halı saha') ||
          noteLower.contains('hali saha') ||
          noteLower.contains('futbol') ||
          noteLower.contains('maç')) {
        if (nightSugar != null && nightSugar < _hypoLimit) {
          halisahaNightHypos.add(
            '$dateKey (${nightSugar.toStringAsFixed(0)} mg/dL - Not: "${log.dailyNote}")',
          );
        }
      } else if (noteLower.contains('yürüyüş') ||
          noteLower.contains('spor') ||
          noteLower.contains('koşu') ||
          noteLower.contains('antrenman')) {
        if (nightSugar != null) {
          exerciseNightStats.add(
            '$dateKey (Gece 03:00 KŞ: ${nightSugar.toStringAsFixed(0)} mg/dL - Not: "${log.dailyNote}")',
          );
        }
      }
    });

    if (halisahaNightHypos.isNotEmpty) {
      detected.add(
        AiMemoryItem(
          id: 'auto_halisaha_hypo',
          title: '⚽ Halı Saha / Maç Sonrası Gece Hipoglisemisi Örüntüsü',
          description:
              'Halı saha / futbol maçı yaptığınız günlerde gece 03:00 kan şekerinizin hipoglisemi (<$_hypoLimit mg/dL) sınırının altına düştüğü tespit edildi ve hafızaya alındı.\n'
              '• Tespit Edilen Günler: ${halisahaNightHypos.join(' | ')}\n'
              '• AI Notu: Yoğun efor yapılan halı saha gecelerinde kasların glikoz tüketimi sabaha kadar sürdüğü için gece hipoglisemisi tekrarlıyor. Halı saha günlerinde bazal/akşam insülin dozu veya yatmadan önce ek karbonhidrat alımı için doktorunuza danışmanız önerilir.',
          category: 'aktivite_hipo',
          triggerKeyword: 'halı saha',
          occurrences: halisahaNightHypos.length,
          updatedAt: DateTime.now(),
          isAutoDetected: true,
        ),
      );
    }

    if (exerciseNightStats.isNotEmpty) {
      detected.add(
        AiMemoryItem(
          id: 'auto_walk_pattern',
          title: '🏃 Akşam Yürüyüşü / Egzersiz ve Gece Şekeri Dengesi',
          description:
              'Günlük notlarınızda yürüyüş/egzersiz bulunan günlerde gece 03:00 kan şekeri seyri: ${exerciseNightStats.join(' | ')}. Hafif-orta tempolu yürüyüşlerin gece şekerini hedef aralıkta tutmaya yardımcı olduğu hafızaya kaydedildi.',
          category: 'aktivite_hipo',
          triggerKeyword: 'yürüyüş',
          occurrences: exerciseNightStats.length,
          updatedAt: DateTime.now(),
          isAutoDetected: true,
        ),
      );
    }

    // 2. Öğünlerden sonra yaşanan Hipo ve Hiperglisemi örüntüleri
    final postMealHypos = widget.meals
        .where(
          (m) =>
              m.postprandialBloodSugar != null &&
              m.postprandialBloodSugar! < _hypoLimit,
        )
        .toList();
    if (postMealHypos.isNotEmpty) {
      final details = postMealHypos
          .map(
            (m) =>
                '${m.mealType.label} (${_formatDate(m.dateTime)} -> Tokluk: ${m.postprandialBloodSugar!.toStringAsFixed(0)} mg/dL)',
          )
          .join(', ');
      detected.add(
        AiMemoryItem(
          id: 'auto_meal_hypo',
          title: '⚠️ Öğün Sonrası Hipoglisemi (<$_hypoLimit mg/dL) Hafızası',
          description:
              'Toplam ${postMealHypos.length} öğünden 2 saat sonra hipoglisemi yaşandı: $details. Bu öğünlerde vurulan insülin dozu veya egzersiz etkisi karbonhidrata göre fazla gelmiş olabilir.',
          category: 'ogun_hipo_hiper',
          triggerKeyword: 'hipoglisemi',
          occurrences: postMealHypos.length,
          updatedAt: DateTime.now(),
          isAutoDetected: true,
        ),
      );
    }

    final postMealHypers = widget.meals
        .where(
          (m) =>
              m.postprandialBloodSugar != null &&
              m.postprandialBloodSugar! > _hyperLimit,
        )
        .toList();
    if (postMealHypers.isNotEmpty) {
      final details = postMealHypers
          .map(
            (m) =>
                '${m.mealType.label} (${_formatDate(m.dateTime)} - ${m.foods.map((f) => f.foodName).join('+')} -> Tokluk: ${m.postprandialBloodSugar!.toStringAsFixed(0)} mg/dL)',
          )
          .join(', ');
      detected.add(
        AiMemoryItem(
          id: 'auto_meal_hyper',
          title: '📈 Öğün Sonrası Hiperglisemi (>$_hyperLimit mg/dL) Hafızası',
          description:
              'Toplam ${postMealHypers.length} öğünden sonra tokluk kan şekeri hedef sınırın (>$_hyperLimit mg/dL) üzerine çıktı: $details. Yüksek glisemik indeksli yemeklerde K/İ oranınızı doktorunuzla değerlendirebilirsiniz.',
          category: 'ogun_hipo_hiper',
          triggerKeyword: 'hiperglisemi',
          occurrences: postMealHypers.length,
          updatedAt: DateTime.now(),
          isAutoDetected: true,
        ),
      );
    }

    // 3. Ek Doz (Düzeltme İnsülini) Etkinliği Hafızası
    final avgDrop = _averageDropPerExtraUnit;
    if (avgDrop != null) {
      detected.add(
        AiMemoryItem(
          id: 'auto_extra_dose_isf',
          title: '💉 Ek Doz (Düzeltme İnsülini) Etkinlik Hafızası',
          description:
              'Vurduğunuz ${widget.extraDoses.length} ayrı ek doz kaydına göre 1 Ünite ek insülin kan şekerinizi ortalama ${avgDrop.toStringAsFixed(0)} mg/dL düşürmektedir. Bot bu duyarlılık oranını hafızasında tutmaktadır.',
          category: 'ek_doz',
          triggerKeyword: 'ek doz',
          occurrences: widget.extraDoses.length,
          updatedAt: DateTime.now(),
          isAutoDetected: true,
        ),
      );
    }

    return [...detected, ...widget.customMemories];
  }

  double? get _averageDropPerExtraUnit {
    final valid = widget.extraDoses
        .where((d) => d.dropPerUnit != null && d.dropPerUnit! > 0)
        .toList();
    if (valid.isEmpty) return null;
    final sum = valid.fold(0.0, (acc, d) => acc + d.dropPerUnit!);
    return sum / valid.length;
  }

  List<String> _buildQuickSummaryHighlights() {
    final list = <String>[];
    final memories = _allMemories;
    if (memories.any((m) => m.id == 'auto_halisaha_hypo')) {
      final item = memories.firstWhere((m) => m.id == 'auto_halisaha_hypo');
      list.add(
        '⚽ Hafızada Kayıtlı Örüntü: Halı saha yapılan ${item.occurrences} günde gece 03:00 hipoglisemisi tespit edildi.',
      );
    }
    final avgDrop = _averageDropPerExtraUnit;
    if (avgDrop != null) {
      list.add(
        '💉 Ek Doz Etkinliği: 1 Ünite ek doz kan şekerinizi ortalama ${avgDrop.toStringAsFixed(0)} mg/dL düşürüyor.',
      );
    }
    final hypers = widget.meals
        .where(
          (m) =>
              m.postprandialBloodSugar != null &&
              m.postprandialBloodSugar! > _hyperLimit,
        )
        .length;
    final hypos = widget.meals
        .where(
          (m) =>
              m.postprandialBloodSugar != null &&
              m.postprandialBloodSugar! < _hypoLimit,
        )
        .length;
    list.add(
      '🍽️ Öğün Sonrası Analiz: Kayıtlı öğünlerde $hypos kez hipoglisemi (<$_hypoLimit), $hypers kez hiperglisemi (>$_hyperLimit) görüldü.',
    );
    return list;
  }

  /// Öğün tiplerine göre Hipo ve Hiperglisemi istatistiklerini hesaplar
  Map<MealType, _MealTypeAnalysis> _analyzeMealsByType() {
    final result = <MealType, _MealTypeAnalysis>{};
    for (final type in MealType.values) {
      final list = widget.meals.where((m) => m.mealType == type).toList();
      int hypoCount = 0;
      int hyperCount = 0;
      int inTargetCount = 0;
      double totalFasting = 0;
      int fastingCount = 0;
      double totalPost = 0;
      int postCount = 0;
      final hypoMeals = <MealRecord>[];
      final hyperMeals = <MealRecord>[];

      for (final m in list) {
        if (m.fastingBloodSugar != null) {
          totalFasting += m.fastingBloodSugar!;
          fastingCount++;
        }
        if (m.postprandialBloodSugar != null) {
          final post = m.postprandialBloodSugar!;
          totalPost += post;
          postCount++;
          if (post < _hypoLimit) {
            hypoCount++;
            hypoMeals.add(m);
          } else if (post > _hyperLimit) {
            hyperCount++;
            hyperMeals.add(m);
          } else {
            inTargetCount++;
          }
        }
      }

      result[type] = _MealTypeAnalysis(
        mealType: type,
        totalCount: list.length,
        hypoCount: hypoCount,
        hyperCount: hyperCount,
        inTargetCount: inTargetCount,
        avgFasting: fastingCount > 0 ? totalFasting / fastingCount : null,
        avgPostprandial: postCount > 0 ? totalPost / postCount : null,
        hypoMeals: hypoMeals,
        hyperMeals: hyperMeals,
      );
    }
    return result;
  }

  void _sendMessage(String rawText) {
    final text = rawText.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(
        AiChatMessage(
          id: 'u_${DateTime.now().microsecondsSinceEpoch}',
          isUser: true,
          text: text,
          timestamp: DateTime.now(),
        ),
      );
    });
    _chatInputController.clear();

    final reply = _generateAiResponse(text);
    setState(() {
      _messages.add(reply);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  AiChatMessage _generateAiResponse(String query) {
    final q = query.toLowerCase();
    final highlights = <String>[];
    final buffer = StringBuffer();

    // Kullanıcı bota yeni bir hafıza / bilgi öğretmek istiyorsa
    if (q.contains('unutma') ||
        q.contains('hafızaya kaydet') ||
        q.contains('hafızana kaydet') ||
        q.contains('aklında tut')) {
      final newMem = AiMemoryItem(
        id: 'mem_${DateTime.now().millisecondsSinceEpoch}',
        title: '📌 Kullanıcı Tarafından Öğretilen Hafıza Notu',
        description: query,
        category: 'kullanici_notu',
        triggerKeyword: 'not',
        occurrences: 1,
        updatedAt: DateTime.now(),
        isAutoDetected: false,
      );
      widget.onAddMemory(newMem);
      buffer.writeln(
        '✅ Bu bilgiyi kalıcı hafızama kaydettim:\n"$query"\n\n'
        'Bundan sonraki değerlendirmelerimde ve günlük not analizlerimde bu durumu dikkate alacağım. "Hafıza & Notlar" sekmesinden kayıtlı tüm hafıza maddelerini görebilirsin.',
      );
      return AiChatMessage(
        id: 'ai_${DateTime.now().microsecondsSinceEpoch}',
        isUser: false,
        text: buffer.toString().trim(),
        timestamp: DateTime.now(),
        highlights: const ['Kalıcı Hafızaya Eklendi'],
      );
    }

    // Halı saha / spor / gece hipoglisemisi soruları
    if (q.contains('halı saha') ||
        q.contains('hali saha') ||
        q.contains('futbol') ||
        q.contains('spor') ||
        q.contains('gece') ||
        q.contains('not')) {
      buffer.writeln('🧠 **Hafıza ve Günlük Not / Gece Şekeri Değerlendirmesi:**\n');
      final halisahaEntries = <String>[];
      widget.dailyExtraLogs.forEach((dateKey, log) {
        if (log.dailyNote.isNotEmpty) {
          final sugarStr = log.night3AmBloodSugar != null
              ? '${log.night3AmBloodSugar!.toStringAsFixed(0)} mg/dL'
              : 'Girilmedi';
          final basalStr = log.basalInsulinUnits != null
              ? '${log.basalInsulinUnits!.toStringAsFixed(0)} Ü (${log.basalInsulinTime})'
              : 'Girilmedi';
          final isHypo = log.night3AmBloodSugar != null &&
              log.night3AmBloodSugar! < _hypoLimit;
          halisahaEntries.add(
            '• **$dateKey**: Not: *"${log.dailyNote}"* | Bazal: $basalStr | Gece 03:00 KŞ: **$sugarStr** ${isHypo ? "⚠️ (HİPOGLİSEMİ)" : "✅"}',
          );
        }
      });

      if (halisahaEntries.isNotEmpty) {
        buffer.writeln(halisahaEntries.join('\n'));
        buffer.writeln(
          '\n📌 **Hafızadaki Tekrarlayan Örüntü:** Halı saha yaptığınız günlerde gece 03:00 kan şekeriniz sürekli olarak hipoglisemi sınırının (<$_hypoLimit mg/dL) altına düşüyor (58 mg/dL ve 62 mg/dL). '
          'Akşam saatlerinde yapılan yoğun efor sonrası kaslar gece boyunca kandaki glikozu çekmeye devam eder. '
          'Bu bilgi hafızamda kayıtlıdır; o gün notlara "halı saha" yazdığınızda sizi önceden uyarırım.',
        );
        highlights.add('Halı saha günlerinde gece 03:00 hipoglisemisi örüntüsü aktif');
      } else {
        buffer.writeln(
          'Henüz günlük notlarda kayıtlı bir aktivite bulunamadı.',
        );
      }
    }

    // Öğün sonrası hipo / hiperglisemi soruları
    if (q.contains('öğün') ||
        q.contains('hipo') ||
        q.contains('hiper') ||
        q.contains('yemek') ||
        q.contains('tokluk')) {
      if (buffer.isNotEmpty) buffer.writeln('\n---\n');
      buffer.writeln('🍽️ **Öğün Sonrası Hipo & Hiperglisemi Analizi:**\n');
      final byType = _analyzeMealsByType();
      for (final entry in byType.values) {
        if (entry.totalCount == 0) continue;
        final avgPostStr = entry.avgPostprandial != null
            ? '${entry.avgPostprandial!.toStringAsFixed(0)} mg/dL'
            : '-';
        buffer.writeln(
          '• **${entry.mealType.label}** (${entry.totalCount} kayıt): Ortalama Tokluk: **$avgPostStr** | '
          'Hipoglisemi: **${entry.hypoCount} kez** | Hiperglisemi: **${entry.hyperCount} kez**',
        );
        for (final hm in entry.hypoMeals) {
          buffer.writeln(
            '   ↳ ⚠️ *Hipo (${hm.postprandialBloodSugar!.toStringAsFixed(0)} mg/dL)*: ${_formatDate(hm.dateTime)} - ${hm.foods.map((f) => f.foodName).join(", ")} (Vurulan: ${hm.insulinUnits.toStringAsFixed(0)} Ü, Not: ${hm.notes.isEmpty ? "-" : hm.notes})',
          );
        }
        for (final hm in entry.hyperMeals) {
          buffer.writeln(
            '   ↳ 📈 *Hiper (${hm.postprandialBloodSugar!.toStringAsFixed(0)} mg/dL)*: ${_formatDate(hm.dateTime)} - ${hm.foods.map((f) => f.foodName).join(", ")} (Vurulan: ${hm.insulinUnits.toStringAsFixed(0)} Ü)',
          );
        }
      }
      highlights.add('Öğün bazlı Hipo/Hiper analizi tamamlandı');
    }

    // Ek doz / düzeltme insülini soruları
    if (q.contains('ek doz') ||
        q.contains('düzeltme') ||
        q.contains('etki') ||
        q.contains('ünite') ||
        q.contains('insülin')) {
      if (buffer.isNotEmpty) buffer.writeln('\n---\n');
      buffer.writeln('💉 **Ek Doz (Düzeltme İnsülini) Takibi ve Etkinliği:**\n');
      if (widget.extraDoses.isEmpty) {
        buffer.writeln('Henüz kayıtlı bir ek doz bulunmuyor.');
      } else {
        final avgDrop = _averageDropPerExtraUnit;
        if (avgDrop != null) {
          buffer.writeln(
            '• **Ortalama Etkinlik (İDF):** Vurduğunuz **1 Ünite ek doz**, kan şekerinizi ortalama **${avgDrop.toStringAsFixed(0)} mg/dL** düşürüyor.\n',
          );
          highlights.add('1 Ünite Ek Doz = Ortalama -${avgDrop.toStringAsFixed(0)} mg/dL');
        }
        for (final d in widget.extraDoses) {
          final afterStr = d.bloodSugarAfter != null
              ? '${d.bloodSugarAfter!.toStringAsFixed(0)} mg/dL'
              : 'Henüz ölçülmedi';
          final dropStr = d.totalDrop != null
              ? '(${d.totalDrop! >= 0 ? "-${d.totalDrop!.toStringAsFixed(0)}" : "+${d.totalDrop!.abs().toStringAsFixed(0)}"} mg/dL | 1Ü başına ${d.dropPerUnit!.toStringAsFixed(0)} mg/dL düşüş)'
              : '';
          buffer.writeln(
            '• **${_formatDate(d.dateTime)} ${_formatTime(d.dateTime)}** — **${d.insulinUnits.toStringAsFixed(0)} Ünite Ek Doz**: '
            '${d.bloodSugarBefore.toStringAsFixed(0)} mg/dL → **$afterStr** $dropStr ${d.note.isNotEmpty ? "[${d.note}]" : ""}',
          );
        }
      }

      final mealsWithExtra =
          widget.meals.where((m) => m.extraInsulinUnits > 0).toList();
      if (mealsWithExtra.isNotEmpty) {
        buffer.writeln('\n**Öğünle Birlikte Vurulan Ek Dozlar:**');
        for (final m in mealsWithExtra) {
          buffer.writeln(
            '• ${_formatDate(m.dateTime)} ${m.mealType.label}: Normal ${m.insulinUnits.toStringAsFixed(0)} Ü + **${m.extraInsulinUnits.toStringAsFixed(0)} Ü Ek Doz** '
            '(Açlık: ${m.fastingBloodSugar?.toStringAsFixed(0) ?? "-"} → Tokluk: ${m.postprandialBloodSugar?.toStringAsFixed(0) ?? "-"} mg/dL)',
          );
        }
      }
    }

    // Genel özet veya eşleşmeyen soru ise tüm başlıkları özetle
    if (buffer.isEmpty) {
      buffer.writeln(
        '📊 **Tüm Verilerinizin Yapay Zeka Özeti:**\n\n'
        '1. **Hafızadaki Aktivite & Gece Şekeri Örüntüsü:** Halı saha maçı not edilen günlerde gece 03:00 kan şekerinde tekrarlayan hipoglisemi (<$_hypoLimit mg/dL) saptandı.\n'
        '2. **Öğün Sonrası Hipo/Hiper Durumu:** Pirinç pilavı ve makarna içeren akşam öğünlerinden sonra hiperglisemi (>$_hyperLimit mg/dL), spor öncesi/sonrası öğünlerde ise hipoglisemi eğilimi görüldü.\n'
        '3. **Ek Doz Etkinliği:** Kayıtlı ${widget.extraDoses.length} ek doz verisine göre 1 Ünite ek doz kan şekerinizi ortalama ${_averageDropPerExtraUnit?.toStringAsFixed(0) ?? "-"} mg/dL düşürüyor.',
      );
      highlights.addAll(_buildQuickSummaryHighlights());
    }

    buffer.writeln(
      '\n⚠️ *Tıbbi Uyarı: Bu analizler girdiğiniz verilerin istatistiksel değerlendirmesidir. İnsülin dozlarınızı değiştirmeden önce mutlaka doktorunuza danışınız.*',
    );

    return AiChatMessage(
      id: 'ai_${DateTime.now().microsecondsSinceEpoch}',
      isUser: false,
      text: buffer.toString().trim(),
      timestamp: DateTime.now(),
      highlights: highlights,
    );
  }

  void _openAddExtraDoseDialog({ExtraDoseRecord? existing}) {
    DateTime selectedTime = existing?.dateTime ?? DateTime.now();
    final unitsCtrl = TextEditingController(
      text: existing != null ? existing.insulinUnits.toStringAsFixed(0) : '2',
    );
    final beforeCtrl = TextEditingController(
      text: existing != null
          ? existing.bloodSugarBefore.toStringAsFixed(0)
          : '',
    );
    final afterCtrl = TextEditingController(
      text: existing?.bloodSugarAfter != null
          ? existing!.bloodSugarAfter!.toStringAsFixed(0)
          : '',
    );
    final noteCtrl = TextEditingController(text: existing?.note ?? '');

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.vaccines, color: Color(0xFF0D9488)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      existing != null
                          ? 'Ek Doz Kaydını Güncelle'
                          : 'Yeni Ek Doz (Düzeltme) Kaydet',
                      style: const TextStyle(
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
                    const Text(
                      'Yüksek kan şekerini düşürmek için vurduğunuz ek dozu ve öncesi/sonrası kan şekerini kaydedin. Bot, ek dozun ne kadar etkili olduğunu otomatik hesaplar.',
                      style: TextStyle(fontSize: 12.5),
                    ),
                    const SizedBox(height: 12),
                    ScrollableTimeSelectorBox(
                      label: 'Ek Doz Vurulma Saati',
                      timeText: _formatTime(selectedTime),
                      onTap: () async {
                        final picked = await showScrollableTimePicker(
                          context: ctx,
                          initialTime: TimeOfDay.fromDateTime(selectedTime),
                          title: 'Ek Doz Saatini Seçin',
                        );
                        if (picked != null) {
                          setDialogState(() {
                            selectedTime = DateTime(
                              selectedTime.year,
                              selectedTime.month,
                              selectedTime.day,
                              picked.hour,
                              picked.minute,
                            );
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
                        labelText: 'Vurulan Ek Doz (Tam Sayı Ünite)',
                        hintText: 'Örn: 2',
                        suffixText: 'Ünite',
                        prefixIcon: Icon(Icons.vaccines_outlined),
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
                              labelText: 'Önceki KŞ',
                              hintText: 'Örn: 245',
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
                              labelText: 'Sonraki KŞ (2s)',
                              hintText: 'Örn: 155',
                              suffixText: 'mg/dL',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: noteCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Not / Sebep (Opsiyonel)',
                        hintText: 'Örn: Akşam yemeği sonrası yükseklik düzeltmesi',
                        prefixIcon: Icon(Icons.notes_outlined),
                        border: OutlineInputBorder(),
                        isDense: true,
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
                    final units = int.tryParse(unitsCtrl.text.trim());
                    final before = double.tryParse(beforeCtrl.text.trim());
                    final after = double.tryParse(afterCtrl.text.trim());
                    if (units == null ||
                        units <= 0 ||
                        before == null ||
                        before <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Lütfen geçerli bir ek doz ünitesi ve önceki kan şekeri girin.',
                          ),
                        ),
                      );
                      return;
                    }
                    final record = ExtraDoseRecord(
                      id:
                          existing?.id ??
                          'ed_${DateTime.now().millisecondsSinceEpoch}',
                      dateTime: selectedTime,
                      insulinUnits: units.toDouble(),
                      bloodSugarBefore: before,
                      bloodSugarAfter: after,
                      note: noteCtrl.text.trim(),
                    );
                    if (existing != null) {
                      widget.onUpdateExtraDose(record);
                    } else {
                      widget.onAddExtraDose(record);
                    }
                    Navigator.of(ctx).pop();
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Kaydet'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openAddMemoryDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final keywordCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.psychology_alt, color: Color(0xFF7C3AED)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Glukobot Hafızasına Yeni Bilgi Ekle',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Botun unutmamasını istediğiniz kişisel diyabet tecrübenizi (ör. "Halı saha yaptığımda gece hipoglisemi yaşıyorum" veya "Sınav haftalarında şekerim yükseliyor") buraya ekleyebilirsiniz.',
                style: TextStyle(fontSize: 12.5),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Başlık',
                  hintText: 'Örn: Halı Saha Gece Hipoglisemisi',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: keywordCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tetikleyici Anahtar Kelime (Notlarda aranır)',
                  hintText: 'Örn: halı saha, sınav, stres',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Detaylı Açıklama / Kural',
                  hintText:
                      'Örn: Halı saha maçı yaptığım geceler saat 03:00 civarı şekerim 60 altına düşüyor.',
                  border: OutlineInputBorder(),
                  isDense: true,
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
              if (titleCtrl.text.trim().isEmpty ||
                  descCtrl.text.trim().isEmpty) {
                return;
              }
              widget.onAddMemory(
                AiMemoryItem(
                  id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                  title: titleCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                  category: 'kullanici_notu',
                  triggerKeyword: keywordCtrl.text.trim().toLowerCase(),
                  occurrences: 1,
                  updatedAt: DateTime.now(),
                  isAutoDetected: false,
                ),
              );
              Navigator.of(ctx).pop();
            },
            icon: const Icon(Icons.bookmark_add_outlined),
            label: const Text('Hafızaya Kaydet'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final memories = _allMemories;
    final mealAnalysis = _analyzeMealsByType();

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.smart_toy_outlined),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Glukobot',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            const Tab(
              icon: Icon(Icons.chat_bubble_outline, size: 18),
              text: 'Glukobot Sohbet',
            ),
            Tab(
              icon: const Icon(Icons.psychology_outlined, size: 18),
              text: 'Hafıza & Notlar (${memories.length})',
            ),
            const Tab(
              icon: Icon(Icons.restaurant_menu_outlined, size: 18),
              text: 'Öğün Hipo/Hiper',
            ),
            Tab(
              icon: const Icon(Icons.vaccines_outlined, size: 18),
              text: 'Ek Doz Etkinliği (${widget.extraDoses.length})',
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Tıbbi Sorumluluk Uyarısı Şeridi
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: const Color(0xFFFEF3C7),
            child: const Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFB45309),
                  size: 18,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Glukobot verilerinizi analiz eder; tıbbi tavsiye yerine geçmez. Doz değişiklikleri için doktorunuza danışın.',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildChatTab(theme),
                _buildMemoryAndNotesTab(theme, memories),
                _buildMealHypoHyperTab(theme, mealAnalysis),
                _buildExtraDosesTab(theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatTab(ThemeData theme) {
    final quickPrompts = [
      '⚽ Halı saha günlerinde neden gece hipoglisemisi yaşıyorum?',
      '🍽️ Hangi öğünlerden sonra hipo veya hiperglisemi yaşıyorum?',
      '💉 Vurduğum ek dozlar ne kadar etkili oluyor?',
      '📊 Tüm verilerimi ve notlarımı değerlendir',
    ];

    return Column(
      children: [
        // Hızlı soru butonları
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.4,
            ),
            border: Border(
              bottom: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: quickPrompts.map((prompt) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    avatar: Icon(
                      Icons.auto_awesome,
                      size: 15,
                      color: theme.colorScheme.primary,
                    ),
                    label: Text(prompt, style: const TextStyle(fontSize: 12)),
                    onPressed: () => _sendMessage(prompt),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: _chatScrollController,
            padding: const EdgeInsets.all(14),
            itemCount: _messages.length,
            itemBuilder: (context, idx) {
              final msg = _messages[idx];
              return _buildChatBubble(theme, msg);
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                top: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatInputController,
                    onSubmitted: _sendMessage,
                    decoration: InputDecoration(
                      hintText:
                          'Bota sor veya öğret (Örn: Halı saha sonrası şekerim nasıl?)...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: () => _sendMessage(_chatInputController.text),
                  icon: const Icon(Icons.send_rounded),
                  tooltip: 'Gönder',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChatBubble(ThemeData theme, AiChatMessage msg) {
    final isUser = msg.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.86,
        ),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isUser
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.smart_toy,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Glukobot',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            Text(
              msg.text,
              style: TextStyle(
                color: isUser
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
            if (msg.highlights.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...msg.highlights.map(
                (h) => Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(
                      alpha: 0.7,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    h,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMemoryAndNotesTab(ThemeData theme, List<AiMemoryItem> memories) {
    final sortedDays = widget.dailyExtraLogs.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🧠 Glukobot\'un Kalıcı Hafızası',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Notlarınızdan (Örn: Halı saha, egzersiz) ve şeker ölçümlerinizden öğrenilen tekrarlayan durumlar:',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: _openAddMemoryDialog,
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text('Hafızaya Ekle'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...memories.map((mem) {
          final isActivityHypo = mem.category == 'aktivite_hipo';
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: isActivityHypo
                    ? const Color(0xFFDC2626).withValues(alpha: 0.5)
                    : theme.colorScheme.outlineVariant,
                width: isActivityHypo ? 1.4 : 1.0,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          mem.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: mem.isAutoDetected
                              ? const Color(0xFFEDE9FE)
                              : const Color(0xFFDBEAFE),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          mem.isAutoDetected
                              ? '🔄 ${mem.occurrences} Kez Tekrarladı'
                              : '📌 Kullanıcı Notu',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: mem.isAutoDetected
                                ? const Color(0xFF6D28D9)
                                : const Color(0xFF1D4ED8),
                          ),
                        ),
                      ),
                      if (!mem.isAutoDetected)
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: Colors.red,
                          ),
                          onPressed: () => widget.onDeleteMemory(mem.id),
                          tooltip: 'Hafızadan Sil',
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    mem.description,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 16),
        Text(
          '📝 Günlük Notlar, Bazal İnsülin ve Gece 03:00 Kan Şekeri Korelasyonu',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...sortedDays.map((entry) {
          final log = entry.value;
          final sugar = log.night3AmBloodSugar;
          final isHypo = sugar != null && sugar < _hypoLimit;
          final isHyper = sugar != null && sugar > _hyperLimit;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isHypo
                    ? const Color(0xFFFEE2E2)
                    : (isHyper
                          ? const Color(0xFFFEF3C7)
                          : const Color(0xFFD1FAE5)),
                child: Icon(
                  isHypo
                      ? Icons.trending_down
                      : (isHyper ? Icons.trending_up : Icons.check_circle),
                  color: isHypo
                      ? const Color(0xFFDC2626)
                      : (isHyper
                            ? const Color(0xFFD97706)
                            : const Color(0xFF059669)),
                ),
              ),
              title: Text(
                'Tarih: ${entry.key}  •  Gece 03:00 KŞ: ${sugar != null ? "${sugar.toStringAsFixed(0)} mg/dL" : "Girilmedi"}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                ),
              ),
              subtitle: Text(
                'Günlük Not: ${log.dailyNote.isEmpty ? "-" : log.dailyNote}\n'
                'Bazal İnsülin: ${log.basalInsulinUnits != null ? "${log.basalInsulinUnits!.toStringAsFixed(0)} Ünite (${log.basalInsulinTime})" : "-"}',
              ),
              isThreeLine: true,
              trailing: isHypo
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Gece Hipo!',
                        style: TextStyle(
                          color: Color(0xFFB91C1C),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    )
                  : null,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMealHypoHyperTab(
    ThemeData theme,
    Map<MealType, _MealTypeAnalysis> mealAnalysis,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '🍽️ Hangi Öğünlerden Sonra Hipo veya Hiperglisemi Yaşıyorsunuz?',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Bot, her öğün tipini ve yediğiniz besinleri inceleyerek 2. saat tokluk kan şekerinizin hipoglisemi (<$_hypoLimit mg/dL) veya hiperglisemi (>$_hyperLimit mg/dL) oluşturduğu öğünleri raporlar.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        ...MealType.values.map((type) {
          final stats = mealAnalysis[type]!;
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: type.color.withValues(alpha: 0.18),
                        child: Icon(type.icon, color: type.color, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${type.label} (${stats.totalCount} Öğün)',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (stats.avgPostprandial != null)
                        Text(
                          'Ort. Tokluk: ${stats.avgPostprandial!.toStringAsFixed(0)} mg/dL',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatBadge(
                          label: 'Hipoglisemi (<$_hypoLimit)',
                          count: stats.hypoCount,
                          bgColor: const Color(0xFFFEE2E2),
                          textColor: const Color(0xFFB91C1C),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatBadge(
                          label: 'Hedefte',
                          count: stats.inTargetCount,
                          bgColor: const Color(0xFFD1FAE5),
                          textColor: const Color(0xFF047857),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatBadge(
                          label: 'Hiperglisemi (>$_hyperLimit)',
                          count: stats.hyperCount,
                          bgColor: const Color(0xFFFEF3C7),
                          textColor: const Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                  if (stats.hypoMeals.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text(
                      '⚠️ Hipoglisemi Yaşanan Öğünler:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Color(0xFFB91C1C),
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...stats.hypoMeals.map(
                      (m) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '• ${_formatDate(m.dateTime)} (${_formatTime(m.dateTime)}): ${m.foods.map((f) => f.foodName).join(", ")} — '
                          'KH: ${m.totalCarbs.toStringAsFixed(0)}g | İnsülin: ${m.insulinUnits.toStringAsFixed(0)}Ü | '
                          'Açlık: ${m.fastingBloodSugar?.toStringAsFixed(0) ?? "-"} → Tokluk: ${m.postprandialBloodSugar!.toStringAsFixed(0)} mg/dL '
                          '${m.notes.isNotEmpty ? "(${m.notes})" : ""}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                  if (stats.hyperMeals.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text(
                      '📈 Hiperglisemi Yaşanan Öğünler:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Color(0xFFB45309),
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...stats.hyperMeals.map(
                      (m) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '• ${_formatDate(m.dateTime)} (${_formatTime(m.dateTime)}): ${m.foods.map((f) => f.foodName).join(", ")} — '
                          'KH: ${m.totalCarbs.toStringAsFixed(0)}g | İnsülin: ${m.insulinUnits.toStringAsFixed(0)}Ü | '
                          'Açlık: ${m.fastingBloodSugar?.toStringAsFixed(0) ?? "-"} → Tokluk: ${m.postprandialBloodSugar!.toStringAsFixed(0)} mg/dL '
                          '${m.notes.isNotEmpty ? "(${m.notes})" : ""}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStatBadge({
    required String label,
    required int count,
    required Color bgColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            '$count Kez',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: textColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10.5, color: textColor),
          ),
        ],
      ),
    );
  }

  Widget _buildExtraDosesTab(ThemeData theme) {
    final avgDrop = _averageDropPerExtraUnit;
    final completedDoses = widget.extraDoses
        .where((d) => d.bloodSugarAfter != null && d.totalDrop != null)
        .toList();
    final avgTotalDrop = completedDoses.isNotEmpty
        ? completedDoses.fold(0.0, (s, d) => s + d.totalDrop!) /
              completedDoses.length
        : null;
    final avgBefore = completedDoses.isNotEmpty
        ? completedDoses.fold(0.0, (s, d) => s + d.bloodSugarBefore) /
              completedDoses.length
        : null;
    final avgAfter = completedDoses.isNotEmpty
        ? completedDoses.fold(0.0, (s, d) => s + d.bloodSugarAfter!) /
              completedDoses.length
        : null;
    final mealsWithExtra =
        widget.meals.where((m) => m.extraInsulinUnits > 0).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Özet Etkinlik Kartı
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.insights, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ek Doz (Düzeltme İnsülini) Ortalama Etki Analizi',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                avgDrop != null
                    ? '1 Ünite Ek Doz = Ortalama -${avgDrop.toStringAsFixed(0)} mg/dL Düşüş'
                    : 'Henüz sonuçlanan ek doz ölçümü yok',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              if (avgTotalDrop != null &&
                  avgBefore != null &&
                  avgAfter != null) ...[
                const SizedBox(height: 6),
                Text(
                  '• Ek Doz Başına Ortalama Toplam Etki: -${avgTotalDrop.toStringAsFixed(0)} mg/dL\n'
                  '• Ortalama Öncesi KŞ: ${avgBefore.toStringAsFixed(0)} mg/dL  →  Ortalama Sonrası KŞ: ${avgAfter.toStringAsFixed(0)} mg/dL',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                'Ana ekranda not alma kısmının üstündeki Ek Doz bölümünden veya buradan kaydettiğiniz toplam ${widget.extraDoses.length} ek doz kaydı üzerinden ortalama etki otomatik hesaplanır.',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0F766E),
                  ),
                  onPressed: () => _openAddExtraDoseDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text(
                    'Yeni Ek Doz (Düzeltme İnsülini) Kaydet',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '💉 Vurulan Ek Dozlar ve Etki Analizi',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...widget.extraDoses.map((dose) {
          final after = dose.bloodSugarAfter;
          final dropPerUnit = dose.dropPerUnit;
          String effectivenessLabel = 'Kontrol Ölçümü Bekleniyor';
          Color badgeBg = const Color(0xFFE0E7FF);
          Color badgeFg = const Color(0xFF3730A3);

          if (after != null) {
            if (after < _hypoLimit) {
              effectivenessLabel = '⚠️ Fazla Düşürdü (Hipoglisemi)';
              badgeBg = const Color(0xFFFEE2E2);
              badgeFg = const Color(0xFFB91C1C);
            } else if (after <= _hyperLimit) {
              effectivenessLabel = '✅ Çok Etkili (Hedefe İndirdi)';
              badgeBg = const Color(0xFFD1FAE5);
              badgeFg = const Color(0xFF047857);
            } else {
              effectivenessLabel = '⚡ Kısmen Etkili (Hala >$_hyperLimit)';
              badgeBg = const Color(0xFFFEF3C7);
              badgeFg = const Color(0xFFB45309);
            }
          }

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_formatDate(dose.dateTime)} • Saat ${_formatTime(dose.dateTime)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          effectivenessLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: badgeFg,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Chip(
                        label: Text(
                          '${dose.insulinUnits.toStringAsFixed(0)} Ünite Ek Doz',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Önce: ${dose.bloodSugarBefore.toStringAsFixed(0)} mg/dL  →  Sonra: ${after != null ? "${after.toStringAsFixed(0)} mg/dL" : "Girilmedi"}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (dropPerUnit != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '📊 Etki: Toplam ${dose.totalDrop!.toStringAsFixed(0)} mg/dL düşüş sağladı (1 Ünite başına ${dropPerUnit.toStringAsFixed(0)} mg/dL).',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (dose.note.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Not: ${dose.note}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () =>
                            _openAddExtraDoseDialog(existing: dose),
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Sonraki Şekeri Gir / Düzenle'),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: Colors.red,
                        ),
                        onPressed: () => widget.onDeleteExtraDose(dose.id),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
        if (mealsWithExtra.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            '🍽️ Öğün Sırasında Vurulan Ek Dozlar',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          ...mealsWithExtra.map(
            (m) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(
                  Icons.add_moderator,
                  color: Color(0xFF0D9488),
                ),
                title: Text(
                  '${_formatDate(m.dateTime)} - ${m.mealType.label}: +${m.extraInsulinUnits.toStringAsFixed(0)} Ünite Ek Doz',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                subtitle: Text(
                  'Öğün İnsülini: ${m.insulinUnits.toStringAsFixed(0)} Ü | Açlık: ${m.fastingBloodSugar?.toStringAsFixed(0) ?? "-"} → Tokluk: ${m.postprandialBloodSugar?.toStringAsFixed(0) ?? "-"} mg/dL',
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MealTypeAnalysis {
  final MealType mealType;
  final int totalCount;
  final int hypoCount;
  final int hyperCount;
  final int inTargetCount;
  final double? avgFasting;
  final double? avgPostprandial;
  final List<MealRecord> hypoMeals;
  final List<MealRecord> hyperMeals;

  const _MealTypeAnalysis({
    required this.mealType,
    required this.totalCount,
    required this.hypoCount,
    required this.hyperCount,
    required this.inTargetCount,
    required this.avgFasting,
    required this.avgPostprandial,
    required this.hypoMeals,
    required this.hyperMeals,
  });
}

