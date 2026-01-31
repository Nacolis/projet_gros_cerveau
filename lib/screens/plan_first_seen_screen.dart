import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/item_college.dart';
import '../models/difficulty.dart';
import '../models/difficulty_config.dart';
import '../services/revision_scheduler.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../utils/college_icons.dart';

class PlanFirstSeenScreen extends StatefulWidget {
  final DateTime? initialDate;
  final DateTime? initialStartTime;

  const PlanFirstSeenScreen({
    super.key,
    this.initialDate,
    this.initialStartTime,
  });

  @override
  State<PlanFirstSeenScreen> createState() => _PlanFirstSeenScreenState();
}

class _PlanFirstSeenScreenState extends State<PlanFirstSeenScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final RevisionScheduler _scheduler = RevisionScheduler();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _availableItems = [];
  List<Map<String, dynamic>> _filteredItems = [];
  Map<String, dynamic>? _selectedItem;
  Difficulty _selectedDifficulty = Difficulty.medium;
  bool _needsGroupRevision = false;
  DateTime? _groupRevisionDate;
  bool _isLoading = true;
  bool _isSaving = false;

  late DateTime _selectedDate;
  TimeOfDay? _selectedStartTime;
  TimeOfDay? _selectedEndTime;
  List<Map<String, DateTime>> _availableTimeSlots = [];

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now().add(const Duration(days: 1));
    if (widget.initialStartTime != null) {
      _selectedStartTime = TimeOfDay.fromDateTime(widget.initialStartTime!);
      _selectedEndTime = TimeOfDay.fromDateTime(
        widget.initialStartTime!.add(const Duration(hours: 2)),
      );
    }
    _loadAvailableItems();
    _loadAvailableTimeSlots();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableItems() async {
    setState(() => _isLoading = true);

    final allItems = await _db.getItemsWithColleges();
    final unseenItems = allItems.where((item) => item['first_seen_date'] == null).toList();

    setState(() {
      _availableItems = unseenItems;
      _filteredItems = unseenItems;
      _isLoading = false;
    });
  }

  void _filterItems(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredItems = _availableItems;
      } else {
        final itemNumber = int.tryParse(query);
        _filteredItems = _availableItems.where((item) {
          if (itemNumber != null) {
            return item['item_number'] == itemNumber;
          }
          return item['item_name'].toString().toLowerCase().contains(query.toLowerCase()) ||
                 item['college_name'].toString().toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  Future<void> _loadAvailableTimeSlots() async {
    final config = await _scheduler.getDifficultyConfig(_selectedDifficulty);
    final firstSeenDuration = config.firstSeenDuration;
    
    final slots = await _scheduler.getAvailableTimeSlotsForDate(
      _selectedDate,
      firstSeenDuration,
    );
    setState(() {
      _availableTimeSlots = slots;
      // Auto-select first available slot if none selected
      if (_selectedStartTime == null && slots.isNotEmpty) {
        _selectedStartTime = TimeOfDay.fromDateTime(slots.first['startTime']!);
        _selectedEndTime = TimeOfDay.fromDateTime(slots.first['endTime']!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Planifier un item',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _availableItems.isEmpty
              ? EmptyState(
                  icon: Icons.celebration,
                  title: 'Tous les items ont été vus !',
                  subtitle: 'Bravo, continuez vos révisions 🎉',
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Info card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.info.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.info.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.info.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.info_outline, color: AppTheme.info, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Planifiez un item pour une date future. Les révisions conflictuelles seront automatiquement reprogrammées.',
                                style: GoogleFonts.poppins(
                                  color: AppTheme.info,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Date selector
                      Text(
                        'Date de la première vue',
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
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceLight,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.calendar_today,
                                color: AppTheme.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
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

                      const SizedBox(height: 20),

                      // Time slot selector
                      Text(
                        'Créneau horaire (2h)',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),

                      if (_availableTimeSlots.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(14),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber, color: AppTheme.warning, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Aucun créneau libre ce jour. Choisir un horaire reportera les révisions existantes.',
                                  style: GoogleFonts.poppins(
                                    color: AppTheme.warning,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Custom time picker
                      AppCard(
                        child: Row(
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
                                    onPressed: () => _pickTime(isStart: true),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.5)),
                                    ),
                                    child: Text(
                                      _selectedStartTime != null
                                          ? _formatTimeOfDay(_selectedStartTime!)
                                          : 'Choisir',
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
                                    onPressed: null,
                                    child: Text(
                                      _selectedEndTime != null
                                          ? _formatTimeOfDay(_selectedEndTime!)
                                          : '--:--',
                                      style: GoogleFonts.poppins(
                                        color: AppTheme.textMuted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Available time slots chips
                      if (_availableTimeSlots.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Créneaux disponibles :',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _availableTimeSlots.take(6).map((slot) {
                            final startTime = TimeOfDay.fromDateTime(slot['startTime']!);
                            final isSelected = _selectedStartTime?.hour == startTime.hour &&
                                _selectedStartTime?.minute == startTime.minute;
                            return ChoiceChip(
                              label: Text(
                                _formatTimeOfDay(startTime),
                                style: GoogleFonts.poppins(
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                ),
                              ),
                              selected: isSelected,
                              selectedColor: AppTheme.primary.withValues(alpha: 0.2),
                              checkmarkColor: AppTheme.primary,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _selectedStartTime = startTime;
                                    _selectedEndTime = TimeOfDay.fromDateTime(slot['endTime']!);
                                  });
                                }
                              },
                            );
                          }).toList(),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Item selector with search
                      Text(
                        'Item à voir',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      
                      // Search bar
                      AppSearchBar(
                        controller: _searchController,
                        hintText: 'Rechercher par n° ou nom...',
                        onChanged: _filterItems,
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Selected item display or selection list
                      if (_selectedItem != null)
                        _buildSelectedItemCard()
                      else
                        Container(
                          height: 180,
                          decoration: BoxDecoration(
                            color: AppTheme.backgroundCard,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.surfaceMedium),
                          ),
                          child: _filteredItems.isEmpty
                              ? Center(
                                  child: Text(
                                    'Aucun item trouvé',
                                    style: GoogleFonts.poppins(
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.all(8),
                                  itemCount: _filteredItems.length,
                                  itemBuilder: (context, index) {
                                    final item = _filteredItems[index];
                                    return _buildItemSelectTile(item);
                                  },
                                ),
                        ),

                      const SizedBox(height: 24),

                      // Difficulty selector
                      Text(
                        'Difficulté prévue',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...Difficulty.values.map((difficulty) => _buildDifficultyTile(difficulty)),

                      const SizedBox(height: 20),

                      // Group revision toggle
                      _buildGroupRevisionCard(),

                      const SizedBox(height: 24),

                      // Summary card
                      if (_selectedItem != null && _selectedStartTime != null)
                        _buildSummaryCard(),

                      const SizedBox(height: 16),

                      // Save button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _canSave() ? _saveScheduledItem : null,
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
                                    const Icon(Icons.schedule, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Planifier cet item',
                                      style: GoogleFonts.poppins(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }
  
  Widget _buildSelectedItemCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          ItemNumberBadge(
            itemNumber: _selectedItem!['item_number'] as int,
            size: 44,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (_selectedItem!['item_name'] as String).length > 40
                      ? '${(_selectedItem!['item_name'] as String).substring(0, 40)}...'
                      : _selectedItem!['item_name'] as String,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    CollegeIcons.buildIcon(
                      _selectedItem!['college_name'],
                      size: 12,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _selectedItem!['college_name'],
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppTheme.primary, size: 20),
            onPressed: () => setState(() => _selectedItem = null),
          ),
        ],
      ),
    );
  }

  Widget _buildItemSelectTile(Map<String, dynamic> item) {
    return InkWell(
      onTap: () => setState(() => _selectedItem = item),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Row(
          children: [
            ItemNumberBadge(
              itemNumber: item['item_number'] as int,
              size: 36,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (item['item_name'] as String).length > 35
                        ? '${(item['item_name'] as String).substring(0, 35)}...'
                        : item['item_name'] as String,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    item['college_name'],
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultyTile(Difficulty difficulty) {
    final isSelected = _selectedDifficulty == difficulty;
    final color = AppTheme.getDifficultyColor(difficulty.name);
    
    return GestureDetector(
      onTap: () async {
        setState(() => _selectedDifficulty = difficulty);
        await _loadAvailableTimeSlots(); // Reload time slots for new difficulty duration
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    difficulty.label,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? color : AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    _getDifficultyDescription(difficulty),
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
      ),
    );
  }

  Widget _buildGroupRevisionCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.backgroundCard,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.group, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Révision de groupe',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      'Planifier une session en groupe',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _needsGroupRevision,
                onChanged: (value) {
                  setState(() {
                    _needsGroupRevision = value;
                    if (!value) _groupRevisionDate = null;
                  });
                },
              ),
            ],
          ),
          if (_needsGroupRevision) ...[
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 10),
            InkWell(
              onTap: _pickGroupRevisionDate,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 18, color: AppTheme.primary),
                    const SizedBox(width: 10),
                    Text(
                      _groupRevisionDate == null
                          ? 'Choisir une date'
                          : DateFormat('EEEE d MMMM', 'fr_FR').format(_groupRevisionDate!),
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _groupRevisionDate == null 
                            ? AppTheme.textMuted 
                            : AppTheme.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.chevron_right, color: AppTheme.textMuted),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Résumé de la planification',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          _buildSummaryRow('Item', '${_selectedItem!['item_number']} - ${_selectedItem!['item_name']}'),
          _buildSummaryRow('Collège', _selectedItem!['college_name']),
          _buildSummaryRow('Date', DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(_selectedDate)),
          _buildSummaryRow(
            'Horaire',
            '${_formatTimeOfDay(_selectedStartTime!)} - ${_formatTimeOfDay(_selectedEndTime!)}',
          ),
          _buildSummaryRow('Difficulté', _selectedDifficulty.label),
          const Divider(),
          const SizedBox(height: 8),
          Text(
            'Révisions planifiées automatiquement :',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          _buildRevisionPlan(),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                color: AppTheme.textMuted,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
                fontSize: 12,
                color: AppTheme.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevisionPlan() {
    return FutureBuilder<DifficultyConfig>(
      future: _scheduler.getDifficultyConfig(_selectedDifficulty),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final config = snapshot.data!;
        if (config.revisionSlots.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Aucune révision configurée pour cette difficulté',
              style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
            ),
          );
        }

        return Column(
          children: config.revisionSlots.map((slotConfig) {
            final date = _selectedDate.add(Duration(days: slotConfig.daysAfterFirstSeen));
            final duration = slotConfig.duration;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, size: 14, color: AppTheme.success),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Révision ${slotConfig.order} (J+${slotConfig.daysAfterFirstSeen})',
                      style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textPrimary),
                    ),
                  ),
                  Text(
                    DateFormat('d MMM', 'fr_FR').format(date),
                    style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _formatDuration(duration),
                      style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textMuted),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      final minutes = duration.inMinutes % 60;
      if (minutes > 0) {
        return '${duration.inHours}h${minutes.toString().padLeft(2, '0')}';
      }
      return '${duration.inHours}h';
    }
    return '${duration.inMinutes} min';
  }

  String _getDifficultyDescription(Difficulty difficulty) {
    switch (difficulty) {
      case Difficulty.easy:
        return 'Révisions plus courtes, moins de répétitions';
      case Difficulty.medium:
        return 'Révisions standard';
      case Difficulty.hard:
        return 'Révisions plus longues';
    }
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
        _selectedStartTime = null;
        _selectedEndTime = null;
      });
      await _loadAvailableTimeSlots();
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedStartTime ?? const TimeOfDay(hour: 14, minute: 0),
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
      final config = await _scheduler.getDifficultyConfig(_selectedDifficulty);
      setState(() {
        _selectedStartTime = picked;
        // Auto-calculate end time based on difficulty
        final startDateTime = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          picked.hour,
          picked.minute,
        );
        final endDateTime = startDateTime.add(config.firstSeenDuration);
        _selectedEndTime = TimeOfDay.fromDateTime(endDateTime);
      });
    }
  }

  Future<void> _pickGroupRevisionDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: _selectedDate,
      lastDate: _selectedDate.add(const Duration(days: 14)),
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
        _groupRevisionDate = picked;
      });
    }
  }

  bool _canSave() {
    return _selectedItem != null &&
        _selectedStartTime != null &&
        _selectedEndTime != null &&
        !_isSaving &&
        (!_needsGroupRevision || _groupRevisionDate != null);
  }

  Future<void> _saveScheduledItem() async {
    if (!_canSave()) return;

    setState(() => _isSaving = true);

    try {
      // Create DateTime objects for start and end times
      final startTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedStartTime!.hour,
        _selectedStartTime!.minute,
      );
      final endTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedEndTime!.hour,
        _selectedEndTime!.minute,
      );

      // Create ItemCollege object
      final itemCollege = ItemCollege(
        id: _selectedItem!['item_college_id'],
        itemId: _selectedItem!['item_id'],
        collegeId: _selectedItem!['college_id'],
        difficulty: _selectedDifficulty,
      );

      // Schedule the first seen for the future
      await _scheduler.scheduleFirstSeenForFuture(
        itemCollege: itemCollege,
        plannedDate: _selectedDate,
        startTime: startTime,
        endTime: endTime,
        needsGroupRevision: _needsGroupRevision,
        groupRevisionDate: _groupRevisionDate,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Item planifié pour le ${DateFormat('d MMMM', 'fr_FR').format(_selectedDate)} !',
            ),
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
}
