import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gallery_app/utils/text_utils.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gallery_app/models/file_info.dart';
import 'package:gallery_app/utils/responsive_layout.dart';

class DocumentMetadataScreen extends StatefulWidget {
  final FileInfo fileInfo;

  const DocumentMetadataScreen({super.key, required this.fileInfo});

  @override
  State<DocumentMetadataScreen> createState() => _DocumentMetadataScreenState();
}

class _DocumentMetadataScreenState extends State<DocumentMetadataScreen> {
  String _sha256Hash = 'Calculating...';
  bool _isCalculatingHash = true;
  String _fileDimensions = 'Detecting...';
  late File _file;
  FileStat? _fileStat;

  @override
  void initState() {
    super.initState();
    _file = File(widget.fileInfo.path);
    try {
      if (_file.existsSync()) {
        _fileStat = _file.statSync();
      }
    } catch (_) {}
    _loadMetadata();
  }

  String _formatSize(int bytes) {
    return TextUtils.formatFileSize(bytes);
  }

  Future<void> _loadMetadata() async {
    // 1. Calculate SHA-256 offline
    try {
      if (await _file.exists()) {
        final bytes = await _file.readAsBytes();
        final digest = sha256.convert(bytes);
        if (mounted) {
          setState(() {
            _sha256Hash = digest.toString();
            _isCalculatingHash = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _sha256Hash = 'File not found on disk';
            _isCalculatingHash = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sha256Hash = 'Error: $e';
          _isCalculatingHash = false;
        });
      }
    }

    // 2. If image, decode dimensions
    if (widget.fileInfo.type == FileType.image) {
      try {
        final decoded = await decodeImageFromList(await _file.readAsBytes());
        if (mounted) {
          setState(() {
            _fileDimensions = '${decoded.width} × ${decoded.height} px';
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _fileDimensions = 'Standard Image';
          });
        }
      }
    } else if (widget.fileInfo.type == FileType.pdf) {
      if (mounted) {
        setState(() {
          _fileDimensions = 'Portable Document Format (PDF)';
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _fileDimensions = 'Text Document';
        });
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    Fluttertoast.showToast(
      msg: '$label copied to clipboard',
      toastLength: Toast.LENGTH_SHORT,
      backgroundColor: const Color(0xFF10B981),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.primaryColor;

    final dateModified = _fileStat?.modified ?? DateTime.now();
    final dateStr = DateFormat('EEEE, MMM d, yyyy • h:mm a').format(dateModified);
    final fileSizeStr = _fileStat != null ? _formatSize(_fileStat!.size) : 'Unknown';
    final ext = widget.fileInfo.path.contains('.')
        ? widget.fileInfo.path.split('.').last.toUpperCase()
        : 'FILE';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Document Info',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 20,
            color: theme.textTheme.titleLarge?.color,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: ResponsiveLayout.getKeyboardPadding(context, defaultBottom: 32.0),
          physics: const BouncingScrollPhysics(),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: ResponsiveLayout.getDialogMaxWidth(context),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // File Icon and Name Banner
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Center(
                              child: Icon(
                                widget.fileInfo.type == FileType.pdf
                                    ? Icons.picture_as_pdf_rounded
                                    : widget.fileInfo.type == FileType.image
                                        ? Icons.image_rounded
                                        : Icons.description_rounded,
                                size: 36,
                                color: primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            widget.fileInfo.name,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              color: theme.textTheme.titleLarge?.color,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white12 : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$ext • $fileSizeStr',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Quick Actions Row
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            icon: const Icon(Icons.open_in_new_rounded, size: 20),
                            label: const Text('Open'),
                            onPressed: () => OpenFilex.open(widget.fileInfo.path),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              side: BorderSide(
                                color: isDark ? Colors.white24 : Colors.black12,
                              ),
                            ),
                            icon: const Icon(Icons.share_rounded, size: 20),
                            label: const Text('Share'),
                            onPressed: () {
                              Share.shareXFiles([XFile(widget.fileInfo.path)]);
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Details Cards
                    Text(
                      'Properties',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: theme.textTheme.titleMedium?.color,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
                        ),
                      ),
                      child: Column(
                        children: [
                          _buildDetailTile(
                            context,
                            icon: Icons.calendar_today_rounded,
                            title: 'Date Modified',
                            value: dateStr,
                          ),
                          const Divider(height: 1),
                          _buildDetailTile(
                            context,
                            icon: Icons.aspect_ratio_rounded,
                            title: 'Dimensions / Type',
                            value: _fileDimensions,
                          ),
                          const Divider(height: 1),
                          _buildDetailTile(
                            context,
                            icon: Icons.data_usage_rounded,
                            title: 'File Size',
                            value: fileSizeStr,
                          ),
                          const Divider(height: 1),
                          _buildDetailTile(
                            context,
                            icon: Icons.folder_open_rounded,
                            title: 'Storage Path',
                            value: widget.fileInfo.path,
                            isCopyable: true,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Cryptographic Integrity (SHA-256)
                    Text(
                      'Cryptographic Integrity (SHA-256)',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: theme.textTheme.titleMedium?.color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Use this cryptographic hash offline to prove this document has never been modified or tampered with.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: theme.hintColor,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF151517) : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.black12,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _sha256Hash,
                              style: TextStyle(
                                fontFamily: 'Courier',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                                height: 1.4,
                              ),
                            ),
                          ),
                          if (!_isCalculatingHash)
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 20),
                              tooltip: 'Copy Hash',
                              onPressed: () => _copyToClipboard(_sha256Hash, 'SHA-256 Hash'),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    bool isCopyable = false,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.primaryColor),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: theme.hintColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
              ],
            ),
          ),
          if (isCopyable)
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 18),
              onPressed: () => _copyToClipboard(value, title),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}
