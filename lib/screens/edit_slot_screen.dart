import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/difficulty.dart';
import '../models/revision_slot.dart';
import '../services/revision_scheduler.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../utils/college_icons.dart';

class EditSlotScreen extends StatefulWidget {
  final Map<String, dynamic> slotData;
  final RevisionSlot slot;

  const EditSlotScreen({
    super.key,
    required this.slotData,
    required this.slot,
  });

  @override
  State<EditSlotScreen> createState() => _EditSlotScreenState();
}

class _EditSlotScreenState extends State<EditSlotScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final RevisionScheduler _scheduler = RevisionScheduler();

  late Difficulty _selectedDifficulty;
  late DateTime _selectedDate;
  late TimeOfDay _selectedStartTime;
  late TimeOfDay _selectedEndTime;
  bool _isSaving = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _selectedDifficulty = Difficulty.values.firstWhere(
      (d) => d.name == widget.slotData['difficulty'],
      orElse: () => Difficulty.medium,
    );
    _selectedDate = widget.slot.scheduledDate;
    _selectedStartTime = TimeOfDay.fromDateTime(widget.slot.scheduledStartTime);
    _selectedEndTime = TimeOfDay.fromDateTime(widget.slot.scheduledEndTime);
  }

  @override
  Widget build(BuildContext context) {
    final isFirstSeen = widget.slot.revisionType == RevisionType.firstSeen;
    final itemName = widget.slotData['item_name'] as String? ?? 'Item';
    final displayName = itemName.length > 50 ? '${itemName.substring(0, 50)}...' : itemName;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Modifier la révision',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        actions: [
          if (!widget.slot.isCompleted)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppTheme.error),
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.backgroundCard,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ItemNumberBadge(
                        itemNumber: widget.slotData['item_number'] as int? ?? 0,
                        size: 44,
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.getRevisionTypeColor(widget.slot.revisionType.name).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.slot.revisionType.label,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.getRevisionTypeColor(widget.slot.revisionType.name),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    displayName,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      CollegeIcons.buildIcon(
                        widget.slotData['college_name'],
                        size: 14,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.slotData['college_name'] ?? '',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Status badge
            if (widget.slot.isCompleted)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.check_circle, color: AppTheme.success, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Complétée le ${DateFormat('d MMMM yyyy', 'fr_FR').format(widget.slot.completedDate!)}',
                        style: GoogleFonts.poppins(
                          color: AppTheme.success,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            if (!widget.slot.isCompleted) ...[
              // Date selector
              Text(
                'Date',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              AppCard(
                onTap: _pickDate,
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.calendar_today, color: AppTheme.primary, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(_selectedDate),
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppTheme.textMuted),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Time selector
              Text(
                'Horaire',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              AppCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Début',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              OutlinedButton(
                                onPressed: _pickStartTime,
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.5)),
                                ),
                                child: Text(
                                  _formatTimeOfDay(_selectedStartTime),
                                  style: GoogleFonts.poppins(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Icon(Icons.arrow_forward, color: AppTheme.textMuted),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Fin',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              OutlinedButton(
                                onPressed: _pickEndTime,
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.5)),
                                ),
                                child: Text(
                                  _formatTimeOfDay(_selectedEndTime),
                                  style: GoogleFonts.poppins(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Durée: ${_calculateDuration().inMinutes} minutes',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Difficulty selector (only for first seen or if not completed)
            if (isFirstSeen && !widget.slot.isCompleted) ...[
              Text(
                'Difficulté',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              
              // Warning about difficulty change
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppTheme.warning, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Modifier la difficulté recalculera automatiquement toutes les révisions à venir.',
                        style: GoogleFonts.poppins(
                          color: AppTheme.warning,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              ...Difficulty.values.map((difficulty) => _buildDifficultyTile(difficulty)),
            ],

            // Show current difficulty for non-first-seen or completed slots
            if (!isFirstSeen || widget.slot.isCompleted) ...[
              Text(
                'Difficulté de l\'item',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              AppCard(
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppTheme.getDifficultyColor(_selectedDifficulty.name).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.signal_cellular_alt,
                        color: AppTheme.getDifficultyColor(_selectedDifficulty.name),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _selectedDifficulty.label,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 28),

            // Save button
            if (!widget.slot.isCompleted && _hasChanges)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveChanges,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.save, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Enregistrer les modifications',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

            // Mark as complete button
            if (!widget.slot.isCompleted)
              Padding(
                padding: EdgeInsets.only(top: _hasChanges ? 12 : 0),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _markAsCompleted,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppTheme.success),
                      foregroundColor: AppTheme.success,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_outline, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Marquer comme complété',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultyTile(Difficulty difficulty) {
    final isSelected = _selectedDifficulty == difficulty;
    final color = AppTheme.getDifficultyColor(difficulty.name);
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDifficulty = difficulty;
          _hasChanges = true;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : AppTheme.backgroundCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : AppTheme.surfaceMedium,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isSelected ? color : AppTheme.surfaceLight,
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Text(
              difficulty.label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? color : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Duration _calculateDuration() {
    final start = DateTime(2000, 1, 1, _selectedStartTime.hour, _selectedStartTime.minute);
    final end = DateTime(2000, 1, 1, _selectedEndTime.hour, _selectedEndTime.minute);
    return end.difference(start);
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('fr', 'FR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primary,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _hasChanges = true;
      });
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedStartTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primary,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedStartTime = picked;
        _hasChanges = true;
      });
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedEndTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primary,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedEndTime = picked;
        _hasChanges = true;
      });
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Supprimer cette révision ?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Cette action ne peut pas être annulée. La révision sera supprimée du planning.',
          style: GoogleFonts.poppins(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Annuler',
              style: GoogleFonts.poppins(color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: Text(
              'Supprimer',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _db.deleteRevisionSlot(widget.slot.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Révision supprimée'),
            backgroundColor: AppTheme.warning,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pop(context, true);
      }
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);

    try {
      // Build new start/end times
      final newStartTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedStartTime.hour,
        _selectedStartTime.minute,
      );
      final newEndTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedEndTime.hour,
        _selectedEndTime.minute,
      );

      // Check if time changed - need to reschedule conflicts
      final timeChanged = newStartTime != widget.slot.scheduledStartTime ||
          newEndTime != widget.slot.scheduledEndTime;

      if (timeChanged) {
        // Reschedule conflicting slots (excluding current slot)
        final conflicts = await _db.getConflictingSlots(newStartTime, newEndTime);
        for (final conflict in conflicts) {
          if (conflict.id != widget.slot.id) {
            // Find new slot for the conflicting revision
            final duration = conflict.scheduledEndTime.difference(conflict.scheduledStartTime);
            final newSlot = await _scheduler.findAvailableSlot(
              conflict.scheduledDate.add(const Duration(days: 1)),
              duration,
            );
            if (newSlot != null) {
              await _db.updateRevisionSlot(conflict.copyWith(
                scheduledDate: newSlot['date'],
                scheduledStartTime: newSlot['startTime'],
                scheduledEndTime: newSlot['endTime'],
              ));
            }
          }
        }
      }

      // Update the slot
      await _db.updateRevisionSlot(widget.slot.copyWith(
        scheduledDate: _selectedDate,
        scheduledStartTime: newStartTime,
        scheduledEndTime: newEndTime,
      ));

      // If this is first seen and difficulty changed, reschedule all revisions
      if (widget.slot.revisionType == RevisionType.firstSeen) {
        final originalDifficulty = Difficulty.values.firstWhere(
          (d) => d.name == widget.slotData['difficulty'],
          orElse: () => Difficulty.medium,
        );

        if (_selectedDifficulty != originalDifficulty) {
          final itemCollege = await _db.readItemCollege(widget.slot.itemCollegeId);
          if (itemCollege != null) {
            await _scheduler.updateDifficultyAndReschedule(
              itemCollege,
              _selectedDifficulty,
            );
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Modifications enregistrées'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _markAsCompleted() async {
    await _db.updateRevisionSlot(widget.slot.copyWith(
      isCompleted: true,
      completedDate: DateTime.now(),
    ));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Révision marquée comme complétée !'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.pop(context, true);
    }
  }
}
