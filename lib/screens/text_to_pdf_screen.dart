import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

import 'package:gallery_app/widgets/folder_picker_dialog.dart';
import 'package:gallery_app/utils/text_utils.dart';
import 'package:gallery_app/theme/app_theme.dart';

class TextToPdfScreen extends StatefulWidget {
  final String? initialText;
  final String? initialTitle;

  const TextToPdfScreen({
    super.key,
    this.initialText,
    this.initialTitle,
  });

  @override
  State<TextToPdfScreen> createState() => _TextToPdfScreenState();
}

class _TextToPdfScreenState extends State<TextToPdfScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _authorController = TextEditingController();

  // Typography state
  double _fontSize = 13.0;
  pw.TextAlign _textAlign = pw.TextAlign.left;
  pw.FontWeight _fontWeight = pw.FontWeight.normal;
  pw.FontStyle _fontStyle = pw.FontStyle.normal;
  final double _lineSpacing = 1.3;

  // Page layout state
  PdfPageFormat _pageFormat = PdfPageFormat.a4;
  bool _isLandscape = false;
  final double _pageMargin = 40.0;

  // Header & Footer options
  bool _includeTitleHeader = true;
  bool _includePageNumbers = true;
  bool _includeDateFooter = true;
  bool _includeAuthor = false;

  bool _isProcessing = false;

  // Statistics
  int _wordCount = 0;
  int _charCount = 0;
  int _lineCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _titleController.text = widget.initialTitle ?? 'Document';
    if (widget.initialText != null && widget.initialText!.isNotEmpty) {
      _textController.text = widget.initialText!;
    }
    _updateStats();
    _textController.addListener(_updateStats);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textController.dispose();
    _titleController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  void _updateStats() {
    final text = _textController.text;
    final words = text.trim().isEmpty
        ? 0
        : text.trim().split(RegExp(r'\s+')).length;
    final chars = text.length;
    final lines = text.isEmpty ? 0 : text.split('\n').length;

    if (mounted) {
      setState(() {
        _wordCount = words;
        _charCount = chars;
        _lineCount = lines;
      });
    }
  }

  void _applyTemplate(String title, String content) {
    setState(() {
      _titleController.text = title;
      _textController.text = content;
    });
    Fluttertoast.showToast(msg: 'Applied template: $title');
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      final currentPos = _textController.selection.start;
      final text = _textController.text;
      if (currentPos >= 0 && currentPos <= text.length) {
        final newText = text.substring(0, currentPos) +
            data.text! +
            text.substring(currentPos);
        _textController.text = newText;
        _textController.selection = TextSelection.collapsed(
          offset: currentPos + data.text!.length,
        );
      } else {
        _textController.text +=
            (_textController.text.isEmpty ? '' : '\n') + data.text!;
      }
      Fluttertoast.showToast(msg: 'Pasted from clipboard');
    } else {
      Fluttertoast.showToast(msg: 'Clipboard is empty');
    }
  }

  Future<Uint8List> _generatePdfBytes() async {
    final pdf = pw.Document();
    final String content = _textController.text.trim().isEmpty
        ? 'No content'
        : _textController.text;
    final String title = _titleController.text.trim().isEmpty
        ? 'Untitled Document'
        : _titleController.text.trim();
    final String author = _authorController.text.trim();
    final String dateStr =
        DateFormat('MMMM dd, yyyy • hh:mm a').format(DateTime.now());

    final format = _isLandscape ? _pageFormat.landscape : _pageFormat;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: pw.EdgeInsets.all(_pageMargin),
        header: (context) {
          if (!_includeTitleHeader || context.pageNumber > 1) {
            return pw.SizedBox.shrink();
          }
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 20),
            padding: const pw.EdgeInsets.only(bottom: 12),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey300, width: 1.5),
              ),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black,
                  ),
                ),
                if (_includeAuthor && author.isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'By $author',
                    style: const pw.TextStyle(
                      fontSize: 11,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
        footer: (context) {
          if (!_includePageNumbers && !_includeDateFooter) {
            return pw.SizedBox.shrink();
          }
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 16),
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(color: PdfColors.grey300, width: 0.8),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                if (_includeDateFooter)
                  pw.Text(
                    dateStr,
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey600,
                    ),
                  )
                else
                  pw.SizedBox.shrink(),
                if (_includePageNumbers)
                  pw.Text(
                    'Page ${context.pageNumber} of ${context.pagesCount}',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey600,
                    ),
                  )
                else
                  pw.SizedBox.shrink(),
              ],
            ),
          );
        },
        build: (context) => [
          pw.Paragraph(
            text: content,
            textAlign: _textAlign,
            style: pw.TextStyle(
              fontSize: _fontSize,
              fontWeight: _fontWeight,
              fontStyle: _fontStyle,
              lineSpacing: _lineSpacing,
              color: PdfColors.black,
            ),
          ),
        ],
      ),
    );

    return await pdf.save();
  }

  Future<void> _exportPdf() async {
    if (_textController.text.trim().isEmpty) {
      Fluttertoast.showToast(msg: 'Please enter text before generating PDF');
      return;
    }

    final rawTitle = _titleController.text.trim().isEmpty
        ? 'Document'
        : _titleController.text.trim();
    final cleanFileName =
        '${rawTitle.replaceAll(RegExp(r'[^\w\s\-]'), '').replaceAll(' ', '_')}.pdf';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => FolderPickerDialog(defaultFileName: cleanFileName),
    );

    if (result == null) return;

    setState(() => _isProcessing = true);

    try {
      final pdfBytes = await _generatePdfBytes();
      final action = result['action'] as String?;
      String? savedPath;

      if (action == 'share') {
        final tempDir = await getTemporaryDirectory();
        final ts = DateTime.now().millisecondsSinceEpoch;
        final tempPath =
            '${tempDir.path}${Platform.pathSeparator}${rawTitle}_$ts.pdf';
        await File(tempPath).writeAsBytes(pdfBytes);
        await Share.shareXFiles([XFile(tempPath)]);
        savedPath = tempPath;
      } else {
        final selectedFolder = result['folder'] as String;
        final ts = DateTime.now().millisecondsSinceEpoch;
        final outFileName =
            '${rawTitle.replaceAll(RegExp(r'[^\w\s\-]'), '').replaceAll(' ', '_')}_$ts.pdf';
        savedPath = '$selectedFolder${Platform.pathSeparator}$outFileName';
        await File(savedPath).writeAsBytes(pdfBytes);
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'PDF Created',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Text(
              'Document successfully saved (${TextUtils.formatFileSize(pdfBytes.length)}):\n$savedPath',
              style: GoogleFonts.poppins(fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: Text('Done', style: GoogleFonts.poppins()),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.share_rounded, size: 16),
                label: Text('Share PDF', style: GoogleFonts.poppins()),
                onPressed: () {
                  Navigator.pop(ctx);
                  if (savedPath != null) {
                    Share.shareXFiles([XFile(savedPath)]);
                  }
                },
              ),
            ],
          ),
        );
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error creating PDF: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appBarTextColor = AppTheme.textPrimary(context);
    final appBarIconColor = AppTheme.tonal(context);
    final appBarIconBorder = AppTheme.surfaceBorder(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surface(context).withOpacity(0.85),
                border: Border(
                  bottom: BorderSide(
                    color: AppTheme.surfaceBorder(context),
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
        leading: Container(
          margin: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: appBarIconColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: appBarIconBorder, width: 1),
          ),
          child: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: appBarTextColor, size: 20),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
          ),
        ),
        title: Text(
          'Text to PDF',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: -0.3,
            color: appBarTextColor,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primary(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextButton.icon(
              onPressed: _isProcessing ? null : _exportPdf,
              icon: const Icon(
                Icons.picture_as_pdf_rounded,
                size: 16,
                color: Colors.white,
              ),
              label: Text(
                'Export',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Elegant Frosted Segmented Tab Switcher
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppTheme.surface(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppTheme.surfaceBorder(context),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(AppTheme.isDark(context) ? 0.2 : 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _buildTopTabItem(
                    index: 0,
                    icon: Icons.edit_note_rounded,
                    label: 'Editor & Styling',
                    isDark: AppTheme.isDark(context),
                  ),
                  _buildTopTabItem(
                    index: 1,
                    icon: Icons.remove_red_eye_rounded,
                    label: 'Live PDF Preview',
                    isDark: AppTheme.isDark(context),
                  ),
                ],
              ),
            ),

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildEditorTab(AppTheme.isDark(context), Theme.of(context)),
                  _buildPreviewTab(AppTheme.isDark(context), Theme.of(context)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopTabItem({
    required int index,
    required IconData icon,
    required String label,
    required bool isDark,
  }) {
    final isSelected = _tabController.index == index;
    final activeBg = AppTheme.primaryContainer(context);
    final activeColor = AppTheme.onPrimaryContainer(context);
    final inactiveColor = AppTheme.textSecondary(context);

    return Expanded(
      child: GestureDetector(
        onTap: () {
          _tabController.animateTo(index);
          setState(() {});
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? activeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: isSelected ? activeColor : inactiveColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? activeColor : inactiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditorTab(bool isDark, ThemeData theme) {
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white10 : Colors.black.withOpacity(0.06);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Document Details Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Document Details',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _titleController,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Document Title',
                    labelStyle: GoogleFonts.inter(
                      fontSize: 13,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                    hintText: 'Enter title...',
                    prefixIcon: Icon(
                      Icons.title_rounded,
                      size: 20,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withOpacity(0.04)
                        : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ),
                if (_includeAuthor) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _authorController,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Author / Organization',
                      labelStyle: GoogleFonts.inter(
                        fontSize: 13,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                      hintText: 'e.g. John Doe, Document Hub',
                      prefixIcon: Icon(
                        Icons.person_outline_rounded,
                        size: 20,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withOpacity(0.04)
                          : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Starter Templates
          Text(
            'Quick Starter Templates',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTemplateChip(
                  label: 'Formal Letter',
                  content:
                      'Dear Sir/Madam,\n\nI am writing to formally submit this letter regarding our discussion...\n\nSincerely,\nAuthor',
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildTemplateChip(
                  label: 'Meeting Minutes',
                  content:
                      'Meeting Date: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}\nAttendees: Team Members\n\nAgenda:\n1. Project Review\n2. Key Deadlines\n3. Action Items:\n- Review documentation\n- Verify offline exports',
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildTemplateChip(
                  label: 'Invoice Summary',
                  content:
                      'INVOICE / RECEIPT\nDate: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}\n\nItem: Professional Services\nQuantity: 1\nRate: \$150.00\nTotal Due: \$150.00\n\nThank you for your business!',
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildTemplateChip(
                  label: 'Project Outline',
                  content:
                      'PROJECT SPECIFICATION\n\n1. Overview & Objectives\n2. Architecture & Design\n3. Functional Requirements\n4. Deployment Checklist',
                  isDark: isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Typography & Page Layout Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Typography & Layout',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.1)
                            : Colors.black.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${_fontSize.toInt()} pt',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Font Size Slider
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: isDark ? Colors.white : Colors.black,
                    inactiveTrackColor: isDark
                        ? Colors.white24
                        : Colors.black.withOpacity(0.1),
                    thumbColor: isDark ? Colors.white : Colors.black,
                    overlayColor: (isDark ? Colors.white : Colors.black)
                        .withOpacity(0.15),
                    trackHeight: 3.5,
                  ),
                  child: Slider(
                    value: _fontSize,
                    min: 9.0,
                    max: 28.0,
                    divisions: 19,
                    onChanged: (val) => setState(() => _fontSize = val),
                  ),
                ),
                const SizedBox(height: 8),

                // Alignment & Weight Row
                Row(
                  children: [
                    // Custom Alignment Segment
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.05)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark
                                ? Colors.white10
                                : Colors.black.withOpacity(0.06),
                          ),
                        ),
                        child: Row(
                          children: [
                            _buildAlignmentItem(
                              pw.TextAlign.left,
                              Icons.format_align_left_rounded,
                              isDark,
                            ),
                            _buildAlignmentItem(
                              pw.TextAlign.center,
                              Icons.format_align_center_rounded,
                              isDark,
                            ),
                            _buildAlignmentItem(
                              pw.TextAlign.right,
                              Icons.format_align_right_rounded,
                              isDark,
                            ),
                            _buildAlignmentItem(
                              pw.TextAlign.justify,
                              Icons.format_align_justify_rounded,
                              isDark,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Bold Toggle Button
                    _buildStyleToggle(
                      icon: Icons.format_bold_rounded,
                      isActive: _fontWeight == pw.FontWeight.bold,
                      isDark: isDark,
                      onTap: () {
                        setState(() {
                          _fontWeight = _fontWeight == pw.FontWeight.bold
                              ? pw.FontWeight.normal
                              : pw.FontWeight.bold;
                        });
                      },
                    ),
                    const SizedBox(width: 6),

                    // Italic Toggle Button
                    _buildStyleToggle(
                      icon: Icons.format_italic_rounded,
                      isActive: _fontStyle == pw.FontStyle.italic,
                      isDark: isDark,
                      onTap: () {
                        setState(() {
                          _fontStyle = _fontStyle == pw.FontStyle.italic
                              ? pw.FontStyle.normal
                              : pw.FontStyle.italic;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // Page Format & Orientation
                Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: DropdownButtonFormField<PdfPageFormat>(
                        value: _pageFormat,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        dropdownColor:
                            isDark ? const Color(0xFF222222) : Colors.white,
                        decoration: InputDecoration(
                          labelText: 'Format',
                          labelStyle: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          filled: true,
                          fillColor: isDark
                              ? Colors.white.withOpacity(0.04)
                              : const Color(0xFFF1F5F9),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.white10
                                  : Colors.black.withOpacity(0.06),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.white10
                                  : Colors.black.withOpacity(0.06),
                            ),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: PdfPageFormat.a4,
                            child: Text('A4'),
                          ),
                          DropdownMenuItem(
                            value: PdfPageFormat.letter,
                            child: Text('Letter'),
                          ),
                          DropdownMenuItem(
                            value: PdfPageFormat.legal,
                            child: Text('Legal'),
                          ),
                          DropdownMenuItem(
                            value: PdfPageFormat.a5,
                            child: Text('A5'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _pageFormat = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Orientation Toggle
                    Expanded(
                      flex: 6,
                      child: _buildOrientationToggle(isDark: isDark),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // High-Contrast Option Chips
                Text(
                  'Header & Footer Inclusions',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildOptionChip(
                      label: 'Title Header',
                      selected: _includeTitleHeader,
                      onSelected: (val) =>
                          setState(() => _includeTitleHeader = val),
                      isDark: isDark,
                    ),
                    _buildOptionChip(
                      label: 'Page Numbers',
                      selected: _includePageNumbers,
                      onSelected: (val) =>
                          setState(() => _includePageNumbers = val),
                      isDark: isDark,
                    ),
                    _buildOptionChip(
                      label: 'Date Stamp',
                      selected: _includeDateFooter,
                      onSelected: (val) =>
                          setState(() => _includeDateFooter = val),
                      isDark: isDark,
                    ),
                    _buildOptionChip(
                      label: 'Author Field',
                      selected: _includeAuthor,
                      onSelected: (val) => setState(() => _includeAuthor = val),
                      isDark: isDark,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Content Editor Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Document Content',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Row(
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.paste_rounded, size: 15),
                          label: Text(
                            'Paste',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: _pasteFromClipboard,
                        ),
                        if (_textController.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear_all_rounded, size: 18),
                            tooltip: 'Clear',
                            onPressed: () {
                              _textController.clear();
                              _updateStats();
                            },
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Statistics row
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.04)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Text(
                        '$_wordCount words',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      Text('•',
                          style: TextStyle(
                              color: isDark ? Colors.white30 : Colors.black26)),
                      Text(
                        '$_charCount characters',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      Text('•',
                          style: TextStyle(
                              color: isDark ? Colors.white30 : Colors.black26)),
                      Text(
                        '$_lineCount lines',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Main Text Input Area
                TextField(
                  controller: _textController,
                  maxLines: null,
                  minLines: 12,
                  keyboardType: TextInputType.multiline,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.5,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText:
                        'Type, paste, or draft your text here...\n\nSwitch to the "Live PDF Preview" tab at the top anytime to view exact pagination before saving!',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 13,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withOpacity(0.02)
                        : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderColor),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Primary Export Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _exportPdf,
              icon: const Icon(Icons.picture_as_pdf_rounded),
              label: Text(
                _isProcessing ? 'Generating PDF...' : 'Save & Export Document',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.white : Colors.black,
                foregroundColor: isDark ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildAlignmentItem(
    pw.TextAlign align,
    IconData icon,
    bool isDark,
  ) {
    final isSelected = _textAlign == align;
    final activeBg = isDark ? Colors.white : Colors.black;
    final activeColor = isDark ? Colors.black : Colors.white;
    final inactiveColor = isDark ? Colors.white60 : Colors.black54;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _textAlign = align),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? activeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, size: 18, color: isSelected ? activeColor : inactiveColor),
        ),
      ),
    );
  }

  Widget _buildStyleToggle({
    required IconData icon,
    required bool isActive,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final activeBg = isDark ? Colors.white : Colors.black;
    final activeColor = isDark ? Colors.black : Colors.white;
    final inactiveBg =
        isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF1F5F9);
    final inactiveColor = isDark ? Colors.white70 : Colors.black54;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: isActive ? activeBg : inactiveBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive
                ? (isDark ? Colors.white : Colors.black)
                : (isDark ? Colors.white10 : Colors.black.withOpacity(0.06)),
          ),
        ),
        child: Icon(icon, size: 18, color: isActive ? activeColor : inactiveColor),
      ),
    );
  }

  Widget _buildOrientationToggle({required bool isDark}) {
    final activeBg = AppTheme.primary(context);
    final activeColor = Colors.white;
    final inactiveColor = AppTheme.textSecondary(context);

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppTheme.tonal(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppTheme.surfaceBorder(context),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isLandscape = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: !_isLandscape ? activeBg : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.crop_portrait_rounded,
                      size: 15,
                      color: !_isLandscape ? activeColor : inactiveColor,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'Port.',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight:
                            !_isLandscape ? FontWeight.w700 : FontWeight.w500,
                        color: !_isLandscape ? activeColor : inactiveColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 3),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isLandscape = true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _isLandscape ? activeBg : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.crop_landscape_rounded,
                      size: 15,
                      color: _isLandscape ? activeColor : inactiveColor,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'Land.',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight:
                            _isLandscape ? FontWeight.w700 : FontWeight.w500,
                        color: _isLandscape ? activeColor : inactiveColor,
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

  Widget _buildOptionChip({
    required String label,
    required bool selected,
    required ValueChanged<bool> onSelected,
    required bool isDark,
  }) {
    final activeBg = AppTheme.primary(context);
    final activeText = Colors.white;
    final inactiveBg = AppTheme.tonal(context);
    final inactiveText = AppTheme.textSecondary(context);

    return GestureDetector(
      onTap: () => onSelected(!selected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? activeBg : inactiveBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? AppTheme.primary(context)
                : AppTheme.surfaceBorder(context),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(Icons.check_rounded, size: 14, color: activeText),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? activeText : inactiveText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateChip({
    required String label,
    required String content,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: () => _applyTemplate(label, content),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bookmark_outline_rounded,
              size: 14,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewTab(bool isDark, ThemeData theme) {
    if (_textController.text.trim().isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.description_outlined,
                size: 64,
                color: isDark ? Colors.white24 : Colors.black26,
              ),
              const SizedBox(height: 16),
              Text(
                'No text to preview',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Type or paste text in the Editor tab to preview the formatted PDF in real-time.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return PdfPreview(
      build: (format) => _generatePdfBytes(),
      canChangeOrientation: false,
      canChangePageFormat: false,
      canDebug: false,
      allowPrinting: true,
      allowSharing: true,
      pdfFileName: '${_titleController.text.trim().replaceAll(' ', '_')}.pdf',
      loadingWidget: const Center(
        child: CircularProgressIndicator(),
      ),
      actions: [
        PdfPreviewAction(
          icon: const Icon(Icons.save_rounded),
          onPressed: (context, build, format) => _exportPdf(),
        ),
      ],
    );
  }
}
