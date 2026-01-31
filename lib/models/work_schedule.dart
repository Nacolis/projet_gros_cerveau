class WorkSchedule {
  final int? id;
  final int dayOfWeek; // 1 = Monday, 7 = Sunday
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;

  WorkSchedule({
    this.id,
    required this.dayOfWeek,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
  });

  String get startTimeString {
    return '${startHour.toString().padLeft(2, '0')}:${startMinute.toString().padLeft(2, '0')}';
  }

  String get endTimeString {
    return '${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}';
  }

  Duration get totalDuration {
    final start = Duration(hours: startHour, minutes: startMinute);
    final end = Duration(hours: endHour, minutes: endMinute);
    return end - start;
  }

  double get totalHours {
    return totalDuration.inMinutes / 60.0;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'day_of_week': dayOfWeek,
      'start_hour': startHour,
      'start_minute': startMinute,
      'end_hour': endHour,
      'end_minute': endMinute,
    };
  }

  factory WorkSchedule.fromMap(Map<String, dynamic> map) {
    return WorkSchedule(
      id: map['id'] as int?,
      dayOfWeek: map['day_of_week'] as int,
      startHour: map['start_hour'] as int,
      startMinute: map['start_minute'] as int,
      endHour: map['end_hour'] as int,
      endMinute: map['end_minute'] as int,
    );
  }

  WorkSchedule copyWith({
    int? id,
    int? dayOfWeek,
    int? startHour,
    int? startMinute,
    int? endHour,
    int? endMinute,
  }) {
    return WorkSchedule(
      id: id ?? this.id,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startHour: startHour ?? this.startHour,
      startMinute: startMinute ?? this.startMinute,
      endHour: endHour ?? this.endHour,
      endMinute: endMinute ?? this.endMinute,
    );
  }

  static String dayName(int day) {
    const days = [
      'Lundi',
      'Mardi',
      'Mercredi',
      'Jeudi',
      'Vendredi',
      'Samedi',
      'Dimanche'
    ];
    return days[day - 1];
  }
}
