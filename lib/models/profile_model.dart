class GlucoseSensor {
  final String id;
  final String name;
  final String brand;
  final String durationText;
  final String description;

  const GlucoseSensor({
    required this.id,
    required this.name,
    required this.brand,
    required this.durationText,
    required this.description,
  });
}

/// Güncel kullanılan şeker takip sensörleri (CGM) listesi
const List<GlucoseSensor> kAvailableGlucoseSensors = [
  GlucoseSensor(
    id: 'freestyle_libre_2',
    name: 'FreeStyle Libre 2',
    brand: 'Abbott',
    durationText: '14 Gün',
    description: 'Düşük/yüksek şeker alarmlı, telefon veya okuyucu ile anlık takip sensörü.',
  ),
  GlucoseSensor(
    id: 'freestyle_libre_3',
    name: 'FreeStyle Libre 3',
    brand: 'Abbott',
    durationText: '14 Gün',
    description: 'Okutma gerektirmeden dakikada bir telefona veri gönderen mikro sensör.',
  ),
  GlucoseSensor(
    id: 'freestyle_libre_1',
    name: 'FreeStyle Libre 1',
    brand: 'Abbott',
    durationText: '14 Gün',
    description: 'NFC ile okutularak ölçüm yapılan 1. nesil sensör.',
  ),
  GlucoseSensor(
    id: 'dexcom_g7',
    name: 'Dexcom G7',
    brand: 'Dexcom',
    durationText: '10 Gün (+12 Saat)',
    description: 'Hepsi bir arada vericili, 30 dakikada ısınan gerçek zamanlı CGM sensörü.',
  ),
  GlucoseSensor(
    id: 'dexcom_g6',
    name: 'Dexcom G6',
    brand: 'Dexcom',
    durationText: '10 Gün',
    description: 'Kalibrasyon gerektirmeyen, ayrı vericili gerçek zamanlı CGM sistemi.',
  ),
  GlucoseSensor(
    id: 'dexcom_one_plus',
    name: 'Dexcom ONE / ONE+',
    brand: 'Dexcom',
    durationText: '10 Gün',
    description: 'Telefon uygulamasıyla gerçek zamanlı şeker takibi ve uyarı sistemi.',
  ),
  GlucoseSensor(
    id: 'medtronic_guardian_4',
    name: 'Medtronic Guardian 4',
    brand: 'Medtronic',
    durationText: '7 Gün',
    description: 'MiniMed 780G insülin pompası ve akıllı sistemlerle uyumlu CGM sensörü.',
  ),
  GlucoseSensor(
    id: 'medtronic_guardian_3',
    name: 'Medtronic Guardian Connect (Guardian 3)',
    brand: 'Medtronic',
    durationText: '7 Gün',
    description: 'Öngörülü yüksek ve düşük şeker uyarılarına sahip CGM sensörü.',
  ),
  GlucoseSensor(
    id: 'medtrum_nano',
    name: 'Medtrum TouchCare Nano CGM',
    brand: 'Medtrum',
    durationText: '14 Gün',
    description: 'İnce tasarımlı, kablosuz gerçek zamanlı glikoz izleme sensörü.',
  ),
  GlucoseSensor(
    id: 'glunovo_i3',
    name: 'Glunovo i3 CGM',
    brand: 'Glunovo',
    durationText: '14 Gün',
    description: 'Bluetooth üzerinden 3 dakikada bir ölçüm aktaran sensör.',
  ),
  GlucoseSensor(
    id: 'sibionics_gs1',
    name: 'SIBIONICS GS1 CGM',
    brand: 'SIBIONICS',
    durationText: '14 Gün',
    description: 'Kalibrasyon ve tarama gerektirmeyen 14 günlük Bluetooth CGM sensörü.',
  ),
  GlucoseSensor(
    id: 'none_fingerstick',
    name: 'Sensör Kullanmıyorum (Parmaktan Ölçüm)',
    brand: 'Glukometre',
    durationText: 'Manuel',
    description: 'Stripli kan şekeri ölçüm cihazı ile takip.',
  ),
];

/// Sabah, Öğle ve Akşam saat aralıklarına göre Karbonhidrat / İnsülin (K/İ) oranı modeli
class CarbRatioSchedule {
  final String periodName; // 'Sabah', 'Öğle', 'Akşam'
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final double carbToInsulinRatio; // 1 Ünite insülinin karşıladığı karbonhidrat (gram)

  const CarbRatioSchedule({
    required this.periodName,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    required this.carbToInsulinRatio,
  });

  String get formattedStart =>
      '${startHour.toString().padLeft(2, '0')}:${startMinute.toString().padLeft(2, '0')}';

  String get formattedEnd =>
      '${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}';

  String get formattedTimeRange => '$formattedStart - $formattedEnd';

  bool containsTime(DateTime dateTime) {
    final totalMinutes = dateTime.hour * 60 + dateTime.minute;
    final startMinutes = startHour * 60 + startMinute;
    final endMinutes = endHour * 60 + endMinute;

    if (startMinutes <= endMinutes) {
      return totalMinutes >= startMinutes && totalMinutes <= endMinutes;
    } else {
      // Gece yarısını aşan saat aralığı (Örn: 18:00 - 05:59)
      return totalMinutes >= startMinutes || totalMinutes <= endMinutes;
    }
  }

  CarbRatioSchedule copyWith({
    String? periodName,
    int? startHour,
    int? startMinute,
    int? endHour,
    int? endMinute,
    double? carbToInsulinRatio,
  }) {
    return CarbRatioSchedule(
      periodName: periodName ?? this.periodName,
      startHour: startHour ?? this.startHour,
      startMinute: startMinute ?? this.startMinute,
      endHour: endHour ?? this.endHour,
      endMinute: endMinute ?? this.endMinute,
      carbToInsulinRatio: carbToInsulinRatio ?? this.carbToInsulinRatio,
    );
  }
}

class UserProfile {
  // Kişisel Bilgiler
  final String firstName;
  final String lastName;
  final DateTime birthDate;
  final double heightCm;
  final double weightKg;

  // Diyabet Bilgileri
  final String selectedSensorId;
  final String diabetesType;

  // Sabah, Öğle, Akşam saat aralıklı K/İ oranları
  final CarbRatioSchedule morningSchedule;
  final CarbRatioSchedule noonSchedule;
  final CarbRatioSchedule eveningSchedule;

  const UserProfile({
    required this.firstName,
    required this.lastName,
    required this.birthDate,
    required this.heightCm,
    required this.weightKg,
    required this.selectedSensorId,
    this.diabetesType = 'Tip 1 Diyabet',
    this.morningSchedule = const CarbRatioSchedule(
      periodName: 'Sabah',
      startHour: 6,
      startMinute: 0,
      endHour: 11,
      endMinute: 59,
      carbToInsulinRatio: 8.0,
    ),
    this.noonSchedule = const CarbRatioSchedule(
      periodName: 'Öğle',
      startHour: 12,
      startMinute: 0,
      endHour: 17,
      endMinute: 59,
      carbToInsulinRatio: 10.0,
    ),
    this.eveningSchedule = const CarbRatioSchedule(
      periodName: 'Akşam',
      startHour: 18,
      startMinute: 0,
      endHour: 5,
      endMinute: 59,
      carbToInsulinRatio: 12.0,
    ),
  });

  List<CarbRatioSchedule> get allSchedules => [
        morningSchedule,
        noonSchedule,
        eveningSchedule,
      ];

  /// Verilen saate uygun K/İ saat aralığını döndürür
  CarbRatioSchedule getScheduleForTime(DateTime dateTime) {
    for (final schedule in allSchedules) {
      if (schedule.containsTime(dateTime)) {
        return schedule;
      }
    }
    // Eğer kullanıcı saat aralıklarında boşluk bıraktıysa saate göre varsayılan eşleşme
    final hour = dateTime.hour;
    if (hour >= 6 && hour < 12) return morningSchedule;
    if (hour >= 12 && hour < 18) return noonSchedule;
    return eveningSchedule;
  }

  String get fullName {
    final full = '${firstName.trim()} ${lastName.trim()}'.trim();
    return full.isEmpty ? 'İsimsiz Kullanıcı' : full;
  }

  int get age {
    final now = DateTime.now();
    int years = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      years--;
    }
    return years < 0 ? 0 : years;
  }

  double? get bmi {
    if (heightCm <= 0 || weightKg <= 0) return null;
    final heightM = heightCm / 100.0;
    return weightKg / (heightM * heightM);
  }

  GlucoseSensor get selectedSensor {
    return kAvailableGlucoseSensors.firstWhere(
      (s) => s.id == selectedSensorId,
      orElse: () => kAvailableGlucoseSensors.first,
    );
  }

  UserProfile copyWith({
    String? firstName,
    String? lastName,
    DateTime? birthDate,
    double? heightCm,
    double? weightKg,
    String? selectedSensorId,
    String? diabetesType,
    CarbRatioSchedule? morningSchedule,
    CarbRatioSchedule? noonSchedule,
    CarbRatioSchedule? eveningSchedule,
  }) {
    return UserProfile(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      birthDate: birthDate ?? this.birthDate,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      selectedSensorId: selectedSensorId ?? this.selectedSensorId,
      diabetesType: diabetesType ?? this.diabetesType,
      morningSchedule: morningSchedule ?? this.morningSchedule,
      noonSchedule: noonSchedule ?? this.noonSchedule,
      eveningSchedule: eveningSchedule ?? this.eveningSchedule,
    );
  }
}

/// Ortak tıbbi uyarı metni
const String kMedicalDisclaimerText =
    'Tıbbi Uyarı: Burada önerilen insülin miktarı yalnızca sizin girdiğiniz Karbonhidrat/İnsülin (K/İ) oranlarına dayalı matematiksel bir hesaplamadır ve tıbbi tavsiye niteliği taşımaz. Bir doktora veya diyabet uzmanına danışmadan insülin dozu belirlemek, değiştirmek veya uygulamak sağlığınız açısından tehlikeli ve yanlıştır.';
