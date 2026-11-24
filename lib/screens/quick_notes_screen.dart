import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

import 'package:gallery_app/models/quick_note_item.dart';
import 'package:gallery_app/models/notes.dart';
import 'package:gallery_app/screens/notes_page.dart';
import 'package:gallery_app/services/recent_activity_service.dart';
import 'package:gallery_app/theme/app_theme.dart';

class QuickNotesScreen extends StatefulWidget {
  const QuickNotesScreen({super.key});

  @override
  State<QuickNotesScreen> createState() => _QuickNotesScreenState();
}

class _QuickNotesScreenState extends State<QuickNotesScreen> {
  static const String _prefKey = 'hub_quick_notes_list_v1';
  List<QuickNoteItem> _notes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);

    if (raw != null) {
      try {
        final List decoded = jsonDecode(raw);
        _notes = decoded.map((e) => QuickNoteItem.fromMap(e)).toList();
      } catch (_) {
        _notes = [];
      }
    } else {
      // Initialize with sample notes matching design reference
      _notes = [
        QuickNoteItem(
          id: 'note_sample_1',
          title: 'Passport & ID Renewal Checklist',
          category: 'Personal',
          contentSnippet:
              '1. Aadhaar & PAN PDF copies\n2. Address proof utility bill\n3. Appointment confirmation slip',
          lastUpdated: DateTime.now().subtract(const Duration(hours: 1)),
          isPinned: true,
        ),
        QuickNoteItem(
          id: 'note_sample_2',
          title: 'Tax Filing FY 2026–27',
          category: 'Finance',
          contentSnippet:
              'Collect Form 16, 80C investment receipts, and bank interest certificates before July.',
          lastUpdated: DateTime.now().subtract(const Duration(days: 1)),
          isPinned: false,
        ),
      ];
      await _saveNotesList();
    }

    _sortNotes();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _sortNotes() {
    _notes.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return b.lastUpdated.compareTo(a.lastUpdated);
    });
  }

  Future<void> _saveNotesList() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_notes.map((e) => e.toMap()).toList());
    await prefs.setString(_prefKey, encoded);
  }

  Future<void> _togglePin(QuickNoteItem note) async {
    HapticFeedback.lightImpact();
    setState(() {
      note.isPinned = !note.isPinned;
      _sortNotes();
    });
    await _saveNotesList();
  }

  Future<void> _deleteNote(QuickNoteItem note) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface(ctx),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Note?',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppTheme.textPrimary(ctx),
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${note.title}"? This cannot be undone.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: AppTheme.textSecondary(ctx),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(color: AppTheme.textMuted(ctx)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB3261E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('folder_notes_${note.id}');
      setState(() {
        _notes.removeWhere((e) => e.id == note.id);
      });
      await _saveNotesList();
      await RecentActivityService.removeActivity(
        title: note.title,
        targetPath: note.id,
      );
    }
  }

  void _showNewNoteDialog() {
    HapticFeedback.lightImpact();
    final titleController = TextEditingController();
    String selectedCategory = 'Personal';
    final categories = ['Personal', 'Finance', 'Work', 'Ideas', 'Checklist'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
          return Container(
            padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomInset),
            decoration: BoxDecoration(
              color: AppTheme.surface(ctx),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(
                top: BorderSide(color: AppTheme.surfaceBorder(ctx), width: 1),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.textMuted(ctx).withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'New Note',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    color: AppTheme.textPrimary(ctx),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  autofocus: true,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary(ctx),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Note Title (e.g. Grocery List)',
                    hintStyle: GoogleFonts.plusJakartaSans(color: AppTheme.textMuted(ctx)),
                    filled: true,
                    fillColor: AppTheme.tonal(ctx),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: AppTheme.surfaceBorder(ctx)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: AppTheme.surfaceBorder(ctx)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: AppTheme.primary(ctx), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Category',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppTheme.textSecondary(ctx),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: categories.map((cat) {
                    final isSel = selectedCategory == cat;
                    return ChoiceChip(
                      label: Text(cat),
                      labelStyle: GoogleFonts.plusJakartaSans(
                        fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 12,
                        color: isSel
                            ? AppTheme.onPrimaryContainer(ctx)
                            : AppTheme.textSecondary(ctx),
                      ),
                      selected: isSel,
                      selectedColor: AppTheme.primaryContainer(ctx),
                      backgroundColor: AppTheme.tonal(ctx),
                      side: BorderSide(
                        color: isSel ? AppTheme.primary(ctx) : AppTheme.surfaceBorder(ctx),
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                      onSelected: (val) {
                        if (val) setModalState(() => selectedCategory = cat);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      final title = titleController.text.trim();
                      if (title.isEmpty) return;
                      Navigator.pop(ctx);

                      final newNote = QuickNoteItem(
                        id: const Uuid().v4(),
                        title: title,
                        category: selectedCategory,
                        contentSnippet: 'Tap to start writing your notes...',
                        lastUpdated: DateTime.now(),
                        isPinned: false,
                      );

                      setState(() {
                        _notes.insert(0, newNote);
                      });
                      await _saveNotesList();
                      RecentActivityService.recordActivity(
                        title: title,
                        subtitle: 'Edited quick note',
                        type: 'note',
                        targetPath: newNote.id,
                      );
                      _openNoteEditor(newNote);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary(ctx),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      'Create Note',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openNoteEditor(QuickNoteItem note) async {
    final prefs = await SharedPreferences.getInstance();
    final noteKey = 'folder_notes_${note.id}';
    final existingData = prefs.getString(noteKey);
    if (existingData == null) {
      // If note content was not yet initialized in folder_notes_${note.id},
      // initialize it from contentSnippet so NotesPage displays the content immediately!
      final snippet = note.contentSnippet.trim();
      final hasRealContent = snippet.isNotEmpty && snippet != 'Tap to start writing your notes...';
      final initialText = hasRealContent ? snippet : '';
      final delta = [
        {"insert": "$initialText\n"}
      ];
      final newFolderNote = FolderNotes(
        folderPath: note.id,
        notesContent: jsonEncode(delta),
        lastEdited: DateTime.now(),
      );
      await prefs.setString(noteKey, jsonEncode(newFolderNote.toMap()));
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NotesPage(folderPath: note.id),
      ),
    );

    // Refresh snippet after returning from editor
    final rawNote = prefs.getString('folder_notes_${note.id}');
    if (rawNote != null) {
      try {
        final map = jsonDecode(rawNote);
        final content = map['notesContent'] as String? ?? '';
        String plain = '';
        if (content.startsWith('[') || content.startsWith('{')) {
          // Delta JSON or plain JSON
          final decoded = jsonDecode(content);
          if (decoded is List) {
            plain = decoded
                .map((op) => op is Map && op.containsKey('insert') ? op['insert'].toString() : '')
                .join('')
                .trim();
          }
        } else {
          plain = content.trim();
        }

        if (plain.isNotEmpty) {
          note.contentSnippet = plain.split('\n').take(4).join('\n');
        }
        note.lastUpdated = DateTime.now();
      } catch (_) {}
    }

    _sortNotes();
    await _saveNotesList();
    await RecentActivityService.recordActivity(
      title: note.title,
      subtitle: 'Edited quick note',
      type: 'note',
      targetPath: note.id,
    );
    if (mounted) setState(() {});
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inDays == 0 && dt.day == now.day) {
      return 'Updated Today, ${DateFormat('h:mm a').format(dt)}';
    } else if (diff.inDays <= 1 || (now.day - dt.day == 1 && diff.inDays < 2)) {
      return 'Updated Yesterday';
    } else {
      return 'Updated ${DateFormat('MMM d, h:mm a').format(dt)}';
    }
  }

  Color _getCategoryColor(String cat, BuildContext context) {
    final isDark = AppTheme.isDark(context);
    switch (cat.toLowerCase()) {
      case 'scanned':
        return isDark ? const Color(0xFF2E2D64) : const Color(0xFFEDE7F6);
      case 'personal':
        return isDark ? const Color(0xFF3C2D4D) : const Color(0xFFE8DEF8); // Soft Lavender
      case 'finance':
        return isDark ? const Color(0xFF1B3B52) : const Color(0xFFC2E7FF); // Soft Sky
      case 'work':
        return isDark ? const Color(0xFF1C345C) : const Color(0xFFD3E3FD); // Soft Blue
      case 'ideas':
        return isDark ? const Color(0xFF1B3D28) : const Color(0xFFCEEAD6); // Soft Mint
      default:
        return AppTheme.tonal(context);
    }
  }

  Color _getCategoryTextColor(String cat, BuildContext context) {
    final isDark = AppTheme.isDark(context);
    switch (cat.toLowerCase()) {
      case 'scanned':
        return isDark ? const Color(0xFFC7D2FE) : const Color(0xFF4338CA);
      case 'personal':
        return isDark ? const Color(0xFFE8DEF8) : const Color(0xFF1D192B);
      case 'finance':
        return isDark ? const Color(0xFFC2E7FF) : const Color(0xFF001D35);
      case 'work':
        return isDark ? const Color(0xFFD3E3FD) : const Color(0xFF041E49);
      case 'ideas':
        return isDark ? const Color(0xFFCEEAD6) : const Color(0xFF0D652D);
      default:
        return AppTheme.textPrimary(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        backgroundColor: AppTheme.surface(context),
        elevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        leading: Container(
          margin: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: AppTheme.tonal(context),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.surfaceBorder(context), width: 1),
          ),
          child: IconButton(
            icon: Icon(
              Icons.arrow_back_rounded,
              color: AppTheme.textPrimary(context),
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Quick Notes',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: AppTheme.textPrimary(context),
              ),
            ),
            Text(
              '${_notes.length} notes stored locally',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w400,
                fontSize: 12,
                color: AppTheme.textMuted(context),
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: ElevatedButton.icon(
              onPressed: _showNewNoteDialog,
              icon: const Icon(Icons.add, size: 16),
              label: Text(
                'New Note',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary(context),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.edit_note_rounded,
                        size: 64,
                        color: AppTheme.textMuted(context).withOpacity(0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No Notes Yet',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: AppTheme.textSecondary(context),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tap "+ New Note" above to write your first note',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: AppTheme.textMuted(context),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: _notes.length,
                  itemBuilder: (context, index) {
                    final note = _notes[index];
                    return _buildNoteCard(note);
                  },
                ),
    );
  }

  Widget _buildNoteCard(QuickNoteItem note) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.surfaceBorder(context), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(AppTheme.isDark(context) ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _openNoteEditor(note),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Category chip + Pin & Delete buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getCategoryColor(note.category, context),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        note.category,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _getCategoryTextColor(note.category, context),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            note.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                            size: 18,
                            color: note.isPinned
                                ? AppTheme.primary(context)
                                : AppTheme.textMuted(context),
                          ),
                          onPressed: () => _togglePin(note),
                          tooltip: note.isPinned ? 'Unpin' : 'Pin',
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          padding: EdgeInsets.zero,
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: Color(0xFFB3261E),
                          ),
                          onPressed: () => _deleteNote(note),
                          tooltip: 'Delete Note',
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Note Title
                Text(
                  note.title,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppTheme.textPrimary(context),
                  ),
                ),

                const SizedBox(height: 6),

                // Note Content Snippet
                Text(
                  note.contentSnippet,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: AppTheme.textSecondary(context),
                    height: 1.45,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 14),

                // Footer row: Timestamp & "Pinned to Favorites" badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatTimestamp(note.lastUpdated),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: AppTheme.textMuted(context),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    if (note.isPinned)
                      Text(
                        'Pinned to Favorites',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textMuted(context),
                        ),
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

