import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../database/database_helper.dart';
import '../models/revision_slot.dart';
import '../models/work_schedule.dart';
import '../theme/app_theme.dart';
import '../utils/college_icons.dart';

class AddRevisionScreen extends StatefulWidget {
  final int itemId;
  final List<Map<String, dynamic>> itemColleges;
  final RevisionSlot? existingSlot;
  final Map<String, dynamic>? existingSlotData;

  const AddRevisionScreen({
    super.key,
    required this.itemId,
    required this.itemColleges,
    this.existingSlot,
    this.existingSlotData,
  });

  @override
  State<AddRevisionScreen> createState() => _AddRevisionScreenState();
}

class _AddRevisionScreenState extends State<AddRevisionScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  
  // Step tracking
  int _currentStep = 0;
  
  // Form data
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 14, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 15, minute: 0);
  RevisionType _selectedType = RevisionType.lecture;
  int? _selectedCollegeId;
  String _notes = '';
  
  // Calendar data
  DateTime _focusedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  Map<DateTime, Duration> _availableTimePerDay = {};
  List<Map<String, dynamic>> _revisionsForSelectedDay = [];
  WorkSchedule? _workSchedule;
  bool _isLoading = true;
  bool _isSaving = false;

  bool get isEditing => widget.existingSlot != null;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    
    // If editing, pre-fill the form
    if (widget.existingSlot != null) {
      final slot = widget.existingSlot!;
      _selectedDate = slot.scheduledDate;
      _focusedDay = slot.scheduledDate;
      _startTime = TimeOfDay.fromDateTime(slot.scheduledStartTime);
      _endTime = TimeOfDay.fromDateTime(slot.scheduledEndTime);
      _selectedType = slot.revisionType;
      _notes = slot.notes ?? '';
      
      if (widget.existingSlotData != null) {
        _selectedCollegeId = widget.existingSlotData!['college_id'] as int?;
      }
    } else if (widget.itemColleges.isNotEmpty) {
      _selectedCollegeId = widget.itemColleges.first['item_college_id'] as int;
    }
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    
    // Load work schedule for today
    _workSchedule = await _db.readWorkScheduleForDay(_selectedDate.weekday);
    
    // Load available time for visible month
    await _loadAvailableTimeForMonth(_focusedDay);
    
    // Load revisions for selected day
    await _loadRevisionsForDay(_selectedDate);
    
    setState(() => _isLoading = false);
  }

  Future<void> _loadAvailableTimeForMonth(DateTime month) async {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0);
    
    final Map<DateTime, Duration> availableTime = {};
    
    for (var day = startOfMonth; 
         day.isBefore(endOfMonth) || day.isAtSameMomentAs(endOfMonth); 
         day = day.add(const Duration(days: 1))) {
      
      final workSchedule = await _db.readWorkScheduleForDay(day.weekday);
      if (workSchedule == null) continue;
      
      final totalAvailable = Duration(
        hours: workSchedule.endHour - workSchedule.startHour,
        minutes: workSchedule.endMinute - workSchedule.startMinute,
      );
      
      final scheduledTime = await _db.getTotalScheduledTimeForDate(day);
      final remaining = totalAvailable - scheduledTime;
      
      final normalizedDay = DateTime(day.year, day.month, day.day);
      availableTime[normalizedDay] = remaining.isNegative ? Duration.zero : remaining;
    }
    
    setState(() {
      _availableTimePerDay = availableTime;
    });
  }

  Future<void> _loadRevisionsForDay(DateTime date) async {
    final revisions = await _db.getRevisionSlotsWithDetailsInRange(date, date);
    setState(() {
      _revisionsForSelectedDay = revisions;
    });
    
    // Also load work schedule for this day
    _workSchedule = await _db.readWorkScheduleForDay(date.weekday);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: Text(isEditing ? 'Modifier la révision' : 'Ajouter une révision'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // Step indicator
        _buildStepIndicator(),
        
        // Content
        Expanded(
          child: _currentStep == 0 
              ? _buildDateSelection()
              : _buildDetailsForm(),
        ),
        
        // Navigation buttons
        _buildNavigationButtons(),
      ],
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildStepDot(0, 'Date'),
          Expanded(child: Container(height: 2, color: _currentStep >= 1 ? AppTheme.primary : AppTheme.surfaceMedium)),
          _buildStepDot(1, 'Détails'),
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
            fontSize: 12,
            color: isActive ? AppTheme.textPrimary : AppTheme.textMuted,
            fontWeight: isActive ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

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
                leftChevronIcon: Icon(Icons.chevron_left, color: AppTheme.primary),
                rightChevronIcon: Icon(Icons.chevron_right, color: AppTheme.primary),
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
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                ),
                selectedTextStyle: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                defaultTextStyle: GoogleFonts.poppins(),
                weekendTextStyle: GoogleFonts.poppins(),
                outsideTextStyle: GoogleFonts.poppins(color: AppTheme.textMuted),
              ),

              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDate = selectedDay;
                  _focusedDay = focusedDay;
                });
                _loadRevisionsForDay(selectedDay);
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
    final normalizedDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
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
          
          if (_revisionsForSelectedDay.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'Aucune révision prévue',
                  style: GoogleFonts.poppins(
                    color: AppTheme.textMuted,
                  ),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _revisionsForSelectedDay.length,
              itemBuilder: (context, index) {
                return _buildMiniRevisionCard(_revisionsForSelectedDay[index]);
              },
            ),
          
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
                  itemName.length > 35 ? '${itemName.substring(0, 35)}...' : itemName,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
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
        ],
      ),
    );
  }

  Widget _buildDetailsForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selected date summary
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
          
          // Revision type
          Text(
            'Type de révision',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          _buildTypeSelector(),
          
          const SizedBox(height: 24),
          
          // College selector (only for lecture type)
          if (_selectedType == RevisionType.lecture) ...[
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
          Text(
            'Horaire',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          _buildTimeSelectors(),
          
          const SizedBox(height: 24),
          
          // Notes
          Text(
            'Notes (optionnel)',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            initialValue: _notes.isEmpty ? null : _notes,
            onChanged: (value) => _notes = value,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Ajouter une note...',
              filled: true,
              fillColor: AppTheme.backgroundCard,
            ),
          ),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Row(
      children: RevisionType.values.map((type) {
        final isSelected = _selectedType == type;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() => _selectedType = type);
              // Reset college selection if not lecture
              if (type != RevisionType.lecture) {
                _selectedCollegeId = widget.itemColleges.first['item_college_id'] as int;
              }
            },
            child: Container(
              margin: EdgeInsets.only(right: type != RevisionType.dossier ? 8 : 0),
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
                    _getTypeIcon(type),
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

  IconData _getTypeIcon(RevisionType type) {
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
      children: widget.itemColleges.map((college) {
        final id = college['item_college_id'] as int;
        final name = college['college_name'] as String;
        final isSelected = _selectedCollegeId == id;
        
        return GestureDetector(
          onTap: () => setState(() => _selectedCollegeId = id),
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

  Widget _buildTimeSelectors() {
    return Row(
      children: [
        Expanded(
          child: _buildTimePicker(
            label: 'Début',
            time: _startTime,
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: _startTime,
              );
              if (picked != null) {
                setState(() {
                  _startTime = picked;
                  // Auto-adjust end time if needed
                  if (_timeToMinutes(_endTime) <= _timeToMinutes(_startTime)) {
                    _endTime = TimeOfDay(
                      hour: _startTime.hour + 1,
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
                      content: Text('L\'heure de fin doit être après l\'heure de début'),
                    ),
                  );
                }
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTimePicker({
    required String label,
    required TimeOfDay time,
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
                Icon(Icons.access_time, color: AppTheme.primary, size: 20),
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

  Widget _buildNavigationButtons() {
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
              flex: _currentStep == 0 ? 1 : 1,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _handleNext,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_currentStep == 0 ? 'Suivant' : (isEditing ? 'Modifier' : 'Créer')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleNext() {
    if (_currentStep == 0) {
      setState(() => _currentStep = 1);
    } else {
      _saveRevision();
    }
  }

  Future<void> _saveRevision() async {
    if (_selectedCollegeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un collège')),
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
        id: widget.existingSlot?.id,
        itemCollegeId: _selectedCollegeId!,
        revisionType: _selectedType,
        scheduledDate: _selectedDate,
        scheduledStartTime: startDateTime,
        scheduledEndTime: endDateTime,
        isCompleted: widget.existingSlot?.isCompleted ?? false,
        completedDate: widget.existingSlot?.completedDate,
        notes: _notes.isEmpty ? null : _notes,
      );
      
      if (isEditing) {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
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
