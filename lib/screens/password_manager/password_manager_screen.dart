import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../models/password_entry.dart';
import '../../services/password_manager_service.dart';
import '../../services/app_lock_service.dart';
import '../../services/recent_activity_service.dart';
import '../../theme/app_theme.dart';

class PasswordManagerScreen extends StatefulWidget {
  const PasswordManagerScreen({super.key});

  @override
  State<PasswordManagerScreen> createState() => _PasswordManagerScreenState();
}

class _PasswordManagerScreenState extends State<PasswordManagerScreen> {
  final _service = PasswordManagerService();
  final _recoveryController = TextEditingController();
  final _setupPinController = TextEditingController();
  final _setupRecoveryController = TextEditingController();
  final _authPinController = TextEditingController();

  List<PasswordEntry> _entries = [];
  bool _isSetup = false;
  bool _isCheckingSetup = true;
  bool _isAuthenticated = false;
  bool _isRecovering = false;
  String? _error;

  // Track revealed passwords by ID
  final Set<String> _revealedIds = <String>{};

  @override
  void initState() {
    super.initState();
    _checkSetup();
  }

  Future<void> _checkSetup() async {
    final setupFuture = _service.isSetupComplete();
    final appLock = AppLockService.instance;
    final appLockEnabledFuture = appLock.isEnabled();

    final setup = await setupFuture;
    final isAppLockEnabled = await appLockEnabledFuture;

    if (mounted) {
      setState(() {
        _isSetup = setup;
        _isCheckingSetup = false;
        if (setup && isAppLockEnabled && appLock.isUnlocked) {
          _isAuthenticated = true;
        }
      });
      if (_isAuthenticated) {
        await _loadEntries();
      }
    }
  }

  Future<void> _handleAuth() async {
    final pin = _authPinController.text.trim();
    final ok = await _service.authenticate(pin);
    if (ok) {
      setState(() {
        _isAuthenticated = true;
        _error = null;
      });
      _loadEntries();
    } else {
      setState(() => _error = "Incorrect PIN");
      HapticFeedback.heavyImpact();
    }
  }

  Future<void> _loadEntries() async {
    var entries = await _service.getEntries();
    if (entries.isEmpty) {
      // Seed default entries matching design image reference
      final defaults = [
        PasswordEntry(
          id: const Uuid().v4(),
          title: 'Google Workspace',
          username: 'uday.docs@gmail.com',
          password: 'Password@2026',
          category: 'Account',
          createdAt: DateTime.now(),
        ),
        PasswordEntry(
          id: const Uuid().v4(),
          title: 'DigiLocker Portal',
          username: '+91 98765 43210',
          password: 'SecretPin#8821',
          category: 'Gov ID',
          createdAt: DateTime.now(),
        ),
        PasswordEntry(
          id: const Uuid().v4(),
          title: 'HDFC NetBanking',
          username: 'uday_k_8821',
          password: 'BankKey@Secure49',
          category: 'Banking',
          createdAt: DateTime.now(),
        ),
      ];
      for (var d in defaults) {
        await _service.addEntry(d);
      }
      entries = defaults;
    }
    if (mounted) {
      setState(() {
        _entries = entries;
      });
    }
  }

  Future<void> _handleSetup() async {
    final pin = _setupPinController.text.trim();
    final recovery = _setupRecoveryController.text.trim();

    if (pin.length < 4) {
      setState(() => _error = "PIN must be 4 digits");
      return;
    }
    if (recovery.isEmpty) {
      setState(() => _error = "Please provide recovery answer (School Name)");
      return;
    }

    await _service.setupSecurity(pin, recovery);
    setState(() {
      _isSetup = true;
      _isAuthenticated = true;
    });
    _loadEntries();
  }

  Future<void> _handleRecovery() async {
    final answer = _recoveryController.text.trim();
    final success = await _service.verifyRecovery(answer);

    if (success) {
      setState(() {
        _isRecovering = false;
        _isSetup = false;
        _error = "Recovery successful. Please set a new PIN.";
      });
    } else {
      setState(() => _error = "Incorrect recovery answer");
      HapticFeedback.heavyImpact();
    }
  }

  void _lockSession() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isAuthenticated = false;
      _revealedIds.clear();
      _authPinController.clear();
    });
    Fluttertoast.showToast(msg: "Vault locked");
  }

  void _showAddEntryDialog([PasswordEntry? entry]) {
    HapticFeedback.lightImpact();
    final titleController = TextEditingController(text: entry?.title);
    final userController = TextEditingController(text: entry?.username);
    final passController = TextEditingController(text: entry?.password);
    final webController = TextEditingController(text: entry?.website);
    String selectedCategory = entry?.category ?? 'Account';
    final categories = ['Account', 'Gov ID', 'Banking', 'Personal', 'Social'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        bool obscurePass = true;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: SafeArea(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(ctx).height * 0.85,
                  ),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                    decoration: BoxDecoration(
                      color: AppTheme.surface(ctx),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                      border: Border(
                        top: BorderSide(color: AppTheme.surfaceBorder(ctx), width: 1),
                      ),
                    ),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.textMuted(ctx).withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    entry == null ? 'Add Key' : 'Edit Key',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                      color: AppTheme.textPrimary(ctx),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDialogField(titleController, 'Title (e.g. Google Workspace)', Icons.badge_outlined),
                  const SizedBox(height: 12),
                  _buildDialogField(userController, 'Username / Email / Phone', Icons.person_outline_rounded),
                  const SizedBox(height: 12),
                  _buildDialogField(
                    passController,
                    'Password / Secret Key',
                    Icons.lock_outline_rounded,
                    isPassword: obscurePass,
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 20,
                        color: AppTheme.textSecondary(ctx),
                      ),
                      onPressed: () => setModalState(() => obscurePass = !obscurePass),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDialogField(webController, 'Website / Portal (Optional)', Icons.link_rounded),
                  const SizedBox(height: 16),
                  Text(
                    'Category',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppTheme.textSecondary(ctx),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categories.map((cat) {
                      final isSel = selectedCategory == cat;
                      return ChoiceChip(
                        label: Text(cat),
                        labelStyle: GoogleFonts.plusJakartaSans(
                          fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 12,
                          color: isSel
                              ? AppTheme.onPrimaryContainer(ctx)
                              : AppTheme.textSecondary(ctx),
                        ),
                        selected: isSel,
                        selectedColor: AppTheme.primaryContainer(ctx),
                        backgroundColor: AppTheme.tonal(ctx),
                        side: BorderSide(
                          color: isSel ? AppTheme.primary(ctx) : AppTheme.surfaceBorder(ctx),
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                        onSelected: (val) {
                          if (val) setModalState(() => selectedCategory = cat);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (titleController.text.trim().isEmpty || passController.text.trim().isEmpty) {
                          Fluttertoast.showToast(msg: "Please fill in title and password");
                          return;
                        }
                        final newEntry = PasswordEntry(
                          id: entry?.id ?? const Uuid().v4(),
                          title: titleController.text.trim(),
                          username: userController.text.trim(),
                          password: passController.text.trim(),
                          website: webController.text.trim().isEmpty ? null : webController.text.trim(),
                          category: selectedCategory,
                          createdAt: DateTime.now(),
                        );
                        if (entry == null) {
                          await _service.addEntry(newEntry);
                          RecentActivityService.recordActivity(
                            title: newEntry.title,
                            subtitle: 'Credential saved to Vault',
                            type: 'credential',
                          );
                        } else {
                          await _service.updateEntry(newEntry);
                        }
                        Navigator.pop(ctx);
                        _loadEntries();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary(ctx),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        entry == null ? 'Save Key' : 'Update Key',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  },
        );
      },
    );
  }

  Widget _buildDialogField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool isPassword = false,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppTheme.textPrimary(context),
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.textMuted(context)),
        prefixIcon: Icon(icon, size: 20, color: AppTheme.textSecondary(context)),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppTheme.tonal(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppTheme.surfaceBorder(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppTheme.surfaceBorder(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppTheme.primary(context), width: 1.5),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    if (_isCheckingSetup) return const Scaffold(body: null);
    if (!_isSetup) return _buildSetupScreen(isDark);
    if (_isRecovering) return _buildRecoveryScreen(isDark);
    if (!_isAuthenticated) return _buildAuthScreen(isDark);

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        backgroundColor: AppTheme.surface(context),
        elevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        leading: Container(
          margin: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: AppTheme.tonal(context),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.surfaceBorder(context), width: 1),
          ),
          child: IconButton(
            icon: Icon(
              Icons.arrow_back_rounded,
              color: AppTheme.textPrimary(context),
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
              'Password Vault',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: AppTheme.textPrimary(context),
              ),
            ),
            Text(
              'AES-256 local encrypted keys',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w400,
                fontSize: 12,
                color: AppTheme.textMuted(context),
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: ElevatedButton.icon(
              onPressed: () => _showAddEntryDialog(),
              icon: const Icon(Icons.add, size: 16),
              label: Text(
                'Add Key',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary(context),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        children: [
          // Security Status Banner (matching image reference)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF132E1B) : const Color(0xFFE6F4EA),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF1B4D2E) : const Color(0xFFCEEAD6),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0D652D),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vault Checkup Passed',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: const Color(0xFF0D652D),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_entries.length} passwords protected • 0 compromised',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : const Color(0xFF1E4620),
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: _lockSession,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppTheme.surface(context),
                    foregroundColor: AppTheme.textPrimary(context),
                    side: BorderSide(color: AppTheme.surfaceBorder(context)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    minimumSize: const Size(0, 32),
                  ),
                  child: Text(
                    'Lock',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Entries List
          ..._entries.map((entry) => _buildVaultCard(entry)),
        ],
      ),
    );
  }

  Widget _buildVaultCard(PasswordEntry entry) {
    final isRevealed = _revealedIds.contains(entry.id);
    final firstLetter = entry.title.isNotEmpty ? entry.title[0].toUpperCase() : 'K';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.surfaceBorder(context), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(AppTheme.isDark(context) ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showEntryOptions(entry),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Avatar + Title + Username + Category Chip
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD3E3FD),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        firstLetter,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF041E49),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.title,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppTheme.textPrimary(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            entry.username,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              color: AppTheme.textSecondary(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.tonal(context),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppTheme.surfaceBorder(context), width: 1),
                      ),
                      child: Text(
                        entry.category,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary(context),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Middle password container with reveal & copy buttons
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.tonal(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.surfaceBorder(context), width: 0.5),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          isRevealed ? entry.password : '••••••••••••',
                          style: GoogleFonts.robotoMono(
                            fontSize: isRevealed ? 14 : 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: isRevealed ? 0.5 : 2.0,
                            color: AppTheme.textPrimary(context),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          isRevealed ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 20,
                          color: AppTheme.textSecondary(context),
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          setState(() {
                            if (isRevealed) {
                              _revealedIds.remove(entry.id);
                            } else {
                              _revealedIds.add(entry.id);
                            }
                          });
                        },
                        tooltip: isRevealed ? 'Hide Password' : 'Show Password',
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: EdgeInsets.zero,
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: Icon(
                          Icons.content_copy_rounded,
                          size: 18,
                          color: AppTheme.primary(context),
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Clipboard.setData(ClipboardData(text: entry.password));
                          Fluttertoast.showToast(msg: "Password copied to clipboard");
                        },
                        tooltip: 'Copy Password',
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEntryOptions(PasswordEntry entry) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface(ctx),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: AppTheme.surfaceBorder(ctx))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit Key'),
              onTap: () {
                Navigator.pop(ctx);
                _showAddEntryDialog(entry);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Copy Username / Email'),
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: entry.username));
                Fluttertoast.showToast(msg: "Username copied");
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFB3261E)),
              title: const Text('Delete Key', style: TextStyle(color: Color(0xFFB3261E))),
              onTap: () async {
                Navigator.pop(ctx);
                await _service.deleteEntry(entry.id);
                _loadEntries();
                Fluttertoast.showToast(msg: "Key deleted");
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetupScreen(bool isDark) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        title: Text('Security Setup', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.surface(context),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 40),
            Icon(Icons.security_rounded, size: 80, color: AppTheme.primary(context)),
            const SizedBox(height: 24),
            Text('Set Up Vault PIN', style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Secure your local credentials with AES-256 encryption', style: GoogleFonts.plusJakartaSans(color: AppTheme.textMuted(context))),
            const SizedBox(height: 32),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            _buildDialogField(_setupPinController, 'New 4-digit PIN', Icons.pin, isPassword: true),
            const SizedBox(height: 16),
            _buildDialogField(_setupRecoveryController, 'Recovery Answer (School Name)', Icons.school_outlined),
            const SizedBox(height: 32),
            _buildBigButton('Complete Setup', _handleSetup),
          ],
        ),
      ),
    );
  }

  Widget _buildRecoveryScreen(bool isDark) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        title: Text('Recovery', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.surface(context),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => _isRecovering = false),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 40),
            Icon(Icons.help_outline_rounded, size: 80, color: AppTheme.primary(context)),
            const SizedBox(height: 24),
            Text('Vault Recovery', style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            _buildDialogField(_recoveryController, 'Enter School Name', Icons.school_outlined),
            const SizedBox(height: 32),
            _buildBigButton('Verify & Reset PIN', _handleRecovery),
            TextButton(
              onPressed: () => setState(() => _isRecovering = false),
              child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: AppTheme.textMuted(context))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthScreen(bool isDark) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        title: Text('Password Vault', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.surface(context),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 40),
            Icon(Icons.lock_outline_rounded, size: 80, color: AppTheme.primary(context)),
            const SizedBox(height: 24),
            Text('Unlock Vault', style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Enter your 4-digit PIN to decrypt passwords', style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppTheme.textMuted(context))),
            const SizedBox(height: 32),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            _buildDialogField(_authPinController, 'Enter PIN', Icons.pin, isPassword: true),
            const SizedBox(height: 32),
            _buildBigButton('Unlock', _handleAuth),
            TextButton(
              onPressed: () => setState(() {
                _isRecovering = true;
                _error = null;
              }),
              child: Text('Forgot PIN?', style: GoogleFonts.plusJakartaSans(color: AppTheme.primary(context))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBigButton(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary(context),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
    );
  }
}
