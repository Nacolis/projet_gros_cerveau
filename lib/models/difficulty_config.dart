import 'difficulty.dart';

/// Configuration for a revision slot within a difficulty level
class RevisionSlotConfig {
  final int? id;
  final int difficultyConfigId;
  final int order; // Order of this revision slot (1, 2, 3, etc.)
  final int daysAfterFirstSeen; // Number of days after first seen (e.g., 1 for J+1)
  final int durationMinutes; // Duration in minutes

  RevisionSlotConfig({
    this.id,
    required this.difficultyConfigId,
    required this.order,
    required this.daysAfterFirstSeen,
    required this.durationMinutes,
  });

  Duration get duration => Duration(minutes: durationMinutes);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'difficulty_config_id': difficultyConfigId,
      'slot_order': order,
      'days_after_first_seen': daysAfterFirstSeen,
      'duration_minutes': durationMinutes,
    };
  }

  factory RevisionSlotConfig.fromMap(Map<String, dynamic> map) {
    return RevisionSlotConfig(
      id: map['id'] as int?,
      difficultyConfigId: map['difficulty_config_id'] as int,
      order: map['slot_order'] as int,
      daysAfterFirstSeen: map['days_after_first_seen'] as int,
      durationMinutes: map['duration_minutes'] as int,
    );
  }

  RevisionSlotConfig copyWith({
    int? id,
    int? difficultyConfigId,
    int? order,
    int? daysAfterFirstSeen,
    int? durationMinutes,
  }) {
    return RevisionSlotConfig(
      id: id ?? this.id,
      difficultyConfigId: difficultyConfigId ?? this.difficultyConfigId,
      order: order ?? this.order,
      daysAfterFirstSeen: daysAfterFirstSeen ?? this.daysAfterFirstSeen,
      durationMinutes: durationMinutes ?? this.durationMinutes,
    );
  }
}

/// Configuration for a difficulty level (Facile, Moyen, Difficile)
class DifficultyConfig {
  final int? id;
  final Difficulty difficulty;
  final int firstSeenDurationMinutes; // Duration in minutes for first seen
  final List<RevisionSlotConfig> revisionSlots;

  DifficultyConfig({
    this.id,
    required this.difficulty,
    required this.firstSeenDurationMinutes,
    this.revisionSlots = const [],
  });

  Duration get firstSeenDuration => Duration(minutes: firstSeenDurationMinutes);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'difficulty': difficulty.name,
      'first_seen_duration_minutes': firstSeenDurationMinutes,
    };
  }

  factory DifficultyConfig.fromMap(Map<String, dynamic> map, [List<RevisionSlotConfig>? slots]) {
    return DifficultyConfig(
      id: map['id'] as int?,
      difficulty: Difficulty.fromString(map['difficulty'] as String),
      firstSeenDurationMinutes: map['first_seen_duration_minutes'] as int,
      revisionSlots: slots ?? [],
    );
  }

  DifficultyConfig copyWith({
    int? id,
    Difficulty? difficulty,
    int? firstSeenDurationMinutes,
    List<RevisionSlotConfig>? revisionSlots,
  }) {
    return DifficultyConfig(
      id: id ?? this.id,
      difficulty: difficulty ?? this.difficulty,
      firstSeenDurationMinutes: firstSeenDurationMinutes ?? this.firstSeenDurationMinutes,
      revisionSlots: revisionSlots ?? this.revisionSlots,
    );
  }

  /// Get default configuration for a difficulty level
  static DifficultyConfig getDefault(Difficulty difficulty) {
    switch (difficulty) {
      case Difficulty.easy:
        return DifficultyConfig(
          difficulty: difficulty,
          firstSeenDurationMinutes: 90, // 1h30
          revisionSlots: [],
        );
      case Difficulty.medium:
        return DifficultyConfig(
          difficulty: difficulty,
          firstSeenDurationMinutes: 120, // 2h
          revisionSlots: [],
        );
      case Difficulty.hard:
        return DifficultyConfig(
          difficulty: difficulty,
          firstSeenDurationMinutes: 180, // 3h
          revisionSlots: [],
        );
    }
  }

  /// Get default revision slots for a difficulty level
  static List<RevisionSlotConfig> getDefaultRevisionSlots(int configId, Difficulty difficulty) {
    switch (difficulty) {
      case Difficulty.easy:
        return [
          RevisionSlotConfig(difficultyConfigId: configId, order: 1, daysAfterFirstSeen: 1, durationMinutes: 60), // J+1: 1h
          RevisionSlotConfig(difficultyConfigId: configId, order: 2, daysAfterFirstSeen: 7, durationMinutes: 30), // J+7: 30min
          RevisionSlotConfig(difficultyConfigId: configId, order: 3, daysAfterFirstSeen: 50, durationMinutes: 60), // J+50: 1h
        ];
      case Difficulty.medium:
        return [
          RevisionSlotConfig(difficultyConfigId: configId, order: 1, daysAfterFirstSeen: 1, durationMinutes: 120), // J+1: 2h
          RevisionSlotConfig(difficultyConfigId: configId, order: 2, daysAfterFirstSeen: 7, durationMinutes: 60), // J+7: 1h
          RevisionSlotConfig(difficultyConfigId: configId, order: 3, daysAfterFirstSeen: 20, durationMinutes: 60), // J+20: 1h
          RevisionSlotConfig(difficultyConfigId: configId, order: 4, daysAfterFirstSeen: 35, durationMinutes: 60), // J+35: 1h
        ];
      case Difficulty.hard:
        return [
          RevisionSlotConfig(difficultyConfigId: configId, order: 1, daysAfterFirstSeen: 1, durationMinutes: 150), // J+1: 2h30
          RevisionSlotConfig(difficultyConfigId: configId, order: 2, daysAfterFirstSeen: 7, durationMinutes: 90), // J+7: 1h30
          RevisionSlotConfig(difficultyConfigId: configId, order: 3, daysAfterFirstSeen: 20, durationMinutes: 90), // J+20: 1h30
          RevisionSlotConfig(difficultyConfigId: configId, order: 4, daysAfterFirstSeen: 35, durationMinutes: 90), // J+35: 1h30
          RevisionSlotConfig(difficultyConfigId: configId, order: 5, daysAfterFirstSeen: 70, durationMinutes: 90), // J+70: 1h30
        ];
    }
  }
}
