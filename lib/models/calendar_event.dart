enum EventType {
  exam('Examen', 'exam'),
  whiteExam('Examen blanc', 'white_exam'),
  masterclass('Masterclass', 'masterclass'),
  other('Autre', 'other');

  const EventType(this.label, this.value);
  final String label;
  final String value;

  static EventType fromString(String value) {
    return EventType.values.firstWhere(
      (e) => e.value == value || e.name == value,
      orElse: () => EventType.other,
    );
  }
}

class CalendarEvent {
  final int? id;
  final String name;
  final EventType eventType;
  final int? itemCollegeId; // Optional link to an item/college
  final DateTime scheduledDate;
  final DateTime scheduledStartTime;
  final DateTime scheduledEndTime;
  final bool isCompleted;
  final DateTime? completedDate;
  final String? notes;

  CalendarEvent({
    this.id,
    required this.name,
    required this.eventType,
    this.itemCollegeId,
    required this.scheduledDate,
    required this.scheduledStartTime,
    required this.scheduledEndTime,
    this.isCompleted = false,
    this.completedDate,
    this.notes,
  });

  Duration get duration {
    return scheduledEndTime.difference(scheduledStartTime);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'event_type': eventType.value,
      'item_college_id': itemCollegeId,
      'scheduled_date': scheduledDate.toIso8601String(),
      'scheduled_start_time': scheduledStartTime.toIso8601String(),
      'scheduled_end_time': scheduledEndTime.toIso8601String(),
      'is_completed': isCompleted ? 1 : 0,
      'completed_date': completedDate?.toIso8601String(),
      'notes': notes,
    };
  }

  factory CalendarEvent.fromMap(Map<String, dynamic> map) {
    return CalendarEvent(
      id: map['id'] as int?,
      name: map['name'] as String,
      eventType: EventType.fromString(map['event_type'] as String),
      itemCollegeId: map['item_college_id'] as int?,
      scheduledDate: DateTime.parse(map['scheduled_date'] as String),
      scheduledStartTime: DateTime.parse(map['scheduled_start_time'] as String),
      scheduledEndTime: DateTime.parse(map['scheduled_end_time'] as String),
      isCompleted: (map['is_completed'] as int) == 1,
      completedDate: map['completed_date'] != null
          ? DateTime.parse(map['completed_date'] as String)
          : null,
      notes: map['notes'] as String?,
    );
  }

  CalendarEvent copyWith({
    int? id,
    String? name,
    EventType? eventType,
    int? itemCollegeId,
    DateTime? scheduledDate,
    DateTime? scheduledStartTime,
    DateTime? scheduledEndTime,
    bool? isCompleted,
    DateTime? completedDate,
    String? notes,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      name: name ?? this.name,
      eventType: eventType ?? this.eventType,
      itemCollegeId: itemCollegeId ?? this.itemCollegeId,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      scheduledStartTime: scheduledStartTime ?? this.scheduledStartTime,
      scheduledEndTime: scheduledEndTime ?? this.scheduledEndTime,
      isCompleted: isCompleted ?? this.isCompleted,
      completedDate: completedDate ?? this.completedDate,
      notes: notes ?? this.notes,
    );
  }
}
