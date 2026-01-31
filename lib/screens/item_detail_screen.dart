import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/revision_slot.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../utils/college_icons.dart';
import 'add_revision_screen.dart';

class ItemDetailScreen extends StatefulWidget {
  final int itemId;

  const ItemDetailScreen({
    super.key,
    required this.itemId,
  });

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  Map<String, dynamic>? _itemData;
  List<Map<String, dynamic>> _revisions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final itemData = await _db.getItemWithColleges(widget.itemId);
    final revisions = await _db.getRevisionSlotsForItemWithDetails(widget.itemId);
    
    setState(() {
      _itemData = itemData;
      _revisions = revisions;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: Text(_isLoading ? 'Chargement...' : 'Item ${_itemData?['item_number'] ?? ''}'),
        actions: [
          if (!_isLoading && _itemData != null)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Ajouter une révision',
              onPressed: _navigateToAddRevision,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _itemData == null
              ? const Center(child: Text('Item non trouvé'))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final colleges = _itemData!['colleges'] as List<Map<String, dynamic>>;
    
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item header card
            _buildHeaderCard(),
            
            const SizedBox(height: 16),
            
            // Colleges section
            _buildCollegesSection(colleges),
            
            const SizedBox(height: 24),
            
            // Revisions section
            _buildRevisionsSection(),
            
            const SizedBox(height: 24),
            
            // Add revision button
            _buildAddRevisionButton(),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.backgroundCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ItemNumberBadge(
            itemNumber: _itemData!['item_number'] as int,
            size: 60,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Item ${_itemData!['item_number']}',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _itemData!['item_name'] as String,
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollegesSection(List<Map<String, dynamic>> colleges) {
    if (colleges.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Collèges',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: colleges.map((college) {
            final name = college['college_name'] as String;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: CollegeIcons.getColor(name).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: CollegeIcons.getColor(name).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CollegeIcons.buildIcon(
                    name,
                    size: 18,
                    color: CollegeIcons.getColor(name),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    name,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildRevisionsSection() {
    // Separate completed and upcoming revisions
    final completedRevisions = _revisions.where((r) {
      final slot = RevisionSlot.fromMap(r);
      return slot.isCompleted;
    }).toList();
    
    final upcomingRevisions = _revisions.where((r) {
      final slot = RevisionSlot.fromMap(r);
      return !slot.isCompleted;
    }).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Révisions',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const Spacer(),
            if (_revisions.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${completedRevisions.length}/${_revisions.length}',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        
        if (_revisions.isEmpty)
          _buildEmptyRevisionsState()
        else ...[
          // Upcoming revisions
          if (upcomingRevisions.isNotEmpty) ...[
            ...upcomingRevisions.map((rev) => _buildRevisionCard(rev)),
          ],
          
          // Completed revisions (greyed out)
          if (completedRevisions.isNotEmpty) ...[
            if (upcomingRevisions.isNotEmpty) 
              const SizedBox(height: 16),
            Text(
              'Complétées',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            ...completedRevisions.map((rev) => _buildRevisionCard(rev, isCompleted: true)),
          ],
        ],
      ],
    );
  }

  Widget _buildEmptyRevisionsState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceMedium),
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_note_outlined,
            size: 48,
            color: AppTheme.textMuted,
          ),
          const SizedBox(height: 12),
          Text(
            'Aucune révision planifiée',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Ajoutez votre première révision',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevisionCard(Map<String, dynamic> rev, {bool isCompleted = false}) {
    final revSlot = RevisionSlot.fromMap(rev);
    final collegeName = rev['college_name'] as String? ?? '';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isCompleted 
            ? AppTheme.surfaceLight 
            : AppTheme.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isCompleted ? null : AppTheme.cardShadow,
        border: isCompleted 
            ? Border.all(color: AppTheme.surfaceMedium) 
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showRevisionOptions(rev, revSlot),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Date badge
                Container(
                  width: 56,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isCompleted 
                        ? AppTheme.textMuted.withValues(alpha: 0.3)
                        : AppTheme.getRevisionTypeColor(revSlot.revisionType.name),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        DateFormat('d').format(revSlot.scheduledDate),
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: isCompleted ? AppTheme.textMuted : Colors.white,
                        ),
                      ),
                      Text(
                        DateFormat('MMM', 'fr_FR').format(revSlot.scheduledDate).toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isCompleted 
                              ? AppTheme.textMuted 
                              : Colors.white.withValues(alpha: 0.8),
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
                      // Type and college
                      Row(
                        children: [
                          RevisionTypeBadge(
                            revisionType: revSlot.revisionType.name,
                            label: revSlot.revisionType.label,
                          ),
                          const SizedBox(width: 8),
                          if (collegeName.isNotEmpty && revSlot.revisionType == RevisionType.lecture)
                            Expanded(
                              child: Row(
                                children: [
                                  CollegeIcons.buildIcon(
                                    collegeName,
                                    size: 14,
                                    color: isCompleted 
                                        ? AppTheme.textMuted 
                                        : AppTheme.textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      collegeName.length > 15 
                                          ? '${collegeName.substring(0, 15)}...'
                                          : collegeName,
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: isCompleted 
                                            ? AppTheme.textMuted 
                                            : AppTheme.textSecondary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      
                      const SizedBox(height: 6),
                      
                      // Time
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: isCompleted 
                                ? AppTheme.textMuted 
                                : AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${DateFormat('HH:mm').format(revSlot.scheduledStartTime)} - ${DateFormat('HH:mm').format(revSlot.scheduledEndTime)}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: isCompleted 
                                  ? AppTheme.textMuted 
                                  : AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isCompleted 
                                  ? AppTheme.surfaceMedium 
                                  : AppTheme.surfaceLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${revSlot.duration.inMinutes}min',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isCompleted 
                                    ? AppTheme.textMuted 
                                    : AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      // Notes if any
                      if (revSlot.notes != null && revSlot.notes!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.notes,
                              size: 14,
                              color: isCompleted 
                                  ? AppTheme.textMuted 
                                  : AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                revSlot.notes!,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                  color: isCompleted 
                                      ? AppTheme.textMuted 
                                      : AppTheme.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Status icon
                Icon(
                  isCompleted 
                      ? Icons.check_circle 
                      : Icons.radio_button_unchecked,
                  color: isCompleted 
                      ? AppTheme.success 
                      : AppTheme.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddRevisionButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _navigateToAddRevision,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter une révision'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: BorderSide(color: AppTheme.primary, width: 1.5),
        ),
      ),
    );
  }

  void _showRevisionOptions(Map<String, dynamic> rev, RevisionSlot revSlot) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.backgroundCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BottomSheetHandle(),
            const SizedBox(height: 20),
            
            // Revision info
            Text(
              '${revSlot.revisionType.label} - ${DateFormat('d MMM yyyy', 'fr_FR').format(revSlot.scheduledDate)}',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Actions
            _buildOptionTile(
              icon: Icons.edit_outlined,
              title: 'Modifier',
              onTap: () {
                Navigator.pop(context);
                _editRevision(rev, revSlot);
              },
            ),
            
            if (revSlot.isCompleted)
              _buildOptionTile(
                icon: Icons.undo,
                title: 'Marquer comme non complétée',
                onTap: () async {
                  Navigator.pop(context);
                  await _toggleCompleted(revSlot, false);
                },
              )
            else
              _buildOptionTile(
                icon: Icons.check_circle_outline,
                title: 'Marquer comme complétée',
                color: AppTheme.success,
                onTap: () async {
                  Navigator.pop(context);
                  await _toggleCompleted(revSlot, true);
                },
              ),
            
            _buildOptionTile(
              icon: Icons.delete_outline,
              title: 'Supprimer',
              color: AppTheme.error,
              onTap: () {
                Navigator.pop(context);
                _deleteRevision(revSlot);
              },
            ),
            
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppTheme.textPrimary),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w500,
          color: color ?? AppTheme.textPrimary,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Future<void> _navigateToAddRevision() async {
    final colleges = _itemData!['colleges'] as List<Map<String, dynamic>>;
    if (colleges.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun collège associé à cet item')),
      );
      return;
    }
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddRevisionScreen(
          itemId: widget.itemId,
          itemColleges: colleges,
        ),
      ),
    );
    
    if (result == true) {
      _loadData();
    }
  }

  void _editRevision(Map<String, dynamic> rev, RevisionSlot revSlot) async {
    final colleges = _itemData!['colleges'] as List<Map<String, dynamic>>;
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddRevisionScreen(
          itemId: widget.itemId,
          itemColleges: colleges,
          existingSlot: revSlot,
          existingSlotData: rev,
        ),
      ),
    );
    
    if (result == true) {
      _loadData();
    }
  }

  Future<void> _toggleCompleted(RevisionSlot slot, bool completed) async {
    await _db.updateRevisionSlot(
      slot.copyWith(
        isCompleted: completed,
        completedDate: completed ? DateTime.now() : null,
      ),
    );
    _loadData();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(completed 
              ? 'Révision marquée comme complétée' 
              : 'Révision marquée comme non complétée'),
          backgroundColor: completed ? AppTheme.success : AppTheme.info,
        ),
      );
    }
  }

  Future<void> _deleteRevision(RevisionSlot slot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la révision ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await _db.deleteRevisionSlot(slot.id!);
      _loadData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Révision supprimée'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }
}
