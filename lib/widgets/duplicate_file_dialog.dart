import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

enum DuplicateFileAction {
  replace,
  keepBoth,
  skip,
}

class DuplicateFileResolution {
  final DuplicateFileAction action;
  final bool applyToAll;

  const DuplicateFileResolution({
    required this.action,
    this.applyToAll = false,
  });
}

class DuplicateFileDialog extends StatefulWidget {
  final String fileName;
  final String? destinationFolderName;
  final bool showApplyToAll;

  const DuplicateFileDialog({
    super.key,
    required this.fileName,
    this.destinationFolderName,
    this.showApplyToAll = false,
  });

  static Future<DuplicateFileResolution?> show(
    BuildContext context, {
    required String fileName,
    String? destinationFolderName,
    bool showApplyToAll = false,
  }) {
    return showDialog<DuplicateFileResolution>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: DuplicateFileDialog(
          fileName: fileName,
          destinationFolderName: destinationFolderName,
          showApplyToAll: showApplyToAll,
        ),
      ),
    );
  }

  static String generateUniqueFileName(String folderPath, String fileName) {
    final dotIdx = fileName.lastIndexOf('.');
    final nameWithoutExt = dotIdx != -1 ? fileName.substring(0, dotIdx) : fileName;
    final ext = dotIdx != -1 ? fileName.substring(dotIdx) : '';

    int counter = 1;
    String candidateName = '$nameWithoutExt ($counter)$ext';
    String candidatePath = '$folderPath${Platform.pathSeparator}$candidateName';

    while (File(candidatePath).existsSync()) {
      counter++;
      candidateName = '$nameWithoutExt ($counter)$ext';
      candidatePath = '$folderPath${Platform.pathSeparator}$candidateName';
    }

    return candidateName;
  }

  @override
  State<DuplicateFileDialog> createState() => _DuplicateFileDialogState();
}

class _DuplicateFileDialogState extends State<DuplicateFileDialog> {
  bool _applyToAll = false;

  IconData _getFileIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return Icons.picture_as_pdf_rounded;
    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp')) {
      return Icons.image_rounded;
    }
    if (lower.endsWith('.doc') || lower.endsWith('.docx') || lower.endsWith('.txt')) {
      return Icons.description_rounded;
    }
    return Icons.insert_drive_file_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final fileIcon = _getFileIcon(widget.fileName);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: AppTheme.surfaceBorder(context),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.45 : 0.12),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Icon & Title
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withOpacity(0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.copy_all_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'File Already Exists',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: AppTheme.textPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Conflict in ${widget.destinationFolderName ?? 'folder'}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // File Preview Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.tonal(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppTheme.surfaceBorder(context).withOpacity(0.7),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(fileIcon, size: 20, color: AppTheme.primary(context)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.fileName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Option 1: Allow this file also (Keep Both) - Highlighted
              _buildChoiceCard(
                context,
                icon: Icons.add_to_photos_rounded,
                iconBg: AppTheme.primary(context).withOpacity(0.12),
                iconColor: AppTheme.primary(context),
                title: 'Allow this file also',
                subtitle: 'Keep both files by renaming the new copy',
                isHighlighted: true,
                badgeText: 'Recommended',
                onTap: () => Navigator.pop(
                  context,
                  DuplicateFileResolution(
                    action: DuplicateFileAction.keepBoth,
                    applyToAll: _applyToAll,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Option 2: Replace with this file
              _buildChoiceCard(
                context,
                icon: Icons.sync_rounded,
                iconBg: Colors.redAccent.withOpacity(0.12),
                iconColor: Colors.redAccent,
                title: 'Replace with this file',
                subtitle: 'Overwrites existing file in the folder',
                isHighlighted: false,
                onTap: () => Navigator.pop(
                  context,
                  DuplicateFileResolution(
                    action: DuplicateFileAction.replace,
                    applyToAll: _applyToAll,
                  ),
                ),
              ),

              if (widget.showApplyToAll) ...[
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => setState(() => _applyToAll = !_applyToAll),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    child: Row(
                      children: [
                        SizedBox(
                          height: 22,
                          width: 22,
                          child: Checkbox(
                            value: _applyToAll,
                            activeColor: AppTheme.primary(context),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                            onChanged: (v) =>
                                setState(() => _applyToAll = v ?? false),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Apply to all remaining conflicts',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Skip / Cancel Button
              SizedBox(
                height: 44,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(
                    context,
                    DuplicateFileResolution(
                      action: DuplicateFileAction.skip,
                      applyToAll: _applyToAll,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary(context),
                    side: BorderSide(color: AppTheme.surfaceBorder(context)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Skip this file',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceCard(
    BuildContext context, {
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isHighlighted = false,
    String? badgeText,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isHighlighted
              ? AppTheme.primary(context).withOpacity(0.08)
              : AppTheme.tonal(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isHighlighted
                ? AppTheme.primary(context).withOpacity(0.4)
                : AppTheme.surfaceBorder(context),
            width: isHighlighted ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (badgeText != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primary(context),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badgeText,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isHighlighted
                  ? AppTheme.primary(context)
                  : AppTheme.textMuted(context),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper function to show a processing snackbar
void showProcessingSnackBar(
  BuildContext context, {
  String message = 'Processing... This may take a few seconds',
}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      backgroundColor: const Color(0xFF1E293B),
    ),
  );
}
