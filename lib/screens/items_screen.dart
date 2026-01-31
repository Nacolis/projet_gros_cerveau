import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../database/database_helper.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../utils/college_icons.dart';
import '../models/college.dart';
import 'item_detail_screen.dart';

class ItemsScreen extends StatefulWidget {
  const ItemsScreen({super.key});

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<Map<String, dynamic>> _groupedItems = [];
  List<College> _colleges = [];
  College? _selectedCollege;
  bool _isLoading = true;
  bool _isImporting = false;
  bool _showOnlyWithRevisions = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final colleges = await _db.readAllColleges();
    final items = await _db.getGroupedItems();
    
    setState(() {
      _colleges = colleges;
      _groupedItems = items;
      _isLoading = false;
    });
  }

  Future<void> _searchItems() async {
    if (_searchQuery.isEmpty && _selectedCollege == null) {
      await _loadData();
      return;
    }
    
    setState(() => _isLoading = true);
    
    final items = await _db.searchItems(
      _searchQuery,
      collegeId: _selectedCollege?.id,
    );
    
    setState(() {
      _groupedItems = items;
      _isLoading = false;
    });
  }

  List<Map<String, dynamic>> get _filteredItems {
    var items = _groupedItems;
    
    if (_showOnlyWithRevisions) {
      items = items.where((item) => (item['revision_count'] as int) > 0).toList();
    }
    
    return items;
  }

  Future<void> _importCSV() async {
    setState(() => _isImporting = true);
    try {
      await _db.importFromCSV('https://univ-edt.fr/item.csv');
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Items importés avec succès !'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'importation: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isImporting) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              'Importation des items en cours...',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Search and filters section
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Search bar
              AppSearchBar(
                controller: _searchController,
                hintText: 'Rechercher par n° ou nom...',
                showFilter: true,
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                  _searchItems();
                },
                onFilterTap: _showFilterBottomSheet,
              ),
              
              const SizedBox(height: 12),
              
              // Filter chips row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // With revisions filter chip
                    FilterChip(
                      label: Text(
                        'Avec révisions',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      selected: _showOnlyWithRevisions,
                      onSelected: (selected) {
                        setState(() => _showOnlyWithRevisions = selected);
                      },
                      selectedColor: AppTheme.primaryLight,
                      checkmarkColor: AppTheme.primary,
                      side: BorderSide(
                        color: _showOnlyWithRevisions ? AppTheme.primary : AppTheme.surfaceMedium,
                      ),
                    ),
                    
                    const SizedBox(width: 8),
                    
                    // Selected college chip
                    if (_selectedCollege != null)
                      Chip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CollegeIcons.buildIcon(
                              _selectedCollege!.name,
                              size: 16,
                              color: AppTheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _selectedCollege!.name.length > 20
                                  ? '${_selectedCollege!.name.substring(0, 20)}...'
                                  : _selectedCollege!.name,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        deleteIcon: const Icon(Icons.close, size: 18),
                        onDeleted: () {
                          setState(() => _selectedCollege = null);
                          _searchItems();
                        },
                        backgroundColor: AppTheme.surfaceLight,
                        side: BorderSide(color: AppTheme.primary),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Stats bar
        if (_groupedItems.isNotEmpty && !_isLoading)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildStatBadge(
                  icon: Icons.library_books,
                  label: '${_filteredItems.length} items',
                  color: AppTheme.primary,
                ),
                const SizedBox(width: 12),
                _buildStatBadge(
                  icon: Icons.event_note,
                  label: '${_filteredItems.where((i) => (i['revision_count'] as int) > 0).length} avec révisions',
                  color: AppTheme.success,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _importCSV,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Réimporter'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
        
        // Items list
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _groupedItems.isEmpty
                  ? _buildEmptyState()
                  : _filteredItems.isEmpty
                      ? EmptyState(
                          icon: Icons.search_off,
                          title: 'Aucun résultat',
                          subtitle: 'Essayez avec d\'autres critères de recherche',
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredItems.length,
                          itemBuilder: (context, index) {
                            return _buildItemCard(_filteredItems[index]);
                          },
                        ),
        ),
      ],
    );
  }

  Widget _buildStatBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return EmptyState(
      icon: Icons.download,
      title: 'Aucun item trouvé',
      subtitle: 'Importez les items ECN depuis le fichier CSV pour commencer',
      action: ElevatedButton.icon(
        onPressed: _importCSV,
        icon: const Icon(Icons.download),
        label: const Text('Importer les items'),
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final colleges = item['colleges'] as List<Map<String, dynamic>>;
    final revisionCount = item['revision_count'] as int;
    final completedCount = item['completed_count'] as int;
    final itemName = item['item_name'] as String;
    final hasRevisions = revisionCount > 0;
    
    // Truncate name for display
    final displayName = itemName.length > 60 
        ? '${itemName.substring(0, 60)}...'
        : itemName;
    
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () => _navigateToItemDetail(item),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item number badge
          ItemNumberBadge(
            itemNumber: item['item_number'] as int,
            isSeen: hasRevisions && completedCount == revisionCount,
          ),
          
          const SizedBox(width: 14),
          
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Item name
                Text(
                  displayName,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                
                const SizedBox(height: 8),
                
                // Colleges chips (show first 2-3)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ...colleges.take(3).map((college) {
                      return _buildMiniCollegeChip(
                        college['college_name'] as String,
                      );
                    }),
                    if (colleges.length > 3)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '+${colleges.length - 3}',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 8),
          
          // Revision count indicator
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (revisionCount > 0) ...[
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        value: revisionCount > 0 ? completedCount / revisionCount : 0,
                        strokeWidth: 3,
                        backgroundColor: AppTheme.surfaceMedium,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          completedCount == revisionCount ? AppTheme.success : AppTheme.primary,
                        ),
                      ),
                    ),
                    Text(
                      '$completedCount/$revisionCount',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ] else
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.add,
                    color: AppTheme.textMuted,
                    size: 20,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniCollegeChip(String name) {
    // Truncate long names
    final displayName = name.length > 15 ? '${name.substring(0, 12)}...' : name;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CollegeIcons.buildIcon(
            name,
            size: 12,
            color: AppTheme.textMuted,
          ),
          const SizedBox(width: 4),
          Text(
            displayName,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToItemDetail(Map<String, dynamic> item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ItemDetailScreen(
          itemId: item['item_id'] as int,
        ),
      ),
    );
    // Reload data when returning
    _loadData();
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppTheme.backgroundCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              const BottomSheetHandle(),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Filtrer par collège',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_selectedCollege != null)
                      TextButton(
                        onPressed: () {
                          setState(() => _selectedCollege = null);
                          _searchItems();
                          Navigator.pop(context);
                        },
                        child: const Text('Effacer'),
                      ),
                  ],
                ),
              ),
              
              const SizedBox(height: 8),
              
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _colleges.length,
                  itemBuilder: (context, index) {
                    final college = _colleges[index];
                    final isSelected = _selectedCollege?.id == college.id;
                    
                    return ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? AppTheme.primary 
                              : CollegeIcons.getColor(college.name).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: CollegeIcons.buildIcon(
                            college.name,
                            color: isSelected 
                                ? Colors.white 
                                : CollegeIcons.getColor(college.name),
                            size: 20,
                          ),
                        ),
                      ),
                      title: Text(
                        college.name,
                        style: GoogleFonts.poppins(
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                        ),
                      ),
                      trailing: isSelected 
                          ? const Icon(Icons.check_circle, color: AppTheme.primary)
                          : null,
                      onTap: () {
                        setState(() => _selectedCollege = college);
                        _searchItems();
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
