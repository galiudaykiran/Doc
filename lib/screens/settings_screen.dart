import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/app_lock_service.dart';
import '../services/folder_lock_service.dart';
import '../services/notification_service.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:gallery_app/services/zip_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:fluttertoast/fluttertoast.dart';

class SettingsScreen extends StatefulWidget {
  final Function(ThemeMode) setThemeMode;

  const SettingsScreen({super.key, required this.setThemeMode});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  ThemeMode _themeMode = ThemeMode.system;
  bool _defaultViewIsGrid = true;
  double _storageUsedMb = 0.0;
  double _maxStorageMb = 1024.0;
  bool _appLockEnabled = false;
  bool _folderLockEnabled = false;
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _calculateStorageInfo();
    _loadAppLockSettings();
    _loadNotificationSettings();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final themeStr = prefs.getString('theme_mode') ?? 'system';
    setState(() {
      if (themeStr == 'light') {
        _themeMode = ThemeMode.light;
      } else if (themeStr == 'dark') {
        _themeMode = ThemeMode.dark;
      } else {
        _themeMode = ThemeMode.system;
      }

      _defaultViewIsGrid = prefs.getBool('default_view_is_grid') ?? true;
      _maxStorageMb = prefs.getDouble('max_storage_mb') ?? 1024.0;
    });
  }

  Future<void> _saveTheme(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    String modeStr = 'system';
    if (mode == ThemeMode.light) {
      modeStr = 'light';
    } else if (mode == ThemeMode.dark) {
      modeStr = 'dark';
    }
    
    await prefs.setString('theme_mode', modeStr);
    setState(() => _themeMode = mode);
    widget.setThemeMode(mode);
  }

  Future<void> _saveDefaultView(bool isGrid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('default_view_is_grid', isGrid);
    setState(() => _defaultViewIsGrid = isGrid);
  }

  Future<void> _calculateStorageInfo() async {
    try {
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final Directory documentFoldersDir = Directory(
        '${appDocDir.path}${Platform.pathSeparator}document_folders',
      );
      if (!await documentFoldersDir.exists()) return;

      int totalBytes = 0;
      await for (var entity in documentFoldersDir.list(recursive: true, followLinks: false)) {
        if (entity is File) totalBytes += await entity.length();
      }
      if (mounted) {
        setState(() => _storageUsedMb = totalBytes / (1024 * 1024));
      }
    } catch (_) {}
  }


  
  Future<void> _loadNotificationSettings() async {
    final enabled = await NotificationService.instance.isEnabled();
    if (mounted) setState(() => _notificationsEnabled = enabled);
  }



  Future<void> _toggleNotifications(bool value) async {
    await NotificationService.instance.setEnabled(value);
    setState(() => _notificationsEnabled = value);
  }





  void _showStorageBreakdown() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
         padding: const EdgeInsets.all(24),
         decoration: BoxDecoration(
           color: _getCardColor(isDark),
           borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24))
         ),
         child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Text('Storage Details', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: _getTextColor(isDark))),
               const SizedBox(height: 24),
               _buildStorageBreakdownItem(isDark, "Documents & Images", '${_storageUsedMb.toStringAsFixed(1)} MB', isDark ? Colors.white : Colors.black87),
               _buildStorageBreakdownItem(isDark, "Free Space", '${(_maxStorageMb - _storageUsedMb).toStringAsFixed(1)} MB', isDark ? Colors.white24 : Colors.grey.shade300),
               const SizedBox(height: 24),
            ]
         ),
      ),
    );
  }

  void _showExtendStorageDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: _getBgColor(isDark),
        title: Row(
          children: [
            Icon(Icons.auto_fix_high_rounded, color: Theme.of(context).primaryColor),
            const SizedBox(width: 12),
            Text('Premium Storage', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Increase your storage limit to store more high-quality documents and PDFs.', 
              style: GoogleFonts.poppins(fontSize: 14, color: _getSubTextColor(isDark))),
            const SizedBox(height: 24),
            _buildUpgradeOption(1024, '1 GB Plan', 'Standard', 'Default'),
            const SizedBox(height: 12),
            _buildUpgradeOption(5 * 1024, '5 GB Plan', 'Professional', 'Recommended'),
            const SizedBox(height: 12),
            _buildUpgradeOption(10 * 1024, '10 GB Plan', 'Enterprise', 'Maximum'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Maybe Later', style: GoogleFonts.poppins(color: _getSubTextColor(isDark))),
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradeOption(double sizeMb, String title, String tier, String badge) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCurrent = _maxStorageMb == sizeMb;

    return GestureDetector(
      onTap: isCurrent ? null : () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble('max_storage_mb', sizeMb);
        setState(() {
          _maxStorageMb = sizeMb;
        });
        Navigator.pop(context);
        _showDummySnackBar('Successfully upgraded to $title!');
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _getCardColor(isDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCurrent ? Theme.of(context).primaryColor : (isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
            width: isCurrent ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(badge, style: GoogleFonts.poppins(fontSize: 10, color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  Text(tier, style: GoogleFonts.poppins(fontSize: 12, color: _getSubTextColor(isDark))),
                ],
              ),
            ),
            if (isCurrent)
              Icon(Icons.check_circle_rounded, color: Theme.of(context).primaryColor)
            else
              Icon(Icons.add_circle_outline_rounded, color: _getSubTextColor(isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageBreakdownItem(bool isDark, String label, String size, Color color) {
     return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
           children: [
             Icon(Icons.circle, size: 12, color: color),
             const SizedBox(width: 12),
             Text(label, style: GoogleFonts.poppins(color: _getTextColor(isDark), fontSize: 14)),
             const Spacer(),
             Text(size, style: GoogleFonts.poppins(color: _getSubTextColor(isDark), fontSize: 14, fontWeight: FontWeight.w600)),
           ]
        ),
     );
  }

  void _showAboutDialog(bool isDark) {
    showAboutDialog(
      context: context,
      applicationName: 'Document Hub',
      applicationVersion: '2.1.0 (Build 2024.05.08)',
      applicationIcon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.description_rounded, color: Theme.of(context).colorScheme.onPrimary, size: 30),
      ),
      children: [
        const SizedBox(height: 16),
        Text(
          'Document Hub is a premium productivity suite designed for seamless document management. Organize your PDFs, images, and notes with state-of-the-art glassmorphic aesthetics and robust security.',
          style: GoogleFonts.poppins(fontSize: 14, color: _getTextColor(isDark)),
        ),
        const SizedBox(height: 20),
        _buildAboutDetail('Developer', 'Gali Uday Kiran'),
        _buildAboutDetail('Version', '2.1.0 (Build 2024.05.08)'),
        _buildAboutDetail('Features', 'Password Manager, Advanced Scanner, PDF Suite, Notes, Todos, Trash'),
        _buildAboutDetail('Security', 'Hardware-Backed App Lock & Folder Protection'),
        _buildAboutDetail('Theme', 'Premium Monochromatic Glassmorphism'),
        const SizedBox(height: 16),
        Text(
          '© 2024 Document Hub Team. All rights reserved.',
          style: GoogleFonts.poppins(fontSize: 12, color: _getSubTextColor(isDark)),
        ),
      ],
    );
  }

  Widget _buildAboutDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 85,
            child: Text(
              '$label: ',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Theme.of(context).primaryColor.withOpacity(0.8),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDummySnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 3)));
  }

  // -------------- STYLING TOKENS --------------
  Color _getBgColor(bool isDark) => isDark ? Colors.black : const Color(0xFFF7F8FA);
  Color _getCardColor(bool isDark) => isDark ? Colors.white.withOpacity(0.05) : Colors.white;
  Color _getIconBgColor(bool isDark) => isDark ? Colors.white.withOpacity(0.1) : const Color(0xFFEEF0F7);
  Color _getIconColor(bool isDark) => isDark ? Colors.white : Theme.of(context).primaryColor;
  Color _getTextColor(bool isDark) => isDark ? Colors.white : Colors.black87;
  Color _getSubTextColor(bool isDark) => isDark ? Colors.white54 : Colors.black54;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: _getBgColor(isDark),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: _getTextColor(isDark)),
            onPressed: () => Navigator.pop(context),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Settings', style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: _getTextColor(isDark))),
              Text('Manage your preferences and app settings', style: GoogleFonts.poppins(fontSize: 12, color: _getSubTextColor(isDark))),
            ],
          ),
          actions: [
            Padding(
               padding: const EdgeInsets.only(right: 16),
               child: Container(
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05))),
                  child: IconButton(
                     icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, color: _getSubTextColor(isDark)),
                     onPressed: () {
                         _saveTheme(isDark ? ThemeMode.light : ThemeMode.dark);
                     }, 
                  )
               )
            )
          ],
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('PREFERENCES').animate().fade(delay: 50.ms),
            _buildCardGroup(isDark, [
              _buildSettingRow(isDark, icon: Icons.language_rounded, title: 'Language', subtitle: 'English', trailing: _buildArrow(isDark), onTap: () => _showDummySnackBar('Language settings coming soon!')),
              _buildDivider(isDark),
              _buildSettingRow(
                isDark,
                icon: _defaultViewIsGrid ? Icons.grid_view_rounded : Icons.view_list_rounded,
                title: 'Default Folder View',
                subtitle: _defaultViewIsGrid ? 'Grid layout active' : 'List layout active',
                trailing: CupertinoSwitch(
                  value: _defaultViewIsGrid,
                  onChanged: (val) => _saveDefaultView(val),
                  activeColor: isDark ? Colors.white : Colors.black,
                ),
              ),
              _buildDivider(isDark),
              _buildSettingRow(
                isDark,
                icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                title: 'Theme Preference',
                subtitle: _themeMode == ThemeMode.dark ? 'Dark Mode' : (_themeMode == ThemeMode.light ? 'Light Mode' : 'System Default'),
                trailing: _buildArrow(isDark),
                onTap: () => _saveTheme(isDark ? ThemeMode.light : ThemeMode.dark),
              ),
            ]).animate().fade(duration: 400.ms).slideY(begin: 0.1, curve: Curves.easeOutCubic),
            
            const SizedBox(height: 20),
            _buildSectionTitle('NOTIFICATIONS').animate().fade(delay: 100.ms),
            _buildCardGroup(isDark, [
              _buildSettingRow(
                isDark,
                icon: Icons.notifications_active_rounded,
                title: 'Enable Notifications',
                subtitle: _notificationsEnabled
                    ? 'Todo reminders are active'
                    : 'All notifications are muted',
                trailing: CupertinoSwitch(
                  value: _notificationsEnabled,
                  onChanged: _toggleNotifications,
                  activeColor: isDark ? Colors.white : Colors.black,
                ),
              ),
              _buildDivider(isDark),
              _buildSettingRow(
                isDark,
                icon: Icons.notifications_paused_rounded,
                title: 'Todo Reminders',
                subtitle: 'Get reminded when tasks are due',
                trailing: _buildArrow(isDark),
                onTap: () => _notificationsEnabled
                    ? _showDummySnackBar('Todo reminders are always sent when a due date is set.')
                    : _showDummySnackBar('Enable notifications first.'),
              ),
            ]).animate().fade(delay: 100.ms, duration: 400.ms).slideY(begin: 0.1, curve: Curves.easeOutCubic),

            const SizedBox(height: 20),
            _buildSectionTitle('STORAGE').animate().fade(delay: 200.ms),
            _buildCardGroup(isDark, [
               _buildStorageItem(isDark),
               _buildDivider(isDark),
               _buildSettingRow(
                 isDark, 
                 icon: Icons.unarchive_rounded, 
                 title: 'Extend Storage Capacity', 
                 subtitle: 'Upgrade to 5GB or 10GB for more space', 
                 trailing: _buildArrow(isDark),
                 onTap: _showExtendStorageDialog,
               ),
            ]).animate().fade(delay: 200.ms, duration: 400.ms).slideY(begin: 0.1, curve: Curves.easeOutCubic),            const SizedBox(height: 20),
            _buildSectionTitle('SECURITY').animate().fade(delay: 300.ms),
            _buildCardGroup(isDark, [
              _buildSettingRow(isDark, icon: Icons.security_rounded, title: 'App Lock', subtitle: 'Protect the app with PIN', trailing: CupertinoSwitch(value: _appLockEnabled, onChanged: _toggleAppLock, activeColor: isDark ? Colors.white : Colors.black)),
              _buildDivider(isDark),
              _buildSettingRow(isDark, icon: Icons.vpn_key_rounded, title: 'Change App PIN', subtitle: 'Update your security PIN', trailing: _buildArrow(isDark), onTap: () => _setOrChangeAppLockPin()),
              _buildDivider(isDark),
              _buildSettingRow(isDark, icon: Icons.folder_special_rounded, title: 'Folder Lock', subtitle: 'Protect individual folders', trailing: CupertinoSwitch(value: _folderLockEnabled, onChanged: _toggleFolderLock, activeColor: isDark ? Colors.white : Colors.black)),
              _buildDivider(isDark),
              _buildSettingRow(isDark, icon: Icons.password_rounded, title: 'Change Folder PIN', subtitle: 'Update your folder PIN', trailing: _buildArrow(isDark), onTap: () => _setOrChangeFolderLockPin()),
            ]).animate().fade(delay: 300.ms, duration: 400.ms).slideY(begin: 0.1, curve: Curves.easeOutCubic),

            const SizedBox(height: 20),
            _buildSectionTitle('MORE').animate().fade(delay: 400.ms),
            _buildCardGroup(isDark, [
              _buildSettingRow(isDark, icon: Icons.cloud_upload_rounded, title: 'Backup & Restore', subtitle: 'Offline ZIP backup and restore', trailing: _buildArrow(isDark), onTap: _showBackupRestoreDialog),
              _buildDivider(isDark),
              _buildSettingRow(isDark, icon: Icons.info_outline_rounded, title: 'About Document Hub', subtitle: 'Version 2.1.0 (Build 2024.05.08)', trailing: _buildArrow(isDark), onTap: () => _showAboutDialog(isDark)),
            ]).animate().fade(delay: 400.ms, duration: 400.ms).slideY(begin: 0.1, curve: Curves.easeOutCubic),
            
            const SizedBox(height: 40),
            Center(
               child: Text('© 2024 Document Hub. All rights reserved.', style: GoogleFonts.poppins(fontSize: 11, color: _getSubTextColor(isDark))),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          color: Theme.of(context).primaryColor,
          fontWeight: FontWeight.w600,
          fontSize: 11,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildCardGroup(bool isDark, List<Widget> children) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: isDark ? ImageFilter.blur(sigmaX: 12, sigmaY: 12) : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
        child: Container(
          decoration: BoxDecoration(
            color: _getCardColor(isDark),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
          ),
          child: Column(
            children: children,
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 60),
      child: Divider(height: 1, thickness: 1, color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
    );
  }

  Widget _buildSettingRow(bool isDark, {required IconData icon, required String title, required String subtitle, required Widget trailing, VoidCallback? onTap}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _getIconBgColor(isDark),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: _getIconColor(isDark)),
      ),
      title: Text(title, style: GoogleFonts.poppins(color: _getTextColor(isDark), fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: GoogleFonts.poppins(color: _getSubTextColor(isDark), fontSize: 12)),
      trailing: trailing,
      onTap: onTap,
    );
  }

  Widget _buildArrow(bool isDark) {
    return Icon(Icons.arrow_forward_ios_rounded, color: _getSubTextColor(isDark), size: 14);
  }

  Widget _buildStorageItem(bool isDark) {
     final targetValue = (_storageUsedMb / _maxStorageMb).clamp(0.0, 1.0);
     return Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
           children: [
              SizedBox(
                 width: 70, height: 70,
                 child: Stack(
                    alignment: Alignment.center,
                    children: [
                       TweenAnimationBuilder<double>(
                         tween: Tween<double>(begin: 0, end: targetValue),
                         duration: const Duration(seconds: 1),
                         curve: Curves.easeOutCubic,
                         builder: (context, value, child) {
                           return CircularProgressIndicator(
                              value: value,
                              strokeWidth: 6,
                              backgroundColor: _getIconBgColor(isDark),
                              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                           );
                         },
                       ),
                       TweenAnimationBuilder<double>(
                         tween: Tween<double>(begin: 0, end: targetValue * 100),
                         duration: const Duration(seconds: 1),
                         curve: Curves.easeOutCubic,
                         builder: (context, value, child) {
                           return Text('${value.toStringAsFixed(0)}%', style: GoogleFonts.poppins(color: _getTextColor(isDark), fontWeight: FontWeight.bold));
                         },
                       ),
                    ]
                 )
              ),
              const SizedBox(width: 20),
              Expanded(
                 child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Text('Storage Used', style: GoogleFonts.poppins(color: _getTextColor(isDark), fontSize: 14, fontWeight: FontWeight.bold)),
                       Text('${_storageUsedMb.toStringAsFixed(1)} MB of ${_maxStorageMb >= 1024 ? "${(_maxStorageMb / 1024).toStringAsFixed(0)} GB" : "${_maxStorageMb.toStringAsFixed(0)} MB"} used', style: GoogleFonts.poppins(color: _getSubTextColor(isDark), fontSize: 12)),
                       const SizedBox(height: 8),
                       ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0, end: targetValue),
                            duration: const Duration(seconds: 1),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, child) {
                              return LinearProgressIndicator(
                                 value: value,
                                 minHeight: 6,
                                 backgroundColor: _getIconBgColor(isDark),
                                 valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                              );
                            },
                          )
                       )
                    ]
                 )
              ),
              const SizedBox(width: 16),
              GestureDetector(
                 onTap: _showStorageBreakdown,
                 child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                       color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                       borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                       children: [
                          Icon(Icons.folder_open_rounded, size: 16, color: _getTextColor(isDark)),
                          const SizedBox(width: 8),
                          Text('Manage Storage', style: GoogleFonts.poppins(fontSize: 11, color: _getIconColor(isDark), fontWeight: FontWeight.w600)),
                       ]
                    )
                 )
              ),
              const SizedBox(width: 12),
              _buildArrow(isDark),
           ]
        ),
     );
  }

  Future<void> _loadAppLockSettings() async {
    final isEnabled = await AppLockService.instance.isEnabled();
    final fEnabled = await FolderLockService.instance.isEnabled();
    if (mounted) setState(() {
      _appLockEnabled = isEnabled;
      _folderLockEnabled = fEnabled;
    });
  }

  Future<void> _toggleAppLock(bool value) async {
    final service = AppLockService.instance;
    if (value && !await service.hasPin()) {
      await _setOrChangeAppLockPin();
    } else {
      await service.setEnabled(value);
      setState(() => _appLockEnabled = value);
    }
  }

  Future<void> _setOrChangeAppLockPin() async {
    final controller = TextEditingController();
    final confirmController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set App PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: controller, keyboardType: TextInputType.number, obscureText: true, maxLength: 4, decoration: const InputDecoration(hintText: 'Enter 4-digit PIN')),
            TextField(controller: confirmController, keyboardType: TextInputType.number, obscureText: true, maxLength: 4, decoration: const InputDecoration(hintText: 'Confirm PIN')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () {
            if (controller.text.length == 4 && controller.text == confirmController.text) Navigator.pop(context, controller.text);
          }, child: const Text('Save')),
        ],
      ),
    );
    if (result != null) {
      await AppLockService.instance.setPin(result);
      await AppLockService.instance.setEnabled(true);
      setState(() => _appLockEnabled = true);
    }
  }

  Future<void> _toggleFolderLock(bool value) async {
    final service = FolderLockService.instance;
    if (value && !await service.hasPin()) {
      await _setOrChangeFolderLockPin();
    } else {
      await service.setEnabled(value);
      setState(() => _folderLockEnabled = value);
    }
  }

  Future<void> _setOrChangeFolderLockPin() async {
    final controller = TextEditingController();
    final confirmController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Folder PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: controller, keyboardType: TextInputType.number, obscureText: true, maxLength: 4, decoration: const InputDecoration(hintText: 'Enter 4-digit PIN')),
            TextField(controller: confirmController, keyboardType: TextInputType.number, obscureText: true, maxLength: 4, decoration: const InputDecoration(hintText: 'Confirm PIN')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () {
            if (controller.text.length == 4 && controller.text == confirmController.text) {
              Navigator.pop(context, controller.text);
            }
          }, child: const Text('Save')),
        ],
      ),
    );
    if (result != null) {
      await FolderLockService.instance.setPin(result);
      await FolderLockService.instance.setEnabled(true);
      setState(() => _folderLockEnabled = true);
    }
  }

  void _showBackupRestoreDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Offline Backup & Restore',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.archive_rounded, color: Theme.of(context).primaryColor),
              ),
              title: Text(
                'Create ZIP Backup',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              subtitle: const Text('Package all documents offline'),
              onTap: () {
                Navigator.pop(context);
                _backupToZip();
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.unarchive_rounded, color: Theme.of(context).primaryColor),
              ),
              title: Text(
                'Restore from ZIP Archive',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              subtitle: const Text('Extract offline ZIP into Document Hub'),
              onTap: () {
                Navigator.pop(context);
                _restoreFromZip();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _backupToZip() async {
    try {
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final Directory docDir = Directory('${appDocDir.path}${Platform.pathSeparator}document_folders');
      if (!await docDir.exists()) {
        Fluttertoast.showToast(msg: "No documents to backup");
        return;
      }
      Fluttertoast.showToast(msg: "Creating ZIP backup...");
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outPath = '${appDocDir.path}${Platform.pathSeparator}DocumentHub_Backup_$timestamp.zip';
      final zip = await ZipService.compressDirectory(docDir, outPath);
      if (zip != null && await zip.exists()) {
        Fluttertoast.showToast(msg: "Backup saved: ${zip.path.split(Platform.pathSeparator).last}");
        await Share.shareXFiles([XFile(zip.path)], text: 'Document Hub Offline Backup');
      } else {
        Fluttertoast.showToast(msg: "Backup failed", backgroundColor: Colors.red);
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Error: $e", backgroundColor: Colors.red);
    }
  }

  Future<void> _restoreFromZip() async {
    try {
      final result = await fp.FilePicker.platform.pickFiles(type: fp.FileType.custom, allowedExtensions: ['zip']);
      if (result == null || result.files.single.path == null) return;
      final zipFile = File(result.files.single.path!);
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final zipName = zipFile.path.split(Platform.pathSeparator).last.replaceAll('.zip', '');
      final targetDir = Directory('${appDocDir.path}${Platform.pathSeparator}document_folders${Platform.pathSeparator}$zipName');
      Fluttertoast.showToast(msg: "Restoring files...");
      final count = await ZipService.extractZipToDirectory(zipFile, targetDir);
      if (count > 0) {
        Fluttertoast.showToast(msg: "Restored $count files into '$zipName'", backgroundColor: const Color(0xFF10B981));
        _calculateStorageInfo();
      } else {
        Fluttertoast.showToast(msg: "No files found in archive", backgroundColor: Colors.orange);
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Error: $e", backgroundColor: Colors.red);
    }
  }
}
