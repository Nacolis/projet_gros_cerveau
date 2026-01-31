import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../database/database_helper.dart';
import '../models/difficulty.dart';
import '../models/difficulty_config.dart';
import '../services/revision_scheduler.dart';
import '../theme/app_theme.dart';

class DifficultySettingsScreen extends StatefulWidget {
  const DifficultySettingsScreen({super.key});

  @override
  State<DifficultySettingsScreen> createState() => _DifficultySettingsScreenState();
}

class _DifficultySettingsScreenState extends State<DifficultySettingsScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final RevisionScheduler _scheduler = RevisionScheduler();
  List<DifficultyConfig> _configs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConfigs();
  }

  Future<void> _loadConfigs() async {
    setState(() => _isLoading = true);
    final configs = await _db.readAllDifficultyConfigs();
    setState(() {
      _configs = configs;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Configuration des difficultés',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppTheme.primary, AppTheme.primaryDark],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AppTheme.floatingShadow,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.tune,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Paramètres de révision',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Configurez la durée et le planning des révisions',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Info card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.info.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppTheme.info,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Pour chaque niveau de difficulté, configurez la durée de première vue et ajoutez autant de créneaux de révision que souhaité.',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: AppTheme.info,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Difficulty cards
                ..._configs.map((config) => _buildDifficultyCard(config)),
              ],
            ),
    );
  }

  Widget _buildDifficultyCard(DifficultyConfig config) {
    final color = _getDifficultyColor(config.difficulty);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getDifficultyIcon(config.difficulty),
                    color: color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    config.difficulty.label,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.edit_outlined, color: color, size: 20),
                  onPressed: () => _editDifficultyConfig(config),
                ),
              ],
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // First seen duration
                _buildConfigRow(
                  icon: Icons.visibility,
                  label: 'Première vue',
                  value: _formatDuration(config.firstSeenDuration),
                  color: color,
                ),
                
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                
                // Revision slots
                Text(
                  'Créneaux de révision (${config.revisionSlots.length})',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                
                if (config.revisionSlots.isEmpty)
                  Text(
                    'Aucune révision configurée',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: AppTheme.textMuted,
                    ),
                  )
                else
                  ...config.revisionSlots.map((slot) => _buildRevisionSlotRow(slot, color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRevisionSlotRow(RevisionSlotConfig slot, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${slot.order}',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'J+${slot.daysAfterFirstSeen}',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _formatDuration(slot.duration),
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getDifficultyColor(Difficulty difficulty) {
    switch (difficulty) {
      case Difficulty.easy:
        return AppTheme.success;
      case Difficulty.medium:
        return AppTheme.warning;
      case Difficulty.hard:
        return AppTheme.error;
    }
  }

  IconData _getDifficultyIcon(Difficulty difficulty) {
    switch (difficulty) {
      case Difficulty.easy:
        return Icons.sentiment_satisfied_alt;
      case Difficulty.medium:
        return Icons.sentiment_neutral;
      case Difficulty.hard:
        return Icons.sentiment_very_dissatisfied;
    }
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

  Future<void> _editDifficultyConfig(DifficultyConfig config) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => EditDifficultyScreen(config: config),
      ),
    );
    
    if (result == true) {
      _scheduler.clearConfigCache();
      await _loadConfigs();
    }
  }
}

class EditDifficultyScreen extends StatefulWidget {
  final DifficultyConfig config;

  const EditDifficultyScreen({super.key, required this.config});

  @override
  State<EditDifficultyScreen> createState() => _EditDifficultyScreenState();
}

class _EditDifficultyScreenState extends State<EditDifficultyScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  late int _firstSeenMinutes;
  late List<RevisionSlotConfig> _slots;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _firstSeenMinutes = widget.config.firstSeenDurationMinutes;
    _slots = List.from(widget.config.revisionSlots);
  }

  @override
  Widget build(BuildContext context) {
    final color = _getDifficultyColor(widget.config.difficulty);
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context, false),
        ),
        title: Text(
          'Modifier ${widget.config.difficulty.label}',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Enregistrer',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                  ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // First seen duration
          _buildSection(
            title: 'Durée de première vue',
            subtitle: 'Temps alloué pour découvrir un nouvel item',
            child: _buildDurationPicker(
              value: _firstSeenMinutes,
              onChanged: (value) => setState(() => _firstSeenMinutes = value),
              color: color,
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Revision slots
          _buildSection(
            title: 'Créneaux de révision',
            subtitle: 'Ajoutez et configurez les révisions espacées',
            trailing: IconButton(
              icon: Icon(Icons.add_circle, color: color),
              onPressed: _addSlot,
            ),
            child: _slots.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.surfaceMedium, style: BorderStyle.solid),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.event_repeat, size: 40, color: AppTheme.textMuted),
                        const SizedBox(height: 8),
                        Text(
                          'Aucune révision configurée',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: AppTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Appuyez sur + pour ajouter une révision',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  )
                : ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _slots.length,
                    onReorder: _reorderSlots,
                    itemBuilder: (context, index) => _buildSlotCard(index, color),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String subtitle,
    required Widget child,
    Widget? trailing,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildDurationPicker({
    required int value,
    required ValueChanged<int> onChanged,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundCard,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatMinutes(value),
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  'Durée actuelle',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              _buildDurationButton(
                icon: Icons.remove,
                onPressed: value > 15 ? () => onChanged(value - 15) : null,
                color: color,
              ),
              const SizedBox(width: 8),
              _buildDurationButton(
                icon: Icons.add,
                onPressed: value < 480 ? () => onChanged(value + 15) : null,
                color: color,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDurationButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required Color color,
  }) {
    return Material(
      color: onPressed != null ? color.withValues(alpha: 0.1) : AppTheme.surfaceLight,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: Icon(
            icon,
            color: onPressed != null ? color : AppTheme.textMuted,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildSlotCard(int index, Color color) {
    final slot = _slots[index];
    
    return Container(
      key: ValueKey(index),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundCard,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          // Drag handle
          Icon(Icons.drag_handle, color: AppTheme.textMuted, size: 20),
          const SizedBox(width: 8),
          
          // Order badge
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Days input
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Jours après',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: AppTheme.textMuted,
                  ),
                ),
                Row(
                  children: [
                    Text('J+', style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textPrimary)),
                    SizedBox(
                      width: 50,
                      child: TextFormField(
                        initialValue: slot.daysAfterFirstSeen.toString(),
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          border: InputBorder.none,
                        ),
                        onChanged: (value) {
                          final days = int.tryParse(value) ?? slot.daysAfterFirstSeen;
                          setState(() {
                            _slots[index] = slot.copyWith(daysAfterFirstSeen: days);
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Duration
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Durée',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: AppTheme.textMuted,
                  ),
                ),
                Row(
                  children: [
                    InkWell(
                      onTap: slot.durationMinutes > 15
                          ? () => setState(() {
                                _slots[index] = slot.copyWith(durationMinutes: slot.durationMinutes - 15);
                              })
                          : null,
                      child: Icon(Icons.remove_circle_outline, size: 18, color: AppTheme.textMuted),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatMinutes(slot.durationMinutes),
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: slot.durationMinutes < 480
                          ? () => setState(() {
                                _slots[index] = slot.copyWith(durationMinutes: slot.durationMinutes + 15);
                              })
                          : null,
                      child: Icon(Icons.add_circle_outline, size: 18, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Delete button
          IconButton(
            icon: Icon(Icons.delete_outline, color: AppTheme.error, size: 20),
            onPressed: () => _deleteSlot(index),
          ),
        ],
      ),
    );
  }

  void _addSlot() {
    setState(() {
      final lastDays = _slots.isEmpty ? 0 : _slots.last.daysAfterFirstSeen;
      _slots.add(RevisionSlotConfig(
        difficultyConfigId: widget.config.id!,
        order: _slots.length + 1,
        daysAfterFirstSeen: lastDays + 7,
        durationMinutes: 60,
      ));
    });
  }

  void _deleteSlot(int index) {
    setState(() {
      _slots.removeAt(index);
    });
  }

  void _reorderSlots(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final slot = _slots.removeAt(oldIndex);
      _slots.insert(newIndex, slot);
    });
  }

  String _formatMinutes(int minutes) {
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      if (mins > 0) {
        return '${hours}h${mins.toString().padLeft(2, '0')}';
      }
      return '${hours}h';
    }
    return '${minutes}min';
  }

  Color _getDifficultyColor(Difficulty difficulty) {
    switch (difficulty) {
      case Difficulty.easy:
        return AppTheme.success;
      case Difficulty.medium:
        return AppTheme.warning;
      case Difficulty.hard:
        return AppTheme.error;
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    
    try {
      final updatedConfig = widget.config.copyWith(
        firstSeenDurationMinutes: _firstSeenMinutes,
      );
      
      await _db.updateDifficultyConfigWithSlots(updatedConfig, _slots);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.config.difficulty.label} mis à jour'),
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
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
