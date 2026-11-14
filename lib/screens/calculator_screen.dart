import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:math_expressions/math_expressions.dart' hide Stack;
import 'package:gallery_app/utils/responsive_layout.dart';
import 'package:gallery_app/theme/app_theme.dart';

enum CalculatorTab { calculator, converter, history }

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  CalculatorTab _currentTab = CalculatorTab.calculator;

  // Calculator State
  String _input = '';
  String _result = '0';
  final List<String> _history = [];

  // Unit Converter State
  String _converterCategory = 'Storage';
  final TextEditingController _converterInputController =
      TextEditingController(text: '1');
  String _fromUnit = 'MB';
  String _toUnit = 'KB';
  String _convertedResult = '1024';

  final List<String> _categories = [
    'Storage',
    'Length',
    'Weight',
    'Area',
    'Temperature',
  ];

  final Map<String, List<String>> _units = {
    'Storage': ['Bytes', 'KB', 'MB', 'GB', 'TB'],
    'Length': ['mm', 'cm', 'm', 'km', 'in', 'ft', 'yd'],
    'Weight': ['mg', 'g', 'kg', 'oz', 'lb'],
    'Area': ['sq ft', 'sq m', 'sq yd', 'acres', 'hectares'],
    'Temperature': ['°C', '°F', 'K'],
  };

  @override
  void initState() {
    super.initState();
    _converterInputController.addListener(_calculateConversion);
  }

  @override
  void dispose() {
    _converterInputController.dispose();
    super.dispose();
  }

  void _onButtonPressed(String value) {
    HapticFeedback.lightImpact();
    setState(() {
      if (value == 'C') {
        _input = '';
        _result = '0';
      } else if (value == '⌫') {
        if (_input.isNotEmpty) {
          _input = _input.substring(0, _input.length - 1);
        }
      } else if (value == '=') {
        if (_input.isNotEmpty) {
          try {
            final eval = _evaluateExpression(_input);
            _history.insert(0, '$_input = $eval');
            if (_history.length > 20) _history.removeLast();
            _result = eval;
            _input = eval;
          } catch (e) {
            _result = 'Error';
          }
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
        expression
            .replaceAll('x', '*')
            .replaceAll('×', '*')
            .replaceAll('÷', '/')
            .replaceAll('%', '/100'),
      );
      ContextModel cm = ContextModel();
      double eval = exp.evaluate(EvaluationType.REAL, cm);

      if (eval.isNaN) return 'Error';
      if (eval.isInfinite) return 'Error: Div by 0';

      if (eval % 1 == 0) return eval.toInt().toString();

      String result = eval.toStringAsFixed(6);
      if (result.contains('.')) {
        result = result
            .replaceAll(RegExp(r'0*$'), '')
            .replaceAll(RegExp(r'\.$'), '');
      }
      return result;
    } catch (_) {
      return 'Error';
    }
  }

  void _calculateConversion() {
    final val = double.tryParse(_converterInputController.text) ?? 0.0;
    double res = 0.0;

    switch (_converterCategory) {
      case 'Storage':
        final Map<String, double> toBytes = {
          'Bytes': 1,
          'KB': 1024,
          'MB': 1024 * 1024,
          'GB': 1024 * 1024 * 1024,
          'TB': 1024.0 * 1024 * 1024 * 1024,
        };
        final bytes = val * (toBytes[_fromUnit] ?? 1);
        res = bytes / (toBytes[_toUnit] ?? 1);
        break;

      case 'Length':
        final Map<String, double> toMeters = {
          'mm': 0.001,
          'cm': 0.01,
          'm': 1.0,
          'km': 1000.0,
          'in': 0.0254,
          'ft': 0.3048,
          'yd': 0.9144,
        };
        final meters = val * (toMeters[_fromUnit] ?? 1);
        res = meters / (toMeters[_toUnit] ?? 1);
        break;

      case 'Weight':
        final Map<String, double> toGrams = {
          'mg': 0.001,
          'g': 1.0,
          'kg': 1000.0,
          'oz': 28.3495,
          'lb': 453.592,
        };
        final grams = val * (toGrams[_fromUnit] ?? 1);
        res = grams / (toGrams[_toUnit] ?? 1);
        break;

      case 'Area':
        final Map<String, double> toSqMeters = {
          'sq m': 1.0,
          'sq ft': 0.092903,
          'sq yd': 0.836127,
          'acres': 4046.86,
          'hectares': 10000.0,
        };
        final sqMeters = val * (toSqMeters[_fromUnit] ?? 1);
        res = sqMeters / (toSqMeters[_toUnit] ?? 1);
        break;

      case 'Temperature':
        if (_fromUnit == _toUnit) {
          res = val;
        } else if (_fromUnit == '°C' && _toUnit == '°F') {
          res = (val * 9 / 5) + 32;
        } else if (_fromUnit == '°C' && _toUnit == 'K') {
          res = val + 273.15;
        } else if (_fromUnit == '°F' && _toUnit == '°C') {
          res = (val - 32) * 5 / 9;
        } else if (_fromUnit == '°F' && _toUnit == 'K') {
          res = (val - 32) * 5 / 9 + 273.15;
        } else if (_fromUnit == 'K' && _toUnit == '°C') {
          res = val - 273.15;
        } else if (_fromUnit == 'K' && _toUnit == '°F') {
          res = (val - 273.15) * 9 / 5 + 32;
        }
        break;
    }

    setState(() {
      if (res % 1 == 0) {
        _convertedResult = res.toInt().toString();
      } else {
        _convertedResult = res
            .toStringAsFixed(4)
            .replaceAll(RegExp(r'0*$'), '')
            .replaceAll(RegExp(r'\.$'), '');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Calculator & Tools',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 20,
            color: theme.textTheme.titleLarge?.color,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Tab Selector Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.tonal(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.surfaceBorder(context), width: 1),
                ),
                child: Row(
                  children: [
                    _buildTabButton('Calculator', CalculatorTab.calculator, Icons.calculate_outlined),
                    _buildTabButton('Converter', CalculatorTab.converter, Icons.swap_horiz_rounded),
                    _buildTabButton('History', CalculatorTab.history, Icons.history_rounded),
                  ],
                ),
              ),
            ),

            // Tab Views
            Expanded(
              child: _currentTab == CalculatorTab.calculator
                  ? _buildCalculatorView(context)
                  : _currentTab == CalculatorTab.converter
                      ? _buildConverterView(context)
                      : _buildHistoryView(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String label, CalculatorTab tab, IconData icon) {
    final isSelected = _currentTab == tab;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _currentTab = tab);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.surface(context)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(color: AppTheme.surfaceBorder(context), width: 1)
                : null,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(AppTheme.isDark(context) ? 0.2 : 0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? AppTheme.primary(context)
                    : AppTheme.textSecondary(context),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? AppTheme.textPrimary(context)
                        : AppTheme.textSecondary(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Calculator View ---
  Widget _buildCalculatorView(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryBg = isDark ? const Color(0xFF242426) : Colors.grey.shade100;
    final opBg = theme.primaryColor.withOpacity(isDark ? 0.25 : 0.15);
    final opText = theme.primaryColor;
    final equalsBg = theme.primaryColor;
    final equalsText = theme.colorScheme.onPrimary;

    return Column(
      children: [
        // Display Section (Adaptive height)
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            alignment: Alignment.bottomRight,
            child: SingleChildScrollView(
              reverse: true,
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    _input.isEmpty ? '0' : _input,
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.w400,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _result,
                    style: GoogleFonts.poppins(
                      fontSize: 44,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
            ),
          ),
        ),

        const Divider(height: 1),

        // Keypad Section (Adaptive Grid inside Expanded - Guaranteed ZERO overflow)
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      _buildCalcKey('C', color: opBg, textColor: Colors.redAccent),
                      _buildCalcKey('(', color: opBg, textColor: opText),
                      _buildCalcKey(')', color: opBg, textColor: opText),
                      _buildCalcKey('÷', color: opBg, textColor: opText),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      _buildCalcKey('7', color: primaryBg),
                      _buildCalcKey('8', color: primaryBg),
                      _buildCalcKey('9', color: primaryBg),
                      _buildCalcKey('×', color: opBg, textColor: opText),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      _buildCalcKey('4', color: primaryBg),
                      _buildCalcKey('5', color: primaryBg),
                      _buildCalcKey('6', color: primaryBg),
                      _buildCalcKey('-', color: opBg, textColor: opText),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      _buildCalcKey('1', color: primaryBg),
                      _buildCalcKey('2', color: primaryBg),
                      _buildCalcKey('3', color: primaryBg),
                      _buildCalcKey('+', color: opBg, textColor: opText),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      _buildCalcKey('0', color: primaryBg),
                      _buildCalcKey('.', color: primaryBg),
                      _buildCalcKey('⌫', color: primaryBg),
                      _buildCalcKey('=', color: equalsBg, textColor: equalsText),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCalcKey(
    String label, {
    Color? color,
    Color? textColor,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final defaultText = isDark ? Colors.white : Colors.black87;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Material(
          color: color ?? (isDark ? const Color(0xFF242426) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _onButtonPressed(label),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: textColor ?? defaultText,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Offline Unit Converter View ---
  Widget _buildConverterView(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUnits = _units[_converterCategory] ?? [];

    return SingleChildScrollView(
      padding: ResponsiveLayout.getKeyboardPadding(context, defaultBottom: 24),
      physics: const BouncingScrollPhysics(),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: ResponsiveLayout.getDialogMaxWidth(context)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Category Selector
                Text(
                  'Select Category',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: theme.hintColor),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: _categories.map((cat) {
                      final isSelected = _converterCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            setState(() {
                              _converterCategory = cat;
                              _fromUnit = _units[cat]!.first;
                              _toUnit = _units[cat]!.length > 1 ? _units[cat]![1] : _units[cat]!.first;
                            });
                            _calculateConversion();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primaryContainer(context)
                                  : AppTheme.tonal(context),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.primary(context).withOpacity(0.4)
                                    : AppTheme.surfaceBorder(context),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              cat,
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                fontSize: 13,
                                color: isSelected
                                    ? AppTheme.onPrimaryContainer(context)
                                    : AppTheme.textSecondary(context),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 24),

                // From Unit Input Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.surfaceBorder(context)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('From', style: GoogleFonts.inter(fontSize: 12, color: theme.hintColor)),
                          DropdownButton<String>(
                            value: _fromUnit,
                            underline: const SizedBox(),
                            items: currentUnits.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _fromUnit = val);
                                _calculateConversion();
                              }
                            },
                          ),
                        ],
                      ),
                      TextField(
                        controller: _converterInputController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: '0',
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ),

                // Swap Units Button
                Center(
                  child: IconButton(
                    icon: const Icon(Icons.swap_vert_rounded, size: 28),
                    color: theme.primaryColor,
                    onPressed: () {
                      setState(() {
                        final temp = _fromUnit;
                        _fromUnit = _toUnit;
                        _toUnit = temp;
                      });
                      _calculateConversion();
                    },
                  ),
                ),

                // To Unit Result Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.surfaceBorder(context)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('To', style: GoogleFonts.inter(fontSize: 12, color: theme.hintColor)),
                          DropdownButton<String>(
                            value: _toUnit,
                            underline: const SizedBox(),
                            items: currentUnits.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _toUnit = val);
                                _calculateConversion();
                              }
                            },
                          ),
                        ],
                      ),
                      SelectableText(
                        _convertedResult,
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: theme.primaryColor,
                        ),
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

  // --- Calculation History View ---
  Widget _buildHistoryView(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_rounded, size: 64, color: theme.hintColor.withOpacity(0.4)),
            const SizedBox(height: 12),
            Text(
              'No Calculations Yet',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: theme.hintColor),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _history.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = _history[index];
        final parts = item.split(' = ');
        final expr = parts.first;
        final res = parts.length > 1 ? parts.last : '';

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.surfaceBorder(context)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(expr, style: GoogleFonts.poppins(fontSize: 13, color: theme.hintColor)),
                    const SizedBox(height: 2),
                    Text(
                      '= $res',
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 18),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: res));
                  Fluttertoast.showToast(msg: "Result copied to clipboard");
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
