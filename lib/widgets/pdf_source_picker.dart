import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:path_provider/path_provider.dart';
import 'package:gallery_app/utils/text_utils.dart';

class PdfSourcePicker {
  /// Prompts the user to pick a single PDF from either Document Hub folders or Device Storage.
  static Future<String?> pickSinglePdf(
    BuildContext context, {
    String title = 'Select PDF',
  }) async {
    final source = await showModalBottomSheet<_PdfSourceType>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SourceChoiceSheet(title: title),
    );

    if (source == null) return null;

    if (source == _PdfSourceType.device) {
      final result = await fp.FilePicker.platform.pickFiles(
        type: fp.FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result != null && result.files.isNotEmpty) {
        return result.files.single.path;
      }
      return null;
    } else {
      if (!context.mounted) return null;
      return await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => const _DocumentHubPdfPickerSheet(multiSelect: false),
      );
    }
  }

  /// Prompts the user to pick one or more PDFs from either Document Hub folders or Device Storage.
  static Future<List<String>?> pickMultiplePdfs(
    BuildContext context, {
    String title = 'Add PDF Files',
  }) async {
    final source = await showModalBottomSheet<_PdfSourceType>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SourceChoiceSheet(title: title),
    );

    if (source == null) return null;

    if (source == _PdfSourceType.device) {
      final result = await fp.FilePicker.platform.pickFiles(
        type: fp.FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
      );
      if (result != null) {
        return result.files
            .where((f) => f.path != null)
            .map((f) => f.path!)
            .toList();
      }
      return null;
    } else {
      if (!context.mounted) return null;
      final selected = await showModalBottomSheet<List<String>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => const _DocumentHubPdfPickerSheet(multiSelect: true),
      );
      return selected;
    }
  }
}

enum _PdfSourceType { documentHub, device }

class _SourceChoiceSheet extends StatelessWidget {
  final String title;
  const _SourceChoiceSheet({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Choose where you want to select the PDF from',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 20),
          _buildSourceOption(
            context,
            icon: Icons.folder_special_rounded,
            title: 'Document Hub Folders',
            subtitle: 'Choose from your created and organized folders',
            type: _PdfSourceType.documentHub,
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _buildSourceOption(
            context,
            icon: Icons.phone_android_rounded,
            title: 'Browse Device Storage',
            subtitle: 'Pick any PDF stored on your phone or SD card',
            type: _PdfSourceType.device,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildSourceOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required _PdfSourceType type,
    required bool isDark,
  }) {
    return InkWell(
      onTap: () => Navigator.pop(context, type),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white12 : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: isDark ? Colors.white : Colors.black87),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentHubPdfPickerSheet extends StatefulWidget {
  final bool multiSelect;
  const _DocumentHubPdfPickerSheet({required this.multiSelect});

  @override
  State<_DocumentHubPdfPickerSheet> createState() =>
      _DocumentHubPdfPickerSheetState();
}

class _DocumentHubPdfPickerSheetState
    extends State<_DocumentHubPdfPickerSheet> {
  bool _isLoading = true;
  Map<String, List<File>> _folderPdfs = {};
  String _searchQuery = '';
  final Set<String> _selectedPaths = {};

  @override
  void initState() {
    super.initState();
    _loadPdfs();
  }

  Future<void> _loadPdfs() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final rootDir = Directory(
        '${appDir.path}${Platform.pathSeparator}document_folders',
      );
      if (!await rootDir.exists()) {
        await rootDir.create(recursive: true);
      }

      final folders = rootDir.listSync().whereType<Directory>().toList();
      final map = <String, List<File>>{};

      for (final folder in folders) {
        final folderName = folder.path.split(Platform.pathSeparator).last;
        final pdfs = folder
            .listSync()
            .whereType<File>()
            .where((f) => f.path.toLowerCase().endsWith('.pdf'))
            .toList();
        if (pdfs.isNotEmpty) {
          // Sort newest first
          pdfs.sort(
            (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
          );
          map[folderName] = pdfs;
        }
      }

      if (mounted) {
        setState(() {
          _folderPdfs = map;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Filter by search
    final filtered = <String, List<File>>{};
    _folderPdfs.forEach((folderName, files) {
      final matchedFiles = files.where((file) {
        final name = file.path.split(Platform.pathSeparator).last.toLowerCase();
        return name.contains(_searchQuery.toLowerCase()) ||
            folderName.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
      if (matchedFiles.isNotEmpty) {
        filtered[folderName] = matchedFiles;
      }
    });

    final totalPdfCount =
        filtered.values.fold<int>(0, (sum, list) => sum + list.length);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.multiSelect
                              ? 'Select PDFs from Folders'
                              : 'Select PDF from Folder',
                          style: GoogleFonts.poppins(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        if (widget.multiSelect && _selectedPaths.isNotEmpty)
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: theme.primaryColor,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                            ),
                            icon: const Icon(Icons.check_rounded, size: 16),
                            label: Text(
                              'Add (${_selectedPaths.length})',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onPressed: () =>
                                Navigator.pop(context, _selectedPaths.toList()),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Search bar
                    TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search PDFs or folders...',
                        hintStyle: GoogleFonts.poppins(
                          fontSize: 13,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withOpacity(0.06)
                            : const Color(0xFFF1F5F9),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 0,
                          horizontal: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Content
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : totalPdfCount == 0
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.picture_as_pdf_outlined,
                                    size: 54,
                                    color: isDark
                                        ? Colors.white24
                                        : Colors.black26,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No PDF files found in Document Hub folders',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'You can also pick files from Device Storage',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: isDark
                                          ? Colors.white38
                                          : Colors.black38,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            itemCount: filtered.keys.length,
                            itemBuilder: (ctx, folderIdx) {
                              final folderName =
                                  filtered.keys.elementAt(folderIdx);
                              final pdfs = filtered[folderName]!;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.04)
                                      : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white10
                                        : Colors.black.withOpacity(0.05),
                                  ),
                                ),
                                child: Theme(
                                  data: theme.copyWith(
                                    dividerColor: Colors.transparent,
                                  ),
                                  child: ExpansionTile(
                                    initiallyExpanded: true,
                                    leading: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.white10
                                            : Colors.blue.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.folder_rounded,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.blue[700],
                                        size: 20,
                                      ),
                                    ),
                                    title: Text(
                                      folderName,
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${pdfs.length} PDF${pdfs.length == 1 ? '' : 's'}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: isDark
                                            ? Colors.white54
                                            : Colors.black54,
                                      ),
                                    ),
                                    children: pdfs.map((file) {
                                      final fileName = file.path
                                          .split(Platform.pathSeparator)
                                          .last;
                                      final size = file.lengthSync();
                                      final isSelected =
                                          _selectedPaths.contains(file.path);

                                      return ListTile(
                                        dense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 2,
                                        ),
                                        leading: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: const Icon(
                                            Icons.picture_as_pdf_rounded,
                                            color: Colors.red,
                                            size: 18,
                                          ),
                                        ),
                                        title: Text(
                                          fileName,
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 13,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black87,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: Text(
                                          TextUtils.formatFileSize(size),
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            color: isDark
                                                ? Colors.white54
                                                : Colors.black45,
                                          ),
                                        ),
                                        trailing: widget.multiSelect
                                            ? Checkbox(
                                                value: isSelected,
                                                onChanged: (val) {
                                                  setState(() {
                                                    if (val == true) {
                                                      _selectedPaths.add(
                                                        file.path,
                                                      );
                                                    } else {
                                                      _selectedPaths.remove(
                                                        file.path,
                                                      );
                                                    }
                                                  });
                                                },
                                              )
                                            : const Icon(
                                                Icons.arrow_forward_ios_rounded,
                                                size: 14,
                                              ),
                                        onTap: () {
                                          if (widget.multiSelect) {
                                            setState(() {
                                              if (isSelected) {
                                                _selectedPaths.remove(file.path);
                                              } else {
                                                _selectedPaths.add(file.path);
                                              }
                                            });
                                          } else {
                                            Navigator.pop(context, file.path);
                                          }
                                        },
                                      );
                                    }).toList(),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}

