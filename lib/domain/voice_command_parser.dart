// Pure Voice Command & Intent Parser for Darb.
// Handles Arabic (Iraqi & Modern Standard Arabic) and English navigation commands.

enum VoiceIntentType {
  navigate,
  cancelNavigation,
  muteSound,
  unmuteSound,
  reportHazard,
  unknown,
}

class VoiceCommandResult {
  final VoiceIntentType intent;
  final String rawText;
  final String destinationQuery;
  final String? hazardType;

  const VoiceCommandResult({
    required this.intent,
    required this.rawText,
    this.destinationQuery = '',
    this.hazardType,
  });

  bool get isNavigation => intent == VoiceIntentType.navigate && destinationQuery.isNotEmpty;

  @override
  String toString() =>
      'VoiceCommandResult(intent: $intent, query: "$destinationQuery", hazard: $hazardType)';
}

class VoiceCommandParser {
  const VoiceCommandParser();

  /// Parse natural language voice text into structured navigation intent.
  VoiceCommandResult parse(String text) {
    final raw = text.trim();
    if (raw.isEmpty) {
      return VoiceCommandResult(intent: VoiceIntentType.unknown, rawText: raw);
    }

    final lower = raw.toLowerCase();

    // 1. Cancel / Stop Navigation
    if (_matchesAny(lower, [
      'الغاء الملاحة',
      'إلغاء الملاحة',
      'وقف الملاحة',
      'أوقف الملاحة',
      'انهاء الملاحة',
      'إنهاء الملاحة',
      'بطلت',
      'cancel navigation',
      'stop navigation',
      'end navigation',
      'stop route',
    ])) {
      return VoiceCommandResult(
        intent: VoiceIntentType.cancelNavigation,
        rawText: raw,
      );
    }

    // 2. Mute Sound
    if (_matchesAny(lower, [
      'كتم الصوت',
      'اخرس',
      'اسكت',
      'صامت',
      'mute',
      'mute sound',
      'mute voice',
    ])) {
      return VoiceCommandResult(
        intent: VoiceIntentType.muteSound,
        rawText: raw,
      );
    }

    // 3. Unmute Sound
    if (_matchesAny(lower, [
      'تشغيل الصوت',
      'شغل الصوت',
      'تكلم',
      'احجي',
      'تفعيل الصوت',
      'unmute',
      'unmute sound',
      'turn on voice',
    ])) {
      return VoiceCommandResult(
        intent: VoiceIntentType.unmuteSound,
        rawText: raw,
      );
    }

    // 4. Report Hazard
    if (_matchesAny(lower, [
      'بلاغ عن حادث',
      'سجل حادث',
      'حادث سير',
      'حادث',
      'report accident',
      'report crash',
    ])) {
      return VoiceCommandResult(
        intent: VoiceIntentType.reportHazard,
        rawText: raw,
        hazardType: 'crash',
      );
    }
    if (_matchesAny(lower, [
      'بلاغ عن مطب',
      'سجل مطب',
      'مطب اصطناعي',
      'اكو مطب',
      'مطب',
      'report speed bump',
      'report bump',
    ])) {
      return VoiceCommandResult(
        intent: VoiceIntentType.reportHazard,
        rawText: raw,
        hazardType: 'bump',
      );
    }
    if (_matchesAny(lower, [
      'بلاغ عن شرطة',
      'بلاغ عن سيطرة',
      'اكو سيطرة',
      'سيطرة',
      'مفرزة',
      'report police',
    ])) {
      return VoiceCommandResult(
        intent: VoiceIntentType.reportHazard,
        rawText: raw,
        hazardType: 'police',
      );
    }

    // 5. Navigation intent: Extract clean destination query
    final destination = extractDestination(raw);
    if (destination.isNotEmpty) {
      return VoiceCommandResult(
        intent: VoiceIntentType.navigate,
        rawText: raw,
        destinationQuery: destination,
      );
    }

    // Default fallback: treat the raw string as a destination search query
    return VoiceCommandResult(
      intent: VoiceIntentType.navigate,
      rawText: raw,
      destinationQuery: raw,
    );
  }

  /// Extracts the clean target destination query from conversational spoken Arabic or English.
  /// Example: "اريد الذهاب لمطعم رويال كالاكسي في المنصور" -> "مطعم رويال كالاكسي المنصور"
  String extractDestination(String raw) {
    var text = raw.trim();

    // Regex list of conversational command prefixes in Arabic & English
    final prefixPatterns = [
      // Arabic conversational prefixes (Iraqi & MSA)
      r'^(اريد|أريد|حبي اريد|اريد ان|أريد أن)\s+(الذهاب|أذهب|اروح|أروح)\s+(الى|إلى|لـ|ل)?\s*',
      r'^(وديني|ودّيني|اخذني|أخذني|وصلني|وصّلني)\s+(الى|إلى|لـ|ل)?\s*',
      r'^(دربني|دربنى)\s+(على|الى|إلى|لـ|ل)?\s*',
      r'^(روح|امشي|اتجه)\s+(الى|إلى|لـ|ل)?\s*',
      r'^(درب\s+(الى|إلى|لـ|ل)?)\s*',
      r'^(ابحث\s+عن|دور\s+على|وين|أين|موقع)\s*',
      r'^(طريق|مسار)\s+(الى|إلى|لـ|ل)?\s*',
      // English conversational prefixes
      r'^(i\s+want\s+to\s+go\s+to|take\s+me\s+to|navigate\s+to|drive\s+to|go\s+to|head\s+to|directions\s+to|where\s+is|find|search\s+for)\s*',
    ];

    for (final pattern in prefixPatterns) {
      final reg = RegExp(pattern, caseSensitive: false);
      if (reg.hasMatch(text)) {
        text = text.replaceFirst(reg, '').trim();
        break;
      }
    }

    // Clean leading single "لـ" or "ل" preposition if left attached to the first word
    // e.g., "لمطعم رويال" -> "مطعم رويال" (avoid stripping words starting with 'ل' like 'لبنان' or 'لوتس')
    if (text.startsWith('لـ')) {
      text = text.substring(2).trim();
    } else if (text.startsWith('ل') && text.length > 4 && _isPrepositionLam(text)) {
      text = text.substring(1).trim();
    }

    // Normalize filler connective prepositions e.g. "في المنصور" -> "المنصور", "بشارع" -> "شارع"
    text = text.replaceAll(RegExp(r'\s+في\s+'), ' ');
    text = text.replaceAll(RegExp(r'\s+يم\s+'), ' ');
    text = text.replaceAll(RegExp(r'\s+قرب\s+'), ' قرب ');
    text = text.replaceAll(RegExp(r'\s+بـ'), ' ');

    // Normalize multiple spaces
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    return text;
  }

  bool _isPrepositionLam(String wordWithLam) {
    // If the word starts with 'ل' followed by common place nouns:
    // لمطعم, لمول, لفندق, لمستشفى, للمطار, لشارع, لجامع, لمنطقة, لكافيه
    final commonNouns = [
      'مطعم',
      'مول',
      'ساحة',
      'فندق',
      'مستشفى',
      'مشفى',
      'مطار',
      'شارع',
      'جامع',
      'مسجد',
      'كافيه',
      'مقهى',
      'محطة',
      'بارك',
      'حديقة',
      'حي',
      'مدينة',
      'سوق',
      'مكتبة',
      'صيدلية',
      'مدرسه',
      'مدرسة',
      'جامعة',
      'كلية',
      'معرض',
      'برج',
    ];

    final rest = wordWithLam.substring(1);
    for (final noun in commonNouns) {
      if (rest.startsWith(noun) || rest.startsWith('ال$noun')) {
        return true;
      }
    }
    // Handle double lam for definite nouns: "للمنصور" -> "المنصور"
    if (wordWithLam.startsWith('لل')) {
      return true;
    }
    return false;
  }

  bool _matchesAny(String input, List<String> phrases) {
    for (final p in phrases) {
      if (input == p || input.contains(p)) return true;
    }
    return false;
  }
}
