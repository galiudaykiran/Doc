import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:fluttertoast/fluttertoast.dart';

class FolderPickerDialog extends StatefulWidget {
  final String defaultFileName;
  final bool isFolderOnly;

  const FolderPickerDialog({
    super.key,
    required this.defaultFileName,
    this.isFolderOnly = false,
  });

  @override
  State<FolderPickerDialog> createState() => _FolderPickerDialogState();
}

class _FolderPickerDialogState extends State<FolderPickerDialog> {
  List<Directory> _folders = [];
  String? _selectedFolderPath;
  bool _isLoading = true;
  final TextEditingController _newFolderController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  @override
  void dispose() {
    _newFolderController.dispose();
    super.dispose();
  }

  Future<void> _loadFolders() async {
    try {
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final String appDocPath = appDocDir.path;
      final Directory folderDir = Directory(
        '$appDocPath${Platform.pathSeparator}document_folders',
      );

      if (!await folderDir.exists()) {
        await folderDir.create(recursive: true);
      }

      final List<FileSystemEntity> entities = await folderDir.list().toList();
      final List<Directory> folders = entities.whereType<Directory>().toList();

      setState(() {
        _folders = folders;
        _isLoading = false;
        if (folders.isNotEmpty) {
          _selectedFolderPath = folders.first.path;
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createNewFolder() async {
    final folderName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('New Folder', style: GoogleFonts.poppins()),
        content: TextField(
          controller: _newFolderController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Folder Name',
            hintText: 'Enter folder name',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          FilledButton(
            onPressed: () {
              if (_newFolderController.text.trim().isNotEmpty) {
                Navigator.pop(ctx, _newFolderController.text.trim());
              }
            },
            child: Text('Create', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );

    if (folderName != null) {
      try {
        final Directory appDocDir = await getApplicationDocumentsDirectory();
        final newFolderPath =
            '${appDocDir.path}${Platform.pathSeparator}document_folders${Platform.pathSeparator}$folderName';
        final newFolder = Directory(newFolderPath);
        await newFolder.create(recursive: true);

        _newFolderController.clear();
        await _loadFolders();
        setState(() => _selectedFolderPath = newFolderPath);

        Fluttertoast.showToast(msg: 'Folder "$folderName" created');
      } catch (e) {
        Fluttertoast.showToast(msg: 'Error creating folder: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).primaryColor;
    
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.folder_rounded, color: accentColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Save PDF To',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
          if (!widget.isFolderOnly)
            IconButton(
              onPressed: () => Navigator.pop(context, {'action': 'share'}),
              icon: Icon(Icons.share_rounded, color: accentColor),
              tooltip: 'Share PDF',
            ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: accentColor))
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select a folder:',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_folders.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.folder_off_rounded,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No folders yet',
                              style: GoogleFonts.poppins(color: Colors.grey),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Create a new folder to save your PDF',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 250),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _folders.length,
                        itemBuilder: (context, index) {
                          final folder = _folders[index];
                          final folderName = folder.path
                              .split(Platform.pathSeparator)
                              .last;
                          final isSelected = _selectedFolderPath == folder.path;

                          return ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? accentColor.withOpacity(0.2)
                                    : Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.folder_rounded,
                                color: isSelected
                                    ? accentColor
                                    : Colors.grey,
                              ),
                            ),
                            title: Text(
                              folderName,
                              style: GoogleFonts.poppins(
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                            trailing: isSelected
                                ? Icon(
                                    Icons.check_circle_rounded,
                                    color: accentColor,
                                  )
                                : null,
                            onTap: () {
                              setState(() => _selectedFolderPath = folder.path);
                            },
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            selected: isSelected,
                            selectedTileColor: accentColor.withOpacity(0.1),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _createNewFolder,
                    icon: const Icon(Icons.create_new_folder_rounded),
                    label: Text(
                      'Create New Folder',
                      style: GoogleFonts.poppins(),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accentColor,
                      side: BorderSide(color: accentColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: GoogleFonts.poppins()),
        ),
        FilledButton(
          onPressed: _selectedFolderPath != null
              ? () => Navigator.pop(context, {'action': 'save', 'folder': _selectedFolderPath})
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: accentColor,
            foregroundColor: isDark ? Colors.black : Colors.white,
          ),
          child: Text(widget.isFolderOnly ? 'Extract Here' : 'Save Here', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
