import 'dart:io';
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
      builder: (ctx) => DuplicateFileDialog(
        fileName: fileName,
        destinationFolderName: destinationFolderName,
        showApplyToAll: showApplyToAll,
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

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return AlertDialog(
      backgroundColor: AppTheme.surface(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.copy_rounded,
              color: Colors.amber,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'File Already Exists',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: AppTheme.textPrimary(context),
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'A file named "${widget.fileName}" already exists in ${widget.destinationFolderName ?? 'this folder'}.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              height: 1.4,
              color: AppTheme.textSecondary(context),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.tonal(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.surfaceBorder(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildActionTile(
                  icon: Icons.find_replace_rounded,
                  iconColor: Colors.redAccent,
                  title: 'Replace with this file',
                  subtitle: 'Overwrites existing file',
                  onTap: () => Navigator.pop(
                    context,
                    DuplicateFileResolution(
                      action: DuplicateFileAction.replace,
                      applyToAll: _applyToAll,
                    ),
                  ),
                ),
                const Divider(height: 16),
                _buildActionTile(
                  icon: Icons.add_circle_outline_rounded,
                  iconColor: AppTheme.primary(context),
                  title: 'Allow this file also',
                  subtitle: 'Keep both files by renaming new file',
                  onTap: () => Navigator.pop(
                    context,
                    DuplicateFileResolution(
                      action: DuplicateFileAction.keepBoth,
                      applyToAll: _applyToAll,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (widget.showApplyToAll) ...[
            const SizedBox(height: 10),
            InkWell(
              onTap: () => setState(() => _applyToAll = !_applyToAll),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: Checkbox(
                        value: _applyToAll,
                        activeColor: AppTheme.primary(context),
                        onChanged: (v) => setState(() => _applyToAll = v ?? false),
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
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(
            context,
            DuplicateFileResolution(
              action: DuplicateFileAction.skip,
              applyToAll: _applyToAll,
            ),
          ),
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.textMuted(context),
          ),
          child: const Text('Skip this file'),
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: AppTheme.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textMuted(context),
              size: 18,
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
