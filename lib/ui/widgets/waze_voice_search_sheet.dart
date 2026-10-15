import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../app/app_controller.dart';
import '../../domain/models.dart';
import '../../domain/voice_command_parser.dart';
import '../../services/voice_navigation_service.dart';
import '../waze_theme.dart';

enum VoiceSheetState {
  listening,
  processing,
  searching,
  navigating,
  multipleResults,
  error,
}

class WazeVoiceSearchSheet extends StatefulWidget {
  const WazeVoiceSearchSheet({
    super.key,
    required this.controller,
    this.voiceService,
  });

  final AppController controller;
  final VoiceNavigationService? voiceService;

  static Future<void> show(BuildContext context, AppController controller) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.65),
      builder: (_) => WazeVoiceSearchSheet(controller: controller),
    );
  }

  @override
  State<WazeVoiceSearchSheet> createState() => _WazeVoiceSearchSheetState();
}

class _WazeVoiceSearchSheetState extends State<WazeVoiceSearchSheet>
    with SingleTickerProviderStateMixin {
  late final VoiceNavigationService _voiceService;
  final VoiceCommandParser _parser = const VoiceCommandParser();
  late final AnimationController _pulseAnim;

  VoiceSheetState _state = VoiceSheetState.listening;
  String _recognizedText = '';
  String _extractedQuery = '';
  String _statusMessage = '';
  double _soundLevel = 0.0;
  List<Place> _candidatePlaces = [];
  Timer? _autoNavTimer;
  Timer? _silenceTimer;
  int _navCountdown = 3;

  @override
  void initState() {
    super.initState();
    _voiceService = widget.voiceService ?? VoiceNavigationService();
    _pulseAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _initAndStartListening();
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _autoNavTimer?.cancel();
    _pulseAnim.dispose();
    _voiceService.stopListening();
    super.dispose();
  }

  Future<void> _initAndStartListening() async {
    final ar = widget.controller.arabic;
    _silenceTimer?.cancel();
    setState(() {
      _state = VoiceSheetState.listening;
      _recognizedText = '';
      _extractedQuery = '';
      _candidatePlaces = [];
      _statusMessage = ar
          ? 'تحدث براحتك... جارٍ الاستماع لجملتك بالكامل'
          : 'Listening... Take your time speaking your destination';
    });

    final ok = await _voiceService.initialize(
      onStatus: (status) {
        if (!mounted) return;
        if ((status == 'notListening' || status == 'done') && _recognizedText.trim().isNotEmpty) {
          if (_state == VoiceSheetState.listening) {
            _silenceTimer?.cancel();
            _handleFinalSpokenText(_recognizedText);
          }
        }
      },
    );
    if (!ok && mounted) {
      setState(() {
        _state = VoiceSheetState.error;
        _statusMessage = ar
            ? 'تعذر الوصول إلى المايكروفون. يرجى تفعيل الإذن.'
            : 'Microphone unavailable. Please grant permission.';
      });
      return;
    }

    await _voiceService.startListening(
      onResult: (text, isFinal) {
        if (!mounted) return;
        final clean = text.trim();
        if (clean.isEmpty) return;

        setState(() {
          _recognizedText = text;
        });

        // Smart sentence completion:
        // Reset the silence debounce timer. We wait for 2.4 seconds of continuous silence
        // after speaking stops before concluding the sentence, preventing mid-phrase cut-offs.
        _silenceTimer?.cancel();
        _silenceTimer = Timer(const Duration(milliseconds: 2400), () {
          if (mounted && _state == VoiceSheetState.listening && _recognizedText.trim().isNotEmpty) {
            _handleFinalSpokenText(_recognizedText);
          }
        });
      },
      onSoundLevelChange: (level) {
        if (mounted) {
          setState(() {
            _soundLevel = (level / 10.0).clamp(0.0, 1.0);
          });
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 5),
    );
  }

  Future<void> _handleFinalSpokenText(String spokenText) async {
    _silenceTimer?.cancel();
    await _voiceService.stopListening();
    final ar = widget.controller.arabic;

    setState(() {
      _state = VoiceSheetState.processing;
      _statusMessage = ar ? 'جارٍ تحليل الأمر الصوتي...' : 'Analyzing command...';
    });

    // 1. Parse Voice Intent with Iraqi/Arabic NLP Parser
    final result = _parser.parse(spokenText);

    // 2. Non-navigation voice commands (Cancel, Mute, Hazard, etc.)
    if (result.intent != VoiceIntentType.navigate) {
      await widget.controller.executeVoiceCommand(result);
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    // 3. Navigation intent: Search for extracted destination
    final query = result.destinationQuery.isNotEmpty ? result.destinationQuery : spokenText;
    setState(() {
      _state = VoiceSheetState.searching;
      _extractedQuery = query;
      _statusMessage = ar
          ? 'جارٍ البحث عن: "$query"'
          : 'Searching for: "$query"';
    });

    final places = await widget.controller.searchPlacesDirect(query);

    if (!mounted) return;

    if (places.isEmpty) {
      setState(() {
        _state = VoiceSheetState.error;
        _statusMessage = ar
            ? 'لم نعثر على "$query". جرب تحديد اسم المكان بشكل أدق.'
            : 'No places found for "$query". Please try again.';
      });
      return;
    }

    if (places.length == 1) {
      _triggerSinglePlaceNavigation(places.first);
    } else {
      setState(() {
        _state = VoiceSheetState.multipleResults;
        _candidatePlaces = places.take(3).toList();
        _statusMessage = ar
            ? 'اختر وجهتك المطلوبة:'
            : 'Select your destination:';
      });
    }
  }

  void _triggerSinglePlaceNavigation(Place place) {
    final ar = widget.controller.arabic;
    setState(() {
      _state = VoiceSheetState.navigating;
      _candidatePlaces = [place];
      _navCountdown = 3;
      _statusMessage = ar
          ? 'تم العثور على الوجهة! بدء الملاحة...'
          : 'Destination found! Starting route...';
    });

    _autoNavTimer?.cancel();
    _autoNavTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _navCountdown--;
      });
      if (_navCountdown <= 0) {
        timer.cancel();
        _confirmAndNavigate(place);
      }
    });
  }

  Future<void> _confirmAndNavigate(Place place) async {
    _autoNavTimer?.cancel();
    await _voiceService.stopListening();
    if (mounted) {
      Navigator.of(context).pop();
    }
    await widget.controller.navigateToPlaceFromVoice(place);
  }

  @override
  Widget build(BuildContext context) {
    final ar = widget.controller.arabic;
    final isDark = widget.controller.dark;
    final bgGradient = isDark
        ? const LinearGradient(
            colors: [Color(0xFF101722), Color(0xFF182232)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          )
        : const LinearGradient(
            colors: [Color(0xFFF8FAFC), Color(0xFFEDF2F7)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          );

    final textColor = isDark ? Colors.white : Colors.black87;

    return Directionality(
      textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
      child: Container(
        decoration: BoxDecoration(
          gradient: bgGradient,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 30,
              offset: const Offset(0, -6),
            ),
          ],
          border: Border.all(
            color: WazeColors.cyan.withOpacity(0.35),
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pull Handle
              Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: textColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: WazeColors.cyan.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.mic_rounded,
                          color: WazeColors.cyan,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        ar ? 'الملاحة الصوتية الذكية' : 'Smart Voice Navigation',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: textColor.withOpacity(0.6)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Central Animation / Visualizer
              _buildCenterVisualizer(),

              const SizedBox(height: 16),

              // Status Message
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _state == VoiceSheetState.error
                      ? WazeColors.red
                      : WazeColors.cyan,
                ),
              ),

              const SizedBox(height: 12),

              // Spoken Transcript Box
              if (_recognizedText.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2838) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: WazeColors.cyan.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    '"$_recognizedText"',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                ),

              const SizedBox(height: 14),

              // Results or Candidates List
              if (_state == VoiceSheetState.multipleResults ||
                  _state == VoiceSheetState.navigating)
                _buildCandidatesList(textColor),

              // Example Helper Hint (when listening)
              if (_state == VoiceSheetState.listening && _recognizedText.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.amber.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lightbulb_rounded, color: Colors.amber, size: 16),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          ar
                              ? 'مثال: "اريد الذهاب لساحة الفردوس"'
                              : 'e.g. "Take me to Firdos Square"',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // Bottom Action Button
              _buildBottomActionButtons(ar),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenterVisualizer() {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, child) {
        final pulseScale = 1.0 + (_pulseAnim.value * 0.18) + (_soundLevel * 0.25);
        final glowOpacity = (0.2 + (_pulseAnim.value * 0.3) + (_soundLevel * 0.5)).clamp(0.1, 0.85);

        return GestureDetector(
          onTap: () {
            if (_state == VoiceSheetState.listening) {
              if (_recognizedText.isNotEmpty) {
                _handleFinalSpokenText(_recognizedText);
              } else {
                _voiceService.stopListening();
                setState(() => _state = VoiceSheetState.error);
              }
            } else {
              _initAndStartListening();
            }
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer Glowing Aura
              Container(
                width: 96 * pulseScale,
                height: 96 * pulseScale,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (_state == VoiceSheetState.error
                          ? WazeColors.red
                          : WazeColors.cyan)
                      .withOpacity(glowOpacity * 0.35),
                ),
              ),
              // Inner Pulsing Ring
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: _state == VoiceSheetState.error
                        ? [WazeColors.red, const Color(0xFFB71C1C)]
                        : [WazeColors.cyan, const Color(0xFF007DAF)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_state == VoiceSheetState.error
                              ? WazeColors.red
                              : WazeColors.cyan)
                          .withOpacity(0.6),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  _state == VoiceSheetState.searching || _state == VoiceSheetState.processing
                      ? Icons.hourglass_top_rounded
                      : _state == VoiceSheetState.navigating
                          ? Icons.navigation_rounded
                          : Icons.mic_rounded,
                  color: Colors.black87,
                  size: 38,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCandidatesList(Color textColor) {
    final ar = widget.controller.arabic;
    return Column(
      children: _candidatePlaces.map((place) {
        final distKm = const Distance().as(
              LengthUnit.Kilometer,
              widget.controller.position,
              place.point,
            );

        final title = ar ? place.nameAr : place.name;
        final sub = (ar ? place.subtitleAr : place.subtitle) ?? '';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: widget.controller.dark
                ? const Color(0xFF1E2838)
                : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: WazeColors.cyan.withOpacity(0.4),
              width: 1.2,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: CircleAvatar(
              backgroundColor: WazeColors.cyan.withOpacity(0.2),
              child: const Icon(Icons.place_rounded, color: WazeColors.cyan),
            ),
            title: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: textColor,
              ),
            ),
            subtitle: Text(
              sub.isNotEmpty ? sub : (ar ? 'بغداد' : 'Baghdad'),
              style: TextStyle(
                fontSize: 12,
                color: textColor.withOpacity(0.7),
              ),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${distKm.toStringAsFixed(1)} ${ar ? 'كم' : 'km'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: WazeColors.cyan,
                  ),
                ),
                if (_state == VoiceSheetState.navigating)
                  Text(
                    '${_navCountdown}s',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: Colors.amber,
                    ),
                  ),
              ],
            ),
            onTap: () => _confirmAndNavigate(place),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBottomActionButtons(bool ar) {
    if (_state == VoiceSheetState.navigating && _candidatePlaces.isNotEmpty) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                _autoNavTimer?.cancel();
                setState(() {
                  _state = VoiceSheetState.multipleResults;
                });
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: WazeColors.red),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                ar ? 'إلغاء' : 'Cancel',
                style: const TextStyle(color: WazeColors.red, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: () => _confirmAndNavigate(_candidatePlaces.first),
              style: ElevatedButton.styleFrom(
                backgroundColor: WazeColors.cyan,
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.navigation_rounded),
              label: Text(
                ar ? 'انطلق الآن (${_navCountdown})' : 'Drive Now (${_navCountdown})',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      );
    }

    if (_state == VoiceSheetState.listening && _recognizedText.trim().isNotEmpty) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                _silenceTimer?.cancel();
                _initAndStartListening();
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: WazeColors.cyan.withOpacity(0.5)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                ar ? 'إعادة' : 'Restart',
                style: const TextStyle(color: WazeColors.cyan, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: () {
                _silenceTimer?.cancel();
                _handleFinalSpokenText(_recognizedText);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: WazeColors.cyan,
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.search_rounded),
              label: Text(
                ar ? 'تم، ابحث الآن' : 'Done, Search Now',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      );
    }

    if (_state == VoiceSheetState.error) {
      return ElevatedButton.icon(
        onPressed: _initAndStartListening,
        style: ElevatedButton.styleFrom(
          backgroundColor: WazeColors.cyan,
          foregroundColor: Colors.black87,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: const Icon(Icons.refresh_rounded),
        label: Text(
          ar ? 'إعادة المحاولة' : 'Try Again',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      );
    }

    return TextButton.icon(
      onPressed: () {
        _silenceTimer?.cancel();
        _voiceService.stopListening();
        Navigator.of(context).pop();
      },
      icon: const Icon(Icons.keyboard_rounded, size: 18),
      label: Text(ar ? 'أو اكتب الوجهة يدوياً' : 'Or type destination manually'),
      style: TextButton.styleFrom(foregroundColor: WazeColors.cyan),
    );
  }
}
