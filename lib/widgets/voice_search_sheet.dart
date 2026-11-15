import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../theme/app_theme.dart';

class VoiceSearchSheet extends StatefulWidget {
  final String initialQuery;
  final ValueChanged<String> onSearchSubmitted;
  final List<String> quickTopics;

  const VoiceSearchSheet({
    super.key,
    required this.initialQuery,
    required this.onSearchSubmitted,
    this.quickTopics = const [
      'Documents',
      'Images',
      'Invoices',
      'Notes',
      'PDF',
      'Personal',
      'Receipts',
    ],
  });

  static Future<void> show(
    BuildContext context, {
    required String initialQuery,
    required ValueChanged<String> onSearchSubmitted,
    List<String>? quickTopics,
  }) {
    HapticFeedback.mediumImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VoiceSearchSheet(
        initialQuery: initialQuery,
        onSearchSubmitted: onSearchSubmitted,
        quickTopics: quickTopics ?? const [
          'Documents',
          'Images',
          'Invoices',
          'Notes',
          'PDF',
          'Personal',
          'Receipts',
        ],
      ),
    );
  }

  @override
  State<VoiceSearchSheet> createState() => _VoiceSearchSheetState();
}

class _VoiceSearchSheetState extends State<VoiceSearchSheet>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _voiceInputController;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late final stt.SpeechToText _speech;
  bool _speechAvailable = false;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _voiceInputController = TextEditingController(text: widget.initialQuery);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      _speechAvailable = await _speech.initialize(
        onError: (err) {
          if (mounted) {
            setState(() {
              _isListening = false;
              _pulseController.stop();
            });
          }
        },
        onStatus: (status) {
          if (mounted) {
            if (status == 'listening') {
              setState(() {
                _isListening = true;
                _pulseController.repeat(reverse: true);
              });
            } else if (status == 'notListening' || status == 'done') {
              setState(() {
                _isListening = false;
                _pulseController.stop();
              });
            }
          }
        },
      );
      if (_speechAvailable) {
        _startListening();
      }
    } catch (_) {}
  }

  void _startListening() async {
    if (!_speechAvailable) return;
    try {
      await _speech.listen(
        onResult: (result) {
          if (mounted) {
            setState(() {
              _voiceInputController.text = result.recognizedWords;
            });
            if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
              _submitSearch(result.recognizedWords);
            }
          }
        },
      );
      if (mounted) {
        setState(() {
          _isListening = true;
          _pulseController.repeat(reverse: true);
        });
      }
    } catch (_) {}
  }

  void _stopListening() async {
    try {
      await _speech.stop();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _isListening = false;
        _pulseController.stop();
      });
    }
  }

  void _toggleListening() {
    HapticFeedback.lightImpact();
    if (_isListening) {
      _stopListening();
    } else {
      _startListening();
    }
  }

  @override
  void dispose() {
    try {
      _speech.stop();
    } catch (_) {}
    _voiceInputController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _submitSearch(String query) {
    final trimmed = query.trim();
    widget.onSearchSubmitted(trimmed);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isDark = AppTheme.isDark(context);

    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: AppTheme.surfaceBorder(context),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              color: AppTheme.textMuted(context).withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Voice Search',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _isListening ? 'Listening for keywords...' : 'Tap mic to resume listening',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: _isListening
                          ? AppTheme.primary(context)
                          : AppTheme.textMuted(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
                color: AppTheme.textSecondary(context),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Animated Pulsing Mic Button
          GestureDetector(
            onTap: _toggleListening,
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                final scale = _isListening ? 1.0 + (_pulseAnimation.value * 0.12) : 1.0;
                final ringOpacity = _isListening
                    ? (0.28 - (_pulseAnimation.value * 0.18)).clamp(0.05, 0.3)
                    : 0.0;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 96 * scale,
                      height: 96 * scale,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.primary(context).withOpacity(ringOpacity),
                      ),
                    ),
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.primary(context),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary(context).withOpacity(0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        _isListening ? Icons.mic_rounded : Icons.mic_off_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 18),

          // Voice / Query Input Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.tonal(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.surfaceBorder(context),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _voiceInputController,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary(context),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Speak or type query...',
                      hintStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: AppTheme.textMuted(context),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onSubmitted: _submitSearch,
                  ),
                ),
                if (_voiceInputController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    color: AppTheme.textSecondary(context),
                    onPressed: () {
                      _voiceInputController.clear();
                      setState(() {});
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                  color: AppTheme.primary(context),
                  onPressed: () => _submitSearch(_voiceInputController.text),
                  tooltip: 'Search',
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Quick Topic Chips
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Quick Suggestions',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary(context),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.quickTopics.map((topic) {
              return ActionChip(
                label: Text(
                  topic,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.onPrimaryContainer(context),
                  ),
                ),
                backgroundColor: AppTheme.primaryContainer(context).withOpacity(0.55),
                side: BorderSide(
                  color: AppTheme.primary(context).withOpacity(0.2),
                  width: 1,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _submitSearch(topic);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
