
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:gallery_app/models/notes.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:gallery_app/theme/app_theme.dart';
import 'package:gallery_app/services/recent_activity_service.dart';

class NotesPage extends StatefulWidget {
  final String folderPath;

  const NotesPage({super.key, required this.folderPath});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  late quill.QuillController _quillController;
  final FocusNode _focusNode = FocusNode();
  final FlutterTts _flutterTts = FlutterTts();
  FolderNotes? _folderNotes;
  bool _isSpeaking = false;

  // Auto-save timer
  Timer? _autoSaveTimer;

  // Search functionality
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  int _currentMatchIndex = -1;
  int _totalMatches = 0;

  // Status metrics & Unsaved status (using ValueNotifier to avoid page-wide setState)
  final ValueNotifier<bool> _unsavedNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<int> _wordCountNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> _charCountNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> _readTimeNotifier = ValueNotifier<int>(0);

  // Undo/Redo
  final List<String> _history = [];
  int _historyIndex = -1;
  bool _isPreviewMode = false;

  @override
  void initState() {
    super.initState();
    _quillController = quill.QuillController.basic();
    
    // Use stream listener for changes to avoid lag from cursor movements
    _quillController.changes.listen((change) {
      if (change.source == quill.ChangeSource.local) {
        _onTextChanged();
      }
    });
    
    _initTts();
    _loadNotes();
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _flutterTts.stop();
    _saveNotes();
    // Stream listener doesn't need manual removal if the controller is disposed
    _quillController.dispose();
    _focusNode.dispose();
    _searchController.dispose();
    _unsavedNotifier.dispose();
    _wordCountNotifier.dispose();
    _charCountNotifier.dispose();
    _readTimeNotifier.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    _updateMetrics();
    
    if (!_unsavedNotifier.value) {
      _unsavedNotifier.value = true;
    }

    // Cancel existing timer
    _autoSaveTimer?.cancel();

    // Start new timer for auto-save (2 seconds after typing stops)
    _autoSaveTimer = Timer(const Duration(seconds: 2), () {
      _saveNotes();
      if (mounted) {
        _unsavedNotifier.value = false;
      }
    });
  }

  void _updateMetrics() {
    final text = _quillController.document.toPlainText();
    _charCountNotifier.value = text.length;
    _wordCountNotifier.value = text.isEmpty ? 0 : text.trim().split(RegExp(r'\s+')).length;
    _readTimeNotifier.value = (_wordCountNotifier.value / 200).ceil();
  }

  void _pushToHistory() {
    // Remove any history after current index
    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }

    _history.add(_quillController.document.toPlainText());
    if (_history.length > 50) {
      _history.removeAt(0);
    } else {
      _historyIndex++;
    }
  }

  void _undo() {
    if (_quillController.hasUndo) {
      _quillController.undo();
      setState(() {});
    }
  }

  void _redo() {
    if (_quillController.hasRedo) {
      _quillController.redo();
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
      if (mounted) setState(() => _isSpeaking = false);
    });

    _flutterTts.setCancelHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });

    _flutterTts.setErrorHandler((msg) {
      if (mounted) setState(() => _isSpeaking = false);
    });
  }

  Future<void> _speak() async {
    final text = _quillController.document.toPlainText();
    if (text.isNotEmpty) {
      if (_isSpeaking) {
        await _flutterTts.stop();
        setState(() => _isSpeaking = false);
      } else {
        setState(() => _isSpeaking = true);
        await _flutterTts.speak(text);
      }
    }
  }

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final notesJson = prefs.getString('folder_notes_${widget.folderPath}');

    if (notesJson != null) {
      try {
        _folderNotes = FolderNotes.fromMap(jsonDecode(notesJson));
        final content = _folderNotes!.notesContent;
        
        // Try parsing as Delta (JSON)
        try {
          final deltaJson = jsonDecode(content);
          if (deltaJson is List) {
            _quillController.document = quill.Document.fromJson(deltaJson);
          } else {
            _quillController.document = quill.Document()..insert(0, content);
          }
        } catch (e) {
          // If not JSON, it's old plain text notes
          _quillController.document = quill.Document()..insert(0, content);
        }
      } catch (e) {
        _folderNotes = FolderNotes(folderPath: widget.folderPath);
      }
    } else {
      _folderNotes = FolderNotes(folderPath: widget.folderPath);
    }

    _updateMetrics();
    setState(() {});
  }

  Future<void> _saveNotes({bool showSnackBar = false}) async {
    if (_folderNotes == null) return;

    final prefs = await SharedPreferences.getInstance();
    _folderNotes!.notesContent = jsonEncode(_quillController.document.toDelta().toJson());
    _folderNotes!.lastEdited = DateTime.now();

    await prefs.setString(
      'folder_notes_${widget.folderPath}',
      jsonEncode(_folderNotes!.toMap()),
    );

    // Keep Recent Activity updated with this note
    try {
      String noteTitle = 'Quick Note';
      final quickNotesRaw = prefs.getString('hub_quick_notes_list_v1');
      if (quickNotesRaw != null) {
        final List list = jsonDecode(quickNotesRaw);
        for (var item in list) {
          if (item is Map && item['id'] == widget.folderPath) {
            noteTitle = item['title'] ?? 'Quick Note';
            break;
          }
        }
      }
      if (noteTitle == 'Quick Note' && widget.folderPath.isNotEmpty && widget.folderPath != 'quick_notes') {
        final sep = Platform.pathSeparator;
        final clean = widget.folderPath.endsWith(sep)
            ? widget.folderPath.substring(0, widget.folderPath.length - 1)
            : widget.folderPath;
        final parts = clean.split(sep);
        if (parts.isNotEmpty && parts.last.isNotEmpty) {
          noteTitle = '${parts.last} Notes';
        }
      }
      await RecentActivityService.recordActivity(
        title: noteTitle,
        subtitle: 'Edited quick note',
        type: 'note',
        targetPath: widget.folderPath,
      );
    } catch (_) {}

    if (showSnackBar && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Notes saved!', style: GoogleFonts.poppins()),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
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
      _pushToHistory();
      setState(() {
        _quillController.clear();
        _folderNotes!.notesContent = '';
        _folderNotes!.lastEdited = null;
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('folder_notes_${widget.folderPath}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Notes cleared!', style: GoogleFonts.poppins()),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _shareNotes() async {
    final text = _quillController.document.toPlainText();
    if (text.isNotEmpty) {
      await Share.share(
        text,
        subject:
            'Notes for ${widget.folderPath.split(Platform.pathSeparator).last}',
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(
        content: Text('No notes to share!'),
        duration: Duration(seconds: 3),
      ));
    }
  }

  void _copyToClipboard() {
    final text = _quillController.document.toPlainText();
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied to clipboard', style: GoogleFonts.poppins()),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Search functionality
  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _currentMatchIndex = -1;
        _totalMatches = 0;
      }
    });
  }

  void _performSearch() {
    if (_searchController.text.isEmpty) {
      setState(() {
        _currentMatchIndex = -1;
        _totalMatches = 0;
      });
      return;
    }

    final text = _quillController.document.toPlainText().toLowerCase();
    final query = _searchController.text.toLowerCase();

    _totalMatches = query.allMatches(text).length;

    if (_totalMatches > 0) {
      _currentMatchIndex = 0;
    } else {
      _currentMatchIndex = -1;
    }

    setState(() {});
  }

  // Export functionality
  Future<void> _exportAsTxt() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'note_${DateTime.now().millisecondsSinceEpoch}.txt';
      final filePath = '${directory.path}/$fileName';
      final text = _quillController.document.toPlainText();
      final file = File(filePath);
      await file.writeAsString(text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Exported to $fileName',
              style: GoogleFonts.poppins(),
            ),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Share',
              onPressed: () => Share.shareXFiles([XFile(filePath)]),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e', style: GoogleFonts.poppins()),
            duration: const Duration(seconds: 3),
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
              _quillController.document.toPlainText(),
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
            duration: const Duration(seconds: 3),
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
            duration: const Duration(seconds: 3),
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
                'Meeting Notes\n\nDate: ${DateTime.now().toString().split(' ')[0]}\nAttendees: \n\nAgenda\n• \n\nDiscussion\n\nAction Items\n☐ \n\nNext Steps\n',
                Icons.people_outline,
              ),
              _buildTemplateItem(
                'To-Do List',
                '${DateTime.now().toString().split(' ')[0]} Tasks\n\nHigh Priority\n☐ \n\nMedium Priority\n☐ \n\nLow Priority\n☐ ',
                Icons.checklist_rounded,
              ),
              _buildTemplateItem(
                'Journal Entry',
                'Journal - ${DateTime.now().toString().split(' ')[0]}\n\nMood: \n\nToday I...\n\nGrateful for:\n• \n\nTomorrow I will:\n• ',
                Icons.book_outlined,
              ),
              _buildTemplateItem(
                'Project Outline',
                'Project: \n\nOverview\n\nGoals\n1. \n\nTimeline\n\nResources Needed\n• \n\nNotes\n',
                Icons.work_outline,
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
        if (_quillController.document.toPlainText().isNotEmpty) {
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
                    _pushToHistory();
                    _quillController.document = quill.Document()..insert(0, template);
                    Navigator.pop(context);
                  },
                  child: Text('Replace', style: GoogleFonts.poppins()),
                ),
              ],
            ),
          );
        } else {
          _pushToHistory();
          _quillController.document = quill.Document()..insert(0, template);
          Navigator.pop(context);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final appBarTextColor = AppTheme.textPrimary(context);
    final appBarIconBg = AppTheme.tonal(context);
    final appBarIconBorder = AppTheme.surfaceBorder(context);

    return Scaffold(
      extendBodyBehindAppBar: false,
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        backgroundColor: AppTheme.surface(context),
        elevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        leading: Container(
          margin: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: appBarIconBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: appBarIconBorder, width: 1),
          ),
          child: IconButton(
            icon: Icon(
              Icons.arrow_back_rounded,
              color: appBarTextColor,
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
              _folderNotes?.folderPath.split(Platform.pathSeparator).last ??
                  'Notes',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: appBarTextColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (_folderNotes?.lastEdited != null)
              Text(
                'Edited ${DateTime.now().difference(_folderNotes!.lastEdited!).inMinutes < 60 ? "Just now" : _folderNotes!.lastEdited!.toString().substring(0, 16)}',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w400,
                  fontSize: 11,
                  color: AppTheme.textMuted(context),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          // Undo button
          IconButton(
            icon: const Icon(Icons.undo_rounded, size: 20),
            color: _quillController.hasUndo
                ? appBarTextColor
                : appBarTextColor.withOpacity(0.35),
            onPressed: _quillController.hasUndo ? _undo : null,
            tooltip: 'Undo',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          // Redo button
          IconButton(
            icon: const Icon(Icons.redo_rounded, size: 20),
            color: _quillController.hasRedo
                ? appBarTextColor
                : appBarTextColor.withOpacity(0.35),
            onPressed: _quillController.hasRedo ? _redo : null,
            tooltip: 'Redo',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          // Preview button
          IconButton(
            icon: Icon(_isPreviewMode ? Icons.edit_note_rounded : Icons.visibility_rounded, size: 20),
            color: appBarTextColor,
            onPressed: () => setState(() => _isPreviewMode = !_isPreviewMode),
            tooltip: _isPreviewMode ? 'Edit Mode' : 'Preview Mode',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          // Save button
          IconButton(
            icon: const Icon(Icons.save_rounded, size: 20),
            color: AppTheme.primary(context),
            onPressed: () => _saveNotes(showSnackBar: true),
            tooltip: 'Save Notes',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          // Menu button
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: appBarTextColor, size: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onSelected: (value) {
              switch (value) {
                case 'search':
                  _toggleSearch();
                  break;
                case 'pin':
                  if (_folderNotes != null) {
                    setState(() {
                      _folderNotes!.isPinned = !_folderNotes!.isPinned;
                      _saveNotes();
                    });
                  }
                  break;
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
                case 'speak':
                  _speak();
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              _buildPopupMenuItem(
                'search',
                _isSearching ? 'Close Search' : 'Search Notes',
                Icons.search_rounded,
              ),
              _buildPopupMenuItem(
                'pin',
                _folderNotes?.isPinned == true ? 'Unpin Note' : 'Pin Note',
                _folderNotes?.isPinned == true ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                color: _folderNotes?.isPinned == true ? Colors.orange : null,
              ),
              const PopupMenuDivider(),
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
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomRight,
                  colors: [
                    isDark ? const Color(0xFF000000) : const Color(0xFFF8FAFC),
                    isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF1F5F9),
                    isDark ? const Color(0xFF000000) : const Color(0xFFF8FAFC),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
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
                    child: Row(
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
                        if (_totalMatches > 0)
                          Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: Text(
                              '${_currentMatchIndex + 1}/$_totalMatches',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                // Tags & Info Strip
                if (_folderNotes != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      border: Border(
                        bottom: BorderSide(
                          color: Theme.of(context).dividerColor.withOpacity(0.05),
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 36,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              ActionChip(
                                avatar: Icon(
                                  Icons.add,
                                  size: 14,
                                  color: Theme.of(context).primaryColor,
                                ),
                                label: Text(
                                  "Tag",
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                                padding: EdgeInsets.zero,
                                onPressed: _showAddTagDialog,
                                backgroundColor: Theme.of(context).primaryColor.withOpacity(0.08),
                                side: BorderSide.none,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ..._folderNotes!.tags.map(
                                (tag) => Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: InputChip(
                                    label: Text(
                                      tag,
                                      style: GoogleFonts.poppins(fontSize: 11),
                                    ),
                                    onDeleted: () {
                                      setState(() {
                                        _folderNotes!.tags.remove(tag);
                                        _saveNotes();
                                      });
                                    },
                                    backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                                    side: BorderSide.none,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.query_stats_rounded, size: 12, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            ValueListenableBuilder<int>(
                              valueListenable: _wordCountNotifier,
                              builder: (context, words, _) => ValueListenableBuilder<int>(
                                valueListenable: _readTimeNotifier,
                                builder: (context, time, _) => ValueListenableBuilder<int>(
                                  valueListenable: _charCountNotifier,
                                  builder: (context, chars, _) => Text(
                                    '$words words  •  $time min read  •  $chars chars',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: Colors.grey.shade500,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const Spacer(),
                            ValueListenableBuilder<bool>(
                              valueListenable: _unsavedNotifier,
                              builder: (context, unsaved, _) {
                                if (!unsaved) return const SizedBox.shrink();
                                return Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: Colors.orange,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Unsaved',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        color: Colors.orange.shade700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                // Text Editor Area
                Expanded(
                  child: Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: _isPreviewMode
                        ? Markdown(
                            data: _quillController.document.toPlainText(),
                            onTapLink: (text, href, title) {
                              if (href != null) {
                                launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication);
                              }
                            },
                            styleSheet: MarkdownStyleSheet(
                              p: GoogleFonts.poppins(
                                fontSize: 16,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              h1: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              a: const TextStyle(
                                color: Colors.blue,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          )
                        : Localizations(
                            locale: const Locale('en'),
                            delegates: const [
                              GlobalMaterialLocalizations.delegate,
                              GlobalWidgetsLocalizations.delegate,
                              GlobalCupertinoLocalizations.delegate,
                              quill.FlutterQuillLocalizations.delegate,
                            ],
                            child: quill.QuillEditor.basic(
                              key: const ValueKey('notes_quill_editor_core'),
                              controller: _quillController,
                              config: const quill.QuillEditorConfig(
                                autoFocus: false,
                                expands: true,
                                padding: EdgeInsets.fromLTRB(20, 16, 20, 24),
                                placeholder: 'Start writing your notes...',
                                scrollable: true,
                              ),
                            ),
                          ),
                  ),
                ),

                // Formatting Toolbar (Only show in edit mode)
                if (!_isPreviewMode)
                  NotesFormattingToolbar(
                    key: const ValueKey('notes_formatting_toolbar_wrapper'),
                    controller: _quillController,
                  ),
              ],
            ),
          ),
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


  Widget _buildAppBarAction({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    required Color color,
  }) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, color: color, size: 22),
        onPressed: onPressed,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

class NotesFormattingToolbar extends StatelessWidget {
  final quill.QuillController controller;

  const NotesFormattingToolbar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Theme(
      data: Theme.of(context).copyWith(
        canvasColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        primaryColor: Theme.of(context).primaryColor,
        colorScheme: Theme.of(context).colorScheme.copyWith(
          primary: Theme.of(context).primaryColor,
          onPrimary: Colors.white,
          secondaryContainer: Theme.of(context).primaryColor.withOpacity(0.15),
          onSecondaryContainer: Theme.of(context).primaryColor,
          surface: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          onSurface: isDark ? Colors.white : Colors.black,
        ),
      ),
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).dividerColor.withOpacity(0.12),
              ),
            ),
          ),
          child: Localizations(
            locale: const Locale('en'),
            delegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              quill.FlutterQuillLocalizations.delegate,
            ],
            child: quill.QuillSimpleToolbar(
              key: const ValueKey('notes_quill_simple_toolbar_instance'),
              controller: controller,
              config: const quill.QuillSimpleToolbarConfig(
                showAlignmentButtons: true,
                showQuote: false,
                showLink: true,
                showCodeBlock: true,
                showSearchButton: false,
                showSubscript: false,
                showSuperscript: false,
                showSmallButton: false,
                showInlineCode: true,
                showFontFamily: false,
                showFontSize: false,
                multiRowsDisplay: false,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

