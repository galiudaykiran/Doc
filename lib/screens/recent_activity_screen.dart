import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/folder_info.dart';
import '../models/recent_activity_item.dart';
import '../services/recent_activity_service.dart';
import '../theme/app_theme.dart';
import 'folder_images_page.dart';
import 'notes_page.dart';
import 'password_manager/password_manager_screen.dart';

class RecentActivityScreen extends StatefulWidget {
  final List<FolderInfo> folders;
  final VoidCallback? onAddTap;

  const RecentActivityScreen({
    super.key,
    required this.folders,
    this.onAddTap,
  });

  @override
  State<RecentActivityScreen> createState() => _RecentActivityScreenState();
}

class _RecentActivityScreenState extends State<RecentActivityScreen> {
  List<RecentActivityItem> _activities = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';

  final List<String> _filters = ['All', 'Documents', 'Notes', 'Folders'];

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    final list = await RecentActivityService.getActivities();
    if (mounted) {
      setState(() {
        _activities = list;
        _isLoading = false;
      });
    }
  }

  List<RecentActivityItem> get _filteredActivities {
    if (_selectedFilter == 'All') return _activities;
    if (_selectedFilter == 'Folders') {
      return _activities.where((a) => a.type == 'folder').toList();
    }
    if (_selectedFilter == 'Notes') {
      return _activities.where((a) => a.type == 'note').toList();
    }
    if (_selectedFilter == 'Documents') {
      return _activities
          .where((a) => a.type == 'document' || a.type == 'credential')
          .toList();
    }
    return _activities;
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final itemDate = DateTime(dt.year, dt.month, dt.day);

    if (itemDate == today) {
      return DateFormat('h:mm a').format(dt);
    } else if (today.difference(itemDate).inDays < 7) {
      return DateFormat('EEE, h:mm a').format(dt);
    } else {
      return DateFormat('MMM d, h:mm a').format(dt);
    }
  }

  String _getDateHeader(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final itemDate = DateTime(dt.year, dt.month, dt.day);

    if (itemDate == today) return 'TODAY';
    if (itemDate == yesterday) return 'YESTERDAY';
    if (today.difference(itemDate).inDays < 7) return 'EARLIER THIS WEEK';
    return 'PREVIOUS';
  }

  Map<String, List<RecentActivityItem>> _groupByDate(
      List<RecentActivityItem> items) {
    final Map<String, List<RecentActivityItem>> grouped = {};
    for (final item in items) {
      final header = _getDateHeader(item.timestamp);
      grouped.putIfAbsent(header, () => []).add(item);
    }
    return grouped;
  }

  Future<void> _handleItemTap(RecentActivityItem item) async {
    HapticFeedback.lightImpact();
    if (item.type == 'folder') {
      FolderInfo? folder;
      try {
        folder = widget.folders.firstWhere(
          (f) =>
              (item.targetPath != null && f.path == item.targetPath) ||
              f.name.toLowerCase() == item.title.toLowerCase(),
        );
      } catch (_) {}

      if (folder != null) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FolderImagesPage(folder: folder!),
          ),
        );
        _loadActivities();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Folder "${item.title}" not found'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } else if (item.type == 'note') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => NotesPage(
            folderPath: item.targetPath ?? 'quick_notes',
          ),
        ),
      );
      _loadActivities();
    } else if (item.type == 'credential' || item.type == 'document') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const PasswordManagerScreen(),
        ),
      );
      _loadActivities();
    }
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByDate(_filteredActivities);

    return Scaffold(
      backgroundColor: AppTheme.surface(context),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top App Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 16, 6),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: AppTheme.textPrimary(context),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recent Activity',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                            color: AppTheme.textPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Chronological history across your hub',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: AppTheme.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Filter Chips
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final filter = _filters[index];
                  final isSelected = _selectedFilter == filter;

                  return InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selectedFilter = filter;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryContainer(context)
                            : AppTheme.tonal(context),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primary(context).withOpacity(0.3)
                              : AppTheme.surfaceBorder(context),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        filter,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected
                              ? AppTheme.onPrimaryContainer(context)
                              : AppTheme.textSecondary(context),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Content List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredActivities.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.history_rounded,
                                size: 48,
                                color: AppTheme.textMuted(context),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No recent activities found',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary(context),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                          children: grouped.entries.map((entry) {
                            final sectionTitle = entry.key;
                            final items = entry.value;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(4, 16, 4, 10),
                                  child: Text(
                                    sectionTitle,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                      color: AppTheme.textMuted(context),
                                    ),
                                  ),
                                ),
                                ...items.map((item) => _buildActivityCard(item)),
                              ],
                            );
                          }).toList(),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCard(RecentActivityItem item) {
    Color iconBg;
    Color iconFg;
    IconData icon;

    switch (item.type) {
      case 'note':
        iconBg = const Color(0xFFF3E8FF);
        iconFg = const Color(0xFF7E22CE);
        icon = Icons.edit_note_rounded;
        break;
      case 'credential':
        iconBg = const Color(0xFFDCFCE7);
        iconFg = const Color(0xFF15803D);
        icon = Icons.description_rounded;
        break;
      case 'document':
        iconBg = const Color(0xFFFEF3C7);
        iconFg = const Color(0xFFD97706);
        icon = Icons.insert_drive_file_rounded;
        break;
      case 'folder':
      default:
        iconBg = const Color(0xFFD3E3FD);
        iconFg = const Color(0xFF0B57D0);
        icon = Icons.folder_rounded;
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppTheme.surface(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: AppTheme.surfaceBorder(context),
            width: 1,
          ),
        ),
        elevation: AppTheme.isDark(context) ? 0 : 0.5,
        shadowColor: Colors.black.withOpacity(0.04),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _handleItemTap(item),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                // Leading Icon in Tonal Container
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: iconFg,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),

                // Title & Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppTheme.textPrimary(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.subtitle,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppTheme.textSecondary(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Trailing Timestamp & Chevron
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTimestamp(item.timestamp),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: AppTheme.textMuted(context),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: AppTheme.textMuted(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

