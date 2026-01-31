import '../models/revision_slot.dart';
import '../models/item_college.dart';
import '../models/work_schedule.dart';
import '../models/difficulty.dart';
import '../models/difficulty_config.dart';
import '../database/database_helper.dart';

class RevisionScheduler {
  final DatabaseHelper _db = DatabaseHelper.instance;
  
  // Cache for difficulty configs to avoid repeated database calls
  final Map<Difficulty, DifficultyConfig> _configCache = {};

  // Get difficulty configuration from database (with caching)
  Future<DifficultyConfig> getDifficultyConfig(Difficulty difficulty) async {
    if (_configCache.containsKey(difficulty)) {
      return _configCache[difficulty]!;
    }
    
    final config = await _db.readDifficultyConfig(difficulty);
    if (config != null) {
      _configCache[difficulty] = config;
      return config;
    }
    
    // Fallback to default if not found in database
    return DifficultyConfig.getDefault(difficulty);
  }

  // Clear cache (call when configs are updated)
  void clearConfigCache() {
    _configCache.clear();
  }

  // Get first seen duration based on difficulty
  Future<Duration> getFirstSeenDuration(Difficulty difficulty) async {
    final config = await getDifficultyConfig(difficulty);
    return config.firstSeenDuration;
  }

  // Get revision duration based on slot order and difficulty
  Future<Duration> getRevisionDuration(int slotOrder, Difficulty difficulty) async {
    final config = await getDifficultyConfig(difficulty);
    if (slotOrder < 1 || slotOrder > config.revisionSlots.length) {
      return Duration.zero;
    }
    return config.revisionSlots[slotOrder - 1].duration;
  }

  // Get days until revision based on slot order and difficulty
  Future<int> getDaysUntilRevision(int slotOrder, Difficulty difficulty) async {
    final config = await getDifficultyConfig(difficulty);
    if (slotOrder < 1 || slotOrder > config.revisionSlots.length) {
      return 0;
    }
    return config.revisionSlots[slotOrder - 1].daysAfterFirstSeen;
  }

  // Get number of revision slots for a difficulty
  Future<int> getRevisionSlotCount(Difficulty difficulty) async {
    final config = await getDifficultyConfig(difficulty);
    return config.revisionSlots.length;
  }

  // Schedule all revisions for an item-college after first seen
  Future<void> scheduleRevisionsForItem(ItemCollege itemCollege) async {
    if (itemCollege.id == null || itemCollege.firstSeenDate == null) return;

    final difficulty = itemCollege.difficulty;
    final firstSeenDate = itemCollege.firstSeenDate!;
    final config = await getDifficultyConfig(difficulty);

    // Schedule all configured revision slots
    for (int i = 0; i < config.revisionSlots.length; i++) {
      final slotConfig = config.revisionSlots[i];
      await _scheduleRevision(
        itemCollege.id!,
        i + 1, // slot order (1-based)
        slotConfig.duration,
        slotConfig.daysAfterFirstSeen,
        firstSeenDate,
      );
    }
  }

  Future<void> _scheduleRevision(
    int itemCollegeId,
    int slotOrder,
    Duration duration,
    int daysAfterFirstSeen,
    DateTime referenceDate,
  ) async {
    if (duration == Duration.zero) return; // Skip if no time allocated

    final targetDate = referenceDate.add(Duration(days: daysAfterFirstSeen));

    // Find available slot
    final slot = await findAvailableSlot(targetDate, duration);
    if (slot != null) {
      // Use a dynamic revision type based on slot order
      final revisionType = _getRevisionTypeForSlot(slotOrder);
      await _db.createRevisionSlot(RevisionSlot(
        itemCollegeId: itemCollegeId,
        revisionType: revisionType,
        scheduledDate: slot['date']!,
        scheduledStartTime: slot['startTime']!,
        scheduledEndTime: slot['endTime']!,
      ));
    }
  }

  // Map slot order to revision type for backward compatibility
  RevisionType _getRevisionTypeForSlot(int slotOrder) {
    switch (slotOrder) {
      case 1:
        return RevisionType.revision1;
      case 2:
        return RevisionType.revision2Qcm;
      case 3:
        return RevisionType.revision3;
      case 4:
        return RevisionType.revision4;
      case 5:
        return RevisionType.revision5;
      case 6:
        return RevisionType.revision6;
      default:
        // For additional slots beyond 6, cycle through or use a generic type
        return RevisionType.values[(slotOrder % 6) + 2]; // Skip firstSeen and groupRevision
    }
  }

  // Find an available slot for a revision
  Future<Map<String, DateTime>?> findAvailableSlot(
    DateTime targetDate,
    Duration duration,
  ) async {
    // Start from target date and search forward
    DateTime searchDate = DateTime(targetDate.year, targetDate.month, targetDate.day);

    for (int i = 0; i < 30; i++) {
      // Search up to 30 days ahead
      final dayOfWeek = searchDate.weekday;
      final workSchedule = await _db.readWorkScheduleForDay(dayOfWeek);

      if (workSchedule != null) {
        final slot = await _findSlotInDay(searchDate, workSchedule, duration);
        if (slot != null) {
          return slot;
        }
      }

      searchDate = searchDate.add(const Duration(days: 1));
    }

    return null; // No slot found
  }

  Future<Map<String, DateTime>?> _findSlotInDay(
    DateTime date,
    WorkSchedule workSchedule,
    Duration duration,
  ) async {
    // Get existing revision slots for this day
    final existingSlots = await _db.readRevisionSlotsForDate(date);

    // Create time slots
    final dayStart = DateTime(
      date.year,
      date.month,
      date.day,
      workSchedule.startHour,
      workSchedule.startMinute,
    );

    final dayEnd = DateTime(
      date.year,
      date.month,
      date.day,
      workSchedule.endHour,
      workSchedule.endMinute,
    );

    // Try to find a slot
    DateTime currentTime = dayStart;

    while (currentTime.add(duration).isBefore(dayEnd) ||
        currentTime.add(duration).isAtSameMomentAs(dayEnd)) {
      final potentialEndTime = currentTime.add(duration);

      // Check if this slot overlaps with any existing slot
      bool hasOverlap = false;
      for (final existing in existingSlots) {
        if (_slotsOverlap(
          currentTime,
          potentialEndTime,
          existing.scheduledStartTime,
          existing.scheduledEndTime,
        )) {
          hasOverlap = true;
          // Jump to the end of this slot
          currentTime = existing.scheduledEndTime;
          break;
        }
      }

      if (!hasOverlap) {
        return {
          'date': date,
          'startTime': currentTime,
          'endTime': potentialEndTime,
        };
      }
    }

    return null;
  }

  bool _slotsOverlap(
    DateTime start1,
    DateTime end1,
    DateTime start2,
    DateTime end2,
  ) {
    return start1.isBefore(end2) && end1.isAfter(start2);
  }

  // Find available slots for new items (first 2 hours of days with >4 hours)
  Future<List<DateTime>> findNewItemSlots(DateTime startDate, int count) async {
    final List<DateTime> slots = [];
    DateTime searchDate = DateTime(startDate.year, startDate.month, startDate.day);

    while (slots.length < count) {
      final dayOfWeek = searchDate.weekday;
      final workSchedule = await _db.readWorkScheduleForDay(dayOfWeek);

      if (workSchedule != null && workSchedule.totalHours >= 4) {
        // Check if first 2 hours are available
        final slotStart = DateTime(
          searchDate.year,
          searchDate.month,
          searchDate.day,
          workSchedule.startHour,
          workSchedule.startMinute,
        );

        final slotEnd = slotStart.add(const Duration(hours: 2));

        // Check for conflicts
        final existingSlots = await _db.readRevisionSlotsForDate(searchDate);
        bool hasConflict = false;

        for (final existing in existingSlots) {
          if (_slotsOverlap(
            slotStart,
            slotEnd,
            existing.scheduledStartTime,
            existing.scheduledEndTime,
          )) {
            hasConflict = true;
            break;
          }
        }

        if (!hasConflict) {
          slots.add(slotStart);
        }
      }

      searchDate = searchDate.add(const Duration(days: 1));
    }

    return slots;
  }

  // ==================== NEW METHODS FOR SCHEDULING FUTURE ITEMS ====================

  /// Schedule a "first seen" for a future date at a specific time
  /// This will reschedule any conflicting revisions
  Future<void> scheduleFirstSeenForFuture({
    required ItemCollege itemCollege,
    required DateTime plannedDate,
    required DateTime startTime,
    required DateTime endTime,
    bool needsGroupRevision = false,
    DateTime? groupRevisionDate,
  }) async {
    if (itemCollege.id == null) return;

    // Find and reschedule any conflicting slots
    await _rescheduleConflictingSlots(startTime, endTime);

    // Create the first seen slot (not completed - it's planned for the future)
    await _db.createRevisionSlot(RevisionSlot(
      itemCollegeId: itemCollege.id!,
      revisionType: RevisionType.firstSeen,
      scheduledDate: plannedDate,
      scheduledStartTime: startTime,
      scheduledEndTime: endTime,
      isCompleted: false,
    ));

    // Update the ItemCollege with first seen date (planned)
    final updatedItemCollege = itemCollege.copyWith(
      firstSeenDate: plannedDate,
      needsGroupRevision: needsGroupRevision,
      groupRevisionDate: groupRevisionDate,
    );
    await _db.updateItemCollege(updatedItemCollege);

    // Schedule group revision if needed
    if (needsGroupRevision && groupRevisionDate != null) {
      final groupSlot = await findAvailableSlot(
        groupRevisionDate,
        const Duration(hours: 2),
      );

      if (groupSlot != null) {
        await _db.createRevisionSlot(RevisionSlot(
          itemCollegeId: itemCollege.id!,
          revisionType: RevisionType.groupRevision,
          scheduledDate: groupSlot['date']!,
          scheduledStartTime: groupSlot['startTime']!,
          scheduledEndTime: groupSlot['endTime']!,
        ));
      }
    }

    // Schedule all automatic revisions from the planned first seen date
    await scheduleRevisionsForItem(updatedItemCollege);
  }

  /// Reschedule conflicting slots when a new item is scheduled
  Future<void> _rescheduleConflictingSlots(DateTime newStart, DateTime newEnd) async {
    final conflictingSlots = await _db.getConflictingSlots(newStart, newEnd);
    
    for (final slot in conflictingSlots) {
      if (slot.isCompleted) continue; // Don't touch completed slots
      
      // Find a new slot for this revision
      final duration = slot.scheduledEndTime.difference(slot.scheduledStartTime);
      
      // Start searching from the same day, after the new slot ends
      DateTime searchStart = newEnd;
      
      // Try to find a slot on the same day first
      final sameDaySlot = await _findSlotAfterTime(
        slot.scheduledDate,
        searchStart,
        duration,
      );
      
      if (sameDaySlot != null) {
        // Found a slot on the same day
        await _db.updateRevisionSlot(slot.copyWith(
          scheduledStartTime: sameDaySlot['startTime'],
          scheduledEndTime: sameDaySlot['endTime'],
        ));
      } else {
        // Need to find a slot on another day - add to overflow
        await _handleOverflowSlot(slot, duration);
      }
    }
  }

  /// Find a slot after a specific time on a given day
  Future<Map<String, DateTime>?> _findSlotAfterTime(
    DateTime date,
    DateTime afterTime,
    Duration duration,
  ) async {
    final dayOfWeek = date.weekday;
    final workSchedule = await _db.readWorkScheduleForDay(dayOfWeek);
    if (workSchedule == null) return null;

    final dayEnd = DateTime(
      date.year,
      date.month,
      date.day,
      workSchedule.endHour,
      workSchedule.endMinute,
    );

    // Get existing slots for the day
    final existingSlots = await _db.readRevisionSlotsForDate(date);
    
    // Start from the given time
    DateTime currentTime = afterTime;

    while (currentTime.add(duration).isBefore(dayEnd) ||
        currentTime.add(duration).isAtSameMomentAs(dayEnd)) {
      final potentialEndTime = currentTime.add(duration);

      bool hasOverlap = false;
      for (final existing in existingSlots) {
        if (_slotsOverlap(
          currentTime,
          potentialEndTime,
          existing.scheduledStartTime,
          existing.scheduledEndTime,
        )) {
          hasOverlap = true;
          currentTime = existing.scheduledEndTime;
          break;
        }
      }

      if (!hasOverlap) {
        return {
          'date': date,
          'startTime': currentTime,
          'endTime': potentialEndTime,
        };
      }
    }

    return null;
  }

  /// Handle slots that overflow from a day - spread over next 10 days
  Future<void> _handleOverflowSlot(RevisionSlot slot, Duration duration) async {
    final newSlot = await findAvailableSlot(
      slot.scheduledDate.add(const Duration(days: 1)),
      duration,
    );
    
    if (newSlot != null) {
      await _db.updateRevisionSlot(slot.copyWith(
        scheduledDate: newSlot['date'],
        scheduledStartTime: newSlot['startTime'],
        scheduledEndTime: newSlot['endTime'],
      ));
    }
    // If no slot found, the revision remains in the "unfinished" list
  }

  /// Rebalance all revisions for a date - prioritize most recent items first
  /// This is called when there's too much scheduled for a day
  Future<void> rebalanceDay(DateTime date) async {
    final slotsWithDetails = await _db.getRevisionSlotsWithDetailsInRange(date, date);
    
    // Sort by first_seen_date descending (most recent first)
    slotsWithDetails.sort((a, b) {
      final aDate = a['first_seen_date'] != null 
          ? DateTime.parse(a['first_seen_date'] as String) 
          : DateTime(1900);
      final bDate = b['first_seen_date'] != null 
          ? DateTime.parse(b['first_seen_date'] as String) 
          : DateTime(1900);
      return bDate.compareTo(aDate); // Most recent first
    });

    // Get work schedule for the day
    final workSchedule = await _db.readWorkScheduleForDay(date.weekday);
    if (workSchedule == null) return;

    final dayStart = DateTime(
      date.year,
      date.month,
      date.day,
      workSchedule.startHour,
      workSchedule.startMinute,
    );
    final dayEnd = DateTime(
      date.year,
      date.month,
      date.day,
      workSchedule.endHour,
      workSchedule.endMinute,
    );

    final availableTime = dayEnd.difference(dayStart);
    Duration usedTime = Duration.zero;
    
    final List<RevisionSlot> fittingSlots = [];
    final List<RevisionSlot> overflowSlots = [];

    for (final slotData in slotsWithDetails) {
      final slot = RevisionSlot.fromMap(slotData);
      if (slot.isCompleted) {
        fittingSlots.add(slot); // Keep completed slots
        usedTime += slot.duration;
        continue;
      }

      if (usedTime + slot.duration <= availableTime) {
        fittingSlots.add(slot);
        usedTime += slot.duration;
      } else {
        overflowSlots.add(slot);
      }
    }

    // Reschedule fitting slots to fill the day properly
    DateTime currentTime = dayStart;
    for (final slot in fittingSlots) {
      if (!slot.isCompleted) {
        final newEndTime = currentTime.add(slot.duration);
        await _db.updateRevisionSlot(slot.copyWith(
          scheduledStartTime: currentTime,
          scheduledEndTime: newEndTime,
        ));
        currentTime = newEndTime;
      } else {
        currentTime = slot.scheduledEndTime;
      }
    }

    // Handle overflow slots - spread over next 10 days
    await _spreadOverflowSlots(overflowSlots, date);
  }

  /// Spread overflow slots over the next 10 days, prioritizing recent items
  Future<void> _spreadOverflowSlots(List<RevisionSlot> overflowSlots, DateTime fromDate) async {
    for (final slot in overflowSlots) {
      // Search for available slot in next 10 days
      final duration = slot.duration;
      
      for (int i = 1; i <= 10; i++) {
        final searchDate = fromDate.add(Duration(days: i));
        final newSlot = await _findSlotInDayWithSchedule(searchDate, duration);
        
        if (newSlot != null) {
          await _db.updateRevisionSlot(slot.copyWith(
            scheduledDate: newSlot['date'],
            scheduledStartTime: newSlot['startTime'],
            scheduledEndTime: newSlot['endTime'],
          ));
          break;
        }
      }
      // If no slot found in 10 days, it stays in unfinished list
    }
  }

  Future<Map<String, DateTime>?> _findSlotInDayWithSchedule(
    DateTime date,
    Duration duration,
  ) async {
    final workSchedule = await _db.readWorkScheduleForDay(date.weekday);
    if (workSchedule == null) return null;
    return await _findSlotInDay(date, workSchedule, duration);
  }

  /// Update difficulty for an item and reschedule all its revisions
  Future<void> updateDifficultyAndReschedule(ItemCollege itemCollege, Difficulty newDifficulty) async {
    if (itemCollege.id == null) return;

    // Update the difficulty
    final updatedItemCollege = itemCollege.copyWith(difficulty: newDifficulty);
    await _db.updateItemCollege(updatedItemCollege);

    // Delete all non-completed revisions for this item
    await _db.deleteNonCompletedRevisionsForItemCollege(itemCollege.id!);

    // Reschedule all revisions with new durations
    if (updatedItemCollege.firstSeenDate != null) {
      await scheduleRevisionsForItem(updatedItemCollege);
    }
  }

  /// Get available time slots for a given date (for UI picker)
  Future<List<Map<String, DateTime>>> getAvailableTimeSlotsForDate(
    DateTime date,
    Duration requiredDuration,
  ) async {
    final List<Map<String, DateTime>> availableSlots = [];
    final workSchedule = await _db.readWorkScheduleForDay(date.weekday);
    if (workSchedule == null) return availableSlots;

    final existingSlots = await _db.readRevisionSlotsForDate(date);
    
    final dayStart = DateTime(
      date.year,
      date.month,
      date.day,
      workSchedule.startHour,
      workSchedule.startMinute,
    );
    final dayEnd = DateTime(
      date.year,
      date.month,
      date.day,
      workSchedule.endHour,
      workSchedule.endMinute,
    );

    DateTime currentTime = dayStart;

    while (currentTime.add(requiredDuration).isBefore(dayEnd) ||
        currentTime.add(requiredDuration).isAtSameMomentAs(dayEnd)) {
      final potentialEndTime = currentTime.add(requiredDuration);

      bool hasOverlap = false;
      for (final existing in existingSlots) {
        if (_slotsOverlap(
          currentTime,
          potentialEndTime,
          existing.scheduledStartTime,
          existing.scheduledEndTime,
        )) {
          hasOverlap = true;
          currentTime = existing.scheduledEndTime;
          break;
        }
      }

      if (!hasOverlap) {
        availableSlots.add({
          'startTime': currentTime,
          'endTime': potentialEndTime,
        });
        currentTime = currentTime.add(const Duration(minutes: 30)); // 30 min increments
      }
    }

    return availableSlots;
  }

  /// Check if a specific time slot is available
  Future<bool> isSlotAvailable(DateTime startTime, DateTime endTime) async {
    final conflicts = await _db.getConflictingSlots(startTime, endTime);
    return conflicts.isEmpty;
  }
}
