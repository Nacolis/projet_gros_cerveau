import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/revision_slot.dart';
import '../models/calendar_event.dart';
import '../models/work_schedule.dart';
import '../theme/app_theme.dart';
import '../services/revision_scheduler.dart';
import '../widgets/common_widgets.dart';
import '../utils/college_icons.dart';
import 'item_detail_screen.dart';
import 'add_calendar_entry_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final RevisionScheduler _scheduler = RevisionScheduler();
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _revisionsForDay = [];
  List<Map<String, dynamic>> _eventsForDay = [];
  WorkSchedule? _workSchedule;
  Duration _totalScheduledTime = Duration.zero;
  bool _isRebalancing = false;

  @override
  void initState() {
    super.initState();
    _loadRevisionsForDay();
  }

  Future<void> _loadRevisionsForDay() async {
    final revisions = await _db.getRevisionSlotsWithDetails();
    final events = await _db.getCalendarEventsWithDetailsForDate(_selectedDate);
    final workSchedule = await _db.readWorkScheduleForDay(
      _selectedDate.weekday,
    );

    Duration totalTime = Duration.zero;
    final dayRevisions = revisions.where((rev) {
      final revSlot = RevisionSlot.fromMap(rev);
      final isToday =
          revSlot.scheduledDate.year == _selectedDate.year &&
          revSlot.scheduledDate.month == _selectedDate.month &&
          revSlot.scheduledDate.day == _selectedDate.day;
      if (isToday && !revSlot.isCompleted) {
        totalTime += revSlot.duration;
      }
      return isToday;
    }).toList();

    // Add calendar events time to total
    for (final event in events) {
      final calEvent = CalendarEvent.fromMap(event);
      if (!calEvent.isCompleted) {
        totalTime += calEvent.duration;
      }
    }

    setState(() {
      _revisionsForDay = dayRevisions;
      _eventsForDay = events;
      _workSchedule = workSchedule;
      _totalScheduledTime = totalTime;
    });
  }

  Duration get _availableTime {
    if (_workSchedule == null) return Duration.zero;
    return Duration(
      hours: _workSchedule!.endHour - _workSchedule!.startHour,
      minutes: _workSchedule!.endMinute - _workSchedule!.startMinute,
    );
  }

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddCalendarEntryScreen(initialDate: _selectedDate),
            ),
          );
          if (result == true) {
            _loadRevisionsForDay();
          }
        },
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add),
        label: Text(
          'Ajouter',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Date picker card
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundCard,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildNavButton(
                          icon: Icons.chevron_left,
                          onPressed: () {
                            setState(() {
                              _selectedDate = _selectedDate.subtract(
                                const Duration(days: 1),
                              );
                            });
                            _loadRevisionsForDay();
                          },
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _selectedDate,
                                firstDate: DateTime(2024),
                                lastDate: DateTime(2030),
                                builder: (context, child) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: ColorScheme.light(
                                        primary: AppTheme.primary,
                                        onPrimary: Colors.white,
                                        surface: AppTheme.backgroundCard,
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (picked != null) {
                                setState(() {
                                  _selectedDate = picked;
                                });
                                _loadRevisionsForDay();
                              }
                            },
                            child: Column(
                              children: [
                                if (_isToday)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    margin: const EdgeInsets.only(bottom: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      "Aujourd'hui",
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                Text(
                                  DateFormat(
                                    'EEEE',
                                    'fr_FR',
                                  ).format(_selectedDate),
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: AppTheme.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  DateFormat(
                                    'd MMMM yyyy',
                                    'fr_FR',
                                  ).format(_selectedDate),
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        _buildNavButton(
                          icon: Icons.chevron_right,
                          onPressed: () {
                            setState(() {
                              _selectedDate = _selectedDate.add(
                                const Duration(days: 1),
                              );
                            });
                            _loadRevisionsForDay();
                          },
                        ),
                      ],
                    ),

                    // Quick day navigation
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 64,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: 30,
                        itemBuilder: (context, index) {
                          final date = DateTime.now().add(
                            Duration(days: index - 2),
                          );
                          final isSelected =
                              date.year == _selectedDate.year &&
                              date.month == _selectedDate.month &&
                              date.day == _selectedDate.day;

                          return GestureDetector(
                            onTap: () {
                              setState(() => _selectedDate = date);
                              _loadRevisionsForDay();
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 48,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.primary
                                    : AppTheme.surfaceLight,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    DateFormat('E', 'fr_FR')
                                        .format(date)
                                        .substring(0, 2)
                                        .toUpperCase(),
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? Colors.white.withValues(alpha: 0.8)
                                          : AppTheme.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${date.day}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected
                                          ? Colors.white
                                          : AppTheme.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Time summary card
              if (_workSchedule != null &&
                  (_revisionsForDay.isNotEmpty || _eventsForDay.isNotEmpty))
                _buildTimeSummaryCard(),

              // Events and Revisions list
              Expanded(
                child: (_revisionsForDay.isEmpty && _eventsForDay.isEmpty)
                    ? EmptyState(
                        icon: Icons.event_busy,
                        title: 'Aucune activité prévue',
                        subtitle: 'Ajoutez une révision ou un événement',
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                        children: [
                          // Calendar events section
                          if (_eventsForDay.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8, top: 4),
                              child: Text(
                                'Événements',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ),
                            ..._eventsForDay.map((event) {
                              final calEvent = CalendarEvent.fromMap(event);
                              return _buildCalendarEventCard(event, calEvent);
                            }),
                            const SizedBox(height: 16),
                          ],

                          // Revisions section
                          if (_revisionsForDay.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8, top: 4),
                              child: Text(
                                'Révisions',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ),
                            ..._revisionsForDay.map((rev) {
                              final revSlot = RevisionSlot.fromMap(rev);
                              return _buildRevisionCard(rev, revSlot);
                            }),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: AppTheme.surfaceLight,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: AppTheme.textSecondary, size: 24),
        ),
      ),
    );
  }

  Widget _buildTimeSummaryCard() {
    final scheduledMinutes = _totalScheduledTime.inMinutes;
    final availableMinutes = _availableTime.inMinutes;
    final percentage = availableMinutes > 0
        ? (scheduledMinutes / availableMinutes).clamp(0.0, 1.5)
        : 0.0;

    final isOverScheduled = scheduledMinutes > availableMinutes;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isOverScheduled
            ? AppTheme.error.withValues(alpha: 0.08)
            : AppTheme.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOverScheduled
              ? AppTheme.error.withValues(alpha: 0.3)
              : AppTheme.surfaceMedium,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                isOverScheduled ? Icons.warning_amber_rounded : Icons.schedule,
                color: isOverScheduled ? AppTheme.error : AppTheme.primary,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${_formatDuration(_totalScheduledTime)} / ${_formatDuration(_availableTime)}',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: isOverScheduled
                        ? AppTheme.error
                        : AppTheme.textPrimary,
                  ),
                ),
              ),
              if (isOverScheduled)
                TextButton.icon(
                  onPressed: _isRebalancing ? null : _rebalanceDay,
                  icon: _isRebalancing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_fix_high, size: 18),
                  label: Text(_isRebalancing ? '...' : 'Réorganiser'),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percentage.clamp(0.0, 1.0),
              backgroundColor: AppTheme.surfaceMedium,
              valueColor: AlwaysStoppedAnimation<Color>(
                isOverScheduled ? AppTheme.error : AppTheme.primary,
              ),
              minHeight: 8,
            ),
          ),
          if (isOverScheduled)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Dépassement de ${_formatDuration(_totalScheduledTime - _availableTime)}',
                style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.error),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0 && minutes > 0) {
      return '${hours}h${minutes.toString().padLeft(2, '0')}';
    } else if (hours > 0) {
      return '${hours}h';
    } else {
      return '${minutes}min';
    }
  }

  Future<void> _rebalanceDay() async {
    setState(() => _isRebalancing = true);

    try {
      await _scheduler.rebalanceDay(_selectedDate);
      await _loadRevisionsForDay();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Journée réorganisée !'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      setState(() => _isRebalancing = false);
    }
  }

  Widget _buildRevisionCard(Map<String, dynamic> rev, RevisionSlot revSlot) {
    final itemName = rev['item_name'] as String;
    final collegeName = rev['college_name'] as String? ?? '';
    final displayName = itemName.length > 45
        ? '${itemName.substring(0, 45)}...'
        : itemName;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
        border: revSlot.isCompleted
            ? Border.all(color: AppTheme.success.withValues(alpha: 0.3))
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showEventDetails(rev, revSlot),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Time badge
                Container(
                  width: 56,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.getRevisionTypeColor(
                      revSlot.revisionType.name,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        DateFormat('HH:mm').format(revSlot.scheduledStartTime),
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Container(
                        width: 12,
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.5),
                        margin: const EdgeInsets.symmetric(vertical: 3),
                      ),
                      Text(
                        DateFormat('HH:mm').format(revSlot.scheduledEndTime),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 14),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              displayName,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                                decoration: revSlot.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          RevisionTypeBadge(
                            revisionType: revSlot.revisionType.name,
                            label: revSlot.revisionType.label,
                          ),
                          const SizedBox(width: 8),
                          if (collegeName.isNotEmpty)
                            Expanded(
                              child: Row(
                                children: [
                                  CollegeIcons.buildIcon(
                                    collegeName,
                                    size: 14,
                                    color: AppTheme.textMuted,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      collegeName.length > 15
                                          ? '${collegeName.substring(0, 15)}...'
                                          : collegeName,
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: AppTheme.textMuted,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Complete button
                _buildCompleteButton(revSlot),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarEventCard(
    Map<String, dynamic> eventData,
    CalendarEvent calEvent,
  ) {
    final eventColor = _getEventTypeColor(calEvent.eventType);
    final itemName = eventData['item_name'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
        border: calEvent.isCompleted
            ? Border.all(color: AppTheme.success.withValues(alpha: 0.3))
            : Border.all(color: eventColor.withValues(alpha: 0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showCalendarEventDetails(eventData, calEvent),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Time badge
                Container(
                  width: 56,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: eventColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        DateFormat('HH:mm').format(calEvent.scheduledStartTime),
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Container(
                        width: 12,
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.5),
                        margin: const EdgeInsets.symmetric(vertical: 3),
                      ),
                      Text(
                        DateFormat('HH:mm').format(calEvent.scheduledEndTime),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 14),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        calEvent.name,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                          decoration: calEvent.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: eventColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getEventTypeIcon(calEvent.eventType),
                                  size: 12,
                                  color: eventColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  calEvent.eventType.label,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: eventColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (itemName != null) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                itemName.length > 20
                                    ? '${itemName.substring(0, 20)}...'
                                    : itemName,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppTheme.textMuted,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Complete button
                _buildEventCompleteButton(calEvent),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEventCompleteButton(CalendarEvent calEvent) {
    if (calEvent.isCompleted) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.success.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.check_circle,
          color: AppTheme.success,
          size: 24,
        ),
      );
    }

    final eventColor = _getEventTypeColor(calEvent.eventType);
    return Material(
      color: AppTheme.surfaceLight,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: () => _markEventAsCompleted(calEvent),
        customBorder: const CircleBorder(),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: Icon(Icons.check_circle_outline, color: eventColor, size: 24),
        ),
      ),
    );
  }

  Color _getEventTypeColor(EventType type) {
    switch (type) {
      case EventType.exam:
        return const Color(0xFFE53935);
      case EventType.whiteExam:
        return const Color(0xFFFF9800);
      case EventType.masterclass:
        return const Color(0xFF9C27B0);
      case EventType.other:
        return const Color(0xFF607D8B);
    }
  }

  IconData _getEventTypeIcon(EventType type) {
    switch (type) {
      case EventType.exam:
        return Icons.assignment;
      case EventType.whiteExam:
        return Icons.assignment_outlined;
      case EventType.masterclass:
        return Icons.school;
      case EventType.other:
        return Icons.event;
    }
  }

  Future<void> _markEventAsCompleted(CalendarEvent event) async {
    await _db.updateCalendarEvent(
      event.copyWith(isCompleted: true, completedDate: DateTime.now()),
    );
    _loadRevisionsForDay();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Événement complété !'),
          backgroundColor: AppTheme.success,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _unmarkEventCompleted(CalendarEvent event) async {
    await _db.updateCalendarEvent(
      event.copyWith(isCompleted: false, completedDate: null),
    );
    _loadRevisionsForDay();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Événement non complété'),
          backgroundColor: AppTheme.info,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showCalendarEventDetails(
    Map<String, dynamic> eventData,
    CalendarEvent calEvent,
  ) {
    final eventColor = _getEventTypeColor(calEvent.eventType);
    final itemName = eventData['item_name'] as String?;
    final itemNumber = eventData['item_number'] as int?;
    final collegeName = eventData['college_name'] as String?;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppTheme.backgroundCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const BottomSheetHandle(),
                  const SizedBox(height: 12),

                  // Header with type badge and status
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: eventColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getEventTypeIcon(calEvent.eventType),
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              calEvent.eventType.label,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (calEvent.isCompleted)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.success,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.check,
                                size: 16,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Complété',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      // Edit button
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () async {
                          Navigator.pop(context);
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddCalendarEntryScreen(
                                existingEvent: calEvent,
                                existingEventData: eventData,
                              ),
                            ),
                          );
                          if (result == true) {
                            _loadRevisionsForDay();
                          }
                        },
                      ),
                      // Delete button
                      IconButton(
                        icon: const Icon(
                          Icons.delete,
                          size: 20,
                          color: AppTheme.error,
                        ),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Supprimer l\'événement ?'),
                              content: const Text(
                                'Cette action est irréversible.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Annuler'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppTheme.error,
                                  ),
                                  child: const Text('Supprimer'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await _db.deleteCalendarEvent(calEvent.id!);
                            if (mounted) {
                              Navigator.pop(context);
                              _loadRevisionsForDay();
                            }
                          }
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Event name
                  Text(
                    calEvent.name,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                      height: 1.3,
                    ),
                  ),

                  // Linked item if any
                  if (itemName != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.link, size: 16, color: AppTheme.textMuted),
                        const SizedBox(width: 8),
                        Text(
                          '$itemNumber - $itemName',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],

                  if (collegeName != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        CollegeIcons.buildIcon(
                          collegeName,
                          size: 16,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          collegeName,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Time info
                  _buildDetailRow(
                    icon: Icons.access_time,
                    label: 'Horaire',
                    value:
                        '${DateFormat('HH:mm').format(calEvent.scheduledStartTime)} - ${DateFormat('HH:mm').format(calEvent.scheduledEndTime)}',
                    subtitle: '${calEvent.duration.inMinutes} minutes',
                  ),

                  // Notes if any
                  if (calEvent.notes != null && calEvent.notes!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildDetailRow(
                      icon: Icons.notes,
                      label: 'Notes',
                      value: calEvent.notes!,
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Actions
                  Row(
                    children: [
                      if (!calEvent.isCompleted)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await _markEventAsCompleted(calEvent);
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.check),
                            label: const Text('Compléter'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: eventColor,
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await _unmarkEventCompleted(calEvent);
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.undo),
                            label: const Text('Annuler'),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompleteButton(RevisionSlot revSlot) {
    if (revSlot.isCompleted) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.success.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.check_circle,
          color: AppTheme.success,
          size: 24,
        ),
      );
    }

    return Material(
      color: AppTheme.surfaceLight,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: () => _markAsCompleted(revSlot),
        customBorder: const CircleBorder(),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: Icon(
            Icons.check_circle_outline,
            color: AppTheme.primary,
            size: 24,
          ),
        ),
      ),
    );
  }

  void _showEventDetails(Map<String, dynamic> rev, RevisionSlot revSlot) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppTheme.backgroundCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const BottomSheetHandle(),
                  const SizedBox(height: 12),

                  // Header with type badge and status
                  Row(
                    children: [
                      RevisionTypeBadge(
                        revisionType: revSlot.revisionType.name,
                        label: revSlot.revisionType.label,
                      ),
                      const Spacer(),
                      if (revSlot.isCompleted)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.success,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.check,
                                size: 16,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Complété',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Item name (full)
                  Text(
                    '${rev['item_number']} - ${rev['item_name']}',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // College with icon
                  Row(
                    children: [
                      CollegeIcons.buildIcon(
                        rev['college_name'] ?? '',
                        size: 18,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        rev['college_name'] ?? '',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Time info
                  _buildDetailRow(
                    icon: Icons.access_time,
                    label: 'Horaire',
                    value:
                        '${DateFormat('HH:mm').format(revSlot.scheduledStartTime)} - ${DateFormat('HH:mm').format(revSlot.scheduledEndTime)}',
                    subtitle: '${revSlot.duration.inMinutes} minutes',
                  ),

                  // Notes if any
                  if (revSlot.notes != null && revSlot.notes!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildDetailRow(
                      icon: Icons.notes,
                      label: 'Notes',
                      value: revSlot.notes!,
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _navigateToItemDetail(rev);
                          },
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Voir l\'item'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (!revSlot.isCompleted)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await _markAsCompleted(revSlot);
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.check),
                            label: const Text('Compléter'),
                          ),
                        )
                      else
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await _unmarkCompleted(revSlot);
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.undo),
                            label: const Text('Annuler'),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    String? subtitle,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.textSecondary, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppTheme.textMuted,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? AppTheme.textPrimary,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _navigateToItemDetail(Map<String, dynamic> rev) async {
    final itemId = rev['item_id'] as int?;
    if (itemId == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ItemDetailScreen(itemId: itemId)),
    );
    _loadRevisionsForDay();
  }

  Future<void> _markAsCompleted(RevisionSlot slot) async {
    await _db.updateRevisionSlot(
      slot.copyWith(isCompleted: true, completedDate: DateTime.now()),
    );
    _loadRevisionsForDay();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Révision complétée !'),
          backgroundColor: AppTheme.success,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _unmarkCompleted(RevisionSlot slot) async {
    await _db.updateRevisionSlot(
      slot.copyWith(isCompleted: false, completedDate: null),
    );
    _loadRevisionsForDay();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Révision non complétée'),
          backgroundColor: AppTheme.info,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
