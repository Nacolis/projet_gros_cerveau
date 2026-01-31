import '../models/revision_slot.dart';
import '../models/work_schedule.dart';
import '../database/database_helper.dart';

/// Simplified RevisionScheduler for manual revision management
/// Provides utility methods for time slot management and day rebalancing
class RevisionScheduler {
  final DatabaseHelper _db = DatabaseHelper.instance;

  /// Find an available slot for a revision starting from targetDate
  Future<Map<String, DateTime>?> findAvailableSlot(
    DateTime targetDate,
    Duration duration,
  ) async {
    DateTime searchDate = DateTime(targetDate.year, targetDate.month, targetDate.day);

    for (int i = 0; i < 30; i++) {
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

    return null;
  }

  Future<Map<String, DateTime>?> _findSlotInDay(
    DateTime date,
    WorkSchedule workSchedule,
    Duration duration,
  ) async {
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

  bool _slotsOverlap(
    DateTime start1,
    DateTime end1,
    DateTime start2,
    DateTime end2,
  ) {
    return start1.isBefore(end2) && end1.isAfter(start2);
  }

  /// Rebalance all revisions for a date when overscheduled
  /// Keeps completed slots, spreads overflow to next days
  Future<void> rebalanceDay(DateTime date) async {
    final slotsWithDetails = await _db.getRevisionSlotsWithDetailsInRange(date, date);
    
    // Sort by creation date (oldest first - FIFO)
    slotsWithDetails.sort((a, b) {
      final slotA = RevisionSlot.fromMap(a);
      final slotB = RevisionSlot.fromMap(b);
      return (slotA.id ?? 0).compareTo(slotB.id ?? 0);
    });

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
        fittingSlots.add(slot);
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

  Future<void> _spreadOverflowSlots(List<RevisionSlot> overflowSlots, DateTime fromDate) async {
    for (final slot in overflowSlots) {
      final duration = slot.duration;
      
      for (int i = 1; i <= 10; i++) {
        final searchDate = fromDate.add(Duration(days: i));
        final workSchedule = await _db.readWorkScheduleForDay(searchDate.weekday);
        if (workSchedule == null) continue;
        
        final newSlot = await _findSlotInDay(searchDate, workSchedule, duration);
        
        if (newSlot != null) {
          await _db.updateRevisionSlot(slot.copyWith(
            scheduledDate: newSlot['date'],
            scheduledStartTime: newSlot['startTime'],
            scheduledEndTime: newSlot['endTime'],
          ));
          break;
        }
      }
    }
  }

  /// Get available time for a date (total work hours minus scheduled time)
  Future<Duration> getAvailableTimeForDate(DateTime date) async {
    final workSchedule = await _db.readWorkScheduleForDay(date.weekday);
    if (workSchedule == null) return Duration.zero;

    final existingSlots = await _db.readRevisionSlotsForDate(date);
    
    Duration totalScheduled = Duration.zero;
    for (final slot in existingSlots) {
      if (!slot.isCompleted) {
        totalScheduled += slot.duration;
      }
    }

    final workDuration = Duration(
      hours: workSchedule.endHour - workSchedule.startHour,
      minutes: workSchedule.endMinute - workSchedule.startMinute,
    );

    final available = workDuration - totalScheduled;
    return available.isNegative ? Duration.zero : available;
  }

  /// Check if a specific time slot is available
  Future<bool> isSlotAvailable(DateTime startTime, DateTime endTime) async {
    final conflicts = await _db.getConflictingSlots(startTime, endTime);
    return conflicts.isEmpty;
  }
}
