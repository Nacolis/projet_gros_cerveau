enum RevisionType {
  lecture('Lecture'),
  qcm('QCM'),
  dossier('Dossier');

  const RevisionType(this.label);
  final String label;

  static RevisionType fromString(String value) {
    return RevisionType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => RevisionType.lecture,
    );
  }
}

class RevisionSlot {
  final int? id;
  final int itemCollegeId;
  final RevisionType revisionType;
  final DateTime scheduledDate;
  final DateTime scheduledStartTime;
  final DateTime scheduledEndTime;
  final bool isCompleted;
  final DateTime? completedDate;
  final String? notes;

  RevisionSlot({
    this.id,
    required this.itemCollegeId,
    required this.revisionType,
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
      'item_college_id': itemCollegeId,
      'revision_type': revisionType.name,
      'scheduled_date': scheduledDate.toIso8601String(),
      'scheduled_start_time': scheduledStartTime.toIso8601String(),
      'scheduled_end_time': scheduledEndTime.toIso8601String(),
      'is_completed': isCompleted ? 1 : 0,
      'completed_date': completedDate?.toIso8601String(),
      'notes': notes,
    };
  }

  factory RevisionSlot.fromMap(Map<String, dynamic> map) {
    return RevisionSlot(
      id: map['id'] as int?,
      itemCollegeId: map['item_college_id'] as int,
      revisionType: RevisionType.fromString(map['revision_type'] as String),
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

  RevisionSlot copyWith({
    int? id,
    int? itemCollegeId,
    RevisionType? revisionType,
    DateTime? scheduledDate,
    DateTime? scheduledStartTime,
    DateTime? scheduledEndTime,
    bool? isCompleted,
    DateTime? completedDate,
    String? notes,
  }) {
    return RevisionSlot(
      id: id ?? this.id,
      itemCollegeId: itemCollegeId ?? this.itemCollegeId,
      revisionType: revisionType ?? this.revisionType,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      scheduledStartTime: scheduledStartTime ?? this.scheduledStartTime,
      scheduledEndTime: scheduledEndTime ?? this.scheduledEndTime,
      isCompleted: isCompleted ?? this.isCompleted,
      completedDate: completedDate ?? this.completedDate,
      notes: notes ?? this.notes,
    );
  }
}
