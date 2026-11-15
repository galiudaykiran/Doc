import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:share_plus/share_plus.dart';

import '../models/user_profile.dart';
import '../services/profile_service.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _dobController;
  late TextEditingController _phoneController;
  late TextEditingController _aadharController;
  final Map<String, TextEditingController> _customControllers = {};

  bool _isLoading = true;
  bool _isSaving = false;
  bool _maskAadhar = true;

  final List<String> _suggestedCustomFields = const [
    'Driving License',
    'Bank Account No',
    'IFSC Code',
    'PAN Number',
    'Passport Number',
    'Voter ID',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _dobController = TextEditingController();
    _phoneController = TextEditingController();
    _aadharController = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _dobController.dispose();
    _phoneController.dispose();
    _aadharController.dispose();
    for (final c in _customControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await ProfileService.getProfile();
    if (mounted) {
      // Clear existing custom controllers
      for (final c in _customControllers.values) {
        c.dispose();
      }
      _customControllers.clear();

      profile.customFields.forEach((key, value) {
        _customControllers[key] = TextEditingController(text: value);
      });

      setState(() {
        _nameController.text = profile.username;
        _emailController.text = profile.email;
        _dobController.text = profile.dob;
        _phoneController.text = profile.phone;
        _aadharController.text = profile.aadhar;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    HapticFeedback.lightImpact();
    DateTime initialDate = DateTime(1998, 8, 15);
    try {
      if (_dobController.text.contains('/')) {
        final parts = _dobController.text.split('/');
        if (parts.length == 3) {
          initialDate = DateTime(
            int.parse(parts[2]),
            int.parse(parts[1]),
            int.parse(parts[0]),
          );
        }
      }
    } catch (_) {}

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppTheme.primary(context),
              brightness: AppTheme.isDark(context) ? Brightness.dark : Brightness.light,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dobController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  void _showAddCustomFieldDialog([String? prefilledName]) {
    HapticFeedback.lightImpact();
    final nameCtrl = TextEditingController(text: prefilledName ?? '');
    final valCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        backgroundColor: AppTheme.surface(ctx),
        title: Text(
          'Add Custom Detail',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: AppTheme.textPrimary(ctx),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Specify field name (e.g. Driving License, Bank Details) and value.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: AppTheme.textSecondary(ctx),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: nameCtrl,
              autofocus: prefilledName == null,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary(ctx),
              ),
              decoration: InputDecoration(
                labelText: 'Field Name',
                hintText: 'e.g. Driving License',
                filled: true,
                fillColor: AppTheme.tonal(ctx),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: valCtrl,
              autofocus: prefilledName != null,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary(ctx),
              ),
              decoration: InputDecoration(
                labelText: 'Value',
                hintText: 'Enter details or number',
                filled: true,
                fillColor: AppTheme.tonal(ctx),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final fieldName = nameCtrl.text.trim();
              if (fieldName.isEmpty) {
                Fluttertoast.showToast(msg: 'Please enter a field name');
                return;
              }
              if (_customControllers.containsKey(fieldName)) {
                Fluttertoast.showToast(msg: 'Field "$fieldName" already exists');
                return;
              }
              setState(() {
                _customControllers[fieldName] = TextEditingController(text: valCtrl.text.trim());
              });
              Navigator.pop(ctx);
              Fluttertoast.showToast(msg: 'Added $fieldName');
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary(ctx)),
            child: const Text('Add Field'),
          ),
        ],
      ),
    );
  }

  void _removeCustomField(String fieldName) {
    HapticFeedback.lightImpact();
    setState(() {
      _customControllers[fieldName]?.dispose();
      _customControllers.remove(fieldName);
    });
    Fluttertoast.showToast(msg: 'Removed $fieldName');
  }

  void _showShareProfileSheet() {
    HapticFeedback.mediumImpact();
    final itemsToShare = <String, bool>{
      'Full Name': true,
      'Email': true,
      'Phone': true,
      'DOB': true,
      'Aadhaar': true,
    };

    for (final key in _customControllers.keys) {
      itemsToShare[key] = true;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                decoration: BoxDecoration(
                  color: AppTheme.surface(ctx),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  border: Border(top: BorderSide(color: AppTheme.surfaceBorder(ctx))),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.textMuted(ctx).withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Share Profile Details',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: AppTheme.textPrimary(ctx),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            final allSelected = itemsToShare.values.every((v) => v);
                            setSheetState(() {
                              itemsToShare.updateAll((key, value) => !allSelected);
                            });
                          },
                          child: Text(
                            itemsToShare.values.every((v) => v) ? 'Deselect All' : 'Select All',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primary(ctx),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Choose which details to include in the shareable text.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppTheme.textSecondary(ctx),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(ctx).height * 0.42,
                      ),
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          children: itemsToShare.keys.map((key) {
                            String previewVal = '';
                            if (key == 'Full Name') previewVal = _nameController.text.trim();
                            else if (key == 'Email') previewVal = _emailController.text.trim();
                            else if (key == 'Phone') previewVal = _phoneController.text.trim();
                            else if (key == 'DOB') previewVal = _dobController.text.trim();
                            else if (key == 'Aadhaar') previewVal = _aadharController.text.trim();
                            else previewVal = _customControllers[key]?.text.trim() ?? '';

                            final isChecked = itemsToShare[key] ?? false;
                            return CheckboxListTile(
                              value: isChecked,
                              activeColor: AppTheme.primary(ctx),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                              title: Text(
                                key,
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: AppTheme.textPrimary(ctx),
                                ),
                              ),
                              subtitle: previewVal.isNotEmpty
                                  ? Text(
                                      previewVal,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary(ctx),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    )
                                  : null,
                              onChanged: (val) {
                                setSheetState(() {
                                  itemsToShare[key] = val ?? false;
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.share_rounded, size: 18),
                        label: Text(
                          'Share Selected Details',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primary(ctx),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () async {
                          final buffer = StringBuffer();
                          buffer.writeln('📋 Profile Information');
                          buffer.writeln('────────────────────');

                          if (itemsToShare['Full Name'] == true && _nameController.text.trim().isNotEmpty) {
                            buffer.writeln('• Name: ${_nameController.text.trim()}');
                          }
                          if (itemsToShare['Phone'] == true && _phoneController.text.trim().isNotEmpty) {
                            buffer.writeln('• Phone: ${_phoneController.text.trim()}');
                          }
                          if (itemsToShare['Email'] == true && _emailController.text.trim().isNotEmpty) {
                            buffer.writeln('• Email: ${_emailController.text.trim()}');
                          }
                          if (itemsToShare['DOB'] == true && _dobController.text.trim().isNotEmpty) {
                            buffer.writeln('• DOB: ${_dobController.text.trim()}');
                          }
                          if (itemsToShare['Aadhaar'] == true && _aadharController.text.trim().isNotEmpty) {
                            buffer.writeln('• Aadhaar: ${_aadharController.text.trim()}');
                          }

                          for (final entry in _customControllers.entries) {
                            if (itemsToShare[entry.key] == true && entry.value.text.trim().isNotEmpty) {
                              buffer.writeln('• ${entry.key}: ${entry.value.text.trim()}');
                            }
                          }

                          buffer.writeln('────────────────────');
                          buffer.writeln('Shared via Document Hub');

                          Navigator.pop(ctx);
                          await Share.share(
                            buffer.toString(),
                            subject: '${_nameController.text.trim()} - Profile Details',
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      Fluttertoast.showToast(msg: 'Username cannot be empty');
      return;
    }

    setState(() => _isSaving = true);
    final customMap = <String, String>{};
    _customControllers.forEach((key, controller) {
      if (controller.text.trim().isNotEmpty) {
        customMap[key] = controller.text.trim();
      }
    });

    final updated = UserProfile(
      username: name,
      email: _emailController.text.trim(),
      dob: _dobController.text.trim(),
      phone: _phoneController.text.trim(),
      aadhar: _aadharController.text.trim(),
      customFields: customMap,
    );

    await ProfileService.saveProfile(updated);

    if (mounted) {
      setState(() => _isSaving = false);
      Fluttertoast.showToast(msg: 'Profile updated successfully');
      Navigator.pop(context, true);
    }
  }

  String get _avatarInitial {
    final name = _nameController.text.trim();
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.tonal(context),
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.surfaceBorder(context)),
          ),
          child: IconButton(
            icon: Icon(
              Icons.arrow_back_rounded,
              color: AppTheme.textPrimary(context),
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Text(
          'Personal Profile',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: AppTheme.textPrimary(context),
          ),
        ),
        centerTitle: false,
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.tonal(context),
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.surfaceBorder(context)),
            ),
            child: IconButton(
              icon: Icon(
                Icons.share_rounded,
                color: AppTheme.primary(context),
                size: 20,
              ),
              tooltip: 'Share Profile Details',
              onPressed: _showShareProfileSheet,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 8),
                  // Avatar with first letter
                  Center(
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryContainer(context),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.primary(context).withOpacity(0.4),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary(context).withOpacity(0.2),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _avatarInitial,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 38,
                            color: AppTheme.onPrimaryContainer(context),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _nameController.text.isNotEmpty ? _nameController.text : 'User Profile',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _emailController.text.isNotEmpty ? _emailController.text : 'Local Document Hub Account',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: AppTheme.textSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Basic Profile Fields Card Container
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.surface(context),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppTheme.surfaceBorder(context)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BASIC DETAILS',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            letterSpacing: 0.8,
                            color: AppTheme.primary(context),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildInputField(
                          context,
                          label: 'Username / Full Name',
                          hint: 'Enter your name',
                          controller: _nameController,
                          icon: Icons.person_rounded,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 16),
                        _buildInputField(
                          context,
                          label: 'Email Address',
                          hint: 'e.g. user@gmail.com',
                          controller: _emailController,
                          icon: Icons.email_rounded,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),
                        _buildInputField(
                          context,
                          label: 'Date of Birth (DOB)',
                          hint: 'DD/MM/YYYY',
                          controller: _dobController,
                          icon: Icons.cake_rounded,
                          readOnly: true,
                          onTap: _pickDate,
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.calendar_month_rounded, size: 20),
                            color: AppTheme.primary(context),
                            onPressed: _pickDate,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildInputField(
                          context,
                          label: 'Phone Number',
                          hint: '+91 98765 43210',
                          controller: _phoneController,
                          icon: Icons.phone_android_rounded,
                          keyboardType: TextInputType.phone,
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 18),
                            color: AppTheme.primary(context),
                            tooltip: 'Copy Phone',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _phoneController.text.trim()));
                              Fluttertoast.showToast(msg: 'Phone copied to clipboard');
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildInputField(
                          context,
                          label: 'Aadhaar Number',
                          hint: 'XXXX XXXX XXXX',
                          controller: _aadharController,
                          icon: Icons.badge_rounded,
                          keyboardType: TextInputType.number,
                          obscureText: _maskAadhar,
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  _maskAadhar ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                  size: 20,
                                ),
                                color: AppTheme.textSecondary(context),
                                onPressed: () {
                                  setState(() => _maskAadhar = !_maskAadhar);
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 18),
                                color: AppTheme.primary(context),
                                tooltip: 'Copy Aadhaar',
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: _aadharController.text.trim()));
                                  Fluttertoast.showToast(msg: 'Aadhaar copied to clipboard');
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Custom Fields Section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.surface(context),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppTheme.surfaceBorder(context)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'CUSTOM DETAILS',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                letterSpacing: 0.8,
                                color: AppTheme.primary(context),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => _showAddCustomFieldDialog(),
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('Add Field'),
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                foregroundColor: AppTheme.primary(context),
                                textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Add your Driving License, Bank Details, PAN, etc. for quick access & sharing.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: AppTheme.textSecondary(context),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Suggestions Wrap
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _suggestedCustomFields
                              .where((name) => !_customControllers.containsKey(name))
                              .map((name) {
                            return ActionChip(
                              label: Text(
                                '+ $name',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.onPrimaryContainer(context),
                                ),
                              ),
                              backgroundColor: AppTheme.primaryContainer(context).withOpacity(0.5),
                              side: BorderSide(
                                color: AppTheme.primary(context).withOpacity(0.2),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                              onPressed: () => _showAddCustomFieldDialog(name),
                            );
                          }).toList(),
                        ),

                        if (_customControllers.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Divider(height: 1),
                          const SizedBox(height: 16),
                          ..._customControllers.entries.map((entry) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _buildCustomFieldRow(context, entry.key, entry.value),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Actions Row: Save & Share
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: OutlinedButton.icon(
                            onPressed: _showShareProfileSheet,
                            icon: const Icon(Icons.share_rounded, size: 20),
                            label: Text(
                              'Share Details',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primary(context),
                              side: BorderSide(color: AppTheme.primary(context), width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: FilledButton.icon(
                            onPressed: _isSaving ? null : _saveProfile,
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.check_circle_rounded, size: 20),
                            label: Text(
                              _isSaving ? 'Saving...' : 'Save Profile',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.primary(context),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildCustomFieldRow(BuildContext context, String fieldName, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              fieldName,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary(context),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
              tooltip: 'Delete $fieldName',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => _removeCustomField(fieldName),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary(context),
          ),
          decoration: InputDecoration(
            hintText: 'Enter $fieldName',
            hintStyle: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: AppTheme.textMuted(context),
            ),
            prefixIcon: Icon(Icons.fact_check_outlined, size: 20, color: AppTheme.primary(context)),
            suffixIcon: IconButton(
              icon: const Icon(Icons.copy_rounded, size: 18),
              color: AppTheme.primary(context),
              tooltip: 'Copy $fieldName',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: controller.text.trim()));
                Fluttertoast.showToast(msg: '$fieldName copied to clipboard');
              },
            ),
            filled: true,
            fillColor: AppTheme.tonal(context),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
        ),
      ],
    );
  }

  Widget _buildInputField(
    BuildContext context, {
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    bool readOnly = false,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    VoidCallback? onTap,
    Widget? suffixIcon,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary(context),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          readOnly: readOnly,
          obscureText: obscureText,
          keyboardType: keyboardType,
          onTap: onTap,
          onChanged: onChanged,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary(context),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: AppTheme.textMuted(context),
            ),
            prefixIcon: Icon(icon, size: 20, color: AppTheme.primary(context)),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: AppTheme.tonal(context),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
        ),
      ],
    );
  }
}

                  const SizedBox(height: 28),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : _saveProfile,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_circle_rounded, size: 20),
                      label: Text(
                        _isSaving ? 'Saving...' : 'Save Profile',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary(context),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildInputField(
    BuildContext context, {
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    bool readOnly = false,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    VoidCallback? onTap,
    Widget? suffixIcon,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary(context),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          readOnly: readOnly,
          obscureText: obscureText,
          keyboardType: keyboardType,
          onTap: onTap,
          onChanged: onChanged,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary(context),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: AppTheme.textMuted(context),
            ),
            prefixIcon: Icon(icon, size: 20, color: AppTheme.primary(context)),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: AppTheme.tonal(context),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
        ),
      ],
    );
  }
}

