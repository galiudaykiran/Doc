import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:math_expressions/math_expressions.dart' hide Stack;

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  String _input = '';
  String _result = '0';

  void _onButtonPressed(String value) {
    setState(() {
      if (value == 'C') {
        _input = '';
        _result = '0';
      } else if (value == '⌫') {
        if (_input.isNotEmpty) {
          _input = _input.substring(0, _input.length - 1);
        }
      } else if (value == '=') {
        try {
          _result = _evaluateExpression(_input);
        } catch (e) {
          _result = 'Error';
        }
      } else {
        _input += value;
      }
    });
  }

  String _evaluateExpression(String expression) {
    try {
      Parser p = Parser();
      Expression exp = p.parse(
        expression.replaceAll('x', '*').replaceAll('÷', '/'),
      );
      ContextModel cm = ContextModel();
      double eval = exp.evaluate(EvaluationType.REAL, cm);
      
      if (eval.isNaN) {
        return 'Error';
      }
      if (eval.isInfinite) {
        return 'Error: Div by 0';
      }
      
      if (eval % 1 == 0) {
        return eval.toInt().toString();
      }
      // Format to maximum 6 decimal places to keep it clean
      String result = eval.toStringAsFixed(6);
      // Remove trailing zeros and decimal point if not needed
      if (result.contains('.')) {
        result = result.replaceAll(RegExp(r'0*$'), '').replaceAll(RegExp(r'\.$'), '');
      }
      return result;
    } catch (e) {
      return 'Error';
    }
  }

  Widget _buildButton(
    String text, {
    Color? color,
    Color? textColor,
    bool isWide = false,
  }) {
    return Expanded(
      flex: isWide ? 2 : 1,
      child: Container(
        margin: const EdgeInsets.all(6),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 20),
            backgroundColor: color,
            foregroundColor: textColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            elevation: 0,
          ),
          onPressed: () => _onButtonPressed(text),
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;

    // Theme-aware colors
    final panelBg = isDark ? const Color(0xFF1E1E2E) : const Color(0xFFF5F5F8);
    final btnDefault = isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05);
    final btnDefaultText = isDark ? Colors.white : Colors.black87;
    final btnOp = isDark ? primary.withOpacity(0.18) : primary.withOpacity(0.1);
    final btnOpText = primary;
    final inputColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final resultColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.15),
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor.withOpacity(0.4),
                    Theme.of(context).primaryColor.withOpacity(0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withOpacity(0.05),
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
        leading: Container(
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.15)
                : Colors.black.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.2)
                  : Colors.black.withOpacity(0.12),
              width: 1,
            ),
          ),
          child: IconButton(
            icon: Icon(
              Icons.arrow_back_rounded,
              color: isDark ? Colors.white : Colors.black87,
              size: 22,
            ),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
          ),
        ),
        title: Text(
          'Calculator',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 22,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Background gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [const Color(0xFF12121F), const Color(0xFF1A1A2E)]
                      : [const Color(0xFFEEEEF5), const Color(0xFFF8F8FC)],
                ),
              ),
            ),
          ),
          Column(
            children: [
              // Display area
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 90, 24, 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _input,
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          color: inputColor,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _result,
                        style: GoogleFonts.poppins(
                          fontSize: 52,
                          fontWeight: FontWeight.bold,
                          color: resultColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Button panel
              Expanded(
                flex: 5,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                  decoration: BoxDecoration(
                    color: panelBg,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(36),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 30,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            _buildButton(
                              'C',
                              color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                              textColor: isDark ? Colors.white : Colors.black87,
                            ),
                            _buildButton(
                              '⌫',
                              color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                              textColor: isDark ? Colors.white : Colors.black87,
                            ),
                            _buildButton(
                              '(',
                              color: btnOp,
                              textColor: btnOpText,
                            ),
                            _buildButton(
                              ')',
                              color: btnOp,
                              textColor: btnOpText,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            _buildButton(
                              'sin',
                              color: btnOp,
                              textColor: btnOpText,
                            ),
                            _buildButton(
                              'cos',
                              color: btnOp,
                              textColor: btnOpText,
                            ),
                            _buildButton(
                              'tan',
                              color: btnOp,
                              textColor: btnOpText,
                            ),
                            _buildButton(
                              '÷',
                              color: btnOp,
                              textColor: btnOpText,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            _buildButton(
                              '7',
                              color: btnDefault,
                              textColor: btnDefaultText,
                            ),
                            _buildButton(
                              '8',
                              color: btnDefault,
                              textColor: btnDefaultText,
                            ),
                            _buildButton(
                              '9',
                              color: btnDefault,
                              textColor: btnDefaultText,
                            ),
                            _buildButton(
                              'x',
                              color: btnOp,
                              textColor: btnOpText,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            _buildButton(
                              '4',
                              color: btnDefault,
                              textColor: btnDefaultText,
                            ),
                            _buildButton(
                              '5',
                              color: btnDefault,
                              textColor: btnDefaultText,
                            ),
                            _buildButton(
                              '6',
                              color: btnDefault,
                              textColor: btnDefaultText,
                            ),
                            _buildButton(
                              '-',
                              color: btnOp,
                              textColor: btnOpText,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            _buildButton(
                              '1',
                              color: btnDefault,
                              textColor: btnDefaultText,
                            ),
                            _buildButton(
                              '2',
                              color: btnDefault,
                              textColor: btnDefaultText,
                            ),
                            _buildButton(
                              '3',
                              color: btnDefault,
                              textColor: btnDefaultText,
                            ),
                            _buildButton(
                              '+',
                              color: btnOp,
                              textColor: btnOpText,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            _buildButton(
                              '%',
                              color: btnOp,
                              textColor: btnOpText,
                            ),
                            _buildButton(
                              '0',
                              color: btnDefault,
                              textColor: btnDefaultText,
                            ),
                            _buildButton(
                              '.',
                              color: btnDefault,
                              textColor: btnDefaultText,
                            ),
                            _buildButton(
                              '=',
                              color: primary,
                              textColor: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
