import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gallery_app/services/trash_service.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:gallery_app/theme/app_theme.dart';
import 'package:gallery_app/services/recent_activity_service.dart';

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  final TrashService _trashService = TrashService.instance;
  List<TrashedItem> _items = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';

  final List<String> _filters = ['All', 'Folders', 'Documents', 'Images'];

  @override
  void initState() {
    super.initState();
    _loadTrash();
  }

  Future<void> _loadTrash() async {
    setState(() => _isLoading = true);
    await _trashService.autoPurgeExpired();
    final items = await _trashService.getAllTrashedItems();
    if (mounted) {
      setState(() {
        _items = items;
        _isLoading = false;
      });
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  List<TrashedItem> get _filteredItems {
    if (_selectedFilter == 'All') return _items;
    if (_selectedFilter == 'Folders') {
      return _items.where((i) => i.isFolder).toList();
    }
    if (_selectedFilter == 'Documents') {
      return _items.where((i) {
        final name = i.name.toLowerCase();
        return !i.isFolder &&
            (name.endsWith('.pdf') || name.endsWith('.doc') || name.endsWith('.docx') || name.endsWith('.txt'));
      }).toList();
    }
    if (_selectedFilter == 'Images') {
      return _items.where((i) {
        final name = i.name.toLowerCase();
        return !i.isFolder &&
            (name.endsWith('.jpg') || name.endsWith('.jpeg') || name.endsWith('.png') || name.endsWith('.webp'));
      }).toList();
    }
    return _items;
  }

  Future<void> _restoreItem(TrashedItem item) async {
    HapticFeedback.lightImpact();
    final success = await _trashService.restoreItem(item);
    if (success) {
      Fluttertoast.showToast(msg: '${item.name} restored');
      _loadTrash();
    } else {
      Fluttertoast.showToast(msg: 'Failed to restore ${item.name}');
    }
  }

  Future<void> _permanentDelete(TrashedItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Permanently Delete?',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'This will permanently delete "${item.name}". This action cannot be undone.',
          style: GoogleFonts.plusJakartaSans(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _trashService.permanentlyDelete(item);
      if (success) {
        await RecentActivityService.removeActivity(
          targetPath: item.originalPath,
          title: item.name,
        );
        Fluttertoast.showToast(msg: '${item.name} permanently deleted');
        _loadTrash();
      }
    }
  }

  Future<void> _emptyTrash() async {
    if (_items.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Empty Trash?',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'This will permanently delete all ${_items.length} items in the trash. This action cannot be undone.',
          style: GoogleFonts.plusJakartaSans(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Empty Trash', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final itemsToDelete = List<TrashedItem>.from(_items);
      await _trashService.emptyTrash();
      await RecentActivityService.removeActivities(
        titles: itemsToDelete.map((i) => i.name).toList(),
        paths: itemsToDelete.map((i) => i.originalPath).toList(),
      );
      Fluttertoast.showToast(msg: 'Trash emptied');
      _loadTrash();
    }
  }

  Future<void> _restoreAll() async {
    if (_items.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Restore All?',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Restore all ${_items.length} items to their original locations?',
          style: GoogleFonts.plusJakartaSans(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      int restored = 0;
      for (final item in List.from(_items)) {
        final success = await _trashService.restoreItem(item);
        if (success) restored++;
      }
      Fluttertoast.showToast(msg: '$restored items restored');
      _loadTrash();
    }
  }

  int _daysLeft(DateTime deletedAt) {
    final expiry = deletedAt.add(const Duration(days: 30));
    final diff = expiry.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final items = _filteredItems;
    final totalSize = _items.fold<int>(0, (sum, i) => sum + i.sizeBytes);

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
                          'Trash',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                            color: AppTheme.textPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Items scheduled for automatic deletion',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: AppTheme.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_items.isNotEmpty) ...[
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.primary(context).withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(Icons.restore_rounded, color: AppTheme.primary(context), size: 20),
                        tooltip: 'Restore All',
                        onPressed: _restoreAll,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 20),
                        tooltip: 'Empty Trash',
                        onPressed: _emptyTrash,
                      ),
                    ),
                  ],
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
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
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
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
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

            const SizedBox(height: 14),

            // Info Card Banner
            if (_items.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.tonal(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.surfaceBorder(context)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryContainer(context),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: AppTheme.onPrimaryContainer(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_items.length} items • ${_formatSize(totalSize)}',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: AppTheme.textPrimary(context),
                              ),
                            ),
                            Text(
                              'Items are permanently purged after 30 days',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: AppTheme.textSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 12),

            // Content List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : items.isEmpty
                      ? _buildEmptyState(context)
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          physics: const BouncingScrollPhysics(),
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return _buildTrashCard(item);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrashCard(TrashedItem item) {
    final isPdf = item.name.toLowerCase().endsWith('.pdf');
    final isImage = item.name.toLowerCase().endsWith('.jpg') ||
        item.name.toLowerCase().endsWith('.jpeg') ||
        item.name.toLowerCase().endsWith('.png');

    Color badgeBg = const Color(0xFFE9EEF6);
    Color badgeFg = const Color(0xFF0B57D0);
    IconData icon = Icons.folder_rounded;

    if (item.isFolder) {
      badgeBg = AppTheme.primaryContainer(context);
      badgeFg = AppTheme.primary(context);
      icon = Icons.folder_rounded;
    } else if (isPdf) {
      badgeBg = const Color(0xFFFCE8E6);
      badgeFg = const Color(0xFFC5221F);
      icon = Icons.picture_as_pdf_rounded;
    } else if (isImage) {
      badgeBg = const Color(0xFFE6F4EA);
      badgeFg = const Color(0xFF137333);
      icon = Icons.image_rounded;
    } else {
      badgeBg = const Color(0xFFE9EEF6);
      badgeFg = const Color(0xFF0B57D0);
      icon = Icons.insert_drive_file_rounded;
    }

    final days = _daysLeft(item.deletedAt);

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_forever_rounded, color: Colors.white, size: 24),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete Permanently?'),
                content: Text('Delete "${item.name}" forever?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (direction) {
        _trashService.permanentlyDelete(item);
        RecentActivityService.removeActivity(
          targetPath: item.originalPath,
          title: item.name,
        );
        setState(() => _items.remove(item));
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.surfaceBorder(context),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(AppTheme.isDark(context) ? 0.2 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: badgeFg, size: 22),
          ),
          title: Text(
            item.name,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppTheme.textPrimary(context),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Row(
            children: [
              Text(
                _formatSize(item.sizeBytes),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: AppTheme.textSecondary(context),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: days <= 3 ? const Color(0xFFFDE8E8) : AppTheme.tonal(context),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${days}d left',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: days <= 3 ? Colors.redAccent : AppTheme.textSecondary(context),
                  ),
                ),
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.restore_rounded, color: AppTheme.primary(context), size: 20),
                tooltip: 'Restore',
                onPressed: () => _restoreItem(item),
              ),
              IconButton(
                icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 20),
                tooltip: 'Delete Forever',
                onPressed: () => _permanentDelete(item),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primaryContainer(context).withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.delete_outline_rounded,
                size: 40,
                color: AppTheme.primary(context),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Trash is Empty',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppTheme.textPrimary(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Deleted files and folders will appear here for 30 days before being permanently removed.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppTheme.textSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
