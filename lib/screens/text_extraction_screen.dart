import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:gallery_app/services/text_extraction_service.dart';
import 'package:gallery_app/screens/text_to_pdf_screen.dart';
import 'package:gallery_app/theme/app_theme.dart';
import 'package:gallery_app/widgets/folder_picker_dialog.dart';
import 'package:gallery_app/widgets/optimized_image.dart';
import 'package:gallery_app/models/quick_note_item.dart';
import 'package:gallery_app/models/notes.dart';
import 'package:gallery_app/services/recent_activity_service.dart';

enum EditorViewMode {
  editorOnly,
  splitView,
}

class TextExtractionScreen extends StatefulWidget {
  final String? initialImagePath;
  final List<String>? initialImagePaths;
  final String? autoExtractTitle;

  const TextExtractionScreen({
    super.key,
    this.initialImagePath,
    this.initialImagePaths,
    this.autoExtractTitle,
  });

  @override
  State<TextExtractionScreen> createState() => _TextExtractionScreenState();
}

class _TextExtractionScreenState extends State<TextExtractionScreen> {
  final TextExtractionService _service = TextExtractionService();
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final FlutterTts _flutterTts = FlutterTts();

  List<String> _imagePaths = [];
  bool _isLoading = false;
  String _statusMessage = '';
  int _selectedPreviewIndex = 0;
  double _fontSize = 15.0;
  EditorViewMode _viewMode = EditorViewMode.editorOnly;
  bool _isPlayingTts = false;

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.autoExtractTitle ?? 'Extracted Document';
    if (widget.initialImagePaths != null && widget.initialImagePaths!.isNotEmpty) {
      _imagePaths = List.from(widget.initialImagePaths!);
      _processImages(_imagePaths);
    } else if (widget.initialImagePath != null && widget.initialImagePath!.isNotEmpty) {
      _imagePaths = [widget.initialImagePath!];
      _processImages(_imagePaths);
    }

    _flutterTts.setCompletionHandler(() {
      if (mounted) setState(() => _isPlayingTts = false);
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _titleController.dispose();
    _focusNode.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  int get _wordCount {
    final text = _textController.text.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
  }

  int get _charCount => _textController.text.length;

  Future<void> _processImages(List<String> paths) async {
    if (paths.isEmpty) return;
    setState(() {
      _isLoading = true;
      _statusMessage = 'Analyzing ${paths.length} ${paths.length == 1 ? "page" : "pages"} & extracting text...';
    });

    try {
      final result = await _service.extractTextFromMultiple(paths);
      if (mounted) {
        setState(() {
          _imagePaths = paths;
          _selectedPreviewIndex = 0;
          _textController.text = result.text;
          _isLoading = false;
        });

        if (result.text.isEmpty) {
          Fluttertoast.showToast(
            msg: "No text detected. Ensure the document is clear and well-lit.",
            backgroundColor: Colors.amber.shade800,
          );
        } else {
          Fluttertoast.showToast(
            msg: "Text extracted successfully!",
            backgroundColor: const Color(0xFF10B981),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        Fluttertoast.showToast(msg: "Error extracting text: $e", backgroundColor: Colors.red);
      }
    }
  }

  Future<void> _scanDocument({bool append = false}) async {
    setState(() {
      _isLoading = true;
      _statusMessage = append ? 'Scanning additional pages...' : 'Launching document scanner...';
    });
    try {
      final result = await _service.scanAndExtract();
      if (!mounted) return;
      if (result != null && result.imagePaths.isNotEmpty) {
        if (append && _imagePaths.isNotEmpty) {
          final int startPage = _imagePaths.length + 1;
          final updatedPaths = List<String>.from(_imagePaths)..addAll(result.imagePaths);
          final buffer = StringBuffer(_textController.text.trim());
          if (result.text.isNotEmpty) {
            if (buffer.isNotEmpty) buffer.writeln('\n\n--- Page $startPage ---');
            buffer.writeln(result.text);
          }
          setState(() {
            _imagePaths = updatedPaths;
            _selectedPreviewIndex = _imagePaths.length - result.imagePaths.length;
            _textController.text = buffer.toString().trim();
            _isLoading = false;
          });
          Fluttertoast.showToast(
            msg: "Added ${result.imagePaths.length} scanned page(s) to document!",
            backgroundColor: const Color(0xFF10B981),
          );
        } else {
          setState(() {
            _imagePaths = result.imagePaths;
            _selectedPreviewIndex = 0;
            _textController.text = result.text;
            _isLoading = false;
          });
          if (result.text.isEmpty) {
            Fluttertoast.showToast(msg: "No text detected in scanned pages.", backgroundColor: Colors.amber.shade800);
          } else {
            Fluttertoast.showToast(msg: "Text extracted successfully!", backgroundColor: const Color(0xFF10B981));
          }
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        Fluttertoast.showToast(msg: "Scanner error: $e");
      }
    }
  }

  Future<void> _pickFromGallery({bool append = false}) async {
    setState(() {
      _isLoading = true;
      _statusMessage = append ? 'Selecting more images from gallery...' : 'Selecting images from gallery...';
    });
    try {
      final result = await _service.pickFromGalleryAndExtract();
      if (!mounted) return;
      if (result != null && result.imagePaths.isNotEmpty) {
        if (append && _imagePaths.isNotEmpty) {
          final int startPage = _imagePaths.length + 1;
          final updatedPaths = List<String>.from(_imagePaths)..addAll(result.imagePaths);
          final buffer = StringBuffer(_textController.text.trim());
          if (result.text.isNotEmpty) {
            if (buffer.isNotEmpty) buffer.writeln('\n\n--- Page $startPage ---');
            buffer.writeln(result.text);
          }
          setState(() {
            _imagePaths = updatedPaths;
            _selectedPreviewIndex = _imagePaths.length - result.imagePaths.length;
            _textController.text = buffer.toString().trim();
            _isLoading = false;
          });
          Fluttertoast.showToast(
            msg: "Added ${result.imagePaths.length} image(s) to document!",
            backgroundColor: const Color(0xFF10B981),
          );
        } else {
          setState(() {
            _imagePaths = result.imagePaths;
            _selectedPreviewIndex = 0;
            _textController.text = result.text;
            _isLoading = false;
          });
          if (result.text.isEmpty) {
            Fluttertoast.showToast(msg: "No text detected in selected image.", backgroundColor: Colors.amber.shade800);
          } else {
            Fluttertoast.showToast(msg: "Text extracted successfully!", backgroundColor: const Color(0xFF10B981));
          }
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        Fluttertoast.showToast(msg: "Gallery error: $e");
      }
    }
  }

  Future<void> _capturePhoto({bool append = false}) async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Opening camera...';
    });
    try {
      final result = await _service.capturePhotoAndExtract();
      if (!mounted) return;
      if (result != null && result.imagePaths.isNotEmpty) {
        if (append && _imagePaths.isNotEmpty) {
          final int startPage = _imagePaths.length + 1;
          final updatedPaths = List<String>.from(_imagePaths)..addAll(result.imagePaths);
          final buffer = StringBuffer(_textController.text.trim());
          if (result.text.isNotEmpty) {
            if (buffer.isNotEmpty) buffer.writeln('\n\n--- Page $startPage ---');
            buffer.writeln(result.text);
          }
          setState(() {
            _imagePaths = updatedPaths;
            _selectedPreviewIndex = _imagePaths.length - 1;
            _textController.text = buffer.toString().trim();
            _isLoading = false;
          });
          Fluttertoast.showToast(
            msg: "Photo page added to document!",
            backgroundColor: const Color(0xFF10B981),
          );
        } else {
          setState(() {
            _imagePaths = result.imagePaths;
            _selectedPreviewIndex = 0;
            _textController.text = result.text;
            _isLoading = false;
          });
          if (result.text.isEmpty) {
            Fluttertoast.showToast(msg: "No text detected in photo.", backgroundColor: Colors.amber.shade800);
          } else {
            Fluttertoast.showToast(msg: "Text extracted successfully!", backgroundColor: const Color(0xFF10B981));
          }
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        Fluttertoast.showToast(msg: "Camera error: $e");
      }
    }
  }

  void _copyToClipboard() {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      Fluttertoast.showToast(msg: "No text to copy");
      return;
    }
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    Fluttertoast.showToast(
      msg: "Text copied to clipboard",
      backgroundColor: const Color(0xFF10B981),
    );
  }

  void _shareAsText() {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      Fluttertoast.showToast(msg: "No text to share");
      return;
    }
    HapticFeedback.lightImpact();
    final docTitle = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : 'Extracted Document';
    Share.share(
      text,
      subject: docTitle,
    );
  }

  // 🧹 Clean broken OCR line-breaks and whitespace
  void _cleanTextSpacing() {
    String t = _textController.text;
    if (t.trim().isEmpty) return;

    // Replace 3+ consecutive newlines with 2
    t = t.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    // Fix broken sentence lines where OCR inserted newlines mid-sentence
    t = t.replaceAllMapped(RegExp(r'([a-z,])\n([a-z])'), (m) => '${m[1]} ${m[2]}');
    // Trim trailing whitespace from each line
    final lines = t.split('\n').map((l) => l.trimRight()).toList();
    t = lines.join('\n').trim();

    setState(() {
      _textController.text = t;
    });
    HapticFeedback.lightImpact();
    Fluttertoast.showToast(
      msg: "Text spacing cleaned!",
      backgroundColor: const Color(0xFF10B981),
    );
  }

  // 🔊 Toggle Text to Speech
  Future<void> _toggleTts() async {
    if (_isPlayingTts) {
      await _flutterTts.stop();
      setState(() => _isPlayingTts = false);
    } else {
      final text = _textController.text.trim();
      if (text.isEmpty) {
        Fluttertoast.showToast(msg: "No text to read");
        return;
      }
      setState(() => _isPlayingTts = true);
      await _flutterTts.speak(text);
    }
  }

  // 📝 Save directly as a Quick Note
  Future<void> _saveAsQuickNote() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      Fluttertoast.showToast(msg: "No text to save as note");
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      const prefKey = 'hub_quick_notes_list_v1';
      final raw = prefs.getString(prefKey);
      List<QuickNoteItem> list = [];
      if (raw != null) {
        try {
          final List decoded = jsonDecode(raw);
          list = decoded.map((e) => QuickNoteItem.fromMap(e)).toList();
        } catch (_) {}
      }

      final docTitle = _titleController.text.trim().isNotEmpty
          ? _titleController.text.trim()
          : 'Scanned Document';

      final noteId = const Uuid().v4();
      final snippet = text.length > 200 ? text.substring(0, 200) : text;

      final newNote = QuickNoteItem(
        id: noteId,
        title: docTitle,
        category: 'Scanned',
        contentSnippet: snippet,
        lastUpdated: DateTime.now(),
        isPinned: false,
      );

      // 1. Save metadata in Quick Notes list
      list.insert(0, newNote);
      await prefs.setString(prefKey, jsonEncode(list.map((e) => e.toMap()).toList()));

      // 2. Save full note content to folder_notes_$noteId for NotesPage
      final delta = [
        {"insert": "$text\n"}
      ];
      final folderNote = FolderNotes(
        folderPath: noteId,
        notesContent: jsonEncode(delta),
        lastEdited: DateTime.now(),
      );
      await prefs.setString(
        'folder_notes_$noteId',
        jsonEncode(folderNote.toMap()),
      );

      // 3. Record recent activity
      await RecentActivityService.recordActivity(
        title: docTitle,
        subtitle: 'Scanned Note (OCR)',
        type: 'note',
        targetPath: noteId,
      );

      HapticFeedback.lightImpact();
      Fluttertoast.showToast(
        msg: "Saved to Notes successfully!",
        backgroundColor: const Color(0xFF10B981),
      );
    } catch (e) {
      Fluttertoast.showToast(msg: "Failed to save note: $e", backgroundColor: Colors.red);
    }
  }

  // 🔍 Find & Replace Dialog
  void _showFindAndReplaceDialog() {
    final findController = TextEditingController();
    final replaceController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Icon(Icons.find_replace_rounded, color: AppTheme.primary(context)),
            const SizedBox(width: 8),
            Text(
              'Find & Replace',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: findController,
              decoration: InputDecoration(
                labelText: 'Find text',
                filled: true,
                fillColor: AppTheme.tonal(context),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: replaceController,
              decoration: InputDecoration(
                labelText: 'Replace with',
                filled: true,
                fillColor: AppTheme.tonal(context),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final findText = findController.text;
              if (findText.isNotEmpty) {
                final original = _textController.text;
                final updated = original.replaceAll(findText, replaceController.text);
                setState(() => _textController.text = updated);
                Navigator.pop(ctx);
                Fluttertoast.showToast(msg: "Occurrences replaced!");
              }
            },
            child: const Text('Replace All'),
          ),
        ],
      ),
    );
  }

  void _showZoomedImageDialog(String imagePath) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 5.0,
                child: Image.file(
                  File(imagePath),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                  shape: const CircleBorder(),
                ),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPdfExportOptions() {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      Fluttertoast.showToast(msg: "Extract text before creating PDF");
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.85,
        ),
        child: Container(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + MediaQuery.of(ctx).padding.bottom),
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: AppTheme.surfaceBorder(context)),
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceBorder(context),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEA4335).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFEA4335), size: 24),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Export Extracted Text as PDF',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary(context),
                          ),
                        ),
                        Text(
                          'Generate, save, or custom format',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: AppTheme.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  tileColor: AppTheme.tonal(context),
                  leading: const Icon(Icons.flash_on_rounded, color: Color(0xFFF59E0B)),
                  title: Text(
                    'Quick PDF & Share',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: Text(
                    'Generate standard A4 document and open share sheet',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.textSecondary(context)),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () {
                    Navigator.pop(ctx);
                    _generateQuickPdfAndShare();
                  },
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  tileColor: AppTheme.tonal(context),
                  leading: Icon(Icons.folder_open_rounded, color: AppTheme.primary(context)),
                  title: Text(
                    'Save PDF to App Folder',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: Text(
                    'Save directly into one of your Document Hub folders',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.textSecondary(context)),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () {
                    Navigator.pop(ctx);
                    _savePdfToFolder();
                  },
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  tileColor: AppTheme.tonal(context),
                  leading: const Icon(Icons.tune_rounded, color: Color(0xFF34A853)),
                  title: Text(
                    'Advanced PDF Editor & Formatter',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: Text(
                    'Customise fonts, alignments, margins, headers & footers',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.textSecondary(context)),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TextToPdfScreen(
                          initialText: _textController.text,
                          initialTitle: _titleController.text.trim().isNotEmpty
                              ? _titleController.text.trim()
                              : (widget.autoExtractTitle ?? 'Extracted Document'),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<String?> _buildPdfFile() async {
    final pdf = pw.Document();
    final text = _textController.text.trim();
    final title = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : (widget.autoExtractTitle ?? 'Extracted Text Document');
    final dateStr = DateTime.now().toLocal().toString().split('.').first;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(bottom: 16),
          padding: const pw.EdgeInsets.only(bottom: 6),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.8)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                dateStr,
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
              ),
            ],
          ),
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 16),
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
          ),
        ),
        build: (context) => [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 14),
          pw.Paragraph(
            text: text,
            style: const pw.TextStyle(fontSize: 11, lineSpacing: 2.0),
          ),
        ],
      ),
    );

    final tempDir = await getTemporaryDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final filePath = '${tempDir.path}/Extracted_Text_$ts.pdf';
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());
    return filePath;
  }

  Future<void> _generateQuickPdfAndShare() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Generating PDF...';
    });
    try {
      final pdfPath = await _buildPdfFile();
      setState(() => _isLoading = false);
      if (pdfPath != null) {
        await Share.shareXFiles(
          [XFile(pdfPath)],
          text: 'Extracted Document PDF',
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      Fluttertoast.showToast(msg: "Error creating PDF: $e");
    }
  }

  Future<void> _savePdfToFolder() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => const FolderPickerDialog(
        defaultFileName: 'Extracted_Text.pdf',
        isFolderOnly: true,
      ),
    );
    if (result == null || result['folder'] == null) return;
    final selectedFolder = result['folder'] as String;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Saving PDF to folder...';
    });

    try {
      final tempPdf = await _buildPdfFile();
      if (tempPdf == null) throw Exception("Failed to build PDF");

      final ts = DateTime.now().millisecondsSinceEpoch;
      final targetPath = '$selectedFolder${Platform.pathSeparator}Extracted_Text_$ts.pdf';
      await File(tempPdf).copy(targetPath);

      setState(() => _isLoading = false);
      Fluttertoast.showToast(
        msg: "PDF saved to folder successfully!",
        backgroundColor: const Color(0xFF10B981),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      Fluttertoast.showToast(msg: "Failed to save: $e", backgroundColor: Colors.red);
    }
  }

  void _showImageSourceChooser({bool isAppending = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.85,
        ),
        child: Container(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + MediaQuery.of(ctx).padding.bottom),
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: AppTheme.surfaceBorder(context)),
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceBorder(context),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  isAppending
                      ? 'Add Pages to Document (Multi-Page OCR)'
                      : 'Select Images for Text Extraction',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isAppending
                      ? 'New text and pages will be appended to your current document'
                      : 'Scan documents, pick multiple photos from gallery, or snap a photo',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: AppTheme.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 20),
                _buildSourceOption(
                  icon: Icons.document_scanner_rounded,
                  color: AppTheme.primary(context),
                  title: isAppending ? 'Scan More Pages' : 'Scan Document (Auto-Crop Multi-Page)',
                  subtitle: 'Camera scanner with perspective correction & auto-detect',
                  onTap: () {
                    Navigator.pop(ctx);
                    _scanDocument(append: isAppending);
                  },
                ),
                const SizedBox(height: 10),
                _buildSourceOption(
                  icon: Icons.photo_library_rounded,
                  color: const Color(0xFF34A853),
                  title: isAppending ? 'Add Multiple Images from Gallery' : 'Choose Multiple from Gallery',
                  subtitle: 'Select one or more photos, screenshots, or receipts',
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickFromGallery(append: isAppending);
                  },
                ),
                const SizedBox(height: 10),
                _buildSourceOption(
                  icon: Icons.camera_alt_rounded,
                  color: const Color(0xFF4285F4),
                  title: isAppending ? 'Take Photo to Append' : 'Take Quick Photo',
                  subtitle: 'Snap a direct picture using device camera',
                  onTap: () {
                    Navigator.pop(ctx);
                    _capturePhoto(append: isAppending);
                  },
                ),
                if (!isAppending && _imagePaths.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildSourceOption(
                    icon: Icons.add_circle_outline_rounded,
                    color: const Color(0xFF8B5CF6),
                    title: 'Append Pages (Keep Current Text)',
                    subtitle: 'Add additional pages without overwriting current work',
                    onTap: () {
                      Navigator.pop(ctx);
                      _showImageSourceChooser(isAppending: true);
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSourceOption({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      tileColor: AppTheme.tonal(context),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.14),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(
        title,
        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.textSecondary(context)),
      ),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bool isKeyboardActive = bottomInset > 60;

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: AppTheme.surface(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Text Studio (OCR)',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary(context),
          ),
        ),
        actions: [
          if (_imagePaths.isNotEmpty) ...[
            // Split view toggle button
            IconButton(
              icon: Icon(
                _viewMode == EditorViewMode.splitView
                    ? Icons.vertical_split_rounded
                    : Icons.vertical_split_outlined,
                color: _viewMode == EditorViewMode.splitView
                    ? AppTheme.primary(context)
                    : AppTheme.textSecondary(context),
              ),
              tooltip: _viewMode == EditorViewMode.splitView ? 'Exit Split View' : 'Split View with Image',
              onPressed: () {
                setState(() {
                  _viewMode = _viewMode == EditorViewMode.splitView
                      ? EditorViewMode.editorOnly
                      : EditorViewMode.splitView;
                });
              },
            ),
            // Tools menu button
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, color: AppTheme.textSecondary(context)),
              tooltip: 'Text Tools',
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              onSelected: (val) {
                if (val == 'clean') _cleanTextSpacing();
                if (val == 'replace') _showFindAndReplaceDialog();
                if (val == 'tts') _toggleTts();
                if (val == 'note') _saveAsQuickNote();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'clean',
                  child: Row(
                    children: [
                      Icon(Icons.auto_fix_high_rounded, size: 20, color: Color(0xFF3B82F6)),
                      SizedBox(width: 12),
                      Text('Clean Spacing & Breaks'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'replace',
                  child: Row(
                    children: [
                      Icon(Icons.find_replace_rounded, size: 20, color: Color(0xFF6366F1)),
                      SizedBox(width: 12),
                      Text('Find & Replace...'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'tts',
                  child: Row(
                    children: [
                      Icon(_isPlayingTts ? Icons.stop_rounded : Icons.volume_up_rounded, size: 20, color: const Color(0xFF10B981)),
                      const SizedBox(width: 12),
                      Text(_isPlayingTts ? 'Stop Reading' : 'Read Aloud'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'note',
                  child: Row(
                    children: [
                      Icon(Icons.note_add_rounded, size: 20, color: Color(0xFFF59E0B)),
                      SizedBox(width: 12),
                      Text('Save to Notes'),
                    ],
                  ),
                ),
              ],
            ),
          ],
          IconButton(
            icon: Icon(Icons.add_photo_alternate_outlined, color: AppTheme.primary(context)),
            tooltip: 'New Image',
            onPressed: _showImageSourceChooser,
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Productivity Scrollable Ribbon (Guaranteed 0 overflow on all phone screens!)
              if (_imagePaths.isNotEmpty)
                _buildProductiveRibbon(),

              // Split View Image Preview (shown when Split View is enabled)
              if (_imagePaths.isNotEmpty && _viewMode == EditorViewMode.splitView && !isKeyboardActive)
                _buildSplitImageViewer(),

              // Text Editor / Document Canvas Area
              Expanded(
                child: _imagePaths.isEmpty
                    ? _buildEmptyState()
                    : _buildDocumentCanvas(isKeyboardActive),
              ),

              // Bottom Actions Bar (or slim keyboard accessory bar)
              if (_imagePaths.isNotEmpty)
                isKeyboardActive
                    ? _buildKeyboardAccessoryBar()
                    : _buildBottomActionBar(),
            ],
          ),

          // Loading Overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.45),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  decoration: BoxDecoration(
                    color: AppTheme.surface(context),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppTheme.surfaceBorder(context)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 24,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppTheme.primary(context), strokeWidth: 3),
                      const SizedBox(height: 18),
                      Text(
                        _statusMessage,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppTheme.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Processing takes a few seconds...',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppTheme.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Scrollable Productivity Ribbon (Guaranteed 0 overflow) ───
  Widget _buildProductiveRibbon() {
    return Container(
      height: 44,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        border: Border(
          bottom: BorderSide(color: AppTheme.surfaceBorder(context).withOpacity(0.6)),
        ),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        children: [
          // Pages count chip (clickable to view thumbnail)
          GestureDetector(
            onTap: () {
              if (_imagePaths.isNotEmpty) {
                _showZoomedImageDialog(_imagePaths[_selectedPreviewIndex]);
              }
            },
            child: _buildStatPill(
              Icons.description_outlined,
              '${_imagePaths.length} ${_imagePaths.length == 1 ? "Page" : "Pages"} (tap to view)',
            ),
          ),
          const SizedBox(width: 8),

          // Add Page action chip
          _buildRibbonActionChip(
            icon: Icons.add_photo_alternate_rounded,
            label: '+ Add Page',
            color: const Color(0xFF6366F1),
            onTap: () => _showImageSourceChooser(isAppending: true),
          ),
          const SizedBox(width: 8),
          _buildStatPill(Icons.sort_by_alpha_rounded, '$_wordCount words'),
          const SizedBox(width: 8),
          _buildStatPill(Icons.text_fields_rounded, '$_charCount chars'),
          const SizedBox(width: 8),

          // Font size decrement button
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              if (_fontSize > 12) setState(() => _fontSize -= 1.5);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.tonal(context),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('A-', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            ),
          ),
          const SizedBox(width: 4),

          // Font size increment button
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              if (_fontSize < 24) setState(() => _fontSize += 1.5);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.tonal(context),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('A+', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            ),
          ),
          const SizedBox(width: 8),

          // Clean spacing action
          _buildRibbonActionChip(
            icon: Icons.auto_fix_high_rounded,
            label: 'Clean Breaks',
            color: const Color(0xFF3B82F6),
            onTap: _cleanTextSpacing,
          ),
          const SizedBox(width: 8),

          // Read Aloud / TTS
          _buildRibbonActionChip(
            icon: _isPlayingTts ? Icons.stop_rounded : Icons.volume_up_rounded,
            label: _isPlayingTts ? 'Stop' : 'Listen',
            color: const Color(0xFF10B981),
            onTap: _toggleTts,
          ),
          const SizedBox(width: 8),

          // Clear button
          if (_textController.text.isNotEmpty)
            _buildRibbonActionChip(
              icon: Icons.delete_outline_rounded,
              label: 'Clear',
              color: Colors.redAccent,
              onTap: () {
                _textController.clear();
                setState(() {});
              },
            ),
        ],
      ),
    );
  }

  Widget _buildStatPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.tonal(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppTheme.textSecondary(context)),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRibbonActionChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Split Image Viewer (Top half in Split View mode with Multi-Page Strip) ───
  Widget _buildSplitImageViewer() {
    final imagePath = _imagePaths[_selectedPreviewIndex];
    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.92),
        border: Border(
          bottom: BorderSide(color: AppTheme.surfaceBorder(context)),
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: File(imagePath).existsSync()
                      ? Image.file(File(imagePath), fit: BoxFit.contain)
                      : const Center(child: Text('Image not available', style: TextStyle(color: Colors.white70))),
                ),
                Positioned(
                  top: 8,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Page ${_selectedPreviewIndex + 1} of ${_imagePaths.length} (Pinch to zoom)',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                if (_imagePaths.length > 1)
                  Positioned(
                    top: 8,
                    right: 10,
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.white70, size: 18),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black54,
                        padding: const EdgeInsets.all(6),
                        minimumSize: const Size(30, 30),
                      ),
                      tooltip: 'Remove this page',
                      onPressed: () {
                        setState(() {
                          _imagePaths.removeAt(_selectedPreviewIndex);
                          if (_selectedPreviewIndex >= _imagePaths.length) {
                            _selectedPreviewIndex = _imagePaths.length - 1;
                          }
                        });
                        Fluttertoast.showToast(msg: "Page removed from preview");
                      },
                    ),
                  ),
              ],
            ),
          ),
          // Multi-page thumbnail selector strip
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: Colors.black54,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _imagePaths.length + 1,
              itemBuilder: (context, index) {
                if (index == _imagePaths.length) {
                  return InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _showImageSourceChooser(isAppending: true),
                    child: Container(
                      width: 40,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                    ),
                  );
                }
                final isSelected = index == _selectedPreviewIndex;
                final thumbPath = _imagePaths[index];
                return GestureDetector(
                  onTap: () => setState(() => _selectedPreviewIndex = index),
                  child: Container(
                    width: 38,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? AppTheme.primary(context) : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (File(thumbPath).existsSync())
                            Image.file(File(thumbPath), fit: BoxFit.cover)
                          else
                            const ColoredBox(color: Colors.grey),
                          Container(
                            color: Colors.black.withOpacity(isSelected ? 0.0 : 0.4),
                          ),
                          Center(
                            child: Text(
                              'P${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                                shadows: [Shadow(color: Colors.black, blurRadius: 2)],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── Document Canvas (The Clean, Productive Editor) ───
  Widget _buildDocumentCanvas(bool isKeyboardActive) {
    return Padding(
      padding: EdgeInsets.fromLTRB(14, 10, 14, isKeyboardActive ? 4 : 10),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.isDark(context) ? const Color(0xFF1B1D24) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.surfaceBorder(context),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(AppTheme.isDark(context) ? 0.3 : 0.04),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Document Title Header Row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _titleController,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: AppTheme.textPrimary(context),
                      letterSpacing: -0.2,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Document Title...',
                      hintStyle: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: AppTheme.textMuted(context),
                      ),
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (isKeyboardActive)
                  GestureDetector(
                    onTap: () => FocusScope.of(context).unfocus(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primary(context).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.keyboard_hide_rounded, size: 14, color: AppTheme.primary(context)),
                          const SizedBox(width: 4),
                          Text(
                            'Done',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Divider(height: 12, color: AppTheme.surfaceBorder(context).withOpacity(0.7)),

            // Spacious Editable Text Area
            Expanded(
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                onChanged: (_) => setState(() {}),
                cursorColor: AppTheme.primary(context),
                cursorWidth: 2.2,
                cursorRadius: const Radius.circular(2),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: _fontSize,
                  height: 1.65,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.textPrimary(context),
                  letterSpacing: 0.15,
                ),
                decoration: InputDecoration(
                  hintText: 'Extracted text will appear here. Tap to edit freely...',
                  hintStyle: GoogleFonts.plusJakartaSans(
                    fontSize: _fontSize,
                    color: AppTheme.textMuted(context),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.only(top: 8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Empty State ───
  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primaryContainer(context),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.document_scanner_rounded,
                size: 44,
                color: AppTheme.primary(context),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Extract Text from Image',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select a scanned document, receipt, note, or photo to extract all readable text using high-accuracy on-device OCR.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppTheme.textSecondary(context),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              icon: const Icon(Icons.document_scanner_rounded, size: 20),
              label: const Text('Scan Document'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(220, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _scanDocument,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.photo_library_rounded, size: 20),
              label: const Text('Choose from Gallery'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(220, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _pickFromGallery,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Slim Keyboard Accessory Toolbar ───
  Widget _buildKeyboardAccessoryBar() {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        border: Border(
          top: BorderSide(color: AppTheme.surfaceBorder(context)),
        ),
      ),
      child: Row(
        children: [
          // Quick Clean Spacing chip
          InkWell(
            onTap: _cleanTextSpacing,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.auto_fix_high_rounded, size: 14, color: Color(0xFF3B82F6)),
                  const SizedBox(width: 4),
                  Text(
                    'Clean Breaks',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF3B82F6),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Copy button
          InkWell(
            onTap: _copyToClipboard,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.copy_rounded, size: 14, color: AppTheme.primary(context)),
                  const SizedBox(width: 4),
                  Text(
                    'Copy',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          // Dismiss keyboard Done button
          FilledButton.tonalIcon(
            icon: const Icon(Icons.keyboard_hide_rounded, size: 16),
            label: const Text('Done'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              minimumSize: const Size(0, 32),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => FocusScope.of(context).unfocus(),
          ),
        ],
      ),
    );
  }

  // ─── Prominent Bottom Action Bar (Copy / Share / PDF / Notes) ───
  Widget _buildBottomActionBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        border: Border(
          top: BorderSide(color: AppTheme.surfaceBorder(context)),
        ),
      ),
      child: Row(
        children: [
          // Copy Button
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Copy'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _copyToClipboard,
            ),
          ),
          const SizedBox(width: 8),

          // Share Text Button
          Expanded(
            child: FilledButton.tonalIcon(
              icon: const Icon(Icons.share_rounded, size: 18),
              label: const Text('Share Text'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _shareAsText,
            ),
          ),
          const SizedBox(width: 8),

          // Convert to PDF Button
          Expanded(
            child: FilledButton.icon(
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
              label: const Text('PDF'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEA4335),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _showPdfExportOptions,
            ),
          ),
        ],
      ),
    );
  }
}
