import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

class PremiumPinOverlay extends StatefulWidget {
  final String title;
  final Future<bool> Function(String) onVerify;
  final VoidCallback? onForgotPin;

  const PremiumPinOverlay({
    super.key,
    required this.title,
    required this.onVerify,
    this.onForgotPin,
  });

  @override
  State<PremiumPinOverlay> createState() => _PremiumPinOverlayState();
}

class _PremiumPinOverlayState extends State<PremiumPinOverlay> {
  String _pin = "";
  bool _isError = false;

  void _onKeyTap(String key) {
    if (_pin.length < 4) {
      setState(() {
        _pin += key;
        _isError = false;
      });
      HapticFeedback.lightImpact();
      if (_pin.length == 4) {
        _verifyPin();
      }
    }
  }

  void _onDelete() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
        _isError = false;
      });
      HapticFeedback.lightImpact();
    }
  }

  Future<void> _verifyPin() async {
    final success = await widget.onVerify(_pin);
    if (success) {
      if (mounted) Navigator.pop(context, true);
    } else {
      setState(() {
        _pin = "";
        _isError = true;
      });
      HapticFeedback.heavyImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.black.withOpacity(0.85)),
          ),
          SafeArea(
            child: Column(
              children: [
                const Spacer(),
                Icon(Icons.lock_outline_rounded, size: 64, color: Colors.white.withOpacity(0.9)),
                const SizedBox(height: 24),
                Text(
                  widget.title,
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 48),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    bool filled = index < _pin.length;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isError 
                            ? Colors.redAccent.withOpacity(0.8) 
                            : (filled ? Colors.white : Colors.white.withOpacity(0.15)),
                        border: Border.all(
                          color: _isError ? Colors.redAccent : Colors.white.withOpacity(0.3),
                          width: 2,
                        ),
                        boxShadow: filled ? [
                          BoxShadow(color: Colors.white.withOpacity(0.2), blurRadius: 10, spreadRadius: 2)
                        ] : [],
                      ),
                    );
                  }),
                ),
                
                if (_isError) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Incorrect PIN, try again',
                    style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ],

                const Spacer(),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Column(
                    children: [
                      _buildKeyRow(['1', '2', '3']),
                      const SizedBox(height: 24),
                      _buildKeyRow(['4', '5', '6']),
                      const SizedBox(height: 24),
                      _buildKeyRow(['7', '8', '9']),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const SizedBox(width: 72), 
                          _buildKeyButton('0'),
                          _buildIconButton(Icons.backspace_outlined, _onDelete),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                if (widget.onForgotPin != null)
                  TextButton(
                    onPressed: widget.onForgotPin,
                    child: Text(
                      'Forgot PIN?',
                      style: GoogleFonts.inter(color: Colors.white.withOpacity(0.5), fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                
                const SizedBox(height: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: keys.map((key) => _buildKeyButton(key)).toList(),
    );
  }

  Widget _buildKeyButton(String label) {
    return InkWell(
      onTap: () => _onKeyTap(label),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.06),
          border: Border.all(color: Colors.white10, width: 1),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.inter(fontSize: 30, color: Colors.white, fontWeight: FontWeight.w400),
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: SizedBox(
        width: 72,
        height: 72,
        child: Center(
          child: Icon(icon, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}
