import 'difficulty.dart';

class ItemCollege {
  final int? id;
  final int itemId;
  final int collegeId;
  final Difficulty difficulty;
  final DateTime? firstSeenDate;
  final bool needsGroupRevision;
  final DateTime? groupRevisionDate;

  ItemCollege({
    this.id,
    required this.itemId,
    required this.collegeId,
    this.difficulty = Difficulty.medium,
    this.firstSeenDate,
    this.needsGroupRevision = false,
    this.groupRevisionDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'item_id': itemId,
      'college_id': collegeId,
      'difficulty': difficulty.name,
      'first_seen_date': firstSeenDate?.toIso8601String(),
      'needs_group_revision': needsGroupRevision ? 1 : 0,
      'group_revision_date': groupRevisionDate?.toIso8601String(),
    };
  }

  factory ItemCollege.fromMap(Map<String, dynamic> map) {
    return ItemCollege(
      id: map['id'] as int?,
      itemId: map['item_id'] as int,
      collegeId: map['college_id'] as int,
      difficulty: Difficulty.fromString(map['difficulty'] as String),
      firstSeenDate: map['first_seen_date'] != null
          ? DateTime.parse(map['first_seen_date'] as String)
          : null,
      needsGroupRevision: (map['needs_group_revision'] as int) == 1,
      groupRevisionDate: map['group_revision_date'] != null
          ? DateTime.parse(map['group_revision_date'] as String)
          : null,
    );
  }

  ItemCollege copyWith({
    int? id,
    int? itemId,
    int? collegeId,
    Difficulty? difficulty,
    DateTime? firstSeenDate,
    bool? needsGroupRevision,
    DateTime? groupRevisionDate,
  }) {
    return ItemCollege(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      collegeId: collegeId ?? this.collegeId,
      difficulty: difficulty ?? this.difficulty,
      firstSeenDate: firstSeenDate ?? this.firstSeenDate,
      needsGroupRevision: needsGroupRevision ?? this.needsGroupRevision,
      groupRevisionDate: groupRevisionDate ?? this.groupRevisionDate,
    );
  }
}
