import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../database/database_helper.dart';
import '../models/item_college.dart';
import '../models/difficulty.dart';
import '../models/revision_slot.dart';
import '../services/revision_scheduler.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../utils/college_icons.dart';

class AddFirstSeenScreen extends StatefulWidget {
  const AddFirstSeenScreen({super.key});

  @override
  State<AddFirstSeenScreen> createState() => _AddFirstSeenScreenState();
}

class _AddFirstSeenScreenState extends State<AddFirstSeenScreen> {
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

  @override
  void initState() {
    super.initState();
    _loadAvailableItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableItems() async {
    setState(() => _isLoading = true);
    
    // Load all item-college combinations that haven't been seen yet
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Nouvel item vu',
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
              : Column(
                  children: [
                    // Search bar
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: AppSearchBar(
                        controller: _searchController,
                        hintText: 'Rechercher par n° ou nom...',
                        onChanged: _filterItems,
                      ),
                    ),
                    
                    // Selected item card
                    if (_selectedItem != null)
                      _buildSelectedItemCard(),
                    
                    // Items list or difficulty selection
                    Expanded(
                      child: _selectedItem == null
                          ? _buildItemsList()
                          : _buildDifficultySelection(),
                    ),
                  ],
                ),
    );
  }

  Widget _buildSelectedItemCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          ItemNumberBadge(
            itemNumber: _selectedItem!['item_number'] as int,
            size: 48,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (_selectedItem!['item_name'] as String).length > 50
                      ? '${(_selectedItem!['item_name'] as String).substring(0, 50)}...'
                      : _selectedItem!['item_name'] as String,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
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
                      size: 14,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _selectedItem!['college_name'],
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppTheme.primary),
            onPressed: () {
              setState(() => _selectedItem = null);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList() {
    if (_filteredItems.isEmpty) {
      return EmptyState(
        icon: Icons.search_off,
        title: 'Aucun résultat',
        subtitle: 'Essayez avec un autre terme de recherche',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredItems.length,
      itemBuilder: (context, index) {
        final item = _filteredItems[index];
        return _buildItemTile(item);
      },
    );
  }

  Widget _buildItemTile(Map<String, dynamic> item) {
    final itemName = item['item_name'] as String;
    final displayName = itemName.length > 50 
        ? '${itemName.substring(0, 50)}...'
        : itemName;

    return AppCard(
      onTap: () {
        setState(() => _selectedItem = item);
      },
      child: Row(
        children: [
          ItemNumberBadge(
            itemNumber: item['item_number'] as int,
            size: 44,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    CollegeIcons.buildIcon(
                      item['college_name'],
                      size: 12,
                      color: AppTheme.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      item['college_name'],
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right,
            color: AppTheme.textMuted,
          ),
        ],
      ),
    );
  }

  Widget _buildDifficultySelection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          
          // Difficulty section
          Text(
            'Difficulté',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          
          ...Difficulty.values.map((difficulty) => _buildDifficultyTile(difficulty)),
          
          const SizedBox(height: 24),
          
          // Group revision toggle
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.backgroundCard,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.group,
                        color: AppTheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Révision de groupe',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            'Planifier une session en groupe',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
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
                          if (!value) {
                            _groupRevisionDate = null;
                          }
                        });
                      },
                    ),
                  ],
                ),
                
                if (_needsGroupRevision) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final now = DateTime.now();
                      final endOfWeek = now.add(Duration(days: 7 - now.weekday));
                      
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: now,
                        firstDate: now,
                        lastDate: endOfWeek,
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
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            size: 20,
                            color: AppTheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _groupRevisionDate == null
                                ? 'Choisir une date'
                                : '${_groupRevisionDate!.day}/${_groupRevisionDate!.month}/${_groupRevisionDate!.year}',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _groupRevisionDate == null 
                                  ? AppTheme.textMuted 
                                  : AppTheme.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          const Icon(
                            Icons.chevron_right,
                            color: AppTheme.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Save button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedItem == null || _isSaving
                  ? null
                  : _saveFirstSeen,
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Enregistrer',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDifficultyTile(Difficulty difficulty) {
    final isSelected = _selectedDifficulty == difficulty;
    final color = AppTheme.getDifficultyColor(difficulty.name);
    
    return GestureDetector(
      onTap: () {
        setState(() => _selectedDifficulty = difficulty);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : AppTheme.backgroundCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : AppTheme.surfaceMedium,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected ? color : AppTheme.surfaceLight,
                shape: BoxShape.circle,
                border: Border.all(
                  color: color,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      size: 14,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Text(
              difficulty.label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? color : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveFirstSeen() async {
    if (_selectedItem == null) return;
    
    if (_needsGroupRevision && _groupRevisionDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Veuillez sélectionner une date pour la révision de groupe'),
          backgroundColor: AppTheme.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Update ItemCollege with first seen data
      final itemCollege = ItemCollege(
        id: _selectedItem!['item_college_id'],
        itemId: _selectedItem!['item_id'],
        collegeId: _selectedItem!['college_id'],
        difficulty: _selectedDifficulty,
        firstSeenDate: DateTime.now(),
        needsGroupRevision: _needsGroupRevision,
        groupRevisionDate: _groupRevisionDate,
      );
      
      await _db.updateItemCollege(itemCollege);
      
      // Get first seen duration from config
      final config = await _scheduler.getDifficultyConfig(_selectedDifficulty);
      
      // Create first seen revision slot (the one that just happened)
      final now = DateTime.now();
      await _db.createRevisionSlot(RevisionSlot(
        itemCollegeId: itemCollege.id!,
        revisionType: RevisionType.firstSeen,
        scheduledDate: now,
        scheduledStartTime: now.subtract(config.firstSeenDuration),
        scheduledEndTime: now,
        isCompleted: true,
        completedDate: now,
      ));
      
      // Schedule group revision if needed
      if (_needsGroupRevision && _groupRevisionDate != null) {
        final groupSlot = await _scheduler.findAvailableSlot(
          _groupRevisionDate!,
          const Duration(hours: 2), // Group revision is always 2 hours
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
      
      // Schedule all automatic revisions
      await _scheduler.scheduleRevisionsForItem(itemCollege);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Item enregistré et révisions planifiées !'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pop(context);
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
