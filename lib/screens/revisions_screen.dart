import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/revision_slot.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../utils/college_icons.dart';

class RevisionsScreen extends StatefulWidget {
  const RevisionsScreen({super.key});

  @override
  State<RevisionsScreen> createState() => _RevisionsScreenState();
}

class _RevisionsScreenState extends State<RevisionsScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  List<Map<String, dynamic>> _uncompletedRevisions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUncompletedRevisions();
  }

  Future<void> _loadUncompletedRevisions() async {
    setState(() => _isLoading = true);
    final revisions = await _db.getRevisionSlotsWithDetails();
    final uncompleted = revisions.where((rev) {
      final revSlot = RevisionSlot.fromMap(rev);
      return !revSlot.isCompleted;
    }).toList();

    // Sort by scheduled date
    uncompleted.sort((a, b) {
      final aSlot = RevisionSlot.fromMap(a);
      final bSlot = RevisionSlot.fromMap(b);
      return aSlot.scheduledDate.compareTo(bSlot.scheduledDate);
    });

    setState(() {
      _uncompletedRevisions = uncompleted;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_uncompletedRevisions.isEmpty) {
      return EmptyState(
        icon: Icons.celebration,
        title: 'Toutes les révisions sont à jour !',
        subtitle: 'Continuez votre excellent travail 🎉',
      );
    }

    // Group by status: overdue, today, upcoming
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final overdueRevisions = _uncompletedRevisions.where((rev) {
      final revSlot = RevisionSlot.fromMap(rev);
      final schedDate = DateTime(
        revSlot.scheduledDate.year,
        revSlot.scheduledDate.month,
        revSlot.scheduledDate.day,
      );
      return schedDate.isBefore(today);
    }).toList();

    final todayRevisions = _uncompletedRevisions.where((rev) {
      final revSlot = RevisionSlot.fromMap(rev);
      final schedDate = DateTime(
        revSlot.scheduledDate.year,
        revSlot.scheduledDate.month,
        revSlot.scheduledDate.day,
      );
      return schedDate.isAtSameMomentAs(today);
    }).toList();

    final upcomingRevisions = _uncompletedRevisions.where((rev) {
      final revSlot = RevisionSlot.fromMap(rev);
      final schedDate = DateTime(
        revSlot.scheduledDate.year,
        revSlot.scheduledDate.month,
        revSlot.scheduledDate.day,
      );
      return schedDate.isAfter(today);
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadUncompletedRevisions,
      color: AppTheme.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Summary cards
          _buildSummaryRow(
            overdue: overdueRevisions.length,
            today: todayRevisions.length,
            upcoming: upcomingRevisions.length,
          ),
          
          const SizedBox(height: 20),
          
          if (overdueRevisions.isNotEmpty) ...[
            SectionHeader(
              title: 'En retard',
              color: AppTheme.error,
              count: overdueRevisions.length,
            ),
            ...overdueRevisions.map((rev) => _buildRevisionCard(rev, isOverdue: true)),
            const SizedBox(height: 16),
          ],
          if (todayRevisions.isNotEmpty) ...[
            SectionHeader(
              title: 'Aujourd\'hui',
              color: AppTheme.warning,
              count: todayRevisions.length,
            ),
            ...todayRevisions.map((rev) => _buildRevisionCard(rev)),
            const SizedBox(height: 16),
          ],
          if (upcomingRevisions.isNotEmpty) ...[
            SectionHeader(
              title: 'À venir',
              color: AppTheme.info,
              count: upcomingRevisions.length,
            ),
            ...upcomingRevisions.map((rev) => _buildRevisionCard(rev)),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryRow({
    required int overdue,
    required int today,
    required int upcoming,
  }) {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            label: 'En retard',
            count: overdue,
            color: AppTheme.error,
            icon: Icons.warning_amber_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildSummaryCard(
            label: 'Aujourd\'hui',
            count: today,
            color: AppTheme.warning,
            icon: Icons.today,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildSummaryCard(
            label: 'À venir',
            count: upcoming,
            color: AppTheme.info,
            icon: Icons.schedule,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String label,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            '$count',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRevisionCard(Map<String, dynamic> rev, {bool isOverdue = false}) {
    final revSlot = RevisionSlot.fromMap(rev);
    final itemName = rev['item_name'] as String;
    final collegeName = rev['college_name'] as String? ?? '';
    
    // Truncate long names
    final displayName = itemName.length > 40 
        ? '${itemName.substring(0, 40)}...'
        : itemName;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
        border: isOverdue 
            ? Border.all(color: AppTheme.error.withValues(alpha: 0.3))
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Date badge
            Container(
              width: 56,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.getRevisionTypeColor(revSlot.revisionType.name),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    DateFormat('d').format(revSlot.scheduledDate),
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    DateFormat('MMM', 'fr_FR').format(revSlot.scheduledDate).toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
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
                    displayName,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
                                  collegeName.length > 12 
                                      ? '${collegeName.substring(0, 12)}...'
                                      : collegeName,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
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
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 12,
                        color: AppTheme.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${DateFormat('HH:mm').format(revSlot.scheduledStartTime)} - ${DateFormat('HH:mm').format(revSlot.scheduledEndTime)}',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${revSlot.duration.inMinutes}min',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
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
            
            // Complete button
            Material(
              color: AppTheme.primary.withValues(alpha: 0.1),
              shape: const CircleBorder(),
              child: InkWell(
                onTap: () => _markAsCompleted(revSlot),
                customBorder: const CircleBorder(),
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.check_circle_outline,
                    color: AppTheme.primary,
                    size: 26,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markAsCompleted(RevisionSlot slot) async {
    await _db.updateRevisionSlot(
      slot.copyWith(
        isCompleted: true,
        completedDate: DateTime.now(),
      ),
    );
    _loadUncompletedRevisions();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Révision marquée comme complétée !'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
