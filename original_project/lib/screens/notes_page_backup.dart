import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:gallery_app/models/notes.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class NotesPage extends StatefulWidget {
  final String folderPath;

  const NotesPage({super.key, required this.folderPath});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  late TextEditingController _notesController;
  final FlutterTts _flutterTts = FlutterTts();
  FolderNotes? _folderNotes;
  bool _isEditing = true;
  bool _isSpeaking = false;
  double _fontSize = 16.0;

  // Auto-save timer
  Timer? _autoSaveTimer;
  bool _hasUnsavedChanges = false;

  // Search functionality
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _replaceController = TextEditingController();
  int _currentMatchIndex = -1;
  final List<TextRange> _searchMatches = [];

  // Undo/Redo functionality
  final List<String> _undoStack = [];
  final List<String> _redoStack = [];
  final int _maxHistorySize = 50;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
    _notesController.addListener(_onTextChanged);
    _initTts();
    _loadNotes();
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _flutterTts.stop();
    _saveNotes();
    _notesController.removeListener(_onTextChanged);
    _notesController.dispose();
    _searchController.dispose();
    _replaceController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {
      _hasUnsavedChanges = true;
    });

    // Cancel existing timer
    _autoSaveTimer?.cancel();

    // Start new timer for auto-save (2 seconds after typing stops)
    _autoSaveTimer = Timer(const Duration(seconds: 2), () {
      _saveNotes();
      if (mounted) {
        setState(() {
          _hasUnsavedChanges = false;
        });
      }
    });

    // Update search results if searching
    if (_isSearching) {
      _performSearch();
    }
  }

  void _pushToUndoStack() {
    if (_undoStack.isEmpty || _undoStack.last != _notesController.text) {
      _undoStack.add(_notesController.text);
      if (_undoStack.length > _maxHistorySize) {
        _undoStack.removeAt(0);
      }
      _redoStack.clear();
    }
  }

  void _undo() {
    if (_undoStack.length > 1) {
      _redoStack.add(_undoStack.removeLast());
      final previousText = _undoStack.last;
      _notesController.removeListener(_onTextChanged);
      _notesController.text = previousText;
      _notesController.addListener(_onTextChanged);
      setState(() {});
    }
  }

  void _redo() {
    if (_redoStack.isNotEmpty) {
      final nextText = _redoStack.removeLast();
      _undoStack.add(nextText);
      _notesController.removeListener(_onTextChanged);
      _notesController.text = nextText;
      _notesController.addListener(_onTextChanged);
      setState(() {});
    }
  }

  Future<void> _initTts() async {
    final prefs = await SharedPreferences.getInstance();
    final double pitch = prefs.getDouble('tts_pitch') ?? 1.0;
    final double rate = prefs.getDouble('tts_rate') ?? 0.5;
    final String? voiceName = prefs.getString('tts_voice_name');

    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(rate);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(pitch);

    if (voiceName != null) {
      try {
        final List<dynamic> voices = await _flutterTts.getVoices;
        final voice = voices.firstWhere(
          (v) => v['name'].toString() == voiceName,
          orElse: () => null,
        );
        if (voice != null) {
          await _flutterTts.setVoice({
            "name": voice["name"],
            "locale": voice["locale"],
          });
        }
      } catch (e) {
        debugPrint("Error setting voice in notes: $e");
      }
    }

    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
        });
      }
    });

    _flutterTts.setCancelHandler(() {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
        });
      }
    });

    _flutterTts.setErrorHandler((msg) {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
        });
      }
    });
  }

  Future<void> _speak() async {
    if (_notesController.text.isNotEmpty) {
      if (_isSpeaking) {
        await _flutterTts.stop();
        setState(() => _isSpeaking = false);
      } else {
        setState(() => _isSpeaking = true);
        await _flutterTts.speak(_notesController.text);
      }
    }
  }

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final notesJson = prefs.getString('folder_notes_${widget.folderPath}');
    if (notesJson != null) {
      _folderNotes = FolderNotes.fromMap(jsonDecode(notesJson));
      _notesController.text = _folderNotes!.notesContent;
    } else {
      _folderNotes = FolderNotes(folderPath: widget.folderPath);
    }
    setState(() {});
  }

  Future<void> _saveNotes({bool showSnackBar = false}) async {
    if (_folderNotes == null) return;

    final prefs = await SharedPreferences.getInstance();
    _folderNotes!.notesContent = _notesController.text;
    _folderNotes!.lastEdited = DateTime.now();
    await prefs.setString(
      'folder_notes_${widget.folderPath}',
      jsonEncode(_folderNotes!.toMap()),
    );
    if (showSnackBar && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Notes saved!', style: GoogleFonts.poppins()),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    }
    if (mounted) setState(() {});
  }

  Future<void> _clearNotes() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Clear Notes',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to clear all notes? This action cannot be undone.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text('Clear', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _notesController.clear();
        _folderNotes!.notesContent = '';
        _folderNotes!.lastEdited = null;
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('folder_notes_${widget.folderPath}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Notes cleared!', style: GoogleFonts.poppins()),
          ),
        );
      }
    }
  }

  Future<void> _shareNotes() async {
    if (_notesController.text.isNotEmpty) {
      await Share.share(
        _notesController.text,
        subject:
            'Notes for ${widget.folderPath.split(Platform.pathSeparator).last}',
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No notes to share!')));
    }
  }

  void _insertText(String text, {int offset = 0}) {
    _pushToUndoStack();
    final selection = _notesController.selection;
    final newText = _notesController.text.replaceRange(
      selection.start,
      selection.end,
      text,
    );
    _notesController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: selection.baseOffset + text.length - offset,
      ),
    );
  }

  // Search functionality
  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _replaceController.clear();
        _searchMatches.clear();
        _currentMatchIndex = -1;
      } else {
        _performSearch();
      }
    });
  }

  void _performSearch() {
    _searchMatches.clear();
    _currentMatchIndex = -1;

    if (_searchController.text.isEmpty) {
      setState(() {});
      return;
    }

    final query = _searchController.text.toLowerCase();
    final text = _notesController.text.toLowerCase();

    int index = 0;
    while (index < text.length) {
      final matchIndex = text.indexOf(query, index);
      if (matchIndex == -1) break;

      _searchMatches.add(
        TextRange(start: matchIndex, end: matchIndex + query.length),
      );
      index = matchIndex + 1;
    }

    if (_searchMatches.isNotEmpty) {
      _currentMatchIndex = 0;
      _scrollToMatch();
    }

    setState(() {});
  }

  void _findNext() {
    if (_searchMatches.isEmpty) return;

    setState(() {
      _currentMatchIndex = (_currentMatchIndex + 1) % _searchMatches.length;
      _scrollToMatch();
    });
  }

  void _findPrevious() {
    if (_searchMatches.isEmpty) return;

    setState(() {
      _currentMatchIndex = (_currentMatchIndex - 1) % _searchMatches.length;
      if (_currentMatchIndex < 0) {
        _currentMatchIndex = _searchMatches.length - 1;
      }
      _scrollToMatch();
    });
  }

  void _scrollToMatch() {
    if (_currentMatchIndex >= 0 && _currentMatchIndex < _searchMatches.length) {
      final match = _searchMatches[_currentMatchIndex];
      _notesController.selection = TextSelection(
        baseOffset: match.start,
        extentOffset: match.end,
      );
    }
  }

  void _replaceOne() {
    if (_currentMatchIndex < 0 || _searchMatches.isEmpty) return;

    _pushToUndoStack();
    final match = _searchMatches[_currentMatchIndex];
    final newText = _notesController.text.replaceRange(
      match.start,
      match.end,
      _replaceController.text,
    );

    _notesController.text = newText;
    _performSearch();
  }

  void _replaceAll() {
    if (_searchMatches.isEmpty) return;

    _pushToUndoStack();
    String newText = _notesController.text;
    final replaceText = _replaceController.text;

    // Replace from end to start to maintain indices
    for (int i = _searchMatches.length - 1; i >= 0; i--) {
      final match = _searchMatches[i];
      newText = newText.replaceRange(match.start, match.end, replaceText);
    }

    _notesController.text = newText;
    _performSearch();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Replaced ${_searchMatches.length} occurrences',
          style: GoogleFonts.poppins(),
        ),
      ),
    );
  }

  // Export functionality
  Future<void> _exportAsTxt() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'note_${DateTime.now().millisecondsSinceEpoch}.txt';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(_notesController.text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Exported to $fileName',
              style: GoogleFonts.poppins(),
            ),
            action: SnackBarAction(
              label: 'Share',
              onPressed: () => Share.shareXFiles([XFile(file.path)]),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e', style: GoogleFonts.poppins()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportAsPdf() async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Text(
                'Note',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              _notesController.text,
              style: const pw.TextStyle(fontSize: 12, lineSpacing: 1.5),
            ),
          ],
        ),
      );

      await Printing.layoutPdf(onLayout: (format) async => pdf.save());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'PDF ready to print/save',
              style: GoogleFonts.poppins(),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'PDF export failed: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Templates
  void _showTemplatesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Choose Template',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTemplateItem(
                'Meeting Notes',
                '# Meeting Notes\n\n**Date:** ${DateTime.now().toString().split(' ')[0]}\n**Attendees:** \n\n## Agenda\n- \n\n## Discussion\n\n## Action Items\n- [ ] \n\n## Next Steps\n',
                Icons.people_outline,
              ),
              _buildTemplateItem(
                'To-Do List',
                '# ${DateTime.now().toString().split(' ')[0]} Tasks\n\n## High Priority\n- [ ] \n\n## Medium Priority\n- [ ] \n\n## Low Priority\n- [ ] \n',
                Icons.checklist_rounded,
              ),
              _buildTemplateItem(
                'Journal Entry',
                '# Journal - ${DateTime.now().toString().split(' ')[0]}\n\n## Mood: \n\n## Today I...\n\n## Grateful for:\n- \n\n## Tomorrow I will:\n- \n',
                Icons.book_outlined,
              ),
              _buildTemplateItem(
                'Project Outline',
                '# Project: \n\n## Overview\n\n## Goals\n1. \n\n## Timeline\n\n## Resources Needed\n- \n\n## Notes\n',
                Icons.work_outline,
              ),
              _buildTemplateItem(
                'Code Snippet',
                '# Code Notes\n\n## Language: \n\n## Description:\n\n```\n// Your code here\n```\n\n## Usage:\n\n## References:\n- ',
                Icons.code_rounded,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateItem(String title, String template, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).primaryColor),
      title: Text(title, style: GoogleFonts.poppins()),
      onTap: () {
        _pushToUndoStack();
        if (_notesController.text.isNotEmpty) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text('Replace Content?', style: GoogleFonts.poppins()),
              content: Text(
                'This will replace your current notes. Continue?',
                style: GoogleFonts.poppins(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel', style: GoogleFonts.poppins()),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _notesController.text = template;
                    Navigator.pop(context);
                  },
                  child: Text('Replace', style: GoogleFonts.poppins()),
                ),
              ],
            ),
          );
        } else {
          _notesController.text = template;
          Navigator.pop(context);
        }
      },
    );
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _notesController.text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied to clipboard', style: GoogleFonts.poppins()),
      ),
    );
  }

  int get _wordCount {
    if (_notesController.text.isEmpty) return 0;
    return _notesController.text.trim().split(RegExp(r'\s+')).length;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF1E1E1E)
          : const Color(0xFFF7F9FC), // Softer background
      appBar: AppBar(
        backgroundColor: const Color(0xFF66FFFF),
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF66FFFF), Color(0xFF33CCCC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: Container(
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: Colors.black87,
              size: 22,
            ),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
          ),
        ),
        title: Column(
          children: [
            Text(
              _folderNotes?.folderPath.split(Platform.pathSeparator).last ??
                  'Note',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 19,
                color: Colors.black87,
                letterSpacing: -0.3,
              ),
            ),
            if (_folderNotes?.lastEdited != null)
              Text(
                'Edited ${DateTime.now().difference(_folderNotes!.lastEdited!).inMinutes < 60 ? "Just now" : _folderNotes!.lastEdited!.toString().substring(0, 16)}',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w400,
                  fontSize: 12,
                  color: Colors.black.withOpacity(0.6),
                ),
              ),
          ],
        ),
        centerTitle: true,
        actions: [
          // Undo/Redo buttons
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.undo_rounded),
              color: _undoStack.length > 1 ? Colors.black87 : Colors.black38,
              onPressed: _undoStack.length > 1 ? _undo : null,
              tooltip: 'Undo',
            ),
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.redo_rounded),
              color: _redoStack.isNotEmpty ? Colors.black87 : Colors.black38,
              onPressed: _redoStack.isNotEmpty ? _redo : null,
              tooltip: 'Redo',
            ),
          // Search button
          IconButton(
            icon: Icon(
              _isSearching ? Icons.search_off_rounded : Icons.search_rounded,
            ),
            color: Colors.black87,
            onPressed: _toggleSearch,
            tooltip: 'Search',
          ),
          // Auto-save indicator
          if (_hasUnsavedChanges)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: Center(
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          // Edit/Preview toggle
          IconButton(
            icon: Icon(
              _isEditing ? Icons.visibility_outlined : Icons.edit_outlined,
            ),
            color: Colors.black87,
            onPressed: () {
              setState(() {
                if (_isEditing) _saveNotes(showSnackBar: true);
                _isEditing = !_isEditing;
              });
            },
            tooltip: _isEditing ? 'Preview Mode' : 'Edit Mode',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz_rounded, color: Colors.black87),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onSelected: (value) {
              switch (value) {
                case 'templates':
                  _showTemplatesDialog();
                  break;
                case 'export_txt':
                  _exportAsTxt();
                  break;
                case 'export_pdf':
                  _exportAsPdf();
                  break;
                case 'share':
                  _shareNotes();
                  break;
                case 'copy':
                  _copyToClipboard();
                  break;
                case 'clear':
                  _clearNotes();
                  break;
                case 'font_size':
                  _showFontSizeDialog();
                  break;
                case 'speak':
                  _speak();
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              _buildPopupMenuItem(
                'templates',
                'Templates',
                Icons.description_outlined,
              ),
              const PopupMenuDivider(),
              _buildPopupMenuItem(
                'export_txt',
                'Export as TXT',
                Icons.text_snippet_outlined,
              ),
              _buildPopupMenuItem(
                'export_pdf',
                'Export as PDF',
                Icons.picture_as_pdf_outlined,
              ),
              const PopupMenuDivider(),
              _buildPopupMenuItem(
                'speak',
                _isSpeaking ? 'Stop Reading' : 'Read Aloud',
                Icons.record_voice_over_rounded,
              ),
              _buildPopupMenuItem(
                'font_size',
                'Text Size',
                Icons.text_fields_rounded,
              ),
              const PopupMenuDivider(),
              _buildPopupMenuItem(
                'share',
                'Share Note',
                Icons.ios_share_rounded,
              ),
              _buildPopupMenuItem('copy', 'Copy Text', Icons.copy_rounded),
              const PopupMenuDivider(),
              _buildPopupMenuItem(
                'clear',
                'Clear Note',
                Icons.delete_outline_rounded,
                color: Colors.redAccent,
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          if (_isSearching)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search...',
                            hintStyle: GoogleFonts.inter(fontSize: 14),
                            prefixIcon: const Icon(Icons.search, size: 20),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Theme.of(
                              context,
                            ).scaffoldBackgroundColor,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            isDense: true,
                          ),
                          style: GoogleFonts.inter(fontSize: 14),
                          onChanged: (_) => _performSearch(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.arrow_upward_rounded, size: 20),
                        onPressed: _searchMatches.isNotEmpty
                            ? _findPrevious
                            : null,
                        tooltip: 'Previous',
                        visualDensity: VisualDensity.compact,
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_downward_rounded,
                          size: 20,
                        ),
                        onPressed: _searchMatches.isNotEmpty ? _findNext : null,
                        tooltip: 'Next',
                        visualDensity: VisualDensity.compact,
                      ),
                      if (_searchMatches.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            '${_currentMatchIndex + 1}/${_searchMatches.length}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _replaceController,
                          decoration: InputDecoration(
                            hintText: 'Replace with...',
                            hintStyle: GoogleFonts.inter(fontSize: 14),
                            prefixIcon: const Icon(
                              Icons.find_replace_rounded,
                              size: 20,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Theme.of(
                              context,
                            ).scaffoldBackgroundColor,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            isDense: true,
                          ),
                          style: GoogleFonts.inter(fontSize: 14),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: _searchMatches.isNotEmpty
                            ? _replaceOne
                            : null,
                        icon: const Icon(Icons.done, size: 18),
                        label: Text(
                          'Replace',
                          style: GoogleFonts.inter(fontSize: 13),
                        ),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _searchMatches.isNotEmpty
                            ? _replaceAll
                            : null,
                        icon: const Icon(Icons.done_all, size: 18),
                        label: Text(
                          'All',
                          style: GoogleFonts.inter(fontSize: 13),
                        ),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          // Tags Strip
          if (_folderNotes != null)
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ActionChip(
                    avatar: Icon(
                      Icons.add,
                      size: 16,
                      color: Theme.of(context).primaryColor,
                    ),
                    label: Text(
                      "Tag",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    onPressed: _showAddTagDialog,
                    backgroundColor: Theme.of(
                      context,
                    ).primaryColor.withOpacity(0.1),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ..._folderNotes!.tags.map(
                    (tag) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InputChip(
                        label: Text(
                          tag,
                          style: GoogleFonts.poppins(fontSize: 12),
                        ),
                        onDeleted: _isEditing
                            ? () {
                                setState(() {
                                  _folderNotes!.tags.remove(tag);
                                  _saveNotes();
                                });
                              }
                            : null,
                        backgroundColor: Theme.of(context).cardTheme.color,
                        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                        deleteIconColor: Colors.grey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (_isEditing) _buildFormatToolbar(),

          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    spreadRadius: 0,
                    blurRadius: 15,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                child: _isEditing
                    ? TextField(
                        controller: _notesController,
                        maxLines: null,
                        expands: true,
                        keyboardType: TextInputType.multiline,
                        textAlignVertical: TextAlignVertical.top,
                        style: GoogleFonts.inter(
                          fontSize: _fontSize,
                          height: 1.65,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                          fontWeight: FontWeight.w400,
                        ),
                        cursorColor: Theme.of(context).primaryColor,
                        cursorWidth: 2,
                        decoration: InputDecoration(
                          hintText: 'Start writing your notes...',
                          hintStyle: GoogleFonts.inter(
                            color: Colors.grey.withOpacity(0.4),
                            fontStyle: FontStyle.italic,
                            fontSize: _fontSize,
                          ),
                          filled: true,
                          fillColor: Theme.of(context).cardTheme.color,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 28,
                          ),
                        ),
                        onChanged: (v) => setState(() {}),
                      )
                    : Markdown(
                        data: _notesController.text.isEmpty
                            ? '# Start writing\n\nYour notes will appear here in preview mode.'
                            : _notesController.text,
                        selectable: true,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 28,
                        ),
                        styleSheet:
                            MarkdownStyleSheet.fromTheme(
                              Theme.of(context),
                            ).copyWith(
                              p: GoogleFonts.inter(
                                fontSize: _fontSize,
                                height: 1.65,
                                fontWeight: FontWeight.w400,
                              ),
                              h1: GoogleFonts.inter(
                                fontSize: _fontSize + 10,
                                fontWeight: FontWeight.w800,
                                height: 1.3,
                                letterSpacing: -0.5,
                              ),
                              h2: GoogleFonts.inter(
                                fontSize: _fontSize + 6,
                                fontWeight: FontWeight.w700,
                                height: 1.3,
                                letterSpacing: -0.3,
                              ),
                              h3: GoogleFonts.inter(
                                fontSize: _fontSize + 3,
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                              ),
                              listBullet: GoogleFonts.inter(
                                fontSize: _fontSize,
                                height: 1.65,
                              ),
                              code: GoogleFonts.jetBrainsMono(
                                fontSize: _fontSize - 2,
                                backgroundColor: Colors.grey.withOpacity(0.1),
                              ),
                              blockquoteDecoration: BoxDecoration(
                                border: Border(
                                  left: BorderSide(
                                    color: Theme.of(context).primaryColor,
                                    width: 4,
                                  ),
                                ),
                                color: Theme.of(
                                  context,
                                ).primaryColor.withOpacity(0.05),
                                borderRadius: const BorderRadius.only(
                                  topRight: Radius.circular(4),
                                  bottomRight: Radius.circular(4),
                                ),
                              ),
                            ),
                      ),
              ),
            ),
          ),
          _buildStatusBar(),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildPopupMenuItem(
    String value,
    String text,
    IconData icon, {
    Color? color,
  }) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Text(
            text,
            style: GoogleFonts.poppins(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddTagDialog() {
    String newTag = '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Add Tag',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Tag name (e.g. Work, Ideas)',
          ),
          onChanged: (v) => newTag = v,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (newTag.trim().isNotEmpty) {
                setState(() {
                  _folderNotes?.tags.add(newTag.trim());
                  _saveNotes();
                });
              }
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatToolbar() {
    return Container(
      height: 54,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _FormatButton(
            icon: Icons.format_bold,
            onTap: () => _insertText('**text**', offset: 6),
            tooltip: 'Bold (Ctrl+B)',
          ),
          _FormatButton(
            icon: Icons.format_italic,
            onTap: () => _insertText('*text*', offset: 5),
            tooltip: 'Italic (Ctrl+I)',
          ),
          _FormatButton(
            icon: Icons.format_underline_rounded,
            onTap: () => _insertText('__text__', offset: 6),
            tooltip: 'Underline (Ctrl+U)',
          ),
          _FormatButton(
            icon: Icons.strikethrough_s_rounded,
            onTap: () => _insertText('~~text~~', offset: 6),
            tooltip: 'Strikethrough',
          ),
          _FormatButton(
            icon: Icons.highlight_rounded,
            onTap: () => _insertText('==text==', offset: 6),
            tooltip: 'Highlight',
          ),
          const VerticalDivider(indent: 12, endIndent: 12),
          _FormatButton(
            icon: Icons.title,
            onTap: () => _insertText('# ', offset: 0),
            tooltip: 'Header 1',
          ),
          _FormatButton(
            icon: Icons.format_size_rounded,
            onTap: () => _insertText('## ', offset: 0),
            tooltip: 'Header 2',
          ),
          const VerticalDivider(indent: 12, endIndent: 12),
          _FormatButton(
            icon: Icons.format_list_bulleted_rounded,
            onTap: () => _insertText('\n- ', offset: 0),
            tooltip: 'Bullet List',
          ),
          _FormatButton(
            icon: Icons.format_list_numbered_rounded,
            onTap: () => _insertText('\n1. ', offset: 0),
            tooltip: 'Numbered List',
          ),
          _FormatButton(
            icon: Icons.check_box_outlined,
            onTap: () => _insertText('\n- [ ] ', offset: 0),
            tooltip: 'Checklist',
          ),
          const VerticalDivider(indent: 12, endIndent: 12),
          _FormatButton(
            icon: Icons.format_quote_rounded,
            onTap: () => _insertText('\n> ', offset: 0),
            tooltip: 'Quote',
          ),
          _FormatButton(
            icon: Icons.code_rounded,
            onTap: () => _insertText('`text`', offset: 5),
            tooltip: 'Inline Code',
          ),
          _FormatButton(
            icon: Icons.code_off_rounded,
            onTap: () => _insertText('\\n```\\ncode\\n```\\n', offset: 0),
            tooltip: 'Code Block',
          ),
          _FormatButton(
            icon: Icons.link_rounded,
            onTap: () => _insertText('[text](url)', offset: 6),
            tooltip: 'Link',
          ),
          const VerticalDivider(indent: 12, endIndent: 12),
          _FormatButton(
            icon: Icons.horizontal_rule_rounded,
            onTap: () => _insertText('\n---\n', offset: 0),
            tooltip: 'Divider',
          ),
          _FormatButton(
            icon: Icons.table_chart_outlined,
            onTap: () => _insertText(
              '\n| Column 1 | Column 2 |\n|----------|----------|\n| Data 1   | Data 2   |\n',
              offset: 0,
            ),
            tooltip: 'Table',
          ),
          _FormatButton(
            icon: Icons.emoji_emotions_outlined,
            onTap: () => _insertText('😀', offset: 0),
            tooltip: 'Emoji',
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    int readTime = (_wordCount / 200).ceil();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.08),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.article_outlined, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(
            '$_wordCount words',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 20),
          Icon(Icons.schedule_outlined, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(
            '$readTime min read',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            '${_notesController.text.length} chars',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showFontSizeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Text Size',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Slider(
                  value: _fontSize,
                  min: 12.0,
                  max: 30.0,
                  divisions: 9,
                  label: _fontSize.round().toString(),
                  onChanged: (value) {
                    setState(() => _fontSize = value);
                    this.setState(() {}); // Update parent widget
                  },
                ),
                Text(
                  'Sample Text',
                  style: GoogleFonts.poppins(fontSize: _fontSize),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Done', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }
}

class _FormatButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  const _FormatButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        icon: Icon(icon, size: 21),
        onPressed: onTap,
        tooltip: tooltip,
        color: Theme.of(context).primaryColor,
        splashRadius: 22,
        padding: const EdgeInsets.all(8),
      ),
    );
  }
}
