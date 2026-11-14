import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import 'dart:ui';
import '../../models/password_entry.dart';
import '../../services/password_manager_service.dart';
import '../../services/app_lock_service.dart';
import '../../widgets/premium_pin_overlay.dart';

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
      if (_isAuthenticated) _loadEntries();
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
    final entries = await _service.getEntries();
    setState(() {
      _entries = entries;
    });
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

  void _showAddEntryDialog([PasswordEntry? entry]) {
    final titleController = TextEditingController(text: entry?.title);
    final userController = TextEditingController(text: entry?.username);
    final passController = TextEditingController(text: entry?.password);
    final webController = TextEditingController(text: entry?.website);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        bool obscurePass = true;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
            margin: const EdgeInsets.all(16),
            padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry == null ? 'Add Password' : 'Edit Password', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 20)),
                const SizedBox(height: 20),
                _buildDialogField(titleController, 'Title (e.g. Google)', Icons.title),
                const SizedBox(height: 12),
                _buildDialogField(userController, 'Username/Email', Icons.person_outline),
                const SizedBox(height: 12),
                _buildDialogField(
                  passController, 
                  'Password', 
                  Icons.lock_outline, 
                  isPassword: obscurePass,
                  suffixIcon: IconButton(
                    icon: Icon(obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                    onPressed: () => setModalState(() => obscurePass = !obscurePass),
                  ),
                ),
                const SizedBox(height: 12),
                _buildDialogField(webController, 'Website (Optional)', Icons.language),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (titleController.text.isEmpty || passController.text.isEmpty) return;
                      final newEntry = PasswordEntry(
                        id: entry?.id ?? const Uuid().v4(),
                        title: titleController.text,
                        username: userController.text,
                        password: passController.text,
                        website: webController.text,
                        createdAt: DateTime.now(),
                      );
                      if (entry == null) await _service.addEntry(newEntry);
                      else await _service.updateEntry(newEntry);
                      Navigator.pop(context);
                      _loadEntries();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text('Save Password', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

  Widget _buildDialogField(TextEditingController controller, String label, IconData icon, {bool isPassword = false, Widget? suffixIcon}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: GoogleFonts.inter(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: isDark ? Colors.white70 : Colors.black54),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: isDark ? const Color(0xFF111111) : const Color(0xFFF3F4F6),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_isCheckingSetup) return const Scaffold(body: null); // Fast blank start
    if (!_isSetup) return _buildSetupScreen(isDark);
    if (_isRecovering) return _buildRecoveryScreen(isDark);
    if (!_isAuthenticated) return _buildAuthScreen(isDark);

    return Scaffold(
          backgroundColor: isDark ? Colors.black : const Color(0xFFF8FAFC),
          appBar: AppBar(
            title: Text('Password Manager', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
          ),
          body: _entries.isEmpty
              ? Center(child: Text('No passwords saved yet', style: GoogleFonts.inter(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _entries.length,
                  itemBuilder: (context, index) {
                    final entry = _entries[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: isDark ? const Color(0xFF111111) : Colors.white,
                      child: ListTile(
                        leading: const Icon(Icons.password_rounded),
                        title: Text(entry.title, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                        subtitle: Text(entry.username, style: GoogleFonts.inter(fontSize: 12)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.copy_rounded, size: 22, color: isDark ? Colors.white70 : Colors.black87),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: entry.password));
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.edit_outlined, size: 22, color: isDark ? Colors.white70 : Colors.black87),
                              onPressed: () => _showAddEntryDialog(entry),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 22, color: Colors.red),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete Password?'),
                                    content: const Text('Are you sure you want to delete this password?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await _service.deleteEntry(entry.id);
                                  _loadEntries();
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showAddEntryDialog(),
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: Text('Add New', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        );
  }

  Widget _buildSetupScreen(bool isDark) {
    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF8FAFC),
      appBar: AppBar(title: Text('Security Setup', style: GoogleFonts.inter(fontWeight: FontWeight.bold))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 40),
            Icon(Icons.security_rounded, size: 80, color: isDark ? Colors.white : Colors.black),
            const SizedBox(height: 24),
            Text('Set Up Security', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            _buildDialogField(_setupPinController, 'New 4-digit PIN', Icons.pin, isPassword: true),
            const SizedBox(height: 16),
            _buildDialogField(_setupRecoveryController, 'Recovery: Your School Name', Icons.school),
            const SizedBox(height: 32),
            _buildBigButton('Complete Setup', _handleSetup),
          ],
        ),
      ),
    );
  }

  Widget _buildRecoveryScreen(bool isDark) {
    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Recovery', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _isRecovering = false)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 40),
            Icon(Icons.help_outline_rounded, size: 80, color: isDark ? Colors.white : Colors.black),
            const SizedBox(height: 24),
            Text('Recovery', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            _buildDialogField(_recoveryController, 'Enter School Name', Icons.history_edu),
            const SizedBox(height: 32),
            _buildBigButton('Verify & Reset', _handleRecovery),
            TextButton(onPressed: () => setState(() => _isRecovering = false), child: Text('Back', style: GoogleFonts.inter(color: Colors.grey))),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthScreen(bool isDark) {
    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Authentication', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 40),
            Icon(Icons.lock_outline_rounded, size: 80, color: isDark ? Colors.white : Colors.black),
            const SizedBox(height: 24),
            Text('Authentication', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('Enter Manager PIN', style: GoogleFonts.inter(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 40),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            _buildDialogField(_authPinController, 'Enter PIN', Icons.pin, isPassword: true),
            const SizedBox(height: 32),
            _buildBigButton('Authenticate', _handleAuth),
            TextButton(
              onPressed: () => setState(() {
                _isRecovering = true;
                _error = null;
              }),
              child: Text('Forgot PIN?', style: GoogleFonts.inter(color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBigButton(String label, VoidCallback onPressed) {
    return SizedBox(width: double.infinity, child: ElevatedButton(onPressed: onPressed, style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.bold))));
  }
}
