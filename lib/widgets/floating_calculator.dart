import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:math_expressions/math_expressions.dart' hide Stack;

class FloatingCalculator extends StatefulWidget {
  const FloatingCalculator({super.key});

  @override
  State<FloatingCalculator> createState() => _FloatingCalculatorState();
}

class _FloatingCalculatorState extends State<FloatingCalculator> {
  String _input = '';
  String _result = '0';
  Offset _position = const Offset(20, 100);
  bool _isMinimized = false;

  void _onButtonPressed(String value) {
    setState(() {
      if (value == 'C') {
        _input = '';
        _result = '0';
      } else if (value == '⌫') {
        if (_input.isNotEmpty) {
          _input = _input.substring(0, _input.length - 1);
          _calculateResult();
        }
      } else if (value == '=') {
        _calculateResult();
        if (_result != 'Error') {
          _input = _result;
        }
      } else {
        _input += value;
        _calculateResult();
      }
    });
  }

  void _calculateResult() {
    try {
      if (_input.isEmpty) {
        _result = '0';
        return;
      }

      String expression = _input
          .replaceAll('×', '*')
          .replaceAll('÷', '/')
          .replaceAll('%', '/100');

      Parser parser = Parser();
      Expression exp = parser.parse(expression);
      ContextModel cm = ContextModel();
      double eval = exp.evaluate(EvaluationType.REAL, cm);

      // Format the result
      if (eval == eval.toInt()) {
        _result = eval.toInt().toString();
      } else {
        _result = eval.toStringAsFixed(2);
      }
    } catch (e) {
      _result = 'Error';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Stack(
      children: [
        Positioned(
          left: _position.dx,
          top: _position.dy,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                _position = Offset(
                  (_position.dx + details.delta.dx).clamp(
                    0.0,
                    size.width - 300,
                  ),
                  (_position.dy + details.delta.dy).clamp(
                    0.0,
                    size.height - 400,
                  ),
                );
              });
            },
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: _isMinimized ? 60 : 300,
                height: _isMinimized ? 60 : 460,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [isDark ? Colors.grey.shade900 : Colors.white, isDark ? Colors.black87 : Colors.grey.shade100],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: _isMinimized ? _buildMinimizedView() : _buildFullView(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMinimizedView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () => setState(() => _isMinimized = false),
      borderRadius: BorderRadius.circular(20),
      child: Center(
        child: Icon(Icons.calculate_rounded, color: isDark ? Colors.white : Colors.black87, size: 28),
      ),
    );
  }

  Widget _buildFullView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;

    return Column(
      children: [
        // Header with minimize and close buttons
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.1),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                Icons.drag_indicator_rounded,
                color: subTextColor,
                size: 20,
              ),
              Text(
                'Calculator',
                style: GoogleFonts.poppins(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.minimize_rounded, size: 18),
                    color: textColor,
                    onPressed: () => setState(() => _isMinimized = true),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    color: textColor,
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Display
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.all(16),
            alignment: Alignment.bottomRight,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _input.isEmpty ? '0' : _input,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    color: subTextColor,
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _result,
                  style: GoogleFonts.poppins(
                    fontSize: 36,
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),

        // Buttons
        Expanded(
          flex: 3,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.black : Colors.white,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildButtonRow(['C', '⌫', '%', '÷']),
                  _buildButtonRow(['7', '8', '9', '×']),
                  _buildButtonRow(['4', '5', '6', '-']),
                  _buildButtonRow(['1', '2', '3', '+']),
                  _buildButtonRow(['0', '.', '=']),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildButtonRow(List<String> buttons) {
    return Row(
        children: buttons.map((btn) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final isOperator = ['÷', '×', '-', '+', '='].contains(btn);
          final isSpecial = ['C', '⌫', '%'].contains(btn);

          return Expanded(
            flex: btn == '0' ? 2 : 1,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: ElevatedButton(
                onPressed: () => _onButtonPressed(btn),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isOperator
                      ? (isDark ? Colors.white : Colors.black)
                      : isSpecial
                      ? Colors.grey.shade300
                      : (isDark ? Colors.white10 : Colors.white),
                  foregroundColor: isOperator || isSpecial
                      ? (isOperator ? (isDark ? Colors.black : Colors.white) : Colors.black87)
                      : (isDark ? Colors.white : Colors.black87),
                  elevation: isOperator ? 2 : 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.zero,
                ),
                child: Text(
                  btn,
                  style: GoogleFonts.poppins(
                    fontSize: btn == '⌫' ? 18 : 20,
                    fontWeight: isOperator ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
    );
  }
}

class FloatingCalculatorButton extends StatelessWidget {
  const FloatingCalculatorButton({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      mini: true,
      heroTag: 'calculator_fab',
      backgroundColor: Theme.of(context).primaryColor,
      onPressed: () {
        showDialog(
          context: context,
          barrierColor: Colors.transparent,
          barrierDismissible: false,
          builder: (context) => const FloatingCalculator(),
        );
      },
      child: const Icon(Icons.calculate_rounded, size: 20),
    );
  }
}
