import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../database/database_helper.dart';
import '../models/revision_slot.dart';
import '../models/calendar_event.dart';
import '../models/work_schedule.dart';
import '../theme/app_theme.dart';
import '../utils/college_icons.dart';

/// Unified entry types for the calendar
enum CalendarEntryType { revision, event }

class AddCalendarEntryScreen extends StatefulWidget {
  /// For editing an existing revision
  final RevisionSlot? existingRevision;
  final Map<String, dynamic>? existingRevisionData;

  /// For editing an existing event
  final CalendarEvent? existingEvent;
  final Map<String, dynamic>? existingEventData;

  /// For creating a new revision for a specific item
  final int? itemId;
  final List<Map<String, dynamic>>? itemColleges;

  /// Initial date for new entries
  final DateTime? initialDate;

  /// Force a specific entry type (revision or event)
  final CalendarEntryType? forceEntryType;

  const AddCalendarEntryScreen({
    super.key,
    this.existingRevision,
    this.existingRevisionData,
    this.existingEvent,
    this.existingEventData,
    this.itemId,
    this.itemColleges,
    this.initialDate,
    this.forceEntryType,
  });

  @override
  State<AddCalendarEntryScreen> createState() => _AddCalendarEntryScreenState();
}

class _AddCalendarEntryScreenState extends State<AddCalendarEntryScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  // Step tracking
  int _currentStep = 0;

  // Entry type
  CalendarEntryType _entryType = CalendarEntryType.event;

  // Revision specific data
  RevisionType _selectedRevisionType = RevisionType.lecture;
  int? _selectedItemCollegeId;
  List<Map<String, dynamic>> _itemColleges = [];
  int? _selectedItemId;

  // Event specific data
  EventType _selectedEventType = EventType.exam;
  bool _linkToItem = false;

  // Common data
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 14, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 15, minute: 0);

  // Calendar data
  DateTime _focusedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  Map<DateTime, Duration> _availableTimePerDay = {};
  List<Map<String, dynamic>> _revisionsForSelectedDay = [];
  List<Map<String, dynamic>> _eventsForSelectedDay = [];
  WorkSchedule? _workSchedule;

  // Items data for selection
  List<Map<String, dynamic>> _groupedItems = [];
  List<Map<String, dynamic>> _filteredItems = [];

  bool _isLoading = true;
  bool _isSaving = false;

  bool get isEditingRevision => widget.existingRevision != null;
  bool get isEditingEvent => widget.existingEvent != null;
  bool get isEditing => isEditingRevision || isEditingEvent;
  bool get isCreatingRevisionForItem => widget.itemId != null;

  @override
  void initState() {
    super.initState();
    _initializeForm();
    _loadInitialData();
  }

  void _initializeForm() {
    if (widget.initialDate != null) {
      _selectedDate = widget.initialDate!;
      _focusedDay = widget.initialDate!;
    }

    // Determine entry type
    if (widget.forceEntryType != null) {
      _entryType = widget.forceEntryType!;
    } else if (isEditingRevision || isCreatingRevisionForItem) {
      _entryType = CalendarEntryType.revision;
    } else if (isEditingEvent) {
      _entryType = CalendarEntryType.event;
    }
    else {
      _entryType = CalendarEntryType.revision; 
    }

    // If editing revision
    if (widget.existingRevision != null) {
      final slot = widget.existingRevision!;
      _selectedDate = slot.scheduledDate;
      _focusedDay = slot.scheduledDate;
      _startTime = TimeOfDay.fromDateTime(slot.scheduledStartTime);
      _endTime = TimeOfDay.fromDateTime(slot.scheduledEndTime);
      _selectedRevisionType = slot.revisionType;
      _notesController.text = slot.notes ?? '';

      if (widget.existingRevisionData != null) {
        _selectedItemCollegeId =
            widget.existingRevisionData!['item_college_id'] as int?;
        _selectedItemId = widget.existingRevisionData!['item_id'] as int?;
      }
    }

    // If creating revision for specific item
    if (widget.itemColleges != null && widget.itemColleges!.isNotEmpty) {
      _itemColleges = widget.itemColleges!;
      _selectedItemCollegeId = _itemColleges.first['item_college_id'] as int;
      _selectedItemId = widget.itemId;
    }

    // If editing event
    if (widget.existingEvent != null) {
      final event = widget.existingEvent!;
      _nameController.text = event.name;
      _selectedEventType = event.eventType;
      _selectedDate = event.scheduledDate;
      _focusedDay = event.scheduledDate;
      _startTime = TimeOfDay.fromDateTime(event.scheduledStartTime);
      _endTime = TimeOfDay.fromDateTime(event.scheduledEndTime);
      _notesController.text = event.notes ?? '';
      _selectedItemCollegeId = event.itemCollegeId;
      _linkToItem = event.itemCollegeId != null;
    } else if (_entryType == CalendarEntryType.event) {
      _nameController.text = _selectedEventType.label;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    _workSchedule = await _db.readWorkScheduleForDay(_selectedDate.weekday);
    await _loadAvailableTimeForMonth(_focusedDay);
    await _loadScheduleForDay(_selectedDate);

    final items = await _db.getGroupedItems();

    setState(() {
      _groupedItems = items;
      _filteredItems = items;
      _isLoading = false;
    });
  }

  Future<void> _loadAvailableTimeForMonth(DateTime month) async {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0);

    final Map<DateTime, Duration> availableTime = {};

    for (
      var day = startOfMonth;
      day.isBefore(endOfMonth) || day.isAtSameMomentAs(endOfMonth);
      day = day.add(const Duration(days: 1))
    ) {
      final workSchedule = await _db.readWorkScheduleForDay(day.weekday);
      if (workSchedule == null) continue;

      final totalAvailable = Duration(
        hours: workSchedule.endHour - workSchedule.startHour,
        minutes: workSchedule.endMinute - workSchedule.startMinute,
      );

      final scheduledRevisionTime = await _db.getTotalScheduledTimeForDate(day);
      final events = await _db.readCalendarEventsForDate(day);
      Duration scheduledEventTime = Duration.zero;
      for (final event in events) {
        if (!event.isCompleted) {
          scheduledEventTime += event.duration;
        }
      }

      final remaining =
          totalAvailable - scheduledRevisionTime - scheduledEventTime;

      final normalizedDay = DateTime(day.year, day.month, day.day);
      availableTime[normalizedDay] = remaining.isNegative
          ? Duration.zero
          : remaining;
    }

    setState(() {
      _availableTimePerDay = availableTime;
    });
  }

  Future<void> _loadScheduleForDay(DateTime date) async {
    final revisions = await _db.getRevisionSlotsWithDetailsInRange(date, date);
    final events = await _db.getCalendarEventsWithDetailsForDate(date);
    final workSchedule = await _db.readWorkScheduleForDay(date.weekday);

    setState(() {
      _revisionsForSelectedDay = revisions;
      _eventsForSelectedDay = events;
      _workSchedule = workSchedule;
    });

    _calculateFirstAvailableSlot();
  }

  void _calculateFirstAvailableSlot() {
    if (isEditing) return;
    if (_workSchedule == null) return;

    // Default duration is 1 hour
    const durationMinutes = 60;

    // Create a list of occupied time ranges in minutes from midnight
    List<List<int>> occupiedRanges = [];

    for (final rev in _revisionsForSelectedDay) {
      final slot = RevisionSlot.fromMap(rev);
      occupiedRanges.add([
        slot.scheduledStartTime.hour * 60 + slot.scheduledStartTime.minute,
        slot.scheduledEndTime.hour * 60 + slot.scheduledEndTime.minute,
      ]);
    }

    for (final eventData in _eventsForSelectedDay) {
      final event = CalendarEvent.fromMap(eventData);
      occupiedRanges.add([
        event.scheduledStartTime.hour * 60 + event.scheduledStartTime.minute,
        event.scheduledEndTime.hour * 60 + event.scheduledEndTime.minute,
      ]);
    }

    // Sort ranges by start time
    occupiedRanges.sort((a, b) => a[0].compareTo(b[0]));

    // Merge overlapping ranges
    List<List<int>> mergedRanges = [];
    if (occupiedRanges.isNotEmpty) {
      mergedRanges.add(List.from(occupiedRanges[0]));
      for (int i = 1; i < occupiedRanges.length; i++) {
        final current = occupiedRanges[i];
        final last = mergedRanges.last;
        if (current[0] <= last[1]) {
          last[1] = current[1] > last[1] ? current[1] : last[1];
        } else {
          mergedRanges.add(List.from(current));
        }
      }
    }

    int workStart = _workSchedule!.startHour * 60 + _workSchedule!.startMinute;
    int workEnd = _workSchedule!.endHour * 60 + _workSchedule!.endMinute;

    int proposedStart = workStart;

    for (final range in mergedRanges) {
      if (proposedStart + durationMinutes <= range[0]) {
        // Found a slot before this occupied range
        break;
      }
      // Move proposed start to the end of the occupied range
      if (proposedStart < range[1]) {
        proposedStart = range[1];
      }
    }

    // Check if the proposed slot fits within work hours
    if (proposedStart + durationMinutes <= workEnd) {
      setState(() {
        _startTime = TimeOfDay(hour: proposedStart ~/ 60, minute: proposedStart % 60);
        int endMinutes = proposedStart + durationMinutes;
        _endTime = TimeOfDay(hour: endMinutes ~/ 60, minute: endMinutes % 60);
      });
    } else {
      // If no slot found, just set to workStart
      setState(() {
        _startTime = TimeOfDay(hour: workStart ~/ 60, minute: workStart % 60);
        int endMinutes = workStart + durationMinutes;
        _endTime = TimeOfDay(hour: endMinutes ~/ 60, minute: endMinutes % 60);
      });
    }
  }

  void _filterItems(String query) {
    if (query.isEmpty) {
      setState(() => _filteredItems = _groupedItems);
      return;
    }

    final itemNumber = int.tryParse(query);
    setState(() {
      _filteredItems = _groupedItems.where((item) {
        if (itemNumber != null) {
          return item['item_number'] == itemNumber;
        }
        return (item['item_name'] as String).toLowerCase().contains(
          query.toLowerCase(),
        );
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    String title;
    if (isEditingRevision) {
      title = 'Modifier la révision';
    } else if (isEditingEvent) {
      title = 'Modifier l\'événement';
    } else if (isCreatingRevisionForItem) {
      title = 'Ajouter une révision';
    } else {
      title = 'Ajouter au calendrier';
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(title: Text(title)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    // If creating for specific item, skip type selection
    final showTypeSelection = !isCreatingRevisionForItem && !isEditing;
    final totalSteps = showTypeSelection ? 3 : 2;

    return Column(
      children: [
        _buildStepIndicator(totalSteps, showTypeSelection),
        Expanded(child: _buildStepContent(showTypeSelection)),
        _buildNavigationButtons(totalSteps),
      ],
    );
  }

  Widget _buildStepIndicator(int totalSteps, bool showTypeSelection) {
    List<String> labels;
    if (showTypeSelection) {
      labels = ['Type', 'Date', 'Détails'];
    } else {
      labels = ['Date', 'Détails'];
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          for (int i = 0; i < labels.length; i++) ...[
            _buildStepDot(i, labels[i]),
            if (i < labels.length - 1)
              Expanded(
                child: Container(
                  height: 2,
                  color: _currentStep > i
                      ? AppTheme.primary
                      : AppTheme.surfaceMedium,
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildStepDot(int step, String label) {
    final isActive = _currentStep >= step;
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive ? AppTheme.primary : AppTheme.surfaceMedium,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isActive && _currentStep > step
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : Text(
                    '${step + 1}',
                    style: GoogleFonts.poppins(
                      color: isActive ? Colors.white : AppTheme.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: isActive ? AppTheme.textPrimary : AppTheme.textMuted,
            fontWeight: isActive ? FontWeight.w500 : FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildStepContent(bool showTypeSelection) {
    if (showTypeSelection) {
      switch (_currentStep) {
        case 0:
          return _buildTypeSelection();
        case 1:
          return _buildDateSelection();
        case 2:
          return _buildDetailsForm();
        default:
          return const SizedBox();
      }
    } else {
      switch (_currentStep) {
        case 0:
          return _buildDateSelection();
        case 1:
          return _buildDetailsForm();
        default:
          return const SizedBox();
      }
    }
  }

  // ============ STEP 1: TYPE SELECTION ============

  Widget _buildTypeSelection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Que souhaitez-vous ajouter ?',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),

          // Revision option
          Text(
            'Révision',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          _buildRevisionTypeCard(),
          // Event types
          const SizedBox(height: 24),
          Text(
            'Événements',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          ...EventType.values.map((type) => _buildEventTypeCard(type)),
        ],
      ),
    );
  }

  Widget _buildEventTypeCard(EventType type) {
    final isSelected =
        _entryType == CalendarEntryType.event && _selectedEventType == type;
    final color = _getEventTypeColor(type);
    final icon = _getEventTypeIcon(type);

    return GestureDetector(
      onTap: () {
        setState(() {
          _entryType = CalendarEntryType.event;
          _selectedEventType = type;
          _nameController.text = type.label;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.1)
              : AppTheme.backgroundCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : AppTheme.surfaceMedium,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected ? color : AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : AppTheme.textSecondary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type.label,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? color : AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    _getEventTypeDescription(type),
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: color, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildRevisionTypeCard() {
    final isSelected = _entryType == CalendarEntryType.revision;

    return GestureDetector(
      onTap: () {
        setState(() {
          _entryType = CalendarEntryType.revision;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withValues(alpha: 0.1)
              : AppTheme.backgroundCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.surfaceMedium,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primary : AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.menu_book,
                color: isSelected ? Colors.white : AppTheme.textSecondary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Révision d\'item',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppTheme.primary
                          : AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    'Planifier une session de révision',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: AppTheme.primary, size: 22),
          ],
        ),
      ),
    );
  }

  // ============ STEP 2: DATE SELECTION ============

  Widget _buildDateSelection() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Calendar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.backgroundCard,
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppTheme.cardShadow,
            ),
            child: TableCalendar(
              locale: 'fr_FR',
              firstDay: DateTime.now().subtract(const Duration(days: 365)),
              lastDay: DateTime.now().add(const Duration(days: 365 * 2)),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDate, day),
              calendarFormat: _calendarFormat,
              startingDayOfWeek: StartingDayOfWeek.monday,
              headerStyle: HeaderStyle(
                titleCentered: true,
                formatButtonVisible: false,
                titleTextStyle: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                leftChevronIcon: Icon(
                  Icons.chevron_left,
                  color: AppTheme.primary,
                ),
                rightChevronIcon: Icon(
                  Icons.chevron_right,
                  color: AppTheme.primary,
                ),
              ),
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: AppTheme.primaryLight.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                todayTextStyle: GoogleFonts.poppins(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w600,
                ),
                selectedDecoration: BoxDecoration(
                  color: _entryType == CalendarEntryType.event
                      ? _getEventTypeColor(_selectedEventType)
                      : AppTheme.primary,
                  shape: BoxShape.circle,
                ),
                selectedTextStyle: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                defaultTextStyle: GoogleFonts.poppins(),
                weekendTextStyle: GoogleFonts.poppins(),
                outsideTextStyle: GoogleFonts.poppins(
                  color: AppTheme.textMuted,
                ),
              ),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDate = selectedDay;
                  _focusedDay = focusedDay;
                });
                _loadScheduleForDay(selectedDay);
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
                _loadAvailableTimeForMonth(focusedDay);
              },
            ),
          ),

          const SizedBox(height: 16),

          // Available time info
          _buildAvailableTimeCard(),

          const SizedBox(height: 16),

          // Day schedule
          _buildDaySchedule(),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildAvailableTimeCard() {
    final normalizedDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final available = _availableTimePerDay[normalizedDate] ?? Duration.zero;

    Color color;
    String message;
    if (available.inMinutes <= 0) {
      color = AppTheme.error;
      message = 'Journée complète';
    } else if (available.inMinutes < 120) {
      color = AppTheme.warning;
      message = '${_formatDuration(available)} disponible';
    } else {
      color = AppTheme.success;
      message = '${_formatDuration(available)} disponible';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            available.inMinutes <= 0 ? Icons.event_busy : Icons.event_available,
            color: color,
          ),
          const SizedBox(width: 12),
          Text(
            message,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
          if (_workSchedule != null) ...[
            const Spacer(),
            Text(
              '${_workSchedule!.startHour}h-${_workSchedule!.endHour}h',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDaySchedule() {
    final hasRevisions = _revisionsForSelectedDay.isNotEmpty;
    final hasEvents = _eventsForSelectedDay.isNotEmpty;
    final isEmpty = !hasRevisions && !hasEvents;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Planning du ${DateFormat('d MMMM', 'fr_FR').format(_selectedDate)}',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          if (isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'Aucune activité prévue',
                  style: GoogleFonts.poppins(color: AppTheme.textMuted),
                ),
              ),
            )
          else ...[
            // Events first
            if (hasEvents) ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Text(
                  'Événements',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textMuted,
                  ),
                ),
              ),
              ...(_eventsForSelectedDay.map((e) => _buildMiniEventCard(e))),
              const SizedBox(height: 8),
            ],

            // Then revisions
            if (hasRevisions) ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Text(
                  'Révisions',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textMuted,
                  ),
                ),
              ),
              ...(_revisionsForSelectedDay.map(
                (r) => _buildMiniRevisionCard(r),
              )),
            ],
          ],

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildMiniRevisionCard(Map<String, dynamic> rev) {
    final slot = RevisionSlot.fromMap(rev);
    final itemName = rev['item_name'] as String;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.getRevisionTypeColor(slot.revisionType.name),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  itemName.length > 35
                      ? '${itemName.substring(0, 35)}...'
                      : itemName,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    decoration: slot.isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${DateFormat('HH:mm').format(slot.scheduledStartTime)} - ${DateFormat('HH:mm').format(slot.scheduledEndTime)}',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (slot.isCompleted)
            Icon(Icons.check_circle, size: 16, color: AppTheme.success),
        ],
      ),
    );
  }

  Widget _buildMiniEventCard(Map<String, dynamic> eventData) {
    final event = CalendarEvent.fromMap(eventData);
    final color = _getEventTypeColor(event.eventType);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.name,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    decoration: event.isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${DateFormat('HH:mm').format(event.scheduledStartTime)} - ${DateFormat('HH:mm').format(event.scheduledEndTime)}',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              event.eventType.label,
              style: GoogleFonts.poppins(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          if (event.isCompleted) ...[
            const SizedBox(width: 6),
            Icon(Icons.check_circle, size: 16, color: AppTheme.success),
          ],
        ],
      ),
    );
  }

  // ============ STEP 3: DETAILS FORM ============

  Widget _buildDetailsForm() {
    if (_entryType == CalendarEntryType.event) {
      return _buildEventDetailsForm();
    } else {
      return _buildRevisionDetailsForm();
    }
  }

  Widget _buildEventDetailsForm() {
    final eventColor = _getEventTypeColor(_selectedEventType);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: eventColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(_getEventTypeIcon(_selectedEventType), color: eventColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedEventType.label,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: eventColor,
                        ),
                      ),
                      Text(
                        DateFormat(
                          'EEEE d MMMM yyyy',
                          'fr_FR',
                        ).format(_selectedDate),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: eventColor.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Event name
          Text(
            'Nom de l\'événement',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: 'Ex: ${_selectedEventType.label}',
              filled: true,
              fillColor: AppTheme.backgroundCard,
            ),
          ),

          const SizedBox(height: 24),

          // Time selection
          _buildTimeSection(eventColor),

          const SizedBox(height: 24),

          // Link to item
          _buildLinkToItemSection(),

          const SizedBox(height: 24),

          // Notes
          _buildNotesSection(),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildRevisionDetailsForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: AppTheme.primary),
                const SizedBox(width: 12),
                Text(
                  DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(_selectedDate),
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w500,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // If not creating for specific item, show item selector
          if (!isCreatingRevisionForItem && !isEditingRevision) ...[
            Text(
              'Sélectionner un item',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            _buildItemSelector(),
            const SizedBox(height: 24),
          ],

          // Revision type
          Text(
            'Type de révision',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          _buildRevisionTypeSelector(),

          const SizedBox(height: 24),

          // College selector
          if (_itemColleges.isNotEmpty &&
              _selectedRevisionType == RevisionType.lecture) ...[
            Text(
              'Collège',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            _buildCollegeSelector(),
            const SizedBox(height: 24),
          ],

          // Time selection
          _buildTimeSection(AppTheme.primary),

          const SizedBox(height: 24),

          // Notes
          _buildNotesSection(),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildItemSelector() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.surfaceMedium),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              onChanged: _filterItems,
              decoration: InputDecoration(
                hintText: 'Rechercher par numéro ou nom...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: AppTheme.surfaceLight,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 8),
              itemCount: _filteredItems.length,
              itemBuilder: (context, index) {
                final item = _filteredItems[index];
                final colleges = item['colleges'] as List<Map<String, dynamic>>;
                return _buildItemTile(item, colleges);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemTile(
    Map<String, dynamic> item,
    List<Map<String, dynamic>> colleges,
  ) {
    final isSelected = _selectedItemId == item['item_id'];

    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      backgroundColor: isSelected
          ? AppTheme.primary.withValues(alpha: 0.05)
          : null,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primary
                  : AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${item['item_number']}',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppTheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item['item_name'] as String,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      children: colleges.map((college) {
        final itemCollegeId = college['item_college_id'] as int;
        final isCollegeSelected = _selectedItemCollegeId == itemCollegeId;
        final collegeName = college['college_name'] as String;

        return InkWell(
          onTap: () {
            setState(() {
              _selectedItemId = item['item_id'] as int;
              _selectedItemCollegeId = itemCollegeId;
              _itemColleges = colleges;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            color: isCollegeSelected
                ? AppTheme.primary.withValues(alpha: 0.1)
                : null,
            child: Row(
              children: [
                CollegeIcons.buildIcon(
                  collegeName,
                  size: 18,
                  color: isCollegeSelected
                      ? AppTheme.primary
                      : AppTheme.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    collegeName,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: isCollegeSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: isCollegeSelected
                          ? AppTheme.primary
                          : AppTheme.textPrimary,
                    ),
                  ),
                ),
                if (isCollegeSelected)
                  const Icon(
                    Icons.check_circle,
                    color: AppTheme.primary,
                    size: 20,
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRevisionTypeSelector() {
    return Row(
      children: RevisionType.values.map((type) {
        final isSelected = _selectedRevisionType == type;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() => _selectedRevisionType = type);
              if (type != RevisionType.lecture && _itemColleges.isNotEmpty) {
                _selectedItemCollegeId =
                    _itemColleges.first['item_college_id'] as int;
              }
            },
            child: Container(
              margin: EdgeInsets.only(
                right: type != RevisionType.dossier ? 8 : 0,
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.getRevisionTypeColor(type.name)
                    : AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.getRevisionTypeColor(type.name)
                      : AppTheme.surfaceMedium,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    _getRevisionTypeIcon(type),
                    color: isSelected ? Colors.white : AppTheme.textSecondary,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    type.label,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? Colors.white : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  IconData _getRevisionTypeIcon(RevisionType type) {
    switch (type) {
      case RevisionType.lecture:
        return Icons.menu_book;
      case RevisionType.qcm:
        return Icons.quiz;
      case RevisionType.dossier:
        return Icons.folder_open;
    }
  }

  Widget _buildCollegeSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _itemColleges.map((college) {
        final id = college['item_college_id'] as int;
        final name = college['college_name'] as String;
        final isSelected = _selectedItemCollegeId == id;

        return GestureDetector(
          onTap: () => setState(() => _selectedItemCollegeId = id),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? CollegeIcons.getColor(name)
                  : AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? CollegeIcons.getColor(name)
                    : AppTheme.surfaceMedium,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CollegeIcons.buildIcon(
                  name,
                  size: 18,
                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  name,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? Colors.white : AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTimeSection(Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Horaire',
          style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildTimePicker(
                label: 'Début',
                time: _startTime,
                accentColor: accentColor,
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _startTime,
                  );
                  if (picked != null) {
                    setState(() {
                      _startTime = picked;
                      if (_timeToMinutes(_endTime) <=
                          _timeToMinutes(_startTime)) {
                        _endTime = TimeOfDay(
                          hour: (_startTime.hour + 1) % 24,
                          minute: _startTime.minute,
                        );
                      }
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTimePicker(
                label: 'Fin',
                time: _endTime,
                accentColor: accentColor,
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _endTime,
                  );
                  if (picked != null) {
                    if (_timeToMinutes(picked) > _timeToMinutes(_startTime)) {
                      setState(() => _endTime = picked);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'L\'heure de fin doit être après l\'heure de début',
                          ),
                        ),
                      );
                    }
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimePicker({
    required String label,
    required TimeOfDay time,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.backgroundCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.surfaceMedium),
        ),
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
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.access_time, color: accentColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkToItemSection() {
    final eventColor = _getEventTypeColor(_selectedEventType);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Lier à un item',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Switch(
              value: _linkToItem,
              onChanged: (value) {
                setState(() {
                  _linkToItem = value;
                  if (!value) {
                    _selectedItemCollegeId = null;
                  }
                });
              },
              activeColor: eventColor,
            ),
          ],
        ),
        if (_linkToItem) ...[const SizedBox(height: 12), _buildItemSelector()],
      ],
    );
  }

  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notes (optionnel)',
          style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _notesController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Ajouter une note...',
            filled: true,
            fillColor: AppTheme.backgroundCard,
          ),
        ),
      ],
    );
  }

  // ============ NAVIGATION ============

  Widget _buildNavigationButtons(int totalSteps) {
    final isLastStep = _currentStep == totalSteps - 1;
    Color buttonColor = AppTheme.primary;
    if (_entryType == CalendarEntryType.event) {
      buttonColor = _getEventTypeColor(_selectedEventType);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundCard,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _currentStep--),
                  child: const Text('Retour'),
                ),
              ),
            if (_currentStep > 0) const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _isSaving ? null : _handleNext,
                style: ElevatedButton.styleFrom(backgroundColor: buttonColor),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Text(
                        isLastStep
                            ? (isEditing ? 'Modifier' : 'Créer')
                            : 'Suivant',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleNext() {
    final showTypeSelection = !isCreatingRevisionForItem && !isEditing;
    final totalSteps = showTypeSelection ? 3 : 2;

    if (_currentStep < totalSteps - 1) {
      // Validation before moving to next step
      if (_entryType == CalendarEntryType.revision &&
          !isCreatingRevisionForItem &&
          !isEditingRevision) {
        // On details step, validate item selection
        if (_currentStep == (showTypeSelection ? 1 : 0) + 1 - 1 &&
            _selectedItemCollegeId == null) {
          // Will be validated on save
        }
      }
      setState(() => _currentStep++);
    } else {
      _save();
    }
  }

  Future<void> _save() async {
    if (_entryType == CalendarEntryType.event) {
      await _saveEvent();
    } else {
      await _saveRevision();
    }
  }

  Future<void> _saveEvent() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez entrer un nom pour l\'événement'),
        ),
      );
      return;
    }

    if (_linkToItem && _selectedItemCollegeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner un item ou désactiver le lien'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final startDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _startTime.hour,
        _startTime.minute,
      );

      final endDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _endTime.hour,
        _endTime.minute,
      );

      final event = CalendarEvent(
        id: widget.existingEvent?.id,
        name: _nameController.text.trim(),
        eventType: _selectedEventType,
        itemCollegeId: _linkToItem ? _selectedItemCollegeId : null,
        scheduledDate: _selectedDate,
        scheduledStartTime: startDateTime,
        scheduledEndTime: endDateTime,
        isCompleted: widget.existingEvent?.isCompleted ?? false,
        completedDate: widget.existingEvent?.completedDate,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );

      if (isEditingEvent) {
        await _db.updateCalendarEvent(event);
      } else {
        await _db.createCalendarEvent(event);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  Future<void> _saveRevision() async {
    if (_selectedItemCollegeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner un item et un collège'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final startDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _startTime.hour,
        _startTime.minute,
      );

      final endDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _endTime.hour,
        _endTime.minute,
      );

      final slot = RevisionSlot(
        id: widget.existingRevision?.id,
        itemCollegeId: _selectedItemCollegeId!,
        revisionType: _selectedRevisionType,
        scheduledDate: _selectedDate,
        scheduledStartTime: startDateTime,
        scheduledEndTime: endDateTime,
        isCompleted: widget.existingRevision?.isCompleted ?? false,
        completedDate: widget.existingRevision?.completedDate,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );

      if (isEditingRevision) {
        await _db.updateRevisionSlot(slot);
      } else {
        await _db.createRevisionSlot(slot);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  // ============ HELPERS ============

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

  String _getEventTypeDescription(EventType type) {
    switch (type) {
      case EventType.exam:
        return 'Examen officiel noté';
      case EventType.whiteExam:
        return 'Examen d\'entraînement';
      case EventType.masterclass:
        return 'Session de cours magistral';
      case EventType.other:
        return 'Événement personnalisé';
    }
  }

  int _timeToMinutes(TimeOfDay time) => time.hour * 60 + time.minute;

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
}
