import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gallery_app/widgets/folder_picker_dialog.dart';

class TextToPdfScreen extends StatefulWidget {
  const TextToPdfScreen({super.key});

  @override
  State<TextToPdfScreen> createState() => _TextToPdfScreenState();
}

class _TextToPdfScreenState extends State<TextToPdfScreen> {
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _titleController = TextEditingController(text: 'Untitled PDF');
  double _fontSize = 14.0;
  pw.TextAlign _textAlign = pw.TextAlign.left;
  PdfPageFormat _pageFormat = PdfPageFormat.a4;
  bool _isProcessing = false;

  @override
  void dispose() {
    _textController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _exportPdf() async {
    if (_textController.text.trim().isEmpty) {
      Fluttertoast.showToast(msg: 'Please enter some text');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final pdf = pw.Document();
      final String content = _textController.text;
      final String title = _titleController.text;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: _pageFormat,
          margin: const pw.EdgeInsets.all(50),
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Text(title, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 20),
            pw.Paragraph(
              text: content,
              textAlign: _textAlign,
              style: pw.TextStyle(fontSize: _fontSize),
            ),
          ],
        ),
      );

      final pdfBytes = await pdf.save();
      
      if (!mounted) return;
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) => FolderPickerDialog(
          defaultFileName: '${title.replaceAll(' ', '_')}.pdf',
        ),
      );

      if (result == null) return;

      final action = result['action'] as String;
      String? filePath;

      if (action == 'share') {
        final outputDir = await getApplicationDocumentsDirectory();
        final tempPath = '${outputDir.path}/${title.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';
        await File(tempPath).writeAsBytes(pdfBytes);
        Share.shareXFiles([XFile(tempPath)]);
        filePath = tempPath;
      } else {
        final selectedFolder = result['folder'] as String;
        filePath = '$selectedFolder/${title.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';
        await File(filePath).writeAsBytes(pdfBytes);
      }

      if (mounted && filePath != null) {
        Fluttertoast.showToast(msg: 'PDF saved successfully');
        Navigator.pop(context);
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Text to PDF', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        actions: [
          if (_isProcessing)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            IconButton(
              icon: const Icon(Icons.check_rounded),
              onPressed: _exportPdf,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'PDF Title'),
              style: GoogleFonts.poppins(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _textController,
              maxLines: null,
              decoration: const InputDecoration(
                hintText: 'Enter text here...',
                border: OutlineInputBorder(),
              ),
              style: GoogleFonts.poppins(fontSize: _fontSize),
            ),
          ],
        ),
      ),
    );
  }
}
